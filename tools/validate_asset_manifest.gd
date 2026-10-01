extends SceneTree
## Headless asset-manifest validator (MVP 0 acceptance criterion:
## "Asset manifest dapat divalidasi").
##
## Run with:
##   godot --headless --script res://tools/validate_asset_manifest.gd
##
## Checks:
## 1. Every file catalogued in data/manifest/asset_manifest.json still
##    exists on disk (catches manifest drift).
## 2. Every asset path referenced by a CampaignData resource actually
##    exists (catches broken data-driven references).
## Known, already-documented asset gaps (docs/PLACEHOLDER_REGISTER.md) are
## not treated as failures at this stage.

func _initialize() -> void:
	var ok := true
	ok = _validate_manifest_entries_exist() and ok
	ok = _validate_campaign_references() and ok
	print("[AssetManifestValidator] %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _validate_manifest_entries_exist() -> bool:
	var manifest_path := "res://data/manifest/asset_manifest.json"
	if not FileAccess.file_exists(manifest_path):
		push_error("Missing asset manifest: %s" % manifest_path)
		return false
	var text := FileAccess.get_file_as_string(manifest_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Asset manifest JSON did not parse to a dictionary.")
		return false
	var missing: Array = []
	for entry in parsed.get("assets", []):
		var p: String = "res://" + String(entry["path"])
		if not FileAccess.file_exists(p):
			missing.append(p)
	if missing.size() > 0:
		push_error("Manifest lists %d file(s) that no longer exist on disk: %s" % [missing.size(), missing])
		return false
	print("[AssetManifestValidator] %d cataloged file(s) verified present." % int(parsed.get("asset_count", 0)))
	return true


func _validate_campaign_references() -> bool:
	var ok := true
	var dir := DirAccess.open("res://data/campaigns/")
	if dir == null:
		push_error("Cannot open res://data/campaigns/")
		return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var checked := 0
	while file_name != "":
		if file_name.ends_with(".tres"):
			var campaign: CampaignData = load("res://data/campaigns/" + file_name)
			checked += 1
			var paths := [campaign.story_path, campaign.portrait_path, campaign.main_character_sprite_path, campaign.concept_map_path]
			for p in paths:
				if p != "" and not FileAccess.file_exists(p):
					push_error("%s: missing referenced asset %s" % [campaign.id, p])
					ok = false
			if campaign.faction == null:
				push_error("%s: faction reference is null" % campaign.id)
				ok = false
		file_name = dir.get_next()
	dir.list_dir_end()
	print("[AssetManifestValidator] checked %d campaign resource(s)." % checked)
	if checked != 4:
		push_error("Expected 4 campaign resources, found %d" % checked)
		ok = false
	return ok
