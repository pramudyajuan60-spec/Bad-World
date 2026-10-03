class_name RTSUnit
extends CharacterBody2D
## MVP 1 playable unit: 4-directional animated sprite, NavigationAgent2D
## movement with avoidance, attack-move, health, selection visuals.
##
## Animations expected on the AnimatedSprite2D (SpriteFrames):
##   idle_se / idle_sw / idle_ne / idle_nw
##   walk_se / walk_sw / walk_ne / walk_nw
##   attack_se / attack_sw / attack_ne / attack_nw

enum State { IDLE, MOVING, ATTACKING, DEAD }

const DIR_SE := "se"
const DIR_SW := "sw"
const DIR_NE := "ne"
const DIR_NW := "nw"

@export var unit_name: String = "Unit"
@export var max_hp: float = 100.0
@export var move_speed: float = 140.0
@export var weapon_id: StringName = &"rifle"
@export var sight_range: float = 320.0
@export var is_enemy: bool = false

var hp: float
var state: int = State.IDLE
var target: RTSUnit = null  # attack target (null = move order only)
var attack_move_pos: Vector2 = Vector2.INF  # attack-move destination
var selected: bool = false
# --- MVP 2 weapon state ---
var weapon: WeaponData
var ammo_in_mag: int = 0
var reserve_ammo: int = 0
var is_reloading: bool = false
var _reload_timer: float = 0.0

var _nav: NavigationAgent2D
var _sprite: AnimatedSprite2D
var _attack_timer: float = 0.0
var _facing: String = DIR_SE
var _ring: Node2D
var _hp_bar: ProgressBar

signal died(unit: RTSUnit)
signal hp_changed(unit: RTSUnit)


func _ready() -> void:
	hp = max_hp
	_nav = $NavigationAgent2D
	_sprite = $AnimatedSprite2D
	_ring = $SelectionRing
	_hp_bar = $HealthBar
	_nav.max_speed = move_speed
	_nav.path_desired_distance = 6.0
	_nav.target_desired_distance = 10.0
	# RVO avoidance so units don't stack (acceptance: "Unit tidak menumpuk")
	_nav.avoidance_enabled = true
	_nav.radius = 14.0
	equip_weapon(weapon_id)
	_play("idle", _facing)
	_update_selection_visual()
	_update_hp_bar()


## Equip a weapon by id; resets magazine from the weapon's default reserve.
func equip_weapon(id: StringName) -> void:
	weapon = WeaponsDB.get_weapon(id)
	if weapon == null:
		weapon = WeaponsDB.get_weapon(&"rifle")
	weapon_id = weapon.id
	ammo_in_mag = weapon.magazine_size
	reserve_ammo = weapon.reserve_ammo
	is_reloading = false
	_reload_timer = 0.0


func start_reload() -> void:
	if is_reloading or weapon == null:
		return
	if ammo_in_mag >= weapon.magazine_size or reserve_ammo <= 0:
		return
	is_reloading = true
	_reload_timer = weapon.reload_time


func _finish_reload() -> void:
	var need: int = weapon.magazine_size - ammo_in_mag
	var take: int = mini(need, reserve_ammo)
	ammo_in_mag += take
	reserve_ammo -= take
	is_reloading = false


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
	match state:
		State.IDLE:
			_acquire_target()
			velocity = Vector2.ZERO
			move_and_slide()
			if _nav.is_navigation_finished() == false:
				pass
		State.MOVING:
			_follow_path(delta)
			_acquire_target()
		State.ATTACKING:
			_combat(delta)
	_play_state_anim()


func order_move(pos: Vector2) -> void:
	"""Plain move order: clears attack target."""
	if state == State.DEAD:
		return
	target = null
	attack_move_pos = Vector2.INF
	_nav.target_position = pos
	state = State.MOVING


func order_attack_move(pos: Vector2) -> void:
	"""Attack-move: move to pos, engaging enemies seen on the way."""
	if state == State.DEAD:
		return
	target = null
	attack_move_pos = pos
	_nav.target_position = pos
	state = State.MOVING


func order_attack(unit: RTSUnit) -> void:
	"""Focused attack on a specific unit."""
	if state == State.DEAD or unit == null or unit.state == State.DEAD:
		return
	target = unit
	attack_move_pos = Vector2.INF
	state = State.ATTACKING


func order_stop() -> void:
	if state == State.DEAD:
		return
	target = null
	attack_move_pos = Vector2.INF
	_nav.target_position = global_position
	state = State.IDLE
	velocity = Vector2.ZERO


func take_damage(amount: float, from: RTSUnit) -> void:
	if state == State.DEAD:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(self)
	_update_hp_bar()
	if hp <= 0.0:
		_die()
	elif state == State.IDLE and from != null and not from.is_enemy == is_enemy:
		# retaliate when idle and hit by an enemy
		order_attack(from)


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_play("idle", _facing)  # TODO: death anim when extracted
	_sprite.modulate = Color(0.45, 0.45, 0.5, 0.85)
	_ring.visible = false
	_hp_bar.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	_nav.set_deferred("avoidance_enabled", false)
	died.emit(self)
	# fade out after a moment
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_sprite, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)


func _follow_path(_delta: float) -> void:
	if _nav.is_navigation_finished():
		_on_arrived()
		return
	var next_pos: Vector2 = _nav.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	velocity = dir * move_speed
	_update_facing(dir)
	move_and_slide()


func _on_arrived() -> void:
	velocity = Vector2.ZERO
	if attack_move_pos != Vector2.INF:
		# attack-move destination reached; hold and scan
		attack_move_pos = Vector2.INF
	state = State.IDLE


func _acquire_target() -> void:
	"""Auto-acquire nearest enemy in sight while idle or attack-moving."""
	if target != null and is_instance_valid(target) and target.state != State.DEAD:
		if state == State.IDLE or state == State.MOVING:
			state = State.ATTACKING
		return
	var game := _game()
	if game == null:
		return
	var foes: Array = game.get_enemies_of(self)
	var best: RTSUnit = null
	var best_d := sight_range
	for f in foes:
		if f.state == State.DEAD:
			continue
		var d: Vector2 = f.global_position - global_position
		if d.length() < best_d:
			best_d = d.length()
			best = f
	if best != null:
		target = best
		if state == State.IDLE:
			state = State.ATTACKING
		# attack-moving units engage without abandoning their path entirely:
		# they stop to fight, then resume via attack_move_pos still set.


func _combat(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.state == State.DEAD:
		target = null
		# resume attack-move if one was in progress
		if attack_move_pos != Vector2.INF:
			_nav.target_position = attack_move_pos
			state = State.MOVING
		else:
			state = State.IDLE
		return
	var to: Vector2 = target.global_position - global_position
	_update_facing(to.normalized())
	if to.length() > weapon.attack_range:
		# chase
		_nav.target_position = target.global_position
		_follow_path(delta)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		_nav.target_position = global_position
		_try_fire()


func _try_fire() -> void:
	# Out of ammo and nothing to reload with: cannot attack.
	if ammo_in_mag <= 0 and reserve_ammo <= 0:
		return
	# Auto-reload when magazine is empty.
	if ammo_in_mag <= 0:
		start_reload()
		return
	if is_reloading:
		return
	if _attack_timer > 0.0:
		return
	# Line-of-sight check before firing.
	if not _has_los(target):
		return
	_attack_timer = 1.0 / weapon.rate_of_fire
	_play("attack", _facing, true)
	ammo_in_mag -= 1
	# Accuracy roll per pellet.
	for i in weapon.pellets:
		var hit_chance: float = weapon.accuracy * _accuracy_modifier()
		if randf() <= hit_chance:
			target.take_damage(weapon.damage, self)


## Combined accuracy modifier from morale/suppression/cover (MVP 2b hooks).
func _accuracy_modifier() -> float:
	return 1.0


func _has_los(target_unit: RTSUnit) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, target_unit.global_position)
	query.exclude = [self]
	query.collision_mask = 1  # world/obstacle layer
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty()


func _update_facing(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	if dir.x >= 0.0 and dir.y >= 0.0:
		_facing = DIR_SE
	elif dir.x < 0.0 and dir.y >= 0.0:
		_facing = DIR_SW
	elif dir.x >= 0.0 and dir.y < 0.0:
		_facing = DIR_NE
	else:
		_facing = DIR_NW


func _play_state_anim() -> void:
	match state:
		State.IDLE:
			_play("idle", _facing)
		State.MOVING:
			_play("walk", _facing)
		State.ATTACKING:
			var cd: float = 1.0 / weapon.rate_of_fire if weapon else 0.8
			if _attack_timer > cd * 0.5:
				pass  # attack anim already triggered
			elif target != null:
				_play("attack", _facing)
			else:
				_play("idle", _facing)


func _play(base: String, dir: String, restart := false) -> void:
	var anim := "%s_%s" % [base, dir]
	if _sprite.sprite_frames.has_animation(anim):
		if restart or _sprite.animation != anim:
			_sprite.play(anim)


func set_selected(v: bool) -> void:
	selected = v
	_update_selection_visual()


func _update_selection_visual() -> void:
	_ring.visible = selected and state != State.DEAD
	_ring.queue_redraw()


func _update_hp_bar() -> void:
	_hp_bar.value = 100.0 * hp / max_hp
	_hp_bar.visible = state != State.DEAD and hp < max_hp


func _game() -> Node:
	return get_tree().current_scene
