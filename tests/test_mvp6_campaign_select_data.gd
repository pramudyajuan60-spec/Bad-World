extends SceneTree
## Headless tests for MVP6 "Campaign selection dengan portrait, faction,
## keunggulan, kelemahan, starting units, economy rating, unit cap".
## Checks the underlying data every campaign card is built from (not
## the Control tree itself, which needs a real viewport) — the same
## split test_campaign_data.gd already uses for MVP0 data checks. Run
## with:
##   godot4 --headless --path . --script res://tests/test_mvp6_campaign_select_data.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	await process_frame
	var db = root.get_node("CampaignDatabase")
	for c in db.get_all_campaigns():
		var faction: FactionData = c.faction
		_expect(faction != null, "%s should have a linked FactionData" % c.id)
		if faction == null:
			continue
		_expect(not faction.strengths.is_empty(), "%s's faction should list at least one strength (keunggulan)" % faction.display_name)
		_expect(not faction.weaknesses.is_empty(), "%s's faction should list at least one weakness (kelemahan)" % faction.display_name)
		_expect(faction.economy_rating_stars >= 1 and faction.economy_rating_stars <= 5, "%s's economy_rating_stars should be 1..5" % faction.display_name)
		_expect(faction.economy_rating_label != "", "%s should have a non-empty economy_rating_label" % faction.display_name)
		_expect(faction.max_roster > 0, "%s should have a positive unit cap (max_roster)" % faction.display_name)
		_expect(c.portrait_path != "" and FileAccess.file_exists(c.portrait_path.replace("res://", "res://")), "%s should reference an existing portrait_path" % c.menu_name)
		_expect(c.story_path != "" and FileAccess.file_exists(c.story_path), "%s should reference an existing canonical Story.txt" % c.menu_name)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] mvp6_campaign_select_data: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
