class_name Vehicle
extends CharacterBody2D
## Drivable vehicle (Prompt Dasar MVP3 "KENDARAAN"). Implements the same
## public method names SelectionManager/CommandController already use
## for BwUnit (set_selected, order_move, order_stop, global_position,
## faction_side, tier_label) via duck typing, so the existing RTS
## selection/command code needs only small additions to also recognize
## vehicles — see docs/TECH_DECISIONS.md "Vehicle mounting model".
##
## Seating: the first unit to enter becomes the driver (required to
## move); further units up to seat_capacity are passengers. A Gun
## Truck/APC's turret auto-fires at the nearest in-range hostile
## whenever any seat is occupied, applying a moving-accuracy penalty
## when the vehicle's velocity is non-zero, per Prompt Dasar.

signal died(vehicle)
signal hp_changed(vehicle, ratio)
signal selection_changed(vehicle, is_selected)

const ENTER_RANGE := 60.0
const REPAIR_COST_PER_HP := 4.0
## Vehicle's own cargo/cash hold, separate from any passenger's personal
## carry (Prompt Dasar: "Kendaraan mengangkut unit/cargo/cash").
const CARGO_CAPACITY := 6

@export var vehicle_data: VehicleData = null
@export var faction_side: StringName = &"player"
var tier_label: String = "VEHICLE"

var hp: float = 100.0
var max_hp: float = 100.0
var is_selected: bool = false
var seats: Array = [] # Array[BwUnit]
var driver = null # BwUnit or null
var carried_cargo: int = 0
var carried_cash: int = 0

var _turret_weapon: WeaponData = null
var _turret_target = null
var _fire_timer: float = 0.0
var _combat_log: Node = null

@onready var nav_agent: NavigationAgent2D = $NavAgent
@onready var body_poly: Polygon2D = $Body
@onready var selection_ring: Node2D = $SelectionRing
@onready var health_bar: Node2D = $HealthBar


func _ready() -> void:
	_combat_log = get_node_or_null("/root/CombatLog")
	if vehicle_data != null:
		max_hp = 150.0 + vehicle_data.seat_capacity * 20.0 # simple MVP3 HP-by-class assumption, see docs/BALANCE.md
		if vehicle_data.has_turret:
			_turret_weapon = load("res://data/weapons/vehicle_mg.tres")
	hp = max_hp
	add_to_group("bw_vehicles")
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.radius = 22.0
	nav_agent.avoidance_enabled = true
	nav_agent.max_speed = 260.0
	_setup_body_visual()
	health_bar.set_ratio(1.0)
	set_selected(false)


func _setup_body_visual() -> void:
	var pts := PackedVector2Array([
		Vector2(-26, -18), Vector2(26, -18), Vector2(30, 0), Vector2(26, 18), Vector2(-26, 18), Vector2(-30, 0),
	])
	body_poly.polygon = pts
	body_poly.color = Color(0.2, 0.55, 0.25) if faction_side == &"player" else Color(0.6, 0.25, 0.1)


func set_selected(value: bool) -> void:
	is_selected = value
	if selection_ring:
		selection_ring.visible = value
	selection_changed.emit(self, value)


## ---------------------------------------------------------------
## Seating
## ---------------------------------------------------------------
func has_free_seat() -> bool:
	var capacity: int = vehicle_data.seat_capacity if vehicle_data else 4
	return seats.size() < capacity


func enter(unit) -> bool:
	if not has_free_seat() or hp <= 0.0:
		return false
	var as_driver: bool = driver == null
	seats.append(unit)
	if as_driver:
		driver = unit
	unit.mount_vehicle(self, as_driver)
	return true


func exit_all() -> void:
	var offset := Vector2(40, 0)
	for unit in seats.duplicate():
		unit.unmount_vehicle(global_position + offset)
		offset = offset.rotated(TAU / max(seats.size(), 1))
	seats.clear()
	driver = null


func exit_unit(unit) -> void:
	if not (unit in seats):
		return
	seats.erase(unit)
	unit.unmount_vehicle(global_position + Vector2(40, 0))
	if driver == unit:
		driver = seats[0] if seats.size() > 0 else null
		if driver:
			driver.is_driver = true


## ---------------------------------------------------------------
## Orders (mirrors BwUnit's public API so CommandController can treat
## a driven vehicle the same way it treats a selected unit)
## ---------------------------------------------------------------
func order_move(target: Vector2) -> void:
	if driver == null or hp <= 0.0:
		return
	nav_agent.target_position = target


func order_stop() -> void:
	nav_agent.target_position = global_position
	velocity = Vector2.ZERO


func take_damage(amount: float, attacker = null) -> void:
	if hp <= 0.0:
		return
	hp = max(0.0, hp - amount)
	if health_bar:
		health_bar.set_ratio(hp / max_hp)
	hp_changed.emit(self, hp / max_hp)
	if hp <= 0.0:
		_destroy()


func repair_cost() -> int:
	return int(ceil((max_hp - hp) * REPAIR_COST_PER_HP))


func repair_full() -> void:
	hp = max_hp
	if health_bar:
		health_bar.set_ratio(1.0)


func _destroy() -> void:
	if _combat_log:
		_combat_log.log_event("A %s was destroyed." % (vehicle_data.display_name if vehicle_data else "vehicle"))
	exit_all()
	died.emit(self)
	queue_free()


## ---------------------------------------------------------------
## Physics
## ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	if driver != null and not nav_agent.is_navigation_finished():
		_move_towards_next_path_point()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
	if _turret_weapon != null and seats.size() > 0:
		_process_turret(delta)


func _move_towards_next_path_point() -> void:
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = next_pos - global_position
	if direction.length() > 0.001:
		direction = direction.normalized()
	nav_agent.velocity = direction * nav_agent.max_speed


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()


func _process_turret(delta: float) -> void:
	if _turret_target == null or not is_instance_valid(_turret_target) or _turret_target.state == BwUnit.State.DEAD or _turret_target.state == BwUnit.State.DOWNED:
		_turret_target = _find_nearest_enemy(_turret_weapon.range_px)
	if _turret_target == null:
		return
	var dist: float = global_position.distance_to(_turret_target.global_position)
	if dist > _turret_weapon.range_px:
		_turret_target = null
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = _turret_weapon.fire_interval_sec()
		# Moving-turret accuracy penalty (Prompt Dasar "KENDARAAN"): converted
		# from an accuracy-point penalty into an equivalent hit-chance
		# reduction since vehicles don't carry a base "accuracy" stat.
		var moving_penalty: float = (vehicle_data.moving_accuracy_penalty / 100.0) if (vehicle_data and velocity.length() > 5.0) else 0.0
		if randf() <= clampf(0.75 - moving_penalty, 0.05, 0.95):
			_turret_target.take_damage(_turret_weapon.damage, self)


func _find_nearest_enemy(max_range: float):
	var tree := get_tree()
	if tree == null:
		return null
	var nearest = null
	var nearest_dist := max_range
	for n in tree.get_nodes_in_group("bw_units"):
		if not (n is BwUnit) or not is_instance_valid(n):
			continue
		if n.faction_side == faction_side or n.state == BwUnit.State.DEAD or n.state == BwUnit.State.DOWNED:
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = n
	return nearest


## ---------------------------------------------------------------
## Cargo/cash carried by the vehicle itself
## ---------------------------------------------------------------
func pickup_loot(cargo: int, cash: int) -> void:
	var room: int = CARGO_CAPACITY - carried_cargo
	carried_cargo += min(room, cargo)
	carried_cash += cash
