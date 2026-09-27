extends SceneTree
## Headless tests for directional cover and suppression (Prompt Dasar
## base rules + MVP2): cover reduces damage only from the blocked
## direction, not from the open flank; taking fire accumulates
## suppression which both degrades accuracy and, past a threshold,
## triggers a simple retreat. Run with:
##   godot4 --headless --path . --script res://tests/test_cover_and_suppression.gd

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
	u.max_hp = 1000.0
	u.accuracy = 0.9
	u.move_speed_px = 0.0
	u.position = pos
	_world.add_child(u)
	return u


func _run() -> void:
	await _test_cover_blocks_only_covered_direction()
	await _test_suppression_reduces_accuracy()
	await _test_suppression_triggers_retreat()
	_finish()


func _test_cover_blocks_only_covered_direction() -> void:
	# Defender stands at the origin with cover_direction = +X, meaning an
	# obstacle sits on its -X side (attacker on the -X side is "blocked";
	# an attacker on the +X open flank should not be reduced).
	var defender := _make_unit("defender", &"player", Vector2.ZERO)
	defender.in_cover = true
	defender.cover_direction = Vector2.RIGHT
	var blocked_attacker := _make_unit("blocked_attacker", &"enemy_dummy", Vector2(-100, 0))
	var open_attacker := _make_unit("open_attacker", &"enemy_dummy", Vector2(100, 0))
	await physics_frame

	defender.take_damage(100.0, blocked_attacker)
	var hp_after_blocked: float = defender.hp
	var blocked_damage: float = defender.max_hp - hp_after_blocked
	defender.hp = defender.max_hp # reset for a clean second measurement
	defender.take_damage(100.0, open_attacker)
	var open_damage: float = defender.max_hp - defender.hp

	_expect(blocked_damage < 100.0, "damage from the covered direction should be reduced below the raw 100, got %.1f" % blocked_damage)
	_expect(is_equal_approx(open_damage, 100.0), "damage from the open flank should be full (no reduction), got %.1f" % open_damage)
	_expect(open_damage > blocked_damage, "open-flank damage should be strictly greater than blocked-direction damage")

	defender.queue_free()
	blocked_attacker.queue_free()
	open_attacker.queue_free()
	await process_frame


func _test_suppression_reduces_accuracy() -> void:
	var u := _make_unit("supp1", &"player", Vector2.ZERO)
	var attacker := _make_unit("supp1_att", &"enemy_dummy", Vector2(10, 0))
	await physics_frame
	var baseline: float = u._effective_accuracy()
	u.take_damage(10.0, attacker) # SUPPRESSION_PER_HIT = 25
	var after_one_hit: float = u._effective_accuracy()
	_expect(after_one_hit < baseline, "taking fire should reduce effective accuracy via suppression (baseline %.2f -> %.2f)" % [baseline, after_one_hit])

	u.queue_free()
	attacker.queue_free()
	await process_frame


func _test_suppression_triggers_retreat() -> void:
	var u := _make_unit("supp2", &"player", Vector2.ZERO)
	# Placed beyond the ~28px combined collision radius of two units so
	# move_and_slide()'s physical collision resolution doesn't keep
	# nudging them apart every frame (that drift was observed pushing a
	# too-close unit out of its own weapon range mid-test). A long-range
	# test weapon keeps the unit in its stationary/suppression-check
	# branch regardless of any minor residual drift.
	var target := _make_unit("supp2_target", &"enemy_dummy", Vector2(60, 0))
	var suppressor := _make_unit("supp2_suppressor", &"enemy_dummy", Vector2(-60, 0))
	var w := WeaponData.new()
	w.id = &"test_retreat_weapon"
	w.range_px = 300.0
	w.uses_ammo = false
	w.is_hitscan = true
	w.damage = 1.0
	w.rate_of_fire_rpm = 60.0
	u.equip_weapon("primary", w)
	await physics_frame
	u.order_attack(target) # puts u into State.ATTACKING
	await physics_frame
	_expect(u.state == BwUnit.State.ATTACKING, "setup: unit should be attacking before suppression builds up")

	# 3 hits at 25 suppression each clears the 70-point retreat threshold.
	u.take_damage(1.0, suppressor)
	u.take_damage(1.0, suppressor)
	u.take_damage(1.0, suppressor)
	var retreated := false
	for i in range(10):
		await physics_frame
		if u.state == BwUnit.State.RETREATING:
			retreated = true
			break
	_expect(retreated, "heavy suppression while attacking should trigger a simple retreat (state=%d)" % u.state)

	u.queue_free()
	target.queue_free()
	suppressor.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] cover_and_suppression: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
