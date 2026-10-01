class_name WeaponData
extends Resource
## Typed schema for a weapon (Prompt Dasar "SENJATA, INVENTORY, DAN
## AMUNISI"). MVP 0 defines the schema only; see docs/BALANCE.md for the
## reference numbers to populate in a later MVP.
##
## MVP 2 populates real instances (data/weapons/*.tres) and adds the
## fields needed for full combat: rate of fire, reload, range,
## hitscan-vs-projectile, and explosive/armor behavior. Prompt Dasar's
## BALANCE V0.1 only specifies price/magazine/reserve per weapon; the
## rest (rpm, reload time, range, damage) are MVP2 game-design values
## chosen and documented per rule 11 — see docs/BALANCE.md "MVP 2
## weapon combat numbers".

enum Category { MELEE, PISTOL, SMG, SHOTGUN, RIFLE, SNIPER, LMG, LAUNCHER, GRENADE, ARMOR }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.PISTOL
@export var price: int = 0
## Nabil crafts weapons from Parts instead of buying them; 0 for factions
## that only use `price`.
@export var parts_cost: int = 0
@export var magazine_size: int = 0
@export var reserve_ammo: int = 0

## Base damage dealt per successful hit (before accuracy roll / cover /
## armor reduction). For explosive weapons this is the damage at the
## center of the blast.
@export var damage: float = 0.0
## Rounds per minute; fire_interval_sec() derives the per-shot cooldown.
## 0 for non-firing items (e.g. ARMOR).
@export var rate_of_fire_rpm: float = 0.0
@export var reload_time_sec: float = 0.0
@export var range_px: float = 200.0
## true = instant hit at fire time (pistols/rifles/etc). false = a travel
## delay before the effect applies (grenades/launchers) — see
## docs/TECH_DECISIONS.md "Projectile weapons are a timed delay, not a
## simulated flight" for why this is a delay rather than a moving node.
@export var is_hitscan: bool = true
@export var projectile_speed_px: float = 0.0
@export var is_melee: bool = false
@export var uses_ammo: bool = true
@export var is_explosive: bool = false
@export var blast_radius_px: float = 0.0
## ARMOR-category only: flat fraction (0..1) of incoming damage negated.
@export var armor_damage_reduction: float = 0.0


func fire_interval_sec() -> float:
	if rate_of_fire_rpm <= 0.0:
		return 1.0
	return 60.0 / rate_of_fire_rpm
