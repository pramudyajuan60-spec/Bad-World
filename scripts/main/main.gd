extends Control
## MVP 0 bootstrap scene.
##
## Confirms the project boots and that campaign data actually loads from
## res://data (acceptance criterion: "Empat campaign dapat dimuat dari
## data"). This is intentionally not a real menu — campaign selection and
## gameplay begin in MVP 1.

@onready var _label: Label = $Label
@onready var _list: VBoxContainer = $CampaignList


func _ready() -> void:
	var db := get_node("/root/CampaignDatabase")
	var campaigns: Array = db.get_all_campaigns()
	campaigns.sort_custom(func(a, b): return String(a.id) < String(b.id))

	_label.text = "BAD WORLD — MVP 0 Bootstrap (%d campaign(s) loaded from data)" % campaigns.size()
	for campaign in campaigns:
		var line := Label.new()
		var faction_name: String = campaign.faction.display_name if campaign.faction else "(missing faction)"
		line.text = "%s — %s (%s)" % [campaign.menu_name, campaign.main_character_name, faction_name]
		_list.add_child(line)

	print("[MVP0] Loaded %d campaign(s) from data." % campaigns.size())
