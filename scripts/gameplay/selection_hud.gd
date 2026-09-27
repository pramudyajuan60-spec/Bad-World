extends Control
## Bottom-left HUD panel: portrait + name + HP of the primary selected
## unit (Prompt Dasar "Selection ring, destination marker, health bar, dan
## unit portrait"). Portraits are real repository assets, not placeholders
## (Juan.jpg for the Main Character; the matching Unit N.jpg for each B1).

@onready var portrait: TextureRect = $Panel/HBox/Portrait
@onready var name_label: Label = $Panel/HBox/VBox/NameLabel
@onready var hp_label: Label = $Panel/HBox/VBox/HpLabel

var _current_unit: BwUnit = null


func _process(_delta: float) -> void:
	if _current_unit != null and is_instance_valid(_current_unit):
		hp_label.text = "HP %d / %d" % [int(_current_unit.hp), int(_current_unit.max_hp)]
	elif visible:
		show_unit(null)


func show_unit(u) -> void:
	_current_unit = u
	if u == null:
		visible = false
		return
	visible = true
	name_label.text = "%s (%s)" % [u.display_name, u.tier_label]
	hp_label.text = "HP %d / %d" % [int(u.hp), int(u.max_hp)]
	var path := _portrait_for(u)
	if path != "" and ResourceLoader.exists(path):
		portrait.texture = load(path)
	else:
		portrait.texture = null


func _portrait_for(u) -> String:
	var uid := String(u.unit_id)
	match u.tier_label:
		"MC":
			return "res://Assets/Character Inspect/Juan.jpg"
		"B1":
			var n := 1
			if uid.find("_") != -1:
				n = clampi(int(uid.split("_")[-1]), 1, 3)
			return "res://Assets/Campaign/Bellarosa Syndicate/Unit/Unit B1/Unit %d.jpg" % n
		_:
			return ""
