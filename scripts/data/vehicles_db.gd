class_name VehiclesDB
extends RefCounted
## MVP 3 vehicle database. Prices from docs/BALANCE.md.

static func _make(id: String, name: String, vc: int, price: int, hp: float,
		speed: float, seats: int, cargo: int, turret: bool) -> VehicleData:
	var v := VehicleData.new()
	v.id = StringName(id)
	v.display_name = name
	v.vehicle_class = vc
	v.price = price
	v.max_hp = hp
	v.move_speed = speed
	v.seat_capacity = seats
	v.cargo_capacity = cargo
	v.has_turret = turret
	v.moving_accuracy_penalty = 0.20 if turret else 0.0
	return v

static func all() -> Dictionary:
	var VC := VehicleData.VehicleClass
	return {
		&"utility": _make("utility", "Utility Vehicle", VC.COMPACT,
			1200, 300.0, 240.0, 4, 12, false),
		&"suv": _make("suv", "Armored SUV", VC.ARMORED_SUV,
			2500, 500.0, 220.0, 4, 8, false),
		&"guntruck": _make("guntruck", "Gun Truck", VC.GUN_TRUCK,
			4500, 600.0, 200.0, 6, 10, true),
		&"apc": _make("apc", "APC", VC.APC,
			7000, 900.0, 180.0, 8, 16, true),
	}

static func get_vehicle(id: StringName) -> VehicleData:
	return all().get(id, null)
