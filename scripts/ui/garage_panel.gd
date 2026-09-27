extends PanelContainer
## Garage panel (Prompt Dasar MVP3): buy any of the 4 vehicle classes.
## Spawned vehicles are empty (no driver) and appear at the Garage.

signal closed
signal buy_requested(vehicle_id: String)

var economy: Node = null
var _money_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(460, 320)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Garage"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_money_label = Label.new()
	vbox.add_child(_money_label)

	for id in ["vehicle_compact", "vehicle_armored_suv", "vehicle_gun_truck", "vehicle_apc"]:
		var data: VehicleData = load("res://data/vehicles/%s.tres" % id.replace("vehicle_", ""))
		var btn := Button.new()
		btn.text = "Buy %s — $%d (%d seats%s)" % [data.display_name, data.price, data.seat_capacity, " + turret" if data.has_turret else ""]
		btn.custom_minimum_size = Vector2(400, 36)
		btn.pressed.connect(_on_buy_pressed.bind(id))
		vbox.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)

	if economy:
		economy.money_changed.connect(func(_m): _refresh())
	_refresh()


func _on_buy_pressed(id: String) -> void:
	buy_requested.emit(id)


func _refresh() -> void:
	if economy:
		_money_label.text = "Money: $%d" % economy.money
