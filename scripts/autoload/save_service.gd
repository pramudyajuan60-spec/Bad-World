extends Node
## Autoload singleton. Minimal save/load for MVP 1 ("Minimal save/load
## posisi unit dan campaign"). Deliberately simple: a single manual slot,
## JSON on disk, schema-versioned. The full autosave + >=3 manual slots +
## migration requirement (Prompt Dasar "SAVE SYSTEM", MVP 6 scope) extends
## this same file format later instead of replacing it.

const SAVE_DIR := "user://saves/"
const SCHEMA_VERSION := 1


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func save_game(slot: int, payload: Dictionary) -> bool:
	payload["schema_version"] = SCHEMA_VERSION
	payload["saved_at_unix"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveService: cannot open %s for writing" % _slot_path(slot))
		return false
	f.store_string(JSON.stringify(payload, "  "))
	return true


## Returns the parsed save Dictionary, or null if missing/corrupt. Never
## throws/crashes on a broken file (rule: "Menangani save rusak tanpa crash").
func load_game(slot: int):
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveService: corrupt save at %s, ignoring" % path)
		return null
	if int(parsed.get("schema_version", -1)) != SCHEMA_VERSION:
		push_warning("SaveService: schema mismatch at %s (got %s, expected %d)" % [path, str(parsed.get("schema_version")), SCHEMA_VERSION])
	return parsed


func delete_save(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
