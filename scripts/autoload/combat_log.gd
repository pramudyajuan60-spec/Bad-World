extends Node
## Autoload singleton. A small, generic event/combat log — kills, downs,
## revives, executions, recruitment, payroll, and friendly-fire warnings
## all funnel through here so any HUD (this MVP's or MVP6's fuller one)
## can subscribe without gameplay code depending on a specific UI node.
## Prompt Dasar calls for "Combat log terbatas" (MVP1 base rules) and an
## "Event/alert log" (MVP6) — this is the shared backing service for both.

signal logged(text: String)

const MAX_ENTRIES := 50

var entries: Array[String] = []


func log_event(text: String) -> void:
	entries.append(text)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	logged.emit(text)
	print("[CombatLog] %s" % text)
