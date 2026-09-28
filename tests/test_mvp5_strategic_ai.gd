extends SceneTree
## MVP5 "STRATEGIC" AI layer, isolated from full combat: recruitment,
## ammo/weapon buying when low, factory upgrade, dealer selection +
## cash-running to the Bank, and vehicle purchase — the acceptance
## criteria "AI dapat menyelesaikan economy loop sendiri" and "AI dapat
## membeli ammo ketika menipis" tested directly against real
## CampaignEconomy/Factory/Bank/DrugDealer/Vehicle instances. Raid and
## attack-MC utility gating are exercised together with real combat by
## the AiMatchArena in test_mvp5_arena.gd instead, since they need
## another live faction to be meaningful.
##
## Run: godot4 --headless --path . --script res://tests/test_mvp5_strategic_ai.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const FACTORY_SCRIPT := preload("res://scripts/economy/factory.gd")
const BANK_SCRIPT := preload("res://scripts/economy/bank_building.gd")
const GARAGE_SCRIPT := preload("res://scripts/economy/garage_building.gd")
const DEALER_SCRIPT := preload("res://scripts/economy/drug_dealer.gd")
const ECONOMY_SCRIPT := preload("res://scripts/economy/campaign_economy.gd")
const STRATEGIC_AI_SCRIPT := preload("res://scripts/ai/faction_strategic_ai.gd")
const KNOWLEDGE_SCRIPT := preload("res://scripts/ai/faction_knowledge.gd")
const VEHICLE_SCENE := preload("res://scenes/gameplay/Vehicle.tscn")
const COMPACT_VEHICLE_DATA := preload("res://data/vehicles/compact.tres")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _attach_shape(area: Area2D, radius: float) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 1


func _run() -> void:
	var campaign: CampaignData = load("res://data/campaigns/campaign_juan.tres")
	var difficulty: DifficultyData = load("res://data/difficulty/difficulty_medium.tres")

	var economy: Node = ECONOMY_SCRIPT.new()
	_world.add_child(economy)
	economy.configure_roster(campaign)
	economy.set_money(20000) # generous but finite, so spend/no-spend decisions are meaningful
	economy.max_roster = 10

	var factory := FACTORY_SCRIPT.new()
	factory.faction_side = &"ai_test"
	factory.position = Vector2(300, 200)
	_attach_shape(factory, 80.0)
	_world.add_child(factory)

	var bank := BANK_SCRIPT.new()
	bank.economy = economy
	bank.position = Vector2(-180, -60)
	_attach_shape(bank, 90.0)
	_world.add_child(bank)

	var garage := GARAGE_SCRIPT.new()
	garage.economy = economy
	garage.position = Vector2(-180, 120)
	_attach_shape(garage, 90.0)
	_world.add_child(garage)

	var dealer := DEALER_SCRIPT.new()
	dealer.dealer_label = "Test Dealer"
	dealer.position = Vector2(500, -260)
	_attach_shape(dealer, 70.0)
	_world.add_child(dealer)

	var knowledge: Node = KNOWLEDGE_SCRIPT.new()
	knowledge.owner_faction_side = &"ai_test"
	knowledge.own_units_getter = Callable(self, "_own_units")
	knowledge.world_units_getter = Callable(self, "_all_units")
	_world.add_child(knowledge)

	var sai: Node = STRATEGIC_AI_SCRIPT.new()
	sai.faction_side = &"ai_test"
	sai.economy = economy
	sai.knowledge = knowledge
	sai.difficulty = difficulty
	sai.factory = factory
	sai.bank = bank
	sai.garage = garage
	sai.dealers = [dealer]
	sai.hq_position = Vector2.ZERO
	sai.roster_getter = Callable(self, "_own_units")
	sai.vehicle_scene = VEHICLE_SCENE
	sai.vehicle_data_catalog = [COMPACT_VEHICLE_DATA]
	sai.vehicles_root = _world
	sai.vehicles_getter = Callable(self, "_own_vehicles")
	_world.add_child(sai)

	# Seed one starving-ammo unit and one full-ammo unit so both the
	# "should resupply" and "should not waste money resupplying a full
	# unit" paths get exercised.
	var low_ammo_unit: BwUnit = _make_unit(&"ai_test", "B2", Vector2(20, 20))
	low_ammo_unit.economy = economy
	low_ammo_unit.equip_weapon("primary", economy.weapon_catalog["weapon_assault_rifle"])
	low_ammo_unit.primary_mag = 2
	low_ammo_unit.primary_reserve = 0

	var full_ammo_unit: BwUnit = _make_unit(&"ai_test", "B2", Vector2(-20, -20))
	full_ammo_unit.economy = economy
	full_ammo_unit.equip_weapon("primary", economy.weapon_catalog["weapon_assault_rifle"])

	var starting_money: int = economy.money

	# Run enough decision ticks + production/travel time for the full
	# recruit -> pickup -> sell -> bank loop and the ammo/vehicle
	# purchases to complete without any human/test intervention.
	for i in range(1500):
		await physics_frame

	_expect(economy.recruited_count > 0 or economy.money < starting_money, "Strategic AI should have taken at least one economic action (recruit/buy) over 400 ticks.")
	_expect(economy.recruited_count > 0, "Strategic AI should have completed at least one recruitment over the full simulated window (acceptance: 'AI dapat menyelesaikan economy loop sendiri').")
	_expect(low_ammo_unit.primary_mag + low_ammo_unit.primary_reserve > 2, "Strategic AI should have resupplied the low-ammo unit (acceptance: 'AI dapat membeli ammo ketika menipis').")
	_expect(economy.money != starting_money, "Strategic AI's economy loop should have changed the money balance over time (spending and/or earning).")
	var vehicles: Array = _own_vehicles()
	_expect(not vehicles.is_empty(), "Strategic AI should have purchased at least one vehicle when it could afford to.")

	if _failures.is_empty():
		print("[Tests] mvp5_strategic_ai: all passed. (money %d -> %d, recruited %d, vehicles %d)" % [starting_money, economy.money, economy.recruited_count, vehicles.size()])
	else:
		for f in _failures:
			printerr(f)
	quit(0 if _failures.is_empty() else 1)


func _make_unit(side: StringName, tier: String, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName("u_%d_%d" % [Time.get_ticks_usec(), randi()])
	u.faction_side = side
	u.tier_label = tier
	u.position = pos
	_world.add_child(u)
	return u


func _own_units() -> Array:
	return _world.get_children().filter(func(n): return n is BwUnit and n.faction_side == &"ai_test" and is_instance_valid(n) and n.state != BwUnit.State.DEAD)


func _all_units() -> Array:
	return _world.get_children().filter(func(n): return n is BwUnit)


func _own_vehicles() -> Array:
	return _world.get_children().filter(func(n): return n is Vehicle and is_instance_valid(n))
