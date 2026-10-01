extends SceneTree
## MVP7 acceptance criterion ("Targetkan 60 FPS dengan seluruh faction
## aktif dan unit mendekati batas"). Extends MVP3's
## profile_navigation_and_vehicles.gd (single-faction, idle navigation)
## to the worst-case scenario this release actually ships: 4 factions
## simultaneously active (the player's own near-cap roster + the 3
## real rival-faction encounters MVP7 now spawns in the open world —
## see docs/PLACEHOLDER_REGISTER.md "Rival faction HQs"), all engaged
## in combat at once (not just idle pathing), measured in real
## wall-clock time (deliberately NOT run with --fixed-fps, which would
## defeat the purpose of an FPS measurement).
##
## Run: godot4 --headless --path . --script res://tools/profile_near_cap_multi_faction.gd
## Captured results + interpretation: docs/BALANCE.md "MVP7 performance".

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const VEHICLE_SCENE := preload("res://scenes/gameplay/Vehicle.tscn")
const PISTOL := preload("res://data/weapons/pistol.tres")
const RIFLE := preload("res://data/weapons/assault_rifle.tres")

var _world: Node2D
var _all_units: Array = []


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	var nav_region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.add_outline(PackedVector2Array([
		Vector2(-4000, -3000), Vector2(4000, -3000), Vector2(4000, 3000), Vector2(-4000, 3000),
	]))
	poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = poly
	_world.add_child(nav_region)
	call_deferred("_run")


func _spawn_faction(side: StringName, count: int, center: Vector2) -> Array:
	var units: Array = []
	for i in range(count):
		var u: BwUnit = UNIT_SCENE.instantiate()
		u.unit_id = StringName("%s_%d" % [side, i])
		u.tier_label = "B1"
		u.faction_side = side
		u.position = center + Vector2(randf_range(-300, 300), randf_range(-300, 300))
		u.equip_weapon("primary", RIFLE if i % 3 == 0 else PISTOL)
		u.primary_reserve = 999
		_world.add_child(u)
		units.append(u)
	return units


func _run() -> void:
	# Player's own roster cap (30 + MC, per Prompt Dasar "BATAS UNIT")
	# plus 3 rival-faction encounters (1 MC + 2 guards each, per
	# _spawn_rival_factions()) — matches the actual live open-world
	# worst case this release ships, not an idealized single-faction one.
	var player_units: Array = _spawn_faction(&"player", 31, Vector2(-2600, -1800))
	var rival_a: Array = _spawn_faction(&"enemy_a", 3, Vector2(2600, -1800))
	var rival_b: Array = _spawn_faction(&"enemy_b", 3, Vector2(-2600, 1800))
	var rival_c: Array = _spawn_faction(&"enemy_c", 3, Vector2(2600, 1800))
	_all_units = player_units + rival_a + rival_b + rival_c

	var vehicles: Array = []
	for i in range(4):
		var v: Vehicle = VEHICLE_SCENE.instantiate()
		v.faction_side = &"player"
		v.position = Vector2(randf_range(-2800, -2200), randf_range(-2000, -1600))
		_world.add_child(v)
		vehicles.append(v)

	await physics_frame
	await physics_frame

	# Combat, not idle pathing: each rival squad attack-moves straight
	# at the player cluster (worst case for target-acquisition +
	# line-of-sight raycasts + suppression/cover checks every frame,
	# not just nav-agent pathing).
	for u in rival_a + rival_b + rival_c:
		u.order_attack_move(Vector2(-2600, -1800) + Vector2(randf_range(-100, 100), randf_range(-100, 100)))
	for u in player_units:
		u.order_move(Vector2(-2600, -1800) + Vector2(randf_range(-400, 400), randf_range(-400, 400)))
	for v in vehicles:
		v.driver = "profiling_stub"
		v.order_move(Vector2(-2500, -1700))

	var frame_times: Array[float] = []
	var frame_count := 600 # 10s at 60Hz real wall-clock time
	for i in range(frame_count):
		var t0 := Time.get_ticks_usec()
		await physics_frame
		var t1 := Time.get_ticks_usec()
		frame_times.append((t1 - t0) / 1000.0) # ms

	frame_times.sort()
	var total := 0.0
	for t in frame_times:
		total += t
	var avg: float = total / frame_times.size()
	var p95: float = frame_times[int(frame_times.size() * 0.95)]
	var worst: float = frame_times[-1]
	var alive_count: int = _all_units.filter(func(u): return is_instance_valid(u) and u.state != BwUnit.State.DEAD).size()

	print("=== MVP7 near-cap multi-faction combat profiling ===")
	print("Factions active: 4 (player + 3 rivals). Total units spawned: %d (player roster cap 31 + 3x3 rival encounters). Vehicles: %d." % [_all_units.size(), vehicles.size()])
	print("Units still alive after 10s of real combat: %d" % alive_count)
	print("Frames measured: %d (real wall-clock, no --fixed-fps)" % frame_count)
	print("Avg physics-frame wall time: %.3f ms (%.1f effective FPS budget)" % [avg, 1000.0 / max(avg, 0.001)])
	print("P95 physics-frame wall time: %.3f ms" % p95)
	print("Worst physics-frame wall time: %.3f ms" % worst)
	print("Godot's own physics tick target: %.3f ms (60Hz)" % (1000.0 / 60.0))
	print("Orphan node count (Performance monitor): %d" % Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	quit(0)
