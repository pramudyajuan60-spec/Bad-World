extends SceneTree
## Headless tests for MVP6 "Victory, defeat, restart, dan campaign
## summary". Loads the real OpenWorldMap scene (same pattern as
## test_mvp4_campaign_spawn.gd). Run with:
##   godot4 --headless --path . --script res://tests/test_mvp6_victory_defeat.gd

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
	await _test_mc_death_triggers_defeat()
	await _test_victory_fires_once_all_enemy_mcs_dead()
	await _test_nabil_victory_also_requires_factory_destroyed()
	await _test_real_rival_factions_are_spawned_and_registered()
	await _test_real_rival_mc_death_actually_triggers_victory()
	await process_frame
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp6_victory_defeat: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


func _test_mc_death_triggers_defeat() -> void:
	_spawn(&"campaign_juan")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	_expect(not map.victory_defeat_screen.visible, "Victory/Defeat screen should be hidden at mission start")
	_expect(not paused, "Game should not start paused")
	var mc: BwUnit = map._get_main_character()
	_expect(mc != null, "Main Character should exist right after spawn")
	mc._die()
	await process_frame
	_expect(map.victory_defeat_screen.visible, "Victory/Defeat screen should show after the player MC dies")
	_expect(paused, "Game should pause once the mission is over")
	_expect(map.victory_defeat_screen.title_label.text == "DEFEAT", "MC death should show DEFEAT, got '%s'" % map.victory_defeat_screen.title_label.text)
	_expect(map.is_mission_over_for_test(), "is_mission_over_for_test() should report true after MC death")
	_expect("Play time" in map.victory_defeat_screen.stats_label.text, "Campaign summary should include play time")
	paused = false


func _test_victory_fires_once_all_enemy_mcs_dead() -> void:
	_spawn(&"campaign_juan")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	# MVP7: _spawn_rival_factions() now always populates 3 *real* rival
	# MCs on spawn; clear those first so this test can assert purely on
	# the generic victory-condition logic with one controlled fake,
	# independent of that real spawn (which gets its own dedicated test
	# below).
	map.clear_enemy_mc_registry_for_test()
	var fake_enemy_mc: BwUnit = map._make_unit(&"fake_rival_mc", "Fake Rival MC", "MC", &"enemy_rival", false)
	fake_enemy_mc.state = BwUnit.State.DEAD
	map.register_enemy_mc_for_test(fake_enemy_mc)
	map.force_check_victory_for_test()
	await process_frame
	_expect(map.victory_defeat_screen.visible, "Victory screen should show once the only registered rival MC is dead")
	_expect(map.victory_defeat_screen.title_label.text == "VICTORY", "All rival MCs dead should show VICTORY, got '%s'" % map.victory_defeat_screen.title_label.text)
	paused = false


func _test_nabil_victory_also_requires_factory_destroyed() -> void:
	_spawn(&"campaign_nabil")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	map.clear_enemy_mc_registry_for_test()
	var fake_cartel_mc: BwUnit = map._make_unit(&"fake_cartel_mc", "Fake Cartel MC", "MC", &"enemy_cartel", false)
	fake_cartel_mc.state = BwUnit.State.DEAD
	map.register_enemy_mc_for_test(fake_cartel_mc)
	# MVP7 bugfix under test: Nabil's factory check must look at the
	# *rival cartels'* factories (_rival_cartel_factories), never the
	# player's own `factory` node — force every real rival factory
	# standing first, then destroy them one at a time.
	var rival_factories: Array = map.rival_cartel_factories_for_test()
	_expect(rival_factories.size() == 3, "Campaign Nabil's 3 rivals (Bellarosa, Nasion, Vartieri) are all cartels, so all 3 should get a rival cartel factory, got %d" % rival_factories.size())
	for rf in rival_factories:
		rf.is_destroyed = false
	map.force_check_victory_for_test()
	await process_frame
	_expect(not map.victory_defeat_screen.visible, "Nabil should not win while a cartel factory is still standing")
	for rf in rival_factories:
		rf.is_destroyed = true
	map.force_check_victory_for_test()
	await process_frame
	_expect(map.victory_defeat_screen.visible, "Nabil should win once all cartel MCs are dead and no cartel factory remains")
	paused = false


func _test_real_rival_factions_are_spawned_and_registered() -> void:
	_spawn(&"campaign_juan")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	# Juan's 3 rivals: Nabil (DEA), Andrés (Nasion), Zie (Vartieri).
	_expect(map._enemy_mc_registry.size() == 3, "Spawning should register exactly 3 real rival MCs (the other 3 campaigns), got %d" % map._enemy_mc_registry.size())
	for mc in map._enemy_mc_registry:
		_expect(is_instance_valid(mc) and mc.state != BwUnit.State.DEAD, "Each real rival MC should start alive")
		_expect(mc.tier_label == "MC", "Each registered rival should actually be tier MC")
		_expect(mc.unit_data != null, "Each rival MC should have its own faction's mc_unit data, not null")
		_expect(not mc.can_move, "Rival MCs are a stationary fixed encounter by design (see docs/TECH_DECISIONS.md), not full mobile AI")
	# Juan's campaign has no uses_armory_instead_of_gun_shop rival
	# requirement, so no rival cartel Factory should be built for it.
	_expect(map.rival_cartel_factories_for_test().is_empty(), "Non-Nabil campaigns should not build any rival cartel factories")


func _test_real_rival_mc_death_actually_triggers_victory() -> void:
	_spawn(&"campaign_juan")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	_expect(not map.victory_defeat_screen.visible, "Victory screen should not show before any rival MC has died")
	# Release Candidate fix pass (Issue 1): find one rival's guard
	# squad before killing that rival's MC, so this same end-to-end
	# test also confirms the real BwUnit._die() path (not just the
	# apply_*_for_test seams in test_rc_mc_death_consequences.gd)
	# actually wires through to _apply_mc_death_consequences().
	var sample_mc = map._enemy_mc_registry[0]
	var sample_side: StringName = sample_mc.faction_side
	var guards_before: Array = []
	for u in map.enemies_root.get_children():
		if u is BwUnit and u.faction_side == sample_side and u.tier_label != "MC":
			guards_before.append(u)
	_expect(not guards_before.is_empty(), "the sampled rival faction should have at least one guard to observe a fate on")
	for mc in map._enemy_mc_registry.duplicate():
		if is_instance_valid(mc):
			mc._die()
	await process_frame
	await process_frame
	await process_frame
	_expect(map.victory_defeat_screen.visible, "Killing all 3 real rival MCs via normal BwUnit._die() should trigger VICTORY for real, with no test-only seam involved")
	_expect(map.victory_defeat_screen.title_label.text == "VICTORY", "Should show VICTORY, got '%s'" % map.victory_defeat_screen.title_label.text)
	var any_guard_fate_applied: bool = false
	for g in guards_before:
		if not is_instance_valid(g) or g.can_move or g.has_gone_rogue or g.state == BwUnit.State.DOWNED:
			any_guard_fate_applied = true
	_expect(any_guard_fate_applied, "killing a real rival MC via actual combat death should apply flee/surrender/rogue to its surviving guards, not just the fake test-registered MCs in the other subtests")
	paused = false
