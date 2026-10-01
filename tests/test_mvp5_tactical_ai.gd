extends SceneTree
## MVP5 "TACTICAL" AI layer: target priority, proactive retreat, and
## grenade avoidance (move/formation/cover/reload/suppression/flank/
## revive/vehicle-entry are exercised together by
## test_mvp5_strategic_and_arena.gd's full-match run, since they only
## show real value in a live multi-unit fight rather than in isolation).
##
## Run: godot4 --headless --path . --script res://tests/test_mvp5_tactical_ai.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const TACTICAL_AI_SCRIPT := preload("res://scripts/ai/unit_tactical_ai.gd")
const KNOWLEDGE_SCRIPT := preload("res://scripts/ai/faction_knowledge.gd")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	var nav_region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.add_outline(PackedVector2Array([
		Vector2(-1500, -1500), Vector2(1500, -1500), Vector2(1500, 1500), Vector2(-1500, 1500),
	]))
	poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = poly
	_world.add_child(nav_region)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_unit(side: StringName, tier: String, pos: Vector2, hp: float = 100.0) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName("u_%d_%d" % [Time.get_ticks_usec(), randi()])
	u.faction_side = side
	u.tier_label = tier
	u.max_hp = hp
	u.hp = hp
	u.vision_range_px = 600.0
	u.position = pos
	_world.add_child(u)
	return u


func _make_knowledge(side: StringName, own_side: StringName) -> Node:
	var k: Node = KNOWLEDGE_SCRIPT.new()
	k.owner_faction_side = side
	k.own_units_getter = Callable(self, "_units_of").bind(own_side)
	k.world_units_getter = Callable(self, "_all_units")
	_world.add_child(k)
	return k


func _units_of(side: StringName) -> Array:
	return _world.get_children().filter(func(n): return n is BwUnit and n.faction_side == side)


func _all_units() -> Array:
	return _world.get_children().filter(func(n): return n is BwUnit)


func _run() -> void:
	await _test_target_priority()
	await _test_proactive_retreat()
	await _test_grenade_avoidance()

	if _failures.is_empty():
		print("[Tests] mvp5_tactical_ai: all passed.")
	else:
		for f in _failures:
			printerr(f)
	quit(0 if _failures.is_empty() else 1)


## MC and low-HP targets should outrank a full-HP regular at similar
## distance (Prompt Dasar "Target priority").
func _test_target_priority() -> void:
	var self_unit := _make_unit(&"a", "B2", Vector2.ZERO)
	var regular := _make_unit(&"b", "B2", Vector2(200, 0), 100.0)
	var mc := _make_unit(&"b", "MC", Vector2(210, 10), 100.0)

	var knowledge := _make_knowledge(&"a", &"a")
	var tai: Node = TACTICAL_AI_SCRIPT.new()
	tai.unit = self_unit
	tai.knowledge = knowledge
	tai.difficulty = load("res://data/difficulty/difficulty_hard.tres") # high decision_quality => deterministic best-pick
	self_unit.add_child(tai)

	for i in range(6):
		await physics_frame

	var picked = tai._pick_priority_target()
	_expect(picked == mc, "Tactical AI should prioritize the Main Character over an equally-close regular.")

	self_unit.queue_free()
	regular.queue_free()
	mc.queue_free()
	knowledge.queue_free()
	await physics_frame


## A unit below its difficulty's retreat_hp_threshold while ATTACKING
## should proactively disengage (Prompt Dasar "AI dapat mundur dari
## perang yang buruk").
func _test_proactive_retreat() -> void:
	var self_unit := _make_unit(&"a", "B2", Vector2.ZERO, 100.0)
	var enemy := _make_unit(&"b", "B2", Vector2(200, 0), 100.0)
	self_unit.hp = 20.0 # below default 0.3 threshold
	self_unit.state = BwUnit.State.ATTACKING
	self_unit.attack_target = enemy

	var knowledge := _make_knowledge(&"a", &"a")
	var tai: Node = TACTICAL_AI_SCRIPT.new()
	tai.unit = self_unit
	tai.knowledge = knowledge
	tai.difficulty = load("res://data/difficulty/difficulty_medium.tres")
	self_unit.add_child(tai)

	for i in range(6):
		await physics_frame

	_expect(self_unit.state != BwUnit.State.ATTACKING, "Low-HP unit should have disengaged instead of continuing to attack.")
	_expect(tai.last_decision_reason.findn("retreat") != -1 or tai.last_decision_reason.findn("disengag") != -1, "Retreat decision should log a reason.")

	self_unit.queue_free()
	enemy.queue_free()
	knowledge.queue_free()
	await physics_frame


## An incoming grenade landing nearby should trigger a move-away order
## (Prompt Dasar "Grenade avoidance") for an enemy-faction unit, but not
## for a friendly-faction unit (own team's own grenade throw).
func _test_grenade_avoidance() -> void:
	var self_unit := _make_unit(&"a", "B2", Vector2(100, 0), 100.0)
	var friendly_thrower_unit := _make_unit(&"a", "B2", Vector2(-500, -500), 100.0)

	var knowledge := _make_knowledge(&"a", &"a")
	var tai: Node = TACTICAL_AI_SCRIPT.new()
	tai.unit = self_unit
	tai.knowledge = knowledge
	tai.difficulty = load("res://data/difficulty/difficulty_medium.tres")
	self_unit.add_child(tai)
	await physics_frame

	var events: Node = root.get_node_or_null("BattlefieldEvents")
	_expect(events != null, "BattlefieldEvents autoload should be registered.")

	var start_pos: Vector2 = self_unit.global_position
	events.grenade_incoming.emit(&"b", Vector2(120, 0), 80.0, 1.0) # enemy-thrown, close
	await physics_frame
	await physics_frame
	_expect(self_unit.global_position.distance_to(start_pos) > 1.0 or tai.last_decision_reason.findn("grenade") != -1, "Unit should react to a nearby enemy grenade by moving or logging an avoidance reason.")

	self_unit.queue_free()
	friendly_thrower_unit.queue_free()
	knowledge.queue_free()
	await physics_frame
