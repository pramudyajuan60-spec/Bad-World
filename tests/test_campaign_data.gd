extends SceneTree
## Minimal headless smoke tests for MVP 0.
##
## Run with:
##   godot --headless --script res://tests/test_campaign_data.gd
##
## This is intentionally not a full testing framework (GUT etc.) — MVP 0
## has no gameplay to test yet. It only proves the data layer works, per
## rule "Jangan mengklaim sebuah fitur selesai jika belum dijalankan dan
## diuji." Replace/extend with a real framework once gameplay exists.

var _failures: Array[String] = []


func _initialize() -> void:
	_test_four_campaigns_load()
	_test_campaign_ids_and_names_match_spec()
	_test_difficulties_load()
	if _failures.is_empty():
		print("[Tests] All MVP0 smoke tests passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("[Tests] FAIL: %s" % f)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _load_campaigns() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://data/campaigns/")
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			var c: CampaignData = load("res://data/campaigns/" + f)
			out[String(c.id)] = c
		f = dir.get_next()
	dir.list_dir_end()
	return out


func _test_four_campaigns_load() -> void:
	var campaigns := _load_campaigns()
	_expect(campaigns.size() == 4, "expected 4 campaigns, found %d" % campaigns.size())


func _test_campaign_ids_and_names_match_spec() -> void:
	var campaigns := _load_campaigns()
	for expected_id in ["campaign_juan", "campaign_fauzi", "campaign_atha", "campaign_nabil"]:
		_expect(campaigns.has(expected_id), "missing campaign id %s" % expected_id)

	if campaigns.has("campaign_fauzi"):
		var c: CampaignData = campaigns["campaign_fauzi"]
		_expect(c.main_character_name == "Zie Vartieri", "campaign_fauzi main character must remain 'Zie Vartieri', not 'Valtieri'")
		_expect(c.faction.display_name == "Vartieri Cartel", "campaign_fauzi faction display name must be 'Vartieri Cartel'")

	if campaigns.has("campaign_nabil"):
		var c: CampaignData = campaigns["campaign_nabil"]
		_expect(c.starting_money == 6500, "campaign_nabil starting_money must match Prompt Dasar BALANCE V0.1 (6500)")


func _test_difficulties_load() -> void:
	var dir := DirAccess.open("res://data/difficulty/")
	var count := 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			count += 1
		f = dir.get_next()
	dir.list_dir_end()
	_expect(count == 3, "expected 3 difficulty presets, found %d" % count)
