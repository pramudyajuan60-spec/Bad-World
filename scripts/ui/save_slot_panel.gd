extends PanelContainer
## Save/Load slot picker (Prompt Dasar MVP6 item 18: "Autosave dan
## minimal tiga manual save slots"). Shows the autosave slot read-only
## (load-only — nothing here ever writes to it manually, so autosave
## can never be overwritten by a manual save) plus SaveService's three
## manual slots, each with its own Save/Load/Delete.

signal closed
signal save_to_slot_requested(slot: int)
signal load_slot_requested(slot: int)

var _rows_host: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(560, 420)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Save / Load"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_rows_host = VBoxContainer.new()
	_rows_host.add_theme_constant_override("separation", 6)
	vbox.add_child(_rows_host)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit())
	vbox.add_child(close_btn)

	refresh()


func refresh() -> void:
	for c in _rows_host.get_children():
		c.queue_free()
	_add_row(SaveService.AUTOSAVE_SLOT, "Autosave", false)
	for slot in SaveService.manual_slots():
		_add_row(slot, "Manual Slot %d" % slot, true)


func _add_row(slot: int, label_text: String, allow_save: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_rows_host.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(130, 0)
	label.text = label_text
	row.add_child(label)

	var summary = SaveService.slot_summary(slot)
	var info := Label.new()
	info.custom_minimum_size = Vector2(240, 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	if summary == null:
		info.text = "(empty)"
	else:
		var campaign: CampaignData = CampaignDatabase.get_campaign(StringName(summary["campaign_id"]))
		var campaign_name: String = campaign.menu_name if campaign else summary["campaign_id"]
		var dt := Time.get_datetime_dict_from_unix_time(summary["saved_at_unix"])
		var when := "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
		info.text = "%s — $%d — %s" % [campaign_name, summary["money"], when]
	row.add_child(info)

	if allow_save:
		var save_btn := Button.new()
		save_btn.text = "Save"
		save_btn.pressed.connect(func(): save_to_slot_requested.emit(slot))
		row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.disabled = summary == null
	load_btn.pressed.connect(func(): load_slot_requested.emit(slot))
	row.add_child(load_btn)

	if allow_save:
		var delete_btn := Button.new()
		delete_btn.text = "Delete"
		delete_btn.disabled = summary == null
		delete_btn.pressed.connect(func():
			SaveService.delete_save(slot)
			refresh()
		)
		row.add_child(delete_btn)
