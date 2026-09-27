extends PanelContainer
## Gun Shop panel (Prompt Dasar MVP2: "Gun Shop"). Buying adds an
## unassigned item to the mission's shared inventory; assigning it to a
## specific unit happens in the Inspect panel (manual per-unit
## assignment, never automatic).

signal closed

var economy: Node = null

var _money_label: Label
var _rows: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(480, 420)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Gun Shop"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_money_label = Label.new()
	vbox.add_child(_money_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 300)
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)

	var ids: Array = economy.weapon_catalog.keys()
	ids.sort()
	for id in ids:
		var w: WeaponData = economy.weapon_catalog[id]
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.text = "Buy %s — $%d" % [w.display_name, w.price]
		btn.custom_minimum_size = Vector2(300, 32)
		btn.pressed.connect(_on_buy_pressed.bind(id))
		row.add_child(btn)
		var count_label := Label.new()
		count_label.custom_minimum_size = Vector2(120, 32)
		row.add_child(count_label)
		_rows[id] = count_label
		list.add_child(row)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)

	economy.money_changed.connect(func(_m): _refresh())
	_refresh()


func _on_buy_pressed(id: String) -> void:
	economy.try_buy_weapon(id)
	_refresh()


func _refresh() -> void:
	_money_label.text = "Money: $%d" % economy.money
	for id in _rows.keys():
		_rows[id].text = "Owned (unassigned): %d" % economy.gun_shop_inventory.get(id, 0)
