extends Node
## Autoload singleton (see [autoload] in project.godot).
##
## Loads the data-driven campaign/faction/difficulty tables from res://data
## on startup so gameplay and UI code never hardcode campaign facts. MVP 0
## only wires loading + lookup; selection UI and gameplay arrive in MVP 1.

const FACTIONS_DIR := "res://data/factions/"
const CAMPAIGNS_DIR := "res://data/campaigns/"
const DIFFICULTIES_DIR := "res://data/difficulty/"

var factions: Dictionary = {} # StringName -> FactionData
var campaigns: Dictionary = {} # StringName -> CampaignData
var difficulties: Dictionary = {} # StringName -> DifficultyData


func _ready() -> void:
	# Factions load first: campaign .tres files hold an ext_resource
	# reference to their faction, which Godot resolves on load regardless
	# of this dictionary, but loading order here keeps logs readable.
	_load_dir(FACTIONS_DIR, factions)
	_load_dir(CAMPAIGNS_DIR, campaigns)
	_load_dir(DIFFICULTIES_DIR, difficulties)
	print("[CampaignDatabase] loaded %d faction(s), %d campaign(s), %d difficulty(ies)." % [
		factions.size(), campaigns.size(), difficulties.size()
	])


func _load_dir(path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("CampaignDatabase: cannot open %s" % path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# Release Candidate Fix Pass: an exported/PCK build's
			# DirAccess lists resource files with Godot's own extra
			# ".remap" redirection suffix (e.g.
			# "faction_bellarosa.tres.remap") instead of the real
			# ".tres" name this check was written against — so this
			# always silently matched 0 files in any actual export
			# (confirmed: editor/`--path .` mode has no remap layer and
			# never exposed this, which is exactly why it went
			# undetected through MVP0-7). load() itself must still be
			# given the un-suffixed name; see docs/TECH_DECISIONS.md
			# "Release Candidate: CampaignDatabase never loaded any
			# data in an actual export".
			var real_name: String = file_name
			if real_name.ends_with(".remap"):
				real_name = real_name.substr(0, real_name.length() - ".remap".length())
			if real_name.ends_with(".tres"):
				var res: Resource = load(path + real_name)
				if res != null and ("id" in res):
					into[res.id] = res
				else:
					push_error("CampaignDatabase: %s%s did not load as expected typed resource" % [path, real_name])
		file_name = dir.get_next()
	dir.list_dir_end()


func get_campaign(id: StringName) -> CampaignData:
	return campaigns.get(id)


func get_all_campaigns() -> Array:
	return campaigns.values()


func get_faction(id: StringName) -> FactionData:
	return factions.get(id)


func get_difficulty(id: StringName) -> DifficultyData:
	return difficulties.get(id)


func get_all_difficulties() -> Array:
	return difficulties.values()
