extends SceneTree
## MVP 1 automated tests (headless).
##
## Run with:
##   godot --headless --path . --script res://tests/test_mvp1.gd
##
## Tests: sprite atlas integrity, game scene boot, unit spawn counts,
## orders (move/stop), save/load round-trip.

var _failures: Array[String] = []


func _initialize() -> void:
	_run_tests()


func _run_tests() -> void:
	await process_frame
	await process_frame
	_test_sprite_atlases()
	_test_game_boots()
	_test_unit_orders()
	_test_save_load()
	if _failures.is_empty():
		print("[Tests] All MVP1 tests passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _test_sprite_atlases() -> void:
	for path in ["res://data/animations/unit_b1.tres",
			"res://data/animations/unit_juan.tres"]:
		var sf: SpriteFrames = load(path)
		_expect(sf != null, "load " + path)
		if sf == null:
			continue
		for base in ["idle", "walk", "attack"]:
			for dir in ["se", "sw", "ne", "nw"]:
				var anim := "%s_%s" % [base, dir]
				_expect(sf.has_animation(anim),
					"%s has %s" % [path.get_file(), anim])
				if sf.has_animation(anim):
					_expect(sf.get_frame_count(anim) >= 1,
						"%s %s non-empty" % [path.get_file(), anim])
	print("[Tests] sprite atlases ok")


func _test_game_boots() -> void:
	var scene: PackedScene = load("res://scenes/game/Game.tscn")
	_expect(scene != null, "Game.tscn loads")
	if scene == null:
		return
	var game := scene.instantiate()
	root.add_child(game)
	var count := 0
	for u in game._units:
		count += 1
	_expect(count == 7, "7 units spawned (Juan+3 B1+3 enemies), got %d" % count)
	var heroes := 0
	var enemies := 0
	for u in game._units:
		if u.is_enemy:
			enemies += 1
		else:
			heroes += 1
	_expect(heroes == 4, "4 player units, got %d" % heroes)
	_expect(enemies == 3, "3 enemies, got %d" % enemies)
	game.queue_free()
	print("[Tests] game boot ok")


func _test_unit_orders() -> void:
	var scene: PackedScene = load("res://scenes/game/Game.tscn")
	var game := scene.instantiate()
	root.add_child(game)
	var u = game._units[0]
	_expect(u.state == 0, "unit starts IDLE")
	u.order_move(Vector2(500, 500))
	_expect(u.state == 1, "unit MOVING after order_move")
	u.order_stop()
	_expect(u.state == 0, "unit IDLE after order_stop")
	var foe = null
	for o in game._units:
		if o.is_enemy:
			foe = o
			break
	_expect(foe != null, "enemy exists")
	u.order_attack(foe)
	_expect(u.state == 2, "unit ATTACKING after order_attack")
	game.queue_free()
	print("[Tests] unit orders ok")


func _test_save_load() -> void:
	var scene: PackedScene = load("res://scenes/game/Game.tscn")
	var game := scene.instantiate()
	root.add_child(game)
	# move a unit, save, move again, load, verify position restored
	var u = game._units[0]
	var saved_pos := Vector2(123, 456)
	u.global_position = saved_pos
	var ok_save: bool = SaveSystem.save_game(game, "test_slot")
	_expect(ok_save, "save_game returns true")
	u.global_position = Vector2(999, 999)
	var ok_load: bool = SaveSystem.load_game(game, "test_slot")
	_expect(ok_load, "load_game returns true")
	var found := false
	for o in game._units:
		if o.unit_name == u.unit_name and o.global_position.distance_to(saved_pos) < 1.0:
			found = true
	_expect(found, "load restores unit position")
	game.queue_free()
	print("[Tests] save/load ok")
