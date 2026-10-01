extends PanelContainer
## Unit inspect panel (Prompt Dasar MVP2: "Unit inspect panel", "Inventory
## manual per unit"). Shows the first selected unit; "Next Unit" cycles
## through the player's full roster (not just the current selection) so
## equipment can be assigned to units that aren't selected on the map.

signal closed

var economy: Node = null
var selection_manager: Node = null

var _roster: Array = []
var _index: int = 0

var _name_label: Label
var _stats_label: Label
var _equip_label: Label
var _status_label: Label
var _slot_rows: Dictionary = {}

const SLOT_CATEGORIES := {
	"primary": [WeaponData.Category.PISTOL, WeaponData.Category.SMG, WeaponData.Category.SHOTGUN, WeaponData.Category.RIFLE, WeaponData.Category.SNIPER, WeaponData.Category.LMG, WeaponData.Category.LAUNCHER],
	"secondary": [WeaponData.Category.MELEE],
	"grenade": [WeaponData.Category.GRENADE],
	"armor": [WeaponData.Category.ARMOR],
}


func _ready() -> void:
	custom_minimum_size = Vector2(520, 480)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Unit Inspect"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_name_label = Label.new()
	vbox.add_child(_name_label)
	_stats_label = Label.new()
	vbox.add_child(_stats_label)
	_equip_label = Label.new()
	_equip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_equip_label)

	for slot in ["primary", "secondary", "grenade", "armor"]:
		var row_title := Label.new()
		row_title.text = "Assign %s:" % slot.capitalize()
		vbox.add_child(row_title)
		var row := HBoxContainer.new()
		vbox.add_child(row)
		_slot_rows[slot] = row

	_status_label = Label.new()
	_status_label.modulate = Color(1.0, 0.6, 0.3)
	vbox.add_child(_status_label)

	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)
	var next_btn := Button.new()
	next_btn.text = "Next Unit"
	next_btn.pressed.connect(_on_next_unit)
	buttons.add_child(next_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit())
	buttons.add_child(close_btn)

	economy.money_changed.connect(func(_m): _refresh())
	refresh_roster()


func refresh_roster() -> void:
	_roster = selection_manager.player_units.filter(func(u): return is_instance_valid(u))
	if _roster.is_empty():
		_index = 0
	else:
		var current := current_unit()
		if not selection_manager.selected.is_empty() and is_instance_valid(selection_manager.selected[0]):
			var sel = selection_manager.selected[0]
			var idx: int = _roster.find(sel)
			if idx != -1:
				_index = idx
		_index = clampi(_index, 0, _roster.size() - 1)
	_refresh()


func current_unit() -> BwUnit:
	if _index >= 0 and _index < _roster.size():
		return _roster[_index]
	return null


func _on_next_unit() -> void:
	if _roster.is_empty():
		return
	_index = (_index + 1) % _roster.size()
	_refresh()


func _refresh() -> void:
	for slot in _slot_rows.keys():
		for c in _slot_rows[slot].get_children():
			c.queue_free()

	var u := current_unit()
	if u == null:
		_name_label.text = "(no units)"
		_stats_label.text = ""
		_equip_label.text = ""
		return

	_name_label.text = "%s (%s)  HP %d/%d  Morale %d" % [u.display_name, u.tier_label, int(u.hp), int(u.max_hp), int(u.morale)]
	_stats_label.text = "State: %s   Missed payroll cycles: %d" % [_state_name(u.state), u.missed_payroll_cycles]
	_equip_label.text = "Primary: %s (mag %d / reserve %d)   Secondary: %s   Grenade: %s (x%d)   Armor: %s" % [
		u.primary_weapon.display_name if u.primary_weapon else "(none)",
		u.primary_mag, u.primary_reserve,
		u.secondary_weapon.display_name if u.secondary_weapon else "(none)",
		u.grenade_weapon.display_name if u.grenade_weapon else "(none)", u.grenade_count,
		u.armor_weapon.display_name if u.armor_weapon else "(none)",
	]

	for slot in SLOT_CATEGORIES.keys():
		var row: HBoxContainer = _slot_rows[slot]
		var categories: Array = SLOT_CATEGORIES[slot]
		for id in economy.weapon_catalog.keys():
			var w: WeaponData = economy.weapon_catalog[id]
			if not (w.category in categories):
				continue
			var count: int = economy.gun_shop_inventory.get(id, 0)
			if count <= 0:
				continue
			var btn := Button.new()
			btn.text = "%s (x%d)" % [w.display_name, count]
			btn.pressed.connect(_on_assign_pressed.bind(slot, id))
			row.add_child(btn)


func _on_assign_pressed(slot: String, weapon_id: String) -> void:
	var u := current_unit()
	if u == null:
		return
	if economy.try_assign_weapon(u, slot, weapon_id):
		_status_label.text = ""
	else:
		_status_label.text = "No unassigned %s available." % weapon_id
	_refresh()


func _state_name(state: int) -> String:
	var names := ["IDLE", "MOVING", "ATTACK_MOVING", "ATTACKING", "DEFENDING", "MOVING_TO_COVER", "DOWNED", "REVIVING", "EXECUTING", "RECRUITING", "RETREATING", "DEAD"]
	if state >= 0 and state < names.size():
		return names[state]
	return "?"
