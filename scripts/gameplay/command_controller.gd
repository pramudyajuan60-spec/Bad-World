extends Node2D
## Raw input -> RTS command glue. Extends Node2D (not Node) purely to get
## get_global_mouse_position() for free, which already accounts for the
## active camera's pan/zoom.
##
## Hotkeys implemented for MVP 1 (subset of the full Prompt Dasar list;
## Patrol/Guard/Tab-cycle/control-group-recenter are later MVPs):
##   Left click            select one / start box-drag
##   Shift + left click    add/remove from selection
##   Drag + release        box select
##   Double-click          select all same-tier units currently spawned
##   Right click ground    move (with formation spacing)
##   Right click enemy     attack
##   A, then right click   attack-move (one-shot "armed" mode)
##
## MVP2 additions:
##   D                     Defend/Cover Mode (move to nearest cover, hold)
##   G, then right click   throw grenade at that ground position
##   R, then right click a downed enemy   recruit instead of execute
##                         (only takes effect if the Main Character is
##                         among the selected units)
##   Right click a downed ally    revive
##   Right click a downed enemy   execute (default) or recruit (armed)
##   S                     stop
##   Ctrl+1..9             assign control group
##   1..9                  recall control group
##   Escape                pause menu (emits pause_requested)

signal pause_requested

var camera: RtsCamera
var selection_manager: SelectionManager
var overlay: Node2D
var markers_parent: Node
var destination_marker_scene: PackedScene
## Populated/maintained by the owning gameplay scene; not queried via
## get_tree() groups so tests can substitute a plain array.
var enemy_units: Array = []
## MVP3: returns all Vehicle instances currently in the mission (both
## player-owned and hostile), set by the owning gameplay scene.
var vehicles_getter: Callable = Callable()
var _patrol_armed: bool = false
const VEHICLE_PICK_RADIUS := 40.0

var _box_start: Vector2 = Vector2.ZERO
var _box_dragging: bool = false
var _attack_move_armed: bool = false
var _grenade_armed: bool = false
var _recruit_armed: bool = false
## MVP4: set by ability_bar.gd when an ACTIVE_AOE ability (e.g. Throw
## Drug Bottle) is pressed; the next ground right-click triggers it
## instead of a normal move order, mirroring the grenade-armed flow.
var _ability_armed_id: StringName = &""
var _ability_armed_caster: BwUnit = null

const CLICK_VS_DRAG_THRESHOLD := 8.0
const SELECT_PICK_RADIUS := 18.0
const ATTACK_PICK_RADIUS := 20.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _box_dragging:
		if overlay:
			overlay.update_box(_box_start, get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var mp := get_global_mouse_position()
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				_handle_double_click(mp)
			else:
				_box_start = mp
				_box_dragging = true
				if overlay:
					overlay.update_box(mp, mp)
		else:
			if _box_dragging:
				_box_dragging = false
				if overlay:
					overlay.hide_box()
				var rect := Rect2(_box_start, mp - _box_start).abs()
				if rect.size.length() > CLICK_VS_DRAG_THRESHOLD:
					var units := SelectionManager.units_in_rect(selection_manager.player_units, rect)
					if event.shift_pressed:
						selection_manager.toggle_selection(units)
					else:
						selection_manager.select_only(units)
				else:
					_handle_single_click(mp, event.shift_pressed)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click(mp)
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and camera:
		camera.zoom_step(-1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and camera:
		camera.zoom_step(1)


func _handle_single_click(pos: Vector2, shift: bool) -> void:
	var clicked := _find_nearest_in(pos, selection_manager.player_units, SELECT_PICK_RADIUS)
	if clicked:
		if shift:
			selection_manager.toggle_selection([clicked])
		else:
			selection_manager.select_only([clicked])
	elif not shift:
		selection_manager.clear_selection()


func _handle_double_click(pos: Vector2) -> void:
	var clicked := _find_nearest_in(pos, selection_manager.player_units, SELECT_PICK_RADIUS)
	if clicked:
		var same := SelectionManager.units_of_same_tier(selection_manager.player_units, clicked)
		selection_manager.select_only(same)


func arm_ability_targeting(ability_id: StringName, caster: BwUnit) -> void:
	_ability_armed_id = ability_id
	_ability_armed_caster = caster


func _handle_right_click(pos: Vector2) -> void:
	if _ability_armed_id != &"" and _ability_armed_caster != null and is_instance_valid(_ability_armed_caster):
		_ability_armed_caster.try_use_ability(_ability_armed_id, pos)
		_ability_armed_id = &""
		_ability_armed_caster = null
		return
	if selection_manager.selected.is_empty():
		return
	var selected: Array = selection_manager.selected
	var enemy := _find_nearest_in(pos, enemy_units, ATTACK_PICK_RADIUS)
	if enemy:
		if enemy.state == BwUnit.State.DOWNED:
			if _recruit_armed and _selection_has_main_character(selected) and enemy.is_recruitable_tier:
				for u in selected:
					u.order_recruit_downed(enemy)
			else:
				for u in selected:
					u.order_execute(enemy)
		else:
			for u in selected:
				u.order_attack(enemy)
		_attack_move_armed = false
		_grenade_armed = false
		_recruit_armed = false
		return
	var downed_ally := _find_downed_ally(pos, selected)
	if downed_ally:
		for u in selected:
			u.order_revive(downed_ally)
		_attack_move_armed = false
		_grenade_armed = false
		_recruit_armed = false
		return
	var vehicle = _find_nearest_vehicle(pos)
	if vehicle and vehicle.faction_side == &"player" and vehicle.has_free_seat():
		for u in selected:
			if u.mounted_vehicle == null:
				u.order_enter_vehicle(vehicle)
		_attack_move_armed = false
		_grenade_armed = false
		_recruit_armed = false
		return
	if _patrol_armed:
		for u in selected:
			u.order_patrol(pos)
		_spawn_destination_marker(pos)
		_patrol_armed = false
		_attack_move_armed = false
		_grenade_armed = false
		_recruit_armed = false
		return
	if _grenade_armed:
		for u in selected:
			u.order_use_grenade(pos)
		_spawn_destination_marker(pos)
	else:
		var positions := FormationUtils.compute_positions(pos, selected.size(), 40.0)
		for i in range(selected.size()):
			var u: BwUnit = selected[i]
			if _attack_move_armed:
				u.order_attack_move(positions[i])
			else:
				u.order_move(positions[i])
		_spawn_destination_marker(pos)
	_attack_move_armed = false
	_grenade_armed = false
	_recruit_armed = false


func _selection_has_main_character(selected: Array) -> bool:
	for u in selected:
		if is_instance_valid(u) and u.tier_label == "MC":
			return true
	return false


func _find_downed_ally(pos: Vector2, selected: Array) -> BwUnit:
	var nearest: BwUnit = null
	var nearest_dist := SELECT_PICK_RADIUS
	for u in selection_manager.player_units:
		if not is_instance_valid(u) or u.state != BwUnit.State.DOWNED or u in selected:
			continue
		var d: float = pos.distance_to(u.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = u
	return nearest


func _find_nearest_vehicle(pos: Vector2):
	if not vehicles_getter.is_valid():
		return null
	var vehicles: Array = vehicles_getter.call()
	var nearest = null
	var nearest_dist := VEHICLE_PICK_RADIUS
	for v in vehicles:
		if not is_instance_valid(v):
			continue
		var d: float = pos.distance_to(v.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = v
	return nearest


func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_S:
			for u in selection_manager.selected:
				u.order_stop()
		KEY_A:
			_attack_move_armed = true
		KEY_D:
			for u in selection_manager.selected:
				u.order_defend()
		KEY_G:
			_grenade_armed = true
		KEY_R:
			_recruit_armed = true
		KEY_P:
			_patrol_armed = true
		KEY_X:
			for u in selection_manager.selected:
				if u.mounted_vehicle != null:
					u.mounted_vehicle.exit_unit(u)
		KEY_ESCAPE:
			pause_requested.emit()
		_:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				var n: int = event.keycode - KEY_1 + 1
				if event.ctrl_pressed:
					selection_manager.assign_control_group(n)
				else:
					selection_manager.recall_control_group(n)


func _find_nearest_in(pos: Vector2, units: Array, max_dist: float) -> BwUnit:
	var nearest: BwUnit = null
	var nearest_dist := max_dist
	for u in units:
		if not is_instance_valid(u):
			continue
		var d: float = pos.distance_to(u.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = u
	return nearest


func _spawn_destination_marker(pos: Vector2) -> void:
	if destination_marker_scene == null or markers_parent == null:
		return
	var marker := destination_marker_scene.instantiate()
	markers_parent.add_child(marker)
	marker.global_position = pos
