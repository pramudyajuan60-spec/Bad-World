class_name VehicleData
extends Resource
## Typed schema for a drivable vehicle (Prompt Dasar "KENDARAAN"). MVP 0
## defines the schema only.

enum VehicleClass { COMPACT, ARMORED_SUV, GUN_TRUCK, APC }

@export var id: StringName = &""
@export var display_name: String = ""
@export var vehicle_class: VehicleClass = VehicleClass.COMPACT
@export var price: int = 0
@export var seat_capacity: int = 0
@export var has_turret: bool = false
## Accuracy penalty in points applied to turret fire while the vehicle moves.
@export var moving_accuracy_penalty: float = 0.0
