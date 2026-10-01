extends Control
## Shows all 4 campaigns (Prompt Dasar MVP 1: "Campaign selection
## menampilkan empat campaign"). All four are playable as of MVP4
## ("Aktifkan seluruh campaign").
##
## MVP6 (item 3): each campaign is a full card — portrait, faction,
## keunggulan (strengths), kelemahan (weaknesses), starting units,
## economy rating, and unit cap — all read from CampaignData/
## FactionData, never hardcoded here, so the numbers stay in sync with
## whatever MVP3/4/5 code actually spawns.

@onready var list: VBoxContainer = $ScrollContainer/VBox
@onready var back_btn: Button = $BackButton


func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	var campaigns: Array = CampaignDatabase.get_all_campaigns()
	campaigns.sort_custom(func(a, b): return String(a.id) < String(b.id))
	for c in campaigns:
		list.add_child(_build_card(c))


func _build_card(c: CampaignData) -> Control:
	var faction: FactionData = c.faction
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1040, 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 120)
	# EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_CENTERED (same combo as
	# story_panel.gd's own portrait): the box stays exactly
	# custom_minimum_size regardless of the source image's own aspect
	# ratio, which otherwise blew this card out much wider than the
	# ScrollContainer (verified via Xvfb capture before this fix).
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.clip_contents = true
	if c.portrait_path != "" and ResourceLoader.exists(c.portrait_path):
		portrait.texture = load(c.portrait_path)
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(760, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var title := Label.new()
	title.text = "%s — %s (%s)" % [c.menu_name, c.main_character_name, faction.display_name if faction else "?"]
	title.add_theme_font_size_override("font_size", 18)
	info.add_child(title)

	if faction:
		info.add_child(_wrapped_label("Keunggulan: " + ("; ".join(faction.strengths) if not faction.strengths.is_empty() else "-")))
		info.add_child(_wrapped_label("Kelemahan: " + ("; ".join(faction.weaknesses) if not faction.weaknesses.is_empty() else "-")))
		info.add_child(_wrapped_label("Economy rating: %s (%s)" % ["★".repeat(faction.economy_rating_stars) + "☆".repeat(5 - faction.economy_rating_stars), faction.economy_rating_label]))
		info.add_child(_wrapped_label("Unit cap: %d recruited + Main Character (%d total)" % [faction.max_roster, faction.max_roster + 1]))

	var starting_tier: String = "B1" if (faction and faction.has_b1) else "B2"
	info.add_child(_wrapped_label("Starting units: %s + 3×%s, starting money $%d, %s" % [
		c.main_character_name, starting_tier, c.starting_money,
		c.starting_vehicle.display_name if c.starting_vehicle else "no starting vehicle",
	]))

	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.custom_minimum_size = Vector2(120, 40)
	select_btn.pressed.connect(_select.bind(c))
	info.add_child(select_btn)

	return card


func _wrapped_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(740, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _select(c) -> void:
	GameState.current_campaign_id = c.id
	get_tree().change_scene_to_file("res://scenes/ui/DifficultySelect.tscn")
