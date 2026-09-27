extends SceneTree
## Headless tests exercising real BwUnit instances inside a real
## NavigationRegion2D: proves attack-move target acquisition + damage +
## death works, and that a unit ordered to move actually travels through
## the navigation system (not just teleporting). Run with:
##   godot4 --headless --path . --script res://tests/test_combat_and_navigation.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	var nav_region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.add_outline(PackedVector2Array([
		Vector2(-1000, -1000), Vector2(1000, -1000),
		Vector2(1000, 1000), Vector2(-1000, 1000),
	]))
	poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = poly
	_world.add_child(nav_region)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_unit(id: String, tier: String, side: StringName, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.tier_label = tier
	u.faction_side = side
	u.max_hp = 60.0
	u.attack_damage = 100.0 # guarantee a one-hit kill for a deterministic test
	u.accuracy = 1.0
	u.attack_range = 40.0
	u.attack_interval = 0.05
	u.acquire_range = 300.0
	u.move_speed_px = 220.0
	u.position = pos
	_world.add_child(u)
	return u


func _run() -> void:
	await _test_move_navigates()
	await _test_attack_move_kills_target()
	_finish()


func _test_move_navigates() -> void:
	var u := _make_unit("mover", "B1", &"player", Vector2(-400, 0))
	# Wait one physics frame for NavigationServer2D to register the map/region.
	await physics_frame
	u.order_move(Vector2(400, 0))
	var start_pos: Vector2 = u.global_position
	for i in range(300): # ~5s of physics at 60Hz, ample margin over the ~3.6s a direct path needs
		await physics_frame
		if u.state == BwUnit.State.IDLE:
			break
	var moved: float = u.global_position.distance_to(start_pos)
	_expect(moved > 300.0, "ordered unit should travel most of the 800px distance via navigation, moved only %.1f" % moved)
	_expect(u.state == BwUnit.State.IDLE, "unit should reach IDLE state after arriving (state=%d)" % u.state)
	u.queue_free()
	await process_frame


func _test_attack_move_kills_target() -> void:
	var attacker := _make_unit("attacker", "B1", &"player", Vector2(-50, 0))
	var enemy := _make_unit("target", "ENEMY", &"enemy_dummy", Vector2(50, 0))
	await physics_frame
	attacker.order_attack_move(Vector2(200, 0))
	var died := false
	for i in range(200): # ~3.3s — RVO avoidance curves the approach path, so allow margin beyond the straight-line closing time
		await physics_frame
		# GDScript lambdas capture locals by value, not by reference, so a
		# signal-connected closure can't flip this loop's `died` flag —
		# check instance validity directly instead.
		if not is_instance_valid(enemy):
			died = true
		if died:
			break
	_expect(died, "attack-move should acquire the nearby enemy and kill it (one-hit-kill test setup)")
	if is_instance_valid(attacker):
		attacker.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] combat_and_navigation: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
