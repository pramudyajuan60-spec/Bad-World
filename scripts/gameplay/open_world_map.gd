extends Node2D
## MVP3 gameplay scene: a connected open world (Prompt Dasar "STRUKTUR
## DUNIA") superseding MVP1/2's single small test map. Adds Factory →
## cargo → 4 Drug Dealers → carried cash → Bank economy loop, Garage +
## vehicles, cartel Patrol, Heat Meter + DEA response, and a destructible/
## repairable factory — layered on MVP1/2's unchanged camera, selection,
## command, and combat systems.
##
## World layout (inspired by, not a pixel copy of, Assets/Game Maps/
## World.png per rule 8): Bellarosa Syndicate HQ northwest, DEA Regional
## Field Office northeast, Nasion Familia HQ southwest, Vartieri Cartel
## HQ southeast, Central City in the middle. Only Bellarosa (Juan) is
## playable in this MVP (per MVP1/2's own scope); the other three HQs
## are non-functional landmark markers — see docs/PLACEHOLDER_REGISTER.md.

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const VEHICLE_SCENE := preload("res://scenes/gameplay/Vehicle.tscn")
const CASH_DROP_SCENE := preload("res://scenes/gameplay/CashDrop.tscn")
const DEST_MARKER_SCENE := preload("res://scenes/gameplay/DestinationMarker.tscn")
const RECRUITMENT_PANEL_SCRIPT := preload("res://scripts/ui/recruitment_panel.gd")
const GUN_SHOP_PANEL_SCRIPT := preload("res://scripts/ui/gun_shop_panel.gd")
const INSPECT_PANEL_SCRIPT := preload("res://scripts/ui/inspect_panel.gd")
const GARAGE_PANEL_SCRIPT := preload("res://scripts/ui/garage_panel.gd")
const FACTORY_SCRIPT := preload("res://scripts/economy/factory.gd")
const DEALER_SCRIPT := preload("res://scripts/economy/drug_dealer.gd")
const BANK_SCRIPT := preload("res://scripts/economy/bank_building.gd")
const GARAGE_SCRIPT := preload("res://scripts/economy/garage_building.gd")
const PANEL_BUILDING_SCRIPT := preload("res://scripts/economy/panel_building.gd")
const HEAT_MANAGER_SCRIPT := preload("res://scripts/economy/heat_manager.gd")

## Open world bounds, large enough to fit 4 region HQs + Central City
## with real travel distance between them.
const MAP_BOUNDS := Rect2(-4000, -3000, 8000, 6000)

const REGION_BELLAROSA := Vector2(-2600, -1800) # NW
const REGION_DEA := Vector2(2600, -1800)         # NE
const REGION_NASION := Vector2(-2600, 1800)      # SW
const REGION_VARTIERI := Vector2(2600, 1800)     # SE
const CENTRAL_CITY := Vector2(0, 0)

const BANK_POS := CENTRAL_CITY + Vector2(-160, -80)
const RECRUITMENT_POS := CENTRAL_CITY + Vector2(160, -80)
const GUN_SHOP_POS := CENTRAL_CITY + Vector2(-160, 80)
const GARAGE_POS := CENTRAL_CITY + Vector2(160, 80)
const FACTORY_POS := REGION_BELLAROSA + Vector2(300, 200)

const DEALER_POSITIONS := [
	Vector2(-900, -300), Vector2(900, -300), Vector2(-900, 900), Vector2(900, 900),
]
const OBSTACLE_RECTS := [
	Rect2(-260, -420, 220, 140), Rect2(180, -380, 260, 160),
	Rect2(-520, 120, 200, 220), Rect2(260, 200, 240, 180), Rect2(-70, -60, 160, 120),
]
const OBSTACLE_LAYER := 2

@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var obstacles_root: Node2D = $Obstacles
@onready var buildings_root: Node2D = $Buildings
@onready var units_root: Node2D = $Units
@onready var enemies_root: Node2D = $Enemies
@onready var vehicles_root: Node2D = $Vehicles
@onready var pickups_root: Node2D = $Pickups
@onready var box_overlay: Node2D = $BoxSelectOverlay
@onready var camera: RtsCamera = $RtsCamera
@onready var selection_manager: SelectionManager = $SelectionManager
@onready var command_controller = $CommandController
@onready var economy = $CampaignEconomy
@onready var heat_manager = $HeatManager
@onready var hud = $HUD/SelectionHud
@onready var pause_menu = $PauseMenu
@onready var hud_layer: CanvasLayer = $HUD

var recruitment_panel: Control
var gun_shop_panel: Control
var inspect_panel: Control
var garage_panel: Control
var recruitment_building
var gun_shop_building
var bank
var garage
var factory
var dealers: Array = []

var _topbar_label: Label
var _objective_label: Label
var _minimap: Control
var _alert_panel: Control
var _alert_label: Label
var _combat_log: Node = null


func _ready() -> void:
	_combat_log = get_node_or_null("/root/CombatLog")
	_build_navigation()
	_build_obstacles()
	camera.bounds = MAP_BOUNDS

	economy.set_money(4000) # Juan's starting money, Prompt Dasar BALANCE V0.1
	_build_buildings()
	economy.safe_zone_points = [BANK_POS, RECRUITMENT_POS]
	economy.unit_recruited.connect(_on_unit_recruited)

	heat_manager.set_script(HEAT_MANAGER_SCRIPT)
	heat_manager.world_bounds = MAP_BOUNDS
	heat_manager.player_position_getter = Callable(self, "_get_player_center")
	heat_manager.wave_dispatched.connect(_on_dea_wave_dispatched)

	command_controller.selection_manager = selection_manager
	command_controller.camera = camera
	command_controller.overlay = box_overlay
	command_controller.markers_parent = self
	command_controller.destination_marker_scene = DEST_MARKER_SCENE
	command_controller.pause_requested.connect(_toggle_pause)
	command_controller.vehicles_getter = Callable(self, "_get_all_vehicles")

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


func _process(delta: float) -> void:
	economy.payroll_units = units_root.get_children().filter(func(c): return c is BwUnit and is_instance_valid(c))
	if _topbar_label:
		_topbar_label.text = "Money: $%d   Roster: %d/%d + MC   Cargo carried: %d   Cash carried: $%d" % [
			economy.money, economy.recruited_count, economy.max_roster,
			_selected_or_first_carried_cargo(), _selected_or_first_carried_cash(),
		]
	if _objective_label:
		_objective_label.text = _compute_objective_text()
	_check_combat_heat()
	if _minimap:
		_minimap.queue_redraw()
	if is_instance_valid(command_controller):
		command_controller.vehicles_getter = Callable(self, "_get_all_vehicles")


func _selected_or_first_carried_cargo() -> int:
	var u = _first_selected_unit()
	return u.carried_cargo if u else 0


func _selected_or_first_carried_cash() -> int:
	var u = _first_selected_unit()
	return u.carried_cash if u else 0


func _first_selected_unit():
	if selection_manager.selected.size() > 0 and is_instance_valid(selection_manager.selected[0]):
		return selection_manager.selected[0]
	return null


## ---------------------------------------------------------------
## World construction
## ---------------------------------------------------------------
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
		body.position = REGION_BELLAROSA + rect.position + rect.size * 0.5
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


func _build_buildings() -> void:
	# Region HQ markers: only Bellarosa is a functional base in this MVP;
	# the other three are visual landmarks (Prompt Dasar names them all,
	# but only Juan's campaign is playable — see docs/PLACEHOLDER_REGISTER.md).
	_add_region_marker("Bellarosa Syndicate HQ", REGION_BELLAROSA, Color(0.2, 0.4, 0.9))
	_add_region_marker("DEA Regional Field Office (PLACEHOLDER)", REGION_DEA, Color(0.7, 0.2, 0.2))
	_add_region_marker("Nasion Familia HQ (PLACEHOLDER)", REGION_NASION, Color(0.6, 0.5, 0.1))
	_add_region_marker("Vartieri Cartel HQ (PLACEHOLDER)", REGION_VARTIERI, Color(0.5, 0.2, 0.6))
	_add_region_marker("Central City", CENTRAL_CITY, Color(0.5, 0.5, 0.5))

	bank = Area2D.new()
	bank.set_script(BANK_SCRIPT)
	bank.position = BANK_POS
	bank.economy = economy
	_attach_circle_shape(bank, 90.0)
	_attach_label(bank, "Bank")
	buildings_root.add_child(bank)

	garage = Area2D.new()
	garage.set_script(GARAGE_SCRIPT)
	garage.position = GARAGE_POS
	garage.economy = economy
	_attach_circle_shape(garage, 90.0)
	_attach_label(garage, "Garage")
	buildings_root.add_child(garage)

	recruitment_building = Area2D.new()
	recruitment_building.set_script(PANEL_BUILDING_SCRIPT)
	recruitment_building.building_label = "Recruitment"
	recruitment_building.position = RECRUITMENT_POS
	_attach_circle_shape(recruitment_building, 90.0)
	_attach_label(recruitment_building, "Recruitment")
	buildings_root.add_child(recruitment_building)

	gun_shop_building = Area2D.new()
	gun_shop_building.set_script(PANEL_BUILDING_SCRIPT)
	gun_shop_building.building_label = "Gun Shop"
	gun_shop_building.position = GUN_SHOP_POS
	_attach_circle_shape(gun_shop_building, 90.0)
	_attach_label(gun_shop_building, "Gun Shop")
	buildings_root.add_child(gun_shop_building)

	factory = Area2D.new()
	factory.set_script(FACTORY_SCRIPT)
	factory.position = FACTORY_POS
	_attach_circle_shape(factory, 80.0)
	_attach_label(factory, "Bellarosa Factory")
	buildings_root.add_child(factory)

	for i in range(4):
		var dealer := Area2D.new()
		dealer.set_script(DEALER_SCRIPT)
		dealer.position = DEALER_POSITIONS[i]
		var is_ph: bool = i == 3 # "Drug Dealer 4 wajib diberi label placeholder"
		dealer.dealer_label = "Drug Dealer %d%s" % [i + 1, " (PLACEHOLDER)" if is_ph else ""]
		dealer.is_placeholder = is_ph
		_attach_circle_shape(dealer, 70.0)
		_attach_label(dealer, dealer.dealer_label)
		buildings_root.add_child(dealer)
		dealers.append(dealer)


func _add_region_marker(label_text: String, pos: Vector2, color: Color) -> void:
	var marker := Node2D.new()
	marker.position = pos
	var visual := Polygon2D.new()
	var half := 220.0
	visual.polygon = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	visual.color = Color(color.r, color.g, color.b, 0.12)
	marker.add_child(visual)
	var label := Label.new()
	label.text = label_text
	label.position = Vector2(-half + 10, -half + 6)
	marker.add_child(label)
	buildings_root.add_child(marker)


func _attach_circle_shape(area: Area2D, radius: float) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 1 # BwUnit and Vehicle both physically live on layer 1
	var visual := Node2D.new()
	area.add_child(visual)


func _attach_label(area: Area2D, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(-40, -18)
	area.add_child(label)


## ---------------------------------------------------------------
## HUD
## ---------------------------------------------------------------
func _build_hud_extras() -> void:
	var topbar := Panel.new()
	topbar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	topbar.position = Vector2(20, 20)
	topbar.custom_minimum_size = Vector2(560, 40)
	hud_layer.add_child(topbar)
	_topbar_label = Label.new()
	_topbar_label.position = Vector2(10, 8)
	topbar.add_child(_topbar_label)

	var objective_panel := Panel.new()
	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.position = Vector2(20, 70)
	objective_panel.custom_minimum_size = Vector2(560, 32)
	hud_layer.add_child(objective_panel)
	_objective_label = Label.new()
	_objective_label.position = Vector2(10, 6)
	objective_panel.add_child(_objective_label)

	var button_row := HBoxContainer.new()
	button_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button_row.position = Vector2(-260, 20)
	button_row.add_theme_constant_override("separation", 8)
	hud_layer.add_child(button_row)

	var inspect_btn := Button.new()
	inspect_btn.text = "Inspect"
	inspect_btn.pressed.connect(func(): _toggle_panel(inspect_panel))
	button_row.add_child(inspect_btn)

	var alert_btn := Button.new()
	alert_btn.text = "Alerts"
	alert_btn.pressed.connect(func(): _alert_panel.visible = not _alert_panel.visible)
	button_row.add_child(alert_btn)

	recruitment_panel = PanelContainer.new()
	recruitment_panel.set_script(RECRUITMENT_PANEL_SCRIPT)
	recruitment_panel.economy = economy
	recruitment_panel.set_anchors_preset(Control.PRESET_CENTER)
	recruitment_panel.position = Vector2(-210, -160)
	recruitment_panel.visible = false
	hud_layer.add_child(recruitment_panel)
	recruitment_panel.closed.connect(func(): recruitment_panel.visible = false)
	recruitment_building.panel = recruitment_panel

	gun_shop_panel = PanelContainer.new()
	gun_shop_panel.set_script(GUN_SHOP_PANEL_SCRIPT)
	gun_shop_panel.economy = economy
	gun_shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	gun_shop_panel.position = Vector2(-240, -210)
	gun_shop_panel.visible = false
	hud_layer.add_child(gun_shop_panel)
	gun_shop_panel.closed.connect(func(): gun_shop_panel.visible = false)
	gun_shop_building.panel = gun_shop_panel

	inspect_panel = PanelContainer.new()
	inspect_panel.set_script(INSPECT_PANEL_SCRIPT)
	inspect_panel.economy = economy
	inspect_panel.selection_manager = selection_manager
	inspect_panel.set_anchors_preset(Control.PRESET_CENTER)
	inspect_panel.position = Vector2(-260, -240)
	inspect_panel.visible = false
	hud_layer.add_child(inspect_panel)
	inspect_panel.closed.connect(func(): inspect_panel.visible = false)

	garage_panel = PanelContainer.new()
	garage_panel.set_script(GARAGE_PANEL_SCRIPT)
	garage_panel.economy = economy
	garage_panel.set_anchors_preset(Control.PRESET_CENTER)
	garage_panel.position = Vector2(-230, -160)
	garage_panel.visible = false
	garage_panel.buy_requested.connect(_on_vehicle_buy_requested)
	hud_layer.add_child(garage_panel)
	garage_panel.closed.connect(func(): garage_panel.visible = false)

	# Alert log (Prompt Dasar "alert" HUD element): a scrollable readout
	# of CombatLog entries. Simplified single-panel implementation rather
	# than a full popup/toast system — see docs/PLACEHOLDER_REGISTER.md.
	_alert_panel = PanelContainer.new()
	_alert_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_alert_panel.position = Vector2(-420, 70)
	_alert_panel.custom_minimum_size = Vector2(400, 220)
	_alert_panel.visible = false
	hud_layer.add_child(_alert_panel)
	var alert_scroll := ScrollContainer.new()
	alert_scroll.custom_minimum_size = Vector2(390, 210)
	_alert_panel.add_child(alert_scroll)
	_alert_label = Label.new()
	_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_alert_label.custom_minimum_size = Vector2(380, 0)
	alert_scroll.add_child(_alert_label)
	if _combat_log:
		_combat_log.logged.connect(_on_log_event)
		_refresh_alert_text()

	# Minimap (Prompt Dasar "Minimap ... HUD"): a schematic top-down
	# _draw() of building/unit positions scaled to fit a small panel —
	# not a rendered SubViewport minimap. See docs/PLACEHOLDER_REGISTER.md.
	_minimap = Control.new()
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_minimap.position = Vector2(-220, -220)
	_minimap.custom_minimum_size = Vector2(200, 200)
	_minimap.draw.connect(_draw_minimap)
	hud_layer.add_child(_minimap)


func _on_log_event(_text: String) -> void:
	_refresh_alert_text()


func _refresh_alert_text() -> void:
	if _combat_log and _alert_label:
		_alert_label.text = "\n".join(_combat_log.entries)


func _draw_minimap() -> void:
	if not _minimap:
		return
	var size: Vector2 = _minimap.size
	_minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08, 0.85))
	var to_map := func(world_pos: Vector2) -> Vector2:
		var t: Vector2 = (world_pos - MAP_BOUNDS.position) / MAP_BOUNDS.size
		return t * size
	for u in units_root.get_children():
		if u is BwUnit and is_instance_valid(u):
			_minimap.draw_circle(to_map.call(u.global_position), 2.5, Color(0.3, 0.8, 1.0))
	for e in enemies_root.get_children():
		if e is BwUnit and is_instance_valid(e):
			_minimap.draw_circle(to_map.call(e.global_position), 2.5, Color(0.9, 0.2, 0.2))
	_minimap.draw_circle(to_map.call(FACTORY_POS), 3.0, Color(0.8, 0.8, 0.2))
	_minimap.draw_circle(to_map.call(BANK_POS), 3.0, Color(0.2, 0.9, 0.4))
	for d in DEALER_POSITIONS:
		_minimap.draw_circle(to_map.call(d), 3.0, Color(0.9, 0.6, 0.2))


func _compute_objective_text() -> String:
	var u = _first_selected_unit()
	if u == null:
		return "Objective: select Juan or your squad to begin the economy loop."
	if u.carried_cash > 0:
		return "Objective: deposit $%d at the Bank (safe zone, central city)." % u.carried_cash
	if u.carried_cargo > 0:
		return "Objective: sell %d cargo at a Drug Dealer." % u.carried_cargo
	return "Objective: pick up cargo at the Bellarosa Factory (northwest)."


func _toggle_panel(panel: Control) -> void:
	panel.visible = not panel.visible
	if panel.visible and panel == inspect_panel:
		inspect_panel.refresh_roster()


## ---------------------------------------------------------------
## Spawning
## ---------------------------------------------------------------
func _spawn_fresh() -> void:
	var juan := _make_unit(&"juan", "Juan Bellarosa", "MC", &"player", true)
	juan.position = REGION_BELLAROSA + Vector2(-80, 40)
	juan.equip_weapon("primary", economy.weapon_catalog["weapon_pistol"])
	juan.equip_weapon("secondary", economy.weapon_catalog["weapon_knife"])
	units_root.add_child(juan)
	selection_manager.register_unit(juan)

	var b1_positions: Array = FormationUtils.compute_positions(REGION_BELLAROSA + Vector2(60, 40), 3, 40.0)
	for i in range(3):
		var b1 := _make_unit(&"b1_%d" % (i + 1), "B1", "B1", &"player", true)
		b1.position = b1_positions[i]
		units_root.add_child(b1)
		selection_manager.register_unit(b1)

	var enemy_positions: Array = FormationUtils.compute_positions(REGION_BELLAROSA + Vector2(520, -40), 4, 50.0)
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
	u.loot_dropped.connect(_on_loot_dropped)
	return u


func _spawn_cash_drop(pos: Vector2, cargo: int, cash: int) -> void:
	if cargo <= 0 and cash <= 0:
		return
	var drop = CASH_DROP_SCENE.instantiate()
	drop.cargo = cargo
	drop.cash = cash
	drop.position = pos
	pickups_root.add_child(drop)


func _on_loot_dropped(pos: Vector2, cargo: int, cash: int) -> void:
	_spawn_cash_drop(pos, cargo, cash)


func _on_unit_recruited(tier: String) -> void:
	var u := _make_unit(&"recruit_%d" % Time.get_ticks_msec(), tier, tier, &"player", true)
	u.position = RECRUITMENT_POS + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	units_root.add_child(u)
	selection_manager.register_unit(u)
	if _combat_log:
		_combat_log.log_event("A new %s joined the roster." % tier)


func _on_recruit_completed(recruiter: BwUnit, target: BwUnit) -> void:
	if not is_instance_valid(target) or target.faction_side == recruiter.faction_side:
		return
	if economy.recruited_count >= economy.max_roster:
		if _combat_log:
			_combat_log.log_event("Recruit failed: roster is full.")
		return
	var cost: int = int(economy.unit_data_by_tier["B1"].recruit_price / 2.0)
	if not economy.spend(cost):
		if _combat_log:
			_combat_log.log_event("Recruit failed: not enough money ($%d needed)." % cost)
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
	if _combat_log:
		_combat_log.log_event("%s recruited a former hostile (cost $%d)." % [recruiter.display_name, cost])
	call_deferred("_refresh_enemy_units_cache")


func _on_enemy_died(_e) -> void:
	call_deferred("_refresh_enemy_units_cache")


func _refresh_enemy_units_cache() -> void:
	var list: Array = []
	for c in enemies_root.get_children():
		if c is BwUnit and is_instance_valid(c):
			list.append(c)
	command_controller.enemy_units = list


func _get_all_vehicles() -> Array:
	return vehicles_root.get_children().filter(func(v): return v is Vehicle and is_instance_valid(v))


## ---------------------------------------------------------------
## Building interaction (E key): factory pickup, dealer sell, bank
## deposit, garage repair/buy, recruitment/gun shop panel toggle.
## ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_handle_interact()


func _handle_interact() -> void:
	var unit = _first_selected_unit()
	if unit == null or not is_instance_valid(unit) or unit.mounted_vehicle != null:
		return
	if unit in factory.get_units_in_range():
		factory.try_pickup(unit)
		return
	for d in dealers:
		if unit in d.get_units_in_range():
			d.start_sell(unit, economy, factory.cargo_value())
			return
	if unit in bank.get_units_in_range():
		bank.start_deposit(unit)
		return
	if recruitment_building.has_player_in_range():
		recruitment_building.toggle_panel()
		return
	if gun_shop_building.has_player_in_range():
		gun_shop_building.toggle_panel()
		return
	if unit.global_position.distance_to(garage.global_position) <= 90.0:
		if not garage.try_repair():
			garage_panel.visible = not garage_panel.visible


func _on_vehicle_buy_requested(vehicle_id: String) -> void:
	var data: VehicleData = load("res://data/vehicles/%s.tres" % vehicle_id.replace("vehicle_", ""))
	if not economy.spend(data.price):
		if _combat_log:
			_combat_log.log_event("Cannot afford %s." % data.display_name)
		return
	var v = VEHICLE_SCENE.instantiate()
	v.vehicle_data = data
	v.faction_side = &"player"
	v.position = GARAGE_POS + Vector2(randf_range(-60, 60), randf_range(80, 140))
	vehicles_root.add_child(v)
	if _combat_log:
		_combat_log.log_event("Purchased a %s." % data.display_name)


## ---------------------------------------------------------------
## Heat Meter + DEA response
## ---------------------------------------------------------------
func _get_player_center() -> Vector2:
	var units := selection_manager.player_units.filter(func(u): return is_instance_valid(u))
	if units.is_empty():
		return REGION_BELLAROSA
	var sum := Vector2.ZERO
	for u in units:
		sum += u.global_position
	return sum / units.size()


func _check_combat_heat() -> void:
	for e in enemies_root.get_children():
		if e is BwUnit and is_instance_valid(e) and e.state == BwUnit.State.ATTACKING:
			heat_manager.notify_combat_tick()
			return
	for u in units_root.get_children():
		if u is BwUnit and is_instance_valid(u) and u.state == BwUnit.State.ATTACKING and u.attack_target and is_instance_valid(u.attack_target) and u.attack_target.faction_side == &"enemy_dea":
			heat_manager.notify_combat_tick()
			return


func _on_dea_wave_dispatched(wave_number: int) -> void:
	var spawn_pos: Vector2 = heat_manager.pick_spawn_point()
	if _combat_log:
		_combat_log.log_event("DEA response wave %d inbound." % wave_number)
	var b2_count: int = 4 if wave_number == 1 else 0
	var b3_count: int = 1 if wave_number == 1 else 2
	for i in range(b2_count):
		var u := _make_unit(&"dea_b2_%d_%d" % [wave_number, i], "DEA Responder (PLACEHOLDER)", "B2", &"enemy_dea", false)
		u.auto_defend = true
		u.equip_weapon("primary", economy.weapon_catalog["weapon_assault_rifle"])
		u.primary_reserve = 999
		u.position = spawn_pos + Vector2(i * 30, 0)
		enemies_root.add_child(u)
	for i in range(b3_count):
		var u := _make_unit(&"dea_b3_%d_%d" % [wave_number, i], "DEA Commander (PLACEHOLDER)", "B3", &"enemy_dea", false)
		u.auto_defend = true
		u.equip_weapon("primary", economy.weapon_catalog["weapon_lmg"])
		u.primary_reserve = 999
		u.position = spawn_pos + Vector2(-40 - i * 30, 20)
		enemies_root.add_child(u)
	var vehicle_id := "vehicle_armored_suv" if wave_number == 1 else "vehicle_apc"
	var vdata: VehicleData = load("res://data/vehicles/%s.tres" % vehicle_id.replace("vehicle_", ""))
	var v = VEHICLE_SCENE.instantiate()
	v.vehicle_data = vdata
	v.faction_side = &"enemy_dea"
	v.position = spawn_pos + Vector2(0, -40)
	vehicles_root.add_child(v)


func _on_selection_updated(units: Array) -> void:
	hud.show_unit(units[0] if units.size() > 0 else null)


func _toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	get_tree().paused = pause_menu.visible


func _on_restart() -> void:
	get_tree().paused = false
	GameState.pending_load_slot = -1
	get_tree().reload_current_scene()


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


## ---------------------------------------------------------------
## Save/load (extended for MVP3: economy, cargo, vehicles, Heat,
## buildings — per that acceptance criterion).
## ---------------------------------------------------------------
func _gather_save_data() -> Dictionary:
	var units_data: Array = []
	for u in units_root.get_children():
		if u is BwUnit:
			units_data.append(_serialize_unit(u))
	for u in enemies_root.get_children():
		if u is BwUnit:
			units_data.append(_serialize_unit(u))
	var vehicles_data: Array = []
	for v in vehicles_root.get_children():
		if v is Vehicle and is_instance_valid(v):
			vehicles_data.append({
				"id": v.vehicle_data.id if v.vehicle_data else "",
				"faction_side": String(v.faction_side),
				"x": v.global_position.x, "y": v.global_position.y,
				"hp": v.hp, "carried_cargo": v.carried_cargo, "carried_cash": v.carried_cash,
			})
	return {
		"campaign_id": String(GameState.current_campaign_id),
		"difficulty_id": String(GameState.current_difficulty_id),
		"units": units_data,
		"vehicles": vehicles_data,
		"money": economy.money,
		"recruited_count": economy.recruited_count,
		"gun_shop_inventory": economy.gun_shop_inventory,
		"factory_level": factory.level,
		"factory_hp": factory.hp,
		"factory_cargo": factory.stored_cargo,
		"heat_waves_dispatched": heat_manager.waves_dispatched,
	}


func _serialize_unit(u: BwUnit) -> Dictionary:
	return {
		"id": String(u.unit_id), "display_name": u.display_name, "tier": u.tier_label,
		"faction_side": String(u.faction_side), "x": u.global_position.x, "y": u.global_position.y,
		"hp": u.hp, "max_hp": u.max_hp, "morale": u.morale,
		"missed_payroll_cycles": u.missed_payroll_cycles, "state": u.state, "downed_timer": u.downed_timer,
		"primary_weapon": String(u.primary_weapon.id) if u.primary_weapon else "",
		"primary_mag": u.primary_mag, "primary_reserve": u.primary_reserve,
		"secondary_weapon": String(u.secondary_weapon.id) if u.secondary_weapon else "",
		"grenade_weapon": String(u.grenade_weapon.id) if u.grenade_weapon else "", "grenade_count": u.grenade_count,
		"armor_weapon": String(u.armor_weapon.id) if u.armor_weapon else "",
		"is_recruitable_tier": u.is_recruitable_tier, "can_move": u.can_move,
		"carried_cargo": u.carried_cargo, "carried_cash": u.carried_cash,
	}


func _on_save() -> void:
	SaveService.save_game(1, _gather_save_data())


func _on_load() -> void:
	get_tree().paused = false
	GameState.pending_load_slot = 1
	get_tree().reload_current_scene()


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
	factory.level = int(data.get("factory_level", 1))
	factory.hp = float(data.get("factory_hp", factory.max_hp))
	factory.is_destroyed = factory.hp <= 0.0
	factory.stored_cargo = int(data.get("factory_cargo", 0))
	heat_manager.waves_dispatched = int(data.get("heat_waves_dispatched", 0))

	for ud in data.get("units", []):
		var tier: String = ud.get("tier", "B1")
		var side := StringName(String(ud.get("faction_side", "player")))
		var movable: bool = bool(ud.get("can_move", side == &"player"))
		var u := _make_unit(StringName(String(ud.get("id", ""))), String(ud.get("display_name", ud.get("id", ""))), tier, side, movable)
		u.position = Vector2(float(ud.get("x", 0.0)), float(ud.get("y", 0.0)))
		u.morale = float(ud.get("morale", 100.0))
		u.missed_payroll_cycles = int(ud.get("missed_payroll_cycles", 0))
		u.is_recruitable_tier = bool(ud.get("is_recruitable_tier", false))
		u.carried_cargo = int(ud.get("carried_cargo", 0))
		u.carried_cash = int(ud.get("carried_cash", 0))
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

	for vd in data.get("vehicles", []):
		var vid: String = vd.get("id", "")
		if vid == "":
			continue
		var vdata: VehicleData = load("res://data/vehicles/%s.tres" % vid.replace("vehicle_", ""))
		var v = VEHICLE_SCENE.instantiate()
		v.vehicle_data = vdata
		v.faction_side = StringName(String(vd.get("faction_side", "player")))
		v.position = Vector2(float(vd.get("x", 0.0)), float(vd.get("y", 0.0)))
		vehicles_root.add_child(v)
		v.call_deferred("set", "hp", float(vd.get("hp", v.max_hp)))
		v.carried_cargo = int(vd.get("carried_cargo", 0))
		v.carried_cash = int(vd.get("carried_cash", 0))


func gather_save_data_for_test() -> Dictionary:
	return _gather_save_data()
