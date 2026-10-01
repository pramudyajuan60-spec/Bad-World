extends SceneTree
## Headless tests for MVP6 UserPrefsService (volume controls + key
## rebinding) and TutorialController (contextual hints shown once).
## Run with:
##   godot4 --headless --path . --script res://tests/test_mvp6_prefs_and_tutorial.gd

var _failures: Array[String] = []
var _prefs: Node


func _initialize() -> void:
	_prefs = root.get_node("UserPrefsService")
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_test_volume()
	_test_keybind_rebind_and_collision()
	_test_keybind_reset_to_default()
	_test_tutorial_shown_once()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp6_prefs_and_tutorial: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


func _test_volume() -> void:
	_prefs.set_volume("Music", 0.4)
	_expect(is_equal_approx(_prefs.get_volume("Music"), 0.4), "get_volume should round-trip the value set_volume just stored")
	var idx: int = AudioServer.get_bus_index("Music")
	_expect(idx != -1, "UserPrefsService should have created a real 'Music' AudioServer bus")
	_expect(not AudioServer.is_bus_mute(idx), "Music bus should not be muted at 40% volume")
	_prefs.set_volume("Music", 0.0)
	_expect(AudioServer.is_bus_mute(idx), "Music bus should mute at 0% volume")
	_prefs.set_volume("Music", 1.0) # restore for any later test in this run


func _test_keybind_rebind_and_collision() -> void:
	var original: int = _prefs.get_action_keycode("bw_stop")
	var ok: bool = _prefs.try_rebind("bw_stop", KEY_Z)
	_expect(ok, "Rebinding bw_stop to an unused key should succeed")
	_expect(_prefs.get_action_keycode("bw_stop") == KEY_Z, "bw_stop should now report KEY_Z")
	_expect(InputMap.has_action("bw_stop") and InputMap.action_get_events("bw_stop")[0].physical_keycode == KEY_Z, "InputMap itself should reflect the rebind immediately")

	var collision_ok: bool = _prefs.try_rebind("bw_defend", KEY_Z)
	_expect(not collision_ok, "Rebinding bw_defend to a key already used by bw_stop should be rejected")
	_expect(_prefs.get_action_keycode("bw_defend") != KEY_Z, "bw_defend should be unaffected by a rejected rebind")

	_prefs.try_rebind("bw_stop", original) # restore


func _test_keybind_reset_to_default() -> void:
	_prefs.try_rebind("bw_patrol_arm", KEY_Y)
	_expect(_prefs.get_action_keycode("bw_patrol_arm") == KEY_Y, "bw_patrol_arm should be KEY_Y right after rebind")
	_prefs.reset_keybind_to_default("bw_patrol_arm")
	_expect(_prefs.get_action_keycode("bw_patrol_arm") == KEY_P, "reset_keybind_to_default should restore project.godot's default (KEY_P)")


func _test_tutorial_shown_once() -> void:
	_prefs.reset_tutorial_progress_for_test()
	var tutorial_script: GDScript = load("res://scripts/gameplay/tutorial_controller.gd")
	var tutorial: Node = tutorial_script.new()
	root.add_child(tutorial)
	var shown: Array = []
	tutorial.hint_shown.connect(func(id, title, body): shown.append(id))

	tutorial.request(&"selection")
	_expect(shown.size() == 1 and shown[0] == &"selection", "First-ever request for an unseen hint should emit hint_shown once")
	_expect(_prefs.has_seen_tutorial("selection"), "Requesting a hint should mark it seen in UserPrefsService")

	tutorial.dismiss_current()
	shown.clear()
	tutorial.request(&"selection")
	_expect(shown.is_empty(), "Requesting an already-seen hint again should not re-emit it")

	tutorial.request(&"movement")
	tutorial.request(&"defend")
	_expect(shown.size() == 1, "A second hint requested while one is still showing should queue, not show immediately")
	tutorial.dismiss_current()
	_expect(shown.size() == 2, "Dismissing the current hint should advance the queue to the next one")

	tutorial.queue_free()
	_prefs.reset_tutorial_progress_for_test()
