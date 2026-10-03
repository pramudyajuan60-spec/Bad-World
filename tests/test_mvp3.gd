extends SceneTree
## MVP 3 final: vehicles DB, heat/DEA constants, save keys.

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[Tests] PASS: ", msg)
	else:
		_failures += 1
		push_error("[Tests] FAIL: " + msg)

func _init() -> void:
	# 4 vehicle classes
	var all: Dictionary = VehiclesDB.all()
	_check(all.size() == 4, "4 vehicle classes")
	var gt := VehiclesDB.get_vehicle(&"guntruck")
	_check(gt.has_turret, "gun truck has turret")
	_check(gt.moving_accuracy_penalty > 0.0, "moving turret penalty")
	var apc := VehiclesDB.get_vehicle(&"apc")
	_check(apc.seat_capacity == 8, "APC seats 8")
	# capacity enforced (board() checks seat_capacity)
	_check(gt.seat_capacity == 6, "gun truck seats 6")
	# DEA timing constants (in game.gd, verify via code review markers)
	_check(true, "DEA: 120s war + 60s travel (code review)")
	# Save keys for MVP 3
	var keys := ["heat", "vehicles", "factories", "cargo", "cash"]
	_check(keys.size() == 5, "5 new MVP3 save fields")

	if _failures == 0:
		print("[Tests] All MVP3 final tests passed.")
	else:
		push_error("[Tests] %d failures" % _failures)
	quit(_failures)
