extends SceneTree
## MVP5 acceptance: "Headless simulation dapat berjalan untuk beberapa
## match". Runs a handful of complete AiMatchArena matches between two
## fully AI-controlled factions (real economy + real combat + real
## tactical/strategic/ambush/knowledge layers) to a resolved outcome
## (one side eliminated) or a generous timeout, and checks the harness
## itself behaves sanely: matches actually resolve (not all timeouts),
## and no faction wins literally every single match by force (which
## would suggest a cheat/asymmetry bug rather than real AI decisions).
##
## This is the smoke/correctness test for the arena harness; the
## broader multi-difficulty win-rate report lives in
## tools/run_ai_winrate_report.gd (Prompt Dasar acceptance: "Laporkan
## hasil win-rate awal per faction/difficulty") since that one runs
## many more matches and takes much longer.
##
## Godot's headless physics loop otherwise paces itself close to real
## wall-clock time even with nothing to render, so a multi-hundred-
## simulated-second AI match would take that many real seconds too;
## --fixed-fps decouples simulation stepping from wall-clock pacing and
## is required to make this test (and the win-rate report tool) finish
## promptly. Discovered while calibrating this exact suite — see
## docs/TECH_DECISIONS.md "Headless AI simulation speed".
## Run: godot4 --headless --fixed-fps 600 --path . --script res://tests/test_mvp5_arena.gd

const ARENA_SCENE_SCRIPT := preload("res://scripts/simulation/ai_match_arena.gd")

var _failures: Array[String] = []
const MAX_MATCH_SEC := 240.0
const TRIALS := 4


func _initialize() -> void:
	call_deferred("_run")


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var juan: CampaignData = load("res://data/campaigns/campaign_juan.tres")
	var atha: CampaignData = load("res://data/campaigns/campaign_atha.tres")
	var medium: DifficultyData = load("res://data/difficulty/difficulty_medium.tres")

	var outcomes: Array[String] = []
	var elapsed_list: Array[float] = []
	seed(4242)
	for trial in range(TRIALS):
		var arena := ARENA_SCENE_SCRIPT.new()
		# extends Node2D — must be in the tree for _ready()/_process
		# chains (NavigationRegion2D, autoload lookups) to work.
		root.add_child(arena)
		arena.setup([
			{"faction_side": &"faction_a", "campaign": juan, "difficulty": medium},
			{"faction_side": &"faction_b", "campaign": atha, "difficulty": medium},
		])
		var result: Dictionary = await arena.run_until_resolved(self, MAX_MATCH_SEC)
		outcomes.append(str(result["winner"]))
		elapsed_list.append(result["elapsed_sec"])
		arena.free_all()
		await process_frame

	var resolved_count: int = 0
	var wins_a := 0
	var wins_b := 0
	for o in outcomes:
		if o != "timeout":
			resolved_count += 1
		if o == "faction_a":
			wins_a += 1
		elif o == "faction_b":
			wins_b += 1

	print("[mvp5_arena] outcomes: %s (elapsed sec: %s)" % [str(outcomes), str(elapsed_list)])
	_expect(resolved_count >= 1, "At least one of %d trial matches should resolve (not time out) within %.0fs each." % [TRIALS, MAX_MATCH_SEC])
	print("[mvp5_arena] resolved %d/%d, elapsed_sec: %s" % [resolved_count, TRIALS, str(elapsed_list)])
	_expect(not (wins_a == resolved_count and resolved_count == TRIALS), "Faction A should not win literally every trial (would suggest a cheat/asymmetry bug rather than real contested AI decisions).")
	_expect(not (wins_b == resolved_count and resolved_count == TRIALS), "Faction B should not win literally every trial (would suggest a cheat/asymmetry bug rather than real contested AI decisions).")

	if _failures.is_empty():
		print("[Tests] mvp5_arena: all passed.")
	else:
		for f in _failures:
			printerr(f)
	quit(0 if _failures.is_empty() else 1)
