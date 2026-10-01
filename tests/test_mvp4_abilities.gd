extends SceneTree
## Headless tests for MVP4 abilities (Prompt Dasar acceptance criterion:
## "Ability mempunyai cooldown, feedback, dan counterplay"). Exercises
## real BwUnit instances with real AbilityData resources, not mocks.
## Run with:
##   godot4 --headless --path . --script res://tests/test_mvp4_abilities.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")

var _failures: Array[String] = []
var _world: Node2D
var _combat_log: Node
var _logged: Array[String] = []


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	_combat_log = root.get_node("CombatLog")
	_combat_log.logged.connect(_on_logged)
	call_deferred("_run")


func _on_logged(text: String) -> void:
	_logged.append(text)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_mc(id: String, abilities: Array) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.tier_label = "MC"
	u.faction_side = &"player"
	u.max_hp = 130.0
	u.accuracy = 0.65
	u.move_speed_px = 0.0
	u.abilities = abilities
	u.position = Vector2.ZERO
	_world.add_child(u)
	return u


func _run() -> void:
	await _test_cooldown_enforced_and_feedback_logged()
	await _test_assassinate_counterplay_caps_mc_special_damage()
	await _test_command_surge_squad_buff_capped_and_not_stackable()
	await _test_deceptive_assault_self_buff_expires()
	await _test_aura_boosts_nearby_regular_units()
	_finish()


func _test_cooldown_enforced_and_feedback_logged() -> void:
	var assassinate: AbilityData = load("res://data/abilities/assassinate.tres")
	var mc := _make_mc("cd_mc", [assassinate])
	var target := _make_mc("cd_target", [])
	target.tier_label = "B1"
	target.faction_side = &"enemy_dummy"
	target.max_hp = 100.0
	mc.attack_target = target
	_logged.clear()

	_expect(mc.can_use_ability(assassinate.id), "ability should be usable before its first use")
	var used1: bool = mc.try_use_ability(assassinate.id)
	_expect(used1, "first use of an off-cooldown ability should succeed")
	_expect(mc.get_ability_cooldown_remaining(assassinate.id) > 0.0, "cooldown should be > 0 immediately after use")
	var used2: bool = mc.try_use_ability(assassinate.id)
	_expect(not used2, "using an ability while on cooldown must fail")

	var found_feedback := false
	for line in _logged:
		if line.findn("used Assassinate") != -1:
			found_feedback = true
	_expect(found_feedback, "using an ability should produce visible CombatLog feedback")

	mc.queue_free()
	target.queue_free()
	await process_frame


func _test_assassinate_counterplay_caps_mc_special_damage() -> void:
	var assassinate: AbilityData = load("res://data/abilities/assassinate.tres")
	var mc := _make_mc("counter_mc", [assassinate])

	var enemy_mc := _make_mc("counter_enemy_mc", [])
	enemy_mc.faction_side = &"enemy_dummy"
	enemy_mc.max_hp = 130.0
	mc.attack_target = enemy_mc
	mc.try_use_ability(assassinate.id)
	var floor_hp: float = enemy_mc.max_hp * assassinate.max_target_damage_cap_fraction
	_expect(enemy_mc.hp >= floor_hp - 0.01, "Assassinate must not reduce a MC target below its damage-cap floor (%.1f), got %.1f" % [floor_hp, enemy_mc.hp])
	_expect(enemy_mc.state != BwUnit.State.DOWNED, "Assassinate's one-hit-kill counterplay means a full-HP MC target should survive a single use, still standing")

	var enemy_b1 := _make_mc("counter_enemy_b1", [])
	enemy_b1.tier_label = "B1"
	enemy_b1.faction_side = &"enemy_dummy"
	enemy_b1.max_hp = 100.0
	mc._ability_cooldowns.clear()
	mc.attack_target = enemy_b1
	mc.try_use_ability(assassinate.id)
	_expect(enemy_b1.hp <= 0.01, "Assassinate against a regular B1 (no counterplay cap applies) should deal its full damage, hp=%.1f" % enemy_b1.hp)

	mc.queue_free()
	enemy_mc.queue_free()
	enemy_b1.queue_free()
	await process_frame


func _test_command_surge_squad_buff_capped_and_not_stackable() -> void:
	var command_surge: AbilityData = load("res://data/abilities/command_surge.tres")
	var mc := _make_mc("surge_mc", [command_surge])
	var allies: Array = []
	for i in range(10): # more than max_targets (8), proves the cap
		var a := _make_mc("surge_ally_%d" % i, [])
		a.tier_label = "B1"
		a.position = Vector2(i * 5, 0) # all well within radius_px
		allies.append(a)

	mc.try_use_ability(command_surge.id)
	var buffed := 0
	for a in allies:
		if a.temp_damage_mult > 1.0:
			buffed += 1
	_expect(buffed == command_surge.max_targets, "Command Surge should buff at most max_targets (%d) allies, buffed %d" % [command_surge.max_targets, buffed])
	for a in allies:
		if a.temp_damage_mult > 1.0:
			_expect(is_equal_approx(a.temp_damage_mult, command_surge.damage_mult), "buffed damage_mult should equal the ability's damage_mult exactly once (not stacked)")

	# Re-triggering while some allies are still buffed must refresh, not stack.
	mc._ability_cooldowns.clear()
	mc.try_use_ability(command_surge.id)
	for a in allies:
		if a.temp_damage_mult > 1.0:
			_expect(is_equal_approx(a.temp_damage_mult, command_surge.damage_mult), "re-using Command Surge must not multiply the buff further (not stackable)")

	mc.queue_free()
	for a in allies:
		a.queue_free()
	await process_frame


func _test_deceptive_assault_self_buff_expires() -> void:
	var deceptive: AbilityData = load("res://data/abilities/deceptive_assault.tres")
	var mc := _make_mc("deceptive_mc", [deceptive])
	var baseline: float = mc._effective_accuracy()
	mc.try_use_ability(deceptive.id)
	var buffed: float = mc._effective_accuracy()
	_expect(buffed > baseline, "Deceptive Assault should temporarily raise effective accuracy (baseline %.2f -> %.2f)" % [baseline, buffed])

	# Counterplay: the buff is temporary — force-expire it and confirm it
	# actually reverts (proving it isn't a permanent stat change). Must
	# be a small *positive* value so _physics_process's decay branch
	# (`if _temp_buff_timer > 0.0`) actually runs the reset; setting it
	# to exactly 0.0 would skip that branch entirely.
	mc._temp_buff_timer = 0.001
	mc._physics_process(0.016)
	var after_expiry: float = mc._effective_accuracy()
	_expect(is_equal_approx(after_expiry, baseline), "Deceptive Assault's bonus must expire back to baseline, not persist permanently")

	mc.queue_free()
	await process_frame


func _test_aura_boosts_nearby_regular_units() -> void:
	var tactical_link: AbilityData = load("res://data/abilities/tactical_link.tres")
	var mc := _make_mc("aura_mc", [tactical_link])
	var nearby := _make_mc("aura_nearby", [])
	nearby.tier_label = "B1"
	nearby.position = Vector2(50, 0) # within tactical_link.radius_px

	nearby._refresh_aura_bonuses()
	_expect(nearby.aura_accuracy_bonus > 0.0, "a regular unit near a Tactical Link MC should gain an aura accuracy bonus")

	var far := _make_mc("aura_far", [])
	far.tier_label = "B1"
	far.position = Vector2(tactical_link.radius_px + 500.0, 0) # well outside radius
	far._refresh_aura_bonuses()
	_expect(far.aura_accuracy_bonus == 0.0, "counterplay: a unit outside the aura radius should get no bonus — isolating/killing the MC removes the aura")

	mc.queue_free()
	nearby.queue_free()
	far.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp4_abilities: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
