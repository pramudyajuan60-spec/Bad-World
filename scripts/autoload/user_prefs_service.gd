extends Node
## Autoload singleton. Persists the two user-facing preference
## categories MVP6 asks for that have nothing to do with campaign save
## data: audio bus volumes (Prompt Dasar "Volume controls meskipun
## audio masih placeholder") and keybind overrides (Prompt Dasar "Key
## rebinding"). Deliberately separate from SaveService — these are
## installation-wide preferences, not per-campaign progress, so they
## live in their own small `user://user_prefs.json` file and are never
## touched by autosave/manual-save/load.
##
## "Audio masih placeholder" (Prompt Dasar, base rule + MVP6 item 16):
## no real sound assets exist yet, so these buses currently have
## nothing to mix — but the Master/Music/SFX buses are real
## `AudioServer` buses and the sliders genuinely change their volume_db,
## so the controls are not dead placeholders themselves, only the
## audio content routed through them is.

const PREFS_PATH := "user://user_prefs.json"
const REBINDABLE_ACTIONS := [
	"bw_stop", "bw_attack_move_arm", "bw_defend", "bw_grenade_arm",
	"bw_recruit_arm", "bw_patrol_arm", "bw_exit_vehicle", "bw_pause",
	"bw_interact", "bw_toggle_debug_overlay",
	"bw_cam_left", "bw_cam_right", "bw_cam_up", "bw_cam_down",
]
## Human-readable label per action, for the rebind UI.
const ACTION_LABELS := {
	"bw_stop": "Stop", "bw_attack_move_arm": "Attack-Move (arm)",
	"bw_defend": "Defend / Cover Mode", "bw_grenade_arm": "Throw Grenade (arm)",
	"bw_recruit_arm": "Recruit Downed Enemy (arm)", "bw_patrol_arm": "Patrol Mode (arm)",
	"bw_exit_vehicle": "Exit Vehicle", "bw_pause": "Pause Menu",
	"bw_interact": "Interact (building/vehicle)", "bw_toggle_debug_overlay": "Toggle AI Debug Overlay",
	"bw_cam_left": "Pan Camera Left", "bw_cam_right": "Pan Camera Right",
	"bw_cam_up": "Pan Camera Up", "bw_cam_down": "Pan Camera Down",
}
const AUDIO_BUSES := ["Master", "Music", "SFX"]

signal volume_changed(bus_name: String, linear: float)
signal keybind_changed(action: String)

var _volumes: Dictionary = {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
## action -> physical_keycode int override (only present once rebound
## away from project.godot's default).
var _keybind_overrides: Dictionary = {}
## Tutorial hint ids (TutorialController) already shown at least once,
## ever, across every campaign/save — see tutorial_controller.gd.
var _seen_tutorial_steps: Dictionary = {}


func has_seen_tutorial(id: String) -> bool:
	return _seen_tutorial_steps.has(id)


func mark_tutorial_seen(id: String) -> void:
	if _seen_tutorial_steps.has(id):
		return
	_seen_tutorial_steps[id] = true
	_save()


## Test/debug only: lets a headless test exercise "first time ever"
## behavior deterministically without touching the real prefs file.
func reset_tutorial_progress_for_test() -> void:
	_seen_tutorial_steps.clear()


func _ready() -> void:
	_ensure_audio_buses_exist()
	_load()
	for bus_name in AUDIO_BUSES:
		_apply_volume(bus_name, _volumes.get(bus_name, 1.0))
	for action in _keybind_overrides.keys():
		_apply_keybind(action, int(_keybind_overrides[action]))


func _ensure_audio_buses_exist() -> void:
	for bus_name in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			if bus_name != "Master":
				AudioServer.set_bus_send(idx, "Master")


## ---------------------------------------------------------------
## Volume
## ---------------------------------------------------------------
func get_volume(bus_name: String) -> float:
	return _volumes.get(bus_name, 1.0)


func set_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_volumes[bus_name] = linear
	_apply_volume(bus_name, linear)
	volume_changed.emit(bus_name, linear)
	_save()


func _apply_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(linear, 0.0001)) if linear > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, linear <= 0.0)


## ---------------------------------------------------------------
## Key rebinding
## ---------------------------------------------------------------
func get_action_label(action: String) -> String:
	return ACTION_LABELS.get(action, action)


## First physical keycode currently bound to `action` (after any
## override), or 0 if none.
func get_action_keycode(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return 0


func get_action_key_label(action: String) -> String:
	var keycode := get_action_keycode(action)
	if keycode == 0:
		return "(unbound)"
	return OS.get_keycode_string(keycode)


## Rebinds `action` to a single physical key, replacing whatever was
## bound before (this project only ever binds one key per action).
## Rejects binding the same physical key to two different rebindable
## actions, so a rebind can never silently create a dead button
## elsewhere (Prompt Dasar acceptance: "Tidak ada tombol mati").
func try_rebind(action: String, physical_keycode: int) -> bool:
	if not (action in REBINDABLE_ACTIONS):
		return false
	for other in REBINDABLE_ACTIONS:
		if other == action:
			continue
		if get_action_keycode(other) == physical_keycode:
			return false
	_apply_keybind(action, physical_keycode)
	_keybind_overrides[action] = physical_keycode
	keybind_changed.emit(action)
	_save()
	return true


func _apply_keybind(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action, ev)


func reset_keybind_to_default(action: String) -> void:
	_keybind_overrides.erase(action)
	_save()
	# Defaults live in project.godot; the simplest correct way to
	# restore them at runtime is to reload the project's own input map
	# for just this one action from ProjectSettings.
	var key := "input/%s" % action
	if ProjectSettings.has_setting(key):
		var default_cfg: Dictionary = ProjectSettings.get_setting(key)
		InputMap.action_erase_events(action)
		for ev in default_cfg.get("events", []):
			InputMap.action_add_event(action, ev)
	keybind_changed.emit(action)


## ---------------------------------------------------------------
## Persistence
## ---------------------------------------------------------------
func _save() -> void:
	var payload := {"volumes": _volumes, "keybinds": _keybind_overrides, "tutorial_seen": _seen_tutorial_steps.keys()}
	var f := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "  "))


func _load() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		return
	var f := FileAccess.open(PREFS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return # corrupt prefs file: silently fall back to defaults, never crash
	var vol = parsed.get("volumes", {})
	if vol is Dictionary:
		for k in vol.keys():
			if k in AUDIO_BUSES:
				_volumes[k] = clampf(float(vol[k]), 0.0, 1.0)
	var kb = parsed.get("keybinds", {})
	if kb is Dictionary:
		for k in kb.keys():
			if k in REBINDABLE_ACTIONS:
				_keybind_overrides[k] = int(kb[k])
	var seen = parsed.get("tutorial_seen", [])
	if seen is Array:
		for id in seen:
			_seen_tutorial_steps[String(id)] = true
