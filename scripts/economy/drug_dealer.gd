extends Area2D
## Drug Dealer (Prompt Dasar MVP3): sells carried cargo for carried
## cash. Each dealer has its own independent diminishing-demand curve
## (100%/90%/75%/50%...) that recovers after ~45s of not being used, and
## selling requires a 5s channel — implemented via BwUnit's generic
## start_interaction/on_interaction_complete hook.

const SELL_CHANNEL_SEC := 5.0
const DEMAND_RECOVERY_SEC := 45.0
const DEMAND_STEPS := [1.0, 0.9, 0.75, 0.5] # 4th and beyond stay at the last (50%) value

@export var dealer_label: String = "Drug Dealer"
@export var is_placeholder: bool = false

var _sale_count: int = 0
var _time_since_last_sale: float = 999.0
var _units_in_range: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_time_since_last_sale += delta
	if _time_since_last_sale >= DEMAND_RECOVERY_SEC and _sale_count > 0:
		_sale_count = 0


func current_demand_multiplier() -> float:
	var idx: int = min(_sale_count, DEMAND_STEPS.size() - 1)
	return DEMAND_STEPS[idx]


func start_sell(unit, economy: Node, cargo_unit_value: int) -> bool:
	if unit.carried_cargo <= 0:
		return false
	unit.start_interaction(self, SELL_CHANNEL_SEC)
	set_meta("pending_economy_%d" % unit.get_instance_id(), economy)
	set_meta("pending_value_%d" % unit.get_instance_id(), cargo_unit_value)
	return true


func on_interaction_complete(unit) -> void:
	var economy_key := "pending_economy_%d" % unit.get_instance_id()
	var value_key := "pending_value_%d" % unit.get_instance_id()
	# Godot 4.3 quirk: get_meta(key, null) still logs a spurious ERROR
	# line for a missing key even though it correctly returns the null
	# default — has_meta() must be checked first to stay silent.
	var economy = null
	if has_meta(economy_key):
		economy = get_meta(economy_key)
		remove_meta(economy_key)
	var cargo_value: int = 700
	if has_meta(value_key):
		cargo_value = get_meta(value_key)
		remove_meta(value_key)
	if unit.carried_cargo <= 0:
		return
	var earned: int = int(cargo_value * current_demand_multiplier() * unit.carried_cargo)
	unit.carried_cargo = 0
	unit.carried_cash += earned
	_sale_count += 1
	_time_since_last_sale = 0.0
	if economy:
		economy._log_event("%s sold cargo to %s for $%d (demand now %d%%)." % [unit.display_name, dealer_label, earned, int(current_demand_multiplier() * 100)])


func _on_body_entered(body: Node) -> void:
	if body is BwUnit:
		_units_in_range.append(body)


func _on_body_exited(body: Node) -> void:
	_units_in_range.erase(body)


func get_units_in_range() -> Array:
	return _units_in_range.filter(func(u): return is_instance_valid(u))
