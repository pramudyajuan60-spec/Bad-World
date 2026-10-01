extends SceneTree
## Headless tests for the Heat Meter/DEA response timing (Prompt Dasar:
## "Setelah 120 detik kontak senjata berkelanjutan, panggilan DEA aktif.
## DEA tiba sekitar 60 detik kemudian", max 2 waves, spawn far from the
## player) and for the carried-cargo/cash loot-on-downed mechanic
## ("Kehilangan carrier sebelum Bank memiliki konsekuensi"). Run with:
##   godot4 --headless --path . --script res://tests/test_mvp3_heat_and_loot.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const HEAT_SCRIPT := preload("res://scripts/economy/heat_manager.gd")

var _failures: Array[String] = []
var _world: Node2D
## Bound-method targets for signal tests: GDScript inline lambdas
## capture outer locals by value (see docs/TEST_PLAN.md), so a signal
## payload must be captured via a real method on this script instance
## instead of `func(x): outer_var = x`.
var _last_loot_pos: Vector2 = Vector2(-1, -1)
var _last_loot_cargo: int = -1
var _last_loot_cash: int = -1
var _wave_count: int = 0


func _on_loot_dropped(pos: Vector2, cargo: int, cash: int) -> void:
	_last_loot_pos = pos
	_last_loot_cargo = cargo
	_last_loot_cash = cash


func _on_wave_dispatched(_n: int) -> void:
	_wave_count += 1


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_heat() -> Node:
	var h := Node.new()
	h.set_script(HEAT_SCRIPT)
	h.world_bounds = Rect2(-1000, -1000, 2000, 2000)
	_world.add_child(h)
	return h


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


func _run() -> void:
	await _test_dea_wave_dispatched_after_combat_and_travel_time()
	await _test_no_combat_decays_heat_before_threshold()
	await _test_max_two_waves_then_cooldown()
	await _test_spawn_point_is_far_from_player()
	await _test_downed_carrier_drops_loot()
	_finish()


func _test_dea_wave_dispatched_after_combat_and_travel_time() -> void:
	var heat := _make_heat()
	await process_frame
	_wave_count = 0
	heat.wave_dispatched.connect(_on_wave_dispatched)

	# 120s of continuous combat should arm the dispatch timer...
	for i in range(12):
		heat.notify_combat_tick()
		heat._process(10.0) # 12 * 10s = 120s
	_expect(_wave_count == 0, "a wave should not dispatch before the 60s travel delay elapses")

	# ...then DEA_TRAVEL_SEC (60s) more before the wave actually arrives.
	heat._process(65.0)
	_expect(_wave_count == 1, "wave 1 should dispatch once 120s combat + 60s travel have both elapsed, got %d dispatch(es)" % _wave_count)

	heat.queue_free()
	await process_frame


func _test_no_combat_decays_heat_before_threshold() -> void:
	var heat := _make_heat()
	await process_frame
	_wave_count = 0
	heat.wave_dispatched.connect(_on_wave_dispatched)

	# Only 60s of combat (half the 120s needed), then silence for longer
	# than NO_COMBAT_DECAY_SEC (30s) — heat should decay, not accumulate.
	for i in range(6):
		heat.notify_combat_tick()
		heat._process(10.0)
	heat._process(40.0) # well past the 30s no-combat decay window
	heat._process(200.0) # even with lots of time, no wave should ever come from this alone
	_expect(_wave_count == 0, "heat should decay after a no-combat gap instead of eventually dispatching on its own")

	heat.queue_free()
	await process_frame


func _test_max_two_waves_then_cooldown() -> void:
	var heat := _make_heat()
	await process_frame
	_wave_count = 0
	heat.wave_dispatched.connect(_on_wave_dispatched)

	# Drive two full combat+travel cycles back to back.
	for wave in range(2):
		for i in range(12):
			heat.notify_combat_tick()
			heat._process(10.0)
		heat._process(65.0)
	_expect(_wave_count == 2, "exactly 2 waves should have dispatched, got %d" % _wave_count)

	# A third combat+travel cycle should NOT dispatch a 3rd wave: MAX_WAVES
	# is reached and a 6-minute cooldown is in effect.
	for i in range(12):
		heat.notify_combat_tick()
		heat._process(10.0)
	heat._process(65.0)
	_expect(_wave_count == 2, "no 3rd wave should dispatch while the cluster cooldown is active, got %d" % _wave_count)

	heat.queue_free()
	await process_frame


func _test_spawn_point_is_far_from_player() -> void:
	var heat := _make_heat()
	await process_frame
	heat.player_position_getter = Callable(self, "_player_pos_stub")
	var spawn: Vector2 = heat.pick_spawn_point()
	var dist: float = spawn.distance_to(_player_pos_stub())
	_expect(dist > 500.0, "DEA spawn point should be far from the player, not on top of them (dist=%.1f)" % dist)

	heat.queue_free()
	await process_frame


func _player_pos_stub() -> Vector2:
	return Vector2.ZERO # player at the world center; every edge candidate should be far


func _test_downed_carrier_drops_loot() -> void:
	var carrier := _make_unit("loot_carrier", Vector2(10, 10))
	carrier.carried_cargo = 2
	carrier.carried_cash = 350
	carrier.loot_dropped.connect(_on_loot_dropped)
	await physics_frame
	carrier.take_damage(1000.0)
	await physics_frame

	_expect(carrier.state == BwUnit.State.DOWNED, "setup: lethal damage should down the carrier")
	_expect(_last_loot_cargo == 2, "loot_dropped should report the carrier's full cargo amount, got %d" % _last_loot_cargo)
	_expect(_last_loot_cash == 350, "loot_dropped should report the carrier's full cash amount, got %d" % _last_loot_cash)
	_expect(carrier.carried_cargo == 0 and carrier.carried_cash == 0, "the carrier should be emptied once its loot is dropped")

	carrier.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp3_heat_and_loot: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
