extends Area2D
## Generic "walk up, press E, open a UI panel" building trigger — used
## for Recruitment and Gun Shop, which are pure UI (no channeled action
## of their own). See docs/TECH_DECISIONS.md "Recruitment/Gun Shop/
## Inspect are HUD buttons" for why MVP2 had these as always-visible
## buttons and MVP3 upgrades them to real in-world buildings.

@export var building_label: String = "Building"

var panel: Control = null
var _units_in_range: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func has_player_in_range() -> bool:
	for u in _units_in_range:
		if is_instance_valid(u) and u.faction_side == &"player":
			return true
	return false


func toggle_panel() -> void:
	if panel:
		panel.visible = not panel.visible


func _on_body_entered(body: Node) -> void:
	if body is BwUnit:
		_units_in_range.append(body)


func _on_body_exited(body: Node) -> void:
	_units_in_range.erase(body)
