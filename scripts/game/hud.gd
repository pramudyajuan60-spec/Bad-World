extends CanvasLayer
## MVP 1 HUD: selection info, hints, pause panel, flash messages.

var _flash_label: Label
var _flash_tween: Tween


func _ready() -> void:
	_flash_label = $Flash
	($PausePanel as Control).visible = false


func update_selection(selected: Array) -> void:
	var info: Label = $SelectionInfo
	if selected.is_empty():
		info.text = "No selection"
	elif selected.size() == 1:
		var u = selected[0]
		var wname: String = u.weapon.display_name if u.weapon != null else "none"
		var armor := "Vest" if u.has_armor else "-"
		var state := "DOWNED" if u.state == 3 else ("DEFEND" if u.defend_mode else "OK")
		info.text = "%s | HP %d/%d | %s %d/%d | Grenades %d | %s | Tier %d | $%d/cycle | Cargo %d | Cash $%d | %s" % [
			u.unit_name, int(u.hp), int(u.max_hp), wname,
			u.ammo_in_mag, u.reserve_ammo, u.grenades, armor,
			u.unit_tier, u.salary, u.carried_cargo, u.carried_cash, state]
	else:
		var names: Array = []
		for u in selected:
			names.append("%s (%d HP)" % [u.unit_name, int(u.hp)])
		info.text = "%d selected: %s" % [selected.size(), ", ".join(names)]


func update_economy(money: int, morale: float, payroll_in: float) -> void:
	var label: Label = $EconomyInfo
	var morale_str := "Morale %d%%" % int(morale)
	if morale < 50.0:
		morale_str = "[LOW] " + morale_str
	label.text = "$%d | %s | Payroll %ds" % [money, morale_str, int(payroll_in)]


func set_vehicle_info(v: Vehicle) -> void:
	var info: Label = $SelectionInfo
	info.text = "%s | HP %d/%d | Seats %d/%d | Cargo %d/%d" % [
		v.vdata.display_name, int(v.hp), int(v.vdata.max_hp),
		v.passengers.size(), v.vdata.seat_capacity,
		v.carried_cargo, v.vdata.cargo_capacity]


func update_heat(heat: float, dea_active: bool) -> void:
	var label: Label = $HeatInfo
	if dea_active:
		label.text = "DEA ACTIVE!"
		label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif heat >= 60.0:
		label.text = "HEAT %d%% - LAY LOW!" % int(heat)
		label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	else:
		label.text = "Heat %d%%" % int(heat)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func show_end_screen(won: bool, reason: String, summary: Dictionary) -> void:
	var panel := $EndScreen as Control
	panel.visible = true
	var title: Label = $EndScreen/Title
	title.text = "VICTORY" if won else "DEFEAT"
	title.add_theme_color_override("font_color",
		Color(0.4, 1, 0.4) if won else Color(1, 0.3, 0.3))
	var body: Label = $EndScreen/Summary
	body.text = "%s\n\nCampaign: %s\nKills: %d\nMoney earned: $%d\nMC level: %d\nUnits: %d" % [
		reason, summary["campaign"], summary["kills"],
		summary["money_earned"], summary["mc_level"], summary["units"]]


func flash(text: String, warning := false) -> void:
	_flash_label.text = text
	_flash_label.modulate = Color(1, 0.4, 0.4, 1) if warning else Color(1, 1, 1, 1)
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(1.2)
	_flash_tween.tween_property(_flash_label, "modulate:a", 0.0, 0.6)


func _on_resume_pressed() -> void:
	get_parent()._toggle_pause()


func _on_restart_pressed() -> void:
	get_parent().restart()


func _on_quit_to_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_ability_q() -> void:
	get_parent()._use_ability_q()


func _on_ability_w() -> void:
	get_parent()._use_ability_w()


func _process(_delta: float) -> void:
	# Update ability button labels with cooldowns.
	var game := get_parent()
	var q: Button = $AbilityBar/AbilityQ
	var w: Button = $AbilityBar/AbilityW
	var q_names := {"campaign_juan": "Assassinate", "campaign_fauzi": "Deceive",
		"campaign_atha": "Surge", "campaign_nabil": "Grenade"}
	var w_names := {"campaign_juan": "TactLink", "campaign_fauzi": "VehCmd",
		"campaign_atha": "Bottle", "campaign_nabil": "Aura"}
	var cid := String(game.campaign.id) if game.campaign else "campaign_juan"
	q.text = "Q: %s" % q_names.get(cid, "?")
	w.text = "W: %s" % w_names.get(cid, "?")
	if game.ability_q_cd > 0:
		q.text += " (%.0f)" % game.ability_q_cd
		q.disabled = true
	else:
		q.disabled = false
	if game.ability_w_cd > 0:
		w.text += " (%.0f)" % game.ability_w_cd
		w.disabled = true
	else:
		w.disabled = false


func _on_save_pressed() -> void:
	SaveSystem.save_game(get_parent(), "quicksave")
	flash("Game saved.")


func _on_load_pressed() -> void:
	if SaveSystem.load_game(get_parent(), "quicksave"):
		flash("Game loaded.")
	else:
		flash("No save found.")
