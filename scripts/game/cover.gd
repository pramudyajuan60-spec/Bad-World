class_name CoverPoint
extends StaticBody2D
## MVP 2 directional cover: a low obstacle (sandbag, car, crate) that does
## NOT block line-of-sight but reduces incoming damage for units crouched
## behind it relative to the attacker.
##
## Directional rule: cover protects a defender only when the attacker is on
## the opposite side of the cover from the defender.

@export var protection: float = 0.5  # damage multiplier when in cover (0.5 = -50%)
@export var cover_radius: float = 48.0  # defender must be this close to benefit

func _ready() -> void:
	add_to_group("cover")


## Returns the damage multiplier for `defender` against `attacker_pos`.
## 1.0 = no cover benefit.
func protection_for(defender_pos: Vector2, attacker_pos: Vector2) -> float:
	if defender_pos.distance_to(global_position) > cover_radius:
		return 1.0
	var to_defender: Vector2 = (defender_pos - global_position).normalized()
	var to_attacker: Vector2 = (attacker_pos - global_position).normalized()
	# Opposite sides => cover is between them.
	if to_defender.dot(to_attacker) < -0.3:
		return protection
	return 1.0
