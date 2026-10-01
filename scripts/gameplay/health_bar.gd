extends Node2D
## PLACEHOLDER visual: drawn bars stand in for a themed health-bar sprite
## until real UI art exists (MVP 6). See docs/PLACEHOLDER_REGISTER.md.

@export var bar_width: float = 32.0
@export var bar_height: float = 5.0

var ratio: float = 1.0


func set_ratio(r: float) -> void:
	ratio = clampf(r, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var bg_rect := Rect2(-bar_width * 0.5, 0.0, bar_width, bar_height)
	draw_rect(bg_rect, Color(0.12, 0.12, 0.12, 0.85))
	var fill_color := Color(0.2, 0.8, 0.2)
	if ratio <= 0.25:
		fill_color = Color(0.85, 0.2, 0.2)
	elif ratio <= 0.5:
		fill_color = Color(0.9, 0.7, 0.1)
	var fill_rect := Rect2(-bar_width * 0.5, 0.0, bar_width * ratio, bar_height)
	draw_rect(fill_rect, fill_color)
