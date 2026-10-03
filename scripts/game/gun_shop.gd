class_name GunShop
extends StaticBody2D
## MVP 2e: Gun shop building. Sells weapons, ammo, grenades, armor.
## Purchases are made via hotkeys with units selected (shop must exist).

const GRENADE_PRICE := 120
const VEST_PRICE := 600

# hotkey shift+number -> weapon id
const WEAPON_KEYS := {
	KEY_1: &"pistol",
	KEY_2: &"smg",
	KEY_3: &"shotgun",
	KEY_4: &"rifle",
	KEY_5: &"sniper",
	KEY_6: &"lmg",
}

func _ready() -> void:
	add_to_group("gun_shop")


static func buy_weapon(game: Node, unit: RTSUnit, weapon_id: StringName) -> bool:
	var w := WeaponsDB.get_weapon(weapon_id)
	if w == null:
		return false
	if game.money < w.price:
		return false
	game.money -= w.price
	unit.equip_weapon(weapon_id)
	return true


static func buy_ammo(game: Node, unit: RTSUnit) -> bool:
	if unit.weapon == null:
		return false
	var cost: int = unit.weapon.ammo_price
	if cost <= 0 or game.money < cost:
		return false
	game.money -= cost
	unit.reserve_ammo += unit.weapon.magazine_size * 2
	return true


static func buy_grenade(game: Node, unit: RTSUnit) -> bool:
	if game.money < GRENADE_PRICE:
		return false
	game.money -= GRENADE_PRICE
	unit.grenades += 1
	return true


static func buy_vest(game: Node, unit: RTSUnit) -> bool:
	if unit.has_armor or game.money < VEST_PRICE:
		return false
	game.money -= VEST_PRICE
	unit.has_armor = true
	return true
