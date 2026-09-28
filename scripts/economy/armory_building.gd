extends Area2D
## DEA Armory (Nabil's Gun Shop equivalent, Prompt Dasar: "Nabil tidak
## membeli senjata biasa. Senjata dibuat di DEA Armory menggunakan Parts
## dan waktu crafting"). Thin walk-up trigger; all crafting logic lives
## in CampaignEconomy (try_start_craft/_advance_armory) so it can be
## exercised headlessly without a scene.

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
