extends Node2D
## PLACEHOLDER visual (see docs/PLACEHOLDER_REGISTER.md): a drawn ring
## stands in for a proper selection-ring sprite/shader until real UI art
## exists (MVP 6).

@export var radius: float = 20.0
@export var ring_color: Color = Color(0.25, 0.95, 0.35, 0.9)


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, ring_color, 2.0, true)
