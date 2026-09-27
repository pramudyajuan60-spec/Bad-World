extends SceneTree
## Ad hoc profiling script for MVP3's closing instruction ("Profiling
## navigation dan kendaraan, laporkan hasil"). Not part of the
## permanent automated test suite (tests/) since it measures wall-clock
## performance rather than asserting correctness; kept under tools/ for
## repeatability if a later MVP wants to re-check after adding more
## systems. Run with:
##   godot4 --headless --path . --script res://tools/profile_navigation_and_vehicles.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const VEHICLE_SCENE := preload("res://scenes/gameplay/Vehicle.tscn")

var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	var nav_region := NavigationRegion2D.new()
	var poly := NavigationPolygon.new()
	poly.add_outline(PackedVector2Array([
		Vector2(-3000, -3000), Vector2(3000, -3000), Vector2(3000, 3000), Vector2(-3000, 3000),
	]))
	poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = poly
	_world.add_child(nav_region)
	call_deferred("_run")


func _run() -> void:
	# 31 units = Juan's own-side roster cap (30 + MC), the largest count
	# this campaign's rules allow on one side at once.
	var units: Array = []
	for i in range(31):
		var u: BwUnit = UNIT_SCENE.instantiate()
		u.tier_label = "B1"
		u.faction_side = &"player"
		u.position = Vector2(randf_range(-1500, -200), randf_range(-1500, 1500))
		_world.add_child(u)
		units.append(u)

	var vehicles: Array = []
	for i in range(4): # one of each class, a reasonable concurrent count
		var v: Vehicle = VEHICLE_SCENE.instantiate()
		v.faction_side = &"player"
		v.position = Vector2(randf_range(-1500, -200), randf_range(-1500, 1500))
		_world.add_child(v)
		vehicles.append(v)

	await physics_frame # let the navigation map register before issuing orders

	for u in units:
		u.order_move(Vector2(randf_range(200, 1500), randf_range(-1500, 1500)))
	for v in vehicles:
		v.driver = "profiling_stub" # bypass the seat requirement just for this profiling run
		v.order_move(Vector2(randf_range(200, 1500), randf_range(-1500, 1500)))

	var frame_times: Array[float] = []
	var frame_count := 300 # 5s at 60Hz
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

	print("=== Navigation + Vehicle Profiling Report ===")
	print("Units: %d (navigating), Vehicles: %d (navigating)" % [units.size(), vehicles.size()])
	print("Frames measured: %d" % frame_count)
	print("Avg physics-frame wall time: %.3f ms (%.1f effective FPS budget)" % [avg, 1000.0 / max(avg, 0.001)])
	print("P95 physics-frame wall time: %.3f ms" % p95)
	print("Worst physics-frame wall time: %.3f ms" % worst)
	print("Godot's own physics tick target: %.3f ms (60Hz)" % (1000.0 / 60.0))
	quit(0)
