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
const ARMORY_SCRIPT := preload("res://scripts/economy/armory_building.gd")
const ARMORY_PANEL_SCRIPT := preload("res://scripts/ui/armory_panel.gd")
const ABILITY_BAR_SCRIPT := preload("res://scripts/ui/ability_bar.gd")
const KNOWLEDGE_SCRIPT := preload("res://scripts/ai/faction_knowledge.gd")
const AI_DEBUG_OVERLAY_SCENE := preload("res://scenes/ui/AiDebugOverlay.tscn")
const TUTORIAL_CONTROLLER_SCRIPT := preload("res://scripts/gameplay/tutorial_controller.gd")

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
## Maps campaign id -> that faction's HQ region. Kept here rather than
## on CampaignData since it's purely a world-layout concern of this one
## scene (see docs/TECH_DECISIONS.md).
const REGION_BY_CAMPAIGN := {
	&"campaign_juan": Vector2(-2600, -1800), # Bellarosa, NW
	&"campaign_fauzi": Vector2(2600, 1800),          # Vartieri, SE
	&"campaign_atha": Vector2(-2600, 1800),          # Nasion, SW
	&"campaign_nabil": Vector2(2600, -1800),         # DEA, NE
}

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
@onready var victory_defeat_screen = $VictoryDefeatScreen
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
var _save_slot_panel: Control
var _settings_panel: Control
var _payroll_warning_label: Label
var _payroll_warning_timer: float = 0.0
var _low_ammo_label: Label
var _demand_panel: Control
var _demand_label: Label
var _patrol_panel: Control
var _patrol_label: Label
var _diplomacy_panel: Control
var _diplomacy_label: Label
var _camera_alert_panel: Control
var _camera_alert_label: Label
var _camera_alert_target_pos: Vector2 = Vector2.ZERO
var _camera_alert_timer: float = 0.0
var _last_hp_ratio: Dictionary = {}
var _tutorial: Node = null
var _tutorial_panel: Control
var _tutorial_title_label: Label
var _tutorial_body_label: Label
const SAVE_SLOT_PANEL_SCRIPT := preload("res://scripts/ui/save_slot_panel.gd")
const SETTINGS_PANEL_SCRIPT := preload("res://scripts/ui/settings_panel.gd")
const VICTORY_DEFEAT_SCREEN_SCENE := preload("res://scenes/gameplay/VictoryDefeatScreen.tscn")
const AUTOSAVE_INTERVAL_SEC := 90.0
var _autosave_timer: float = 0.0
## MVP6 campaign-summary stats (Prompt Dasar "campaign summary").
var elapsed_play_sec: float = 0.0
var enemies_eliminated_count: int = 0
var _victory_defeat_screen: Node = null
var _mission_over: bool = false
## Populated only if/when a rival faction Main Character is ever
## spawned in this live map (not yet — see docs/PLACEHOLDER_REGISTER.md
## "Rival faction HQs"); kept generic and tested in isolation
## (tests/test_mvp6_victory_defeat.gd) so the victory condition is
## correct and ready the moment that content lands.
var _enemy_mc_registry: Array = []
## MVP5: dev-only fog-of-war feed for this map's fixed hostile
## encounters (the "Hostile (PLACEHOLDER)" test squad + DEA response
## waves), exposed only through the F3 debug overlay. These squads are
## deliberately stationary (can_move = false, an MVP1/3 design choice)
## and keep using their existing tested BwUnit.auto_defend behavior —
## a real, mobile TACTICAL/STRATEGIC AI faction only makes sense for a
## unit that can actually move, which is exactly what the headless
## AiMatchArena drives (see scripts/simulation/ai_match_arena.gd and
## docs/TECH_DECISIONS.md "MVP5 live-game AI scope"). This knowledge
## instance exists purely so a developer can see what these fixed
## encounters would perceive, not to drive any decision of theirs.
var _hostile_knowledge: Node = null
var _ai_debug_overlay: Node = null

## MVP4: resolved once in _ready() from GameState.current_campaign_id.
var current_campaign: CampaignData
var current_faction: FactionData
var player_hq_position: Vector2 = Vector2.ZERO
var armory_building
var armory_panel: Control
var ability_bar: Control
var _patrolling_nabil_cache: Array = []
## Tracks currently-spawned player Special units (for Zie's Triad
## Synergy check, and generally so specials aren't double-recruited).
var special_unit_instances: Array = []
var _recruited_special_ids: Array = []
const TRIAD_SYNERGY_RADIUS_PX := 240.0 # 12m * 20px/m


func _ready() -> void:
	_combat_log = get_node_or_null("/root/CombatLog")

	# Resolve which campaign to build for *before* any faction-specific
	# construction happens. A save file's own campaign_id takes priority
	# over whatever GameState.current_campaign_id currently holds — e.g.
	# "Continue" from the Main Menu never explicitly sets it, so without
	# this peek a Zie save would incorrectly build Juan's world/buildings
	# before _load_from_slot corrected it too late (see docs/TECH_DECISIONS.md
	# "Save/load must resolve the campaign before faction-specific setup").
	var pending_slot := GameState.pending_load_slot
	var loaded_save_data = null
	if pending_slot >= 0 and SaveService.has_save(pending_slot):
		loaded_save_data = SaveService.load_game(pending_slot)
		if loaded_save_data != null and loaded_save_data.has("campaign_id"):
			GameState.current_campaign_id = StringName(String(loaded_save_data["campaign_id"]))

	current_campaign = CampaignDatabase.get_campaign(GameState.current_campaign_id)
	if current_campaign == null:
		current_campaign = CampaignDatabase.get_campaign(&"campaign_juan")
	current_faction = current_campaign.faction
	player_hq_position = REGION_BY_CAMPAIGN.get(current_campaign.id, REGION_BELLAROSA)

	_build_navigation()
	_build_obstacles()
	camera.bounds = MAP_BOUNDS

	economy.set_money(current_campaign.starting_money)
	economy.lifetime_money_earned = 0 # starting funds aren't "earned"
	economy.max_roster = current_faction.max_roster
	economy.configure_roster(current_campaign)
	_build_buildings()
	economy.safe_zone_points = [BANK_POS, RECRUITMENT_POS]
	economy.unit_recruited.connect(_on_unit_recruited)

	heat_manager.set_script(HEAT_MANAGER_SCRIPT)
	heat_manager.world_bounds = MAP_BOUNDS
	heat_manager.player_position_getter = Callable(self, "_get_player_center")
	heat_manager.wave_dispatched.connect(_on_dea_wave_dispatched)

	_hostile_knowledge = KNOWLEDGE_SCRIPT.new()
	_tutorial = TUTORIAL_CONTROLLER_SCRIPT.new()
	add_child(_tutorial)
	_hostile_knowledge.owner_faction_side = &"hostile_shared"
	_hostile_knowledge.own_units_getter = Callable(self, "_get_hostile_units")
	_hostile_knowledge.world_units_getter = Callable(self, "_get_player_side_units")
	add_child(_hostile_knowledge)

	_ai_debug_overlay = AI_DEBUG_OVERLAY_SCENE.instantiate()
	add_child(_ai_debug_overlay)
	_ai_debug_overlay.visible = false
	_ai_debug_overlay.watched = [{"faction_side": &"hostile_shared", "knowledge": _hostile_knowledge}]

	command_controller.selection_manager = selection_manager
	command_controller.camera = camera
	command_controller.overlay = box_overlay
	command_controller.markers_parent = self
	command_controller.destination_marker_scene = DEST_MARKER_SCENE
	command_controller.pause_requested.connect(_toggle_pause)
	command_controller.vehicles_getter = Callable(self, "_get_all_vehicles")
	command_controller.move_order_issued.connect(func(): _tutorial.request(&"movement"))
	command_controller.defend_order_issued.connect(func(): _tutorial.request(&"defend"))
	command_controller.patrol_order_issued.connect(func(): _tutorial.request(&"patrol"))
	command_controller.vehicle_enter_order_issued.connect(func(): _tutorial.request(&"vehicle"))

	selection_manager.selection_updated.connect(_on_selection_updated)

	pause_menu.visible = false
	pause_menu.resume_requested.connect(_toggle_pause)
	pause_menu.restart_requested.connect(_on_restart)
	pause_menu.save_load_requested.connect(_on_save_load_requested)
	pause_menu.settings_requested.connect(_on_settings_requested)
	pause_menu.quit_to_menu_requested.connect(_on_quit_to_menu)

	_build_hud_extras()

	GameState.pending_load_slot = -1
	if loaded_save_data != null:
		_apply_save_data(loaded_save_data)
	else:
		_spawn_fresh()

	_refresh_enemy_units_cache()
	_tutorial.request(&"mc_protection")


func _process(delta: float) -> void:
	if _mission_over:
		return
	elapsed_play_sec += delta
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
	if current_campaign.id == &"campaign_fauzi":
		_update_triad_synergy()
	if current_faction.uses_armory_instead_of_gun_shop:
		_apply_nabil_patrol_income(delta)
		_refresh_patrol_panel()
	if ability_bar:
		ability_bar.refresh()

	_refresh_low_ammo_warning()
	_refresh_demand_panel()
	_refresh_diplomacy_panel()
	_check_victory_condition()

	if _payroll_warning_timer > 0.0:
		_payroll_warning_timer -= delta
		if _payroll_warning_timer <= 0.0 and _payroll_warning_label:
			_payroll_warning_label.visible = false
	if _camera_alert_timer > 0.0:
		_camera_alert_timer -= delta
		if _camera_alert_timer <= 0.0 and _camera_alert_panel:
			_camera_alert_panel.visible = false

	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL_SEC:
		_autosave_timer = 0.0
		_run_autosave()


## MVP4: Zie's Triad Synergy (Prompt Dasar "AKTIF jika ketiganya hidup
## dan berada dalam radius 12 meter"). All-or-nothing: either every
## alive-and-clustered special gets the full buff, or none do.
func _update_triad_synergy() -> void:
	var alive_specials: Array = special_unit_instances.filter(func(u): return is_instance_valid(u) and u.state != BwUnit.State.DEAD and u.state != BwUnit.State.DOWNED)
	var active: bool = false
	if alive_specials.size() == 3:
		active = true
		for i in range(3):
			for j in range(i + 1, 3):
				if alive_specials[i].global_position.distance_to(alive_specials[j].global_position) > TRIAD_SYNERGY_RADIUS_PX:
					active = false
	for u in special_unit_instances:
		if not is_instance_valid(u):
			continue
		if active:
			u.synergy_damage_mult = 1.20
			u.synergy_armor_reduction = 0.15
			u.synergy_suppression_resist_mult = 0.25
		else:
			u.synergy_damage_mult = 1.0
			u.synergy_armor_reduction = 0.0
			u.synergy_suppression_resist_mult = 0.0


## MVP4: Nabil's City Patrol income. Only units actually in
## State.PATROLLING earn (no income while fighting, at Bank, or at
## Recruitment, per Prompt Dasar — those states are never PATROLLING).
func _apply_nabil_patrol_income(delta: float) -> void:
	var patrolling: Array = []
	for u in units_root.get_children():
		if u is BwUnit and is_instance_valid(u) and u.state == BwUnit.State.PATROLLING:
			patrolling.append(u)
	economy.apply_patrol_income(delta, patrolling)


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
	# Region HQ markers: MVP4 activates all 4 campaigns, but a given
	# playthrough is still single-player/single-faction (Prompt Dasar:
	# choose one campaign from the menu). The chosen faction's own HQ
	# gets its real name + a functional Factory; the other three remain
	# visual landmarks for this session (no rival-faction AI yet — that
	# is MVP5 scope) — see docs/PLACEHOLDER_REGISTER.md.
	var hq_labels := {
		&"campaign_juan": ["Bellarosa Syndicate HQ", REGION_BELLAROSA, Color(0.2, 0.4, 0.9)],
		&"campaign_nabil": ["DEA Regional Field Office", REGION_DEA, Color(0.7, 0.2, 0.2)],
		&"campaign_atha": ["Nasion Familia HQ", REGION_NASION, Color(0.6, 0.5, 0.1)],
		&"campaign_fauzi": ["Vartieri Cartel HQ", REGION_VARTIERI, Color(0.5, 0.2, 0.6)],
	}
	for cid in hq_labels.keys():
		var info: Array = hq_labels[cid]
		var label: String = info[0] if cid == current_campaign.id else "%s (PLACEHOLDER)" % info[0]
		_add_region_marker(label, info[1], info[2])
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

	if current_faction.uses_armory_instead_of_gun_shop:
		# Nabil crafts weapons from Parts instead of buying them (Prompt
		# Dasar: "Nabil tidak membeli senjata biasa").
		armory_building = Area2D.new()
		armory_building.set_script(ARMORY_SCRIPT)
		armory_building.position = GUN_SHOP_POS
		_attach_circle_shape(armory_building, 90.0)
		_attach_label(armory_building, "DEA Armory")
		buildings_root.add_child(armory_building)
	else:
		gun_shop_building = Area2D.new()
		gun_shop_building.set_script(PANEL_BUILDING_SCRIPT)
		gun_shop_building.building_label = "Gun Shop"
		gun_shop_building.position = GUN_SHOP_POS
		_attach_circle_shape(gun_shop_building, 90.0)
		_attach_label(gun_shop_building, "Gun Shop")
		buildings_root.add_child(gun_shop_building)

	factory = Area2D.new()
	factory.set_script(FACTORY_SCRIPT)
	factory.level = current_faction.starting_factory_level if current_faction.starting_factory_level > 0 else 1
	factory.faction_side = &"player"
	factory.value_mult = current_faction.factory_value_mult
	factory.speed_mult = current_faction.factory_speed_mult
	factory.position = player_hq_position + Vector2(300, 200)
	_attach_circle_shape(factory, 80.0)
	_attach_label(factory, "%s Factory" % current_faction.display_name)
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
	inspect_btn.pressed.connect(func(): _toggle_panel(inspect_panel); _tutorial.request(&"equipment"))
	button_row.add_child(inspect_btn)

	var alert_btn := Button.new()
	alert_btn.text = "Alerts"
	alert_btn.pressed.connect(func(): _alert_panel.visible = not _alert_panel.visible)
	button_row.add_child(alert_btn)

	if current_faction.uses_armory_instead_of_gun_shop:
		# Nabil's "DEA response menjadi allied AI beranggaran/cooldown":
		# a manual, budgeted dispatch rather than a hostile Heat wave.
		var dispatch_btn := Button.new()
		dispatch_btn.text = "Dispatch Allies ($%d)" % economy.ALLY_DISPATCH_COST
		dispatch_btn.pressed.connect(_on_dispatch_allies_pressed)
		button_row.add_child(dispatch_btn)

	var mc_upgrade_btn := Button.new()
	mc_upgrade_btn.text = "Upgrade MC"
	mc_upgrade_btn.pressed.connect(_on_mc_upgrade_pressed)
	button_row.add_child(mc_upgrade_btn)

	ability_bar = Control.new()
	ability_bar.set_script(ABILITY_BAR_SCRIPT)
	ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ability_bar.position = Vector2(20, -160)
	ability_bar.get_main_character = Callable(self, "_get_main_character")
	ability_bar.command_controller = command_controller
	hud_layer.add_child(ability_bar)

	recruitment_panel = PanelContainer.new()
	recruitment_panel.set_script(RECRUITMENT_PANEL_SCRIPT)
	recruitment_panel.economy = economy
	recruitment_panel.map = self
	recruitment_panel.set_anchors_preset(Control.PRESET_CENTER)
	recruitment_panel.position = Vector2(-210, -160)
	recruitment_panel.visible = false
	hud_layer.add_child(recruitment_panel)
	recruitment_panel.closed.connect(func(): recruitment_panel.visible = false)
	recruitment_building.panel = recruitment_panel

	if current_faction.uses_armory_instead_of_gun_shop:
		armory_panel = PanelContainer.new()
		armory_panel.set_script(ARMORY_PANEL_SCRIPT)
		armory_panel.economy = economy
		armory_panel.set_anchors_preset(Control.PRESET_CENTER)
		armory_panel.position = Vector2(-240, -210)
		armory_panel.visible = false
		hud_layer.add_child(armory_panel)
		armory_panel.closed.connect(func(): armory_panel.visible = false)
		armory_building.panel = armory_panel
	else:
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

	# MVP6: Save/Load slot picker + Settings, both reachable from the
	# Pause Menu, exact same panel scripts SettingsMenu.tscn hosts.
	_save_slot_panel = PanelContainer.new()
	_save_slot_panel.set_script(SAVE_SLOT_PANEL_SCRIPT)
	_save_slot_panel.set_anchors_preset(Control.PRESET_CENTER)
	_save_slot_panel.position = Vector2(-280, -210)
	_save_slot_panel.visible = false
	hud_layer.add_child(_save_slot_panel)
	_save_slot_panel.closed.connect(func(): _save_slot_panel.visible = false)
	_save_slot_panel.save_to_slot_requested.connect(_on_save_to_slot)
	_save_slot_panel.load_slot_requested.connect(_on_load_slot)

	_settings_panel = PanelContainer.new()
	_settings_panel.set_script(SETTINGS_PANEL_SCRIPT)
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-280, -260)
	_settings_panel.visible = false
	hud_layer.add_child(_settings_panel)
	_settings_panel.closed.connect(func(): _settings_panel.visible = false)

	# MVP6 Payroll warning (Prompt Dasar item 8): flashes on a missed
	# payroll cycle rather than only appearing as one Alerts-log line.
	_payroll_warning_label = Label.new()
	_payroll_warning_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_payroll_warning_label.position = Vector2(0, 110)
	_payroll_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_payroll_warning_label.modulate = Color(1.0, 0.3, 0.25)
	_payroll_warning_label.visible = false
	hud_layer.add_child(_payroll_warning_label)
	economy.payroll_processed.connect(_on_payroll_processed)

	# MVP6 Low-ammo warning (item 9): watches the current selection.
	_low_ammo_label = Label.new()
	_low_ammo_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_low_ammo_label.position = Vector2(20, 110)
	_low_ammo_label.modulate = Color(1.0, 0.6, 0.15)
	_low_ammo_label.visible = false
	hud_layer.add_child(_low_ammo_label)

	# MVP6 Factory/dealer demand UI (item 10).
	_demand_panel = PanelContainer.new()
	_demand_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_demand_panel.position = Vector2(20, 150)
	_demand_panel.custom_minimum_size = Vector2(280, 110)
	hud_layer.add_child(_demand_panel)
	_demand_label = Label.new()
	_demand_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_demand_panel.add_child(_demand_label)

	# MVP6 Patrol efficiency overlay (item 11): Nabil-only, since only
	# Nabil's City Patrol has an income-efficiency mechanic to show.
	if current_faction.uses_armory_instead_of_gun_shop:
		_patrol_panel = PanelContainer.new()
		_patrol_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_patrol_panel.position = Vector2(20, 266)
		_patrol_panel.custom_minimum_size = Vector2(280, 90)
		hud_layer.add_child(_patrol_panel)
		_patrol_label = Label.new()
		_patrol_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_patrol_panel.add_child(_patrol_label)

	# MVP6 Diplomacy UI (item 12). The live open world only has one
	# active live faction (the player's) plus DEA Heat response and a
	# fixed non-faction hostile encounter — real multi-faction
	# trust/alliance diplomacy (scripts/diplomacy/diplomacy_controller.gd)
	# only has a second live faction to negotiate with inside
	# AiMatchArena (see docs/TECH_DECISIONS.md "MVP5 live-game AI
	# scope"). This panel honestly shows what *is* live right now
	# (Heat/DEA attention) rather than fabricating an alliance UI with
	# nothing behind it.
	_diplomacy_panel = PanelContainer.new()
	_diplomacy_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_diplomacy_panel.position = Vector2(-420, 300)
	_diplomacy_panel.custom_minimum_size = Vector2(400, 90)
	hud_layer.add_child(_diplomacy_panel)
	_diplomacy_label = Label.new()
	_diplomacy_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_diplomacy_panel.add_child(_diplomacy_label)

	# MVP6 camera alert (item 14): "Under Attack" banner with a Jump
	# button when a player unit off-screen takes damage.
	_camera_alert_panel = PanelContainer.new()
	_camera_alert_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_camera_alert_panel.position = Vector2(-140, 150)
	_camera_alert_panel.visible = false
	hud_layer.add_child(_camera_alert_panel)
	var alert_box := HBoxContainer.new()
	_camera_alert_panel.add_child(alert_box)
	_camera_alert_label = Label.new()
	_camera_alert_label.text = "Under Attack!"
	_camera_alert_label.modulate = Color(1.0, 0.3, 0.3)
	alert_box.add_child(_camera_alert_label)
	var jump_btn := Button.new()
	jump_btn.text = "Jump To"
	jump_btn.pressed.connect(_on_camera_alert_jump_pressed)
	alert_box.add_child(jump_btn)

	victory_defeat_screen.restart_requested.connect(_on_restart)
	victory_defeat_screen.load_requested.connect(func(): _on_load_slot(SaveService.most_recent_slot()))
	victory_defeat_screen.quit_to_menu_requested.connect(_on_quit_to_menu)

	# MVP6 contextual tutorial toast (item 4).
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tutorial_panel.position = Vector2(-260, -280)
	_tutorial_panel.custom_minimum_size = Vector2(520, 0)
	_tutorial_panel.visible = false
	hud_layer.add_child(_tutorial_panel)
	var tutorial_box := VBoxContainer.new()
	tutorial_box.add_theme_constant_override("separation", 6)
	_tutorial_panel.add_child(tutorial_box)
	_tutorial_title_label = Label.new()
	_tutorial_title_label.add_theme_font_size_override("font_size", 18)
	tutorial_box.add_child(_tutorial_title_label)
	_tutorial_body_label = Label.new()
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tutorial_body_label.custom_minimum_size = Vector2(500, 0)
	tutorial_box.add_child(_tutorial_body_label)
	var tutorial_dismiss_btn := Button.new()
	tutorial_dismiss_btn.text = "Got it"
	tutorial_dismiss_btn.pressed.connect(_on_tutorial_dismiss_pressed)
	tutorial_box.add_child(tutorial_dismiss_btn)
	_tutorial.hint_shown.connect(_on_tutorial_hint_shown)


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
	var mc := _make_unit(current_campaign.id, current_campaign.main_character_name, "MC", &"player", true)
	mc.position = player_hq_position + Vector2(-80, 40)
	mc.abilities = current_campaign.abilities
	mc.recruit_cost_multiplier = 0.8 if current_campaign.id == &"campaign_juan" else 1.0 # Juan's Master Manipulator: cheaper enemy-recruit conversion
	mc.equip_weapon("primary", economy.weapon_catalog["weapon_pistol"])
	mc.equip_weapon("secondary", economy.weapon_catalog["weapon_knife"])
	units_root.add_child(mc)
	selection_manager.register_unit(mc)

	# Prompt Dasar starting rosters: Juan/Zie/Andrés spawn with 3xB1;
	# Nabil (no B1 tier) spawns with 3xB2 instead.
	var starting_tier: String = "B1" if current_faction.has_b1 else "B2"
	var starting_positions: Array = FormationUtils.compute_positions(player_hq_position + Vector2(60, 40), 3, 40.0)
	for i in range(3):
		var u := _make_unit(&"start_%d" % (i + 1), starting_tier, starting_tier, &"player", true)
		u.position = starting_positions[i]
		units_root.add_child(u)
		selection_manager.register_unit(u)

	if current_campaign.starting_vehicle:
		var v = VEHICLE_SCENE.instantiate()
		v.vehicle_data = current_campaign.starting_vehicle
		v.faction_side = &"player"
		v.position = player_hq_position + Vector2(-160, 140)
		vehicles_root.add_child(v)

	var enemy_positions: Array = FormationUtils.compute_positions(player_hq_position + Vector2(520, -40), 4, 50.0)
	for i in range(4):
		var e := _make_unit(&"enemy_%d" % (i + 1), "Hostile (PLACEHOLDER)", "ENEMY", &"enemy_dummy", false)
		e.auto_defend = true
		e.is_recruitable_tier = true
		e.equip_weapon("primary", economy.weapon_catalog["weapon_assault_rifle"])
		e.primary_reserve = 999 # dummy encounters get abundant ammo; see docs/TECH_DECISIONS.md
		e.position = enemy_positions[i]
		enemies_root.add_child(e)
		e.died.connect(_on_enemy_died) # died(unit) already supplies e; see selection_manager.gd fix note


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
			u.unit_data = current_campaign.mc_unit
		"B1":
			u.unit_data = current_campaign.b1_unit
		"B2":
			u.unit_data = current_campaign.b2_unit
		"B3":
			u.unit_data = current_campaign.b3_unit
		"SPECIAL":
			pass # unit_data assigned by the caller (special_units are per-instance, not a single shared tier resource)
		_:
			u.max_hp = 90.0
			u.accuracy = 0.5
			u.move_speed_px = 190.0
	u.recruit_completed.connect(_on_recruit_completed)
	u.loot_dropped.connect(_on_loot_dropped)
	if side == &"player":
		u.hp_changed.connect(_on_player_unit_hp_changed)
		if tier == "MC":
			u.died.connect(_on_player_mc_died)
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
	_tutorial.request(&"recruitment")
	var u := _make_unit(&"recruit_%d" % Time.get_ticks_msec(), tier, tier, &"player", true)
	u.position = RECRUITMENT_POS + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	units_root.add_child(u)
	selection_manager.register_unit(u)
	if _combat_log:
		_combat_log.log_event("A new %s joined the roster." % tier)


## MVP4: Special unit unlock/recruit (Prompt Dasar: "Special unlock dan
## harga berfungsi", "Setiap special adalah unit unik, maksimal satu").
## Locked until the Main Character reaches level 4; each special can
## only be recruited once per campaign.
func can_recruit_special(index: int) -> bool:
	var mc = _get_main_character()
	if mc == null or mc.mc_level < 4:
		return false
	if index in _recruited_special_ids:
		return false
	if index < 0 or index >= current_campaign.special_units.size():
		return false
	if economy.recruited_count >= economy.max_roster:
		return false
	var data: UnitData = current_campaign.special_units[index]
	return economy.can_afford(data.recruit_price)


func try_recruit_special(index: int) -> bool:
	if not can_recruit_special(index):
		return false
	var data: UnitData = current_campaign.special_units[index]
	if not economy.spend(data.recruit_price):
		return false
	var u := _make_unit(&"special_%d" % index, "SPECIAL", "SPECIAL", &"player", true)
	u.unit_data = data
	u.max_hp = data.base_hp
	u.accuracy = data.base_accuracy
	u.move_speed_px = data.move_speed * 60.0
	u.hp = u.max_hp
	u.position = RECRUITMENT_POS + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	units_root.add_child(u)
	selection_manager.register_unit(u)
	special_unit_instances.append(u)
	u.special_index = index
	_recruited_special_ids.append(index)
	economy.recruited_count += 1
	if _combat_log:
		_combat_log.log_event("%s joined the roster (Special, unlocked at MC level 4)." % data.display_name)
	return true


func _get_main_character() -> BwUnit:
	for u in units_root.get_children():
		if u is BwUnit and is_instance_valid(u) and u.tier_label == "MC":
			return u
	return null


func _on_recruit_completed(recruiter: BwUnit, target: BwUnit) -> void:
	if not is_instance_valid(target) or target.faction_side == recruiter.faction_side:
		return
	if not current_faction.can_recruit_enemies:
		if _combat_log:
			_combat_log.log_event("Recruit failed: %s cannot recruit surrendered enemies." % current_faction.display_name)
		return
	if economy.recruited_count >= economy.max_roster:
		if _combat_log:
			_combat_log.log_event("Recruit failed: roster is full.")
		return
	var base_price_unit: UnitData = current_campaign.b1_unit if current_campaign.b1_unit else current_campaign.b2_unit
	var cost: int = int(base_price_unit.recruit_price / 2.0 * recruiter.recruit_cost_multiplier)
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
	enemies_eliminated_count += 1
	call_deferred("_refresh_enemy_units_cache")


func _refresh_enemy_units_cache() -> void:
	var list: Array = []
	for c in enemies_root.get_children():
		if c is BwUnit and is_instance_valid(c):
			list.append(c)
	command_controller.enemy_units = list


func _get_all_vehicles() -> Array:
	return vehicles_root.get_children().filter(func(v): return v is Vehicle and is_instance_valid(v))


func _get_hostile_units() -> Array:
	return enemies_root.get_children().filter(func(u): return u is BwUnit and is_instance_valid(u))


func _get_player_side_units() -> Array:
	return units_root.get_children().filter(func(u): return u is BwUnit and is_instance_valid(u))


## ---------------------------------------------------------------
## Building interaction (E key): factory pickup, dealer sell, bank
## deposit, garage repair/buy, recruitment/gun shop panel toggle.
## ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("bw_interact"):
		_handle_interact()
	# MVP5 debug overlay toggle (Prompt Dasar: "Debug overlay tidak
	# muncul pada release build"); the overlay's own _ready() already
	# frees itself in a release export, so this key simply does
	# nothing there since the node no longer exists. MVP6: rebindable
	# via bw_toggle_debug_overlay (default F3), same as every other
	# gameplay hotkey.
	if event.is_action_pressed("bw_toggle_debug_overlay") and is_instance_valid(_ai_debug_overlay):
		_ai_debug_overlay.visible = not _ai_debug_overlay.visible


func _handle_interact() -> void:
	var unit = _first_selected_unit()
	if unit == null or not is_instance_valid(unit) or unit.mounted_vehicle != null:
		return
	if unit in factory.get_units_in_range():
		factory.try_pickup(unit)
		_tutorial.request(&"factory_dealer_bank")
		return
	for d in dealers:
		if unit in d.get_units_in_range():
			d.start_sell(unit, economy, factory.cargo_value())
			_tutorial.request(&"factory_dealer_bank")
			return
	if unit in bank.get_units_in_range():
		bank.start_deposit(unit)
		_tutorial.request(&"factory_dealer_bank")
		return
	if recruitment_building.has_player_in_range():
		recruitment_building.toggle_panel()
		return
	if current_faction.uses_armory_instead_of_gun_shop:
		if armory_building.has_player_in_range():
			armory_building.toggle_panel()
			return
	elif gun_shop_building.has_player_in_range():
		gun_shop_building.toggle_panel()
		return
	if unit.global_position.distance_to(garage.global_position) <= 90.0:
		if not garage.try_repair():
			garage_panel.visible = not garage_panel.visible


func _on_dispatch_allies_pressed() -> void:
	if not economy.try_dispatch_allies():
		if _combat_log:
			_combat_log.log_event("Ally dispatch failed: insufficient budget or on cooldown.")
		return
	var spawn_pos: Vector2 = player_hq_position + Vector2(-400, 0)
	var dea_campaign: CampaignData = current_campaign
	for i in range(2):
		var u := _make_unit(&"ally_dispatch_%d_%d" % [Time.get_ticks_msec(), i], "Allied DEA Agent", "B2", &"player", true)
		u.position = spawn_pos + Vector2(i * 40, 0)
		u.equip_weapon("primary", economy.weapon_catalog["weapon_assault_rifle"])
		u.primary_reserve = 999
		u.auto_defend = true
		units_root.add_child(u)
		selection_manager.register_unit(u)
	if _combat_log:
		_combat_log.log_event("Dispatched 2 allied DEA agents to engage the nearest cartel threat.")


func _on_mc_upgrade_pressed() -> void:
	var mc := _get_main_character()
	if mc == null:
		return
	var cost: int = mc.mc_upgrade_cost()
	if cost < 0:
		if _combat_log:
			_combat_log.log_event("%s is already at max level." % mc.display_name)
		return
	if not economy.spend(cost):
		if _combat_log:
			_combat_log.log_event("Cannot afford MC upgrade ($%d needed)." % cost)
		return
	mc.mc_upgrade()


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
	if current_faction.uses_armory_instead_of_gun_shop:
		return # Nabil's own response is allied-AI dispatch, not hostile Heat — see _handle_interact/try_dispatch_allies.
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
	var dea_campaign: CampaignData = CampaignDatabase.get_campaign(&"campaign_nabil")
	var b2_count: int = 4 if wave_number == 1 else 0
	var b3_count: int = 1 if wave_number == 1 else 2
	for i in range(b2_count):
		var u := _make_unit(&"dea_b2_%d_%d" % [wave_number, i], "DEA Responder (PLACEHOLDER)", "B2", &"enemy_dea", false)
		u.unit_data = dea_campaign.b2_unit # always DEA's own stats, regardless of which campaign is currently playing
		u.auto_defend = true
		u.equip_weapon("primary", economy.weapon_catalog["weapon_assault_rifle"])
		u.primary_reserve = 999
		u.position = spawn_pos + Vector2(i * 30, 0)
		enemies_root.add_child(u)
	for i in range(b3_count):
		var u := _make_unit(&"dea_b3_%d_%d" % [wave_number, i], "DEA Commander (PLACEHOLDER)", "B3", &"enemy_dea", false)
		u.unit_data = dea_campaign.b3_unit
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
	if not units.is_empty():
		_tutorial.request(&"selection")


func _toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	get_tree().paused = pause_menu.visible


## ---------------------------------------------------------------
## MVP6 HUD warnings/overlays (payroll, low ammo, factory/dealer
## demand, patrol efficiency, diplomacy, camera alerts).
## ---------------------------------------------------------------
func _on_payroll_processed(paid: bool, total_due: int) -> void:
	if paid or not _payroll_warning_label:
		return
	_payroll_warning_label.text = "PAYROLL MISSED — $%d due. Morale is dropping across the roster." % total_due
	_payroll_warning_label.visible = true
	_payroll_warning_timer = 6.0


func _refresh_low_ammo_warning() -> void:
	if not _low_ammo_label:
		return
	var warnings: Array = []
	for u in selection_manager.selected:
		if not is_instance_valid(u) or u.primary_weapon == null or not u.primary_weapon.uses_ammo:
			continue
		var total: int = u.primary_mag + u.primary_reserve
		var max_total: int = u.primary_weapon.magazine_size + u.primary_weapon.reserve_ammo
		if total <= 0:
			warnings.append("%s: OUT OF AMMO" % u.display_name)
		elif max_total > 0 and float(total) / float(max_total) <= 0.25:
			warnings.append("%s: LOW AMMO" % u.display_name)
	if warnings.is_empty():
		_low_ammo_label.visible = false
	else:
		_low_ammo_label.text = "\n".join(warnings)
		_low_ammo_label.visible = true
		_tutorial.request(&"ammo")


func _refresh_demand_panel() -> void:
	if not _demand_label or factory == null:
		return
	var lines: Array = ["Factory (Lv %d): %d/%d cargo stored%s" % [
		factory.level, factory.stored_cargo, factory.MAX_STORED_CARGO,
		" [DESTROYED]" if factory.is_destroyed else "",
	]]
	for i in range(dealers.size()):
		var d = dealers[i]
		if not is_instance_valid(d):
			continue
		lines.append("%s demand: %d%%" % [d.dealer_label, int(d.current_demand_multiplier() * 100.0)])
	_demand_label.text = "\n".join(lines)


func _refresh_patrol_panel() -> void:
	if not _patrol_label:
		return
	var patrolling: Array = units_root.get_children().filter(func(u): return u is BwUnit and is_instance_valid(u) and u.state == BwUnit.State.PATROLLING)
	var snapshot: Array = economy.patrol_efficiency_snapshot(patrolling)
	if snapshot.is_empty():
		_patrol_label.text = "City Patrol: no units patrolling."
		return
	var lines: Array = ["City Patrol efficiency:"]
	for entry in snapshot:
		if entry["warmed_up"]:
			lines.append("%s: %d%%" % [entry["name"], int(entry["efficiency"] * 100.0)])
		else:
			lines.append("%s: warming up (%.0fs)" % [entry["name"], entry["idle_sec"]])
	_patrol_label.text = "\n".join(lines)


func _refresh_diplomacy_panel() -> void:
	if not _diplomacy_label:
		return
	_diplomacy_label.text = "DEA Heat response: wave %d/%d dispatched%s\nFull faction diplomacy (trust/alliance/betrayal) activates once rival factions are live in the open world." % [
		heat_manager.waves_dispatched, HEAT_MANAGER_SCRIPT.MAX_WAVES,
		" — in combat" if heat_manager.in_combat else "",
	]


func _on_player_unit_hp_changed(unit, ratio: float) -> void:
	var id: int = unit.get_instance_id()
	var prev: float = _last_hp_ratio.get(id, 1.0)
	_last_hp_ratio[id] = ratio
	if ratio >= prev or not is_instance_valid(unit):
		return
	if _is_on_screen(unit.global_position):
		return
	_camera_alert_target_pos = unit.global_position
	_camera_alert_timer = 6.0
	if _camera_alert_label:
		_camera_alert_label.text = "Under Attack: %s!" % unit.display_name
	if _camera_alert_panel:
		_camera_alert_panel.visible = true


func _is_on_screen(pos: Vector2) -> bool:
	var vp := get_viewport()
	if vp == null or camera == null:
		return true
	var half_size: Vector2 = (vp.get_visible_rect().size / maxf(camera.zoom.x, 0.01)) * 0.5
	var rect := Rect2(camera.global_position - half_size, half_size * 2.0)
	return rect.has_point(pos)


func _on_camera_alert_jump_pressed() -> void:
	camera.global_position = _camera_alert_target_pos
	_camera_alert_panel.visible = false
	_camera_alert_timer = 0.0


func _on_tutorial_hint_shown(_id: StringName, title: String, body: String) -> void:
	_tutorial_title_label.text = title
	_tutorial_body_label.text = body
	_tutorial_panel.visible = true


func _on_tutorial_dismiss_pressed() -> void:
	_tutorial_panel.visible = false
	_tutorial.dismiss_current()


## ---------------------------------------------------------------
## MVP6 victory/defeat + campaign summary.
## ---------------------------------------------------------------
func _on_player_mc_died(_unit = null) -> void:
	if _mission_over:
		return
	_mission_over = true
	victory_defeat_screen.show_result(false, "%s was eliminated. The campaign is lost." % current_campaign.main_character_name, _build_campaign_summary_text())


## Generic rule match (Prompt Dasar "VICTORY DAN DEFEAT"): cartels win
## when every enemy Main Character is eliminated; Nabil additionally
## requires no active cartel factory left standing. `_enemy_mc_registry`
## is never populated by this live map yet (rival faction HQs are
## still non-functional placeholders — see
## docs/PLACEHOLDER_REGISTER.md), so this structurally cannot fire
## here today; it is implemented and covered by
## tests/test_mvp6_victory_defeat.gd against a fake registry so the
## condition is correct and ready the moment rival MCs go live.
func _check_victory_condition() -> void:
	if _mission_over or _enemy_mc_registry.is_empty():
		return
	var all_enemy_mc_dead: bool = true
	for mc in _enemy_mc_registry:
		if is_instance_valid(mc) and mc.state != BwUnit.State.DEAD:
			all_enemy_mc_dead = false
			break
	if not all_enemy_mc_dead:
		return
	if current_faction.uses_armory_instead_of_gun_shop:
		if is_instance_valid(factory) and not factory.is_destroyed:
			return # Nabil additionally needs every cartel factory shut down
	_mission_over = true
	victory_defeat_screen.show_result(true, "All rival Main Characters have been eliminated.", _build_campaign_summary_text())


func _build_campaign_summary_text() -> String:
	var minutes: int = int(elapsed_play_sec) / 60
	var seconds: int = int(elapsed_play_sec) % 60
	return "Campaign: %s (%s)\nPlay time: %d:%02d\nMoney earned: $%d\nFinal balance: $%d\nRoster recruited: %d/%d + MC\nEnemies eliminated: %d" % [
		current_campaign.menu_name, current_campaign.main_character_name,
		minutes, seconds, economy.lifetime_money_earned, economy.money,
		economy.recruited_count, economy.max_roster, enemies_eliminated_count,
	]


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
		"parts": economy.parts,
		"elapsed_play_sec": elapsed_play_sec,
		"enemies_eliminated_count": enemies_eliminated_count,
		"lifetime_money_earned": economy.lifetime_money_earned,
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
		"mc_level": u.mc_level, "special_index": u.special_index,
	}


func _on_save_load_requested() -> void:
	_save_slot_panel.refresh()
	_save_slot_panel.visible = not _save_slot_panel.visible
	if _save_slot_panel.visible:
		_settings_panel.visible = false


func _on_settings_requested() -> void:
	_settings_panel.visible = not _settings_panel.visible
	if _settings_panel.visible:
		_save_slot_panel.visible = false


func _on_save_to_slot(slot: int) -> void:
	SaveService.save_game(slot, _gather_save_data())
	_save_slot_panel.refresh()


func _on_load_slot(slot: int) -> void:
	get_tree().paused = false
	GameState.pending_load_slot = slot
	get_tree().reload_current_scene()


func _run_autosave() -> void:
	SaveService.save_game(SaveService.AUTOSAVE_SLOT, _gather_save_data())


func _apply_save_data(data: Dictionary) -> void:
	if data.has("campaign_id"):
		GameState.current_campaign_id = StringName(String(data["campaign_id"]))
	if data.has("difficulty_id"):
		GameState.current_difficulty_id = StringName(String(data["difficulty_id"]))
	economy.set_money(int(data.get("money", 4000)))
	# set_money()'s own lifetime_money_earned bump treats any increase
	# as "earned"; override with the save's own true lifetime total so
	# loading a save doesn't inflate the campaign-summary stat.
	economy.lifetime_money_earned = int(data.get("lifetime_money_earned", 0))
	economy.recruited_count = int(data.get("recruited_count", 0))
	economy.parts = int(data.get("parts", 0))
	elapsed_play_sec = float(data.get("elapsed_play_sec", 0.0))
	enemies_eliminated_count = int(data.get("enemies_eliminated_count", 0))
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
		var loaded_special_index: int = int(ud.get("special_index", -1))
		if loaded_special_index >= 0:
			u.special_index = loaded_special_index
			u.unit_data = current_campaign.special_units[loaded_special_index]
			special_unit_instances.append(u)
			_recruited_special_ids.append(loaded_special_index)
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
			u.died.connect(_on_enemy_died) # died(unit) already supplies u; see selection_manager.gd fix note
		var saved_state: int = int(ud.get("state", BwUnit.State.IDLE))
		var saved_hp: float = float(ud.get("hp", u.max_hp))
		var loaded_mc_level: int = int(ud.get("mc_level", 1))
		if loaded_mc_level > 1:
			u.mc_level = loaded_mc_level
			u.call_deferred("_apply_mc_level_bonuses")
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


## ---------------------------------------------------------------
## MVP6 victory/defeat test-only hooks (mirrors gather_save_data_for_test's
## existing precedent for a narrow, clearly-named test seam).
## ---------------------------------------------------------------
func register_enemy_mc_for_test(mc: BwUnit) -> void:
	_enemy_mc_registry.append(mc)


func force_check_victory_for_test() -> void:
	_check_victory_condition()


func is_mission_over_for_test() -> bool:
	return _mission_over
