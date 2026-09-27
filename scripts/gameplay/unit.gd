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

enum State {
	IDLE, MOVING, ATTACK_MOVING, ATTACKING, DEFENDING, MOVING_TO_COVER,
	DOWNED, REVIVING, EXECUTING, RECRUITING, RETREATING, DEAD,
}

## -------------------------------------------------------------------
## Tunable MVP2 assumptions (see docs/TECH_DECISIONS.md for rationale)
## -------------------------------------------------------------------
const COVER_DAMAGE_REDUCTION := 0.35
const COVER_SEARCH_RADIUS := 420.0
const SUPPRESSION_PER_HIT := 25.0
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


func downed_duration() -> float:
	match tier_label:
		"SPECIAL":
			return DOWNED_DURATION_SPECIAL
		"MC":
			return DOWNED_DURATION_MC
		_:
			return DOWNED_DURATION_REGULAR


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
	return can_move and state != State.DEAD and state != State.DOWNED


func _clear_all_targets() -> void:
	attack_target = null
	attack_move_destination = null
	revive_target = null
	execute_target = null
	recruit_target = null
	is_reloading = false


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
	suppression = min(100.0, suppression + SUPPRESSION_PER_HIT)
	if state == State.REVIVING or state == State.EXECUTING or state == State.RECRUITING:
		# Taking fire interrupts a channeled action (spec: execution "dapat dihentikan").
		state = State.IDLE
		revive_target = null
		execute_target = null
		recruit_target = null
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
		if attack_move_destination != null:
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


func _process_retreat(delta: float) -> void:
	_retreat_timer -= delta
	if _retreat_timer <= 0.0 or nav_agent.is_navigation_finished():
		state = State.IDLE
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_move_towards_next_path_point()


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
	return clampf(accuracy - penalty, 0.05, 0.99)


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
		target_unit.take_damage(weapon.damage, self)


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
