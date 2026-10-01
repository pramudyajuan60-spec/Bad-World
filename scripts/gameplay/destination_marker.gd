extends Node2D
## PLACEHOLDER move-order marker (drawn X-in-circle). Auto-frees itself
## shortly after appearing. See docs/PLACEHOLDER_REGISTER.md.

@export var lifetime_sec: float = 0.9


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = lifetime_sec
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(queue_free)
	timer.start()


func _draw() -> void:
	var col := Color(0.95, 0.9, 0.2, 0.9)
	draw_arc(Vector2.ZERO, 10.0, 0, TAU, 20, col, 2.0, true)
	draw_line(Vector2(-6, -6), Vector2(6, 6), col, 2.0)
	draw_line(Vector2(-6, 6), Vector2(6, -6), col, 2.0)
