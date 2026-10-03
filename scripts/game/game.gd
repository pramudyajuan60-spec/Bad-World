extends Node2D
## MVP 1 — Juan Bellarosa Core RTS Vertical Slice.
## Owns: map setup, unit spawning, selection (click/shift/box/double-click),
## orders (move / attack-move / stop), control groups, formation offsets,
## pause/restart, save/load, and the HUD hooks.

const UnitScene := preload("res://scenes/game/Unit.tscn")
const B1_FRAMES := preload("res://data/animations/unit_b1.tres")
const JUAN_FRAMES := preload("res://data/animations/unit_juan.tres")

const MAP_BOUNDS := Rect2(-1600, -1200, 3200, 2400)
const FORMATION_SPACING := 56.0

var selection_dragging: bool = false  # read by RTSCamera to pause edge-pan

var _units: Array[RTSUnit] = []
var _selected: Array[RTSUnit] = []
var _groups: Dictionary = {}  # int -> Array[RTSUnit]
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO
var _last_click_time: int = 0
var _last_click_unit: RTSUnit = null
var _attack_move_pending: bool = false
var _paused: bool = false
# --- MVP 2d: economy ---
var money: int = 4000
var morale: float = 100.0  # 0..100, affects accuracy
var payroll_timer: float = 120.0
const PAYROLL_INTERVAL: float = 120.0
var missed_payrolls: int = 0

@onready var _camera: RTSCamera = $RTSCamera
@onready var _select_box: Line2D = $SelectBox
@onready var _hud: CanvasLayer = $HUD


func _process(delta: float) -> void:
	if _paused:
		return
	# Payroll every 120s.
	payroll_timer -= delta
	if payroll_timer <= 0.0:
		payroll_timer = PAYROLL_INTERVAL
		_run_payroll()
	# Morale recovers slowly when paid.
	if missed_payrolls == 0 and morale < 100.0:
		morale = minf(100.0, morale + delta * 2.0)
	# Refresh economy HUD (payroll countdown ticks).
	_hud.update_economy(money, morale, payroll_timer)


func _total_salary() -> int:
	var total := 0
	for u in _units:
		if u.is_enemy or u.state == RTSUnit.State.DEAD:
			continue
		total += u.salary
	return total


func _run_payroll() -> void:
	var due := _total_salary()
	if due <= 0:
		return
	if money >= due:
		money -= due
		missed_payrolls = 0
		_hud.flash("Payroll paid: $%d" % due)
	else:
		missed_payrolls += 1
		morale = maxf(0.0, morale - 25.0)
		_hud.flash("WARNING: Can't pay salaries! Morale dropping.", true)
		if missed_payrolls >= 2:
			# B1 may desert; others get combat penalty (handled via morale)
			for u in _units.duplicate():
				if not u.is_enemy and u.unit_tier == 1 and u.unit_name != "Juan Bellarosa":
					if randf() < 0.3:
						_hud.flash(u.unit_name + " deserted!", true)
						_remove_unit(u)
	_update_hud()


func _remove_unit(u: RTSUnit) -> void:
	_units.erase(u)
	_selected.erase(u)
	u.queue_free()


func _ready() -> void:
	_camera.map_bounds = MAP_BOUNDS
	_build_map()
	_spawn_initial_units()
	_hud.get_node("Hint").text = (
		"LMB: select | Shift+LMB: add | Drag: box | Double-click: select type\n"
		+ "RMB: move | A+RMB: attack-move | S: stop | D: defend | R: reload\n"
		+ "F1/F2/F3: recruit B1/B2/B3 | Ctrl+1..9 / 1..9: groups | Esc: pause")


func _build_map() -> void:
	# Ground
	var ground := Polygon2D.new()
	ground.name = "Ground"
	var r := MAP_BOUNDS
	ground.polygon = PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0),
		r.position + r.size, r.position + Vector2(0, r.size.y)])
	ground.color = Color(0.16, 0.19, 0.14)
	add_child(ground)
	move_child(ground, 0)
	# subtle grid
	var grid := Node2D.new()
	grid.name = "Grid"
	add_child(grid)
	move_child(grid, 1)
	for gx in range(int(r.position.x), int(r.position.x + r.size.x) + 1, 160):
		var ln := Line2D.new()
		ln.points = PackedVector2Array([Vector2(gx, r.position.y), Vector2(gx, r.position.y + r.size.y)])
		ln.default_color = Color(1, 1, 1, 0.045)
		ln.width = 1.0
		grid.add_child(ln)
	for gy in range(int(r.position.y), int(r.position.y + r.size.y) + 1, 160):
		var ln2 := Line2D.new()
		ln2.points = PackedVector2Array([Vector2(r.position.x, gy), Vector2(r.position.x + r.size.x, gy)])
		ln2.default_color = Color(1, 1, 1, 0.045)
		ln2.width = 1.0
		grid.add_child(ln2)
	# Obstacles (buildings/crates) + navigation
	var obstacles: Array[Rect2] = [
		Rect2(-500, -500, 220, 160),
		Rect2(200, -350, 160, 220),
		Rect2(-350, 250, 260, 140),
		Rect2(450, 350, 200, 180),
		Rect2(-900, 100, 140, 300),
	]
	for ob in obstacles:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			ob.position, ob.position + Vector2(ob.size.x, 0),
			ob.position + ob.size, ob.position + Vector2(0, ob.size.y)])
		poly.color = Color(0.32, 0.28, 0.24)
		add_child(poly)
	# Navigation region with obstacle holes
	var nav := NavigationRegion2D.new()
	nav.name = "NavRegion"
	add_child(nav)
	var navpoly := NavigationPolygon.new()
	var outline := PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0),
		r.position + r.size, r.position + Vector2(0, r.size.y)])
	navpoly.add_outline(outline)
	for ob in obstacles:
		navpoly.add_outline(PackedVector2Array([
			ob.position, ob.position + Vector2(0, ob.size.y),
			ob.position + ob.size, ob.position + Vector2(ob.size.x, 0)]))
	navpoly.make_polygons_from_outlines()
	nav.navigation_polygon = navpoly
	# Map border visual
	var border := Line2D.new()
	border.points = PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0),
		r.position + r.size, r.position + Vector2(0, r.size.y), r.position])
	border.default_color = Color(0.9, 0.75, 0.4, 0.8)
	border.width = 4.0
	add_child(border)
	# MVP 2d: Recruitment building (player base, bottom-left)
	_spawn_recruit_building(Vector2(-1250, 950))
	# MVP 2e: Gun shop near recruitment
	_spawn_gun_shop(Vector2(-1050, 950))
	# MVP 2f: Safe zone covering player base (recruit + gun shop)
	var sz := SafeZone.new()
	sz.position = Vector2(-1150, 950)
	sz.radius = 280.0
	add_child(sz)
	# MVP 2 cover points (sandbags/crates): directional, don't block LoS
	var cover_spots: Array[Vector2] = [
		Vector2(-700, 500), Vector2(-300, 600), Vector2(100, 400),
		Vector2(600, -200), Vector2(300, -500), Vector2(-100, -300),
	]
	for spot in cover_spots:
		var cp := CoverPoint.new()
		cp.position = spot
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(56, 24)
		shape.shape = rect
		cp.add_child(shape)
		# collision on cover layer (2) so it doesn't block unit movement/LoS ray
		cp.collision_layer = 2
		cp.collision_mask = 0
		var vis := Polygon2D.new()
		vis.polygon = PackedVector2Array([
			Vector2(-28, -12), Vector2(28, -12),
			Vector2(28, 12), Vector2(-28, 12)])
		vis.color = Color(0.55, 0.48, 0.32, 0.9)
		cp.add_child(vis)
		add_child(cp)


func _spawn_recruit_building(pos: Vector2) -> void:
	var b := RecruitBuilding.new()
	b.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 100)
	shape.shape = rect
	b.add_child(shape)
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-60, -50), Vector2(60, -50),
		Vector2(60, 50), Vector2(-60, 50)])
	vis.color = Color(0.35, 0.42, 0.55, 0.95)
	b.add_child(vis)
	var label := Label.new()
	label.text = "RECRUIT"
	label.position = Vector2(-35, -10)
	label.add_theme_font_size_override("font_size", 14)
	b.add_child(label)
	add_child(b)
	b.recruit_complete.connect(_on_recruit_complete.bind(b))


func _spawn_gun_shop(pos: Vector2) -> void:
	var s := GunShop.new()
	s.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 80)
	shape.shape = rect
	s.add_child(shape)
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-50, -40), Vector2(50, -40),
		Vector2(50, 40), Vector2(-50, 40)])
	vis.color = Color(0.55, 0.38, 0.25, 0.95)
	s.add_child(vis)
	var label := Label.new()
	label.text = "GUN SHOP"
	label.position = Vector2(-38, -10)
	label.add_theme_font_size_override("font_size", 13)
	s.add_child(label)
	add_child(s)


func _on_recruit_complete(tier: int, building: RecruitBuilding) -> void:
	var data: Dictionary = RecruitBuilding.RECRUIT_DATA[tier]
	var spawn_pos: Vector2 = building.position + Vector2(100, 0)
	var u := _spawn_unit("%s-%d" % [data["name"], _units.size() + 1],
		B1_FRAMES, spawn_pos, false, {
			"max_hp": data["hp"],
			"weapon_id": data["weapon"],
			"unit_tier": tier,
			"salary": data["salary"],
		})
	_hud.flash("%s recruited!" % data["name"])


func get_unit_count() -> int:
	var n := 0
	for u in _units:
		if not u.is_enemy and u.state != RTSUnit.State.DEAD:
			n += 1
	return n


func _spawn_initial_units() -> void:
	# Juan + 3x B1 (per MVP 1 spec), player side, bottom-left area
	_spawn_unit("Juan Bellarosa", JUAN_FRAMES, Vector2(-1100, 800),
		false, {"max_hp": 220.0, "move_speed": 165.0, "weapon_id": &"rifle"})
	var b1_pos := [Vector2(-1000, 850), Vector2(-1050, 720), Vector2(-950, 740)]
	for i in 3:
		_spawn_unit("B1-%d" % (i + 1), B1_FRAMES, b1_pos[i], false, {})
	# Dummy enemy group: 3 hostiles, top-right area (reuse B1 art, red tint)
	var e_pos := [Vector2(900, -700), Vector2(1000, -650), Vector2(950, -780)]
	for i in 3:
		var e := _spawn_unit("Hostile-%d" % (i + 1), B1_FRAMES, e_pos[i], true, {})
		e.modulate = Color(1.0, 0.45, 0.45)


func _spawn_unit(u_name: String, frames: SpriteFrames, pos: Vector2,
		is_enemy: bool, stats: Dictionary) -> RTSUnit:
	var u: RTSUnit = UnitScene.instantiate()
	u.unit_name = u_name
	u.is_enemy = is_enemy
	add_child(u)
	u.global_position = pos
	u.get_node("AnimatedSprite2D").sprite_frames = frames
	for k in stats:
		u.set(k, stats[k])
	u.died.connect(_on_unit_died)
	_units.append(u)
	return u


# ---------------------------------------------------------------- selection

func _unhandled_input(event: InputEvent) -> void:
	if _paused:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_drag(mb.position)
			else:
				_end_drag(mb.position, mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_issue_right_click(mb.position, mb.shift_pressed)
	elif event is InputEventMouseMotion:
		if selection_dragging:
			_drag_current = get_global_mouse_position()
			_update_select_box()
	elif event.is_action_pressed("ui_cancel"):
		_toggle_pause()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_hotkey(event as InputEventKey)


func _begin_drag(mouse_px: Vector2) -> void:
	selection_dragging = true
	_drag_start = get_global_mouse_position()
	_drag_current = _drag_start


func _end_drag(mouse_px: Vector2, additive: bool) -> void:
	selection_dragging = false
	_select_box.visible = false
	var end := get_global_mouse_position()
	if _drag_start.distance_to(end) < 12.0:
		_click_select(end, additive)
	else:
		_box_select(Rect2(_drag_start, end - _drag_start).abs(), additive)


func _click_select(world_pos: Vector2, additive: bool) -> void:
	var u := _unit_at(world_pos)
	var now := Time.get_ticks_msec()
	if u != null and not u.is_enemy:
		# double-click: select all visible units of the same frames
		if _last_click_unit == u and now - _last_click_time < 400:
			_select_type(u, additive)
		else:
			if additive:
				_toggle_select(u)
			else:
				_select_only([u])
		_last_click_unit = u
		_last_click_time = now
	else:
		if not additive:
			_select_only([])
		_last_click_unit = null


func _box_select(rect: Rect2, additive: bool) -> void:
	var found: Array[RTSUnit] = []
	for u in _units:
		if u.is_enemy or u.state == RTSUnit.State.DEAD:
			continue
		if rect.has_point(u.global_position):
			found.append(u)
	if additive:
		for u in found:
			if not u in _selected:
				_selected.append(u)
				u.set_selected(true)
	else:
		_select_only(found)
	_update_hud()


func _select_type(u: RTSUnit, additive: bool) -> void:
	var frames: SpriteFrames = u.get_node("AnimatedSprite2D").sprite_frames
	var found: Array[RTSUnit] = []
	for o in _units:
		if o.is_enemy or o.state == RTSUnit.State.DEAD:
			continue
		if o.get_node("AnimatedSprite2D").sprite_frames == frames:
			found.append(o)
	if additive:
		for o in found:
			if not o in _selected:
				_selected.append(o)
				o.set_selected(true)
	else:
		_select_only(found)
	_update_hud()


func _select_only(units: Array) -> void:
	for u in _selected:
		u.set_selected(false)
	_selected.clear()
	for u in units:
		_selected.append(u)
		u.set_selected(true)
	_update_hud()


func _toggle_select(u: RTSUnit) -> void:
	if u in _selected:
		_selected.erase(u)
		u.set_selected(false)
	else:
		_selected.append(u)
		u.set_selected(true)
	_update_hud()


func _unit_at(world_pos: Vector2) -> RTSUnit:
	var best: RTSUnit = null
	var best_d := 36.0
	for u in _units:
		if u.state == RTSUnit.State.DEAD:
			continue
		var d: float = u.global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = u
	return best


func _update_select_box() -> void:
	_select_box.visible = true
	var r := Rect2(_drag_start, _drag_current - _drag_start)
	_select_box.points = PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0),
		r.position + r.size, r.position + Vector2(0, r.size.y), r.position])


# ------------------------------------------------------------------ orders

func _issue_right_click(world_pos: Vector2, queued: bool) -> void:
	if _selected.is_empty():
		return
	var clicked := _unit_at(world_pos)
	# Right-click downed friendly => revive.
	if clicked != null and clicked.state == RTSUnit.State.DOWNED \
			and not clicked.is_enemy and clicked.surrendered == false:
		for u in _selected:
			if not u.is_enemy:
				u.order_revive(clicked)
		_flash_marker(world_pos, Color(0.4, 1, 0.6))
		_hud.flash("Reviving...")
		return
	if clicked != null and clicked.is_enemy and clicked.state != RTSUnit.State.DEAD:
		for u in _selected:
			u.order_attack(clicked)
		_flash_marker(world_pos, Color(1, 0.3, 0.3))
		return
	if _attack_move_pending:
		_attack_move_pending = false
		_order_formation(_selected, world_pos, true)
		_flash_marker(world_pos, Color(1, 0.6, 0.2))
	else:
		_order_formation(_selected, world_pos, false)
		_flash_marker(world_pos, Color(0.4, 1, 0.4))


func _order_formation(units: Array[RTSUnit], dest: Vector2, attack_move: bool) -> void:
	# grid formation around dest so units don't stack (acceptance criterion)
	var n := units.size()
	var cols := int(ceil(sqrt(float(n))))
	var i := 0
	for u in units:
		if u.state == RTSUnit.State.DEAD:
			continue
		var cx: float = (i % cols) - (cols - 1) / 2.0
		var cy: float = (i / cols) - (n / cols) / 2.0
		var offset := Vector2(cx, cy) * FORMATION_SPACING
		var p: Vector2 = dest + offset
		p.x = clampf(p.x, MAP_BOUNDS.position.x + 20, MAP_BOUNDS.end.x - 20)
		p.y = clampf(p.y, MAP_BOUNDS.position.y + 20, MAP_BOUNDS.end.y - 20)
		if attack_move:
			u.order_attack_move(p)
		else:
			u.order_move(p)
		i += 1


func _flash_marker(world_pos: Vector2, color: Color) -> void:
	var m := Node2D.new()
	m.position = world_pos
	add_child(m)
	m.set_script(load("res://scripts/game/destination_marker.gd"))
	m.setup(color)


func _try_recruit(tier: int) -> void:
	var buildings := get_tree().get_nodes_in_group("recruit_building")
	if buildings.is_empty():
		_hud.flash("No recruitment building!", true)
		return
	var b: RecruitBuilding = buildings[0]
	var data: Dictionary = RecruitBuilding.RECRUIT_DATA[tier]
	if get_unit_count() >= 31:
		_hud.flash("Unit cap reached (31)!", true)
		return
	if money < int(data["price"]):
		_hud.flash("Not enough money! Need $%d" % int(data["price"]), true)
		return
	if b.queue_recruit(tier, self):
		_hud.flash("Training %s ($%d)..." % [data["name"], int(data["price"])])
		_update_hud()


func _handle_hotkey(ev: InputEventKey) -> void:
	match ev.keycode:
		KEY_S:
			for u in _selected:
				u.order_stop()
		KEY_A:
			_attack_move_pending = true
			_hud.get_node("Hint").text = "Attack-move: right-click a destination..."
		KEY_H:
			_toggle_pause()
		KEY_R:
			for u in _selected:
				u.start_reload()
			_hud.flash("Reloading...")
		KEY_D:
			var any_off := false
			for u in _selected:
				if not u.defend_mode:
					any_off = true
					break
			for u in _selected:
				u.order_defend(any_off)
			_hud.flash("Defend mode: " + ("ON" if any_off else "OFF"))
		KEY_F1:
			_try_recruit(1)
		KEY_F2:
			_try_recruit(2)
		KEY_F3:
			_try_recruit(3)
		KEY_G:
			_shop_buy("grenade")
		KEY_V:
			_shop_buy("vest")
		KEY_T:
			_shop_buy("ammo")
		KEY_F5:
			SaveSystem.save_game(self, "quicksave")
			_hud.flash("Saved.")
		KEY_F9:
			SaveSystem.load_game(self, "quicksave")
			_hud.flash("Loaded.")
		_:
			# Shift+1..6: buy weapons for selected units
			if ev.shift_pressed and GunShop.WEAPON_KEYS.has(ev.keycode):
				_shop_buy("weapon", GunShop.WEAPON_KEYS[ev.keycode])
				return
			# control groups: Ctrl+1..9 assign, 1..9 recall
			if ev.keycode >= KEY_1 and ev.keycode <= KEY_9:
				var idx := ev.keycode - KEY_1
				if ev.ctrl_pressed:
					_groups[idx] = _selected.duplicate()
					_hud.flash("Group %d assigned (%d units)." % [idx + 1, _selected.size()])
				elif _groups.has(idx):
					_select_only(_groups[idx])


func _shop_buy(what: String, weapon_id: StringName = &"") -> void:
	if get_tree().get_nodes_in_group("gun_shop").is_empty():
		_hud.flash("No gun shop!", true)
		return
	if _selected.is_empty():
		_hud.flash("Select units first.", true)
		return
	var bought := 0
	for u in _selected:
		var ok := false
		match what:
			"weapon":
				ok = GunShop.buy_weapon(self, u, weapon_id)
			"ammo":
				ok = GunShop.buy_ammo(self, u)
			"grenade":
				ok = GunShop.buy_grenade(self, u)
			"vest":
				ok = GunShop.buy_vest(self, u)
		if ok:
			bought += 1
	if bought > 0:
		_hud.flash("Bought %s x%d" % [what, bought])
	else:
		_hud.flash("Can't afford %s!" % what, true)
	_update_hud()


func get_enemies_of(unit: RTSUnit) -> Array:
	var out: Array = []
	for u in _units:
		if u.is_enemy != unit.is_enemy and u.state != RTSUnit.State.DEAD:
			out.append(u)
	return out


func _on_unit_died(unit: RTSUnit) -> void:
	if unit in _selected:
		_selected.erase(unit)
		_update_hud()
	# prune from groups
	for k in _groups:
		(_groups[k] as Array).erase(unit)


# ------------------------------------------------------------------ pause

func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_hud.get_node("PausePanel").visible = _paused


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _update_hud() -> void:
	_hud.update_selection(_selected)
	_hud.update_economy(money, morale, payroll_timer)


# ------------------------------------------------------------------ save

func get_save_data() -> Dictionary:
	var units_data: Array = []
	for u in _units:
		if u.state == RTSUnit.State.DEAD:
			continue
		units_data.append({
			"name": u.unit_name,
			"enemy": u.is_enemy,
			"pos": [u.global_position.x, u.global_position.y],
			"hp": u.hp,
			"hero": u.unit_name == "Juan Bellarosa",
			"weapon": String(u.weapon_id),
			"ammo_mag": u.ammo_in_mag,
			"ammo_reserve": u.reserve_ammo,
			"grenades": u.grenades,
			"armor": u.has_armor,
			"tier": u.unit_tier,
			"salary": u.salary,
		})
	return {"units": units_data, "campaign": "campaign_juan",
		"money": money, "morale": morale, "payroll_timer": payroll_timer}


func apply_save_data(data: Dictionary) -> void:
	for u in _units:
		u.queue_free()
	_units.clear()
	_selected.clear()
	_groups.clear()
	for ud in data.get("units", []):
		var frames: SpriteFrames = JUAN_FRAMES if ud.get("hero", false) else B1_FRAMES
		var u := _spawn_unit(ud["name"], frames,
			Vector2(ud["pos"][0], ud["pos"][1]), ud["enemy"], {})
		u.hp = ud["hp"]
		if ud.has("weapon"):
			u.equip_weapon(StringName(ud["weapon"]))
			u.ammo_in_mag = int(ud.get("ammo_mag", u.ammo_in_mag))
			u.reserve_ammo = int(ud.get("ammo_reserve", u.reserve_ammo))
		u.grenades = int(ud.get("grenades", 0))
		u.has_armor = bool(ud.get("armor", false))
		u.unit_tier = int(ud.get("tier", 1))
		u.salary = int(ud.get("salary", 35))
	money = int(data.get("money", 4000))
	morale = float(data.get("morale", 100.0))
	payroll_timer = float(data.get("payroll_timer", PAYROLL_INTERVAL))
	_update_hud()
