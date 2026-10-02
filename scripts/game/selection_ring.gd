extends Node2D
## Draws the selection ring under a selected unit.

var ring_color: Color = Color(0.35, 1.0, 0.45, 0.95)


func _ready() -> void:
	var parent_unit := get_parent()
	if parent_unit and parent_unit.get("is_enemy"):
		ring_color = Color(1.0, 0.35, 0.3, 0.95)


func _draw() -> void:
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 28, ring_color, 2.5)
