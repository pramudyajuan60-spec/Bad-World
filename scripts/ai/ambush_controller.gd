extends Node
## Ambush behavior for one AI faction (Prompt Dasar MVP5 "AMBUSH": needs
## intel + tactical advantage, a cooldown, a utility threshold, and the
## ability to cancel if the situation changes). Deliberately separate
## from FactionStrategicAI (which owns the overall economy/raid loop)
## since ambush has its own multi-phase state machine (arm -> wait ->
## trigger/cancel) that would otherwise clutter the strategic tick.

signal ambush_triggered(chokepoint: Vector2, squad: Array)
signal ambush_cancelled(reason: String)

enum State { IDLE, ARMED, COMMITTED }

const TRIGGER_RADIUS_PX := 140.0
const MIN_SQUAD_SIZE := 2

var faction_side: StringName = &""
var knowledge: Node = null # FactionKnowledge
var difficulty: DifficultyData = null
## Array[Vector2] candidate chokepoints (bridge/alley/dealer-route/
## narrow-road positions) supplied by the owning scene — these are a
## world-layout concern, not something this generic controller invents.
var chokepoints: Array = []
var roster_getter: Callable = Callable() # Callable() -> Array[BwUnit], this faction's idle/available units

var state: State = State.IDLE
var last_reason: String = ""
var _cooldown_timer: float = 0.0
var _armed_point: Vector2 = Vector2.ZERO
var _armed_squad: Array = []
var _armed_at_sec: float = 0.0
var _armed_intel_unit_id: StringName = &""
var _clock_sec: float = 0.0

const COOLDOWN_SEC := 60.0


func _physics_process(delta: float) -> void:
	_clock_sec += delta
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	match state:
		State.IDLE:
			_try_arm()
		State.ARMED:
			_update_armed()
		State.COMMITTED:
			pass # squad is fighting; nothing left for this controller to decide


## ---------------------------------------------------------------
## Arming: requires intel (a known, still-fresh enemy near a
## chokepoint) AND tactical advantage (our nearby available squad
## outnumbers/outguns what intel suggests is coming), gated by a
## difficulty-scaled utility threshold so it isn't spammed.
## ---------------------------------------------------------------
func _try_arm() -> void:
	if _cooldown_timer > 0.0 or knowledge == null or chokepoints.is_empty():
		return
	if not roster_getter.is_valid():
		return
	var available: Array = roster_getter.call()
	if available.size() < MIN_SQUAD_SIZE:
		return

	for point in chokepoints:
		var intel_unit_id := _find_fresh_intel_near(point)
		if intel_unit_id == &"":
			continue
		var expected_enemy_count: int = max(1, knowledge.known_enemy_count_near(point, TRIGGER_RADIUS_PX * 2.0))
		var utility: float = _score_ambush(available.size(), expected_enemy_count)
		var threshold: float = 0.5 * (difficulty.utility_threshold_mult if difficulty else 1.0)
		if utility < threshold:
			continue
		_armed_squad = available.slice(0, min(available.size(), expected_enemy_count + 1))
		_armed_point = point
		_armed_at_sec = _clock_sec
		_armed_intel_unit_id = intel_unit_id
		state = State.ARMED
		for u in _armed_squad:
			if is_instance_valid(u):
				u.order_move(point)
		last_reason = "Arming ambush at %s: utility %.2f >= threshold %.2f (squad %d vs expected %d)." % [point, utility, threshold, _armed_squad.size(), expected_enemy_count]
		return


func _score_ambush(squad_size: int, expected_enemy_count: int) -> float:
	# Simple force-ratio utility: bigger advantage -> higher score.
	return clampf(float(squad_size) / float(max(expected_enemy_count, 1)) - 0.5, 0.0, 2.0)


func _find_fresh_intel_near(point: Vector2) -> StringName:
	for entry in knowledge.get_known_enemies():
		if _clock_sec - entry["last_seen_sec"] > FactionKnowledgeStaleWindow():
			continue
		if entry["position"].distance_to(point) <= TRIGGER_RADIUS_PX * 3.0:
			var ref = entry.get("unit_ref")
			if ref and is_instance_valid(ref):
				return ref.unit_id
	return &""


## Small helper so this file doesn't need to know FactionKnowledge's
## internal STALE_AFTER_SEC constant name/path explicitly.
func FactionKnowledgeStaleWindow() -> float:
	return knowledge.STALE_AFTER_SEC if knowledge else 20.0


## ---------------------------------------------------------------
## Armed: wait for the enemy to actually reach the chokepoint (real
## trigger), auto-cancel if intel goes stale or the squad itself is no
## longer viable (Prompt Dasar: "AI dapat membatalkan ambush jika
## situasi berubah").
## ---------------------------------------------------------------
func _update_armed() -> void:
	_armed_squad = _armed_squad.filter(func(u): return is_instance_valid(u) and u.state != BwUnit.State.DEAD and u.state != BwUnit.State.DOWNED)
	if _armed_squad.size() < MIN_SQUAD_SIZE:
		_cancel("Squad no longer viable (losses before trigger).")
		return

	var patience: float = difficulty.ambush_intel_patience_sec if difficulty else 25.0
	if _clock_sec - _armed_at_sec > patience:
		_cancel("Intel/opportunity went stale before the enemy arrived.")
		return

	var triggering_enemy = null
	for c in knowledge.get_visible_enemy_units():
		if is_instance_valid(c) and c.global_position.distance_to(_armed_point) <= TRIGGER_RADIUS_PX:
			triggering_enemy = c
			break
	if triggering_enemy == null:
		return # still waiting

	state = State.COMMITTED
	_cooldown_timer = COOLDOWN_SEC
	for u in _armed_squad:
		if is_instance_valid(u):
			u.order_attack(triggering_enemy)
	last_reason = "Ambush triggered at %s against %s." % [_armed_point, triggering_enemy.tier_label]
	ambush_triggered.emit(_armed_point, _armed_squad)
	# Committed squads return to normal strategic control once combat
	# resolves; this controller goes back to scouting for the next one.
	state = State.IDLE
	_armed_squad = []


func _cancel(reason: String) -> void:
	state = State.IDLE
	_cooldown_timer = COOLDOWN_SEC * 0.5 # a cancelled ambush still costs some patience, just less than a spent one
	for u in _armed_squad:
		if is_instance_valid(u):
			u.order_stop()
	_armed_squad = []
	last_reason = reason
	ambush_cancelled.emit(reason)
