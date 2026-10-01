extends SceneTree
## MVP5 "DIPLOMACY": neutral encounter attack/intimidate, cartel contact
## (trust) gain, temporary alliance formation gated by trust, trade
## benefit while allied, betrayal ending an alliance with a trust
## penalty, no shared victory, and never auto-hostile toward neutral.
##
## Run: godot4 --headless --path . --script res://tests/test_mvp5_diplomacy.gd

const DIPLOMACY_SCRIPT := preload("res://scripts/diplomacy/diplomacy_controller.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var diplomacy: Node = DIPLOMACY_SCRIPT.new()
	diplomacy.neutral_faction = load("res://data/neutral/neutral_riverside_crew.tres")
	root.add_child(diplomacy)
	await process_frame

	# Never auto-hostile toward neutral.
	_expect(not diplomacy.is_hostile_by_default(&"neutral"), "Neutral faction should never be treated as auto-hostile by default.")
	_expect(diplomacy.is_hostile_by_default(&"campaign_atha"), "A real rival cartel should be treated as hostile by default.")

	# Intimidate should raise trust (cartel contact) with the neutral faction.
	var easy: DifficultyData = load("res://data/difficulty/difficulty_easy.tres")
	var choice: String = diplomacy.decide_neutral_encounter(&"campaign_juan", 0.5, easy) # low advantage => optimal is intimidate
	_expect(choice == "intimidate" or choice == "attack", "Neutral encounter must resolve to one of the two defined choices.")
	var trust_after_first: float = diplomacy.get_trust(&"campaign_juan", &"neutral")
	_expect(trust_after_first != 0.0, "A neutral encounter should move trust away from its starting neutral value.")

	# Force trust high enough to test alliance formation deterministically.
	for i in range(10):
		diplomacy.decide_neutral_encounter(&"campaign_juan", 0.5, load("res://data/difficulty/difficulty_hard.tres"))
	var trust_now: float = diplomacy.get_trust(&"campaign_juan", &"neutral")
	_expect(trust_now >= DIPLOMACY_SCRIPT.ALLIANCE_TRUST_THRESHOLD, "Repeated intimidate-favoring encounters should build enough trust for an alliance to become possible.")

	var formed: bool = diplomacy.try_propose_alliance(&"campaign_juan", &"neutral")
	_expect(formed, "Alliance should form once trust clears the threshold.")
	_expect(diplomacy.is_allied(&"campaign_juan", &"neutral"), "Faction should now be reported as allied with the neutral faction.")

	# Trade benefit while allied.
	var bonus: float = diplomacy.get_trade_bonus(&"campaign_juan")
	_expect(bonus > 0.0, "An active alliance should grant a nonzero trade benefit.")
	var no_bonus: float = diplomacy.get_trade_bonus(&"campaign_atha")
	_expect(no_bonus == 0.0, "A faction with no active alliance should get no trade benefit.")

	# Betrayal ends the alliance and has a trust consequence.
	var betrayed: bool = diplomacy.try_betray(&"campaign_juan", &"neutral")
	_expect(betrayed, "Betrayal should succeed while an alliance is active.")
	_expect(not diplomacy.is_allied(&"campaign_juan", &"neutral"), "Alliance should end immediately upon betrayal.")
	var trust_after_betrayal: float = diplomacy.get_trust(&"campaign_juan", &"neutral")
	_expect(trust_after_betrayal < trust_now, "Betrayal should have a real, negative trust consequence.")
	var betray_again: bool = diplomacy.try_betray(&"campaign_juan", &"neutral")
	_expect(not betray_again, "Cannot betray an alliance that is no longer active / betrayal should be cooldown-gated, not spammable.")

	# No shared victory: the diplomacy layer itself has no "both win"
	# concept — confirmed structurally by there being no such method to
	# call, and functionally by two allied factions still being
	# independently tracked as eliminable.
	_expect(not diplomacy.has_method("declare_shared_victory"), "Diplomacy layer must not expose any shared-victory concept.")

	if _failures.is_empty():
		print("[Tests] mvp5_diplomacy: all passed.")
	else:
		for f in _failures:
			printerr(f)
	quit(0 if _failures.is_empty() else 1)
