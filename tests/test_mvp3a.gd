extends SceneTree
## MVP 3a smoke test: factory production, dealer demand/pricing.

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[Tests] PASS: ", msg)
	else:
		_failures += 1
		push_error("[Tests] FAIL: " + msg)

func _init() -> void:
	# Factory production config
	_check(Factory.LEVELS[1]["cargo"] == 2, "factory L1 makes 2 cargo/cycle")
	_check(Factory.LEVELS[4]["cargo"] == 6, "factory L4 makes 6 cargo/cycle")
	_check(Factory.MAX_LEVEL == 4, "max factory level 4")

	# Dealer demand + diminishing price
	var d := DrugDealer.new()
	d.demand = 20
	d.demand_max = 20
	var r1: Dictionary = d.sell_cargo(10)
	_check(int(r1["sold"]) == 10, "sold 10 cargo")
	_check(d.demand == 10, "demand dropped to 10")
	# price at full demand vs half demand: full should pay more per unit
	var d2 := DrugDealer.new()
	d2.demand = 20
	d2.demand_max = 20
	var full: Dictionary = d2.sell_cargo(20)
	var d3 := DrugDealer.new()
	d3.demand = 10
	d3.demand_max = 20
	var half: Dictionary = d3.sell_cargo(10)
	var ppc_full: float = float(full["cash"]) / 20.0
	var ppc_half: float = float(half["cash"]) / 10.0
	_check(ppc_full > ppc_half, "diminishing price: full demand pays more/unit (%.1f > %.1f)" % [ppc_full, ppc_half])
	# oversell capped by demand
	var d4 := DrugDealer.new()
	d4.demand = 5
	d4.demand_max = 20
	var r4: Dictionary = d4.sell_cargo(10)
	_check(int(r4["sold"]) == 5, "sale capped by demand")
	d.free()
	d2.free()
	d3.free()
	d4.free()

	if _failures == 0:
		print("[Tests] All MVP3a economy tests passed.")
	else:
		push_error("[Tests] %d failures" % _failures)
	quit(_failures)
