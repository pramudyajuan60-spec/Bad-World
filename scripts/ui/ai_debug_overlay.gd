extends CanvasLayer
## AI debug overlay (Prompt Dasar MVP5: "Buat debug overlay yang dapat
## menampilkan: AI current state, current objective, known enemy
## positions, utility score, economy budget, reason memilih attack/
## retreat" + "Debug overlay tidak muncul pada release build").
##
## Godot marks an exported/release build with OS.has_feature("release")
## rather than the editor-only "editor" feature — using that (not a
## custom project setting) is the standard, engine-verified way to gate
## debug-only UI so it can't accidentally ship in an exported build.
## See docs/TECH_DECISIONS.md "AI debug overlay release gating".

var _label: Label
## Array[Dictionary]: {faction_side, strategic_ai, knowledge, economy}
## strategic_ai/economy are optional — a "watched" entry can instead
## carry only {faction_side, knowledge, tactical_ais: Array[Node]} for
## the live game's simpler fixed hostile encounters, which have no
## economy/strategic layer of their own (see docs/TECH_DECISIONS.md
## "MVP5 live-game AI scope").
var watched: Array = []


func _ready() -> void:
	if OS.has_feature("release"):
		queue_free()
		return
	layer = 50
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(520, 0)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(_label)
	add_child(panel)
	set_process(true)


func _process(_delta: float) -> void:
	if _label == null:
		return
	var lines: Array[String] = ["=== AI DEBUG OVERLAY (dev only) ==="]
	for entry in watched:
		var side: StringName = entry.get("faction_side", &"?")
		var sai: Node = entry.get("strategic_ai")
		var knowledge: Node = entry.get("knowledge")
		var economy: Node = entry.get("economy")
		lines.append("--- Faction: %s ---" % side)
		if economy:
			lines.append("  Budget: $%d (roster %d/%d)" % [economy.money, economy.recruited_count, economy.max_roster])
		if sai:
			lines.append("  Objective: %s" % sai.current_objective)
			for cat in ["raid", "attack_mc"]:
				if sai.last_utility_by_category.has(cat):
					lines.append("  Utility[%s]: %.2f" % [cat, sai.last_utility_by_category[cat]])
			for cat in ["recruitment", "ammo", "factory", "defense", "raid", "attack_mc"]:
				var r: String = sai.get_reason(cat)
				if r != "":
					lines.append("  Reason[%s]: %s" % [cat, r])
		if knowledge:
			var known: Array = knowledge.get_known_enemies()
			lines.append("  Known enemies: %d" % known.size())
			for e in known:
				var pos: Vector2 = e["position"]
				var fresh: String = "fresh" if not knowledge.is_stale(e["unit_id"]) else "stale"
				lines.append("    - %s @ (%d, %d) [%s]" % [e.get("tier_label", "?"), int(pos.x), int(pos.y), fresh])
		var tactical_ais: Array = []
		var getter: Callable = entry.get("tactical_ais_getter", Callable())
		if getter.is_valid():
			tactical_ais = getter.call()
		else:
			tactical_ais = entry.get("tactical_ais", [])
		for tai in tactical_ais:
			if is_instance_valid(tai) and is_instance_valid(tai.unit):
				lines.append("  [%s] state=%s reason=%s" % [tai.unit.display_name, BwUnit.State.keys()[tai.unit.state], tai.last_decision_reason])
	_label.text = "\n".join(lines)
