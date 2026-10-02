class_name RTSCamera
extends Camera2D
## Fixed-angle RTS camera: edge pan, WASD/arrows pan, middle-drag pan,
## wheel zoom, clamped to map bounds. (MVP 1 acceptance: camera stays in map.)

@export var pan_speed: float = 700.0
@export var edge_margin: float = 24.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.12

var map_bounds: Rect2 = Rect2(-1600, -1200, 3200, 2400)

var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO


func _ready() -> void:
	make_current()
	_clamp_to_bounds()


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	# edge pan (disabled while dragging a selection box; game sets the flag)
	if not get_parent().get("selection_dragging"):
		var vp := get_viewport_rect().size
		var mp := get_viewport().get_mouse_position()
		if mp.x < edge_margin:
			move.x -= 1.0
		elif mp.x > vp.x - edge_margin:
			move.x += 1.0
		if mp.y < edge_margin:
			move.y -= 1.0
		elif mp.y > vp.y - edge_margin:
			move.y += 1.0
	if move != Vector2.ZERO:
		position += move.normalized() * pan_speed * delta / zoom.x
		_clamp_to_bounds()
	if _dragging:
		var mp := get_viewport().get_mouse_position()
		var delta_px: Vector2 = (_drag_last - mp) / zoom.x
		position += delta_px
		_drag_last = mp
		_clamp_to_bounds()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(-zoom_step)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			_drag_last = get_viewport().get_mouse_position()


func _apply_zoom(amount: float) -> void:
	var z: float = clampf(zoom.x + amount, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	_clamp_to_bounds()


func _clamp_to_bounds() -> void:
	# keep the view inside the map rect
	var vp: Vector2 = get_viewport_rect().size / zoom.x
	var half := vp * 0.5
	var min_p := map_bounds.position + half
	var max_p := map_bounds.position + map_bounds.size - half
	if min_p.x > max_p.x:
		position.x = map_bounds.get_center().x
	else:
		position.x = clampf(position.x, min_p.x, max_p.x)
	if min_p.y > max_p.y:
		position.y = map_bounds.get_center().y
	else:
		position.y = clampf(position.y, min_p.y, max_p.y)
