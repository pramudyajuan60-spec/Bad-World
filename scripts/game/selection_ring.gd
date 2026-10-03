extends Node2D
## Draws the selection ring under a selected unit.

var ring_color: Color = Color(0.35, 1.0, 0.45, 0.95)


func _ready() -> void:
	var parent_unit := get_parent()
	if parent_unit and parent_unit.get("is_enemy"):
		ring_color = Color(1.0, 0.35, 0.3, 0.95)


func _draw() -> void:
	var parent_unit := get_parent()
	var col: Color = ring_color
	if parent_unit and parent_unit.get("defend_mode"):
		col = Color(0.4, 0.7, 1.0, 0.95)  # blue ring = defending
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 28, col, 2.5)
	if parent_unit and parent_unit.get("defend_mode"):
		# small shield tick marks
		for i in 4:
			var a: float = TAU * i / 4.0
			var p1 := Vector2(cos(a), sin(a)) * 24.0
			var p2 := Vector2(cos(a), sin(a)) * 28.0
			draw_line(p1, p2, col, 3.0)
