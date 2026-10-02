extends Control
## Juan Bellarosa story/profile panel using repository assets.
## Shows portrait, main character art, and the Story.txt text.

@onready var _portrait: TextureRect = $Center/Panel/HBox/Portrait
@onready var _name: Label = $Center/Panel/HBox/Right/Name
@onready var _faction: Label = $Center/Panel/HBox/Right/Faction
@onready var _story: RichTextLabel = $Center/Panel/HBox/Right/Story


func _ready() -> void:
	$Center/Panel/HBox/Right/Buttons/Deploy.pressed.connect(_on_deploy)
	$Center/Panel/HBox/Right/Buttons/Back.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/ui/DifficultySelect.tscn"))
	var db := get_node("/root/CampaignDatabase")
	var c = db.get_campaign(GameState.pending_campaign)
	if c == null:
		c = db.get_campaign(&"campaign_juan")
	_name.text = c.main_character_name
	_faction.text = c.faction.display_name if c.faction else ""
	if ResourceLoader.exists(c.portrait_path):
		_portrait.texture = load(c.portrait_path)
	_story.text = _read_story(c.story_path)


func _read_story(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "(Story file not found: %s)" % path
	var f := FileAccess.open(path, FileAccess.READ)
	var t: String = f.get_as_text()
	f.close()
	return t.strip_edges()


func _on_deploy() -> void:
	GameState.load_on_start = false
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
