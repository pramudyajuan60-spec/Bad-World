extends SceneTree
## Headless tests for Nabil-specific rules (Prompt Dasar Campaign Nabil
## section): cannot recruit surrendered enemies, DEA Armory crafts from
## Parts instead of buying with money, and City Patrol income applies
## the distance-efficiency rules. Run with:
##   godot4 --headless --path . --script res://tests/test_mvp4_nabil_specifics.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")

var _failures: Array[String] = []
var _gs: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	await _test_nabil_cannot_recruit_enemies()
	await _test_nabil_armory_crafting_uses_parts_not_money()
	await _test_nabil_patrol_income_distance_efficiency()
	_finish()


func _test_nabil_cannot_recruit_enemies() -> void:
	_gs.current_campaign_id = &"campaign_nabil"
	change_scene_to_file("res://scenes/gameplay/OpenWorldMap.tscn")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	map.economy.set_money(999999)
	var mc = map._get_main_character()

	var enemy: BwUnit = UNIT_SCENE.instantiate()
	enemy.tier_label = "B1"
	enemy.faction_side = &"enemy_dummy"
	enemy.is_recruitable_tier = true
	enemy.max_hp = 100.0
	map.enemies_root.add_child(enemy)
	await physics_frame
	enemy.take_damage(1000.0)
	await physics_frame
	_expect(enemy.state == BwUnit.State.DOWNED, "setup: enemy should be downed")

	var roster_before: int = map.economy.recruited_count
	map._on_recruit_completed(mc, enemy)
	_expect(map.economy.recruited_count == roster_before, "Nabil must not be able to recruit a surrendered/downed enemy — roster count must not change")
	_expect(enemy.faction_side == &"enemy_dummy", "the enemy must remain hostile, not switch to player side")


func _test_nabil_armory_crafting_uses_parts_not_money() -> void:
	var map = root.get_node("OpenWorldMap")
	var money_before: int = map.economy.money
	map.economy.parts = 0
	var failed: bool = map.economy.try_start_craft("weapon_pistol")
	_expect(not failed, "crafting with 0 Parts should fail")

	map.economy.parts = 200
	var ok: bool = map.economy.try_start_craft("weapon_pistol")
	_expect(ok, "crafting a pistol (40 Parts) with 200 Parts available should succeed")
	_expect(map.economy.parts == 160, "crafting should deduct exactly the Parts cost (40), got %d remaining" % map.economy.parts)
	_expect(map.economy.money == money_before, "crafting must never spend money — Nabil pays with Parts only")

	# Advance the crafting queue directly to completion.
	for i in range(30):
		map.economy._advance_armory(1.0)
	_expect(map.economy.gun_shop_inventory.get("weapon_pistol", 0) >= 1, "a completed craft should add the weapon to the shared inventory pool")


func _test_nabil_patrol_income_distance_efficiency() -> void:
	var map = root.get_node("OpenWorldMap")
	map.economy.set_money(0)
	map.economy._patrol_idle_time.clear()

	var units: Array = []
	for i in range(3):
		var u: BwUnit = UNIT_SCENE.instantiate()
		u.tier_label = "B2"
		u.faction_side = &"player"
		u.position = Vector2(i * 10, 0) # tightly clustered -> same sector
		map.units_root.add_child(u)
		units.append(u)

	# Below the 15s idle threshold: no income yet.
	map.economy.apply_patrol_income(5.0, units)
	_expect(map.economy.money == 0, "patrol income must not start before the 15s minimum idle time")

	# Push well past the threshold and accumulate income.
	map.economy.apply_patrol_income(30.0, units)
	_expect(map.economy.money > 0, "patrol income should start accruing once units have idled past the 15s minimum")

	# A lone, isolated unit should earn strictly more per-unit than one
	# of 3 clustered units in the same sector (distance-efficiency rule).
	var lone_income_economy_before: int = map.economy.money
	var lone_unit: BwUnit = UNIT_SCENE.instantiate()
	lone_unit.tier_label = "B2"
	lone_unit.faction_side = &"player"
	lone_unit.position = Vector2(5000, 5000) # far outside the clustered sector
	map.units_root.add_child(lone_unit)
	map.economy._patrol_idle_time.clear()
	map.economy.apply_patrol_income(30.0, [lone_unit])
	var lone_income: int = map.economy.money - lone_income_economy_before

	map.economy.set_money(0)
	map.economy._patrol_idle_time.clear()
	map.economy.apply_patrol_income(30.0, units) # 3 clustered units together
	var clustered_income: int = map.economy.money
	var clustered_income_per_unit: float = float(clustered_income) / 3.0
	_expect(lone_income > clustered_income_per_unit, "an isolated patroller should earn more per-unit than a crowded cluster (distance-efficiency rule), lone=%d clustered_per_unit=%.1f" % [lone_income, clustered_income_per_unit])

	for u in units:
		u.queue_free()
	lone_unit.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp4_nabil_specifics: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
