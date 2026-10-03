extends Control
## MVP 6b: Simple minimap. Draws dots for units, buildings, camera view.
## Click to move camera.

var game: Node = null
const MAP_BOUNDS := Rect2(-1600, -1200, 3200, 2400)

func _ready() -> void:
	custom_minimum_size = Vector2(180, 135)
	mouse_filter = MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and game != null:
			var world := _to_world(mb.position)
			game._camera.global_position = world

func _to_world(mini_pos: Vector2) -> Vector2:
	var uv := mini_pos / size
	return Vector2(
		MAP_BOUNDS.position.x + uv.x * MAP_BOUNDS.size.x,
		MAP_BOUNDS.position.y + uv.y * MAP_BOUNDS.size.y)

func _to_mini(world: Vector2) -> Vector2:
	var uv := Vector2(
		(world.x - MAP_BOUNDS.position.x) / MAP_BOUNDS.size.x,
		(world.y - MAP_BOUNDS.position.y) / MAP_BOUNDS.size.y)
	return uv * size

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.08, 0.85))
	if game == null:
		return
	# Buildings
	for f in game.get_tree().get_nodes_in_group("factories"):
		var pos := _to_mini((f as Node2D).global_position)
		draw_circle(pos, 3.0, Color(0.8, 0.6, 0.2))
	for d in game.get_tree().get_nodes_in_group("dealers"):
		var pos := _to_mini((d as Node2D).global_position)
		draw_circle(pos, 2.0, Color(0.8, 0.3, 0.8))
	# Units
	for u in game._units:
		if u.state == 4:  # DEAD
			continue
		if u.is_enemy and not u.visible:
			continue  # fog of war
		var pos := _to_mini(u.global_position)
		var col := Color(0.3, 1, 0.3) if not u.is_enemy else Color(1, 0.3, 0.3)
		draw_circle(pos, 2.0, col)
	# Vehicles
	for v in game._vehicles:
		var pos := _to_mini(v.global_position)
		draw_circle(pos, 3.0, Color(0.4, 0.6, 1.0))
	# Camera view rect
	var cam: Node2D = game._camera
	if cam != null:
		var vp: Vector2 = get_viewport_rect().size
		var zoom: float = (cam as Camera2D).zoom.x
		var view_size: Vector2 = vp / zoom
		var tl := _to_mini(cam.global_position - view_size / 2)
		var br := _to_mini(cam.global_position + view_size / 2)
		draw_rect(Rect2(tl, br - tl), Color(1, 1, 1, 0.5), false, 1.0)
