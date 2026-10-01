extends Node
## Autoload singleton. Started MVP 1 as a single manual slot; MVP6 adds
## the full Prompt Dasar "SAVE SYSTEM" requirement: >=3 manual slots,
## a separate autosave slot that manual saves never touch, schema
## versioning with an actual migration path (not just a mismatch
## warning), and never crashing on a corrupt file.
##
## Slot numbering: 0 is the single autosave slot; 1..MANUAL_SLOT_COUNT
## are manual slots. Slot 1 is kept as the pre-MVP6 default slot so
## saves created before this change keep loading unmodified.

const SAVE_DIR := "user://saves/"
const SCHEMA_VERSION := 2
const AUTOSAVE_SLOT := 0
const MANUAL_SLOT_COUNT := 3
## MVP6 (Prompt Dasar "Autosave terpisah"). Fires on an in-mission
## timer; the owning gameplay scene supplies fresh payload via
## autosave_payload_requested and this service writes it to the
## dedicated autosave slot, never a manual one.
signal autosaved


func _ready() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


## Manual slot numbers only (1..MANUAL_SLOT_COUNT), for UI slot pickers.
func manual_slots() -> Array:
	var out: Array = []
	for i in range(1, MANUAL_SLOT_COUNT + 1):
		out.append(i)
	return out


## Metadata for a save-slot picker UI: campaign/difficulty/timestamp
## without needing the caller to parse the full payload. Returns null
## for an empty or corrupt slot (never throws).
func slot_summary(slot: int):
	var data = load_game(slot)
	if data == null:
		return null
	return {
		"campaign_id": String(data.get("campaign_id", "")),
		"difficulty_id": String(data.get("difficulty_id", "")),
		"saved_at_unix": int(data.get("saved_at_unix", 0)),
		"money": int(data.get("money", 0)),
		"elapsed_play_sec": float(data.get("elapsed_play_sec", 0.0)),
	}


## Most-recently-saved slot across autosave + all manual slots, or -1
## if none exist. Used by Main Menu's "Continue" so it always resumes
## the player's latest progress regardless of which slot it lives in.
func most_recent_slot() -> int:
	var best_slot := -1
	var best_time := -1
	for slot in [AUTOSAVE_SLOT] + manual_slots():
		var summary = slot_summary(slot)
		if summary == null:
			continue
		var t: int = summary["saved_at_unix"]
		if t > best_time:
			best_time = t
			best_slot = slot
	return best_slot


func save_game(slot: int, payload: Dictionary) -> bool:
	payload["schema_version"] = SCHEMA_VERSION
	payload["saved_at_unix"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveService: cannot open %s for writing" % _slot_path(slot))
		return false
	f.store_string(JSON.stringify(payload, "  "))
	if slot == AUTOSAVE_SLOT:
		autosaved.emit()
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
	var loaded_version := int(parsed.get("schema_version", -1))
	if loaded_version != SCHEMA_VERSION:
		parsed = _migrate(parsed, loaded_version)
	return parsed


## Upgrades an older-schema payload to SCHEMA_VERSION in place, one
## version step at a time, so a save from several versions ago still
## loads correctly instead of only ever warning (Prompt Dasar "Save
## migration/versioning"). Unknown/negative versions (e.g. a corrupt
## or hand-edited file missing the field) are treated as the oldest
## known version rather than rejected outright.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var version: int = max(from_version, 1)
	while version < SCHEMA_VERSION:
		match version:
			1:
				# v1 -> v2: introduced elapsed_play_sec and
				# enemies_eliminated_count (MVP6 campaign summary
				# stats). Absent on any v1 save; default both to 0
				# rather than failing the load.
				data["elapsed_play_sec"] = data.get("elapsed_play_sec", 0.0)
				data["enemies_eliminated_count"] = data.get("enemies_eliminated_count", 0)
				data["lifetime_money_earned"] = data.get("lifetime_money_earned", 0)
			_:
				pass
		version += 1
	data["schema_version"] = SCHEMA_VERSION
	data["migrated_from_version"] = from_version
	push_warning("SaveService: migrated save from schema_version %d to %d" % [from_version, SCHEMA_VERSION])
	return data


func delete_save(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
