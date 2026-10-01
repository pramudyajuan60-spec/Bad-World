extends SceneTree
## Headless tests for the MVP3 economy loop (Prompt Dasar acceptance
## criterion: "Satu loop lengkap dapat dimainkan: pabrik -> cargo ->
## dealer -> carried cash -> Bank -> pembelian"). Drives real Factory/
## DrugDealer/BankBuilding/CampaignEconomy/BwUnit instances directly
## (not the full OpenWorldMap scene) for fast, focused verification.
## Run with:
##   godot4 --headless --path . --script res://tests/test_mvp3_economy_loop.gd

const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")
const FACTORY_SCRIPT := preload("res://scripts/economy/factory.gd")
const DEALER_SCRIPT := preload("res://scripts/economy/drug_dealer.gd")
const BANK_SCRIPT := preload("res://scripts/economy/bank_building.gd")
const ECONOMY_SCRIPT := preload("res://scripts/economy/campaign_economy.gd")

var _failures: Array[String] = []
var _world: Node2D


func _initialize() -> void:
	_world = Node2D.new()
	root.add_child(_world)
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _make_unit(id: String, pos: Vector2) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.unit_id = StringName(id)
	u.tier_label = "B1"
	u.faction_side = &"player"
	u.max_hp = 100.0
	u.move_speed_px = 0.0
	u.position = pos
	_world.add_child(u)
	return u


func _make_area_with_shape(script: GDScript, radius: float) -> Area2D:
	var a := Area2D.new()
	a.set_script(script)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	a.add_child(shape)
	a.collision_layer = 0
	a.collision_mask = 1
	_world.add_child(a)
	return a


func _make_economy() -> Node:
	var e := Node.new()
	e.set_script(ECONOMY_SCRIPT)
	_world.add_child(e)
	return e


func _run() -> void:
	await _test_factory_produces_cargo_over_time()
	await _test_full_loop_factory_to_bank()
	await _test_dealer_demand_curve_independent_per_dealer()
	await _test_factory_destroy_halts_production_and_repair_restores()
	_finish()


func _test_factory_produces_cargo_over_time() -> void:
	var factory: Area2D = _make_area_with_shape(FACTORY_SCRIPT, 60.0)
	factory.level = 1
	await process_frame # let _ready() set max_hp/hp
	_expect(factory.stored_cargo == 0, "a fresh factory should start with 0 stored cargo")
	# Level 1 interval is 45s; advance well past two full cycles directly
	# via _process ticks (faster and more deterministic than waiting real
	# physics frames for a 45s timer).
	for i in range(10):
		factory._process(10.0) # 100 simulated seconds total
	_expect(factory.stored_cargo >= 2, "factory should have produced at least 2 cargo after 100s at a 45s interval, got %d" % factory.stored_cargo)
	_expect(factory.stored_cargo <= factory.MAX_STORED_CARGO, "factory cargo should be capped at MAX_STORED_CARGO")
	factory.queue_free()
	await process_frame


func _test_full_loop_factory_to_bank() -> void:
	var factory: Area2D = _make_area_with_shape(FACTORY_SCRIPT, 60.0)
	var dealer: Area2D = _make_area_with_shape(DEALER_SCRIPT, 60.0)
	var bank: Area2D = _make_area_with_shape(BANK_SCRIPT, 60.0)
	var economy := _make_economy()
	await process_frame
	economy.set_money(0)
	bank.economy = economy

	factory._process(50.0) # produce 1 cargo (interval 45s at level 1)
	_expect(factory.stored_cargo >= 1, "setup: factory should have produced cargo")

	var carrier := _make_unit("carrier", Vector2.ZERO)
	await physics_frame
	var picked_up: bool = factory.try_pickup(carrier)
	_expect(picked_up, "a unit at the factory should be able to pick up produced cargo")
	_expect(carrier.carried_cargo >= 1, "carrier should now hold cargo, got %d" % carrier.carried_cargo)

	# Sell at the dealer (channeled 5s).
	var cargo_value: int = factory.cargo_value()
	var started: bool = dealer.start_sell(carrier, economy, cargo_value)
	_expect(started, "starting a sell with cargo in hand should succeed")
	_expect(carrier.state == BwUnit.State.INTERACTING, "unit should enter the generic INTERACTING state while selling")
	for i in range(400): # generous margin over the 5s channel
		await physics_frame
		if carrier.state == BwUnit.State.IDLE:
			break
	_expect(carrier.carried_cargo == 0, "cargo should be spent after a successful sale")
	_expect(carrier.carried_cash > 0, "carrier should now hold carried cash, separate from bank balance")
	_expect(economy.money == 0, "carried cash must not touch the bank balance until deposited")

	# Deposit at the Bank (channeled 6s).
	var cash_before: int = carrier.carried_cash
	var deposit_started: bool = bank.start_deposit(carrier)
	_expect(deposit_started, "starting a deposit with cash in hand should succeed")
	for i in range(500): # generous margin over the 6s channel
		await physics_frame
		if carrier.state == BwUnit.State.IDLE:
			break
	_expect(carrier.carried_cash == 0, "carried cash should be cleared after depositing")
	_expect(economy.money == cash_before, "bank balance should increase by exactly the deposited amount, got %d expected %d" % [economy.money, cash_before])

	carrier.queue_free()
	factory.queue_free()
	dealer.queue_free()
	bank.queue_free()
	economy.queue_free()
	await process_frame


func _test_dealer_demand_curve_independent_per_dealer() -> void:
	var dealer_a: Area2D = _make_area_with_shape(DEALER_SCRIPT, 60.0)
	var dealer_b: Area2D = _make_area_with_shape(DEALER_SCRIPT, 60.0)
	var economy := _make_economy()
	await process_frame

	_expect(is_equal_approx(dealer_a.current_demand_multiplier(), 1.0), "a fresh dealer should start at 100% demand")

	# Sell 3 times in a row at dealer_a (instant, by calling the
	# interaction-complete hook directly rather than waiting 3 real 5s
	# channels, since this test only cares about the demand curve math).
	for expected in [1.0, 0.9, 0.75, 0.5]:
		var u := _make_unit("demand_u", Vector2.ZERO)
		u.carried_cargo = 1
		_expect(is_equal_approx(dealer_a.current_demand_multiplier(), expected), "dealer_a demand should be %.2f before this sale, got %.2f" % [expected, dealer_a.current_demand_multiplier()])
		dealer_a.on_interaction_complete(u)
		u.queue_free()

	# dealer_b was never sold to, so it must still be at 100% — proving
	# independent per-dealer demand.
	_expect(is_equal_approx(dealer_b.current_demand_multiplier(), 1.0), "an untouched dealer_b should remain at 100% demand regardless of dealer_a's sales")

	await process_frame
	dealer_a.queue_free()
	dealer_b.queue_free()
	economy.queue_free()
	await process_frame


func _test_factory_destroy_halts_production_and_repair_restores() -> void:
	var factory: Area2D = _make_area_with_shape(FACTORY_SCRIPT, 60.0)
	await process_frame
	factory.take_damage(10000.0)
	_expect(factory.is_destroyed, "lethal damage should destroy the factory")
	factory.stored_cargo = 0
	factory._process(200.0) # would have produced cargo if still active
	_expect(factory.stored_cargo == 0, "a destroyed factory should not produce any cargo")

	var cost: int = factory.repair_cost()
	_expect(cost > 0, "a destroyed factory should report a positive repair cost")
	factory.repair_full()
	_expect(not factory.is_destroyed, "repairing should clear the destroyed flag")
	factory._process(200.0)
	_expect(factory.stored_cargo > 0, "a repaired factory should resume production")

	factory.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp3_economy_loop: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
