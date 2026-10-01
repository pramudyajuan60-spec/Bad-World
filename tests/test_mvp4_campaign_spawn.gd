extends SceneTree
## Headless tests for MVP4 acceptance criteria: "Semua campaign dapat
## dimulai dari menu", "Spawn, resource, unit cap, roster, dan faction
## bonus berbeda", "Nabil tidak dapat merekrut B1", "Nabil maksimal 24
## anggota di luar dirinya", "Campaign lain maksimal 30 anggota di luar
## MC", "Atha dan Fauzi tetap menjadi nama campaign di menu", "Nama
## karakter/faction resmi sesuai Prompt Dasar". Loads the real
## OpenWorldMap scene once per campaign. Run with:
##   godot4 --headless --path . --script res://tests/test_mvp4_campaign_spawn.gd

var _failures: Array[String] = []
var _gs: Node


func _initialize() -> void:
	_gs = root.get_node("GameState")
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _spawn(campaign_id: StringName):
	_gs.current_campaign_id = campaign_id
	change_scene_to_file("res://scenes/gameplay/OpenWorldMap.tscn")


func _run() -> void:
	await _test_menu_names_and_character_names()
	await _test_juan_spawn()
	await _test_zie_spawn()
	await _test_andres_spawn()
	await _test_nabil_spawn_no_b1_and_lower_cap()
	_finish()


func _test_menu_names_and_character_names() -> void:
	var db = root.get_node("CampaignDatabase")
	var fauzi = db.get_campaign(&"campaign_fauzi")
	var atha = db.get_campaign(&"campaign_atha")
	_expect(fauzi.menu_name == "Campaign Fauzi", "Fauzi's menu name must stay 'Campaign Fauzi' even though the character is Zie Vartieri")
	_expect(fauzi.main_character_name == "Zie Vartieri", "Fauzi's main character name must be 'Zie Vartieri', not 'Valtieri'")
	_expect(fauzi.faction.display_name == "Vartieri Cartel", "Fauzi's faction display name must be 'Vartieri Cartel'")
	_expect(atha.menu_name == "Campaign Atha", "Atha's menu name must stay 'Campaign Atha' even though the character is Andrés A. Násion")
	_expect(atha.main_character_name == "Andrés A. Násion", "Atha's main character name must be 'Andrés A. Násion'")


func _count_units(map, side: StringName, tier: String = "") -> int:
	var n := 0
	for u in map.units_root.get_children():
		if u is BwUnit and is_instance_valid(u) and u.faction_side == side:
			if tier == "" or u.tier_label == tier:
				n += 1
	return n


func _test_juan_spawn() -> void:
	_spawn(&"campaign_juan")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	_expect(map.economy.money == 4000, "Juan should start with $4000, got %d" % map.economy.money)
	_expect(map.economy.max_roster == 30, "Juan's faction roster cap should be 30, got %d" % map.economy.max_roster)
	_expect(_count_units(map, &"player", "MC") == 1, "Juan campaign should spawn exactly 1 MC")
	_expect(_count_units(map, &"player", "B1") == 3, "Juan campaign should spawn exactly 3 B1, got %d" % _count_units(map, &"player", "B1"))
	_expect(map._get_main_character().display_name == "Juan Bellarosa", "Juan's spawned MC display_name should be 'Juan Bellarosa'")


func _test_zie_spawn() -> void:
	_spawn(&"campaign_fauzi")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	_expect(map.economy.money == 4500, "Zie should start with $4500, got %d" % map.economy.money)
	_expect(_count_units(map, &"player", "B1") == 3, "Zie campaign should spawn exactly 3 B1 (Zie's own B1, not Juan's)")
	_expect(map._get_main_character().display_name == "Zie Vartieri", "Zie's spawned MC display_name should be 'Zie Vartieri'")
	var vehicles: Array = map._get_all_vehicles()
	_expect(vehicles.size() >= 1, "Zie should start with a pre-owned vehicle (armored SUV per Prompt Dasar), found %d" % vehicles.size())
	# Zie's Vehicle Commander ability should be present.
	var mc = map._get_main_character()
	var has_vc := false
	for a in mc.abilities:
		if a.display_name == "Vehicle Commander":
			has_vc = true
	_expect(has_vc, "Zie's Main Character should carry the Vehicle Commander ability")


func _test_andres_spawn() -> void:
	_spawn(&"campaign_atha")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	_expect(map.economy.money == 5500, "Andrés should start with $5500, got %d" % map.economy.money)
	_expect(map.factory.level == 2, "Andrés's factory should start at Level 2 per Prompt Dasar, got %d" % map.factory.level)
	_expect(map.current_faction.can_recruit_enemies, "Andrés's faction must be able to recruit surrendered enemies")
	var b1_data: UnitData = map.current_campaign.b1_unit
	var juan_b1: UnitData = root.get_node("CampaignDatabase").get_campaign(&"campaign_juan").b1_unit
	_expect(b1_data.base_hp < juan_b1.base_hp, "Andrés's B1 should be weaker (lower HP) than Juan's B1 per Prompt Dasar ('B1 lebih lemah'), got %d vs %d" % [b1_data.base_hp, juan_b1.base_hp])


func _test_nabil_spawn_no_b1_and_lower_cap() -> void:
	_spawn(&"campaign_nabil")
	await process_frame
	await process_frame
	var map = root.get_node("OpenWorldMap")
	_expect(map.economy.money == 6500, "Nabil should start with $6500, got %d" % map.economy.money)
	_expect(map.economy.max_roster == 24, "Nabil's roster cap should be 24 (not 30), got %d" % map.economy.max_roster)
	_expect(not map.current_faction.has_b1, "Nabil's faction must have has_b1 == false")
	_expect(not map.economy.unit_data_by_tier.has("B1"), "Nabil's economy.unit_data_by_tier must not contain a 'B1' entry")
	_expect(_count_units(map, &"player", "B1") == 0, "Nabil campaign must spawn zero B1 units")
	_expect(_count_units(map, &"player", "B2") == 3, "Nabil campaign should spawn exactly 3 B2 instead of B1, got %d" % _count_units(map, &"player", "B2"))
	_expect(not map.current_faction.can_recruit_enemies, "Nabil's faction must not be able to recruit surrendered enemies")
	_expect(map.current_faction.uses_armory_instead_of_gun_shop, "Nabil's faction must use the Armory instead of the Gun Shop")
	_expect(map._get_main_character().display_name == "Nabil Verhan", "Nabil's spawned MC display_name should be 'Nabil Verhan'")


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp4_campaign_spawn: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
