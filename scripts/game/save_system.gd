class_name SaveSystem
extends RefCounted
## Minimal save/load for MVP 1: unit positions, hp, side, and campaign id.
## Stored as JSON under user://saves/<slot>.json.

const SAVE_DIR := "user://saves"


static func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]


static func save_game(game: Node, slot: String) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data: Dictionary = game.get_save_data()
	data["saved_at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("[SaveSystem] cannot write " + _slot_path(slot))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("[SaveSystem] saved to ", _slot_path(slot))
	return true


static func load_game(game: Node, slot: String) -> bool:
	if not FileAccess.file_exists(_slot_path(slot)):
		push_warning("[SaveSystem] no save at " + _slot_path(slot))
		return false
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[SaveSystem] corrupt save " + _slot_path(slot))
		return false
	game.apply_save_data(data)
	print("[SaveSystem] loaded from ", _slot_path(slot))
	return true


static func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot))
