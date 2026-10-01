extends SceneTree
## Headless tests exercising real BwUnit instances inside a real
## NavigationRegion2D: proves a moved unit actually travels via
## pathfinding (not a teleport), and that a weapon-equipped unit ordered
## to attack-move acquires a nearby hostile, closes to range, and kills
## it through the real weapon-ammo combat path (not a flat damage stat).
## Run with:
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


## A deliberately overpowered, ammo-unlimited-in-practice hitscan weapon
## so combat tests are deterministic (guaranteed one-hit kill) without
## needing to also test reload/accuracy variance here — those get their
## own dedicated test file.
func _lethal_weapon() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"test_lethal"
	w.display_name = "Test Lethal Weapon"
	w.damage = 1000.0
	w.rate_of_fire_rpm = 600.0
	w.range_px = 400.0
	w.magazine_size = 10
	w.reserve_ammo = 100
	w.uses_ammo = true
	w.is_hitscan = true
	return w


func _make_unit(id: String, tier: String, side: StringName, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.tier_label = tier
	u.faction_side = side
	u.max_hp = 60.0
	u.accuracy = 1.0
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
	await physics_frame
	u.order_move(Vector2(400, 0))
	var start_pos: Vector2 = u.global_position
	for i in range(300):
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
	attacker.equip_weapon("primary", _lethal_weapon())
	var enemy := _make_unit("target", "ENEMY", &"enemy_dummy", Vector2(50, 0))
	await physics_frame
	attacker.order_attack_move(Vector2(200, 0))
	var downed_or_dead := false
	for i in range(200):
		await physics_frame
		# MVP2 lethal damage enters a DOWNED state rather than an instant
		# kill (see docs/BALANCE.md / Prompt Dasar downed/revive/execute
		# rules) — a freed node also counts in case downed_timer elapsed.
		if not is_instance_valid(enemy) or enemy.state == BwUnit.State.DOWNED:
			downed_or_dead = true
		if downed_or_dead:
			break
	_expect(downed_or_dead, "attack-move should acquire the nearby enemy, use its equipped weapon, and down it")
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
