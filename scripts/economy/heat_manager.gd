extends Node
## Heat Meter + DEA response (Prompt Dasar MVP3). Simplified to a single
## global heat value for this vertical slice's one contested territory,
## rather than Prompt Dasar's full per-cluster (~35m radius) model —
## documented as an MVP3 scope simplification in docs/TECH_DECISIONS.md;
## MVP4/5 (multi-faction, full map) is the natural point to generalize
## this into real spatial clusters.

signal wave_dispatched(wave_number: int)

const COMBAT_HEAT_DURATION_SEC := 120.0 # continuous combat needed to trigger a call
const DEA_TRAVEL_SEC := 60.0
const NO_COMBAT_DECAY_SEC := 30.0
const MAX_WAVES := 2
const CLUSTER_COOLDOWN_SEC := 360.0 # 6 minutes

var in_combat: bool = false
var _combat_timer: float = 0.0
var _no_combat_timer: float = 0.0
var _dispatch_timer: float = -1.0
var waves_dispatched: int = 0
var _cooldown_timer: float = 0.0
var world_bounds: Rect2 = Rect2(-1500, -1000, 3000, 2000)
var player_position_getter: Callable = Callable()


func notify_combat_tick() -> void:
	in_combat = true
	_no_combat_timer = 0.0


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			waves_dispatched = 0
		return

	if in_combat:
		_combat_timer += delta
	_no_combat_timer += delta
	if _no_combat_timer >= NO_COMBAT_DECAY_SEC:
		in_combat = false
		_combat_timer = max(0.0, _combat_timer - delta)

	if _dispatch_timer < 0.0 and _combat_timer >= COMBAT_HEAT_DURATION_SEC and waves_dispatched < MAX_WAVES:
		_dispatch_timer = DEA_TRAVEL_SEC

	if _dispatch_timer >= 0.0:
		_dispatch_timer -= delta
		if _dispatch_timer <= 0.0:
			_dispatch_timer = -1.0
			_combat_timer = 0.0
			waves_dispatched += 1
			wave_dispatched.emit(waves_dispatched)
			if waves_dispatched >= MAX_WAVES:
				_cooldown_timer = CLUSTER_COOLDOWN_SEC


## Picks a spawn point on the world edge, far from the player (Prompt
## Dasar: "DEA tidak spawn tepat di atas pemain" / arrives via map edge).
func pick_spawn_point() -> Vector2:
	var player_pos: Vector2 = player_position_getter.call() if player_position_getter.is_valid() else Vector2.ZERO
	var candidates := [
		Vector2(world_bounds.position.x + 40, world_bounds.position.y + world_bounds.size.y * 0.5),
		Vector2(world_bounds.position.x + world_bounds.size.x - 40, world_bounds.position.y + world_bounds.size.y * 0.5),
		Vector2(world_bounds.position.x + world_bounds.size.x * 0.5, world_bounds.position.y + 40),
		Vector2(world_bounds.position.x + world_bounds.size.x * 0.5, world_bounds.position.y + world_bounds.size.y - 40),
	]
	var best: Vector2 = candidates[0]
	var best_dist := -1.0
	for c in candidates:
		var d: float = c.distance_to(player_pos)
		if d > best_dist:
			best_dist = d
			best = c
	return best
