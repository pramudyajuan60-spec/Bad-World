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
var _vehicles: Array[Vehicle] = []
var _selected_vehicles: Array[Vehicle] = []
var _groups: Dictionary = {}  # int -> Array[RTSUnit]
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO
var _last_click_time: int = 0
var _last_click_unit: RTSUnit = null
var _attack_move_pending: bool = false
var _paused: bool = false
# --- MVP 4: active campaign ---
var campaign: CampaignData
var mc_level: int = 1
const MC_MAX_LEVEL := 5
const MC_UPGRADE_COSTS := {2: 1000, 3: 2000, 4: 3500, 5: 5500}
# --- MVP 4: MC abilities ---
var ability_q_cd: float = 0.0
var ability_w_cd: float = 0.0
const ABILITY_Q_CD := 30.0
const ABILITY_W_CD := 60.0
var _assassinate_pending: bool = false
var _command_surge_timer: float = 0.0
var _tactical_link_timer: float = 0.0
# --- MVP 5: diplomacy (faction standing toward player) ---
var faction_standing := {"vartieri": -100, "nasion": -100, "dea": -50}
# --- MVP 5: strategic AI director ---
var _ai_director_timer: float = 0.0
const AI_DIRECTOR_INTERVAL := 45.0
# --- MVP 6a: victory/defeat ---
var game_over: bool = false
var victory: bool = false
var _kill_count: int = 0
var _money_earned: int = 0
# --- MVP 6c: tutorial + autosave ---
var _tutorial_step: int = 0
var _autosave_timer: float = 300.0
const AUTOSAVE_INTERVAL := 300.0
# --- MVP 2d: economy ---
var money: int = 4000
var morale: float = 100.0  # 0..100, affects accuracy
var payroll_timer: float = 120.0
const PAYROLL_INTERVAL: float = 120.0
var missed_payrolls: int = 0
# --- MVP 3c: heat & DEA ---
var heat: float = 0.0  # 0..100
var _dea_war_timer: float = 0.0  # time at high heat with combat
var _dea_travel_timer: float = 0.0
var _dea_spawned: bool = false
const HEAT_WAR_THRESHOLD := 60.0
const DEA_WAR_TIME := 120.0
const DEA_TRAVEL_TIME := 60.0

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
	# Heat decays slowly.
	heat = maxf(0.0, heat - delta * 0.5)
	# Ability cooldowns and timers.
	ability_q_cd = maxf(0.0, ability_q_cd - delta)
	ability_w_cd = maxf(0.0, ability_w_cd - delta)
	_command_surge_timer = maxf(0.0, _command_surge_timer - delta)
	_tactical_link_timer = maxf(0.0, _tactical_link_timer - delta)
	# MVP 5: fog of war — enemies visible only near player units/vehicles.
	_update_fog()
	# MVP 5: strategic AI director.
	_ai_director_timer += delta
	if _ai_director_timer >= AI_DIRECTOR_INTERVAL:
		_ai_director_timer = 0.0
		_run_ai_director()
	# MVP 6a: check victory/defeat.
	_check_end_conditions()
	# MVP 6c: tutorial + autosave.
	_update_tutorial(delta)
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_INTERVAL
		SaveSystem.save_game(self, "autosave")
	# DEA response logic.
	_update_dea(delta)
	# Refresh economy HUD (payroll countdown ticks).
	_hud.update_economy(money, morale, payroll_timer)
	_hud.update_heat(heat, _dea_spawned)


func add_heat(amount: float) -> void:
	heat = minf(100.0, heat + amount)


func _update_dea(delta: float) -> void:
	if _dea_spawned:
		return
	if heat >= HEAT_WAR_THRESHOLD:
		_dea_war_timer += delta
		if _dea_war_timer >= DEA_WAR_TIME:
			# war long enough; DEA now traveling
			_dea_travel_timer += delta
			if int(_dea_travel_timer) % 10 == 0 and _dea_travel_timer > 1.0:
				# periodic warning (avoid spam: only on 10s boundaries)
				pass
			if _dea_travel_timer >= DEA_TRAVEL_TIME:
				_spawn_dea_raid()
	else:
		_dea_war_timer = maxf(0.0, _dea_war_timer - delta * 2.0)


func _spawn_dea_raid() -> void:
	_dea_spawned = true
	_hud.flash("DEA RAID INCOMING!", true)
	# Spawn at map edge, NOT on top of player (acceptance criterion).
	var spawn := Vector2(1400, -1000)  # NE corner, far from player base SW
	for i in 4:
		var u := _spawn_unit("DEA-%d" % (i + 1), B1_FRAMES,
			spawn + Vector2(i * 50, (i % 2) * 50), true, {
				"max_hp": 170.0, "weapon_id": &"rifle",
				"unit_tier": 2, "salary": 0,
			})
		u.modulate = Color(0.3, 0.5, 1.0)  # blue tint for DEA
	# Order them to attack-move toward player base.
	for u in _units:
		if u.unit_name.begins_with("DEA-"):
			u.order_attack_move(Vector2(-1100, 900))


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
	_load_campaign()
	_camera.map_bounds = MAP_BOUNDS
	_build_map()
	_spawn_initial_units()
	_hud.get_node("Minimap").game = self
	_hud.get_node("Hint").text = (
		"LMB: select | Shift+LMB: add | Drag: box | Double-click: select type\n"
		+ "RMB: move | A+RMB: attack-move | S: stop | D: defend | R: reload\n"
		+ "F1/F2/F3: recruit | C: load cargo | X: sell/deposit\n"
		+ "Shift+1..6: buy weapon | G: grenade | V: vest | T: ammo | Esc: pause")


func _load_campaign() -> void:
	var cid: StringName = GameState.pending_campaign
	if cid == &"":
		cid = &"campaign_juan"
	campaign = CampaignDatabase.campaigns.get(cid)
	if campaign == null:
		campaign = CampaignDatabase.campaigns.get(&"campaign_juan")
	money = campaign.starting_money


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
	# MVP 3b: Garage
	_spawn_garage(Vector2(-850, 1050))
	# MVP 2f: Safe zone covering player base (recruit + gun shop)
	var sz := SafeZone.new()
	sz.position = Vector2(-1150, 950)
	sz.radius = 280.0
	add_child(sz)
	# MVP 3: economy buildings
	_spawn_economy()


func _make_building_visual(size: Vector2, color: Color, label_text: String) -> Node2D:
	var root := Node2D.new()
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2),
		Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)])
	vis.color = color
	root.add_child(vis)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(-size.x / 2 + 8, -10)
	label.add_theme_font_size_override("font_size", 13)
	root.add_child(label)
	return root


func _spawn_economy() -> void:
	# Factories: one per cartel (Bellarosa=player SW, Vartieri NW, Nasion SE, DEA NE)
	var factory_spots := {
		"bellarosa": Vector2(-1350, 700),
		"vartieri": Vector2(-1350, -700),
		"nasion": Vector2(1350, 700),
		"dea": Vector2(1350, -700),
	}
	for faction in factory_spots:
		var f := Factory.new()
		f.position = factory_spots[faction]
		f.faction = faction
	# Player's factory uses campaign start level (Andres=L2).
		var player_faction := "bellarosa"
		if campaign != null:
			match campaign.id:
				&"campaign_fauzi":
					player_faction = "vartieri"
				&"campaign_atha":
					player_faction = "nasion"
				&"campaign_nabil":
					player_faction = "dea"
		if faction == player_faction and campaign != null:
			f.level = campaign.factory_start_level
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(140, 110)
		shape.shape = rect
		f.add_child(shape)
		f.add_child(_make_building_visual(Vector2(140, 110),
			Color(0.5, 0.35, 0.2, 0.95), "FACTORY " + faction.to_upper()))
		add_child(f)
	# Bank (player base)
	var bank := Bank.new()
	bank.position = Vector2(-950, 1050)
	var bshape := CollisionShape2D.new()
	var brect := RectangleShape2D.new()
	brect.size = Vector2(100, 80)
	bshape.shape = brect
	bank.add_child(bshape)
	bank.add_child(_make_building_visual(Vector2(100, 80),
		Color(0.25, 0.5, 0.35, 0.95), "BANK"))
	add_child(bank)
	# 4 drug dealers in Central City
	var dealer_names := ["Dealer Marco", "Dealer Sari", "Dealer Volkov", "Dealer ???"]
	var dealer_spots := [Vector2(-150, -100), Vector2(150, -100),
		Vector2(-150, 150), Vector2(150, 150)]
	for i in 4:
		var d := DrugDealer.new()
		d.position = dealer_spots[i]
		d.dealer_name = dealer_names[i]
		if i == 3:
			d.is_placeholder = true
		var dshape := CollisionShape2D.new()
		var drekt := RectangleShape2D.new()
		drekt.size = Vector2(60, 60)
		dshape.shape = drekt
		d.add_child(dshape)
		var dcol := Color(0.6, 0.25, 0.6, 0.95) if not d.is_placeholder else Color(0.4, 0.4, 0.4, 0.7)
		d.add_child(_make_building_visual(Vector2(60, 60), dcol,
			"D" + str(i + 1)))
		add_child(d)
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


func _spawn_garage(pos: Vector2) -> void:
	var g := StaticBody2D.new()
	g.add_to_group("garage")
	g.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(120, 90)
	shape.shape = rect
	g.add_child(shape)
	g.add_child(_make_building_visual(Vector2(120, 90),
		Color(0.4, 0.4, 0.55, 0.95), "GARAGE"))
	add_child(g)


func spawn_vehicle(vehicle_id: StringName, pos: Vector2) -> Vehicle:
	var data := VehiclesDB.get_vehicle(vehicle_id)
	var v := Vehicle.new()
	v.setup(data)
	# build required child nodes
	var nav := NavigationAgent2D.new()
	nav.name = "NavigationAgent2D"
	v.add_child(nav)
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	col.shape = circle
	v.add_child(col)
	var ring := Node2D.new()
	ring.name = "SelectionRing"
	ring.set_script(load("res://scripts/game/selection_ring.gd"))
	v.add_child(ring)
	v.position = pos
	add_child(v)
	_vehicles.append(v)
	v.destroyed.connect(_on_vehicle_destroyed)
	return v


func _on_vehicle_destroyed(v: Vehicle) -> void:
	_vehicles.erase(v)
	_selected_vehicles.erase(v)


func _on_recruit_complete(tier: int, building: RecruitBuilding) -> void:
	if tier == 4:
		# Special unit.
		var sq: Array = building.get_meta("special_queue", [])
		if sq.is_empty():
			return
		var data: Dictionary = sq.pop_front()
		var spawn_pos: Vector2 = building.position + Vector2(100, 0)
		_spawn_unit(data["name"], B1_FRAMES, spawn_pos, false, {
			"max_hp": float(data["hp"]),
			"weapon_id": data["weapon"],
			"unit_tier": 4,
			"salary": int(data["salary"]),
		})
		_hud.flash("%s recruited!" % data["name"])
		return
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
	# MVP 4: faction-specific spawn.
	var mc_name: String = campaign.main_character_name
	var is_nabil: bool = campaign.id == &"campaign_nabil"
	# MC + starting squad (Nabil gets B2, others get B1).
	_spawn_unit(mc_name, JUAN_FRAMES, Vector2(-1100, 800),
		false, {"max_hp": 220.0, "move_speed": 165.0, "weapon_id": &"rifle",
			"unit_tier": 4, "salary": 0})
	var squad_pos := [Vector2(-1000, 850), Vector2(-1050, 720), Vector2(-950, 740)]
	for i in 3:
		if is_nabil:
			_spawn_unit("B2-%d" % (i + 1), B1_FRAMES, squad_pos[i], false, {
				"max_hp": 170.0, "weapon_id": &"rifle",
				"unit_tier": 2, "salary": 110})
		else:
			_spawn_unit("B1-%d" % (i + 1), B1_FRAMES, squad_pos[i], false, {
				"unit_tier": 1, "salary": 35})
	# Starting vehicle from campaign.
	spawn_vehicle(campaign.starting_vehicle, Vector2(-850, 900))
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


func _clear_unit_selection() -> void:
	for u in _selected:
		u.set_selected(false)
	_selected.clear()


func _click_select(world_pos: Vector2, additive: bool) -> void:
	# Vehicles first (they're bigger targets).
	var v := _vehicle_at(world_pos)
	if v != null:
		_clear_unit_selection()
		for sv in _selected_vehicles:
			sv.set_selected(false)
		_selected_vehicles = [v]
		v.set_selected(true)
		_update_hud()
		return
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
	for v in _selected_vehicles:
		v.set_selected(false)
	_selected_vehicles.clear()
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
		if not u.visible:  # boarded units can't be clicked
			continue
		var d: float = u.global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = u
	return best


func _vehicle_at(world_pos: Vector2) -> Vehicle:
	var best: Vehicle = null
	var best_d := 44.0
	for v in _vehicles:
		var d: float = v.global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = v
	return best


func _update_select_box() -> void:
	_select_box.visible = true
	var r := Rect2(_drag_start, _drag_current - _drag_start)
	_select_box.points = PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0),
		r.position + r.size, r.position + Vector2(0, r.size.y), r.position])


# ------------------------------------------------------------------ orders

func _issue_right_click(world_pos: Vector2, queued: bool) -> void:
	# Assassinate: pending one-shot on clicked enemy.
	if _assassinate_pending:
		_assassinate_pending = false
		var target := _unit_at(world_pos)
		if target != null and target.is_enemy:
			var mc := _get_mc()
			# Counterplay: fails if target is near allies (they warn him).
			var guarded := false
			for u in _units:
				if u != target and u.is_enemy == target.is_enemy \
						and u.global_position.distance_to(target.global_position) < 150.0:
					guarded = true
					break
			if guarded:
				_hud.flash("Assassination failed: target guarded!", true)
			else:
				target.take_damage(500.0, mc)
				_hud.flash("Assassinated %s!" % target.unit_name)
		else:
			_hud.flash("No target.", true)
		return
	# Vehicle selected: order move.
	if not _selected_vehicles.is_empty():
		for v in _selected_vehicles:
			v.order_move(world_pos)
		_flash_marker(world_pos, Color(0.4, 0.6, 1.0))
		return
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
	if get_unit_count() >= campaign.unit_cap + 1:  # +1 for MC
		_hud.flash("Unit cap reached (%d)!" % (campaign.unit_cap + 1), true)
		return
	if tier == 1 and not campaign.can_recruit_b1:
		_hud.flash("Nabil cannot recruit B1!", true)
		return
	if money < int(data["price"]):
		_hud.flash("Not enough money! Need $%d" % int(data["price"]), true)
		return
	if b.queue_recruit(tier, self):
		_hud.flash("Training %s ($%d)..." % [data["name"], int(data["price"])])
		_update_hud()


func _nearest_in_group(pos: Vector2, group: String, max_dist: float) -> Node:
	var best: Node = null
	var best_d := max_dist
	for n in get_tree().get_nodes_in_group(group):
		var d: float = pos.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _cargo_pickup() -> void:
	if _selected.is_empty():
		return
	var loaded := 0
	for u in _selected:
		var f := _nearest_in_group(u.global_position, "factories", 160.0) as Factory
		if f == null or f.destroyed or f.faction != "bellarosa":
			continue
		var space: int = u.MAX_CARGO - u.carried_cargo
		if space <= 0:
			continue
		var got: int = f.take_cargo(space)
		u.carried_cargo += got
		loaded += got
	if loaded > 0:
		_hud.flash("Loaded %d cargo" % loaded)
	else:
		_hud.flash("No cargo: move near your factory", true)
	_update_hud()


func _cargo_sell_or_deposit() -> void:
	if _selected.is_empty():
		return
	# Try deposit at bank first.
	var did_something := false
	for u in _selected:
		var bank := _nearest_in_group(u.global_position, "bank", 160.0)
		if bank != null and u.carried_cash > 0:
			money += u.carried_cash
			_money_earned += u.carried_cash
			_hud.flash("Deposited $%d" % u.carried_cash)
			u.carried_cash = 0
			did_something = true
			continue
		var dealer := _nearest_in_group(u.global_position, "dealers", 160.0) as DrugDealer
		if dealer != null and u.carried_cargo > 0:
			var res: Dictionary = dealer.sell_cargo(u.carried_cargo)
			if int(res["sold"]) > 0:
				u.carried_cargo -= int(res["sold"])
				u.carried_cash += int(res["cash"])
				add_heat(5.0)  # drug dealing attracts attention
				_hud.flash("Sold %d cargo for $%d (carried)" % [int(res["sold"]), int(res["cash"])])
				did_something = true
	if not did_something:
		_hud.flash("Nothing to sell/deposit here", true)
	_update_hud()


func _try_buy_vehicle(vehicle_id: StringName) -> void:
	if get_tree().get_nodes_in_group("garage").is_empty():
		_hud.flash("No garage!", true)
		return
	var data := VehiclesDB.get_vehicle(vehicle_id)
	if money < data.price:
		_hud.flash("Not enough money! Need $%d" % data.price, true)
		return
	money -= data.price
	var garage := get_tree().get_nodes_in_group("garage")[0] as Node2D
	spawn_vehicle(vehicle_id, garage.global_position + Vector2(0, 100))
	_hud.flash("Bought %s!" % data.display_name)
	_update_hud()


func _vehicle_enter_exit() -> void:
	# If vehicles selected: disembark. Else: selected units board nearest vehicle.
	if not _selected_vehicles.is_empty():
		for v in _selected_vehicles:
			v.disembark(self)
		_hud.flash("Disembarked.")
		return
	if _selected.is_empty():
		return
	var boarded := 0
	for u in _selected:
		var v := _nearest_in_group(u.global_position, "vehicles", 120.0) as Vehicle
		if v != null and v.board(u):
			boarded += 1
	if boarded > 0:
		# remove boarded units from selection
		_selected = _selected.filter(func(u): return u.visible)
		_hud.flash("Boarded %d units" % boarded)
	else:
		_hud.flash("No vehicle nearby", true)
	_update_hud()


func _vehicle_repair() -> void:
	if _selected_vehicles.is_empty():
		return
	var repaired := 0
	for v in _selected_vehicles:
		var garage := _nearest_in_group(v.global_position, "garage", 200.0)
		if garage == null:
			continue
		var missing: float = v.vdata.max_hp - v.hp
		if missing <= 0.0:
			continue
		var cost: int = int(missing * 0.5)  # $0.5 per HP
		if money < cost:
			_hud.flash("Can't afford repair ($%d)" % cost, true)
			continue
		money -= cost
		v.hp = v.vdata.max_hp
		repaired += 1
	if repaired > 0:
		_hud.flash("Repaired %d vehicle(s)" % repaired)
	else:
		_hud.flash("Move vehicle near garage to repair", true)
	_update_hud()


func _try_mc_upgrade() -> void:
	if mc_level >= MC_MAX_LEVEL:
		_hud.flash("MC already max level!", true)
		return
	var cost: int = MC_UPGRADE_COSTS[mc_level + 1]
	if money < cost:
		_hud.flash("Need $%d for MC level %d" % [cost, mc_level + 1], true)
		return
	money -= cost
	mc_level += 1
	# Apply bonuses: +HP, +damage, -cooldown (capped per BALANCE.md).
	for u in _units:
		if u.unit_name == campaign.main_character_name:
			u.max_hp *= 1.04  # ~+20% by level 5
			u.hp = u.max_hp
	_hud.flash("MC upgraded to level %d!" % mc_level)
	_update_hud()


func _try_recruit_special(index: int) -> void:
	if mc_level < 4:
		_hud.flash("Specials unlock at MC level 4!", true)
		return
	var specials: Array = RecruitBuilding.SPECIAL_DATA.get(campaign.id, [])
	if index >= specials.size():
		return
	var data: Dictionary = specials[index]
	if get_unit_count() >= campaign.unit_cap + 1:
		_hud.flash("Unit cap reached!", true)
		return
	if money < int(data["price"]):
		_hud.flash("Not enough money! Need $%d" % int(data["price"]), true)
		return
	var buildings := get_tree().get_nodes_in_group("recruit_building")
	if buildings.is_empty():
		return
	money -= int(data["price"])
	var b: RecruitBuilding = buildings[0]
	# Queue as special (use tier 4 marker).
	b.queue.append(4)
	# Store special data for completion handler.
	if not b.has_meta("special_queue"):
		b.set_meta("special_queue", [])
	(b.get_meta("special_queue") as Array).append(data)
	b.queue_changed.emit()
	_hud.flash("Training %s ($%d)..." % [data["name"], int(data["price"])])
	_update_hud()


func _get_mc() -> RTSUnit:
	for u in _units:
		if u.unit_name == campaign.main_character_name and u.state != RTSUnit.State.DEAD:
			return u
	return null


func _use_ability_q() -> void:
	if ability_q_cd > 0.0:
		_hud.flash("Ability on cooldown (%.0fs)" % ability_q_cd, true)
		return
	var mc := _get_mc()
	if mc == null:
		return
	match campaign.id:
		&"campaign_juan":
			# Assassinate: massive damage to selected target (counterplay: needs target selected, single use).
			if _selected.is_empty():
				_hud.flash("Select MC + target enemy first", true)
				return
			ability_q_cd = ABILITY_Q_CD
			_hud.flash("Assassinate ready: right-click a target!")
			_assassinate_pending = true
		&"campaign_fauzi":
			# Deceptive Assault: nearby enemies lose target (confusion).
			ability_q_cd = ABILITY_Q_CD
			for u in _units:
				if u.is_enemy and u.global_position.distance_to(mc.global_position) < 400.0:
					u.target = null
					u.state = RTSUnit.State.IDLE
			_hud.flash("Deceptive Assault! Enemies confused.")
		&"campaign_atha":
			# Command Surge: 2x fire rate for 10s.
			ability_q_cd = ABILITY_Q_CD
			_command_surge_timer = 10.0
			_hud.flash("Command Surge! 2x fire rate for 10s.")
		&"campaign_nabil":
			# Throw Grenade: AoE at MC position.
			ability_q_cd = ABILITY_Q_CD
			_grenade_blast(mc.global_position, 150.0, 80.0)
			_hud.flash("Grenade thrown!")


func _use_ability_w() -> void:
	if ability_w_cd > 0.0:
		_hud.flash("Ability on cooldown (%.0fs)" % ability_w_cd, true)
		return
	var mc := _get_mc()
	if mc == null:
		return
	match campaign.id:
		&"campaign_juan":
			# Tactical Link: reveal + accuracy buff for 15s.
			ability_w_cd = ABILITY_W_CD
			_tactical_link_timer = 15.0
			_hud.flash("Tactical Link active!")
		&"campaign_fauzi":
			# Vehicle Commander: repair + buff vehicles.
			ability_w_cd = ABILITY_W_CD
			for v in _vehicles:
				v.hp = minf(v.vdata.max_hp, v.hp + 200.0)
			_hud.flash("Vehicle Commander: vehicles repaired!")
		&"campaign_atha":
			# Throw Drug Bottle: slow enemies in radius.
			ability_w_cd = ABILITY_W_CD
			for u in _units:
				if u.is_enemy and u.global_position.distance_to(mc.global_position) < 300.0:
					u.suppression = 1.0  # max suppression = slowed/inaccurate
			_hud.flash("Drug Bottle! Enemies suppressed.")
		&"campaign_nabil":
			# Discipline Aura: clear suppression + morale boost.
			ability_w_cd = ABILITY_W_CD
			for u in _units:
				if not u.is_enemy:
					u.suppression = 0.0
			morale = 100.0
			_hud.flash("Discipline Aura! Squad restored.")


func _grenade_blast(pos: Vector2, radius: float, damage: float) -> void:
	for u in _units:
		if u.global_position.distance_to(pos) <= radius:
			u.take_damage(damage, null)
	# visual flash
	_flash_marker(pos, Color(1, 0.6, 0.2))


func _update_fog() -> void:
	# MVP 5: enemy units/buildings visible only within sight of player assets.
	# Player units reveal sight_range; vehicles reveal 400.
	var viewers: Array[Vector2] = []
	for u in _units:
		if not u.is_enemy and u.state != RTSUnit.State.DEAD and u.visible:
			viewers.append(u.global_position)
	for v in _vehicles:
		viewers.append(v.global_position)
	for u in _units:
		if not u.is_enemy:
			continue
		# Don't hide downed/dead (they're already handled).
		if u.state == RTSUnit.State.DEAD:
			continue
		var seen := false
		for vp in viewers:
			if u.global_position.distance_to(vp) < 400.0:
				seen = true
				break
		# Boarded check: units in vehicles are invisible for a different reason.
		var boarded := false
		for v in _vehicles:
			if u in v.passengers:
				boarded = true
				break
		if not boarded:
			u.visible = seen


func _run_ai_director() -> void:
	# MVP 5 strategic AI: hostile factions reinforce and raid periodically.
	# Only acts if standing is hostile.
	for faction in ["vartieri", "nasion"]:
		if int(faction_standing.get(faction, 0)) > -50:
			continue  # not hostile
		# Count this faction's units (use enemy units as proxy).
		var count := 0
		for u in _units:
			if u.is_enemy and u.state != RTSUnit.State.DEAD:
				count += 1
		if count < 6:
			# Reinforce: spawn 2 units at faction territory.
			var base := Vector2(-1200, -800) if faction == "vartieri" else Vector2(1200, 800)
			for i in 2:
				var u := _spawn_unit("%s Raider" % faction.capitalize(), B1_FRAMES,
					base + Vector2(i * 60, 0), true, {"unit_tier": 1, "salary": 0})
				u.modulate = Color(1.0, 0.45, 0.45)
			_hud.flash("%s reinforcements!" % faction.capitalize(), true)
		elif count >= 6:
			# Raid: send half the force toward player base.
			var raiders: Array[RTSUnit] = []
			for u in _units:
				if u.is_enemy and u.state == RTSUnit.State.IDLE:
					raiders.append(u)
					if raiders.size() >= count / 2:
						break
			for r in raiders:
				r.order_attack_move(Vector2(-1100, 900))
			if not raiders.is_empty():
				_hud.flash("Enemy raid incoming!", true)


func _check_end_conditions() -> void:
	if game_over or _paused:
		return
	# Defeat: MC dead.
	var mc := _get_mc()
	if mc == null:
		# Check if MC ever existed (not just not spawned yet).
		var mc_exists := false
		for u in _units:
			if u.unit_name == campaign.main_character_name:
				mc_exists = true
				break
		if mc_exists:
			_end_game(false, "Main Character died.")
		return
	# Victory: all enemy units and factories destroyed.
	var enemies_alive := false
	for u in _units:
		if u.is_enemy and u.state != RTSUnit.State.DEAD:
			enemies_alive = true
			break
	var factories_alive := false
	for f in get_tree().get_nodes_in_group("factories"):
		var fac := f as Factory
		if fac.faction != _player_faction() and not fac.destroyed:
			factories_alive = true
			break
	if not enemies_alive and not factories_alive:
		_end_game(true, "All enemies defeated!")


func _player_faction() -> String:
	match campaign.id:
		&"campaign_fauzi":
			return "vartieri"
		&"campaign_atha":
			return "nasion"
		&"campaign_nabil":
			return "dea"
	return "bellarosa"


func _end_game(won: bool, reason: String) -> void:
	game_over = true
	victory = won
	_paused = true
	get_tree().paused = true
	_hud.show_end_screen(won, reason, _get_summary())


func _get_summary() -> Dictionary:
	return {
		"campaign": campaign.menu_name,
		"kills": _kill_count,
		"money_earned": _money_earned,
		"mc_level": mc_level,
		"units": get_unit_count(),
	}


func _update_tutorial(delta: float) -> void:
	# MVP 6c: contextual tutorial hints.
	if _tutorial_step == 0:
		_hud.set_tutorial("Select your units: left-click or drag a box.")
		if not _selected.is_empty():
			_tutorial_step = 1
	elif _tutorial_step == 1:
		_hud.set_tutorial("Right-click to move. Press A then right-click for attack-move.")
		if _kill_count > 0:
			_tutorial_step = 2
	elif _tutorial_step == 2:
		_hud.set_tutorial("Press F1/F2/F3 to recruit. C: load cargo at factory, X: sell/deposit.")
		if money > 4500 or get_unit_count() > 4:
			_tutorial_step = 3
	elif _tutorial_step == 3:
		_hud.set_tutorial("Buy vehicles (F4/F6/F7/F8), press E to enter. Q/W for MC abilities.")
		_tutorial_step = 4
	elif _tutorial_step == 4:
		_hud.set_tutorial("")  # done


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
		KEY_F10:
			_try_recruit_special(0)
		KEY_F11:
			_try_recruit_special(1)
		KEY_F12:
			_try_recruit_special(2)
		KEY_G:
			_shop_buy("grenade")
		KEY_V:
			_shop_buy("vest")
		KEY_T:
			_shop_buy("ammo")
		KEY_C:
			_cargo_pickup()
		KEY_X:
			_cargo_sell_or_deposit()
		KEY_E:
			_vehicle_enter_exit()
		KEY_P:
			_vehicle_repair()
		KEY_F4:
			_try_buy_vehicle(&"utility")
		KEY_F6:
			_try_buy_vehicle(&"suv")
		KEY_F7:
			_try_buy_vehicle(&"guntruck")
		KEY_F8:
			_try_buy_vehicle(&"apc")
		KEY_U:
			_try_mc_upgrade()
		KEY_Q:
			_use_ability_q()
		KEY_W:
			_use_ability_w()
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
	# Killing generates heat (more for DEA kills by player).
	if unit.is_enemy:
		add_heat(8.0)
		_kill_count += 1
	else:
		add_heat(3.0)


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
	# Vehicle info in selection panel if vehicles selected.
	if not _selected_vehicles.is_empty():
		var v: Vehicle = _selected_vehicles[0]
		_hud.set_vehicle_info(v)


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
			"cargo": u.carried_cargo,
			"cash": u.carried_cash,
		})
	return {"units": units_data, "campaign": "campaign_juan",
		"money": money, "morale": morale, "payroll_timer": payroll_timer,
		"heat": heat, "vehicles": _get_vehicles_save_data(),
		"factories": _get_factories_save_data()}


func _get_vehicles_save_data() -> Array:
	var arr: Array = []
	for v in _vehicles:
		arr.append({
			"id": String(v.vdata.id),
			"pos": [v.global_position.x, v.global_position.y],
			"hp": v.hp,
			"cargo": v.carried_cargo,
		})
	return arr


func _get_factories_save_data() -> Array:
	var arr: Array = []
	for f in get_tree().get_nodes_in_group("factories"):
		var fac := f as Factory
		arr.append({
			"faction": fac.faction,
			"level": fac.level,
			"stock": fac.stock,
			"hp": fac.hp,
		})
	return arr


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
		u.carried_cargo = int(ud.get("cargo", 0))
		u.carried_cash = int(ud.get("cash", 0))
	money = int(data.get("money", 4000))
	morale = float(data.get("morale", 100.0))
	payroll_timer = float(data.get("payroll_timer", PAYROLL_INTERVAL))
	heat = float(data.get("heat", 0.0))
	# Restore vehicles.
	for v in _vehicles:
		v.queue_free()
	_vehicles.clear()
	for vd in data.get("vehicles", []):
		var v := spawn_vehicle(StringName(vd["id"]),
			Vector2(vd["pos"][0], vd["pos"][1]))
		v.hp = float(vd["hp"])
		v.carried_cargo = int(vd["cargo"])
	# Restore factories.
	for f in get_tree().get_nodes_in_group("factories"):
		var fac := f as Factory
		for fd in data.get("factories", []):
			if fd["faction"] == fac.faction:
				fac.level = int(fd["level"])
				fac.stock = int(fd["stock"])
				fac.hp = float(fd["hp"])
				if fac.hp <= 0.0:
					fac.destroyed = true
	_update_hud()
