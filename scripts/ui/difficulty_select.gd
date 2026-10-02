extends Control
## Difficulty selection, then Juan's story panel.

@onready var _list: VBoxContainer = $Center/VBox/List


func _ready() -> void:
	$Center/VBox/Back.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/ui/CampaignSelect.tscn"))
	var db := get_node("/root/CampaignDatabase")
	for d in db.get_all_difficulties():
		var btn := Button.new()
		btn.text = String(d.id).capitalize()
		btn.custom_minimum_size = Vector2(320, 48)
		btn.pressed.connect(_on_pick.bind(d))
		_list.add_child(btn)


func _on_pick(diff) -> void:
	GameState.pending_difficulty = diff.id
	get_tree().change_scene_to_file("res://scenes/ui/StoryPanel.tscn")
