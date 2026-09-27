extends Control
## Story/profile panel (Prompt Dasar MVP 1 item 4): shows the selected
## campaign's canonical Story.txt and portrait, verbatim, before gameplay.

@onready var title_label: Label = $VBox/TitleLabel
@onready var portrait: TextureRect = $VBox/HBox/Portrait
@onready var story_label: Label = $VBox/HBox/StoryScroll/StoryLabel
@onready var begin_btn: Button = $VBox/ButtonRow/BeginButton
@onready var back_btn: Button = $VBox/ButtonRow/BackButton


func _ready() -> void:
	var c = CampaignDatabase.get_campaign(GameState.current_campaign_id)
	if c == null:
		title_label.text = "(missing campaign data)"
		return
	title_label.text = "%s — %s" % [c.menu_name, c.main_character_name]
	if c.portrait_path != "" and ResourceLoader.exists(c.portrait_path):
		portrait.texture = load(c.portrait_path)
	if c.story_path != "" and FileAccess.file_exists(c.story_path):
		var f := FileAccess.open(c.story_path, FileAccess.READ)
		story_label.text = f.get_as_text() if f else "(story unavailable)"
	else:
		story_label.text = "(story unavailable)"
	begin_btn.pressed.connect(_on_begin)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/DifficultySelect.tscn"))


func _on_begin() -> void:
	GameState.pending_load_slot = -1
	get_tree().change_scene_to_file("res://scenes/gameplay/BellarosaTestMap.tscn")
