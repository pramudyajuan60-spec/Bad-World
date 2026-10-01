extends SceneTree
## Headless tests for MVP7 "Release Candidate Validation" checklist
## items that weren't already exercised by an earlier MVP's own test
## suite: the safe-zone-exploit fix (item 13), out-of-ammo behavior
## (item 10), and a basic orphan-node/instance-count stability check
## across repeated spawn/death cycles (item 18). Run with:
##   godot4 --headless --path . --script res://tests/test_mvp7_release_validation.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const ECONOMY_SCRIPT := preload("res://scripts/economy/campaign_economy.gd")
const PISTOL := preload("res://data/weapons/pistol.tres")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_economy() -> Node:
	var e := Node.new()
	e.set_script(ECONOMY_SCRIPT)
	_world.add_child(e)
	return e


func _make_unit(id: String, side: StringName, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.tier_label = "B1"
	u.faction_side = side
	u.max_hp = 100.0
	u.move_speed_px = 0.0
	u.position = pos
	_world.add_child(u)
	return u


func _run() -> void:
	await _test_safe_zone_exploit_attacker_side_is_blocked()
	await _test_out_of_ammo_stops_firing_until_reload()
	await _test_no_orphan_nodes_after_spawn_and_death_cycles()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp7_release_validation: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


## MVP7 bugfix under test (see docs/TECH_DECISIONS.md "Safe zone
## exploit"): a unit standing INSIDE a safe zone must not be able to
## deal damage out, execute, recruit/capture, or throw a grenade
## (Prompt Dasar "Di dalam safe zone: ... Senjata diturunkan"), not
## just be protected from incoming damage (which was already correct).
func _test_safe_zone_exploit_attacker_side_is_blocked() -> void:
	var economy := _make_economy()
	economy.safe_zone_points = [Vector2.ZERO]

	var attacker := _make_unit("exploit_attacker", &"player", Vector2(5, 0)) # inside the 18m/360px radius
	attacker.economy = economy
	attacker.equip_weapon("primary", PISTOL)
	var victim := _make_unit("exploit_victim", &"enemy_dummy", Vector2(50, 0)) # outside the zone, in range
	victim.economy = null # the victim itself isn't in any safe zone

	attacker.order_attack(victim)
	for i in range(240): # plenty of time for several fire_interval_sec() cycles at this weapon's RPM
		await physics_frame
	_expect(victim.hp >= victim.max_hp - 0.01, "a unit standing inside a safe zone must not be able to deal damage out ('weapons lowered'), victim hp=%.1f" % victim.hp)

	# Grenade: caster inside the zone must not be able to throw at all.
	attacker.grenade_weapon = PISTOL # reuse any WeaponData just to pass the null-check; range_px/magazine_size below
	attacker.grenade_count = 3
	attacker.order_use_grenade(Vector2(200, 0))
	_expect(attacker.grenade_count == 3, "a unit standing inside a safe zone must not be able to throw a grenade, grenade_count=%d" % attacker.grenade_count)

	attacker.queue_free()
	victim.queue_free()
	await process_frame


## Prompt Dasar "SENJATA, INVENTORY, DAN AMUNISI": a unit that empties
## its magazine and has zero reserve ammo must stop dealing damage
## (not keep firing for free) and must not recover ammo from nowhere.
func _test_out_of_ammo_stops_firing_until_reload() -> void:
	var attacker := _make_unit("ammo_attacker", &"player", Vector2(0, 0))
	attacker.equip_weapon("primary", PISTOL)
	attacker.accuracy = 1.0 # deterministic hit — this test is about ammo depletion, not the accuracy roll
	attacker.primary_mag = 1
	attacker.primary_reserve = 0 # exactly one shot left, nothing to reload from
	var victim := _make_unit("ammo_victim", &"enemy_dummy", Vector2(50, 0))

	attacker.order_attack(victim)
	var hp_after_first_shots: float = victim.max_hp
	for i in range(600): # 10s at 60fps: comfortably enough for the one shot to land
		await physics_frame
		if victim.hp < victim.max_hp and hp_after_first_shots == victim.max_hp:
			hp_after_first_shots = victim.hp
	_expect(victim.hp < victim.max_hp, "the single loaded round should land at least one hit")
	_expect(attacker.primary_mag == 0, "magazine should be empty after firing its only round, got %d" % attacker.primary_mag)
	var hp_after_depletion: float = victim.hp
	for i in range(600): # another 10s: should deal zero further damage (no ammo, nothing to reload)
		await physics_frame
	_expect(not attacker.is_reloading, "a unit with zero reserve ammo should not enter a reload loop it can never finish")
	_expect(victim.hp == hp_after_depletion, "an out-of-ammo unit must deal no further damage (hp was %.1f, now %.1f)" % [hp_after_depletion, victim.hp])

	attacker.queue_free()
	victim.queue_free()
	await process_frame


## MVP7 item 18 ("Periksa memory leak, orphan node"): spawning and
## killing 50 units in a row should leave the scene tree with the same
## node count it started with (plus the economy/world node itself),
## not an ever-growing pile of nodes that failed to free.
func _test_no_orphan_nodes_after_spawn_and_death_cycles() -> void:
	var spawner_world := Node2D.new()
	root.add_child(spawner_world)
	var baseline: int = spawner_world.get_child_count()

	for i in range(50):
		var u: BwUnit = UNIT_SCENE.instantiate()
		u.unit_id = StringName("orphan_check_%d" % i)
		u.tier_label = "B1"
		u.faction_side = &"player"
		u.max_hp = 10.0
		u.move_speed_px = 0.0
		spawner_world.add_child(u)
		u.set_hp(0.0) # -> _enter_downed()
		u.downed_timer = 0.0

	# _die() is only reached via the DOWNED timer counting down in
	# _physics_process, or by calling it directly as other MVP tests
	# already do (e.g. test_mvp6_victory_defeat.gd); call it directly
	# here since this test only cares about node cleanup, not combat
	# timing.
	for c in spawner_world.get_children():
		if c is BwUnit:
			c._die()

	await process_frame
	await process_frame
	await process_frame

	_expect(spawner_world.get_child_count() == baseline, "all 50 spawned-then-killed units should be gone from the tree after _die()+a few frames, got %d remaining (baseline %d)" % [spawner_world.get_child_count(), baseline])
	spawner_world.queue_free()
	await process_frame
