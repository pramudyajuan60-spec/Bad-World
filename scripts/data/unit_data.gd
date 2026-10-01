class_name UnitData
extends Resource
## Typed schema for a recruitable/spawned unit type (B1/B2/B3/Special/MC).
## MVP 0 defines the schema only; populated balance tables land in MVP 1+
## per docs/BALANCE.md.

enum Tier { B1, B2, B3, SPECIAL, MAIN_CHARACTER }

@export var id: StringName = &""
@export var display_name: String = ""
@export var tier: Tier = Tier.B1
@export var faction: FactionData
@export var base_hp: int = 0
@export var base_armor: int = 0
@export var base_accuracy: float = 0.0
@export var move_speed: float = 0.0
@export var recruit_price: int = 0
@export var salary: int = 0
@export_file("*.png", "*.jpg", "*.jpeg") var portrait_path: String = ""
