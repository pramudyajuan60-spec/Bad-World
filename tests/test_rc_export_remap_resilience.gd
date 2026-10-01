extends SceneTree
## Release Candidate Fix Pass, Issue 5: regression guard for the real,
## serious bug this fix pass found — an exported/PCK build's DirAccess
## lists resource files with Godot's own ".remap" redirection suffix
## (e.g. "faction_bellarosa.tres.remap") instead of their real ".tres"
## name, which CampaignDatabase/CampaignEconomy's directory-scanning
## loaders previously matched against literally and therefore silently
## loaded ZERO campaigns/factions/difficulties/weapons in any actual
## export (confirmed by running the real exported Linux binary headful
## under Xvfb — editor/`--path .` mode never exposed this, since it
## reads the real filesystem directly with no remap layer). This test
## cannot reproduce the PCK remap layer itself (that requires an actual
## export), so it instead asserts the *symptom* this bug always
## produces: directory-scanned data must be non-empty, run in a mode
## (headless --script) consistent with all this project's other tests.
## Run with:
##   godot4 --headless --path . --script res://tests/test_rc_export_remap_resilience.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	await process_frame
	var db = root.get_node("CampaignDatabase")
	_expect(db.factions.size() == 4, "CampaignDatabase should have loaded exactly 4 factions, got %d" % db.factions.size())
	_expect(db.campaigns.size() == 4, "CampaignDatabase should have loaded exactly 4 campaigns, got %d" % db.campaigns.size())
	_expect(db.difficulties.size() == 3, "CampaignDatabase should have loaded exactly 3 difficulties, got %d" % db.difficulties.size())

	var economy_script = load("res://scripts/economy/campaign_economy.gd")
	var economy = Node.new()
	economy.set_script(economy_script)
	root.add_child(economy)
	await process_frame
	_expect(not economy.weapon_catalog.is_empty(), "CampaignEconomy should have loaded at least one weapon into weapon_catalog")
	_expect(economy.weapon_catalog.has("weapon_pistol"), "CampaignEconomy's weapon_catalog should contain the known weapon_pistol entry")
	economy.queue_free()

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Tests] rc_export_remap_resilience: all passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)
