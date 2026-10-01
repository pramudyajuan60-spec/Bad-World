extends SceneTree
## Release Candidate Fix Pass, Issue 1: "Jika Main Character musuh
## mati: Faction musuh tereliminasi. Unit tersisa dapat kabur,
## menyerah, atau menjadi rogue berdasarkan tier." Loads the real
## OpenWorldMap scene (same pattern as test_mvp4_campaign_spawn.gd /
## test_mvp6_victory_defeat.gd). Run with:
##   godot4 --headless --path . --script res://tests/test_rc_mc_death_consequences.gd

var _failures: Array[String] = []
var _gs: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _spawn(campaign_id: StringName):
	_gs.pending_load_slot = -1
	_gs.current_campaign_id = campaign_id
	change_scene_to_file("res://scenes/gameplay/OpenWorldMap.tscn")


func _run() -> void:
	await _test_flee_outcome()
	await _test_surrender_outcome_reuses_downed_state()
	await _test_rogue_outcome()
	await _test_special_always_rogue_never_surrenders()
	await _test_full_mc_death_sweep_only_affects_that_faction()
	await _test_dead_mc_player_side_not_affected()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] rc_mc_death_consequences: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


func _test_flee_outcome() -> void:
	_spawn(&"campaign_juan")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	var u: BwUnit = map._make_unit(&"rc_flee_test", "Flee Test", "B1", &"enemy_fake_rival", false)
	u.position = map.player_hq_position + Vector2(500, 0)
	map.enemies_root.add_child(u)
	await process_frame

	_expect(not u.can_move, "unit should start as a stationary fixed encounter (can_move=false) like every rival guard")
	map.apply_unit_fate_for_test(u, "flee")
	_expect(u.can_move, "a fleeing unit must become able to move")
	_expect(not u.auto_defend, "a fleeing unit must stop defending its position")
	_expect(u.state == BwUnit.State.MOVING, "a fleeing unit should be ordered to move away, got state %d" % u.state)
	_expect(map._fleeing_units.has(u), "a fleeing unit should be tracked for eventual despawn")

	# Simulate enough _process() ticks for the despawn timer to expire.
	for i in range(int(map.FLEE_DESPAWN_SEC) + 2):
		map._process(1.0)
		await process_frame
	_expect(not is_instance_valid(u), "a fleeing unit should eventually leave play (despawn) rather than linger forever")


func _test_surrender_outcome_reuses_downed_state() -> void:
	var map = root.get_node("OpenWorldMap")
	var u: BwUnit = map._make_unit(&"rc_surrender_test", "Surrender Test", "B2", &"enemy_fake_rival", false)
	u.hp = u.max_hp # surrendering, not wounded — should keep whatever hp it had
	u.is_recruitable_tier = false
	map.enemies_root.add_child(u)
	await process_frame

	map.apply_unit_fate_for_test(u, "surrender")
	await process_frame

	_expect(u.state == BwUnit.State.DOWNED, "a surrendered unit should be in the exact same DOWNED state a combat-downed enemy uses (reuse, not a new state)")
	_expect(u.is_recruitable_tier, "a surrendered unit must become recruitable, same as any other downed regular enemy")
	_expect(not u.auto_defend, "a surrendered unit must stop defending/fighting")
	_expect(u.hp > 0.0, "surrendering must not force hp to 0 — it's giving up, not dying (hp=%.1f)" % u.hp)
	_expect(u.downed_timer > 0.0, "a surrendered unit should get the normal tier-based downed_timer countdown")


func _test_rogue_outcome() -> void:
	var map = root.get_node("OpenWorldMap")
	var u: BwUnit = map._make_unit(&"rc_rogue_test", "Rogue Test", "B3", &"enemy_fake_rival", false)
	u.auto_defend = true
	map.enemies_root.add_child(u)
	await process_frame

	map.apply_unit_fate_for_test(u, "rogue")
	_expect(u.has_gone_rogue, "a rogue unit should be flagged has_gone_rogue")
	_expect(u.auto_defend, "a rogue unit keeps fighting (auto_defend unchanged) — it has no faction left to desert *from*")
	_expect(u.state != BwUnit.State.DOWNED and u.state != BwUnit.State.DEAD, "a rogue unit should still be an active combatant, not downed/dead")


func _test_special_always_rogue_never_surrenders() -> void:
	var map = root.get_node("OpenWorldMap")
	var u: BwUnit = map._make_unit(&"rc_special_test", "Special Test", "SPECIAL", &"enemy_fake_rival", false)
	map.enemies_root.add_child(u)
	await process_frame

	# Run the real roll-based resolver many times — Special must be
	# deterministic (always rogue), never surrender/flee, regardless
	# of the RNG roll (Prompt Dasar: "Special tidak menyerah").
	for i in range(20):
		u.has_gone_rogue = false
		u.state = BwUnit.State.IDLE
		u.auto_defend = true
		map._resolve_unit_fate(u)
		_expect(u.has_gone_rogue, "Special must always resolve to rogue (trial %d)" % i)
		_expect(u.state != BwUnit.State.DOWNED, "Special must never surrender/be forced downed by this mechanic (trial %d)" % i)


func _test_full_mc_death_sweep_only_affects_that_faction() -> void:
	_spawn(&"campaign_juan")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")

	var victim_side := &"enemy_sweep_victim"
	var other_side := &"enemy_sweep_bystander"
	var victim_guard: BwUnit = map._make_unit(&"rc_sweep_guard", "Sweep Guard", "B1", victim_side, false)
	map.enemies_root.add_child(victim_guard)
	var bystander: BwUnit = map._make_unit(&"rc_sweep_bystander", "Bystander", "B1", other_side, false)
	map.enemies_root.add_child(bystander)
	var already_downed: BwUnit = map._make_unit(&"rc_sweep_downed", "Already Downed", "B1", victim_side, false)
	map.enemies_root.add_child(already_downed)
	already_downed.call_deferred("_enter_downed")
	await process_frame
	await process_frame

	var downed_state_before := already_downed.state
	map.apply_mc_death_consequences_for_test(victim_side)
	await process_frame

	_expect(bystander.state == BwUnit.State.IDLE and not bystander.has_gone_rogue and bystander.can_move == false, "a unit on a DIFFERENT faction_side must be completely unaffected by another faction's MC death")
	var victim_changed: bool = victim_guard.can_move or victim_guard.has_gone_rogue or victim_guard.state == BwUnit.State.DOWNED or not is_instance_valid(victim_guard)
	_expect(victim_changed, "the victim faction's own surviving guard must have some fate applied (flee/surrender/rogue)")
	_expect(already_downed.state == downed_state_before, "a unit already DOWNED before the sweep must not be re-processed/double-transitioned")


func _test_dead_mc_player_side_not_affected() -> void:
	_spawn(&"campaign_juan")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	var b1 = null
	for u in map.units_root.get_children():
		if u is BwUnit and u.tier_label == "B1":
			b1 = u
			break
	_expect(b1 != null, "Juan's campaign should spawn player-side B1 units to check")
	if b1 == null:
		return
	var can_move_before: bool = b1.can_move
	var auto_defend_before: bool = b1.auto_defend
	# Player MC death is handled by a *different*, stronger mechanism
	# (immediate DEFEAT) — _apply_mc_death_consequences must never run
	# for the player's own faction_side (it is only ever invoked from
	# _on_enemy_died, which the player's own MC death does not go
	# through at all — it uses _on_player_mc_died instead). Confirm
	# directly calling it for &"player" doesn't corrupt player units if
	# it were ever (incorrectly) invoked there.
	map.apply_mc_death_consequences_for_test(&"player")
	await process_frame
	_expect(b1.can_move == can_move_before and b1.auto_defend == auto_defend_before, "even if invoked for the player's side, player units sit outside enemies_root and must be structurally unreachable by this sweep")
