extends Control
## Full-screen Settings entry point reachable from the Main Menu. Hosts
## the shared SettingsPanel (volume + key rebinding); the Pause Menu
## hosts the exact same panel script as an in-mission overlay instead
## (scripts/gameplay/open_world_map.gd _build_hud_extras).

const SETTINGS_PANEL_SCRIPT := preload("res://scripts/ui/settings_panel.gd")

@onready var back_btn: Button = $VBox/BackButton
@onready var panel_host: Control = $PanelHost

var _panel: Control


func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	_panel = PanelContainer.new()
	_panel.set_script(SETTINGS_PANEL_SCRIPT)
	panel_host.add_child(_panel)
	_panel.closed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
