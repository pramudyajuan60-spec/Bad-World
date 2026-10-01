extends CanvasLayer
## Pause overlay. process_mode is set to ALWAYS in the scene so its
## buttons keep working while get_tree().paused == true.

signal resume_requested
signal restart_requested
signal save_load_requested
signal settings_requested
signal quit_to_menu_requested

@onready var resume_btn: Button = $Panel/VBox/ResumeButton
@onready var restart_btn: Button = $Panel/VBox/RestartButton
@onready var save_load_btn: Button = $Panel/VBox/SaveLoadButton
@onready var settings_btn: Button = $Panel/VBox/SettingsButton
@onready var quit_btn: Button = $Panel/VBox/QuitButton


func _ready() -> void:
	resume_btn.pressed.connect(func(): resume_requested.emit())
	restart_btn.pressed.connect(func(): restart_requested.emit())
	save_load_btn.pressed.connect(func(): save_load_requested.emit())
	settings_btn.pressed.connect(func(): settings_requested.emit())
	quit_btn.pressed.connect(func(): quit_to_menu_requested.emit())
