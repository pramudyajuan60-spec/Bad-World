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
