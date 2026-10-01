extends Node
## Per-mission economy for MVP2: money, recruitment queue + unit cap,
## Gun Shop inventory (purchased-but-unassigned weapons), payroll timer,
## and safe-zone geometry (Bank + Recruitment radius). Not an autoload —
## this state belongs to one campaign mission, not the whole game.
##
## Full economy (carried cash, factories, dealers, deposits) is MVP3
## scope ("PABRIK DAN PENJUALAN", "BANK DAN SAFE ZONE" deposit flow).
## MVP2 only needs enough economy to make recruitment/Gun Shop/payroll
## real and testable.

signal money_changed(amount: int)
signal recruitment_progress(tier: String, remaining_sec: float, total_sec: float)
signal unit_recruited(tier: String)
signal payroll_processed(paid: bool, total_due: int)

const PAYROLL_INTERVAL_SEC := 120.0
## Recruitment timer duration is not specified numerically by Prompt
## Dasar (only price/salary/unit-cap are); these scale with tier as a
## documented MVP2 assumption (see docs/TECH_DECISIONS.md).
const RECRUIT_TIME_BY_TIER := {"B1": 8.0, "B2": 12.0, "B3": 18.0}
## 1 in-fiction meter = 20px, used for safe-zone/Heat-style radii.
const PIXELS_PER_METER := 20.0
const SAFE_ZONE_RADIUS_M := 18.0

var _combat_log: Node = null

var money: int = 0
var max_roster: int = 30 # excludes the Main Character, per Prompt Dasar
var recruited_count: int = 0

var unit_data_by_tier: Dictionary = {} # "B1"/"B2"/"B3" -> UnitData
var weapon_catalog: Dictionary = {} # weapon id String -> WeaponData
var gun_shop_inventory: Dictionary = {} # weapon id String -> owned unassigned count

var _recruit_queue: Array = [] # [{tier, remaining, total}]
var _payroll_timer: float = 0.0
var safe_zone_points: Array = [] # Array[Vector2]

## Populated by the owning scene after spawn: every currently-alive
## player-side unit, used to compute payroll due.
var payroll_units: Array = []


func _ready() -> void:
	_combat_log = get_node_or_null("/root/CombatLog")
	_load_weapon_catalog()
	_load_unit_data()


func _load_weapon_catalog() -> void:
	var dir := DirAccess.open("res://data/weapons/")
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			var w: WeaponData = load("res://data/weapons/" + f)
			weapon_catalog[String(w.id)] = w
			gun_shop_inventory[String(w.id)] = 0
		f = dir.get_next()
	dir.list_dir_end()


func _load_unit_data() -> void:
	unit_data_by_tier["B1"] = load("res://data/units/juan_b1.tres")
	unit_data_by_tier["B2"] = load("res://data/units/juan_b2.tres")
	unit_data_by_tier["B3"] = load("res://data/units/juan_b3.tres")


func set_money(amount: int) -> void:
	money = amount
	money_changed.emit(money)


func can_afford(amount: int) -> bool:
	return money >= amount


func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


## --- Recruitment ---
func try_start_recruit(tier: String) -> bool:
	if tier == "SPECIAL":
		return false # locked in MVP2, per Prompt Dasar
	var data: UnitData = unit_data_by_tier.get(tier)
	if data == null:
		return false
	if recruited_count + _recruit_queue.size() >= max_roster:
		return false
	if not can_afford(data.recruit_price):
		return false
	spend(data.recruit_price)
	var total: float = RECRUIT_TIME_BY_TIER.get(tier, 10.0)
	_recruit_queue.append({"tier": tier, "remaining": total, "total": total})
	return true


func _process(delta: float) -> void:
	_advance_recruit_queue(delta)
	_advance_payroll(delta)


func _advance_recruit_queue(delta: float) -> void:
	if _recruit_queue.is_empty():
		return
	var entry: Dictionary = _recruit_queue[0]
	entry["remaining"] -= delta
	recruitment_progress.emit(entry["tier"], max(0.0, entry["remaining"]), entry["total"])
	if entry["remaining"] <= 0.0:
		_recruit_queue.pop_front()
		recruited_count += 1
		unit_recruited.emit(entry["tier"])


## --- Gun Shop ---
func try_buy_weapon(weapon_id: String) -> bool:
	var w: WeaponData = weapon_catalog.get(weapon_id)
	if w == null:
		return false
	if not can_afford(w.price):
		return false
	spend(w.price)
	gun_shop_inventory[weapon_id] = gun_shop_inventory.get(weapon_id, 0) + 1
	return true


func try_assign_weapon(unit: BwUnit, slot: String, weapon_id: String) -> bool:
	var count: int = gun_shop_inventory.get(weapon_id, 0)
	if count <= 0:
		return false
	gun_shop_inventory[weapon_id] = count - 1
	unit.equip_weapon(slot, weapon_catalog[weapon_id])
	return true


## --- Payroll ---
func _advance_payroll(delta: float) -> void:
	_payroll_timer += delta
	if _payroll_timer < PAYROLL_INTERVAL_SEC:
		return
	_payroll_timer = 0.0
	var total_due := 0
	for u in payroll_units:
		if is_instance_valid(u):
			total_due += u.salary
	var paid: bool = can_afford(total_due)
	if paid:
		spend(total_due)
	for u in payroll_units:
		if is_instance_valid(u):
			u.apply_payroll_result(paid)
	_log_event("Payroll: %s ($%d due)." % ["paid" if paid else "MISSED", total_due])
	payroll_processed.emit(paid, total_due)


## --- Safe zone ---
func is_position_safe(pos: Vector2) -> bool:
	var radius_px: float = SAFE_ZONE_RADIUS_M * PIXELS_PER_METER
	for p in safe_zone_points:
		if pos.distance_to(p) <= radius_px:
			return true
	return false


func _log_event(text: String) -> void:
	if _combat_log:
		_combat_log.log_event(text)
