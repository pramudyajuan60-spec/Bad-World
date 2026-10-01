class_name BwUnit
extends CharacterBody2D
## Generic RTS unit for MVP 1's vertical slice: covers Main Character, B1,
## and the dummy enemy squad with one script. Combat here is intentionally
## a flat, accuracy-gated placeholder (no weapon/ammo/line-of-sight) — the
## real weapon-data-driven combat system is MVP 2 (Prompt Dasar "COMBAT
## DAN COVER"). No downed state yet either (also MVP 2); death is final.
##
## In-world visuals (body/ring/health bar) are procedurally drawn
## placeholders, not final sprites — see docs/PLACEHOLDER_REGISTER.md.
## Real per-unit portraits (for HUD, not the world sprite) are wired up by
## the scene that spawns this unit.

signal died(unit)
signal hp_changed(unit, ratio)
signal selection_changed(unit, is_selected)

enum State { IDLE, MOVING, ATTACK_MOVING, ATTACKING, DEAD }

@export var unit_id: StringName = &""
@export var display_name: String = ""
## Display-only tier tag: "MC", "B1", "ENEMY", etc.
@export var tier_label: String = ""
## "player" or "enemy_dummy" for MVP 1. Combat only targets a differing side.
@export var faction_side: StringName = &"player"
@export var can_move: bool = true
## Enemy dummies fight back if a hostile unit wanders into range, even
## though they never receive player orders.
@export var auto_defend: bool = false

@export var max_hp: float = 100.0
@export var move_speed_px: float = 190.0
@export var accuracy: float = 0.55
@export var attack_damage: float = 12.0
@export var attack_range: float = 90.0
@export var attack_interval: float = 1.1
@export var acquire_range: float = 140.0

var hp: float
var state: int = State.IDLE
var attack_target: BwUnit = null
var attack_move_destination = null
var is_selected: bool = false

var _attack_timer: float = 0.0

@onready var nav_agent: NavigationAgent2D = $NavAgent
@onready var body_poly: Polygon2D = $Body
@onready var selection_ring: Node2D = $SelectionRing
@onready var health_bar: Node2D = $HealthBar
@onready var tier_label_node: Label = $TierLabel


func _ready() -> void:
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


func order_move(target: Vector2) -> void:
	if state == State.DEAD or not can_move:
		return
	attack_target = null
	attack_move_destination = null
	state = State.MOVING
	nav_agent.target_position = target


func order_attack_move(target: Vector2) -> void:
	if state == State.DEAD or not can_move:
		return
	attack_target = null
	attack_move_destination = target
	state = State.ATTACK_MOVING
	nav_agent.target_position = target


func order_attack(target: BwUnit) -> void:
	if state == State.DEAD or target == null:
		return
	attack_target = target
	attack_move_destination = null
	state = State.ATTACKING


func order_stop() -> void:
	attack_target = null
	attack_move_destination = null
	state = State.IDLE
	velocity = Vector2.ZERO


func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	hp = max(0.0, hp - amount)
	if health_bar:
		health_bar.set_ratio(hp / max_hp)
	hp_changed.emit(self, hp / max_hp)
	if hp <= 0.0:
		_die()


## Used by save/load to restore a persisted HP value after _ready() has
## already reset hp to max_hp.
func set_hp(value: float) -> void:
	hp = clampf(value, 0.0, max_hp)
	if health_bar:
		health_bar.set_ratio(hp / max_hp)
	if hp <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	died.emit(self)
	queue_free()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	match state:
		State.MOVING:
			_process_movement()
		State.ATTACK_MOVING:
			_process_attack_move()
		State.ATTACKING:
			_process_attacking(delta)
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


func _process_attacking(delta: float) -> void:
	if attack_target == null or not is_instance_valid(attack_target) or attack_target.state == State.DEAD:
		attack_target = null
		if attack_move_destination != null:
			state = State.ATTACK_MOVING
			nav_agent.target_position = attack_move_destination
		else:
			state = State.IDLE
		return
	var dist: float = global_position.distance_to(attack_target.global_position)
	if dist > attack_range:
		nav_agent.target_position = attack_target.global_position
		_move_towards_next_path_point()
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = attack_interval
			if randf() <= accuracy:
				attack_target.take_damage(attack_damage)


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


func _find_nearest_enemy(max_range: float) -> BwUnit:
	var nodes := get_tree().get_nodes_in_group("bw_units")
	var nearest: BwUnit = null
	var nearest_dist := max_range
	for n in nodes:
		if n == self or not (n is BwUnit):
			continue
		var u: BwUnit = n
		if u.faction_side == faction_side or u.state == State.DEAD:
			continue
		var d: float = global_position.distance_to(u.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = u
	return nearest
