extends Node2D
## MVP 1 vertical-slice gameplay scene: one isometric-composition test map
## for Campaign Juan (Prompt Dasar Part 3, MVP 1). Spawns Juan + 3 B1 vs a
## dummy enemy squad, wires camera/selection/commands, and handles
## pause/restart/save/load.
##
## Map geometry is a simple open rectangle with a handful of rectangular
## obstacles loosely arranged (open central lane, structures at the
## edges) taking inspiration from the general composition of
## "Assets/Campaign/Bellarosa Syndicate/Maps/Juan Maps (Mafia).jpg" (shown
## as a non-collidable background), not a pixel-accurate reproduction of
## it — concept art is not collision-ready data (Prompt Dasar rule 8).

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const DEST_MARKER_SCENE := preload("res://scenes/gameplay/DestinationMarker.tscn")

const MAP_BOUNDS := Rect2(-1500, -1000, 3000, 2000)
const OBSTACLE_RECTS := [
	Rect2(-260, -420, 220, 140),
	Rect2(180, -380, 260, 160),
	Rect2(-520, 120, 200, 220),
	Rect2(260, 200, 240, 180),
	Rect2(-70, -60, 160, 120),
]

@onready var background: Sprite2D = $Background
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var obstacles_root: Node2D = $Obstacles
@onready var units_root: Node2D = $Units
@onready var enemies_root: Node2D = $Enemies
@onready var box_overlay: Node2D = $BoxSelectOverlay
@onready var camera: RtsCamera = $RtsCamera
@onready var selection_manager: SelectionManager = $SelectionManager
@onready var command_controller = $CommandController
@onready var hud = $HUD/SelectionHud
@onready var pause_menu = $PauseMenu


func _ready() -> void:
	_build_background()
	_build_navigation()
	_build_obstacles()
	camera.bounds = MAP_BOUNDS

	command_controller.selection_manager = selection_manager
	command_controller.camera = camera
	command_controller.overlay = box_overlay
	command_controller.markers_parent = self
	command_controller.destination_marker_scene = DEST_MARKER_SCENE
	command_controller.pause_requested.connect(_toggle_pause)

	selection_manager.selection_updated.connect(_on_selection_updated)

	pause_menu.visible = false
	pause_menu.resume_requested.connect(_toggle_pause)
	pause_menu.restart_requested.connect(_on_restart)
	pause_menu.save_requested.connect(_on_save)
	pause_menu.load_requested.connect(_on_load)
	pause_menu.quit_to_menu_requested.connect(_on_quit_to_menu)

	var slot := GameState.pending_load_slot
	GameState.pending_load_slot = -1
	if slot >= 1 and SaveService.has_save(slot):
		_load_from_slot(slot)
	else:
		_spawn_fresh()

	_refresh_enemy_units_cache()


func _build_background() -> void:
	var path := "res://Assets/Campaign/Bellarosa Syndicate/Maps/Juan Maps (Mafia).jpg"
	if ResourceLoader.exists(path):
		background.texture = load(path)
		background.centered = true
		var tex_size: Vector2 = background.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var scale_factor: float = max(MAP_BOUNDS.size.x / tex_size.x, MAP_BOUNDS.size.y / tex_size.y)
			background.scale = Vector2(scale_factor, scale_factor)
		background.modulate = Color(1, 1, 1, 0.55)
		background.z_index = -100


func _build_navigation() -> void:
	var poly := NavigationPolygon.new()
	var outline := PackedVector2Array([
		MAP_BOUNDS.position,
		Vector2(MAP_BOUNDS.position.x + MAP_BOUNDS.size.x, MAP_BOUNDS.position.y),
		MAP_BOUNDS.position + MAP_BOUNDS.size,
		Vector2(MAP_BOUNDS.position.x, MAP_BOUNDS.position.y + MAP_BOUNDS.size.y),
	])
	poly.add_outline(outline)
	poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = poly


func _build_obstacles() -> void:
	for rect in OBSTACLE_RECTS:
		var body := StaticBody2D.new()
		body.position = rect.position + rect.size * 0.5

		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = rect.size
		shape.shape = rect_shape
		body.add_child(shape)

		var visual := ColorRect.new()
		visual.color = Color(0.28, 0.28, 0.3)
		visual.size = rect.size
		visual.position = -rect.size * 0.5
		body.add_child(visual)

		# Simplified: approximate each rectangular obstacle as a circular
		# avoidance obstacle for NavigationAgent2D RVO. Good enough for a
		# "sederhana" (simple) MVP 1 test map; physics collision (above)
		# is the hard backstop against actually walking through it.
		var obstacle := NavigationObstacle2D.new()
		obstacle.radius = max(rect.size.x, rect.size.y) * 0.5 + 8.0
		obstacle.avoidance_enabled = true
		body.add_child(obstacle)

		obstacles_root.add_child(body)


func _spawn_fresh() -> void:
	var juan := _make_unit(&"juan", "Juan Bellarosa", "MC", &"player", true)
	juan.position = Vector2(-80, 40)
	units_root.add_child(juan)
	selection_manager.register_unit(juan)

	var b1_positions: Array = FormationUtils.compute_positions(Vector2(60, 40), 3, 40.0)
	for i in range(3):
		var b1 := _make_unit(&"b1_%d" % (i + 1), "B1", "B1", &"player", true)
		b1.position = b1_positions[i]
		units_root.add_child(b1)
		selection_manager.register_unit(b1)

	var enemy_positions: Array = FormationUtils.compute_positions(Vector2(520, -40), 4, 50.0)
	for i in range(4):
		var e := _make_unit(&"enemy_%d" % (i + 1), "Hostile (PLACEHOLDER)", "ENEMY", &"enemy_dummy", false)
		e.auto_defend = true
		e.position = enemy_positions[i]
		enemies_root.add_child(e)
		e.died.connect(_on_enemy_died.bind(e))


func _make_unit(id: StringName, name_: String, tier: String, side: StringName, movable: bool) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = id
	u.display_name = name_
	u.tier_label = tier
	u.faction_side = side
	u.can_move = movable
	match tier:
		"MC":
			u.max_hp = 130.0
			u.attack_damage = 16.0
			u.accuracy = 0.65
			u.move_speed_px = 190.0
		"B1":
			u.max_hp = 100.0
			u.attack_damage = 12.0
			u.accuracy = 0.55
			u.move_speed_px = 190.0
		_:
			u.max_hp = 90.0
			u.attack_damage = 10.0
			u.accuracy = 0.5
			u.move_speed_px = 0.0
	return u


func _on_enemy_died(_e) -> void:
	call_deferred("_refresh_enemy_units_cache")


func _refresh_enemy_units_cache() -> void:
	var list: Array = []
	for c in enemies_root.get_children():
		if c is BwUnit and is_instance_valid(c):
			list.append(c)
	command_controller.enemy_units = list


func _on_selection_updated(units: Array) -> void:
	hud.show_unit(units[0] if units.size() > 0 else null)


func _toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	get_tree().paused = pause_menu.visible


func _on_restart() -> void:
	get_tree().paused = false
	GameState.pending_load_slot = -1
	get_tree().reload_current_scene()


func _gather_save_data() -> Dictionary:
	var units_data: Array = []
	for u in units_root.get_children():
		if u is BwUnit:
			units_data.append(_serialize_unit(u))
	for u in enemies_root.get_children():
		if u is BwUnit:
			units_data.append(_serialize_unit(u))
	return {
		"campaign_id": String(GameState.current_campaign_id),
		"difficulty_id": String(GameState.current_difficulty_id),
		"units": units_data,
	}


func _serialize_unit(u: BwUnit) -> Dictionary:
	return {
		"id": String(u.unit_id),
		"tier": u.tier_label,
		"faction_side": String(u.faction_side),
		"x": u.global_position.x,
		"y": u.global_position.y,
		"hp": u.hp,
		"max_hp": u.max_hp,
	}


func _on_save() -> void:
	SaveService.save_game(1, _gather_save_data())


func _on_load() -> void:
	get_tree().paused = false
	GameState.pending_load_slot = 1
	get_tree().reload_current_scene()


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _load_from_slot(slot: int) -> void:
	var data = SaveService.load_game(slot)
	if data == null:
		_spawn_fresh()
		return
	if data.has("campaign_id"):
		GameState.current_campaign_id = StringName(String(data["campaign_id"]))
	if data.has("difficulty_id"):
		GameState.current_difficulty_id = StringName(String(data["difficulty_id"]))
	for ud in data.get("units", []):
		var tier: String = ud.get("tier", "B1")
		var side := StringName(String(ud.get("faction_side", "player")))
		var movable := side == &"player"
		var u := _make_unit(StringName(String(ud.get("id", ""))), String(ud.get("id", "")), tier, side, movable)
		u.position = Vector2(float(ud.get("x", 0.0)), float(ud.get("y", 0.0)))
		if side == &"player":
			units_root.add_child(u)
			selection_manager.register_unit(u)
		else:
			u.auto_defend = true
			enemies_root.add_child(u)
			u.died.connect(_on_enemy_died.bind(u))
		u.call_deferred("set_hp", float(ud.get("hp", u.max_hp)))


func gather_save_data_for_test() -> Dictionary:
	return _gather_save_data()
