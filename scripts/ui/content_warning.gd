extends Control
## Content warning shown once per app launch, before the Main Menu
## (Prompt Dasar MVP6 item 21: "Content warning yang sesuai untuk tema
## kekerasan/kriminal"). BAD WORLD's whole premise is organized crime
## (cartels, a DEA campaign, executions, recruitment of downed
## enemies) so this names those themes plainly rather than a generic
## disclaimer.

@onready var continue_btn: Button = $VBox/ContinueButton


func _ready() -> void:
	continue_btn.grab_focus()
	continue_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
