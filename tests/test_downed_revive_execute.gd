extends SceneTree
## Headless tests for downed/revive/execution (Prompt Dasar base rules +
## MVP2): a unit reduced to 0 HP is downed rather than instantly dead;
## an ally can revive it; a hostile unit can execute it via the explicit
## 6-second channel, which is cancelable if the executor takes damage
## mid-channel. Run with:
##   godot4 --headless --path . --script res://tests/test_downed_revive_execute.gd

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
	u.max_hp = 100.0
	u.move_speed_px = 300.0
	u.position = pos
	_world.add_child(u)
	return u


func _run() -> void:
	await _test_lethal_damage_downs_not_kills()
	await _test_revive_restores_ally()
	await _test_execution_channel_and_cancel()
	await _test_downed_timer_expiry_is_permadeath()
	_finish()


func _test_lethal_damage_downs_not_kills() -> void:
	var u := _make_unit("d1", &"player", Vector2.ZERO)
	await physics_frame
	u.take_damage(1000.0)
	await physics_frame
	_expect(u.state == BwUnit.State.DOWNED, "lethal damage should down a unit rather than free it instantly")
	_expect(is_instance_valid(u), "a downed unit should still exist in the tree")
	_expect(u.downed_timer > 0.0, "a freshly-downed unit should have a positive downed timer")
	u.queue_free()
	await process_frame


func _test_revive_restores_ally() -> void:
	# Placed within REVIVE_RANGE from the start: this test world has no
	# NavigationRegion2D (pathfinding-to-cover is covered separately in
	# test_combat_and_navigation.gd), so the reviver must already be in
	# range or it can never close the distance to begin the channel.
	var downed_unit := _make_unit("d2", &"player", Vector2(30, 0))
	var reviver := _make_unit("reviver", &"player", Vector2(0, 0))
	await physics_frame
	downed_unit.take_damage(1000.0)
	await physics_frame
	_expect(downed_unit.state == BwUnit.State.DOWNED, "setup: unit must be downed before reviving")

	reviver.order_revive(downed_unit)
	var revived := false
	for i in range(400): # generous margin over travel + REVIVE_CHANNEL_SEC
		await physics_frame
		if downed_unit.state == BwUnit.State.IDLE:
			revived = true
			break
	_expect(revived, "an ally channeling revive on a downed unit should eventually restore it to IDLE")
	if revived:
		_expect(downed_unit.hp > 0.0 and downed_unit.hp < downed_unit.max_hp, "revived unit should return with partial HP, not full or zero (hp=%.1f/%.1f)" % [downed_unit.hp, downed_unit.max_hp])

	downed_unit.queue_free()
	reviver.queue_free()
	await process_frame


func _test_execution_channel_and_cancel() -> void:
	# Part A: an uninterrupted execution succeeds and permanently kills.
	var victim := _make_unit("victim", &"enemy_dummy", Vector2(30, 0))
	var executor := _make_unit("executor", &"player", Vector2(0, 0))
	await physics_frame
	victim.take_damage(1000.0)
	await physics_frame
	executor.order_execute(victim)
	var executed := false
	for i in range(500): # generous margin over travel + the explicit 6s EXECUTE_CHANNEL_SEC
		await physics_frame
		if not is_instance_valid(victim):
			executed = true
			break
	_expect(executed, "an uninterrupted 6s execution channel should permanently kill the downed target")
	executor.queue_free()
	await process_frame

	# Part B: damaging the executor mid-channel cancels the execution,
	# leaving the target downed (not executed).
	var victim2 := _make_unit("victim2", &"enemy_dummy", Vector2(30, 0))
	var executor2 := _make_unit("executor2", &"player", Vector2(0, 0))
	await physics_frame
	victim2.take_damage(1000.0)
	await physics_frame
	executor2.order_execute(victim2)
	for i in range(30): # let the channel actually begin before interrupting it
		await physics_frame
	_expect(executor2.state == BwUnit.State.EXECUTING, "setup: executor should be mid-channel before we interrupt it")
	executor2.take_damage(5.0) # any damage should cancel a channeled action
	await physics_frame
	_expect(executor2.state == BwUnit.State.IDLE, "taking damage mid-execution should cancel the channel (rule: execution 'dapat dihentikan')")
	_expect(is_instance_valid(victim2) and victim2.state == BwUnit.State.DOWNED, "a canceled execution should leave the target downed, not dead")

	victim2.queue_free()
	executor2.queue_free()
	await process_frame


func _test_downed_timer_expiry_is_permadeath() -> void:
	var u := _make_unit("expire", &"enemy_dummy", Vector2.ZERO)
	await physics_frame
	u.take_damage(1000.0)
	await physics_frame
	_expect(u.state == BwUnit.State.DOWNED, "setup: unit must be downed first")
	u.downed_timer = 0.05 # force a fast expiry instead of waiting the full 30s
	var died := false
	for i in range(30):
		await physics_frame
		if not is_instance_valid(u):
			died = true
			break
	_expect(died, "a downed unit whose timer reaches zero without being revived/executed should permanently die")


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] downed_revive_execute: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
