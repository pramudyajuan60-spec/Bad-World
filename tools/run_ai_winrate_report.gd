extends SceneTree
## MVP5 acceptance criterion: "Laporkan hasil win-rate awal per
## faction/difficulty". Runs each of the 4 campaigns' AI against a
## fixed reference opponent, at each of the 3 difficulty presets
## (both sides using the same difficulty, isolating faction balance
## from difficulty-vs-difficulty skill gaps), several trials each, and
## prints a plain-text win-rate table. This is a reporting tool, not a
## pass/fail gate — Prompt Dasar only asks for an initial report here,
## not a specific target band (contrast with MVP4's balance simulation,
## which does assert a band). See docs/BALANCE.md "MVP5 initial AI
## win-rate report" for the captured results and any follow-up notes.
##
## Godot's headless physics loop paces close to real time by default;
## --fixed-fps decouples stepping from wall-clock pacing and cuts this
## report's real runtime by roughly 40-50x (see
## docs/TECH_DECISIONS.md "Headless AI simulation speed").
## Run: godot4 --headless --fixed-fps 600 --path . --script res://tools/run_ai_winrate_report.gd

const ARENA_SCRIPT := preload("res://scripts/simulation/ai_match_arena.gd")

const TRIALS_PER_CONFIG := 3
const MAX_MATCH_SEC := 220.0
const REFERENCE_CAMPAIGN_ID := &"campaign_juan"

var _campaigns: Array = []
var _difficulties: Array = []
var _report_lines: Array[String] = []


func _initialize() -> void:
	_campaigns = [
		load("res://data/campaigns/campaign_juan.tres"),
		load("res://data/campaigns/campaign_atha.tres"),
		load("res://data/campaigns/campaign_fauzi.tres"),
		load("res://data/campaigns/campaign_nabil.tres"),
	]
	_difficulties = [
		load("res://data/difficulty/difficulty_easy.tres"),
		load("res://data/difficulty/difficulty_medium.tres"),
		load("res://data/difficulty/difficulty_hard.tres"),
	]
	call_deferred("_run")


func _reference_campaign_for(campaign: CampaignData) -> CampaignData:
	for c in _campaigns:
		if c.id == REFERENCE_CAMPAIGN_ID and c.id != campaign.id:
			return c
	# The reference campaign itself needs its own distinct opponent.
	for c in _campaigns:
		if c.id != campaign.id:
			return c
	return campaign


func _run() -> void:
	seed(20260928) # reproducible initial report
	_report_lines.append("=== MVP5 initial AI win-rate report ===")
	_report_lines.append("(%d trials/config, both sides same difficulty, timeout %.0fs sim/match)" % [TRIALS_PER_CONFIG, MAX_MATCH_SEC])
	_report_lines.append("%-18s %-10s %8s %8s %8s %10s" % ["Faction", "Difficulty", "Wins", "Losses", "Timeout", "Win rate"])

	for campaign in _campaigns:
		var opponent: CampaignData = _reference_campaign_for(campaign)
		for difficulty in _difficulties:
			var wins := 0
			var losses := 0
			var timeouts := 0
			for trial in range(TRIALS_PER_CONFIG):
				var arena := ARENA_SCRIPT.new()
				root.add_child(arena)
				arena.setup([
					{"faction_side": &"subject", "campaign": campaign, "difficulty": difficulty},
					{"faction_side": &"opponent", "campaign": opponent, "difficulty": difficulty},
				])
				var result: Dictionary = await arena.run_until_resolved(self, MAX_MATCH_SEC)
				match String(result["winner"]):
					"subject":
						wins += 1
					"opponent":
						losses += 1
					_:
						timeouts += 1
				arena.free_all()
				await process_frame
			var decisive: int = wins + losses
			var win_rate_str: String = "%.0f%%" % (100.0 * float(wins) / float(decisive)) if decisive > 0 else "n/a"
			_report_lines.append("%-18s %-10s %8d %8d %8d %10s" % [campaign.menu_name, difficulty.display_name, wins, losses, timeouts, win_rate_str])

	_report_lines.append("")
	_report_lines.append("Difficulty note (Prompt Dasar): Hard/Medium/Easy only change decision")
	_report_lines.append("quality/timing (DifficultyData.decision_quality, utility_threshold_mult,")
	_report_lines.append("retreat_hp_threshold, ambush_intel_patience_sec) — never starting money,")
	_report_lines.append("vision range, or unit count, so any win-rate spread above is a smarter-")
	_report_lines.append("decisions effect, not a resource/vision cheat.")

	for line in _report_lines:
		print(line)
	await _run_difficulty_skill_comparison()
	quit(0)


## Direct evidence for the acceptance criterion "Hard lebih cerdas dari
## Medium, bukan curang": same campaign on both sides (so faction
## asymmetry is eliminated) with only the difficulty differing, which
## isolates the effect of decision-quality knobs alone.
func _run_difficulty_skill_comparison() -> void:
	var lines: Array[String] = []
	lines.append("")
	lines.append("=== Same-faction, cross-difficulty skill check ===")
	lines.append("(isolates decision quality alone: both sides play Campaign Juan)")
	lines.append("%-24s %8s %8s %8s" % ["Matchup", "Higher", "Lower", "Timeout"])
	var juan: CampaignData = _campaigns[0]
	var pairs := [
		["Hard", "Medium", _difficulties[2], _difficulties[1]],
		["Medium", "Easy", _difficulties[1], _difficulties[0]],
	]
	for pair in pairs:
		var higher_wins := 0
		var lower_wins := 0
		var timeouts := 0
		for trial in range(TRIALS_PER_CONFIG):
			var arena := ARENA_SCRIPT.new()
			root.add_child(arena)
			arena.setup([
				{"faction_side": &"higher_skill", "campaign": juan, "difficulty": pair[2]},
				{"faction_side": &"lower_skill", "campaign": juan, "difficulty": pair[3]},
			])
			var result: Dictionary = await arena.run_until_resolved(self, MAX_MATCH_SEC)
			match String(result["winner"]):
				"higher_skill":
					higher_wins += 1
				"lower_skill":
					lower_wins += 1
				_:
					timeouts += 1
			arena.free_all()
			await process_frame
		lines.append("%-24s %8d %8d %8d" % ["%s vs %s" % [pair[0], pair[1]], higher_wins, lower_wins, timeouts])
	for line in lines:
		print(line)
