extends Node
## Contextual tutorial hints (Prompt Dasar MVP6 item 4: "Tutorial
## contextual" covering selection, movement, recruitment, equipment,
## ammo, factory/dealer/bank, vehicle, patrol, defend, and Main
## Character protection).
##
## Each hint id is shown at most once ever — tracked in
## UserPrefsService as an install-wide "seen" set, not tied to a save
## slot or campaign, since the goal (Prompt Dasar acceptance: "Pemain
## baru dapat memahami loop dasar melalui tutorial") is teaching a new
## player the loop once, not re-teaching it on every campaign restart.
## Documented assumption — see docs/TECH_DECISIONS.md.
##
## Queued one at a time (via `hint_shown`/`dismiss_current`) so two
## hints triggered the same frame (e.g. first selection + first move)
## never overlap on screen.

signal hint_shown(id: StringName, title: String, body: String)

const HINTS := {
	&"selection": ["Selecting Units", "Left click a unit to select it, drag to box-select a group, Shift+click to add/remove, or double-click to select every unit of that tier."],
	&"movement": ["Moving Units", "Right-click open ground to move your selected units there. Press A then right-click to attack-move (engage anything along the way)."],
	&"recruitment": ["Recruitment", "New roster members queue and arrive at the Recruitment building over time, up to your faction's unit cap."],
	&"equipment": ["Equipment", "Open Inspect (top-right) to assign primary/secondary/grenade/armor from your Gun Shop or Armory inventory to any unit, even ones not currently selected."],
	&"ammo": ["Ammunition", "Units auto-reload from reserve ammo when their magazine empties. Buy more ammo/weapons at the Gun Shop (or craft at the Armory) before reserves run out."],
	&"factory_dealer_bank": ["Factory, Dealer, Bank", "Pick up cargo at your Factory (E to interact), sell it to a Drug Dealer for carried cash, then deposit that cash at the Bank — cash only counts once it's banked."],
	&"vehicle": ["Vehicles", "Right-click a friendly vehicle with units selected to mount it; press X to exit. Buy more vehicles at the Garage."],
	&"patrol": ["Patrol", "Press P then right-click a point to set a patrol route between here and there."],
	&"defend": ["Defend / Cover", "Press D to send selected units to the nearest cover and hold position there."],
	&"mc_protection": ["Protect Your Main Character", "Your Main Character is your strongest unit and can be leveled up, but if they die or are executed, the campaign ends immediately. Keep them covered."],
}

var _queue: Array = []
var _showing: bool = false


func request(id: StringName) -> void:
	if not HINTS.has(id) or UserPrefsService.has_seen_tutorial(String(id)):
		return
	for q in _queue:
		if q["id"] == id:
			return
	UserPrefsService.mark_tutorial_seen(String(id))
	var entry: Array = HINTS[id]
	_queue.append({"id": id, "title": entry[0], "body": entry[1]})
	_try_show_next()


func dismiss_current() -> void:
	_showing = false
	_try_show_next()


func _try_show_next() -> void:
	if _showing or _queue.is_empty():
		return
	_showing = true
	var next: Dictionary = _queue.pop_front()
	hint_shown.emit(next["id"], next["title"], next["body"])
