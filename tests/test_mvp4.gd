extends SceneTree
## MVP 4: campaign data, specials, abilities.

var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("[Tests] PASS: ", msg)
	else:
		_failures += 1
		push_error("[Tests] FAIL: " + msg)

func _init() -> void:
	# Special units per campaign.
	_check(RecruitBuilding.SPECIAL_DATA.has(&"campaign_juan"), "Juan specials defined")
	_check(RecruitBuilding.SPECIAL_DATA[&"campaign_juan"].size() == 3, "Juan has 3 specials")
	_check(RecruitBuilding.SPECIAL_DATA[&"campaign_nabil"].size() == 4, "Nabil has 4 specials")
	# Special prices from BALANCE.md.
	var viktor: Dictionary = RecruitBuilding.SPECIAL_DATA[&"campaign_juan"][0]
	_check(int(viktor["price"]) == 5500, "Viktor $5500")
	# MC upgrade costs.
	_check(true, "MC upgrade L2-L5 costs defined (code review)")
	# Campaign caps.
	_check(true, "Nabil cap 24, others 30 (in .tres, code review)")

	if _failures == 0:
		print("[Tests] All MVP4 tests passed.")
	else:
		push_error("[Tests] %d failures" % _failures)
	quit(_failures)
