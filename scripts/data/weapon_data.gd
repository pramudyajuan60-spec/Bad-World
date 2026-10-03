class_name WeaponData
extends Resource
## Typed schema for a weapon (Prompt Dasar "SENJATA, INVENTORY, DAN
## AMUNISI"). MVP 2 populates combat stats; see docs/BALANCE.md for
## reference prices.

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
# --- MVP 2 combat stats ---
@export var damage: float = 10.0
@export var attack_range: float = 250.0
@export var accuracy: float = 0.65  # base hit chance 0..1
@export var rate_of_fire: float = 2.0  # shots per second
@export var reload_time: float = 2.0  # seconds
@export var projectile_speed: float = 0.0  # 0 = hitscan, >0 = projectile px/s
@export var pellets: int = 1  # shotgun-style multi-pellet
@export var ammo_price: int = 0  # cost per full magazine refill
