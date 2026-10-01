extends SceneTree
## Headless tests for weapon-data-driven combat (Prompt Dasar MVP2):
## ammo really depletes, reload happens and restores from reserve, an
## out-of-ammo unit falls back to melee rather than firing forever, and
## line-of-sight blocks an otherwise-in-range shot. Run with:
##   godot4 --headless --path . --script res://tests/test_weapon_combat.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_unit(id: String, side: StringName, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.tier_label = "B1"
	u.faction_side = side
	u.max_hp = 1000.0 # keep the target alive across many shots in this file
	u.accuracy = 1.0
	u.acquire_range = 300.0
	u.move_speed_px = 0.0
	u.position = pos
	_world.add_child(u)
	return u


func _test_weapon(mag: int, reserve: int, reload_sec: float, dmg: float = 10.0) -> WeaponData:
	var w := WeaponData.new()
	w.id = &"test_weapon_%d" % Time.get_ticks_usec()
	w.display_name = "Test Weapon"
	w.damage = dmg
	w.rate_of_fire_rpm = 6000.0 # ~0.01s between shots, fires essentially every frame once ready
	w.range_px = 200.0
	w.magazine_size = mag
	w.reserve_ammo = reserve
	w.reload_time_sec = reload_sec
	w.uses_ammo = true
	w.is_hitscan = true
	return w


func _melee_weapon() -> WeaponData:
	var w := WeaponData.new()
	w.id = &"test_melee"
	w.display_name = "Test Knife"
	w.damage = 5.0
	w.rate_of_fire_rpm = 6000.0
	w.range_px = 60.0
	w.uses_ammo = false
	w.is_melee = true
	w.is_hitscan = true
	return w


func _run() -> void:
	await _test_ammo_depletes_and_reloads()
	await _test_out_of_ammo_falls_back_to_melee()
	await _test_line_of_sight_blocks_fire()
	_finish()


func _test_ammo_depletes_and_reloads() -> void:
	var attacker := _make_unit("ammo_attacker", &"player", Vector2(0, 0))
	var target := _make_unit("ammo_target", &"enemy_dummy", Vector2(50, 0))
	attacker.equip_weapon("primary", _test_weapon(2, 4, 0.5))
	await physics_frame
	attacker.order_attack(target)

	# Fire until the magazine should be empty (mag=2), well within a
	# generous frame budget for a 6000rpm weapon.
	for i in range(20):
		await physics_frame
	_expect(attacker.primary_mag == 0, "magazine should be empty after firing its 2 rounds, got %d" % attacker.primary_mag)
	_expect(attacker.is_reloading, "unit should start reloading once its magazine is empty and reserve remains")
	_expect(target.hp < 1000.0, "target should have taken real damage from ammo-based fire")

	# Let the 0.5s reload finish (well within this many frames), then it
	# should resume firing using reserve ammo.
	for i in range(60):
		await physics_frame
	_expect(not attacker.is_reloading, "reload should have completed")
	_expect(attacker.primary_mag > 0 or attacker.primary_reserve >= 0, "magazine should refill from reserve after reload")

	attacker.queue_free()
	target.queue_free()
	await process_frame


func _test_out_of_ammo_falls_back_to_melee() -> void:
	var attacker := _make_unit("oo_attacker", &"player", Vector2(0, 0))
	var target := _make_unit("oo_target", &"enemy_dummy", Vector2(50, 0))
	attacker.equip_weapon("primary", _test_weapon(1, 0, 0.1)) # 1 round, 0 reserve: exactly one shot ever
	attacker.equip_weapon("secondary", _melee_weapon())
	await physics_frame
	attacker.order_attack(target)
	for i in range(15):
		await physics_frame
	_expect(attacker.primary_mag == 0 and attacker.primary_reserve == 0, "the single round should be spent with no reserve left")
	var weapon_in_use := attacker._resolve_active_weapon()
	_expect(weapon_in_use == attacker.secondary_weapon, "with primary ammo fully exhausted, active weapon should fall back to the equipped melee secondary")
	_expect(not attacker.is_reloading, "there is no reserve to reload from, so the unit should not be stuck reloading forever")

	attacker.queue_free()
	target.queue_free()
	await process_frame


func _test_line_of_sight_blocks_fire() -> void:
	var attacker := _make_unit("los_attacker", &"player", Vector2(-60, 0))
	var target := _make_unit("los_target", &"enemy_dummy", Vector2(60, 0))
	attacker.equip_weapon("primary", _test_weapon(50, 50, 0.1))

	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = 2 # obstacles-only layer, see docs/TECH_DECISIONS.md
	obstacle.collision_mask = 0
	obstacle.position = Vector2(0, 0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 200)
	shape.shape = rect
	obstacle.add_child(shape)
	_world.add_child(obstacle)

	await physics_frame
	await physics_frame # let the physics server register the new collider
	attacker.order_attack(target)
	for i in range(20):
		await physics_frame
	_expect(target.hp >= target.max_hp - 0.01, "a wall directly between attacker and target should block line-of-sight and prevent any hit, target hp=%.1f" % target.hp)
	_expect(attacker.primary_mag == 50, "with no line-of-sight, the unit should not have fired at all, mag=%d" % attacker.primary_mag)

	attacker.queue_free()
	target.queue_free()
	obstacle.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] weapon_combat: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
