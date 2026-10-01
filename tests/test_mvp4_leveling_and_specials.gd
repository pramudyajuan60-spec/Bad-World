extends SceneTree
## Headless tests for Main Character leveling (Prompt Dasar "MAIN
## CHARACTER" upgrade, levels 2-5, capped bonuses) and Special unit
## unlock/uniqueness (Prompt Dasar: "Special unlock dan harga
## berfungsi", "Setiap special adalah unit unik, maksimal satu").
## Loads the real OpenWorldMap scene. Run with:
##   godot4 --headless --path . --script res://tests/test_mvp4_leveling_and_specials.gd

var _failures: Array[String] = []
var _gs: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	await _test_mc_level_costs_and_capped_bonuses()
	await _test_special_locked_until_level_4_and_unique()
	_finish()


func _test_mc_level_costs_and_capped_bonuses() -> void:
	_gs.current_campaign_id = &"campaign_juan"
	change_scene_to_file("res://scenes/gameplay/OpenWorldMap.tscn")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	var mc = map._get_main_character()
	var base_hp: float = mc.max_hp

	_expect(mc.mc_level == 1, "MC should start at level 1")
	_expect(mc.mc_upgrade_cost() == 1000, "level 2 upgrade cost should be $1000 per Prompt Dasar, got %d" % mc.mc_upgrade_cost())

	map.economy.set_money(0)
	_expect(not map.economy.spend(1000), "sanity: spend should fail with $0 money")
	map.economy.set_money(20000)
	for expected_cost in [1000, 2000, 3500, 5500]:
		var cost: int = mc.mc_upgrade_cost()
		_expect(cost == expected_cost, "expected upgrade cost $%d, got $%d at level %d" % [expected_cost, cost, mc.mc_level])
		map._on_mc_upgrade_pressed()

	_expect(mc.mc_level == 5, "MC should reach level 5 after 4 upgrades, got %d" % mc.mc_level)
	_expect(mc.mc_upgrade_cost() == -1, "mc_upgrade_cost() should return -1 (no further upgrade) at max level")
	_expect(not mc.mc_upgrade(), "mc_upgrade() should refuse to exceed MC_MAX_LEVEL")

	var expected_max_hp: float = base_hp * 1.20 # Prompt Dasar cap: "Maksimal +20% HP"
	_expect(is_equal_approx(mc.max_hp, expected_max_hp), "MC max_hp at level 5 should be exactly +20%% of base (%.1f), got %.1f" % [expected_max_hp, mc.max_hp])
	_expect(is_equal_approx(mc.mc_damage_bonus_mult(), 1.08), "MC damage bonus at level 5 should be exactly +8%%, got %.3f" % mc.mc_damage_bonus_mult())
	_expect(is_equal_approx(mc.mc_cooldown_reduction_mult(), 0.85), "MC cooldown reduction at level 5 should be exactly -15%%, got %.3f" % mc.mc_cooldown_reduction_mult())


func _test_special_locked_until_level_4_and_unique() -> void:
	_gs.current_campaign_id = &"campaign_juan"
	change_scene_to_file("res://scenes/gameplay/OpenWorldMap.tscn")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	var mc = map._get_main_character()
	map.economy.set_money(999999)

	_expect(not map.can_recruit_special(0), "Special should be locked while MC is below level 4")
	_expect(not map.try_recruit_special(0), "try_recruit_special must refuse while locked")

	for i in range(3): # reach level 4
		map._on_mc_upgrade_pressed()
	_expect(mc.mc_level == 4, "setup: MC should be level 4 now")

	_expect(map.can_recruit_special(0), "Special should unlock at MC level 4")
	var money_before_recruit: int = map.economy.money
	var ok: bool = map.try_recruit_special(0)
	_expect(ok, "recruiting an unlocked, affordable Special should succeed")
	_expect(map.special_unit_instances.size() == 1, "exactly 1 Special should now be in special_unit_instances")

	# Uniqueness: cannot recruit the same special twice.
	var ok2: bool = map.try_recruit_special(0)
	_expect(not ok2, "recruiting the same Special index a second time must fail (each Special is unique, max one)")
	_expect(map.special_unit_instances.size() == 1, "Special count must not have increased on the duplicate attempt")

	# Price actually charged.
	var special_data: UnitData = map.current_campaign.special_units[0]
	_expect(map.economy.money == money_before_recruit - special_data.recruit_price, "recruiting a Special should deduct its exact recruit_price")


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp4_leveling_and_specials: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
