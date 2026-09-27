class_name WeaponData
extends Resource
## Typed schema for a weapon (Prompt Dasar "SENJATA, INVENTORY, DAN
## AMUNISI"). MVP 0 defines the schema only; see docs/BALANCE.md for the
## reference numbers to populate in a later MVP.

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
