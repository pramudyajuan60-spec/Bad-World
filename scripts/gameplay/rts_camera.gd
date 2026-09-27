class_name RtsCamera
extends Camera2D
## Fixed-angle RTS camera: pan (arrow keys + edge-scroll) and zoom, no
## rotation, clamped to the map bounds.
##
## Assumption (Prompt Dasar rule 11): the base ruleset lists both "WASD"
## camera panning and W/A/S/D-adjacent unit hotkeys (S = Stop, D = Defend,
## A = Attack-move) in the same document, which collide. This
## implementation uses arrow keys + edge-scroll for the camera (the
## ruleset explicitly allows "WASD *atau* edge-scroll", i.e. either), so
## letter keys stay free for unit commands. Documented in TECH_DECISIONS.md.

@export var pan_speed: float = 640.0
@export var edge_scroll_margin: float = 18.0
@export var zoom_min: float = 0.6
@export var zoom_max: float = 2.0
@export var zoom_step_amount: float = 0.12
@export var bounds: Rect2 = Rect2(-1500, -1000, 3000, 2000):
	set(value):
		bounds = value
		_apply_bounds()


func _ready() -> void:
	_apply_bounds()


func _apply_bounds() -> void:
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.position.x + bounds.size.x)
	limit_bottom = int(bounds.position.y + bounds.size.y)


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1

	var vp := get_viewport()
	if vp:
		var mouse_pos := vp.get_mouse_position()
		var size := vp.get_visible_rect().size
		if mouse_pos.x <= edge_scroll_margin:
			dir.x -= 1
		elif mouse_pos.x >= size.x - edge_scroll_margin:
			dir.x += 1
		if mouse_pos.y <= edge_scroll_margin:
			dir.y -= 1
		elif mouse_pos.y >= size.y - edge_scroll_margin:
			dir.y += 1

	if dir != Vector2.ZERO:
		position += dir.normalized() * pan_speed * delta * (1.0 / zoom.x)


func zoom_step(direction: int) -> void:
	var factor: float = 1.0 + zoom_step_amount * direction
	var new_zoom: Vector2 = zoom * factor
	new_zoom = new_zoom.clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
	zoom = new_zoom
