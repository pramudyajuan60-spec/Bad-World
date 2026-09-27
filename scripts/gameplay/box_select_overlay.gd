extends Node2D
## Drag-selection rectangle, drawn in world space (as a sibling of the
## units it selects) so it naturally follows camera pan/zoom without any
## manual screen<->world conversion.

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _active: bool = false


func update_box(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	_active = true
	queue_redraw()


func hide_box() -> void:
	_active = false
	queue_redraw()


func current_rect() -> Rect2:
	return Rect2(_from, _to - _from).abs()


func _draw() -> void:
	if not _active:
		return
	var r := current_rect()
	draw_rect(r, Color(0.3, 0.9, 0.4, 0.15), true)
	draw_rect(r, Color(0.3, 0.9, 0.4, 0.9), false, 1.5)
