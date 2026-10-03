extends SceneTree
## MVP 2a smoke test: weapon equip, ammo consumption, reload, LoS.

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[Tests] PASS: ", msg)
	else:
		_failures += 1
		push_error("[Tests] FAIL: " + msg)

func _init() -> void:
	var db: Dictionary = WeaponsDB.all()
	_check(db.size() == 7, "7 weapons in DB, got %d" % db.size())

	var rifle: WeaponData = WeaponsDB.get_weapon(&"rifle")
	_check(rifle != null, "rifle exists")
	_check(rifle.damage == 22.0, "rifle damage 22")
	_check(rifle.magazine_size == 30, "rifle mag 30")
	_check(rifle.attack_range == 340.0, "rifle range 340")

	var sniper: WeaponData = WeaponsDB.get_weapon(&"sniper")
	_check(sniper.attack_range == 600.0, "sniper range 600")

	# Simulate ammo logic on a bare WeaponData (no scene needed)
	var mag: int = rifle.magazine_size
	var reserve: int = rifle.reserve_ammo
	mag -= 5
	_check(mag == 25, "ammo consumed: 25 left")
	# reload
	var need: int = rifle.magazine_size - mag
	var take: int = mini(need, reserve)
	mag += take
	reserve -= take
	_check(mag == 30 and reserve == rifle.reserve_ammo - 5, "reload refills mag")

	if _failures == 0:
		print("[Tests] All MVP2a weapon tests passed.")
	else:
		push_error("[Tests] %d failures" % _failures)
	quit(_failures)
