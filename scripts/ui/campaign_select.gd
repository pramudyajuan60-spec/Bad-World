extends Control
## Shows all 4 campaigns (Prompt Dasar MVP 1: "Campaign selection
## menampilkan empat campaign"). All four are playable as of MVP4
## ("Aktifkan seluruh campaign").

@onready var list: VBoxContainer = $VBox
@onready var back_btn: Button = $BackButton


func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	var campaigns: Array = CampaignDatabase.get_all_campaigns()
	campaigns.sort_custom(func(a, b): return String(a.id) < String(b.id))
	for c in campaigns:
		var btn := Button.new()
		btn.text = "%s — %s" % [c.menu_name, c.main_character_name]
		btn.custom_minimum_size = Vector2(460, 44)
		btn.pressed.connect(_select.bind(c))
		list.add_child(btn)


func _select(c) -> void:
	GameState.current_campaign_id = c.id
	get_tree().change_scene_to_file("res://scenes/ui/DifficultySelect.tscn")
