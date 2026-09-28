extends Node
## Per-faction fog-of-war and intel memory (Prompt Dasar MVP5
## "INFORMATION": "Fog of war", "Last known position", "Threat memory",
## "Intel events", "AI tidak omniscient"). One instance owns exactly one
## AI-controlled faction's *belief state* about the world; every
## strategic/tactical AI decision in this MVP is required to query this
## object rather than iterating the live enemy list directly, so "the
## AI doesn't cheat" is a structural property, not just a promise.
##
## Visibility model: an enemy unit is "visible" this tick if it is
## within vision_range_px of at least one friendly unit AND passes a
## line-of-sight raycast (mirrors BwUnit._has_line_of_sight, duplicated
## here rather than reused since that method is private and tied to a
## specific attacker/target pair, not a batch visibility scan).

signal enemy_spotted(unit_id: StringName, position: Vector2)
signal enemy_lost(unit_id: StringName)
signal intel_event(text: String)

## seconds a last-known-position stays "fresh" before being treated as
## stale (still remembered, but flagged low-confidence) for ambush/
## strategic gating. Not difficulty-dependent — vision quality itself
## never cheats; see docs/BALANCE.md.
const STALE_AFTER_SEC := 20.0
## seconds after going stale that an entry is forgotten entirely.
const FORGET_AFTER_SEC := 90.0
const MAX_INTEL_EVENTS := 30

var owner_faction_side: StringName = &""
## Callable() -> Array[BwUnit]; the faction's own currently-alive units.
var own_units_getter: Callable = Callable()
## Callable() -> Array[BwUnit]; every potentially-visible unit in the
## world (both other AI factions and the player), pre-filter.
var world_units_getter: Callable = Callable()

## unit_id (StringName) -> {position, last_seen_sec, faction_side, tier_label, is_visible_now}
var _known: Dictionary = {}
var _intel_log: Array[String] = []
var _clock_sec: float = 0.0


func _physics_process(delta: float) -> void:
	_clock_sec += delta
	_refresh_visibility()
	_age_out_stale_entries()


func _refresh_visibility() -> void:
	if not own_units_getter.is_valid() or not world_units_getter.is_valid():
		return
	var own_units: Array = own_units_getter.call()
	var world_units: Array = world_units_getter.call()
	var currently_visible: Dictionary = {} # unit_id -> true

	for candidate in world_units:
		if not is_instance_valid(candidate) or candidate.faction_side == owner_faction_side:
			continue
		var spotted := false
		for own in own_units:
			if not is_instance_valid(own):
				continue
			var dist: float = own.global_position.distance_to(candidate.global_position)
			if dist <= own.vision_range_px and _has_line_of_sight(own, candidate):
				spotted = true
				break
		if spotted:
			currently_visible[candidate.unit_id] = true
			var was_known: bool = _known.has(candidate.unit_id)
			_known[candidate.unit_id] = {
				"unit_id": candidate.unit_id,
				"position": candidate.global_position,
				"last_seen_sec": _clock_sec,
				"faction_side": candidate.faction_side,
				"tier_label": candidate.tier_label,
				"is_visible_now": true,
				"unit_ref": candidate,
			}
			if not was_known:
				enemy_spotted.emit(candidate.unit_id, candidate.global_position)
				_log_intel("Spotted %s near (%d, %d)." % [candidate.tier_label, int(candidate.global_position.x), int(candidate.global_position.y)])

	for unit_id in _known.keys():
		if not currently_visible.has(unit_id):
			_known[unit_id]["is_visible_now"] = false
			_known[unit_id]["unit_ref"] = null


func _has_line_of_sight(from_unit, to_unit) -> bool:
	var space_state = from_unit.get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from_unit.global_position, to_unit.global_position)
	params.collision_mask = 2 # obstacles only, matches BwUnit's own scheme
	params.exclude = [from_unit]
	var result = space_state.intersect_ray(params)
	return result.is_empty()


func _age_out_stale_entries() -> void:
	var forgotten: Array = []
	for unit_id in _known.keys():
		var entry: Dictionary = _known[unit_id]
		if entry["is_visible_now"]:
			continue
		if _clock_sec - entry["last_seen_sec"] > FORGET_AFTER_SEC:
			forgotten.append(unit_id)
	for unit_id in forgotten:
		_known.erase(unit_id)
		enemy_lost.emit(unit_id)


## ---------------------------------------------------------------
## Query API — the only interface AI decision code should use.
## ---------------------------------------------------------------
func is_known(unit_id: StringName) -> bool:
	return _known.has(unit_id)


func is_stale(unit_id: StringName) -> bool:
	if not _known.has(unit_id):
		return true
	return _clock_sec - _known[unit_id]["last_seen_sec"] > STALE_AFTER_SEC


func get_known_enemies() -> Array:
	var result: Array = []
	for unit_id in _known.keys():
		result.append(_known[unit_id])
	return result


func get_visible_enemy_units() -> Array:
	var result: Array = []
	for unit_id in _known.keys():
		var entry: Dictionary = _known[unit_id]
		if entry["is_visible_now"] and entry["unit_ref"] != null and is_instance_valid(entry["unit_ref"]):
			result.append(entry["unit_ref"])
	return result


func get_last_known_position(unit_id: StringName):
	if not _known.has(unit_id):
		return null
	return _known[unit_id]["position"]


func known_enemy_count_near(pos: Vector2, radius: float, fresh_only: bool = true) -> int:
	var count := 0
	for unit_id in _known.keys():
		var entry: Dictionary = _known[unit_id]
		if fresh_only and _clock_sec - entry["last_seen_sec"] > STALE_AFTER_SEC:
			continue
		if entry["position"].distance_to(pos) <= radius:
			count += 1
	return count


func _log_intel(text: String) -> void:
	_intel_log.append(text)
	if _intel_log.size() > MAX_INTEL_EVENTS:
		_intel_log.pop_front()
	intel_event.emit(text)


func get_intel_log() -> Array[String]:
	return _intel_log
