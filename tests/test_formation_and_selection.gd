extends SceneTree
## Headless tests for pure/near-pure gameplay math: formation spacing
## (Prompt Dasar: units must not stack at their destination) and the
## selection-rectangle / same-tier helpers used by box-select and
## double-click. Run with:
##   godot4 --headless --path . --script res://tests/test_formation_and_selection.gd

var _failures: Array[String] = []


func _initialize() -> void:
	_test_formation_single_unit()
	_test_formation_spacing_no_overlap()
	_test_units_in_rect()
	_test_units_of_same_tier()
	_test_control_groups()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] formation_and_selection: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


func _test_formation_single_unit() -> void:
	var positions: Array = FormationUtils.compute_positions(Vector2(100, 100), 1, 40.0)
	_expect(positions.size() == 1, "formation(1) should return exactly 1 position")
	_expect(positions[0].distance_to(Vector2(100, 100)) < 0.01, "formation(1) should be exactly the center point")


func _test_formation_spacing_no_overlap() -> void:
	for count in [2, 3, 4, 7, 10]:
		var spacing := 40.0
		var positions: Array = FormationUtils.compute_positions(Vector2.ZERO, count, spacing)
		_expect(positions.size() == count, "formation(%d) should return %d positions, got %d" % [count, count, positions.size()])
		for i in range(positions.size()):
			for j in range(i + 1, positions.size()):
				var d: float = positions[i].distance_to(positions[j])
				_expect(d >= spacing - 0.01, "formation(%d) positions %d and %d are closer (%.2f) than spacing %.2f — units would stack" % [count, i, j, d, spacing])


func _test_units_in_rect() -> void:
	var root := Node2D.new()
	self.root.add_child(root)
	var inside := Node2D.new()
	inside.position = Vector2(10, 10)
	root.add_child(inside)
	var outside := Node2D.new()
	outside.position = Vector2(500, 500)
	root.add_child(outside)
	var rect := Rect2(Vector2(0, 0), Vector2(50, 50))
	var result := SelectionManager.units_in_rect([inside, outside], rect)
	_expect(result.size() == 1 and result[0] == inside, "units_in_rect should only return the unit inside the rect")
	root.queue_free()


const UNIT_SCENE := preload("res://scenes/gameplay/Unit.tscn")


func _make_unit(tier: String) -> BwUnit:
	var u: BwUnit = UNIT_SCENE.instantiate()
	u.tier_label = tier
	root.add_child(u)
	return u


func _test_units_of_same_tier() -> void:
	var a := _make_unit("B1")
	var b := _make_unit("B1")
	var c := _make_unit("MC")
	var result := SelectionManager.units_of_same_tier([a, b, c], a)
	_expect(result.size() == 2 and a in result and b in result and not (c in result), "units_of_same_tier should match only same-tier units")
	a.queue_free()
	b.queue_free()
	c.queue_free()


func _test_control_groups() -> void:
	var sm := SelectionManager.new()
	var u1 := _make_unit("B1")
	var u2 := _make_unit("B1")
	sm.selected = [u1, u2]
	sm.assign_control_group(1)
	_expect(sm.control_groups.has(1), "assign_control_group(1) should create group 1")
	_expect(sm.control_groups[1].size() == 2, "control group 1 should contain both selected units")
	sm.selected = []
	sm.recall_control_group(1)
	_expect(sm.selected.size() == 2, "recall_control_group(1) should restore the 2 units into selection")
	u1.queue_free()
	u2.queue_free()
	sm.free()
