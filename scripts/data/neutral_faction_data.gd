class_name NeutralFactionData
extends Resource
## Third-party neutral faction for Diplomacy encounters (Prompt Dasar
## MVP5 "DIPLOMACY": "Neutral encounter", "Memperoleh cartel contact").
## Not one of the 4 playable cartels/DEA — a smaller local outfit that
## any cartel can choose to fight or court.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Trade benefit applied to an allied faction's Drug Dealer sales while
## the alliance holds (Prompt Dasar "Trade benefit").
@export var allied_dealer_value_bonus: float = 0.15
