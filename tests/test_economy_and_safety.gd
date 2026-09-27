extends SceneTree
## Headless tests for economy/recruitment/payroll (Prompt Dasar MVP2),
## the Bank/Recruitment safe zone, and limited explosive friendly fire.
## Run with:
##   godot4 --headless --path . --script res://tests/test_economy_and_safety.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const ECONOMY_SCRIPT := preload("res://scripts/economy/campaign_economy.gd")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_economy() -> Node:
	var e := Node.new()
	e.set_script(ECONOMY_SCRIPT)
	_world.add_child(e)
	return e


func _make_unit(id: String, side: StringName, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.tier_label = "B1"
	u.faction_side = side
	u.max_hp = 100.0
	u.salary = 35
	u.move_speed_px = 0.0
	u.position = pos
	_world.add_child(u)
	return u


func _run() -> void:
	await _test_recruitment_costs_money_and_time()
	await _test_unit_cap_enforced()
	await _test_payroll_penalty_and_recovery()
	await _test_safe_zone_blocks_damage()
	await _test_explosive_friendly_fire_is_reduced_and_logged()
	_finish()


func _test_recruitment_costs_money_and_time() -> void:
	var economy := _make_economy()
	await process_frame # let _ready() load the weapon/unit catalogs
	economy.set_money(4000)

	var b1_price: int = economy.unit_data_by_tier["B1"].recruit_price
	var ok: bool = economy.try_start_recruit("B1")
	_expect(ok, "recruiting a B1 with enough money should succeed")
	_expect(economy.money == 4000 - b1_price, "recruit price should be deducted immediately (money=%d)" % economy.money)
	_expect(economy.recruited_count == 0, "the unit should not join the roster until the recruitment timer finishes")

	# Advance well past B1's recruitment timer via direct process ticks.
	# (Checking economy.recruited_count directly rather than a
	# signal-connected closure flag: GDScript lambdas capture outer
	# locals by value, so a closure can't reliably flip a caller-visible
	# flag — see docs/TEST_PLAN.md.)
	for i in range(200):
		economy._process(0.1) # 20 simulated seconds, well over B1's ~8s timer
		if economy.recruited_count >= 1:
			break
	_expect(economy.recruited_count == 1, "recruited_count should increment once the timer completes")

	economy.queue_free()
	await process_frame


func _test_unit_cap_enforced() -> void:
	var economy := _make_economy()
	await process_frame
	economy.set_money(100000)
	economy.max_roster = 1
	economy.recruited_count = 1 # roster already full
	var ok: bool = economy.try_start_recruit("B1")
	_expect(not ok, "recruiting past max_roster should fail even with unlimited money")
	_expect(economy.money == 100000, "a rejected recruit should not spend any money")

	economy.queue_free()
	await process_frame


func _test_payroll_penalty_and_recovery() -> void:
	var economy := _make_economy()
	await process_frame
	var u := _make_unit("payroll_u", &"player", Vector2.ZERO)
	economy.payroll_units = [u]

	# Not enough money to cover salary: payroll should be missed and the
	# unit penalized (Prompt Dasar: accuracy -10pt, speed -10%, morale down).
	economy.set_money(10)
	var baseline_accuracy: float = u.accuracy
	var baseline_speed: float = u.move_speed_px if u.move_speed_px > 0 else 190.0
	u.move_speed_px = baseline_speed
	economy._advance_payroll(130.0) # one full PAYROLL_INTERVAL_SEC (120s) in a single tick
	_expect(u.missed_payroll_cycles == 1, "missing payroll should record 1 missed cycle, got %d" % u.missed_payroll_cycles)
	_expect(u.morale < 100.0, "missed payroll should reduce morale below the starting 100")
	_expect(u.accuracy < baseline_accuracy, "missed payroll should apply the accuracy penalty")

	# Now with enough money: payroll succeeds and morale recovers.
	economy.set_money(10000)
	var morale_before_payment: float = u.morale
	economy._advance_payroll(130.0)
	_expect(u.missed_payroll_cycles == 0, "a paid cycle should reset missed_payroll_cycles to 0")
	_expect(u.morale > morale_before_payment, "a paid cycle should recover morale")

	u.queue_free()
	economy.queue_free()
	await process_frame


func _test_safe_zone_blocks_damage() -> void:
	var economy := _make_economy()
	await process_frame
	economy.safe_zone_points = [Vector2(0, 0)]

	var safe_unit := _make_unit("safe_u", &"player", Vector2(10, 0)) # well within the 18m radius
	safe_unit.economy = economy
	var exposed_unit := _make_unit("exposed_u", &"player", Vector2(2000, 2000)) # far outside
	exposed_unit.economy = economy
	await physics_frame

	safe_unit.take_damage(50.0)
	_expect(safe_unit.hp >= safe_unit.max_hp - 0.01, "a unit standing in a safe zone should take no damage, hp=%.1f" % safe_unit.hp)

	exposed_unit.take_damage(50.0)
	_expect(exposed_unit.hp < exposed_unit.max_hp - 0.01, "a unit far outside any safe zone should take damage normally, hp=%.1f" % exposed_unit.hp)

	safe_unit.queue_free()
	exposed_unit.queue_free()
	economy.queue_free()
	await process_frame


func _test_explosive_friendly_fire_is_reduced_and_logged() -> void:
	var attacker := _make_unit("ff_attacker", &"player", Vector2.ZERO)
	var ally := _make_unit("ff_ally", &"player", Vector2(40, 0))
	var enemy := _make_unit("ff_enemy", &"enemy_dummy", Vector2(-40, 0))
	await physics_frame

	var w := WeaponData.new()
	w.id = &"test_grenade"
	w.display_name = "Test Grenade"
	w.damage = 100.0
	w.is_explosive = true
	w.blast_radius_px = 200.0
	w.is_hitscan = true # apply instantly for a deterministic test (no travel delay)

	var logged: Array[String] = []
	var cl: Node = root.get_node_or_null("CombatLog")
	var conn := func(t): logged.append(t)
	if cl:
		cl.logged.connect(conn)

	attacker._apply_explosion(Vector2(-40, 0), w) # centered on the enemy

	_expect(enemy.hp < enemy.max_hp - 0.01, "an enemy inside the blast radius should take explosive damage")
	_expect(ally.hp < ally.max_hp - 0.01, "a friendly unit inside the blast radius should still take some damage (limited friendly fire)")
	var enemy_damage: float = enemy.max_hp - enemy.hp
	var ally_damage: float = ally.max_hp - ally.hp
	_expect(ally_damage < enemy_damage, "friendly-fire damage should be reduced relative to the equivalent hostile-side damage (ally=%.1f, enemy=%.1f)" % [ally_damage, enemy_damage])

	var warned := false
	for line in logged:
		if line.findn("friendly-fire") != -1:
			warned = true
	_expect(warned, "a friendly-fire hit should produce a CombatLog warning")

	if cl:
		cl.logged.disconnect(conn)
	attacker.queue_free()
	ally.queue_free()
	enemy.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] economy_and_safety: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
