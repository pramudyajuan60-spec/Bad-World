extends Area2D
## Cartel factory (Prompt Dasar MVP3 "PABRIK DAN PENJUALAN"). Produces
## cargo over time up to a small on-site cap; a player unit that walks
## up can pick up cargo instantly (spec doesn't mandate a channel here).
## Destructible + repairable: destruction halts production without
## eliminating the faction, matching the acceptance criterion.

signal cargo_available_changed(count: int)
signal hp_changed(ratio: float)
signal destroyed
signal repaired

@export var level: int = 1
@export var faction_side: StringName = &"player"
const MAX_LEVEL := 4
const MAX_STORED_CARGO := 5
## Prompt Dasar PABRIK DAN PENJUALAN table.
const LEVEL_CONFIG := {
	1: {"interval": 45.0, "base_value": 700, "upgrade_cost": 0, "quality": 1.0},
	2: {"interval": 38.0, "base_value": 700, "upgrade_cost": 1500, "quality": 1.15},
	3: {"interval": 32.0, "base_value": 700, "upgrade_cost": 3500, "quality": 1.35},
	4: {"interval": 28.0, "base_value": 700, "upgrade_cost": 7000, "quality": 1.60},
}
## Not specified numerically by Prompt Dasar; a simple MVP3 assumption
## scaling with level (see docs/BALANCE.md).
const MAX_HP_BY_LEVEL := {1: 300.0, 2: 400.0, 3: 500.0, 4: 650.0}
const REPAIR_COST_PER_HP := 6.0

var stored_cargo: int = 0
var hp: float = 300.0
var max_hp: float = 300.0
var is_destroyed: bool = false

var _production_timer: float = 0.0
var _units_in_range: Array = []


func _ready() -> void:
	max_hp = MAX_HP_BY_LEVEL.get(level, 300.0)
	hp = max_hp
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if is_destroyed:
		return
	if stored_cargo >= MAX_STORED_CARGO:
		return
	_production_timer += delta
	var interval: float = LEVEL_CONFIG[level]["interval"]
	if _production_timer >= interval:
		_production_timer = 0.0
		stored_cargo += 1
		cargo_available_changed.emit(stored_cargo)


func cargo_value() -> int:
	return int(LEVEL_CONFIG[level]["base_value"] * LEVEL_CONFIG[level]["quality"])


func upgrade_cost() -> int:
	if level >= MAX_LEVEL:
		return -1
	return LEVEL_CONFIG[level + 1]["upgrade_cost"]


func upgrade() -> void:
	if level < MAX_LEVEL:
		level += 1
		max_hp = MAX_HP_BY_LEVEL.get(level, max_hp)
		hp = max_hp


func take_damage(amount: float) -> void:
	if is_destroyed:
		return
	hp = max(0.0, hp - amount)
	hp_changed.emit(hp / max_hp)
	if hp <= 0.0:
		is_destroyed = true
		destroyed.emit()


func repair_cost() -> int:
	return int(ceil((max_hp - hp) * REPAIR_COST_PER_HP))


func repair_full() -> void:
	hp = max_hp
	is_destroyed = false
	hp_changed.emit(1.0)
	repaired.emit()


## Instant pickup (no channel, per spec silence on this step): a unit in
## range takes up to its remaining cargo capacity from stored_cargo.
func try_pickup(unit) -> bool:
	if is_destroyed or stored_cargo <= 0:
		return false
	var room: int = unit.CARGO_CAPACITY - unit.carried_cargo
	if room <= 0:
		return false
	var taken: int = min(room, stored_cargo)
	stored_cargo -= taken
	unit.carried_cargo += taken
	cargo_available_changed.emit(stored_cargo)
	return true


func _on_body_entered(body: Node) -> void:
	if body is BwUnit:
		_units_in_range.append(body)


func _on_body_exited(body: Node) -> void:
	_units_in_range.erase(body)


func get_units_in_range() -> Array:
	return _units_in_range.filter(func(u): return is_instance_valid(u))
