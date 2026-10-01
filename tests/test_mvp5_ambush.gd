extends SceneTree
## MVP5 "AMBUSH": arms only with intel + tactical advantage, respects a
## utility threshold, and cancels when the situation changes (squad
## wiped before trigger, or intel goes stale).
##
## Run: godot4 --headless --path . --script res://tests/test_mvp5_ambush.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const KNOWLEDGE_SCRIPT := preload("res://scripts/ai/faction_knowledge.gd")
const AMBUSH_SCRIPT := preload("res://scripts/ai/ambush_controller.gd")

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


func _make_unit(side: StringName, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName("u_%d_%d" % [Time.get_ticks_usec(), randi()])
	u.faction_side = side
	u.tier_label = "B2"
	u.vision_range_px = 600.0
	u.position = pos
	_world.add_child(u)
	return u


func _run() -> void:
	await _test_no_arm_without_advantage()
	await _test_arms_and_triggers_with_advantage()
	await _test_cancels_when_squad_wiped()

	if _failures.is_empty():
		print("[Tests] mvp5_ambush: all passed.")
	else:
		for f in _failures:
			printerr(f)
	quit(0 if _failures.is_empty() else 1)


func _setup_ambush(squad: Array, chokepoint: Vector2, difficulty: DifficultyData) -> Dictionary:
	var knowledge: Node = KNOWLEDGE_SCRIPT.new()
	knowledge.owner_faction_side = &"ambusher"
	knowledge.own_units_getter = Callable(func(): return squad)
	knowledge.world_units_getter = Callable(self, "_all_units")
	_world.add_child(knowledge)

	var ambush: Node = AMBUSH_SCRIPT.new()
	ambush.faction_side = &"ambusher"
	ambush.knowledge = knowledge
	ambush.difficulty = difficulty
	ambush.chokepoints = [chokepoint]
	ambush.roster_getter = Callable(func(): return squad)
	_world.add_child(ambush)
	return {"knowledge": knowledge, "ambush": ambush}


func _all_units() -> Array:
	return _world.get_children().filter(func(n): return n is BwUnit)


## A lone weak-outnumbered squad should never arm an ambush against a
## much larger observed force (utility below threshold).
func _test_no_arm_without_advantage() -> void:
	var chokepoint := Vector2(0, 0)
	var squad: Array = [_make_unit(&"ambusher", Vector2(-1000, -1000))]
	var enemies: Array = []
	for i in range(6):
		enemies.append(_make_unit(&"target", chokepoint + Vector2(i * 10, 0)))

	var setup := _setup_ambush(squad, chokepoint, load("res://data/difficulty/difficulty_medium.tres"))
	for i in range(6):
		await physics_frame

	_expect(setup["ambush"].state == AMBUSH_SCRIPT.State.IDLE, "Should not arm an ambush when badly outnumbered (no tactical advantage).")

	for u in squad + enemies:
		u.queue_free()
	setup["knowledge"].queue_free()
	setup["ambush"].queue_free()
	await physics_frame


## A strong squad with fresh intel on a lone approaching enemy near a
## chokepoint should arm, then trigger an attack once the enemy actually
## arrives.
func _test_arms_and_triggers_with_advantage() -> void:
	var chokepoint := Vector2(0, 0)
	var squad: Array = [_make_unit(&"ambusher", Vector2(-40, -40)), _make_unit(&"ambusher", Vector2(-40, 40)), _make_unit(&"ambusher", Vector2(-20, 0))]
	var lone_enemy := _make_unit(&"target", chokepoint + Vector2(300, 0))

	var setup := _setup_ambush(squad, chokepoint, load("res://data/difficulty/difficulty_hard.tres"))
	for i in range(10):
		await physics_frame
	_expect(setup["ambush"].state == AMBUSH_SCRIPT.State.ARMED, "Should arm an ambush with a strong squad and fresh intel on a lone target.")

	lone_enemy.global_position = chokepoint
	for i in range(10):
		await physics_frame
	var triggered_or_idle: bool = setup["ambush"].state == AMBUSH_SCRIPT.State.IDLE
	_expect(triggered_or_idle, "Ambush should have triggered (returns to IDLE after committing) once the target reached the chokepoint.")
	var any_attacking := false
	for u in squad:
		if is_instance_valid(u) and u.state == BwUnit.State.ATTACKING:
			any_attacking = true
	_expect(any_attacking, "Squad should be ordered to attack once the ambush triggers.")

	for u in squad:
		u.queue_free()
	lone_enemy.queue_free()
	setup["knowledge"].queue_free()
	setup["ambush"].queue_free()
	await physics_frame


## If the squad is wiped out before the target arrives, the ambush must
## cancel itself (Prompt Dasar "AI dapat membatalkan ambush jika situasi
## berubah").
func _test_cancels_when_squad_wiped() -> void:
	var chokepoint := Vector2(0, 0)
	var u1 := _make_unit(&"ambusher", Vector2(-40, -40))
	var u2 := _make_unit(&"ambusher", Vector2(-40, 40))
	var squad: Array = [u1, u2]
	var lone_enemy := _make_unit(&"target", chokepoint + Vector2(300, 0))

	var setup := _setup_ambush(squad, chokepoint, load("res://data/difficulty/difficulty_hard.tres"))
	for i in range(10):
		await physics_frame
	_expect(setup["ambush"].state == AMBUSH_SCRIPT.State.ARMED, "Should arm with an initially strong squad.")

	u1.state = BwUnit.State.DEAD
	u2.state = BwUnit.State.DEAD
	for i in range(3):
		await physics_frame
	_expect(setup["ambush"].state == AMBUSH_SCRIPT.State.IDLE, "Ambush should cancel back to IDLE once the squad is wiped before triggering.")
	_expect(setup["ambush"].last_reason.findn("no longer viable") != -1, "Cancellation reason should explain why.")

	u1.queue_free()
	u2.queue_free()
	lone_enemy.queue_free()
	setup["knowledge"].queue_free()
	setup["ambush"].queue_free()
	await physics_frame
