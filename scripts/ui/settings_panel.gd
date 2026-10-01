extends PanelContainer
## Reusable Settings panel (Prompt Dasar MVP6 items 15-17: "Pause/
## settings", "Volume controls meskipun audio masih placeholder", "Key
## rebinding"). Built via code like inspect_panel.gd/garage_panel.gd so
## it can be hosted both full-screen (SettingsMenu.tscn, from Main
## Menu) and as an in-mission overlay toggled from the Pause Menu —
## one implementation, two hosts, same as every other MVP panel.

signal closed

var _rebind_listening_action: StringName = &""
var _rebind_buttons: Dictionary = {} # action -> Button (shows current key)
var _status_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(560, 520)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(540, 420)
	vbox.add_child(tabs)

	tabs.add_child(_build_volume_tab())
	tabs.add_child(_build_controls_tab())

	_status_label = Label.new()
	_status_label.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(_status_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)


func _build_volume_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "Volume"
	box.add_theme_constant_override("separation", 12)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.text = "Audio assets are still placeholder (no mixed sound yet), but these sliders already control real engine audio bus volume."
	box.add_child(note)
	for bus_name in UserPrefsService.AUDIO_BUSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var label := Label.new()
		label.custom_minimum_size = Vector2(90, 0)
		label.text = bus_name
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = UserPrefsService.get_volume(bus_name)
		slider.custom_minimum_size = Vector2(300, 0)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(50, 0)
		value_label.text = "%d%%" % int(slider.value * 100.0)
		slider.value_changed.connect(func(v: float):
			UserPrefsService.set_volume(bus_name, v)
			value_label.text = "%d%%" % int(v * 100.0)
		)
		row.add_child(slider)
		row.add_child(value_label)
	return box


func _build_controls_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Controls"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(500, 0)
	scroll.add_child(box)
	for action in UserPrefsService.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var label := Label.new()
		label.custom_minimum_size = Vector2(230, 0)
		label.text = UserPrefsService.get_action_label(action)
		row.add_child(label)
		var key_btn := Button.new()
		key_btn.custom_minimum_size = Vector2(140, 0)
		key_btn.text = UserPrefsService.get_action_key_label(action)
		key_btn.pressed.connect(_on_rebind_pressed.bind(action, key_btn))
		row.add_child(key_btn)
		_rebind_buttons[action] = key_btn
		var reset_btn := Button.new()
		reset_btn.text = "Reset"
		reset_btn.pressed.connect(_on_reset_pressed.bind(action, key_btn))
		row.add_child(reset_btn)
	return scroll


func _on_rebind_pressed(action: StringName, btn: Button) -> void:
	if _rebind_listening_action != &"":
		# Already listening for a different action: cancel that one first.
		var prev_btn: Button = _rebind_buttons.get(_rebind_listening_action)
		if prev_btn:
			prev_btn.text = UserPrefsService.get_action_key_label(_rebind_listening_action)
	_rebind_listening_action = action
	btn.text = "Press any key..."
	_status_label.text = ""
	set_process_unhandled_key_input(true)


func _on_reset_pressed(action: StringName, btn: Button) -> void:
	UserPrefsService.reset_keybind_to_default(action)
	btn.text = UserPrefsService.get_action_key_label(action)
	_status_label.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if _rebind_listening_action == &"" or not (event is InputEventKey) or not event.pressed:
		return
	var action: StringName = _rebind_listening_action
	var btn: Button = _rebind_buttons.get(action)
	var keycode: int = event.physical_keycode
	_rebind_listening_action = &""
	set_process_unhandled_key_input(false)
	get_viewport().set_input_as_handled()
	if keycode == KEY_ESCAPE:
		if btn:
			btn.text = UserPrefsService.get_action_key_label(action)
		return
	if UserPrefsService.try_rebind(action, keycode):
		if btn:
			btn.text = UserPrefsService.get_action_key_label(action)
		_status_label.text = ""
	else:
		if btn:
			btn.text = UserPrefsService.get_action_key_label(action)
		_status_label.text = "That key is already bound to another action."
