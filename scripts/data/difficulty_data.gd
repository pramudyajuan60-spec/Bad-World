class_name DifficultyData
extends Resource
## AI difficulty preset (Prompt Dasar "AI DAN DIFFICULTY"). Only timing
## numbers are data-driven here; the AI systems that consume them are
## built starting MVP 5.

@export var id: StringName = &""
@export var display_name: String = ""
@export var reaction_delay_sec: float = 1.5
@export var decision_interval_sec: float = 1.5
@export_multiline var notes: String = ""

## MVP5 AI skill knobs (Prompt Dasar: "Difficulty meningkatkan kualitas
## keputusan, bukan memberi uang/vision ilegal"). Every one of these
## affects *decision quality/timing* only — none of them touch
## starting money, vision/fog-of-war range, or income. See
## docs/BALANCE.md "MVP5 difficulty scaling" for the full rationale.

## 0..1 chance the strategic/tactical AI picks the objectively-best
## scored action/target this decision tick instead of a random
## acceptable one. Higher = smarter, not more resourced.
@export_range(0.0, 1.0) var decision_quality: float = 0.6
## Multiplies every utility-action's threshold (ambush, raid, attack-MC
## decisions). Lower = more decisive/willing to act on marginal
## opportunities; never changes an outcome's odds, only how picky the
## AI is about committing to a plan.
@export var utility_threshold_mult: float = 1.0
## HP ratio below which a tactically-controlled unit proactively
## disengages instead of fighting to the death. Higher = retreats
## earlier/smarter, not "takes less damage".
@export var retreat_hp_threshold: float = 0.3
## Seconds an ambush's triggering intel may age before the ambush
## auto-cancels as stale. Higher = better patience/timing.
@export var ambush_intel_patience_sec: float = 25.0
