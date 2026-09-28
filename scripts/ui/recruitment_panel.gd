extends PanelContainer
## Recruitment building panel (Prompt Dasar MVP2: "Recruitment building",
## "B1, B2, B3, dan locked Special", "Recruitment timer, harga, gaji,
## unit cap"). Built entirely in code (no separate .tscn) to keep this
## MVP2 UI iteration-friendly; MVP6 is where real themed UI art replaces
## these generic controls.
##
## MVP4: B1 is omitted entirely when the current faction has none
## (Nabil) — `economy.unit_data_by_tier` simply won't contain that key,
## see CampaignEconomy.configure_roster. Special units are listed with
## their real price, shown locked until the Main Character reaches
## level 4 (Prompt Dasar: "Special unlock dan harga berfungsi").

signal closed

var economy: Node = null
## Set by open_world_map.gd; provides current_campaign.special_units
## plus can_recruit_special()/try_recruit_special()/_get_main_character().
var map: Node = null

var _status_label: Label
var _roster_label: Label
var _queue_label: Label
var _tier_buttons: Dictionary = {}
var _special_buttons: Array = []

const TIER_ORDER := ["B1", "B2", "B3"]


func _ready() -> void:
	custom_minimum_size = Vector2(460, 460)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Recruitment"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_roster_label = Label.new()
	vbox.add_child(_roster_label)

	for tier in TIER_ORDER:
		if not economy.unit_data_by_tier.has(tier):
			continue # e.g. Nabil has no B1 — Prompt Dasar "Nabil tidak dapat merekrut B1"
		var data: UnitData = economy.unit_data_by_tier[tier]
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.text = "Recruit %s — $%d (salary $%d)" % [tier, data.recruit_price, data.salary]
		btn.custom_minimum_size = Vector2(360, 36)
		btn.pressed.connect(_on_recruit_pressed.bind(tier))
		row.add_child(btn)
		_tier_buttons[tier] = btn
		vbox.add_child(row)

	if map:
		var specials_title := Label.new()
		specials_title.text = "Special (unlocks at Main Character level 4)"
		vbox.add_child(specials_title)
		for i in range(map.current_campaign.special_units.size()):
			var data: UnitData = map.current_campaign.special_units[i]
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(400, 36)
			btn.pressed.connect(_on_recruit_special_pressed.bind(i))
			vbox.add_child(btn)
			_special_buttons.append(btn)

	_queue_label = Label.new()
	vbox.add_child(_queue_label)

	_status_label = Label.new()
	_status_label.modulate = Color(1.0, 0.6, 0.3)
	vbox.add_child(_status_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)

	economy.money_changed.connect(func(_m): _refresh())
	economy.recruitment_progress.connect(_on_progress)
	economy.unit_recruited.connect(func(_t): _refresh())
	_refresh()


func _on_recruit_pressed(tier: String) -> void:
	if not economy.try_start_recruit(tier):
		_status_label.text = "Cannot recruit %s (insufficient funds or roster full)." % tier
	else:
		_status_label.text = ""
	_refresh()


func _on_recruit_special_pressed(index: int) -> void:
	if not map.try_recruit_special(index):
		var mc = map._get_main_character()
		if mc == null or mc.mc_level < 4:
			_status_label.text = "Special units unlock at Main Character level 4."
		else:
			_status_label.text = "Cannot recruit this Special (insufficient funds, roster full, or already recruited)."
	else:
		_status_label.text = ""
	_refresh()


func _on_progress(tier: String, remaining: float, total: float) -> void:
	_queue_label.text = "Recruiting %s: %.0fs / %.0fs" % [tier, total - remaining, total]


func _refresh() -> void:
	_roster_label.text = "Roster: %d / %d (+ Main Character)   Money: $%d" % [economy.recruited_count, economy.max_roster, economy.money]
	if map:
		var mc = map._get_main_character()
		var mc_level: int = mc.mc_level if mc else 1
		for i in range(_special_buttons.size()):
			var data: UnitData = map.current_campaign.special_units[i]
			var btn: Button = _special_buttons[i]
			var already: bool = i in map._recruited_special_ids
			if already:
				btn.text = "%s — Recruited" % data.display_name
				btn.disabled = true
			elif mc_level < 4:
				btn.text = "%s — Locked (MC level 4 required, currently %d)" % [data.display_name, mc_level]
				btn.disabled = true
			else:
				btn.text = "Recruit %s — $%d (salary $%d)" % [data.display_name, data.recruit_price, data.salary]
				btn.disabled = not economy.can_afford(data.recruit_price)
