extends SceneTree
## Headless tests for SaveService: round-trip fidelity and graceful
## handling of a corrupt save file (rule: "Menangani save rusak tanpa
## crash"). Uses a dedicated slot number so it never collides with a
## real player's slot 1 save. Run with:
##   godot4 --headless --path . --script res://tests/test_save_service.gd

const TEST_SLOT := 999

var _failures: Array[String] = []
var _save: Node


func _initialize() -> void:
	# Under `--script` (SceneTree override) mode, autoload singletons still
	# instantiate under /root, but GDScript's bare-identifier resolution for
	# autoloads is not reliable in this mode — fetch the node explicitly.
	_save = root.get_node("SaveService")
	_test_round_trip()
	_test_missing_slot_returns_null()
	_test_corrupt_file_returns_null_not_crash()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	_save.delete_save(TEST_SLOT)
	if _failures.is_empty():
		print("[Tests] save_service: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


func _test_round_trip() -> void:
	_save.delete_save(TEST_SLOT)
	var payload := {
		"campaign_id": "campaign_juan",
		"difficulty_id": "difficulty_medium",
		"units": [
			{"id": "juan", "tier": "MC", "faction_side": "player", "x": 12.5, "y": -8.0, "hp": 88.0, "max_hp": 130.0},
			{"id": "b1_1", "tier": "B1", "faction_side": "player", "x": 40.0, "y": 40.0, "hp": 100.0, "max_hp": 100.0},
		],
	}
	var ok: bool = _save.save_game(TEST_SLOT, payload)
	_expect(ok, "save_game should return true on success")
	_expect(_save.has_save(TEST_SLOT), "has_save should be true right after saving")
	var loaded = _save.load_game(TEST_SLOT)
	_expect(loaded != null, "load_game should return a non-null Dictionary right after saving")
	if loaded != null:
		_expect(loaded.get("campaign_id") == "campaign_juan", "loaded campaign_id should round-trip")
		_expect(int(loaded.get("schema_version", -1)) == _save.SCHEMA_VERSION, "loaded save should carry the current schema_version")
		var units: Array = loaded.get("units", [])
		_expect(units.size() == 2, "loaded save should contain both saved units")
		if units.size() == 2:
			_expect(float(units[0].get("hp")) == 88.0, "first unit's hp should round-trip exactly")
			_expect(float(units[1].get("x")) == 40.0, "second unit's x should round-trip exactly")


func _test_missing_slot_returns_null() -> void:
	_save.delete_save(TEST_SLOT)
	var loaded = _save.load_game(TEST_SLOT)
	_expect(loaded == null, "load_game on a missing slot should return null, not crash")
	_expect(not _save.has_save(TEST_SLOT), "has_save on a missing slot should be false")


func _test_corrupt_file_returns_null_not_crash() -> void:
	var path := "user://saves/slot_%d.json" % TEST_SLOT
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not valid json ][")
	f = null
	var loaded = _save.load_game(TEST_SLOT)
	_expect(loaded == null, "load_game on a corrupt file should return null, not crash the engine")
	_save.delete_save(TEST_SLOT)
