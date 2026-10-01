extends Node
## Per-unit tactical AI decision layer (Prompt Dasar MVP5 "TACTICAL").
## Deliberately thin: move/cover/reload/suppression/retreat/revive are
## already real, tested mechanics on BwUnit itself (from MVP1/2); this
## controller only adds the *decision-making* MVP5 asks for on top —
## which target to engage, when to flank instead of walking straight
## in, when to bail out of a fight proactively, when to break off and
## protect the Main Character, and reacting to incoming grenades — by
## calling the unit's existing public order_* methods. It never touches
## combat resolution itself.
##
## Attach one instance as a child of any BwUnit that should be
## AI-controlled (works for both a full AI faction's roster and, if
## ever wanted, a single hostile squad) and set `unit`/`knowledge`/
## `difficulty` before it starts ticking.

signal decision_made(reason: String)

const DECIDE_INTERVAL_FLOOR_SEC := 0.35
const FLANK_OFFSET_RATIO := 0.5
const GRENADE_SAFETY_MARGIN_PX := 40.0
const PROTECT_MC_RADIUS_PX := 260.0

var unit: BwUnit = null
var knowledge: Node = null # FactionKnowledge for this unit's own faction
var difficulty: DifficultyData = null
var main_character_getter: Callable = Callable() # Callable() -> BwUnit or null

var last_decision_reason: String = ""
var _decide_timer: float = 0.0
var _flank_point = null
var _avoiding_grenade_until_sec: float = -1.0
var _clock_sec: float = 0.0
var _battlefield_events: Node = null


func _ready() -> void:
	set_physics_process(true)
	var tree := get_tree()
	if tree:
		_battlefield_events = tree.root.get_node_or_null("BattlefieldEvents")
		if _battlefield_events:
			_battlefield_events.grenade_incoming.connect(_on_grenade_incoming)


func _physics_process(delta: float) -> void:
	_clock_sec += delta
	if unit == null or not is_instance_valid(unit) or unit.state == BwUnit.State.DEAD:
		return
	if _avoiding_grenade_until_sec > _clock_sec:
		return # mid-dodge; let the move order already issued play out
	var interval: float = max(DECIDE_INTERVAL_FLOOR_SEC, difficulty.decision_interval_sec if difficulty else 1.0)
	_decide_timer -= delta
	if _decide_timer > 0.0:
		return
	_decide_timer = interval
	_decide()


func _decide() -> void:
	if unit.state == BwUnit.State.DOWNED or unit.state == BwUnit.State.EXECUTING or unit.state == BwUnit.State.RECRUITING or unit.state == BwUnit.State.INTERACTING:
		return # a channeled/incapacitated state in progress; don't interrupt it

	# Proactive retreat: bail out of a bad fight before being forced to
	# by the (already-existing) suppression-retreat mechanic.
	var retreat_threshold: float = difficulty.retreat_hp_threshold if difficulty else 0.3
	if unit.hp / unit.max_hp <= retreat_threshold and unit.state == BwUnit.State.ATTACKING:
		unit.order_stop()
		_set_reason("HP %.0f%% <= retreat threshold %.0f%%: disengaging." % [unit.hp / unit.max_hp * 100.0, retreat_threshold * 100.0])
		return

	# Revive a downed ally if one is nearby and it's currently safe
	# enough to do so (no fresh, close enemy).
	var downed_ally := _find_nearby_downed_ally()
	if downed_ally and not _has_nearby_threat(unit.global_position, 220.0):
		unit.order_revive(downed_ally)
		_set_reason("Reviving downed ally %s (area clear)." % downed_ally.display_name)
		return

	# Protect Main Character: if our MC is under threat and we aren't
	# already fighting something more urgent, retarget to whatever's
	# threatening the MC.
	var mc = main_character_getter.call() if main_character_getter.is_valid() else null
	if mc and is_instance_valid(mc) and mc.state != BwUnit.State.DEAD:
		var mc_threat = _find_nearest_known_enemy(mc.global_position, PROTECT_MC_RADIUS_PX)
		if mc_threat and not (unit.state == BwUnit.State.ATTACKING and unit.attack_target == mc_threat):
			unit.order_attack(mc_threat)
			_set_reason("Protecting Main Character: engaging threat near %s." % mc.display_name)
			return

	# Target priority among known (fog-of-war-filtered) enemies.
	var best_target = _pick_priority_target()
	if best_target == null:
		return
	if unit.state == BwUnit.State.ATTACKING and unit.attack_target == best_target:
		return # already doing the right thing

	# Flank instead of a straight walk-in when we're not yet in weapon
	# range (a real approach-angle decision, not just "attack-move").
	var weapon := unit._resolve_active_weapon()
	var range_px: float = weapon.range_px if weapon else unit.unarmed_range
	var dist: float = unit.global_position.distance_to(best_target.global_position)
	if dist > range_px * 1.5:
		var flank_point: Vector2 = _compute_flank_point(unit.global_position, best_target.global_position)
		unit.order_move(flank_point)
		_flank_point = flank_point
		_set_reason("Flanking toward %s before engaging %s." % [flank_point, best_target.tier_label])
	else:
		unit.order_attack(best_target)
		_set_reason("Engaging %s (priority target, dist %.0f)." % [best_target.tier_label, dist])


## ---------------------------------------------------------------
## Target priority (Prompt Dasar "Target priority")
## ---------------------------------------------------------------
func _pick_priority_target():
	if knowledge == null:
		return null
	var candidates: Array = knowledge.get_visible_enemy_units()
	if candidates.is_empty():
		return null
	var quality: float = difficulty.decision_quality if difficulty else 0.6
	if randf() > quality:
		# Lower-skill AI sometimes just picks any valid target instead
		# of the objectively best one — this is the literal mechanism
		# behind "Hard lebih cerdas, bukan curang": less consistent
		# decision-making, not worse dice rolls or less vision.
		return candidates[randi() % candidates.size()]

	var best = null
	var best_score := -INF
	for c in candidates:
		if not is_instance_valid(c) or c.state == BwUnit.State.DEAD or c.state == BwUnit.State.DOWNED:
			continue
		var score := 0.0
		var dist: float = unit.global_position.distance_to(c.global_position)
		score -= dist * 0.02
		score += (1.0 - c.hp / max(c.max_hp, 1.0)) * 40.0 # prefer finishing off low-HP targets
		if c.tier_label == "MC":
			score += 60.0
		elif c.tier_label == "SPECIAL":
			score += 30.0
		if best == null or score > best_score:
			best = c
			best_score = score
	return best


func _compute_flank_point(from_pos: Vector2, target_pos: Vector2) -> Vector2:
	var to_target: Vector2 = target_pos - from_pos
	var side: float = 1.0 if (randi() % 2 == 0) else -1.0
	var perpendicular: Vector2 = to_target.orthogonal().normalized() * side
	var approach_point: Vector2 = from_pos + to_target * FLANK_OFFSET_RATIO + perpendicular * (to_target.length() * 0.35)
	return approach_point


func _find_nearby_downed_ally() -> BwUnit:
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: BwUnit = null
	var nearest_dist := 300.0
	for n in tree.get_nodes_in_group("bw_units"):
		if not (n is BwUnit) or not is_instance_valid(n):
			continue
		if n.faction_side != unit.faction_side or n.state != BwUnit.State.DOWNED:
			continue
		var d: float = unit.global_position.distance_to(n.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = n
	return nearest


func _has_nearby_threat(pos: Vector2, radius: float) -> bool:
	if knowledge == null:
		return false
	return knowledge.known_enemy_count_near(pos, radius) > 0


func _find_nearest_known_enemy(pos: Vector2, radius: float):
	if knowledge == null:
		return null
	var best = null
	var best_dist := radius
	for c in knowledge.get_visible_enemy_units():
		if not is_instance_valid(c) or c.state == BwUnit.State.DEAD or c.state == BwUnit.State.DOWNED:
			continue
		var d: float = pos.distance_to(c.global_position)
		if d <= best_dist:
			best_dist = d
			best = c
	return best


## ---------------------------------------------------------------
## Grenade avoidance (Prompt Dasar "Grenade avoidance")
## ---------------------------------------------------------------
func _on_grenade_incoming(thrower_faction: StringName, impact_pos: Vector2, radius: float, fuse_sec: float) -> void:
	if unit == null or not is_instance_valid(unit) or thrower_faction == unit.faction_side:
		return
	var danger_radius: float = radius + GRENADE_SAFETY_MARGIN_PX
	if unit.global_position.distance_to(impact_pos) > danger_radius:
		return
	var away: Vector2 = (unit.global_position - impact_pos)
	if away.length() < 0.01:
		away = Vector2(1, 0)
	var safe_point: Vector2 = impact_pos + away.normalized() * (danger_radius + 60.0)
	unit.order_move(safe_point)
	_avoiding_grenade_until_sec = _clock_sec + max(0.2, fuse_sec)
	_set_reason("Grenade incoming at %s: moving clear." % impact_pos)


func _set_reason(reason: String) -> void:
	last_decision_reason = reason
	decision_made.emit(reason)
