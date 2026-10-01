extends Node
## Per-faction strategic AI (Prompt Dasar MVP5 "STRATEGIC"). Owns every
## non-moment-to-moment economic and force-level decision for one
## AI-controlled faction: recruitment, payroll (delegated to
## CampaignEconomy's own automatic timer — nothing strategic to decide
## there beyond staying solvent), buying weapons/ammo, upgrading the
## factory, choosing which dealer to sell to, banking carried cash,
## buying/repairing vehicles, defending the HQ/factory, raiding the
## enemy's economy, and deciding whether to attack the enemy Main
## Character or wait. Ambush is delegated to a dedicated
## AmbushController (own multi-phase state machine); this class only
## decides the *raid* (proactive) and *defend* (reactive) postures plus
## the attack-MC/wait call, per Prompt Dasar's split between the two.
##
## Every decision here reads only from `knowledge` (fog-of-war) for
## enemy information — never the live enemy roster directly — so "AI
## tidak omniscient" is enforced structurally, not just by convention.

signal decision_made(category: String, reason: String)

const RUNNER_COUNT := 2 # how many of the roster are dedicated cargo/cash runners
const AMMO_RESTOCK_RATIO := 0.3 # buy more when (mag+reserve)/full <= this
const FACTORY_UPGRADE_RESERVE := 1.5 # keep this many upgrade-costs in the bank before spending on it
const RAID_MIN_SQUAD := 2
const RAID_COOLDOWN_SEC := 75.0
const ATTACK_MC_COOLDOWN_SEC := 45.0
const VEHICLE_REPAIR_CHECK_RADIUS_PX := 140.0

enum RunnerPhase { SEEK_FACTORY, SEEK_DEALER, SEEK_BANK }

var faction_side: StringName = &""
var economy: Node = null # CampaignEconomy
var knowledge: Node = null # FactionKnowledge
var difficulty: DifficultyData = null
var diplomacy: Node = null # DiplomacyController, optional

var factory: Node = null
var bank: Node = null
var garage: Node = null
var dealers: Array = [] # Array[Node] (drug_dealer.gd instances)
var hq_position: Vector2 = Vector2.ZERO
var defend_radius_px: float = 260.0

var roster_getter: Callable = Callable() # Callable() -> Array[BwUnit], all alive own units (incl. MC)
var mc_getter: Callable = Callable() # Callable() -> BwUnit or null
var enemy_mc_getter: Callable = Callable() # Callable() -> BwUnit or null (only for tests; production code should rely on knowledge)
var vehicle_data_catalog: Array = [] # Array[VehicleData], cheapest-first recommended
var vehicle_scene: PackedScene = null
var vehicles_root: Node = null
var vehicles_getter: Callable = Callable() # Callable() -> Array[Vehicle], own vehicles
## World point AI factions rally scouts toward when they have no fresh
## intel at all (Prompt Dasar "Scout"). Defaults to the world origin,
## which the map layout puts roughly between HQs; callers with a
## different layout (e.g. a specific enemy region) should override it.
var scout_rally_point: Vector2 = Vector2.ZERO

var last_reason_by_category: Dictionary = {}
## category -> last computed utility float, for the debug overlay
## (Prompt Dasar debug overlay: "Utility score"). Populated alongside
## last_reason_by_category wherever a category has a numeric utility.
var last_utility_by_category: Dictionary = {}
## Rolling label of what this faction is currently "trying to do",
## for the debug overlay's "Current objective" field.
var current_objective: String = "Idle"

var _decide_timer: float = 0.0
var _runner_phase: Dictionary = {} # unit instance id -> RunnerPhase
var _runner_dealer: Dictionary = {} # unit instance id -> dealer node
var _raid_cooldown: float = 0.0
var _attack_mc_cooldown: float = 0.0
var _last_ammo_check: float = 0.0
var _scout_unit_id: int = -1
var _scout_cooldown: float = 0.0

const SCOUT_COOLDOWN_SEC := 40.0


func _physics_process(delta: float) -> void:
	if economy == null or not roster_getter.is_valid():
		return
	if _raid_cooldown > 0.0:
		_raid_cooldown -= delta
	if _attack_mc_cooldown > 0.0:
		_attack_mc_cooldown -= delta

	var interval: float = max(0.5, difficulty.decision_interval_sec if difficulty else 1.0)
	_decide_timer -= delta
	if _decide_timer > 0.0:
		# Runners still need per-frame arrival checks even between full
		# decision passes, or they'd overshoot buildings.
		_advance_runners()
		return
	_decide_timer = interval

	current_objective = "Idle"
	_manage_recruitment()
	_manage_ammo_and_weapons()
	_manage_factory()
	_assign_runners()
	_advance_runners()
	_manage_vehicles()
	_manage_defense()
	_manage_scouting()
	_consider_raid()
	_consider_attack_mc_or_wait()


func _alive_roster() -> Array:
	var all: Array = roster_getter.call()
	return all.filter(func(u): return is_instance_valid(u) and u.state != BwUnit.State.DEAD)


func _idle_roster() -> Array:
	return _alive_roster().filter(func(u): return u.state == BwUnit.State.IDLE or u.state == BwUnit.State.PATROLLING)


## ---------------------------------------------------------------
## Recruitment (Prompt Dasar "Mengatur recruitment")
## ---------------------------------------------------------------
func _manage_recruitment() -> void:
	if economy.recruited_count >= economy.max_roster:
		return
	# Keep a cash cushion equal to one payroll cycle's worth so a new
	# hire doesn't immediately cause a missed-payroll cascade.
	var cushion: int = 400
	for tier in ["B3", "B2", "B1"]:
		if not economy.unit_data_by_tier.has(tier):
			continue
		var ud: UnitData = economy.unit_data_by_tier[tier]
		if economy.money - cushion >= ud.recruit_price and economy.try_start_recruit(tier):
			_set_reason("recruitment", "Recruiting %s ($%d, roster %d/%d)." % [tier, ud.recruit_price, economy.recruited_count, economy.max_roster])
			return


## ---------------------------------------------------------------
## Weapon/ammo buying (Prompt Dasar "Membeli weapon/ammo",
## acceptance: "AI dapat membeli ammo ketika menipis").
## ---------------------------------------------------------------
func _manage_ammo_and_weapons() -> void:
	for u in _alive_roster():
		if u.primary_weapon == null:
			continue
		var full: int = u.primary_weapon.magazine_size + u.primary_weapon.reserve_ammo
		if full <= 0:
			continue
		var current: int = u.primary_mag + u.primary_reserve
		if float(current) / float(full) > AMMO_RESTOCK_RATIO:
			continue
		var weapon_id: String = String(u.primary_weapon.id)
		if not economy.can_afford(u.primary_weapon.price):
			continue
		if economy.try_buy_weapon(weapon_id) and economy.try_assign_weapon(u, "primary", weapon_id):
			_set_reason("ammo", "Resupplied %s's %s (was %d/%d)." % [u.display_name, u.primary_weapon.display_name, current, full])
			return


## ---------------------------------------------------------------
## Factory upgrade (Prompt Dasar "Meng-upgrade pabrik")
## ---------------------------------------------------------------
func _manage_factory() -> void:
	if factory == null or not is_instance_valid(factory) or factory.is_destroyed:
		return
	var cost: int = factory.upgrade_cost()
	if cost < 0:
		return
	if economy.money >= int(cost * FACTORY_UPGRADE_RESERVE) and economy.spend(cost):
		factory.upgrade()
		_set_reason("factory", "Upgraded factory to level %d for $%d." % [factory.level, cost])


## ---------------------------------------------------------------
## Dealer selection + cash running (Prompt Dasar "Memilih dealer",
## "Menyimpan uang ke Bank").
## ---------------------------------------------------------------
func _assign_runners() -> void:
	if factory == null or not is_instance_valid(factory):
		return
	var idle: Array = _idle_roster().filter(func(u): return not _runner_phase.has(u.get_instance_id()))
	var runner_count: int = 0
	for id in _runner_phase.keys():
		runner_count += 1
	while runner_count < RUNNER_COUNT and not idle.is_empty():
		var u = idle.pop_back()
		_runner_phase[u.get_instance_id()] = RunnerPhase.SEEK_FACTORY
		runner_count += 1


func _advance_runners() -> void:
	if factory == null or not is_instance_valid(factory):
		return
	for id in _runner_phase.keys().duplicate():
		var u = instance_from_id(id)
		if u == null or not is_instance_valid(u) or u.state == BwUnit.State.DEAD:
			_runner_phase.erase(id)
			_runner_dealer.erase(id)
			continue
		if u.state == BwUnit.State.INTERACTING or u.state == BwUnit.State.DOWNED:
			continue # let combat/tactical AI or the ongoing channel finish first
		var phase: int = _runner_phase[id]
		match phase:
			RunnerPhase.SEEK_FACTORY:
				if u.carried_cargo > 0:
					_runner_phase[id] = RunnerPhase.SEEK_DEALER
					return _advance_runners_step(u, RunnerPhase.SEEK_DEALER)
				if u.global_position.distance_to(factory.global_position) <= 90.0:
					if factory.try_pickup(u):
						_runner_phase[id] = RunnerPhase.SEEK_DEALER
				else:
					u.order_move(factory.global_position)
			RunnerPhase.SEEK_DEALER:
				if u.carried_cargo <= 0:
					_runner_phase[id] = RunnerPhase.SEEK_BANK
					continue
				var dealer = _runner_dealer.get(id)
				if dealer == null or not is_instance_valid(dealer):
					dealer = _pick_best_dealer()
					_runner_dealer[id] = dealer
				if dealer == null:
					continue
				if u.global_position.distance_to(dealer.global_position) <= 80.0:
					var value: int = factory.cargo_value()
					if diplomacy:
						value = int(value * (1.0 + diplomacy.get_trade_bonus(faction_side)))
					dealer.start_sell(u, economy, value)
				else:
					u.order_move(dealer.global_position)
			RunnerPhase.SEEK_BANK:
				if u.carried_cash <= 0:
					_runner_phase.erase(id)
					_runner_dealer.erase(id)
					continue
				if bank and u.global_position.distance_to(bank.global_position) <= 100.0:
					bank.start_deposit(u)
				elif bank:
					u.order_move(bank.global_position)


func _advance_runners_step(u: BwUnit, _phase: int) -> void:
	pass # phase already updated by caller; kept as a no-op hook for clarity


func _pick_best_dealer():
	var best = null
	var best_score := -INF
	for d in dealers:
		if not is_instance_valid(d):
			continue
		var score: float = d.current_demand_multiplier() * 100.0
		if best == null or score > best_score:
			best = d
			best_score = score
	return best


## ---------------------------------------------------------------
## Vehicles (Prompt Dasar "Membeli dan memperbaiki kendaraan")
## ---------------------------------------------------------------
func _manage_vehicles() -> void:
	if garage and is_instance_valid(garage):
		garage.try_repair()
	if vehicle_scene == null or vehicles_root == null or not vehicles_getter.is_valid():
		return
	var owned: Array = vehicles_getter.call()
	if owned.size() >= 1:
		return
	if vehicle_data_catalog.is_empty():
		return
	var cheapest: VehicleData = vehicle_data_catalog[0]
	for vd in vehicle_data_catalog:
		if vd.price < cheapest.price:
			cheapest = vd
	if not economy.can_afford(cheapest.price):
		return
	if economy.spend(cheapest.price):
		var v = vehicle_scene.instantiate()
		v.vehicle_data = cheapest
		v.faction_side = faction_side
		v.position = hq_position + Vector2(randf_range(-60, 60), randf_range(80, 140))
		vehicles_root.add_child(v)
		_set_reason("vehicle", "Purchased %s for $%d." % [cheapest.display_name, cheapest.price])


## ---------------------------------------------------------------
## Defend HQ/factory (Prompt Dasar "Mempertahankan HQ/pabrik")
## ---------------------------------------------------------------
func _manage_defense() -> void:
	if knowledge == null:
		return
	var threat_near_home: int = knowledge.known_enemy_count_near(hq_position, defend_radius_px * 1.5)
	if threat_near_home <= 0:
		return
	# Idle units near home hold position/engage rather than wandering
	# off on runner duty while the HQ is under threat; tactical AI
	# still governs the actual fight once a target is visible.
	for u in _idle_roster():
		if u.global_position.distance_to(hq_position) <= defend_radius_px * 2.0:
			if _runner_phase.has(u.get_instance_id()):
				continue
			u.order_move(hq_position)
	_set_reason("defense", "%d known enemy near HQ: holding idle units in defense." % threat_near_home)
	if current_objective == "Idle":
		current_objective = "Defending HQ"


## ---------------------------------------------------------------
## Raid — attacking the enemy's economy (Prompt Dasar "Raid",
## "Menyerang rute ekonomi").
## ---------------------------------------------------------------
func _consider_raid() -> void:
	if _raid_cooldown > 0.0 or knowledge == null:
		return
	var known: Array = knowledge.get_known_enemies()
	if known.is_empty():
		return
	# Prompt Dasar: "Alliance dan betrayal memiliki konsekuensi" —
	# skip any observed faction we're currently allied with rather than
	# raiding straight through a pact we ourselves proposed.
	if diplomacy:
		known = known.filter(func(e): return not diplomacy.is_allied(faction_side, e.get("faction_side", &"")))
		if known.is_empty():
			return
	var available: Array = _idle_roster().filter(func(u): return not _runner_phase.has(u.get_instance_id()))
	if available.size() < RAID_MIN_SQUAD:
		return
	# Utility: our spare force vs. the enemy strength we've actually
	# observed near their side — a real economy-route raid needs us to
	# both have spare force AND believe the target is lightly guarded.
	var target_pos: Vector2 = known[randi() % known.size()]["position"]
	var defenders: int = knowledge.known_enemy_count_near(target_pos, 300.0)
	var utility: float = clampf(float(available.size()) / float(max(defenders, 1)) - 0.75, 0.0, 2.0)
	var threshold: float = 0.6 * (difficulty.utility_threshold_mult if difficulty else 1.0)
	last_utility_by_category["raid"] = utility
	if utility < threshold:
		_set_reason("raid", "Waiting: raid utility %.2f < threshold %.2f (defenders ~%d)." % [utility, threshold, defenders])
		return
	var squad: Array = available.slice(0, min(available.size(), defenders + 2))
	for u in squad:
		u.order_move(target_pos)
	_raid_cooldown = RAID_COOLDOWN_SEC
	current_objective = "Raiding enemy economic route"
	_set_reason("raid", "Raiding enemy economic route near %s with %d units (utility %.2f)." % [target_pos, squad.size(), utility])


## ---------------------------------------------------------------
## Attack MC or wait (Prompt Dasar "Menentukan kapan menyerang MC",
## "Menentukan kapan menunggu").
## ---------------------------------------------------------------
func _consider_attack_mc_or_wait() -> void:
	if _attack_mc_cooldown > 0.0 or knowledge == null:
		return
	var enemy_mc = null
	for c in knowledge.get_visible_enemy_units():
		if is_instance_valid(c) and c.tier_label == "MC":
			enemy_mc = c
			break
	if enemy_mc == null:
		return # no intel on the enemy MC's position at all: nothing to decide yet
	var available: Array = _idle_roster().filter(func(u): return not _runner_phase.has(u.get_instance_id()))
	var mc_guard_count: int = knowledge.known_enemy_count_near(enemy_mc.global_position, 250.0)
	var utility: float = clampf(float(available.size()) / float(max(mc_guard_count, 1)) - 1.0, 0.0, 2.0)
	var threshold: float = 0.8 * (difficulty.utility_threshold_mult if difficulty else 1.0)
	last_utility_by_category["attack_mc"] = utility
	if utility < threshold or available.size() < 2:
		_set_reason("attack_mc", "Waiting: MC assault utility %.2f < threshold %.2f (guards ~%d)." % [utility, threshold, mc_guard_count])
		return
	var squad: Array = available.slice(0, min(available.size(), mc_guard_count + 3))
	for u in squad:
		u.order_attack(enemy_mc)
	_attack_mc_cooldown = ATTACK_MC_COOLDOWN_SEC
	current_objective = "Attacking enemy Main Character"
	_set_reason("attack_mc", "Committing %d units to attack the enemy Main Character (utility %.2f)." % [squad.size(), utility])


func _set_reason(category: String, reason: String) -> void:
	last_reason_by_category[category] = reason
	decision_made.emit(category, reason)


func get_reason(category: String) -> String:
	return last_reason_by_category.get(category, "")
## ---------------------------------------------------------------
## Scouting (Prompt Dasar "INFORMATION": "Scout"). Without this, an AI
## faction that starts with zero intel would never discover the enemy
## at all and the whole STRATEGIC layer (raid/attack-MC/ambush) would
## sit permanently idle — confirmed as a real bug by this MVP's own
## required headless simulation (see docs/TEST_PLAN.md "MVP5 arena").
## ---------------------------------------------------------------
func _manage_scouting() -> void:
	if _scout_cooldown > 0.0:
		_scout_cooldown -= max(0.5, difficulty.decision_interval_sec if difficulty else 1.0)
	if not knowledge.get_known_enemies().is_empty():
		return # already have intel; no need to blind-send a scout
	var current_scout = instance_from_id(_scout_unit_id) if _scout_unit_id != -1 else null
	if current_scout and is_instance_valid(current_scout) and current_scout.state != BwUnit.State.DEAD:
		return # scout already en route/alive
	if _scout_cooldown > 0.0:
		return
	var candidates: Array = _idle_roster().filter(func(u): return not _runner_phase.has(u.get_instance_id()) and u.tier_label != "MC")
	if candidates.is_empty():
		return
	var scout = candidates[0]
	scout.order_move(scout_rally_point + Vector2(randf_range(-150, 150), randf_range(-150, 150)))
	_scout_unit_id = scout.get_instance_id()
	_scout_cooldown = SCOUT_COOLDOWN_SEC
	current_objective = "Scouting for enemy contact"
	_set_reason("scout", "No intel at all: sending %s to scout near %s." % [scout.display_name, scout_rally_point])
