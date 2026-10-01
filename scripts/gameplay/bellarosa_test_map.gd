extends Node2D
## MVP 2 gameplay scene: adds real weapon-data combat, Defend/Cover Mode,
## suppression/retreat, downed/revive/execution, a Recruitment building,
## Gun Shop, per-unit manual inventory, payroll, safe zones, and
## recruiting downed regular enemies — on top of MVP 1's map, camera,
## selection, and command systems (unchanged).
##
## Map geometry/background are unchanged from MVP1 — see that script's
## original header comment for the concept-art sourcing note.

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const DEST_MARKER_SCENE := preload("res://scenes/gameplay/DestinationMarker.tscn")
const RECRUITMENT_PANEL_SCRIPT := preload("res://scripts/ui/recruitment_panel.gd")
const GUN_SHOP_PANEL_SCRIPT := preload("res://scripts/ui/gun_shop_panel.gd")
const INSPECT_PANEL_SCRIPT := preload("res://scripts/ui/inspect_panel.gd")

const MAP_BOUNDS := Rect2(-1500, -1000, 3000, 2000)
const OBSTACLE_RECTS := [
	Rect2(-260, -420, 220, 140),
	Rect2(180, -380, 260, 160),
	Rect2(-520, 120, 200, 220),
	Rect2(260, 200, 240, 180),
	Rect2(-70, -60, 160, 120),
]
const OBSTACLE_LAYER := 2
const SAFE_ZONE_BANK_POS := Vector2(-1350, -750)
const SAFE_ZONE_RECRUITMENT_POS := Vector2(-1350, -550)

@onready var background: Sprite2D = $Background
@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var obstacles_root: Node2D = $Obstacles
@onready var units_root: Node2D = $Units
@onready var enemies_root: Node2D = $Enemies
@onready var box_overlay: Node2D = $BoxSelectOverlay
@onready var camera: RtsCamera = $RtsCamera
@onready var selection_manager: SelectionManager = $SelectionManager
@onready var command_controller = $CommandController
@onready var economy = $CampaignEconomy
@onready var hud = $HUD/SelectionHud
@onready var pause_menu = $PauseMenu
@onready var hud_layer: CanvasLayer = $HUD

var _combat_log: Node = null
var recruitment_panel: Control
var gun_shop_panel: Control
var inspect_panel: Control
var _topbar_label: Label


func _ready() -> void:
	_combat_log = get_node_or_null("/root/CombatLog")
	_build_background()
	_build_navigation()
	_build_obstacles()
	camera.bounds = MAP_BOUNDS

	economy.set_money(4000) # Juan's starting money, Prompt Dasar BALANCE V0.1
	economy.safe_zone_points = [SAFE_ZONE_BANK_POS, SAFE_ZONE_RECRUITMENT_POS]
	_build_safe_zone_marker("Bank", SAFE_ZONE_BANK_POS)
	_build_safe_zone_marker("Recruitment", SAFE_ZONE_RECRUITMENT_POS)
	economy.unit_recruited.connect(_on_unit_recruited)

	command_controller.selection_manager = selection_manager
	command_controller.camera = camera
	command_controller.overlay = box_overlay
	command_controller.markers_parent = self
	command_controller.destination_marker_scene = DEST_MARKER_SCENE
	command_controller.pause_requested.connect(_toggle_pause)

	selection_manager.selection_updated.connect(_on_selection_updated)

	pause_menu.visible = false
	pause_menu.resume_requested.connect(_toggle_pause)
	pause_menu.restart_requested.connect(_on_restart)
	pause_menu.save_requested.connect(_on_save)
	pause_menu.load_requested.connect(_on_load)
	pause_menu.quit_to_menu_requested.connect(_on_quit_to_menu)

	_build_hud_extras()

	var slot := GameState.pending_load_slot
	GameState.pending_load_slot = -1
	if slot >= 1 and SaveService.has_save(slot):
		_load_from_slot(slot)
	else:
		_spawn_fresh()

	_refresh_enemy_units_cache()


func _process(_delta: float) -> void:
	economy.payroll_units = units_root.get_children().filter(func(c): return c is BwUnit and is_instance_valid(c))
	if _topbar_label:
		_topbar_label.text = "Money: $%d   Roster: %d/%d + MC" % [economy.money, economy.recruited_count, economy.max_roster]


func _build_background() -> void:
	var path := "res://Assets/Campaign/Bellarosa Syndicate/Maps/Juan Maps (Mafia).jpg"
	if ResourceLoader.exists(path):
		background.texture = load(path)
		background.centered = true
		var tex_size: Vector2 = background.texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			var scale_factor: float = max(MAP_BOUNDS.size.x / tex_size.x, MAP_BOUNDS.size.y / tex_size.y)
			background.scale = Vector2(scale_factor, scale_factor)
		background.modulate = Color(1, 1, 1, 0.55)
		background.z_index = -100


func _build_navigation() -> void:
	var poly := NavigationPolygon.new()
	var outline := PackedVector2Array([
		MAP_BOUNDS.position,
		Vector2(MAP_BOUNDS.position.x + MAP_BOUNDS.size.x, MAP_BOUNDS.position.y),
		MAP_BOUNDS.position + MAP_BOUNDS.size,
		Vector2(MAP_BOUNDS.position.x, MAP_BOUNDS.position.y + MAP_BOUNDS.size.y),
	])
	poly.add_outline(outline)
	poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = poly


func _build_obstacles() -> void:
	for rect in OBSTACLE_RECTS:
		var body := StaticBody2D.new()
		body.position = rect.position + rect.size * 0.5
		# Obstacles live on a dedicated collision layer (2) so BwUnit's
		# line-of-sight raycast can query "obstacles only" without also
		# hitting other units — see docs/TECH_DECISIONS.md.
		body.collision_layer = OBSTACLE_LAYER
		body.collision_mask = 0
		body.add_to_group("cover_objects")

		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = rect.size
		shape.shape = rect_shape
		body.add_child(shape)

		var visual := ColorRect.new()
		visual.color = Color(0.28, 0.28, 0.3)
		visual.size = rect.size
		visual.position = -rect.size * 0.5
		body.add_child(visual)

		var cover_radius: float = max(rect.size.x, rect.size.y) * 0.5 + 8.0
		body.set_meta("cover_radius", cover_radius)

		var obstacle := NavigationObstacle2D.new()
		obstacle.radius = cover_radius
		obstacle.avoidance_enabled = true
		body.add_child(obstacle)

		obstacles_root.add_child(body)


func _build_safe_zone_marker(label_text: String, pos: Vector2) -> void:
	var marker := Node2D.new()
	marker.position = pos
	var visual := Polygon2D.new()
	var pts := PackedVector2Array()
	var radius: float = economy.SAFE_ZONE_RADIUS_M * economy.PIXELS_PER_METER
	for i in range(32):
		var angle: float = TAU * float(i) / 32.0
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = pts
	visual.color = Color(0.2, 0.6, 0.9, 0.15)
	marker.add_child(visual)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(-30, -14)
	marker.add_child(label)
	obstacles_root.add_child(marker)


func _build_hud_extras() -> void:
	var topbar := Panel.new()
	topbar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	topbar.position = Vector2(20, 20)
	topbar.custom_minimum_size = Vector2(360, 40)
	hud_layer.add_child(topbar)
	_topbar_label = Label.new()
	_topbar_label.position = Vector2(10, 8)
	topbar.add_child(_topbar_label)

	var button_row := HBoxContainer.new()
	button_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button_row.position = Vector2(-420, 20)
	button_row.add_theme_constant_override("separation", 8)
	hud_layer.add_child(button_row)

	var recruitment_btn := Button.new()
	recruitment_btn.text = "Recruitment"
	recruitment_btn.pressed.connect(func(): _toggle_panel(recruitment_panel))
	button_row.add_child(recruitment_btn)

	var gun_shop_btn := Button.new()
	gun_shop_btn.text = "Gun Shop"
	gun_shop_btn.pressed.connect(func(): _toggle_panel(gun_shop_panel))
	button_row.add_child(gun_shop_btn)

	var inspect_btn := Button.new()
	inspect_btn.text = "Inspect"
	inspect_btn.pressed.connect(func(): _toggle_panel(inspect_panel))
	button_row.add_child(inspect_btn)

	recruitment_panel = PanelContainer.new()
	recruitment_panel.set_script(RECRUITMENT_PANEL_SCRIPT)
	recruitment_panel.economy = economy
	recruitment_panel.set_anchors_preset(Control.PRESET_CENTER)
	recruitment_panel.position = Vector2(-210, -160)
	recruitment_panel.visible = false
	hud_layer.add_child(recruitment_panel)
	recruitment_panel.closed.connect(func(): recruitment_panel.visible = false)

	gun_shop_panel = PanelContainer.new()
	gun_shop_panel.set_script(GUN_SHOP_PANEL_SCRIPT)
	gun_shop_panel.economy = economy
	gun_shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	gun_shop_panel.position = Vector2(-240, -210)
	gun_shop_panel.visible = false
	hud_layer.add_child(gun_shop_panel)
	gun_shop_panel.closed.connect(func(): gun_shop_panel.visible = false)

	inspect_panel = PanelContainer.new()
	inspect_panel.set_script(INSPECT_PANEL_SCRIPT)
	inspect_panel.economy = economy
	inspect_panel.selection_manager = selection_manager
	inspect_panel.set_anchors_preset(Control.PRESET_CENTER)
	inspect_panel.position = Vector2(-260, -240)
	inspect_panel.visible = false
	hud_layer.add_child(inspect_panel)
	inspect_panel.closed.connect(func(): inspect_panel.visible = false)


func _toggle_panel(panel: Control) -> void:
	panel.visible = not panel.visible
	if panel.visible and panel == inspect_panel:
		inspect_panel.refresh_roster()


func _log_event(text: String) -> void:
	if _combat_log:
		_combat_log.log_event(text)


func _spawn_fresh() -> void:
	var juan := _make_unit(&"juan", "Juan Bellarosa", "MC", &"player", true)
	juan.position = Vector2(-80, 40)
	juan.equip_weapon("primary", economy.weapon_catalog["weapon_pistol"])
	juan.equip_weapon("secondary", economy.weapon_catalog["weapon_knife"])
	units_root.add_child(juan)
	selection_manager.register_unit(juan)

	var b1_positions: Array = FormationUtils.compute_positions(Vector2(60, 40), 3, 40.0)
	for i in range(3):
		var b1 := _make_unit(&"b1_%d" % (i + 1), "B1", "B1", &"player", true)
		b1.position = b1_positions[i]
		units_root.add_child(b1)
		selection_manager.register_unit(b1)

	var enemy_positions: Array = FormationUtils.compute_positions(Vector2(520, -40), 4, 50.0)
	for i in range(4):
		var e := _make_unit(&"enemy_%d" % (i + 1), "Hostile (PLACEHOLDER)", "ENEMY", &"enemy_dummy", false)
		e.auto_defend = true
		e.is_recruitable_tier = true
		e.equip_weapon("primary", economy.weapon_catalog["weapon_assault_rifle"])
		e.primary_reserve = 999 # dummy encounters get abundant ammo; see docs/TECH_DECISIONS.md
		e.position = enemy_positions[i]
		enemies_root.add_child(e)
		e.died.connect(_on_enemy_died.bind(e))


func _make_unit(id: StringName, name_: String, tier: String, side: StringName, movable: bool) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = id
	u.display_name = name_
	u.tier_label = tier
	u.faction_side = side
	u.can_move = movable
	u.economy = economy
	match tier:
		"MC":
			u.unit_data = load("res://data/units/juan_mc.tres")
		"B1":
			u.unit_data = load("res://data/units/juan_b1.tres")
		"B2":
			u.unit_data = load("res://data/units/juan_b2.tres")
		"B3":
			u.unit_data = load("res://data/units/juan_b3.tres")
		_:
			u.max_hp = 90.0
			u.accuracy = 0.5
			u.move_speed_px = 190.0
	u.recruit_completed.connect(_on_recruit_completed)
	return u


func _on_unit_recruited(tier: String) -> void:
	var u := _make_unit(&"recruit_%d" % Time.get_ticks_msec(), tier, tier, &"player", true)
	u.position = SAFE_ZONE_RECRUITMENT_POS + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	units_root.add_child(u)
	selection_manager.register_unit(u)
	_log_event("A new %s joined the roster." % tier)


func _on_recruit_completed(recruiter: BwUnit, target: BwUnit) -> void:
	if not is_instance_valid(target) or target.faction_side == recruiter.faction_side:
		return
	if economy.recruited_count >= economy.max_roster:
		_log_event("Recruit failed: roster is full.")
		return
	var cost: int = int(economy.unit_data_by_tier["B1"].recruit_price / 2.0)
	if not economy.spend(cost):
		_log_event("Recruit failed: not enough money ($%d needed)." % cost)
		return
	var remembered_pos: Vector2 = target.global_position
	target.faction_side = &"player"
	target.can_move = true
	target.state = BwUnit.State.IDLE
	target.hp = target.max_hp * BwUnit.RECRUIT_HP_FRACTION
	target.is_recruitable_tier = false
	target.primary_weapon = null
	target.secondary_weapon = null
	target._setup_body_visual()
	target.body_poly.modulate = Color(1, 1, 1, 1)
	target.health_bar.set_ratio(target.hp / target.max_hp)
	enemies_root.remove_child(target)
	units_root.add_child(target)
	target.global_position = remembered_pos
	selection_manager.register_unit(target)
	economy.recruited_count += 1
	_log_event("%s recruited a former hostile (cost $%d)." % [recruiter.display_name, cost])
	call_deferred("_refresh_enemy_units_cache")


func _on_enemy_died(_e) -> void:
	call_deferred("_refresh_enemy_units_cache")


func _refresh_enemy_units_cache() -> void:
	var list: Array = []
	for c in enemies_root.get_children():
		if c is BwUnit and is_instance_valid(c):
			list.append(c)
	command_controller.enemy_units = list


func _on_selection_updated(units: Array) -> void:
	hud.show_unit(units[0] if units.size() > 0 else null)


func _toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	get_tree().paused = pause_menu.visible


func _on_restart() -> void:
	get_tree().paused = false
	GameState.pending_load_slot = -1
	get_tree().reload_current_scene()


func _gather_save_data() -> Dictionary:
	var units_data: Array = []
	for u in units_root.get_children():
		if u is BwUnit:
			units_data.append(_serialize_unit(u))
	for u in enemies_root.get_children():
		if u is BwUnit:
			units_data.append(_serialize_unit(u))
	return {
		"campaign_id": String(GameState.current_campaign_id),
		"difficulty_id": String(GameState.current_difficulty_id),
		"units": units_data,
		"money": economy.money,
		"recruited_count": economy.recruited_count,
		"gun_shop_inventory": economy.gun_shop_inventory,
	}


func _serialize_unit(u: BwUnit) -> Dictionary:
	return {
		"id": String(u.unit_id),
		"display_name": u.display_name,
		"tier": u.tier_label,
		"faction_side": String(u.faction_side),
		"x": u.global_position.x,
		"y": u.global_position.y,
		"hp": u.hp,
		"max_hp": u.max_hp,
		"morale": u.morale,
		"missed_payroll_cycles": u.missed_payroll_cycles,
		"state": u.state,
		"downed_timer": u.downed_timer,
		"primary_weapon": String(u.primary_weapon.id) if u.primary_weapon else "",
		"primary_mag": u.primary_mag,
		"primary_reserve": u.primary_reserve,
		"secondary_weapon": String(u.secondary_weapon.id) if u.secondary_weapon else "",
		"grenade_weapon": String(u.grenade_weapon.id) if u.grenade_weapon else "",
		"grenade_count": u.grenade_count,
		"armor_weapon": String(u.armor_weapon.id) if u.armor_weapon else "",
		"is_recruitable_tier": u.is_recruitable_tier,
		"can_move": u.can_move,
	}


func _on_save() -> void:
	SaveService.save_game(1, _gather_save_data())


func _on_load() -> void:
	get_tree().paused = false
	GameState.pending_load_slot = 1
	get_tree().reload_current_scene()


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _load_from_slot(slot: int) -> void:
	var data = SaveService.load_game(slot)
	if data == null:
		_spawn_fresh()
		return
	if data.has("campaign_id"):
		GameState.current_campaign_id = StringName(String(data["campaign_id"]))
	if data.has("difficulty_id"):
		GameState.current_difficulty_id = StringName(String(data["difficulty_id"]))
	economy.set_money(int(data.get("money", 4000)))
	economy.recruited_count = int(data.get("recruited_count", 0))
	var saved_inventory = data.get("gun_shop_inventory", null)
	if saved_inventory is Dictionary:
		for k in saved_inventory.keys():
			economy.gun_shop_inventory[k] = int(saved_inventory[k])

	for ud in data.get("units", []):
		var tier: String = ud.get("tier", "B1")
		var side := StringName(String(ud.get("faction_side", "player")))
		var movable: bool = bool(ud.get("can_move", side == &"player"))
		var u := _make_unit(StringName(String(ud.get("id", ""))), String(ud.get("display_name", ud.get("id", ""))), tier, side, movable)
		u.position = Vector2(float(ud.get("x", 0.0)), float(ud.get("y", 0.0)))
		u.morale = float(ud.get("morale", 100.0))
		u.missed_payroll_cycles = int(ud.get("missed_payroll_cycles", 0))
		u.is_recruitable_tier = bool(ud.get("is_recruitable_tier", false))
		var primary_id: String = ud.get("primary_weapon", "")
		if primary_id != "" and economy.weapon_catalog.has(primary_id):
			u.equip_weapon("primary", economy.weapon_catalog[primary_id])
			u.primary_mag = int(ud.get("primary_mag", u.primary_mag))
			u.primary_reserve = int(ud.get("primary_reserve", u.primary_reserve))
		var secondary_id: String = ud.get("secondary_weapon", "")
		if secondary_id != "" and economy.weapon_catalog.has(secondary_id):
			u.equip_weapon("secondary", economy.weapon_catalog[secondary_id])
		var grenade_id: String = ud.get("grenade_weapon", "")
		if grenade_id != "" and economy.weapon_catalog.has(grenade_id):
			u.equip_weapon("grenade", economy.weapon_catalog[grenade_id])
			u.grenade_count = int(ud.get("grenade_count", u.grenade_count))
		var armor_id: String = ud.get("armor_weapon", "")
		if armor_id != "" and economy.weapon_catalog.has(armor_id):
			u.equip_weapon("armor", economy.weapon_catalog[armor_id])
		if side == &"player":
			units_root.add_child(u)
			selection_manager.register_unit(u)
		else:
			u.auto_defend = true
			enemies_root.add_child(u)
			u.died.connect(_on_enemy_died.bind(u))
		var saved_state: int = int(ud.get("state", BwUnit.State.IDLE))
		var saved_hp: float = float(ud.get("hp", u.max_hp))
		if saved_state == BwUnit.State.DOWNED and saved_hp <= 0.0:
			u.call_deferred("_enter_downed")
			u.call_deferred("set", "downed_timer", float(ud.get("downed_timer", 30.0)))
		else:
			u.call_deferred("set_hp", saved_hp)


func gather_save_data_for_test() -> Dictionary:
	return _gather_save_data()
