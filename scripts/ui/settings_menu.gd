extends Control
## MVP 1 placeholder settings screen. Full audio/video/key-rebinding
## settings are MVP 6 scope; this screen exists (rather than a dead
## "Settings" button) and clearly says what is not implemented yet.

@onready var back_btn: Button = $VBox/BackButton


func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
