class_name AiMatchArena
extends Node2D
## Headless AI-vs-AI match harness (Prompt Dasar MVP5 acceptance:
## "Headless simulation dapat berjalan untuk beberapa match", "Laporkan
## hasil win-rate awal per faction/difficulty"). Wires up N complete,
## independent per-faction economies (Factory/Bank/Garage/Dealers +
## roster) each driven entirely by FactionStrategicAI + UnitTacticalAI
## + FactionKnowledge + AmbushController, with real BwUnit combat and
## real NavigationAgent2D pathing — the same components MVP1-4 already
## ship and test, just now decided by AI instead of a human/test
## script. Callers (tests, or a future in-game spectator mode) call
## setup() then await run_until_resolved().

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const FACTORY_SCRIPT := preload("res://scripts/economy/factory.gd")
const BANK_SCRIPT := preload("res://scripts/economy/bank_building.gd")
const GARAGE_SCRIPT := preload("res://scripts/economy/garage_building.gd")
const DEALER_SCRIPT := preload("res://scripts/economy/drug_dealer.gd")
const ECONOMY_SCRIPT := preload("res://scripts/economy/campaign_economy.gd")
const TACTICAL_AI_SCRIPT := preload("res://scripts/ai/unit_tactical_ai.gd")
const STRATEGIC_AI_SCRIPT := preload("res://scripts/ai/faction_strategic_ai.gd")
const KNOWLEDGE_SCRIPT := preload("res://scripts/ai/faction_knowledge.gd")
const AMBUSH_SCRIPT := preload("res://scripts/ai/ambush_controller.gd")
const VEHICLE_SCENE := preload("res://scenes/gameplay/Vehicle.tscn")
const COMPACT_VEHICLE_DATA := preload("res://data/vehicles/compact.tres")

const STARTING_GRUNTS := 3
const HQ_SPACING_PX := 1400.0

class FactionRuntime:
	var faction_side: StringName
	var campaign: CampaignData
	var difficulty: DifficultyData
	var economy: Node
	var knowledge: Node
	var strategic_ai: Node
	var ambush: Node
	var factory: Node
	var bank: Node
	var garage: Node
	var dealers: Array = []
	var hq_position: Vector2
	var all_spawned_units: Array = [] # ever-spawned, for elimination checks (dead ones stay counted)
	var units_root: Node

var _factions: Array = [] # Array[FactionRuntime]
var diplomacy: Node = null
var _clock_sec: float = 0.0
var _combat_log_stub: Node = null


func setup(faction_configs: Array) -> void:
	# Bare CombatLog stand-in: unit.gd caches "/root/CombatLog" once at
	# _ready() time; in a real game this is the autoload, but a
	# standalone arena node (not the game's own scene tree root) has no
	# such singleton, so units just log nowhere here. That's fine —
	# this harness doesn't assert on combat-log text, only on outcomes.
	var nav_region := NavigationRegion2D.new()
	var half: float = HQ_SPACING_PX * max(1, faction_configs.size())
	var poly := NavigationPolygon.new()
	poly.add_outline(PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	]))
	poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = poly
	add_child(nav_region)

	diplomacy = DiplomacyControllerScript().new()
	diplomacy.neutral_faction = load("res://data/neutral/neutral_riverside_crew.tres")
	add_child(diplomacy)

	var n: int = faction_configs.size()
	for i in range(n):
		var cfg: Dictionary = faction_configs[i]
		var angle: float = TAU * float(i) / float(max(n, 1))
		var hq_pos: Vector2 = Vector2(cos(angle), sin(angle)) * HQ_SPACING_PX
		_build_faction(cfg, hq_pos)


func _build_faction(cfg: Dictionary, hq_pos: Vector2) -> void:
	var fr := FactionRuntime.new()
	fr.faction_side = cfg.get("faction_side", StringName("faction_%d" % _factions.size()))
	fr.campaign = cfg["campaign"]
	fr.difficulty = cfg["difficulty"]
	fr.hq_position = hq_pos

	fr.units_root = Node2D.new()
	add_child(fr.units_root)

	fr.economy = ECONOMY_SCRIPT.new()
	add_child(fr.economy)
	fr.economy.configure_roster(fr.campaign)
	fr.economy.set_money(fr.campaign.starting_money)
	fr.economy.lifetime_money_earned = 0 # starting funds aren't "earned" — see open_world_map.gd's identical fix
	fr.economy.max_roster = fr.campaign.faction.max_roster if fr.campaign.faction else 15

	fr.factory = FACTORY_SCRIPT.new()
	fr.factory.faction_side = fr.faction_side
	fr.factory.value_mult = fr.campaign.faction.factory_value_mult if fr.campaign.faction else 1.0
	fr.factory.speed_mult = fr.campaign.faction.factory_speed_mult if fr.campaign.faction else 1.0
	fr.factory.position = hq_pos + Vector2(220, 140)
	_attach_shape(fr.factory, 80.0)
	add_child(fr.factory)

	fr.bank = BANK_SCRIPT.new()
	fr.bank.economy = fr.economy
	fr.bank.position = hq_pos + Vector2(-180, -60)
	_attach_shape(fr.bank, 90.0)
	add_child(fr.bank)

	fr.garage = GARAGE_SCRIPT.new()
	fr.garage.economy = fr.economy
	fr.garage.position = hq_pos + Vector2(-180, 120)
	_attach_shape(fr.garage, 90.0)
	add_child(fr.garage)

	for j in range(2):
		var dealer = DEALER_SCRIPT.new()
		dealer.dealer_label = "Dealer %d (%s)" % [j, fr.faction_side]
		dealer.position = hq_pos + Vector2(400 + j * 220, -260)
		_attach_shape(dealer, 70.0)
		add_child(dealer)
		fr.dealers.append(dealer)

	fr.knowledge = KNOWLEDGE_SCRIPT.new()
	fr.knowledge.owner_faction_side = fr.faction_side
	fr.knowledge.own_units_getter = Callable(self, "_get_alive_units").bind(fr)
	fr.knowledge.world_units_getter = Callable(self, "_get_all_units")
	add_child(fr.knowledge)

	fr.ambush = AMBUSH_SCRIPT.new()
	fr.ambush.faction_side = fr.faction_side
	fr.ambush.knowledge = fr.knowledge
	fr.ambush.difficulty = fr.difficulty
	fr.ambush.chokepoints = [Vector2.ZERO] # the shared center point between all HQs
	fr.ambush.roster_getter = Callable(self, "_get_idle_non_runner_units").bind(fr)
	add_child(fr.ambush)

	fr.strategic_ai = STRATEGIC_AI_SCRIPT.new()
	fr.strategic_ai.faction_side = fr.faction_side
	fr.strategic_ai.economy = fr.economy
	fr.strategic_ai.knowledge = fr.knowledge
	fr.strategic_ai.difficulty = fr.difficulty
	fr.strategic_ai.diplomacy = diplomacy
	fr.strategic_ai.factory = fr.factory
	fr.strategic_ai.bank = fr.bank
	fr.strategic_ai.garage = fr.garage
	fr.strategic_ai.dealers = fr.dealers
	fr.strategic_ai.hq_position = hq_pos
	fr.strategic_ai.roster_getter = Callable(self, "_get_alive_units").bind(fr)
	fr.strategic_ai.vehicle_scene = VEHICLE_SCENE
	fr.strategic_ai.vehicle_data_catalog = [COMPACT_VEHICLE_DATA]
	fr.strategic_ai.vehicles_root = fr.units_root
	fr.strategic_ai.vehicles_getter = Callable(self, "_get_faction_vehicles").bind(fr)
	add_child(fr.strategic_ai)

	var mc := _spawn_unit(fr, "MC", "MC", hq_pos)
	fr.strategic_ai.mc_getter = Callable(func(): return mc if is_instance_valid(mc) else null)
	for k in range(STARTING_GRUNTS):
		_spawn_unit(fr, "grunt_%d" % k, "B2", hq_pos + Vector2(randf_range(-80, 80), randf_range(80, 160)))

	_factions.append(fr)


func _attach_shape(area: Area2D, radius: float) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 1


func _spawn_unit(fr: FactionRuntime, id: String, tier: String, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.display_name = "%s %s" % [fr.faction_side, id]
	u.tier_label = tier
	u.faction_side = fr.faction_side
	u.economy = fr.economy
	u.vision_range_px = 480.0
	match tier:
		"MC":
			u.unit_data = fr.campaign.mc_unit
		"B1":
			u.unit_data = fr.campaign.b1_unit
		"B2":
			u.unit_data = fr.campaign.b2_unit
		"B3":
			u.unit_data = fr.campaign.b3_unit
	u.position = pos
	fr.units_root.add_child(u)
	u.equip_weapon("primary", fr.economy.weapon_catalog.get("weapon_assault_rifle"))
	fr.all_spawned_units.append(u)

	var tai := TACTICAL_AI_SCRIPT.new()
	tai.unit = u
	tai.knowledge = fr.knowledge
	tai.difficulty = fr.difficulty
	tai.main_character_getter = Callable(self, "_get_faction_mc").bind(fr)
	u.add_child(tai)
	return u


func _get_faction_mc(fr: FactionRuntime):
	for u in fr.all_spawned_units:
		if is_instance_valid(u) and u.tier_label == "MC":
			return u
	return null


func _get_alive_units(fr: FactionRuntime) -> Array:
	return fr.all_spawned_units.filter(func(u): return is_instance_valid(u) and u.state != BwUnit.State.DEAD)


func _get_idle_non_runner_units(fr: FactionRuntime) -> Array:
	return _get_alive_units(fr).filter(func(u): return u.state == BwUnit.State.IDLE)


func _get_all_units() -> Array:
	var all: Array = []
	for fr in _factions:
		for u in fr.all_spawned_units:
			if is_instance_valid(u):
				all.append(u)
	return all


func _get_faction_vehicles(fr: FactionRuntime) -> Array:
	var result: Array = []
	for child in fr.units_root.get_children():
		if child is Vehicle and is_instance_valid(child):
			result.append(child)
	return result


## A match resolves once a faction's Main Character is eliminated
## (Prompt Dasar treats "Menentukan kapan menyerang MC" as the
## decisive objective) rather than requiring every ever-recruited unit
## dead — with ongoing recruitment/revival on both sides, "wipe the
## entire roster" could drag on indefinitely without ever being a
## meaningful signal, whereas MC death is a real, single, decisive event.
func is_faction_eliminated(faction_side: StringName) -> bool:
	for fr in _factions:
		if fr.faction_side != faction_side:
			continue
		var mc = _get_faction_mc(fr)
		if mc == null or not is_instance_valid(mc):
			return true # MC was never spawned or already freed: treat as eliminated
		return mc.state == BwUnit.State.DEAD
	return true


## Runs real physics frames until exactly one faction has surviving
## units (or the timeout elapses). Returns {"winner": StringName or
## "timeout"/"draw", "elapsed_sec": float}.
func run_until_resolved(tree: SceneTree, max_sec: float) -> Dictionary:
	var elapsed := 0.0
	var step_sec: float = 1.0 / float(max(Engine.physics_ticks_per_second, 1))
	while elapsed < max_sec:
		await tree.physics_frame
		elapsed += step_sec
		var alive_sides: Array = []
		for fr in _factions:
			if not is_faction_eliminated(fr.faction_side):
				alive_sides.append(fr.faction_side)
		if alive_sides.size() <= 1:
			return {"winner": (alive_sides[0] if alive_sides.size() == 1 else "draw"), "elapsed_sec": elapsed}
	return {"winner": "timeout", "elapsed_sec": elapsed}


func DiplomacyControllerScript() -> Script:
	return load("res://scripts/diplomacy/diplomacy_controller.gd")


func free_all() -> void:
	queue_free()


## ---------------------------------------------------------------
## MVP7 balance-report read-only accessors (tools/run_balance_report.gd).
## Deliberately narrow getters rather than exposing _factions/
## FactionRuntime directly, so the reporting tool can't accidentally
## mutate match state.
## ---------------------------------------------------------------
func get_faction_sides() -> Array:
	return _factions.map(func(fr): return fr.faction_side)


func get_money(faction_side: StringName) -> int:
	for fr in _factions:
		if fr.faction_side == faction_side:
			return fr.economy.money
	return 0


## Gross money earned (sales + deposits etc., never decremented by
## spending — see CampaignEconomy.lifetime_money_earned), the honest
## basis for an "income per minute" report metric. `get_money()` above
## is a net balance and can legitimately go *down* over a match purely
## from aggressive AI spending, which would misreport as negative
## income if used for that purpose.
func get_lifetime_money_earned(faction_side: StringName) -> int:
	for fr in _factions:
		if fr.faction_side == faction_side:
			return fr.economy.lifetime_money_earned
	return 0


func get_army_size(faction_side: StringName) -> int:
	for fr in _factions:
		if fr.faction_side == faction_side:
			return _get_alive_units(fr).size()
	return 0


func get_vehicle_count(faction_side: StringName) -> int:
	for fr in _factions:
		if fr.faction_side == faction_side:
			return _get_faction_vehicles(fr).size()
	return 0


## Connects `callback` (no args) to every faction's AmbushController
## ambush_triggered signal, so a caller can count real ambush
## commitments across a match without reaching into _factions itself.
func connect_ambush_triggered(callback: Callable) -> void:
	for fr in _factions:
		if fr.ambush:
			fr.ambush.ambush_triggered.connect(func(_cp, _squad): callback.call())
