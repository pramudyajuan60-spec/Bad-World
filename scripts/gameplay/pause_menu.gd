extends CanvasLayer
## Pause overlay. process_mode is set to ALWAYS in the scene so its
## buttons keep working while get_tree().paused == true.

signal resume_requested
signal restart_requested
signal save_requested
signal load_requested
signal quit_to_menu_requested

@onready var resume_btn: Button = $Panel/VBox/ResumeButton
@onready var restart_btn: Button = $Panel/VBox/RestartButton
@onready var save_btn: Button = $Panel/VBox/SaveButton
@onready var load_btn: Button = $Panel/VBox/LoadButton
@onready var quit_btn: Button = $Panel/VBox/QuitButton
@onready var status_label: Label = $Panel/VBox/StatusLabel


func _ready() -> void:
	resume_btn.pressed.connect(func(): resume_requested.emit())
	restart_btn.pressed.connect(func(): restart_requested.emit())
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(func(): load_requested.emit())
	quit_btn.pressed.connect(func(): quit_to_menu_requested.emit())
	load_btn.disabled = not SaveService.has_save(1)


func _on_save_pressed() -> void:
	save_requested.emit()
	status_label.text = "Saved to slot 1."
	load_btn.disabled = not SaveService.has_save(1)
