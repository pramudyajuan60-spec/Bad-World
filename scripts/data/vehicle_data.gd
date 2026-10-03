class_name VehicleData
extends Resource
## Typed schema for a drivable vehicle (Prompt Dasar "KENDARAAN").
## MVP 3 populates combat/movement stats.

enum VehicleClass { COMPACT, ARMORED_SUV, GUN_TRUCK, APC }

@export var id: StringName = &""
@export var display_name: String = ""
@export var vehicle_class: VehicleClass = VehicleClass.COMPACT
@export var price: int = 0
@export var seat_capacity: int = 0
@export var has_turret: bool = false
## Accuracy penalty in points applied to turret fire while the vehicle moves.
@export var moving_accuracy_penalty: float = 0.0
# --- MVP 3 stats ---
@export var max_hp: float = 300.0
@export var move_speed: float = 220.0
@export var cargo_capacity: int = 12
@export var turret_damage: float = 18.0
@export var turret_range: float = 300.0
@export var turret_rof: float = 2.0  # shots per second
