extends SceneTree
## MVP 2b smoke test: directional cover, defend mode, suppression.

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[Tests] PASS: ", msg)
	else:
		_failures += 1
		push_error("[Tests] FAIL: " + msg)

func _init() -> void:
	# Cover directional logic (pure math, no scene needed)
	var cp := CoverPoint.new()
	cp.position = Vector2.ZERO
	# defender behind cover (south), attacker north => protected
	var m1: float = cp.protection_for(Vector2(0, 30), Vector2(0, -100))
	_check(m1 < 1.0, "cover protects from opposite side (mult=%.2f)" % m1)
	# defender and attacker same side => no protection
	var m2: float = cp.protection_for(Vector2(0, 30), Vector2(0, 100))
	_check(m2 == 1.0, "no cover from same side")
	# defender too far => no protection
	var m3: float = cp.protection_for(Vector2(0, 200), Vector2(0, -100))
	_check(m3 == 1.0, "no cover when too far")
	cp.free()

	if _failures == 0:
		print("[Tests] All MVP2b cover tests passed.")
	else:
		push_error("[Tests] %d failures" % _failures)
	quit(_failures)
