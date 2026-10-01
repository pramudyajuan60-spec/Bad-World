extends SceneTree
## Headless tests for MVP3 vehicles: seat capacity is really enforced,
## enter/exit works, a moving turret takes an accuracy penalty vs. a
## stationary one, and repair restores HP for a real cost. Run with:
##   godot4 --headless --path . --script res://tests/test_mvp3_vehicle.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const VEHICLE_SCENE := preload("res://scenes/gameplay/Vehicle.tscn")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_unit(id: String, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.tier_label = "B1"
	u.faction_side = &"player"
	u.max_hp = 100.0
	u.move_speed_px = 0.0
	u.position = pos
	_world.add_child(u)
	return u


func _make_vehicle(data_path: String, pos: Vector2) -> Vehicle:
	var v: Vehicle = VEHICLE_SCENE.instantiate()
	v.vehicle_data = load(data_path)
	v.faction_side = &"player"
	v.position = pos
	_world.add_child(v)
	return v


func _run() -> void:
	await _test_seat_capacity_enforced()
	await _test_enter_exit_hides_and_restores_unit()
	await _test_moving_turret_accuracy_penalty()
	await _test_repair_restores_hp_for_cost()
	_finish()


func _test_seat_capacity_enforced() -> void:
	var v := _make_vehicle("res://data/vehicles/compact.tres", Vector2.ZERO) # 4 seats
	await process_frame
	var entered_count := 0
	var units: Array = []
	for i in range(5): # one more than the compact's 4 seats
		var u := _make_unit("seat_u_%d" % i, Vector2.ZERO)
		units.append(u)
		if v.enter(u):
			entered_count += 1
	_expect(entered_count == 4, "a 4-seat compact should accept exactly 4 units, accepted %d" % entered_count)
	_expect(v.seats.size() == 4, "vehicle.seats should report exactly 4 occupants")
	_expect(not v.has_free_seat(), "a full vehicle should report no free seat")

	for u in units:
		u.queue_free()
	v.queue_free()
	await process_frame


func _test_enter_exit_hides_and_restores_unit() -> void:
	var v := _make_vehicle("res://data/vehicles/compact.tres", Vector2(500, 500))
	var u := _make_unit("mount_u", Vector2(500, 500))
	await process_frame
	var ok: bool = v.enter(u)
	_expect(ok, "entering an empty vehicle with a free seat should succeed")
	_expect(u.mounted_vehicle == v, "unit.mounted_vehicle should point at the vehicle it entered")
	_expect(u.is_driver, "the first unit to enter an empty vehicle should become the driver")
	_expect(not u.visible, "a mounted unit should be hidden")
	_expect(v.driver == u, "vehicle.driver should be set to the entering unit")

	v.exit_unit(u)
	_expect(u.mounted_vehicle == null, "exiting should clear mounted_vehicle")
	_expect(u.visible, "an exited unit should become visible again")
	_expect(v.driver == null, "the vehicle should have no driver once its only occupant exits")

	u.queue_free()
	v.queue_free()
	await process_frame


func _test_moving_turret_accuracy_penalty() -> void:
	var v := _make_vehicle("res://data/vehicles/gun_truck.tres", Vector2.ZERO) # has_turret = true
	var gunner := _make_unit("gunner", Vector2.ZERO)
	await process_frame
	v.enter(gunner)
	var target := _make_unit("turret_target", Vector2(100, 0))
	target.faction_side = &"enemy_dummy"
	target.max_hp = 100000.0 # keep it alive across many shots
	await physics_frame

	# Stationary: fire for a while and record damage dealt.
	v.velocity = Vector2.ZERO
	var hp_start_stationary: float = target.hp
	for i in range(120): # ~2s
		v._process_turret(1.0 / 60.0)
	var stationary_damage: float = hp_start_stationary - target.hp
	_expect(stationary_damage > 0.0, "a stationary armed turret in range should deal some damage over 2s")

	# Moving: same duration, but force velocity to simulate driving.
	target.hp = hp_start_stationary
	v._turret_target = null
	var hp_start_moving: float = target.hp
	for i in range(120):
		v.velocity = Vector2(50, 0) # non-zero every tick, forcing the moving-penalty branch
		v._process_turret(1.0 / 60.0)
	var moving_damage: float = hp_start_moving - target.hp

	_expect(moving_damage < stationary_damage, "a moving turret should deal less damage than a stationary one over the same duration (moving=%.1f, stationary=%.1f)" % [moving_damage, stationary_damage])

	gunner.queue_free()
	target.queue_free()
	v.queue_free()
	await process_frame


func _test_repair_restores_hp_for_cost() -> void:
	var v := _make_vehicle("res://data/vehicles/armored_suv.tres", Vector2.ZERO)
	await process_frame
	v.take_damage(50.0)
	_expect(v.hp < v.max_hp, "setup: vehicle should be damaged")
	var cost: int = v.repair_cost()
	_expect(cost > 0, "a damaged vehicle should report a positive repair cost")
	v.repair_full()
	_expect(is_equal_approx(v.hp, v.max_hp), "repair_full should restore HP to max")

	v.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp3_vehicle: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
