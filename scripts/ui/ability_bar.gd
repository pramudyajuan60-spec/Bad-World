extends Control
## Main Character ability bar (MVP4 acceptance criterion: "Ability
## mempunyai cooldown, feedback, dan counterplay" needs a player-facing
## way to see/trigger this). Minimal button-row implementation; final
## themed UI art is MVP6 scope (see docs/PLACEHOLDER_REGISTER.md).
##
## AURA abilities never appear here (always-on, no button needed).
## ACTIVE_AOE abilities (Throw Drug Bottle) "arm" a targeting mode on
## CommandController and require a follow-up ground right-click,
## mirroring the existing grenade-throw flow.

var get_main_character: Callable = Callable()
var command_controller: Node = null

var _buttons: Dictionary = {} # ability id -> Button
var _built_for: BwUnit = null


func refresh() -> void:
	if not get_main_character.is_valid():
		return
	var mc = get_main_character.call()
	if mc == null or not is_instance_valid(mc):
		visible = false
		return
	visible = true
	if mc != _built_for:
		_rebuild(mc)
	for a in mc.abilities:
		if a.category == AbilityData.Category.AURA:
			continue
		var btn: Button = _buttons.get(a.id)
		if btn == null:
			continue
		var remaining: float = mc.get_ability_cooldown_remaining(a.id)
		if remaining > 0.0:
			btn.text = "%s (%.0fs)" % [a.display_name, remaining]
			btn.disabled = true
		else:
			btn.text = a.display_name
			btn.disabled = false


func _rebuild(mc: BwUnit) -> void:
	_built_for = mc
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 6)
	for a in mc.abilities:
		if a.category == AbilityData.Category.AURA:
			continue
		var btn := Button.new()
		btn.text = a.display_name
		btn.custom_minimum_size = Vector2(220, 36)
		btn.tooltip_text = a.description + "\n\nCounterplay: " + a.counterplay_note
		btn.pressed.connect(_on_ability_pressed.bind(mc, a))
		vbox.add_child(btn)
		_buttons[a.id] = btn


func _on_ability_pressed(mc: BwUnit, ability: AbilityData) -> void:
	if ability.category == AbilityData.Category.ACTIVE_AOE:
		if command_controller:
			command_controller.arm_ability_targeting(ability.id, mc)
	else:
		mc.try_use_ability(ability.id)
