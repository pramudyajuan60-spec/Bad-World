class_name Vehicle
extends CharacterBody2D
## MVP 3 drivable vehicle: carries units/cargo, turret shoots on the move.

var vdata: VehicleData
var hp: float
var passengers: Array[RTSUnit] = []
var carried_cargo: int = 0
var selected: bool = false
var _nav: NavigationAgent2D
var _turret_timer: float = 0.0
var _turret_target: RTSUnit = null
var _ring: Node2D

signal destroyed(vehicle: Vehicle)


func setup(data: VehicleData) -> void:
	vdata = data
	hp = data.max_hp


func _ready() -> void:
	add_to_group("vehicles")
	_nav = $NavigationAgent2D
	_nav.max_speed = vdata.move_speed
	_nav.avoidance_enabled = true
	_nav.radius = 22.0
	_ring = $SelectionRing
	_update_selection_visual()
	# simple visual: rounded rect body
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-30, -18), Vector2(30, -18),
		Vector2(30, 18), Vector2(-30, 18)])
	vis.color = Color(0.45, 0.45, 0.5, 0.95)
	add_child(vis)
	move_child(vis, 0)


func _physics_process(delta: float) -> void:
	_turret_timer = maxf(0.0, _turret_timer - delta)
	if not _nav.is_navigation_finished():
		var dir: Vector2 = _nav.get_next_path_position() - global_position
		if dir.length() > 4.0:
			velocity = dir.normalized() * vdata.move_speed
		else:
			velocity = Vector2.ZERO
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		move_and_slide()
	_update_turret(delta)


func order_move(pos: Vector2) -> void:
	_nav.target_position = pos


func board(unit: RTSUnit) -> bool:
	if passengers.size() >= vdata.seat_capacity:
		return false
	if unit.state == RTSUnit.State.DEAD or unit.state == RTSUnit.State.DOWNED:
		return false
	# transfer cargo/cash to vehicle
	carried_cargo = mini(vdata.cargo_capacity, carried_cargo + unit.carried_cargo)
	unit.carried_cargo = 0
	passengers.append(unit)
	unit.visible = false
	unit.set_physics_process(false)
	unit.global_position = global_position
	return true


func disembark(game: Node) -> void:
	for i in passengers.size():
		var u: RTSUnit = passengers[i]
		u.visible = true
		u.set_physics_process(true)
		u.global_position = global_position + Vector2(40 + i * 30, 0)
		u.order_stop()
	passengers.clear()


func _update_turret(delta: float) -> void:
	if not vdata.has_turret:
		return
	# acquire target
	if _turret_target == null or not is_instance_valid(_turret_target) \
			or _turret_target.state == RTSUnit.State.DEAD:
		_turret_target = _find_target()
	if _turret_target == null:
		return
	var dist: float = global_position.distance_to(_turret_target.global_position)
	if dist > vdata.turret_range:
		_turret_target = null
		return
	if _turret_timer <= 0.0:
		_turret_timer = 1.0 / vdata.turret_rof
		var acc: float = 0.70
		if velocity.length() > 10.0:
			acc -= vdata.moving_accuracy_penalty  # moving turret penalty
		if randf() <= acc:
			_turret_target.take_damage(vdata.turret_damage, null)


func _find_target() -> RTSUnit:
	var game := get_tree().current_scene
	var best: RTSUnit = null
	var best_d := vdata.turret_range
	# vehicles are player-owned in MVP 3; target enemies
	for u in game.get_nodes_in_group("units"):
		var ru := u as RTSUnit
		if ru == null or ru.is_enemy == false or ru.state == RTSUnit.State.DEAD:
			continue
		var d: float = global_position.distance_to(ru.global_position)
		if d < best_d:
			best_d = d
			best = ru
	return best


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		_explode()


func _explode() -> void:
	# passengers die with the vehicle (simplified)
	for u in passengers:
		u.take_damage(99999.0, null)
	destroyed.emit(self)
	queue_free()


func set_selected(v: bool) -> void:
	selected = v
	_update_selection_visual()


func _update_selection_visual() -> void:
	if _ring:
		_ring.visible = selected
		_ring.queue_redraw()
