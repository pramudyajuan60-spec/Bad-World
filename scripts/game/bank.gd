class_name Bank
extends StaticBody2D
## MVP 3: Bank. Units deposit carried cash here -> bank balance (game.money).
## Bank area is a safe zone.

func _ready() -> void:
	add_to_group("bank")
