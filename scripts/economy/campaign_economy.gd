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
## MVP4: Nabil's DEA Armory (Prompt Dasar "Nabil membuat senjata di
## Armory menggunakan Parts").
signal parts_changed(amount: int)
signal crafting_progress(weapon_id: String, remaining_sec: float, total_sec: float)
signal item_crafted(weapon_id: String)

const PAYROLL_INTERVAL_SEC := 120.0
## Recruitment timer duration is not specified numerically by Prompt
## Dasar (only price/salary/unit-cap are); these scale with tier as a
## documented MVP2 assumption (see docs/TECH_DECISIONS.md).
const RECRUIT_TIME_BY_TIER := {"B1": 8.0, "B2": 12.0, "B3": 18.0}
## 1 in-fiction meter = 20px, used for safe-zone/Heat-style radii.
const PIXELS_PER_METER := 20.0
const SAFE_ZONE_RADIUS_M := 18.0

## Armory (Nabil only; Prompt Dasar "SENJATA, INVENTORY, DAN AMUNISI").
const ARMORY_PARTS_PER_TICK := 100
const ARMORY_TICK_SEC := 90.0
const ARMORY_MAX_PARTS := 1500
## Prompt Dasar Parts costs; crafting time scales 5-18s with cost.
const ARMORY_PARTS_COST := {
	"weapon_pistol": 40, "weapon_smg": 70, "weapon_shotgun": 90,
	"weapon_assault_rifle": 110, "weapon_sniper_rifle": 180,
	"weapon_lmg": 220, "weapon_grenade": 30,
}

## Nabil's City Patrol income (Prompt Dasar "PATROL"). $110 per unit
## per 60s baseline, reduced by nearby-patroller distance rules.
const PATROL_BASE_INCOME_PER_MIN := 110.0
const PATROL_MIN_IDLE_SEC := 15.0
const PATROL_MAX_INCOME_UNITS_PER_SECTOR := 4
## Sector size used only to group patrol income calculations; not a
## real world-partition system (see docs/TECH_DECISIONS.md).
const PATROL_SECTOR_SIZE_PX := 600.0

## Nabil's "DEA response menjadi allied AI" (Prompt Dasar Campaign Nabil
## section). Budgeted dispatch instead of hostile Heat/DEA waves.
const ALLY_DISPATCH_COST := 300
const ALLY_DISPATCH_COOLDOWN_SEC := 90.0

var parts: int = 0
var _armory_production_timer: float = 0.0
var _armory_queue: Array = [] # [{weapon_id, remaining, total}]
var _patrol_idle_time: Dictionary = {} # unit instance id -> seconds stood still while patrolling
var _ally_dispatch_cooldown: float = 0.0

var _combat_log: Node = null

var money: int = 0
## MVP6 campaign-summary stat (Prompt Dasar "campaign summary"): total
## money gained over the mission, tracked separately from `money`
## (which can also go down via spend()). Reset to 0 right after the
## owning scene sets starting_money, so starting funds don't count as
## "earned".
var lifetime_money_earned: int = 0
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
		if not dir.current_is_dir():
			# Release Candidate Fix Pass: see campaign_database.gd's
			# identical fix — an exported PCK lists these as
			# "<name>.tres.remap", not "<name>.tres"; load() still
			# needs the un-suffixed name.
			var real_name: String = f
			if real_name.ends_with(".remap"):
				real_name = real_name.substr(0, real_name.length() - ".remap".length())
			if real_name.ends_with(".tres"):
				var w: WeaponData = load("res://data/weapons/" + real_name)
				weapon_catalog[String(w.id)] = w
				gun_shop_inventory[String(w.id)] = 0
		f = dir.get_next()
	dir.list_dir_end()


func _load_unit_data() -> void:
	unit_data_by_tier["B1"] = load("res://data/units/juan_b1.tres")
	unit_data_by_tier["B2"] = load("res://data/units/juan_b2.tres")
	unit_data_by_tier["B3"] = load("res://data/units/juan_b3.tres")


## MVP4: overrides the Juan-only defaults above with the actual campaign
## being played. Called once by open_world_map.gd after resolving
## current_campaign. B1 key is omitted entirely for factions without it
## (Nabil), so any UI that iterates unit_data_by_tier.keys() naturally
## hides the B1 option without needing its own faction check.
func configure_roster(campaign: CampaignData) -> void:
	unit_data_by_tier.clear()
	if campaign.b1_unit:
		unit_data_by_tier["B1"] = campaign.b1_unit
	unit_data_by_tier["B2"] = campaign.b2_unit
	unit_data_by_tier["B3"] = campaign.b3_unit


func set_money(amount: int) -> void:
	if amount > money:
		lifetime_money_earned += (amount - money)
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
	_advance_armory(delta)
	if _ally_dispatch_cooldown > 0.0:
		_ally_dispatch_cooldown -= delta


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


## --- Nabil's DEA Armory (Parts, not money) ---
func try_start_craft(weapon_id: String) -> bool:
	var cost: int = ARMORY_PARTS_COST.get(weapon_id, -1)
	if cost < 0 or parts < cost:
		return false
	parts -= cost
	parts_changed.emit(parts)
	# Prompt Dasar: "Crafting membutuhkan waktu 5-18 detik tergantung
	# item" — scaled linearly by Parts cost across the known 30-220 range.
	var t: float = clampf(remap(float(cost), 30.0, 220.0, 5.0, 18.0), 5.0, 18.0)
	_armory_queue.append({"weapon_id": weapon_id, "remaining": t, "total": t})
	return true


func _advance_armory(delta: float) -> void:
	if parts < ARMORY_MAX_PARTS:
		_armory_production_timer += delta
		if _armory_production_timer >= ARMORY_TICK_SEC:
			_armory_production_timer = 0.0
			parts = min(ARMORY_MAX_PARTS, parts + ARMORY_PARTS_PER_TICK)
			parts_changed.emit(parts)
	if _armory_queue.is_empty():
		return
	var entry: Dictionary = _armory_queue[0]
	entry["remaining"] -= delta
	crafting_progress.emit(entry["weapon_id"], max(0.0, entry["remaining"]), entry["total"])
	if entry["remaining"] <= 0.0:
		_armory_queue.pop_front()
		var wid: String = entry["weapon_id"]
		gun_shop_inventory[wid] = gun_shop_inventory.get(wid, 0) + 1
		item_crafted.emit(wid)


## --- Nabil's City Patrol income (distance-efficiency rules) ---
## Called once per frame by the owning scene with the current list of
## Nabil units in State.PATROLLING. Units must stand/patrol at least
## PATROL_MIN_IDLE_SEC before earning, per Prompt Dasar; income never
## applies while fighting, at Bank, or at Recruitment (callers simply
## don't pass those units in).
func apply_patrol_income(delta: float, patrolling_units: Array) -> void:
	var sectors: Dictionary = {} # Vector2i sector -> Array[BwUnit]
	for u in patrolling_units:
		if not is_instance_valid(u):
			continue
		var id: int = u.get_instance_id()
		_patrol_idle_time[id] = _patrol_idle_time.get(id, 0.0) + delta
		if _patrol_idle_time[id] < PATROL_MIN_IDLE_SEC:
			continue
		var sector := Vector2i(floori(u.global_position.x / PATROL_SECTOR_SIZE_PX), floori(u.global_position.y / PATROL_SECTOR_SIZE_PX))
		if not sectors.has(sector):
			sectors[sector] = []
		sectors[sector].append(u)

	var total_income := 0.0
	for sector in sectors.keys():
		var units: Array = sectors[sector]
		for i in range(min(units.size(), PATROL_MAX_INCOME_UNITS_PER_SECTOR)):
			var efficiency: float = 1.0
			# Prompt Dasar distance rule, approximated per-sector by rank
			# (1st full, 2nd 50%, 3rd+ 25% within the same crowded sector)
			# since exact pairwise <8m/8-15m checks would need a full
			# spatial query for a rule that only matters when units are
			# clustered together in the same small area anyway.
			if i == 1:
				efficiency = 0.5
			elif i >= 2:
				efficiency = 0.25
			total_income += (PATROL_BASE_INCOME_PER_MIN / 60.0) * delta * efficiency
	if total_income > 0.0:
		set_money(money + int(round(total_income)))


## MVP6 "Patrol efficiency overlay" (read-only UI helper): mirrors
## apply_patrol_income's sector-rank-based efficiency rule without any
## side effects, so the HUD can show each patrolling unit's current
## income tier and idle-warmup progress every frame.
func patrol_efficiency_snapshot(patrolling_units: Array) -> Array:
	var sectors: Dictionary = {}
	for u in patrolling_units:
		if not is_instance_valid(u):
			continue
		var sector := Vector2i(floori(u.global_position.x / PATROL_SECTOR_SIZE_PX), floori(u.global_position.y / PATROL_SECTOR_SIZE_PX))
		if not sectors.has(sector):
			sectors[sector] = []
		sectors[sector].append(u)
	var out: Array = []
	for sector in sectors.keys():
		var units: Array = sectors[sector]
		for i in range(units.size()):
			var u = units[i]
			var id: int = u.get_instance_id()
			var idle_sec: float = _patrol_idle_time.get(id, 0.0)
			var warmed_up: bool = idle_sec >= PATROL_MIN_IDLE_SEC
			var efficiency := 1.0
			if i >= PATROL_MAX_INCOME_UNITS_PER_SECTOR:
				efficiency = 0.0 # beyond this sector's income cap entirely
			elif i == 1:
				efficiency = 0.5
			elif i >= 2:
				efficiency = 0.25
			out.append({
				"name": u.display_name, "efficiency": efficiency if warmed_up else 0.0,
				"warmed_up": warmed_up, "idle_sec": idle_sec,
			})
	return out


## --- Nabil's allied DEA response dispatch (replaces hostile Heat/DEA) ---
func try_dispatch_allies() -> bool:
	if _ally_dispatch_cooldown > 0.0 or not can_afford(ALLY_DISPATCH_COST):
		return false
	spend(ALLY_DISPATCH_COST)
	_ally_dispatch_cooldown = ALLY_DISPATCH_COOLDOWN_SEC
	return true


func _log_event(text: String) -> void:
	if _combat_log:
		_combat_log.log_event(text)
