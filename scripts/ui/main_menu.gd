extends Control

@onready var start_btn: Button = $VBox/StartButton
@onready var continue_btn: Button = $VBox/ContinueButton
@onready var settings_btn: Button = $VBox/SettingsButton
@onready var exit_btn: Button = $VBox/ExitButton


func _ready() -> void:
	start_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/CampaignSelect.tscn"))
	continue_btn.disabled = SaveService.most_recent_slot() == -1
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn"))
	exit_btn.pressed.connect(func(): get_tree().quit())


func _on_continue() -> void:
	GameState.pending_load_slot = SaveService.most_recent_slot()
	get_tree().change_scene_to_file("res://scenes/gameplay/OpenWorldMap.tscn")
