extends Control
## Campaign selection: shows all four campaigns, only Juan playable in MVP 1.

@onready var _list: VBoxContainer = $Center/VBox/List


func _ready() -> void:
	$Center/VBox/Back.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	var db := get_node("/root/CampaignDatabase")
	var campaigns: Array = db.get_all_campaigns()
	campaigns.sort_custom(func(a, b): return String(a.id) < String(b.id))
	for c in campaigns:
		var btn := Button.new()
		var playable: bool = String(c.id) == "campaign_juan"
		btn.text = "%s — %s%s" % [c.menu_name, c.main_character_name,
			"" if playable else "  (locked — MVP 1)"]
		btn.disabled = not playable
		btn.custom_minimum_size = Vector2(420, 48)
		if playable:
			btn.pressed.connect(_on_pick.bind(c))
		_list.add_child(btn)


func _on_pick(campaign) -> void:
	GameState.pending_campaign = campaign.id
	get_tree().change_scene_to_file("res://scenes/ui/DifficultySelect.tscn")
