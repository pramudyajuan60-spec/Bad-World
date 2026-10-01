class_name BwUnit
extends CharacterBody2D
## Generic RTS unit spanning Main Character, B1/B2/B3, and the dummy
## enemy squad. MVP 2 adds real weapon-data-driven combat (accuracy,
## range, rate of fire, reload, ammo, line-of-sight, hitscan/projectile),
## Defend/Cover Mode, suppression + simple retreat, downed/revive/
## execution, and enemy recruitment. Combat numbers not specified by
## Prompt Dasar's BALANCE V0.1 (rate of fire, reload time, range,
## revive/recruit channel durations, cover/friendly-fire percentages) are
## MVP2 design assumptions documented in docs/TECH_DECISIONS.md and
## docs/BALANCE.md.
##
## In-world visuals (body/ring/health bar) remain procedurally drawn
## placeholders — see docs/PLACEHOLDER_REGISTER.md.

signal died(unit)
signal hp_changed(unit, ratio)
signal selection_changed(unit, is_selected)
signal downed(unit)
signal revived(unit)
signal recruit_completed(recruiter, target)
## Emitted the instant a carrying unit goes down, so the owning scene can
## spawn a world-pickup for the lost cargo/cash (see cash_drop.gd). Not
## emitted if the unit was carrying nothing.
signal loot_dropped(position: Vector2, cargo: int, cash: int)

enum State {
	IDLE, MOVING, ATTACK_MOVING, ATTACKING, DEFENDING, MOVING_TO_COVER,
	DOWNED, REVIVING, EXECUTING, RECRUITING, RETREATING, DEAD,
	INTERACTING, PATROLLING,
}

## -------------------------------------------------------------------
## Tunable MVP2 assumptions (see docs/TECH_DECISIONS.md for rationale)
## -------------------------------------------------------------------
const COVER_DAMAGE_REDUCTION := 0.35
const COVER_SEARCH_RADIUS := 420.0
const SUPPRESSION_PER_HIT := 25.0
## MVP4 addition: Special/MC tiers are veteran, hardened combatants and
## intrinsically resist suppression more than regular grunts (Prompt
## Dasar doesn't specify a tier/suppression relationship — this is a
## documented balance assumption, see docs/BALANCE.md "Special/MC
## suppression resistance", surfaced by writing the required MVP4
## balance simulation: without it, any single high-value unit facing
## several simultaneous attackers gets suppression-locked into an
## unbreakable retreat loop regardless of its own stats, which made
## "a Special can handle ~4xB1" structurally impossible under the
## MVP2 suppression model).
const SPECIAL_TIER_SUPPRESSION_RESIST := 0.45
const SUPPRESSION_DECAY_PER_SEC := 15.0
const MAX_SUPPRESSION_ACCURACY_PENALTY := 0.4
const SUPPRESSION_RETREAT_THRESHOLD := 70.0
const RETREAT_DISTANCE := 150.0
const RETREAT_DURATION_SEC := 2.0
const REVIVE_CHANNEL_SEC := 4.0
const REVIVE_RANGE := 50.0
const REVIVE_HP_FRACTION := 0.5
const EXECUTE_CHANNEL_SEC := 6.0 # explicit in Prompt Dasar base rules
const RECRUIT_CHANNEL_SEC := 4.0
const RECRUIT_HP_FRACTION := 0.5
const FRIENDLY_FIRE_MULTIPLIER := 0.5
const DOWNED_DURATION_REGULAR := 30.0
const DOWNED_DURATION_SPECIAL := 45.0
const DOWNED_DURATION_MC := 90.0

@export var unit_id: StringName = &""
@export var display_name: String = ""
## Display-only tier tag: "MC", "B1", "B2", "B3", "SPECIAL", "ENEMY".
@export var tier_label: String = ""
@export var faction_side: StringName = &"player"
@export var can_move: bool = true
@export var auto_defend: bool = false
## Only Juan-side recruiters may complete a recruit action on this unit
## (spec: only regular B1/B2/B3-tier enemies can be recruited).
@export var is_recruitable_tier: bool = false

## Optional data-driven base stats; when set, overrides the exported
## defaults below in _ready(). Enemy dummies intentionally have none.
@export var unit_data: UnitData = null

## Optional reference to the mission's economy, used only to check the
## Bank/Recruitment safe-zone radius. Assigned by the spawning scene;
## left null in isolated tests where safe zones are irrelevant.
var economy: Node = null

## MVP3: when set, this unit is riding inside a Vehicle. Movement/combat
## orders directed at this unit while mounted are redirected to the
## vehicle by CommandController instead (see command_controller.gd); the
## unit itself is hidden and its own physics processing is paused for as
## long as it stays mounted.
var mounted_vehicle: Node = null
var is_driver: bool = false
## MVP3 carried cargo/cash (Prompt Dasar "Carried cash terpisah dari
## bank balance"). A carrier's cargo/cash is only "safe" once deposited
## with CampaignEconomy at a Bank; losing the carrier before that drops
## it as a lootable world pickup (see cash_drop.gd).
var carried_cargo: int = 0
var carried_cash: int = 0
const CARGO_CAPACITY := 2

## ---------------------------------------------------------------
## MVP4: Main Character abilities, leveling, and transient buffs.
## See docs/TECH_DECISIONS.md "Ability system" for the design.
## ---------------------------------------------------------------
## Only populated for tier_label == "MC" by the spawning scene.
var abilities: Array = [] # Array[AbilityData]
var _ability_cooldowns: Dictionary = {} # StringName -> remaining seconds
## Bonus applied to this unit's *own* recruit-enemy conversion price,
## e.g. Juan's Master Manipulator (see docs/BALANCE.md). 1.0 = no change.
var recruit_cost_multiplier: float = 1.0

var mc_level: int = 1
## Set by the spawning scene when this unit is a Special (index into
## CampaignData.special_units); -1 for non-Special units. Persisted so
## save/load can restore _recruited_special_ids without re-deriving it.
var special_index: int = -1
const MC_MAX_LEVEL := 5
## Prompt Dasar "MAIN CHARACTER" upgrade cost table, levels 2-5.
const MC_LEVEL_COSTS := {2: 1000, 3: 2000, 4: 3500, 5: 5500}
## Cumulative caps at level 5, applied linearly per level per Prompt
## Dasar ("Jangan membuat scaling tanpa batas").
const MC_MAX_HP_BONUS_FRAC := 0.20
const MC_MAX_DAMAGE_BONUS_FRAC := 0.08
const MC_MAX_COOLDOWN_REDUCTION_FRAC := 0.15
var _mc_base_max_hp: float = 0.0

## Temporary buffs applied by abilities (self-cast or squad-cast).
## Decay automatically in _physics_process.
var temp_damage_mult: float = 1.0
var temp_accuracy_bonus: float = 0.0
var _temp_buff_timer: float = 0.0

## Continuously recomputed each physics frame from nearby AURA-category
## abilities on friendly Main Characters (Tactical Link, Discipline
## Aura). Applied on top of temp_accuracy_bonus.
var aura_accuracy_bonus: float = 0.0
var aura_suppression_resist_mult: float = 0.0

## MVP4: Zie's Triad Synergy (Prompt Dasar: active only when all 3 of
## her Specials are alive and within 12m of each other). Computed
## externally by the owning map scene (it alone knows which 3 unit
## instances make up the trio) and applied here as plain multipliers.
var synergy_damage_mult: float = 1.0
var synergy_armor_reduction: float = 0.0
var synergy_suppression_resist_mult: float = 0.0

@export var max_hp: float = 100.0
@export var move_speed_px: float = 190.0
@export var accuracy: float = 0.55
@export var acquire_range: float = 140.0
## Fallback melee-ish stats used only when no weapon is resolved (kept
## small deliberately: an unarmed unit should not fight effectively).
@export var unarmed_damage: float = 4.0
@export var unarmed_range: float = 34.0
@export var unarmed_fire_interval: float = 1.0

var hp: float
var recruit_price: int = 0
var salary: int = 0
var morale: float = 100.0
var missed_payroll_cycles: int = 0

var state: int = State.IDLE
var attack_target: BwUnit = null
var attack_move_destination = null
var revive_target: BwUnit = null
var execute_target: BwUnit = null
var recruit_target: BwUnit = null
var interaction_building = null
## MVP3: set by order_enter_vehicle(); checked every physics frame so a
## unit walking toward a vehicle automatically boards it on arrival.
var pending_vehicle_to_enter = null
const VEHICLE_ENTER_RANGE := 55.0
## MVP3 Patrol Mode (Prompt Dasar "P: Patrol Mode", "Patrol area untuk
## cartel"). While patrolling, the unit walks between patrol_point_a/b
## and auto-engages any hostile within acquire_range; once that fight
## ends it resumes patrolling instead of going IDLE.
var is_patrolling: bool = false
var patrol_point_a: Vector2 = Vector2.ZERO
var patrol_point_b: Vector2 = Vector2.ZERO
var _patrol_heading_to_b: bool = true
var is_selected: bool = false

var primary_weapon: WeaponData = null
var secondary_weapon: WeaponData = null
var grenade_weapon: WeaponData = null
var armor_weapon: WeaponData = null
var primary_mag: int = 0
var primary_reserve: int = 0
var grenade_count: int = 0
var is_reloading: bool = false

var in_cover: bool = false
var cover_direction: Vector2 = Vector2.ZERO
var suppression: float = 0.0

var downed_timer: float = 0.0
var _channel_timer: float = 0.0
var _fire_timer: float = 0.0
var _reload_timer: float = 0.0
var _retreat_timer: float = 0.0
var _pending_cover_body: Node = null
## Looked up via get_node() at runtime rather than referenced as a bare
## autoload identifier: GDScript's compile-time autoload resolution is
## unreliable for `--headless --script` (custom MainLoop) invocations —
## see docs/TECH_DECISIONS.md "Autoload references in headless test
## scripts". This keeps unit.gd testable in that mode without changing
## normal-boot behavior.
var _combat_log: Node = null

@onready var nav_agent: NavigationAgent2D = $NavAgent
@onready var body_poly: Polygon2D = $Body
@onready var selection_ring: Node2D = $SelectionRing
@onready var health_bar: Node2D = $HealthBar
@onready var tier_label_node: Label = $TierLabel


func _ready() -> void:
	_combat_log = get_node_or_null("/root/CombatLog")
	if unit_data != null:
		max_hp = unit_data.base_hp
		accuracy = unit_data.base_accuracy
		move_speed_px = unit_data.move_speed * 60.0 # UnitData speed is a small "tiles/sec"-style scalar; convert to px/s
		recruit_price = unit_data.recruit_price
		salary = unit_data.salary
		if display_name == "":
			display_name = unit_data.display_name
	hp = max_hp
	_mc_base_max_hp = max_hp
	add_to_group("bw_units")
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.radius = 14.0
	nav_agent.avoidance_enabled = true
	nav_agent.max_speed = move_speed_px
	_setup_body_visual()
	tier_label_node.text = tier_label
	health_bar.set_ratio(1.0)
	set_selected(false)


func _setup_body_visual() -> void:
	var pts := PackedVector2Array()
	var radius := 14.0
	var segments := 16
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	body_poly.polygon = pts
	body_poly.color = Color(0.15, 0.45, 0.85) if faction_side == &"player" else Color(0.75, 0.2, 0.2)


func set_selected(value: bool) -> void:
	is_selected = value
	if selection_ring:
		selection_ring.visible = value
	selection_changed.emit(self, value)


func _log_event(text: String) -> void:
	if _combat_log:
		_combat_log.log_event(text)


## ---------------------------------------------------------------
## Equipment (manual, per Prompt Dasar: never auto-equip all units)
## ---------------------------------------------------------------
func equip_weapon(slot: String, weapon: WeaponData) -> void:
	match slot:
		"primary":
			primary_weapon = weapon
			primary_mag = weapon.magazine_size if weapon else 0
			primary_reserve = weapon.reserve_ammo if weapon else 0
			is_reloading = false
		"secondary":
			secondary_weapon = weapon
		"grenade":
			grenade_weapon = weapon
			grenade_count = weapon.magazine_size if weapon else 0
		"armor":
			armor_weapon = weapon


## ---------------------------------------------------------------
## Main Character leveling (Prompt Dasar "MAIN CHARACTER" upgrade,
## levels 2-5, capped cumulative bonuses).
## ---------------------------------------------------------------
func mc_upgrade_cost() -> int:
	if mc_level >= MC_MAX_LEVEL:
		return -1
	return MC_LEVEL_COSTS[mc_level + 1]


func mc_upgrade() -> bool:
	if mc_level >= MC_MAX_LEVEL:
		return false
	mc_level += 1
	_apply_mc_level_bonuses()
	_log_event("%s reached Main Character level %d." % [display_name, mc_level])
	return true


func _apply_mc_level_bonuses() -> void:
	var progress: float = float(mc_level - 1) / float(MC_MAX_LEVEL - 1) # 0.0 at level 1, 1.0 at level 5
	var hp_frac: float = progress * MC_MAX_HP_BONUS_FRAC
	var new_max_hp: float = _mc_base_max_hp * (1.0 + hp_frac)
	var hp_ratio: float = hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = new_max_hp
	hp = max_hp * hp_ratio
	if health_bar:
		health_bar.set_ratio(hp / max_hp)


## Cumulative weapon-damage bonus fraction at the current level (Prompt
## Dasar cap: "Maksimal +8% weapon damage"). Applied as a multiplier in
## _trigger_weapon.
func mc_damage_bonus_mult() -> float:
	var progress: float = float(mc_level - 1) / float(MC_MAX_LEVEL - 1)
	return 1.0 + progress * MC_MAX_DAMAGE_BONUS_FRAC


## Cumulative ability-cooldown reduction fraction at the current level
## (Prompt Dasar cap: "Maksimal -15% ability cooldown").
func mc_cooldown_reduction_mult() -> float:
	var progress: float = float(mc_level - 1) / float(MC_MAX_LEVEL - 1)
	return 1.0 - progress * MC_MAX_COOLDOWN_REDUCTION_FRAC


## ---------------------------------------------------------------
## Abilities (Prompt Dasar per-faction ability list; MVP4 acceptance
## criterion: "Ability mempunyai cooldown, feedback, dan counterplay").
## AURA-category abilities are always-on (scanned by nearby units, see
## _refresh_aura_bonuses below) and never appear here; only active
## categories are triggered through this entry point.
## ---------------------------------------------------------------
func get_ability_cooldown_remaining(ability_id: StringName) -> float:
	return _ability_cooldowns.get(ability_id, 0.0)


func can_use_ability(ability_id: StringName) -> bool:
	if state == State.DEAD or state == State.DOWNED:
		return false
	return get_ability_cooldown_remaining(ability_id) <= 0.0


func try_use_ability(ability_id: StringName, target_pos = null) -> bool:
	var ability: AbilityData = null
	for a in abilities:
		if a.id == ability_id:
			ability = a
			break
	if ability == null or ability.category == AbilityData.Category.AURA:
		return false
	if not can_use_ability(ability_id):
		return false

	match ability.category:
		AbilityData.Category.ACTIVE_BURST:
			_use_ability_burst(ability)
		AbilityData.Category.ACTIVE_SELF_BUFF:
			_use_ability_self_buff(ability)
		AbilityData.Category.ACTIVE_SQUAD_BUFF:
			_use_ability_squad_buff(ability)
		AbilityData.Category.ACTIVE_AOE:
			if target_pos == null:
				return false
			_use_ability_aoe(ability, target_pos)

	_ability_cooldowns[ability_id] = ability.cooldown_sec * mc_cooldown_reduction_mult()
	_log_event("%s used %s." % [display_name, ability.display_name])
	return true


func _use_ability_burst(ability: AbilityData) -> void:
	var target: BwUnit = attack_target
	if target == null or not is_instance_valid(target):
		target = _find_nearest_enemy(acquire_range * 1.5)
	if target == null:
		return
	var dmg: float = ability.damage_amount
	if target.tier_label == "MC" or target.tier_label == "SPECIAL":
		# Counterplay: cannot one-hit a MC/Special — cap so the target
		# always keeps at least max_target_damage_cap_fraction of its HP.
		var floor_hp: float = target.max_hp * ability.max_target_damage_cap_fraction
		dmg = min(dmg, max(0.0, target.hp - floor_hp))
	target.take_damage(dmg, self)


func _use_ability_self_buff(ability: AbilityData) -> void:
	temp_accuracy_bonus = ability.accuracy_bonus
	_temp_buff_timer = ability.duration_sec


func _use_ability_squad_buff(ability: AbilityData) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var affected := 0
	for n in tree.get_nodes_in_group("bw_units"):
		if affected >= ability.max_targets:
			break
		if not (n is BwUnit) or not is_instance_valid(n) or n == self:
			continue
		var u: BwUnit = n
		if u.faction_side != faction_side or u.state == State.DEAD or u.state == State.DOWNED:
			continue
		if global_position.distance_to(u.global_position) > ability.radius_px:
			continue
		# Not stackable: refresh rather than multiply if already active.
		u.temp_damage_mult = ability.damage_mult
		u._temp_buff_timer = ability.duration_sec
		affected += 1


func _use_ability_aoe(ability: AbilityData, target_pos: Vector2) -> void:
	var w := WeaponData.new()
	w.id = StringName("ability_weapon_%s" % ability.id)
	w.display_name = ability.display_name
	w.damage = ability.damage_amount
	w.is_explosive = true
	w.blast_radius_px = ability.radius_px
	w.is_hitscan = false
	w.projectile_speed_px = 260.0
	w.range_px = 999999.0
	_fire_projectile(w, target_pos)


## Recomputes aura_accuracy_bonus/aura_suppression_resist_mult from any
## nearby same-faction Main Character carrying an AURA-category ability.
## Called once per physics frame; cheap at this game's unit-count scale
## (roster cap 24-30).
func _refresh_aura_bonuses() -> void:
	aura_accuracy_bonus = 0.0
	aura_suppression_resist_mult = 0.0
	if tier_label == "MC" or tier_label == "VEHICLE":
		return
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("bw_units"):
		if not (n is BwUnit) or not is_instance_valid(n):
			continue
		var mc: BwUnit = n
		if mc.tier_label != "MC" or mc.faction_side != faction_side:
			continue
		if mc.state == State.DEAD or mc.state == State.DOWNED:
			continue
		for a in mc.abilities:
			if a.category != AbilityData.Category.AURA:
				continue
			if global_position.distance_to(mc.global_position) <= a.radius_px:
				aura_accuracy_bonus = max(aura_accuracy_bonus, a.accuracy_bonus)
				aura_suppression_resist_mult = max(aura_suppression_resist_mult, a.suppression_resist_mult)
				if a.morale_bonus_per_sec > 0.0:
					morale = min(100.0, morale + a.morale_bonus_per_sec * get_physics_process_delta_time())


func downed_duration() -> float:
	match tier_label:
		"SPECIAL":
			return DOWNED_DURATION_SPECIAL
		"MC":
			return DOWNED_DURATION_MC
		_:
			return DOWNED_DURATION_REGULAR


## ---------------------------------------------------------------
## Vehicle mounting (MVP3) — see docs/TECH_DECISIONS.md "Vehicle
## mounting model" for why units hide/pause rather than the vehicle
## itself being a selectable RTS unit.
## ---------------------------------------------------------------
func mount_vehicle(vehicle: Node, as_driver: bool) -> void:
	mounted_vehicle = vehicle
	is_driver = as_driver
	set_selected(false)
	visible = false
	set_physics_process(false)
	set_collision_layer_value(1, false)


func unmount_vehicle(exit_position: Vector2) -> void:
	mounted_vehicle = null
	is_driver = false
	global_position = exit_position
	visible = true
	set_physics_process(true)
	set_collision_layer_value(1, true)
	state = State.IDLE
	velocity = Vector2.ZERO


## ---------------------------------------------------------------
## Loot pickup (MVP3)
## ---------------------------------------------------------------
func pickup_loot(cargo: int, cash: int) -> void:
	var room: int = CARGO_CAPACITY - carried_cargo
	var taken: int = min(room, cargo)
	carried_cargo += taken
	carried_cash += cash


## ---------------------------------------------------------------
## Orders
## ---------------------------------------------------------------
func order_move(target: Vector2) -> void:
	if not _can_receive_orders():
		return
	_clear_all_targets()
	in_cover = false
	state = State.MOVING
	nav_agent.target_position = target


func order_attack_move(target: Vector2) -> void:
	if not _can_receive_orders():
		return
	_clear_all_targets()
	in_cover = false
	attack_move_destination = target
	state = State.ATTACK_MOVING
	nav_agent.target_position = target


func order_attack(target: BwUnit) -> void:
	if not _can_receive_orders() or target == null:
		return
	_clear_all_targets()
	in_cover = false
	attack_target = target
	state = State.ATTACKING


func order_stop() -> void:
	_clear_all_targets()
	in_cover = false
	state = State.IDLE
	velocity = Vector2.ZERO


func order_defend() -> void:
	if not _can_receive_orders():
		return
	_clear_all_targets()
	var cover_body := _find_nearest_cover(COVER_SEARCH_RADIUS)
	if cover_body:
		var dir: Vector2 = (global_position - cover_body.global_position)
		if dir.length() < 0.01:
			dir = Vector2.RIGHT
		dir = dir.normalized()
		var cover_radius: float = cover_body.get_meta("cover_radius", 60.0)
		cover_direction = dir
		_pending_cover_body = cover_body
		state = State.MOVING_TO_COVER
		nav_agent.target_position = cover_body.global_position + dir * (cover_radius + 20.0)
	else:
		state = State.IDLE
		velocity = Vector2.ZERO


func order_revive(target: BwUnit) -> void:
	if not _can_receive_orders() or target == null or not is_instance_valid(target):
		return
	if target.state != State.DOWNED or target.faction_side != faction_side:
		return
	_clear_all_targets()
	in_cover = false
	revive_target = target
	state = State.REVIVING
	nav_agent.target_position = target.global_position


func order_execute(target: BwUnit) -> void:
	if not _can_receive_orders() or target == null or not is_instance_valid(target):
		return
	if target.state != State.DOWNED or target.faction_side == faction_side:
		return
	if target.economy != null and target.economy.is_position_safe(target.global_position):
		_log_event("Execution of %s blocked: inside a safe zone." % target.display_name)
		return
	_clear_all_targets()
	in_cover = false
	execute_target = target
	state = State.EXECUTING
	nav_agent.target_position = target.global_position


func order_recruit_downed(target: BwUnit) -> void:
	if not _can_receive_orders() or target == null or not is_instance_valid(target):
		return
	if target.state != State.DOWNED or target.faction_side == faction_side or not target.is_recruitable_tier:
		return
	_clear_all_targets()
	in_cover = false
	recruit_target = target
	state = State.RECRUITING
	nav_agent.target_position = target.global_position


## MVP3: generic building-driven channel (Bank deposit, Dealer sell).
## `building` must implement `on_interaction_complete(unit)`.
func order_patrol(other_point: Vector2) -> void:
	if not _can_receive_orders():
		return
	_clear_all_targets()
	in_cover = false
	is_patrolling = true
	patrol_point_a = global_position
	patrol_point_b = other_point
	_patrol_heading_to_b = true
	state = State.PATROLLING
	nav_agent.target_position = patrol_point_b


func order_enter_vehicle(vehicle) -> void:
	if not _can_receive_orders() or vehicle == null or not is_instance_valid(vehicle):
		return
	if global_position.distance_to(vehicle.global_position) <= VEHICLE_ENTER_RANGE:
		vehicle.enter(self)
		return
	order_move(vehicle.global_position)
	pending_vehicle_to_enter = vehicle


func start_interaction(building, duration: float) -> void:
	if not _can_receive_orders():
		return
	_clear_all_targets()
	in_cover = false
	interaction_building = building
	_channel_timer = duration
	state = State.INTERACTING


func order_use_grenade(target_pos: Vector2) -> void:
	if not _can_receive_orders() or grenade_weapon == null or grenade_count <= 0:
		return
	var dir: Vector2 = target_pos - global_position
	var dist: float = dir.length()
	var max_range: float = grenade_weapon.range_px
	var clamped_pos: Vector2 = target_pos
	if dist > max_range and dist > 0.001:
		clamped_pos = global_position + dir.normalized() * max_range
	grenade_count -= 1
	_fire_projectile(grenade_weapon, clamped_pos)


func _can_receive_orders() -> bool:
	return can_move and state != State.DEAD and state != State.DOWNED and mounted_vehicle == null


func _clear_all_targets() -> void:
	attack_target = null
	attack_move_destination = null
	revive_target = null
	execute_target = null
	recruit_target = null
	is_reloading = false
	is_patrolling = false
	pending_vehicle_to_enter = null


## ---------------------------------------------------------------
## Damage / downed / death
## ---------------------------------------------------------------
func take_damage(amount: float, attacker = null) -> void:
	if state == State.DEAD or state == State.DOWNED:
		return
	if economy != null and economy.is_position_safe(global_position):
		_log_event("Attack on %s blocked: inside a safe zone." % display_name)
		return
	var final_amount := amount
	if in_cover and attacker != null and is_instance_valid(attacker):
		var attacker_dir: Vector2 = (attacker.global_position - global_position).normalized()
		if cover_direction.dot(attacker_dir) < -0.3:
			final_amount *= (1.0 - COVER_DAMAGE_REDUCTION)
	if armor_weapon != null:
		final_amount *= (1.0 - armor_weapon.armor_damage_reduction)
	final_amount *= (1.0 - synergy_armor_reduction)
	var tier_resist: float = SPECIAL_TIER_SUPPRESSION_RESIST if (tier_label == "SPECIAL" or tier_label == "MC") else 0.0
	var suppression_gain: float = SUPPRESSION_PER_HIT * (1.0 - aura_suppression_resist_mult) * (1.0 - synergy_suppression_resist_mult) * (1.0 - tier_resist)
	suppression = min(100.0, suppression + suppression_gain)
	if state == State.REVIVING or state == State.EXECUTING or state == State.RECRUITING or state == State.INTERACTING:
		# Taking fire interrupts a channeled action (spec: execution "dapat dihentikan").
		state = State.IDLE
		revive_target = null
		execute_target = null
		recruit_target = null
		interaction_building = null
	hp = max(0.0, hp - final_amount)
	if health_bar:
		health_bar.set_ratio(hp / max_hp)
	hp_changed.emit(self, hp / max_hp)
	if hp <= 0.0:
		_enter_downed()


func set_hp(value: float) -> void:
	hp = clampf(value, 0.0, max_hp)
	if health_bar:
		health_bar.set_ratio(hp / max_hp)
	if hp <= 0.0:
		_enter_downed()


func _enter_downed() -> void:
	state = State.DOWNED
	downed_timer = downed_duration()
	attack_target = null
	velocity = Vector2.ZERO
	if body_poly:
		body_poly.modulate = Color(1, 1, 1, 0.4)
	if selection_ring:
		selection_ring.visible = false
	downed.emit(self)
	_log_event("%s is downed (%.0fs to revive or execute)." % [display_name, downed_timer])
	if carried_cargo > 0 or carried_cash > 0:
		loot_dropped.emit(global_position, carried_cargo, carried_cash)
		_log_event("%s dropped %d cargo and $%d as loot." % [display_name, carried_cargo, carried_cash])
		carried_cargo = 0
		carried_cash = 0


func _complete_revive() -> void:
	hp = max_hp * REVIVE_HP_FRACTION
	state = State.IDLE
	if body_poly:
		body_poly.modulate = Color(1, 1, 1, 1)
	if health_bar:
		health_bar.set_ratio(hp / max_hp)
	revived.emit(self)
	_log_event("%s was revived." % display_name)


func _die() -> void:
	state = State.DEAD
	died.emit(self)
	_log_event("%s died." % display_name)
	queue_free()


## ---------------------------------------------------------------
## Physics / state machine
## ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	suppression = max(0.0, suppression - SUPPRESSION_DECAY_PER_SEC * delta)
	_refresh_aura_bonuses()

	if _temp_buff_timer > 0.0:
		_temp_buff_timer -= delta
		if _temp_buff_timer <= 0.0:
			temp_damage_mult = 1.0
			temp_accuracy_bonus = 0.0

	if not _ability_cooldowns.is_empty():
		var expired: Array = []
		for k in _ability_cooldowns.keys():
			_ability_cooldowns[k] = max(0.0, _ability_cooldowns[k] - delta)
			if _ability_cooldowns[k] <= 0.0:
				expired.append(k)
		for k in expired:
			_ability_cooldowns.erase(k)

	if pending_vehicle_to_enter != null:
		if not is_instance_valid(pending_vehicle_to_enter):
			pending_vehicle_to_enter = null
		elif global_position.distance_to(pending_vehicle_to_enter.global_position) <= VEHICLE_ENTER_RANGE:
			var v = pending_vehicle_to_enter
			pending_vehicle_to_enter = null
			v.enter(self)
			return

	match state:
		State.DEAD:
			return
		State.DOWNED:
			downed_timer -= delta
			if downed_timer <= 0.0:
				_die()
		State.MOVING:
			_process_movement()
		State.ATTACK_MOVING:
			_process_attack_move()
		State.ATTACKING:
			_process_attacking(delta)
		State.MOVING_TO_COVER:
			_process_moving_to_cover()
		State.DEFENDING:
			_process_defending(delta)
		State.REVIVING:
			_process_revive_or_recruit(delta, true)
		State.RECRUITING:
			_process_revive_or_recruit(delta, false)
		State.EXECUTING:
			_process_execute(delta)
		State.RETREATING:
			_process_retreat(delta)
		State.INTERACTING:
			_process_interaction(delta)
		State.PATROLLING:
			_process_patrolling()
		State.IDLE:
			velocity = Vector2.ZERO
			move_and_slide()
			if auto_defend:
				var enemy := _find_nearest_enemy(acquire_range)
				if enemy:
					order_attack(enemy)


func _process_movement() -> void:
	if nav_agent.is_navigation_finished():
		state = State.IDLE
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_move_towards_next_path_point()


func _process_attack_move() -> void:
	var enemy := _find_nearest_enemy(acquire_range)
	if enemy:
		attack_target = enemy
		state = State.ATTACKING
		return
	if nav_agent.is_navigation_finished():
		state = State.IDLE
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_move_towards_next_path_point()


func _process_moving_to_cover() -> void:
	if nav_agent.is_navigation_finished():
		in_cover = true
		state = State.DEFENDING
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_move_towards_next_path_point()


func _process_defending(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	if attack_target == null or not is_instance_valid(attack_target) or attack_target.state == State.DEAD or attack_target.state == State.DOWNED:
		attack_target = _find_nearest_enemy(acquire_range)
	if attack_target:
		_try_fire_stationary(delta)


func _process_attacking(delta: float) -> void:
	if attack_target == null or not is_instance_valid(attack_target) or attack_target.state == State.DEAD or attack_target.state == State.DOWNED:
		attack_target = null
		if is_patrolling:
			state = State.PATROLLING
			nav_agent.target_position = patrol_point_b if _patrol_heading_to_b else patrol_point_a
		elif attack_move_destination != null:
			state = State.ATTACK_MOVING
			nav_agent.target_position = attack_move_destination
		else:
			state = State.IDLE
		return
	var weapon := _resolve_active_weapon()
	var range_px: float = weapon.range_px if weapon else unarmed_range
	var dist: float = global_position.distance_to(attack_target.global_position)
	if dist > range_px:
		nav_agent.target_position = attack_target.global_position
		_move_towards_next_path_point()
		return
	velocity = Vector2.ZERO
	move_and_slide()
	if suppression >= SUPPRESSION_RETREAT_THRESHOLD:
		_enter_retreat()
		return
	_try_fire_stationary(delta)


func _try_fire_stationary(delta: float) -> void:
	var weapon := _resolve_active_weapon()
	if weapon == null:
		return # unarmed: cannot fight until a weapon is manually assigned
	var range_px: float = weapon.range_px
	var dist: float = global_position.distance_to(attack_target.global_position)
	if dist > range_px:
		return
	if weapon == primary_weapon and weapon.uses_ammo and primary_mag <= 0 and not is_reloading:
		_start_reload()
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
		return
	if not _has_line_of_sight(attack_target):
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = weapon.fire_interval_sec()
		_trigger_weapon(weapon, attack_target)


func _process_revive_or_recruit(delta: float, is_revive: bool) -> void:
	var target: BwUnit = revive_target if is_revive else recruit_target
	if target == null or not is_instance_valid(target) or target.state != State.DOWNED:
		state = State.IDLE
		return
	var dist: float = global_position.distance_to(target.global_position)
	if dist > REVIVE_RANGE:
		nav_agent.target_position = target.global_position
		_move_towards_next_path_point()
		return
	velocity = Vector2.ZERO
	move_and_slide()
	if _channel_timer <= 0.0:
		_channel_timer = REVIVE_CHANNEL_SEC if is_revive else RECRUIT_CHANNEL_SEC
	_channel_timer -= delta
	if _channel_timer <= 0.0:
		if is_revive:
			target._complete_revive()
			revive_target = null
		else:
			recruit_completed.emit(self, target)
			recruit_target = null
		state = State.IDLE


func _process_execute(delta: float) -> void:
	if execute_target == null or not is_instance_valid(execute_target) or execute_target.state != State.DOWNED:
		state = State.IDLE
		return
	var dist: float = global_position.distance_to(execute_target.global_position)
	if dist > REVIVE_RANGE:
		nav_agent.target_position = execute_target.global_position
		_move_towards_next_path_point()
		return
	velocity = Vector2.ZERO
	move_and_slide()
	if _channel_timer <= 0.0:
		_channel_timer = EXECUTE_CHANNEL_SEC
	_channel_timer -= delta
	if _channel_timer <= 0.0:
		var t := execute_target
		execute_target = null
		state = State.IDLE
		_log_event("%s executed %s." % [display_name, t.display_name])
		t._die()


func _enter_retreat() -> void:
	var away_dir := Vector2.RIGHT
	if attack_target and is_instance_valid(attack_target):
		away_dir = (global_position - attack_target.global_position)
		if away_dir.length() > 0.01:
			away_dir = away_dir.normalized()
	_retreat_timer = RETREAT_DURATION_SEC
	state = State.RETREATING
	nav_agent.target_position = global_position + away_dir * RETREAT_DISTANCE


func _process_patrolling() -> void:
	var enemy := _find_nearest_enemy(acquire_range)
	if enemy:
		attack_target = enemy
		state = State.ATTACKING
		return
	if nav_agent.is_navigation_finished():
		_patrol_heading_to_b = not _patrol_heading_to_b
		nav_agent.target_position = patrol_point_b if _patrol_heading_to_b else patrol_point_a
	_move_towards_next_path_point()


func _process_retreat(delta: float) -> void:
	_retreat_timer -= delta
	if _retreat_timer <= 0.0 or nav_agent.is_navigation_finished():
		state = State.IDLE
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_move_towards_next_path_point()


func _process_interaction(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_channel_timer -= delta
	if _channel_timer <= 0.0:
		var building = interaction_building
		interaction_building = null
		state = State.IDLE
		if building and building.has_method("on_interaction_complete"):
			building.on_interaction_complete(self)


func _move_towards_next_path_point() -> void:
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = next_pos - global_position
	if direction.length() > 0.001:
		direction = direction.normalized()
	var desired_velocity := direction * move_speed_px
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = desired_velocity
	else:
		_on_velocity_computed(desired_velocity)


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()


## ---------------------------------------------------------------
## Weapon resolution / firing
## ---------------------------------------------------------------
func _resolve_active_weapon() -> WeaponData:
	if primary_weapon != null and (not primary_weapon.uses_ammo or primary_mag > 0 or primary_reserve > 0 or is_reloading):
		return primary_weapon
	if secondary_weapon != null:
		return secondary_weapon
	return null


func _start_reload() -> void:
	if is_reloading or primary_weapon == null or primary_reserve <= 0:
		return
	is_reloading = true
	_reload_timer = primary_weapon.reload_time_sec


func _finish_reload() -> void:
	is_reloading = false
	if primary_weapon == null:
		return
	var need: int = primary_weapon.magazine_size - primary_mag
	var take: int = min(need, primary_reserve)
	primary_mag += take
	primary_reserve -= take


func _effective_accuracy() -> float:
	var penalty: float = clampf(suppression / 100.0 * MAX_SUPPRESSION_ACCURACY_PENALTY, 0.0, MAX_SUPPRESSION_ACCURACY_PENALTY)
	return clampf(accuracy - penalty + aura_accuracy_bonus + temp_accuracy_bonus, 0.05, 0.99)


func _trigger_weapon(weapon: WeaponData, target_unit: BwUnit) -> void:
	if weapon.uses_ammo:
		if weapon == primary_weapon:
			if primary_mag <= 0:
				_start_reload()
				return
			primary_mag -= 1
		# secondary (melee) weapons default to uses_ammo = false and skip this branch.
	if weapon.is_explosive:
		_fire_projectile(weapon, target_unit.global_position)
		return
	if randf() <= _effective_accuracy():
		var dmg: float = weapon.damage * temp_damage_mult * synergy_damage_mult
		if tier_label == "MC":
			dmg *= mc_damage_bonus_mult()
		target_unit.take_damage(dmg, self)


func _fire_projectile(weapon: WeaponData, impact_pos: Vector2) -> void:
	if weapon.is_hitscan:
		_apply_explosion(impact_pos, weapon)
		return
	var dist: float = global_position.distance_to(impact_pos)
	var travel: float = dist / max(weapon.projectile_speed_px, 1.0)
	var tree := get_tree()
	if tree == null:
		_apply_explosion(impact_pos, weapon)
		return
	var timer := tree.create_timer(travel)
	timer.timeout.connect(_apply_explosion.bind(impact_pos, weapon))


func _apply_explosion(pos: Vector2, weapon: WeaponData) -> void:
	_log_event("%s explosion (%s)." % [weapon.display_name, display_name])
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("bw_units"):
		if not (n is BwUnit) or not is_instance_valid(n):
			continue
		var u: BwUnit = n
		if u.state == State.DEAD:
			continue
		var d: float = pos.distance_to(u.global_position)
		if d > weapon.blast_radius_px:
			continue
		var falloff: float = 1.0 - (d / weapon.blast_radius_px) * 0.5
		var dmg: float = weapon.damage * falloff
		if u.faction_side == faction_side:
			if u == self:
				continue
			dmg *= FRIENDLY_FIRE_MULTIPLIER
			_log_event("WARNING: friendly-fire from %s hit %s for %d." % [display_name, u.display_name, int(dmg)])
		u.take_damage(dmg, self)


## ---------------------------------------------------------------
## Line of sight / cover / targeting helpers
## ---------------------------------------------------------------
func _has_line_of_sight(target: BwUnit) -> bool:
	var space_state := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	params.collision_mask = 2 # obstacles only (see docs/TECH_DECISIONS.md layer scheme)
	params.exclude = [self]
	var result := space_state.intersect_ray(params)
	return result.is_empty()


func _find_nearest_cover(max_dist: float) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: Node = null
	var nearest_dist := max_dist
	for n in tree.get_nodes_in_group("cover_objects"):
		var d: float = global_position.distance_to(n.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = n
	return nearest


func _find_nearest_enemy(max_range: float) -> BwUnit:
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: BwUnit = null
	var nearest_dist := max_range
	for n in tree.get_nodes_in_group("bw_units"):
		if n == self or not (n is BwUnit):
			continue
		var u: BwUnit = n
		if u.faction_side == faction_side or u.state == State.DEAD or u.state == State.DOWNED:
			continue
		var d: float = global_position.distance_to(u.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = u
	return nearest


## ---------------------------------------------------------------
## Payroll (called by the gameplay scene's economy on each payroll tick)
## ---------------------------------------------------------------
func apply_payroll_result(paid: bool) -> void:
	if paid:
		missed_payroll_cycles = 0
		morale = min(100.0, morale + 20.0)
	else:
		missed_payroll_cycles += 1
		morale = max(0.0, morale - 30.0)
		accuracy = max(0.05, accuracy - 0.10)
		move_speed_px *= 0.9
		nav_agent.max_speed = move_speed_px
		_log_event("%s missed payroll (%d cycle(s))." % [display_name, missed_payroll_cycles])
