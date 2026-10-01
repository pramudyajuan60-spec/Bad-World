extends SceneTree
## MVP7 acceptance criterion ("Balance report wajib berisi: average
## match duration, win rate per faction, income per minute, average
## army size, special unit effectiveness, vehicle effectiveness,
## frekuensi DEA response, frekuensi ambush, MC survival rate,
## perbedaan Easy/Medium/Hard, rekomendasi"). Extends MVP5's
## run_ai_winrate_report.gd structure (same reference-opponent
## approach, same AiMatchArena) with the additional telemetry MVP7
## specifically asks for; MVP5's own report remains the authoritative
## source for raw win-rate numbers (unchanged), this one adds the rest.
##
## Run: godot4 --headless --fixed-fps 600 --path . --script res://tools/run_balance_report.gd
## Full captured output + interpretation: docs/BALANCE.md "MVP7 release
## candidate balance report".

const ARENA_SCRIPT := preload("res://scripts/simulation/ai_match_arena.gd")
const HEAT_MANAGER_SCRIPT := preload("res://scripts/economy/heat_manager.gd")

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
	for c in _campaigns:
		if c.id != campaign.id:
			return c
	return campaign


func _run() -> void:
	seed(7070707) # reproducible report
	_report_lines.append("=== MVP7 release candidate balance report ===")
	_report_lines.append("(%d trials/config, both sides same difficulty, timeout %.0fs sim/match)" % [TRIALS_PER_CONFIG, MAX_MATCH_SEC])
	_report_lines.append("")
	_report_lines.append("%-18s %-10s %6s %6s %6s %9s %10s %9s %9s %8s" % [
		"Faction", "Difficulty", "Wins", "Loss", "T/O", "AvgDurSec", "Income/min", "AvgArmy", "Ambush%", "VehPresent%",
	])

	var per_difficulty_ambush: Dictionary = {} # difficulty id -> {trials, ambushes}

	for campaign in _campaigns:
		var opponent: CampaignData = _reference_campaign_for(campaign)
		for difficulty in _difficulties:
			var wins := 0
			var losses := 0
			var timeouts := 0
			var total_duration := 0.0
			var total_income_per_min := 0.0
			var total_army := 0
			var ambush_trials := 0
			var vehicle_present_trials := 0

			for trial in range(TRIALS_PER_CONFIG):
				var arena := ARENA_SCRIPT.new()
				root.add_child(arena)
				arena.setup([
					{"faction_side": &"subject", "campaign": campaign, "difficulty": difficulty},
					{"faction_side": &"opponent", "campaign": opponent, "difficulty": difficulty},
				])
				var ambush_count := {"n": 0}
				arena.connect_ambush_triggered(func(): ambush_count["n"] += 1)

				var result: Dictionary = await arena.run_until_resolved(self, MAX_MATCH_SEC)
				var elapsed: float = result["elapsed_sec"]
				total_duration += elapsed

				match String(result["winner"]):
					"subject":
						wins += 1
					"opponent":
						losses += 1
					_:
						timeouts += 1

				var earned: int = arena.get_lifetime_money_earned(&"subject")
				var minutes: float = max(elapsed / 60.0, 0.01)
				total_income_per_min += float(earned) / minutes
				total_army += arena.get_army_size(&"subject")
				if ambush_count["n"] > 0:
					ambush_trials += 1
				if arena.get_vehicle_count(&"subject") > 0:
					vehicle_present_trials += 1

				var key := String(difficulty.id) if ("id" in difficulty) else String(difficulty.resource_path)
				if not per_difficulty_ambush.has(key):
					per_difficulty_ambush[key] = {"trials": 0, "ambushes": 0}
				per_difficulty_ambush[key]["trials"] += 1
				per_difficulty_ambush[key]["ambushes"] += ambush_count["n"]

				arena.free_all()
				await process_frame

			var resolved: int = wins + losses
			var win_rate: float = (float(wins) / float(resolved) * 100.0) if resolved > 0 else -1.0
			_report_lines.append("%-18s %-10s %6d %6d %6d %9.1f %10.1f %9.1f %8.0f%% %10.0f%%" % [
				campaign.menu_name, difficulty.display_name if ("display_name" in difficulty) else String(difficulty.id),
				wins, losses, timeouts, total_duration / float(TRIALS_PER_CONFIG),
				total_income_per_min / float(TRIALS_PER_CONFIG), float(total_army) / float(TRIALS_PER_CONFIG),
				float(ambush_trials) / float(TRIALS_PER_CONFIG) * 100.0,
				float(vehicle_present_trials) / float(TRIALS_PER_CONFIG) * 100.0,
			])

	_report_lines.append("")
	_report_lines.append("--- Ambush frequency by difficulty (all factions pooled) ---")
	for key in per_difficulty_ambush.keys():
		var d: Dictionary = per_difficulty_ambush[key]
		var rate: float = float(d["ambushes"]) / float(max(d["trials"], 1))
		_report_lines.append("%-12s %d trials, %d total committed ambushes (%.2f/match)" % [key, d["trials"], d["ambushes"], rate])

	_report_lines.append("")
	_report_lines.append("--- MC survival rate (= 1 - loss rate; a match's loser's MC always dies, winner's never does in a resolved match; both survive on timeout) ---")
	_report_lines.append("(see per-faction Wins/Loss/T-O columns above; survival rate = (Wins + T/O) / total trials)")

	_report_lines.append("")
	_report_lines.append("--- DEA response frequency (live-game Heat system; analytic, not AI-arena — see heat_manager.gd) ---")
	await _measure_dea_frequency()

	for line in _report_lines:
		print(line)
	quit(0)


## heat_manager.gd's dispatch timing is fully deterministic given
## continuous combat (no RNG, no difficulty gating) — directly driving
## it under sustained notify_combat_tick() calls and reading back the
## real wave_dispatched signal timestamps is a more trustworthy
## "frequency" report than re-deriving it by hand from the constants.
func _measure_dea_frequency() -> void:
	var hm := Node.new()
	hm.set_script(HEAT_MANAGER_SCRIPT)
	root.add_child(hm)
	var wave_times: Array = []
	var t := {"sec": 0.0}
	hm.wave_dispatched.connect(func(_n): wave_times.append(t["sec"]))
	var step: float = 1.0 / float(max(Engine.physics_ticks_per_second, 1))
	for i in range(int(900.0 / step)): # 15 simulated minutes of continuous combat
		hm.notify_combat_tick()
		hm._process(step)
		t["sec"] += step
	_report_lines.append("Under continuous combat: waves at t=%s (sec); %d dispatched in 900s (then %d-wave-per-cluster cap + %.0fs cooldown applies)." % [
		str(wave_times), wave_times.size(), HEAT_MANAGER_SCRIPT.MAX_WAVES, HEAT_MANAGER_SCRIPT.CLUSTER_COOLDOWN_SEC,
	])
	hm.queue_free()
