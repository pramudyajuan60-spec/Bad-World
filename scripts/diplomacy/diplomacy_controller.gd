extends Node
## Cross-faction diplomacy (Prompt Dasar MVP5 "DIPLOMACY"). Owned once
## per match (not per faction) since relationships are inherently
## pairwise. Tracks, for every unordered pair of factions (including
## the shared NeutralFactionData "third party"):
##   - trust: float, -1..1, drifts toward 0 slowly and moves sharply on
##     betrayal or on honoring a trade for a while.
##   - allied: bool, a temporary non-aggression + trade-bonus pact.
##
## Explicitly enforces "Tidak ada shared victory": nothing in this file
## ever marks two factions as jointly winning: alliance only gates
## hostility/utility checks elsewhere (e.g. AmbushController/strategic
## raid code should skip allied targets — wiring left to callers) and
## grants a dealer trade bonus; the match's own win condition (see
## ai_match_arena.gd) only ever asks "is faction X eliminated?".

signal alliance_formed(a: StringName, b: StringName)
signal alliance_broken(a: StringName, b: StringName, betrayed: bool)
signal neutral_encounter_resolved(faction: StringName, choice: String, trust_delta: float)

const TRUST_MIN := -1.0
const TRUST_MAX := 1.0
const ALLIANCE_TRUST_THRESHOLD := 0.35
const BETRAYAL_TRUST_THRESHOLD := -0.5
const ALLIANCE_MIN_DURATION_SEC := 60.0
const ALLIANCE_MAX_DURATION_SEC := 240.0
const BETRAYAL_COOLDOWN_SEC := 120.0
const TRUST_DECAY_PER_SEC := 0.002 # slow drift toward 0

## key: "a|b" (alphabetically sorted faction_side strings) -> {trust, allied, ally_expires_sec, betrayal_cooldown}
var _relations: Dictionary = {}
var _clock_sec: float = 0.0
var neutral_faction: NeutralFactionData = null


func _physics_process(delta: float) -> void:
	_clock_sec += delta
	for key in _relations.keys():
		var rel: Dictionary = _relations[key]
		if rel["trust"] > 0.0:
			rel["trust"] = max(0.0, rel["trust"] - TRUST_DECAY_PER_SEC * delta)
		elif rel["trust"] < 0.0:
			rel["trust"] = min(0.0, rel["trust"] + TRUST_DECAY_PER_SEC * delta)
		if rel.get("betrayal_cooldown", 0.0) > 0.0:
			rel["betrayal_cooldown"] -= delta
		if rel["allied"] and _clock_sec >= rel.get("ally_expires_sec", 0.0):
			rel["allied"] = false
			alliance_broken.emit(_first_of(key), _second_of(key), false)


func _key(a: StringName, b: StringName) -> String:
	var sa := String(a)
	var sb := String(b)
	return "%s|%s" % [sa, sb] if sa <= sb else "%s|%s" % [sb, sa]


func _first_of(key: String) -> StringName:
	return StringName(key.split("|")[0])


func _second_of(key: String) -> StringName:
	return StringName(key.split("|")[1])


func _get_relation(a: StringName, b: StringName) -> Dictionary:
	var key := _key(a, b)
	if not _relations.has(key):
		_relations[key] = {"trust": 0.0, "allied": false, "ally_expires_sec": 0.0, "betrayal_cooldown": 0.0}
	return _relations[key]


func get_trust(a: StringName, b: StringName) -> float:
	return _get_relation(a, b)["trust"]


func is_allied(a: StringName, b: StringName) -> bool:
	return _get_relation(a, b)["allied"]


## Trade benefit granted to an allied faction's dealer sales while the
## alliance holds (Prompt Dasar "Trade benefit"). Looks up whichever
## alliance this faction currently holds, if any.
func get_trade_bonus(faction_side: StringName) -> float:
	if neutral_faction == null:
		return 0.0
	for key in _relations.keys():
		var rel: Dictionary = _relations[key]
		if not rel["allied"]:
			continue
		if _first_of(key) == faction_side or _second_of(key) == faction_side:
			return neutral_faction.allied_dealer_value_bonus
	return 0.0


## ---------------------------------------------------------------
## Neutral encounter: attack or intimidate (Prompt Dasar "Neutral
## encounter", "Attack atau Intimidate", "Memperoleh cartel contact").
## Utility-gated by difficulty decision_quality, same as tactical
## target-priority: a lower-skill AI sometimes makes the objectively
## worse call.
## ---------------------------------------------------------------
func decide_neutral_encounter(faction_side: StringName, own_force_advantage: float, difficulty: DifficultyData) -> String:
	var quality: float = difficulty.decision_quality if difficulty else 0.6
	# Intimidate is the better choice unless we clearly outmatch them
	# (attack trades a one-time gain for losing the contact); a
	# low-quality roll ignores that and picks the opposite.
	var optimal: String = "attack" if own_force_advantage >= 2.0 else "intimidate"
	var choice: String = optimal if randf() <= quality else ("intimidate" if optimal == "attack" else "attack")
	var trust_delta: float = 0.3 if choice == "intimidate" else -0.4
	var rel := _get_relation(faction_side, &"neutral")
	rel["trust"] = clampf(rel["trust"] + trust_delta, TRUST_MIN, TRUST_MAX)
	neutral_encounter_resolved.emit(faction_side, choice, trust_delta)
	return choice


## ---------------------------------------------------------------
## Alliance / trust / betrayal (Prompt Dasar "Alliance sementara",
## "Trust", "Betrayal").
## ---------------------------------------------------------------
func try_propose_alliance(a: StringName, b: StringName) -> bool:
	var rel := _get_relation(a, b)
	if rel["allied"] or rel["trust"] < ALLIANCE_TRUST_THRESHOLD:
		return false
	rel["allied"] = true
	rel["ally_expires_sec"] = _clock_sec + randf_range(ALLIANCE_MIN_DURATION_SEC, ALLIANCE_MAX_DURATION_SEC)
	alliance_formed.emit(a, b)
	return true


## Betraying an ally for immediate gain (e.g. raiding their economy
## mid-alliance). Gated by a cooldown and requires the betrayer to
## actually be allied right now, so it can't be spammed as a free
## surprise-attack toggle.
func try_betray(a: StringName, b: StringName) -> bool:
	var rel := _get_relation(a, b)
	if not rel["allied"] or rel.get("betrayal_cooldown", 0.0) > 0.0:
		return false
	rel["allied"] = false
	rel["trust"] = clampf(rel["trust"] - 0.9, TRUST_MIN, TRUST_MAX)
	rel["betrayal_cooldown"] = BETRAYAL_COOLDOWN_SEC
	alliance_broken.emit(a, b, true)
	return true


## AI factions should never treat a neutral third party as an
## auto-hostile default target (Prompt Dasar acceptance: "AI tidak
## menyerang faction neutral otomatis") — callers gate targeting with
## this rather than assuming any non-self faction is fair game.
func is_hostile_by_default(faction_side: StringName) -> bool:
	return faction_side != &"neutral"
