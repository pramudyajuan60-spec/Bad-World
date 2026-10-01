extends CanvasLayer
## Victory/Defeat/campaign-summary overlay (Prompt Dasar MVP6 item 20:
## "Victory, defeat, restart, dan campaign summary"). One reusable
## screen for both outcomes, since they share the same shape (title +
## stat summary + Restart/Load/Quit) and Prompt Dasar's own VICTORY DAN
## DEFEAT section describes both as ending the mission the same way.
##
## process_mode ALWAYS (set on the scene) so its buttons work while
## get_tree().paused == true, same pattern as PauseMenu.

signal restart_requested
signal load_requested
signal quit_to_menu_requested

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var restart_btn: Button = $Panel/VBox/ButtonRow/RestartButton
@onready var load_btn: Button = $Panel/VBox/ButtonRow/LoadButton
@onready var quit_btn: Button = $Panel/VBox/ButtonRow/QuitButton


func _ready() -> void:
	visible = false
	restart_btn.pressed.connect(func(): restart_requested.emit())
	load_btn.pressed.connect(func(): load_requested.emit())
	quit_btn.pressed.connect(func(): quit_to_menu_requested.emit())


## `is_victory` picks the title/color; `reason` is the one-line cause
## (e.g. "Zie Vartieri was executed." / "All rival Main Characters have
## been eliminated."); `stats_text` is the pre-formatted campaign
## summary body (play time, money earned, roster, enemies eliminated).
func show_result(is_victory: bool, reason: String, stats_text: String) -> void:
	title_label.text = "VICTORY" if is_victory else "DEFEAT"
	title_label.modulate = Color(0.3, 0.9, 0.4) if is_victory else Color(0.9, 0.25, 0.25)
	subtitle_label.text = reason
	stats_label.text = stats_text
	load_btn.disabled = SaveService.most_recent_slot() == -1
	visible = true
	get_tree().paused = true
