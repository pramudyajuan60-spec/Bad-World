extends PanelContainer
## DEA Armory panel: craft weapons from Parts instead of buying with
## money (Prompt Dasar). Crafted items land in the same
## `gun_shop_inventory` pool the Inspect panel already reads from, so
## manual per-unit assignment works identically regardless of source.

signal closed

var economy: Node = null

var _parts_label: Label
var _queue_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(460, 380)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "DEA Armory"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_parts_label = Label.new()
	vbox.add_child(_parts_label)

	var ids: Array = economy.ARMORY_PARTS_COST.keys()
	ids.sort()
	for id in ids:
		var w: WeaponData = economy.weapon_catalog.get(id)
		if w == null:
			continue
		var cost: int = economy.ARMORY_PARTS_COST[id]
		var btn := Button.new()
		btn.text = "Craft %s — %d Parts" % [w.display_name, cost]
		btn.custom_minimum_size = Vector2(400, 32)
		btn.pressed.connect(_on_craft_pressed.bind(id))
		vbox.add_child(btn)

	_queue_label = Label.new()
	vbox.add_child(_queue_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)

	economy.parts_changed.connect(func(_p): _refresh())
	economy.crafting_progress.connect(_on_progress)
	_refresh()


func _on_craft_pressed(id: String) -> void:
	economy.try_start_craft(id)
	_refresh()


func _on_progress(weapon_id: String, remaining: float, total: float) -> void:
	_queue_label.text = "Crafting %s: %.0fs / %.0fs" % [weapon_id, total - remaining, total]


func _refresh() -> void:
	_parts_label.text = "Parts: %d / %d" % [economy.parts, economy.ARMORY_MAX_PARTS]
