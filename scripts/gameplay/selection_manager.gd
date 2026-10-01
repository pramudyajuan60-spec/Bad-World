class_name SelectionManager
extends Node
## Owns the player's unit roster and current selection/control groups.
## Selection-rectangle and same-tier helpers are static + pure so they can
## be unit-tested without input simulation (see tests/test_selection_and_formation.gd).

signal selection_updated(units: Array)

var player_units: Array = []
var selected: Array = []
var control_groups: Dictionary = {}


func register_unit(u: BwUnit) -> void:
	player_units.append(u)
	u.died.connect(_on_unit_died.bind(u))


func _on_unit_died(u: BwUnit) -> void:
	player_units.erase(u)
	selected.erase(u)
	for k in control_groups.keys():
		control_groups[k].erase(u)
	selection_updated.emit(selected)


func select_only(units: Array) -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected = units.duplicate()
	for u in selected:
		u.set_selected(true)
	selection_updated.emit(selected)


func toggle_selection(units: Array) -> void:
	for u in units:
		if u in selected:
			selected.erase(u)
			u.set_selected(false)
		else:
			selected.append(u)
			u.set_selected(true)
	selection_updated.emit(selected)


func clear_selection() -> void:
	select_only([])


static func units_in_rect(units: Array, rect: Rect2) -> Array:
	var result: Array = []
	for u in units:
		if is_instance_valid(u) and rect.has_point(u.global_position):
			result.append(u)
	return result


static func units_of_same_tier(units: Array, reference: BwUnit) -> Array:
	var result: Array = []
	for u in units:
		if is_instance_valid(u) and u.tier_label == reference.tier_label:
			result.append(u)
	return result


func assign_control_group(n: int) -> void:
	control_groups[n] = selected.duplicate()


func recall_control_group(n: int) -> void:
	if not control_groups.has(n):
		return
	var units: Array = (control_groups[n] as Array).filter(func(u): return is_instance_valid(u))
	control_groups[n] = units
	if units.is_empty():
		return
	select_only(units)
