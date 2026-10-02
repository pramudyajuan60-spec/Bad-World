extends Node2D
## Expanding/fading destination marker shown on move/attack orders.

var _color: Color = Color(0.4, 1.0, 0.4)
var _t: float = 0.0


func setup(color: Color) -> void:
	_color = color
	var tw := create_tween()
	tw.tween_property(self, "_t", 1.0, 0.6)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := 6.0 + _t * 22.0
	var c := _color
	c.a = 1.0 - _t
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, c, 3.0)
	draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 24, c, 2.0)
