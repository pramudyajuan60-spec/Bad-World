extends Area2D
## Garage (Prompt Dasar MVP3): buy any of the 4 vehicle classes (spawned
## empty, awaiting a driver), and repair the nearest damaged player
## vehicle within range. No channel specified for either action.

signal vehicle_purchase_requested(vehicle_data_id: String)

var economy: Node = null
var _vehicles_in_range: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func nearest_damaged_vehicle():
	var best = null
	var best_hp_ratio := 1.0
	for v in _vehicles_in_range:
		if not is_instance_valid(v) or v.hp <= 0.0:
			continue
		var ratio: float = v.hp / v.max_hp
		if ratio < 1.0 and ratio <= best_hp_ratio:
			best_hp_ratio = ratio
			best = v
	return best


func try_repair() -> bool:
	var v = nearest_damaged_vehicle()
	if v == null:
		return false
	var cost: int = v.repair_cost()
	if not economy.spend(cost):
		return false
	v.repair_full()
	economy._log_event("Repaired a vehicle for $%d." % cost)
	return true


func _on_body_entered(body: Node) -> void:
	if body is Vehicle:
		_vehicles_in_range.append(body)


func _on_body_exited(body: Node) -> void:
	_vehicles_in_range.erase(body)
