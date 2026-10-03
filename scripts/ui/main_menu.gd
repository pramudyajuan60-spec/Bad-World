extends Control
## MVP 1 main menu: Start, Continue, Settings, Exit.

@onready var _start_btn: Button = $Center/VBox/Start
@onready var _continue_btn: Button = $Center/VBox/Continue


func _ready() -> void:
	_start_btn.pressed.connect(_on_start)
	_continue_btn.pressed.connect(_on_continue)
	$Center/VBox/Settings.pressed.connect(_on_settings)
	$Center/VBox/Exit.pressed.connect(_on_exit)
	_continue_btn.disabled = not SaveSystem.has_save("quicksave")
	$Title.text = "BAD WORLD"
	# MVP 6c: content warning on first launch.
	if not FileAccess.file_exists("user://warning_seen"):
		$ContentWarning.visible = true


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CampaignSelect.tscn")


func _on_continue() -> void:
	# jump straight into Juan's slice and load the quicksave
	GameState.pending_campaign = &"campaign_juan"
	GameState.pending_difficulty = &"medium"
	GameState.load_on_start = true
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")


func _on_settings() -> void:
	$Center/VBox/Settings.release_focus()


func _on_exit() -> void:
	get_tree().quit()


func _on_warning_ack() -> void:
	var f := FileAccess.open("user://warning_seen", FileAccess.WRITE)
	f.store_string("1")
	f.close()
	$ContentWarning.visible = false
