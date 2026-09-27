extends Control

@onready var list: VBoxContainer = $VBox
@onready var back_btn: Button = $BackButton

const ORDER: Array[StringName] = [&"difficulty_easy", &"difficulty_medium", &"difficulty_hard"]


func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/CampaignSelect.tscn"))
	for id in ORDER:
		var d = CampaignDatabase.get_difficulty(id)
		if d == null:
			continue
		var btn := Button.new()
		btn.text = d.display_name
		btn.custom_minimum_size = Vector2(300, 44)
		btn.pressed.connect(_select.bind(d))
		list.add_child(btn)


func _select(d) -> void:
	GameState.current_difficulty_id = d.id
	get_tree().change_scene_to_file("res://scenes/ui/StoryPanel.tscn")
