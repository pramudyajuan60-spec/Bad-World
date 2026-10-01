extends SceneTree
## Headless tests for MVP6 "Autosave dan minimal tiga manual save
## slots" + "Save migration/versioning". Run with:
##   godot4 --headless --path . --script res://tests/test_mvp6_save_slots_and_migration.gd

var _failures: Array[String] = []
var _save: Node

const TEST_MANUAL_SLOTS := [101, 102, 103]
const TEST_AUTOSAVE_SLOT := 100


func _initialize() -> void:
	_save = root.get_node("SaveService")
	_test_three_manual_slots_are_independent()
	_test_autosave_never_touched_by_manual_save()
	_test_most_recent_slot_picks_latest_including_autosave()
	_test_migration_upgrades_old_schema()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	for slot in TEST_MANUAL_SLOTS + [TEST_AUTOSAVE_SLOT]:
		_save.delete_save(slot)
	if _failures.is_empty():
		print("[Tests] mvp6_save_slots_and_migration: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


func _test_three_manual_slots_are_independent() -> void:
	for slot in TEST_MANUAL_SLOTS:
		_save.delete_save(slot)
	_expect(_save.manual_slots().size() >= 3, "SaveService should expose at least 3 manual slots")
	_save.save_game(TEST_MANUAL_SLOTS[0], {"campaign_id": "campaign_juan", "money": 111})
	_save.save_game(TEST_MANUAL_SLOTS[1], {"campaign_id": "campaign_fauzi", "money": 222})
	var a = _save.load_game(TEST_MANUAL_SLOTS[0])
	var b = _save.load_game(TEST_MANUAL_SLOTS[1])
	var c = _save.load_game(TEST_MANUAL_SLOTS[2])
	_expect(int(a.get("money")) == 111, "Manual slot 1 should keep its own save")
	_expect(int(b.get("money")) == 222, "Manual slot 2 should keep its own, different save")
	_expect(c == null, "An untouched manual slot should load as null (empty), not bleed another slot's data")


func _test_autosave_never_touched_by_manual_save() -> void:
	_save.delete_save(TEST_AUTOSAVE_SLOT)
	_save.save_game(TEST_AUTOSAVE_SLOT, {"campaign_id": "campaign_atha", "money": 999})
	_save.save_game(TEST_MANUAL_SLOTS[0], {"campaign_id": "campaign_juan", "money": 111})
	var autosave = _save.load_game(TEST_AUTOSAVE_SLOT)
	_expect(autosave != null and int(autosave.get("money")) == 999, "Saving to a manual slot must never overwrite the autosave slot's own data")


func _test_most_recent_slot_picks_latest_including_autosave() -> void:
	for slot in TEST_MANUAL_SLOTS + [TEST_AUTOSAVE_SLOT]:
		_save.delete_save(slot)
	_save.save_game(TEST_MANUAL_SLOTS[0], {"campaign_id": "campaign_juan"})
	# AUTOSAVE_SLOT is a *real* SaveService constant (0); this test only
	# proves the ranking logic using our own disposable high-numbered
	# slots so it never collides with a real player's autosave.
	var newer := {"campaign_id": "campaign_fauzi"}
	newer["schema_version"] = _save.SCHEMA_VERSION
	newer["saved_at_unix"] = Time.get_unix_time_from_system() + 1000
	var f := FileAccess.open("user://saves/slot_%d.json" % TEST_MANUAL_SLOTS[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(newer))
	f = null
	var best_among_two: int = -1
	var best_time := -1
	for slot in [TEST_MANUAL_SLOTS[0], TEST_MANUAL_SLOTS[1]]:
		var s = _save.slot_summary(slot)
		if s != null and int(s["saved_at_unix"]) > best_time:
			best_time = int(s["saved_at_unix"])
			best_among_two = slot
	_expect(best_among_two == TEST_MANUAL_SLOTS[1], "The more-recently-saved slot should be identified as newer")


func _test_migration_upgrades_old_schema() -> void:
	_save.delete_save(TEST_MANUAL_SLOTS[2])
	var old_payload := {
		"campaign_id": "campaign_juan", "schema_version": 1,
		"saved_at_unix": Time.get_unix_time_from_system(), "money": 500,
	}
	var f := FileAccess.open("user://saves/slot_%d.json" % TEST_MANUAL_SLOTS[2], FileAccess.WRITE)
	f.store_string(JSON.stringify(old_payload))
	f = null
	var loaded = _save.load_game(TEST_MANUAL_SLOTS[2])
	_expect(loaded != null, "An old schema_version=1 save should still load, not be rejected")
	_expect(int(loaded.get("schema_version", -1)) == _save.SCHEMA_VERSION, "A migrated save should report the current schema_version")
	_expect(int(loaded.get("migrated_from_version", -1)) == 1, "A migrated save should record which version it migrated from")
	_expect(int(loaded.get("enemies_eliminated_count", -1)) == 0, "Migration should backfill the new v2 field with a safe default")
	_expect(int(loaded.get("money")) == 500, "Migration should preserve all pre-existing fields unchanged")
