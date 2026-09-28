class_name AbilityData
extends Resource
## Typed schema for a Main Character ability (Prompt Dasar per-faction
## ability list + MVP4 acceptance criterion: "Ability mempunyai
## cooldown, feedback, dan counterplay"). One flexible schema covers
## every ability category rather than a subclass per ability, since
## there are only ~7 distinct abilities total across 4 factions —
## unused fields for a given category are simply left at their default.
## See docs/TECH_DECISIONS.md "Ability system" for the category design.

enum Category { AURA, ACTIVE_BURST, ACTIVE_SELF_BUFF, ACTIVE_SQUAD_BUFF, ACTIVE_AOE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.AURA
@export_multiline var description: String = ""
@export_multiline var counterplay_note: String = ""

## Active abilities only; 0 for passive AURA.
@export var cooldown_sec: float = 0.0
## ACTIVE_SELF_BUFF / ACTIVE_SQUAD_BUFF duration; AURA ignores this
## (always active while the source MC is alive and nearby).
@export var duration_sec: float = 0.0
@export var radius_px: float = 200.0

## ACTIVE_BURST / ACTIVE_AOE direct damage.
@export var damage_amount: float = 0.0
## Counterplay cap for ACTIVE_BURST against MC/Special targets: damage
## is reduced so the target's HP cannot drop below this fraction of its
## max_hp from a single use (e.g. Assassinate "tidak boleh one-hit
## terhadap MC atau Special").
@export var max_target_damage_cap_fraction: float = 1.0

## ACTIVE_SQUAD_BUFF damage multiplier applied to buffed allies' weapon
## damage for duration_sec (e.g. Command Surge's "2x combat output").
@export var damage_mult: float = 1.0
@export var max_targets: int = 0

## AURA / ACTIVE_SELF_BUFF accuracy bonus, added directly to accuracy.
@export var accuracy_bonus: float = 0.0
## AURA: fraction reduction to suppression accumulation (0..1).
@export var suppression_resist_mult: float = 0.0
## AURA (Discipline Aura): flat morale regen bonus per second.
@export var morale_bonus_per_sec: float = 0.0

## AURA (Vehicle Commander) — bonuses applied to nearby allied vehicles
## instead of units.
@export var vehicle_hp_mult: float = 1.0
@export var vehicle_speed_mult: float = 1.0
@export var vehicle_turret_damage_mult: float = 1.0
@export var vehicle_repair_cost_mult: float = 1.0
