class_name WeaponsDB
extends RefCounted
## Weapon database for MVP 2. Stats tuned for the game's scale
## (unit radius ~16px, typical engagement 150-400px).
## Prices from docs/BALANCE.md "Weapons (Gun Shop prices)".

static func _make(id: String, name: String, cat: int, price: int, parts: int,
		mag: int, dmg: float, rng: float, acc: float, rof: float,
		reload: float, pellets: int = 1, ammo_price: int = 0) -> WeaponData:
	var w := WeaponData.new()
	w.id = StringName(id)
	w.display_name = name
	w.category = cat
	w.price = price
	w.parts_cost = parts
	w.magazine_size = mag
	w.reserve_ammo = mag * 3
	w.damage = dmg
	w.attack_range = rng
	w.accuracy = acc
	w.rate_of_fire = rof
	w.reload_time = reload
	w.pellets = pellets
	w.ammo_price = ammo_price
	return w

static func all() -> Dictionary:
	var C := WeaponData.Category
	return {
		&"pistol": _make("pistol", "Pistol", C.PISTOL, 250, 40, 12, 15.0, 260.0, 0.65, 1.5, 1.5, 1, 30),
		&"smg": _make("smg", "SMG", C.SMG, 500, 70, 30, 14.0, 220.0, 0.60, 5.0, 2.0, 1, 50),
		&"shotgun": _make("shotgun", "Shotgun", C.SHOTGUN, 650, 90, 8, 8.0, 160.0, 0.60, 1.0, 2.5, 6, 60),
		&"rifle": _make("rifle", "Assault Rifle", C.RIFLE, 800, 110, 30, 22.0, 340.0, 0.70, 3.0, 2.2, 1, 70),
		&"sniper": _make("sniper", "Sniper Rifle", C.SNIPER, 1200, 180, 5, 80.0, 600.0, 0.85, 0.5, 3.0, 1, 100),
		&"lmg": _make("lmg", "LMG", C.LMG, 1600, 220, 60, 18.0, 320.0, 0.55, 6.0, 4.0, 1, 120),
		&"knife": _make("knife", "Knife", C.MELEE, 90, 0, 0, 25.0, 48.0, 0.90, 1.2, 0.0, 1, 0),
	}

static func get_weapon(id: StringName) -> WeaponData:
	return all().get(id, null)
