extends SceneTree
## MVP5 "INFORMATION" layer: fog of war, last known position, threat
## memory staleness, and "AI tidak omniscient" as a structural property
## (not just a promise) — an AI's FactionKnowledge only ever reports
## enemies its own units can currently or recently see.
##
## Run: godot4 --headless --path . --script res://tests/test_mvp5_information.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const KNOWLEDGE_SCRIPT := preload("res://scripts/ai/faction_knowledge.gd")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_unit(side: StringName, pos: Vector2, vision: float = 400.0) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName("u_%d_%d" % [Time.get_ticks_usec(), randi()])
	u.faction_side = side
	u.tier_label = "B2"
	u.vision_range_px = vision
	u.position = pos
	_world.add_child(u)
	return u


func _run() -> void:
	# --- Basic visibility: within range + LOS => known; far away => not known ---
	var own := _make_unit(&"a", Vector2.ZERO, 300.0)
	var near_enemy := _make_unit(&"b", Vector2(150, 0))
	var far_enemy := _make_unit(&"b", Vector2(5000, 0))

	var knowledge: Node = KNOWLEDGE_SCRIPT.new()
	knowledge.owner_faction_side = &"a"
	knowledge.own_units_getter = Callable(self, "_own_units")
	knowledge.world_units_getter = Callable(self, "_all_units")
	_world.add_child(knowledge)

	await physics_frame
	await physics_frame

	_expect(knowledge.is_known(near_enemy.unit_id), "Near enemy within vision range should become known.")
	_expect(not knowledge.is_known(far_enemy.unit_id), "Far enemy outside vision range should stay unknown (AI tidak omniscient).")

	# --- Last known position persists after losing sight ---
	near_enemy.global_position = Vector2(150, 0)
	var pos_before = knowledge.get_last_known_position(near_enemy.unit_id)
	_expect(pos_before != null, "Last known position should be recorded while visible.")
	near_enemy.global_position = Vector2(9000, 9000) # move far away, out of vision
	await physics_frame
	await physics_frame
	_expect(knowledge.is_known(near_enemy.unit_id), "Enemy should still be remembered (last known position) after losing direct sight.")
	var pos_after = knowledge.get_last_known_position(near_enemy.unit_id)
	_expect(pos_after.distance_to(Vector2(150, 0)) < 1.0, "Last known position should reflect where it was last actually seen, not its current real position.")

	# --- Staleness: freshly seen is not stale; long-unseen becomes stale ---
	_expect(not knowledge.is_stale(near_enemy.unit_id), "Just-seen entry should not be stale immediately after losing sight.")
	# Directly simulate elapsed time without a multi-second real sleep:
	# poke the private clock forward the way is done for other timers in
	# this codebase's tests (documented assumption: fine for testing pure
	# accounting logic that has no per-frame physics dependency).
	knowledge._clock_sec += 25.0
	_expect(knowledge.is_stale(near_enemy.unit_id), "Entry older than STALE_AFTER_SEC should be reported stale.")

	_expect(_failures.is_empty(), "Failures:\n" + "\n".join(_failures))
	if _failures.is_empty():
		print("[Tests] mvp5_information: all passed.")
	else:
		for f in _failures:
			printerr(f)
	quit(0 if _failures.is_empty() else 1)


func _own_units() -> Array:
	return _world.get_children().filter(func(n): return n is BwUnit and n.faction_side == &"a")


func _all_units() -> Array:
	return _world.get_children().filter(func(n): return n is BwUnit)
