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
	var fake_cartel_mc: BwUnit = map._make_unit(&"fake_cartel_mc", "Fake Cartel MC", "MC", &"enemy_cartel", false)
	fake_cartel_mc.state = BwUnit.State.DEAD
	map.register_enemy_mc_for_test(fake_cartel_mc)
	map.factory.is_destroyed = false
	map.force_check_victory_for_test()
	await process_frame
	_expect(not map.victory_defeat_screen.visible, "Nabil should not win while a cartel factory is still standing")
	map.factory.is_destroyed = true
	map.force_check_victory_for_test()
	await process_frame
	_expect(map.victory_defeat_screen.visible, "Nabil should win once all cartel MCs are dead and no cartel factory remains")
	paused = false
