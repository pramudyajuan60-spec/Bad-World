extends SceneTree
## Headless test proving MVP3's save/load extension actually persists
## the new state (Prompt Dasar acceptance criterion: "Save/load
## menyimpan economy, cargo, kendaraan, Heat, dan bangunan"). Loads the
## real OpenWorldMap scene, mutates its state (money, factory, a
## purchased vehicle, a unit's carried cargo/cash), saves, reloads via
## the scene's own save/load path, and checks the restored state. Uses
## a dedicated slot so it never collides with a real player's slot 1.
## Run with:
##   godot4 --headless --path . --script res://tests/test_mvp3_save_load.gd

const TEST_SLOT := 998

var _failures: Array[String] = []
var _save: Node
var _game_state: Node


func _initialize() -> void:
	_save = root.get_node("SaveService")
	_game_state = root.get_node("GameState")
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	_save.delete_save(TEST_SLOT)
	change_scene_to_file("res://scenes/gameplay/OpenWorldMap.tscn")
	await process_frame
	await process_frame
	await create_timer(0.2).timeout

	var map = root.get_node("OpenWorldMap")
	map.economy.set_money(12345)
	map.factory.level = 3
	map.factory.stored_cargo = 4
	map.heat_manager.waves_dispatched = 1
	var juan = null
	for u in map.units_root.get_children():
		if u is BwUnit and u.tier_label == "MC":
			juan = u
			break
	_expect(juan != null, "setup: Juan should have spawned")
	juan.carried_cargo = 2
	juan.carried_cash = 777

	var vdata: VehicleData = load("res://data/vehicles/compact.tres")
	var v = load("res://scenes/gameplay/Vehicle.tscn").instantiate()
	v.vehicle_data = vdata
	v.faction_side = &"player"
	v.position = Vector2(1234, -567)
	map.vehicles_root.add_child(v)
	await process_frame

	_save.save_game(TEST_SLOT, map.gather_save_data_for_test())

	# Reload fresh from that slot via the scene's own load path.
	_game_state.pending_load_slot = TEST_SLOT
	change_scene_to_file("res://scenes/gameplay/OpenWorldMap.tscn")
	await process_frame
	await process_frame
	await create_timer(0.3).timeout

	var map2 = root.get_node("OpenWorldMap")
	_expect(map2.economy.money == 12345, "restored money should match, got %d" % map2.economy.money)
	_expect(map2.factory.level == 3, "restored factory level should match, got %d" % map2.factory.level)
	_expect(map2.factory.stored_cargo == 4, "restored factory cargo should match, got %d" % map2.factory.stored_cargo)
	_expect(map2.heat_manager.waves_dispatched == 1, "restored Heat waves_dispatched should match, got %d" % map2.heat_manager.waves_dispatched)

	var juan2 = null
	for u in map2.units_root.get_children():
		if u is BwUnit and u.tier_label == "MC":
			juan2 = u
			break
	_expect(juan2 != null, "reloaded save should still have a Main Character")
	if juan2:
		_expect(juan2.carried_cargo == 2, "restored carried_cargo should match, got %d" % juan2.carried_cargo)
		_expect(juan2.carried_cash == 777, "restored carried_cash should match, got %d" % juan2.carried_cash)

	var found_vehicle := false
	for veh in map2.vehicles_root.get_children():
		if veh is Vehicle and is_instance_valid(veh) and is_equal_approx(veh.global_position.x, 1234.0):
			found_vehicle = true
	_expect(found_vehicle, "the purchased/placed vehicle should be restored at its saved position")

	_save.delete_save(TEST_SLOT)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp3_save_load: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
