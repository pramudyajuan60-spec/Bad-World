extends PanelContainer
## Recruitment building panel (Prompt Dasar MVP2: "Recruitment building",
## "B1, B2, B3, dan locked Special", "Recruitment timer, harga, gaji,
## unit cap"). Built entirely in code (no separate .tscn) to keep this
## MVP2 UI iteration-friendly; MVP6 is where real themed UI art replaces
## these generic controls.

signal closed

var economy: Node = null

var _status_label: Label
var _roster_label: Label
var _queue_label: Label
var _tier_buttons: Dictionary = {}

const TIER_ORDER := ["B1", "B2", "B3"]


func _ready() -> void:
	custom_minimum_size = Vector2(420, 320)
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
		var data: UnitData = economy.unit_data_by_tier[tier]
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.text = "Recruit %s — $%d (salary $%d)" % [tier, data.recruit_price, data.salary]
		btn.custom_minimum_size = Vector2(360, 36)
		btn.pressed.connect(_on_recruit_pressed.bind(tier))
		row.add_child(btn)
		_tier_buttons[tier] = btn
		vbox.add_child(row)

	var special_label := Label.new()
	special_label.text = "Special — Locked (unlocks at level 4, see MVP4)"
	special_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(special_label)

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


func _on_progress(tier: String, remaining: float, total: float) -> void:
	_queue_label.text = "Recruiting %s: %.0fs / %.0fs" % [tier, total - remaining, total]


func _refresh() -> void:
	_roster_label.text = "Roster: %d / %d (+ Main Character)   Money: $%d" % [economy.recruited_count, economy.max_roster, economy.money]
