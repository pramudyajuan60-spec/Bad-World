class_name SafeZone
extends Area2D
## MVP 2f: Safe zone (Bank, Recruitment). Attacks and grenades are refused
## inside. Visualized as a dashed circle.

@export var radius: float = 220.0

func _ready() -> void:
	add_to_group("safe_zone")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	collision_layer = 0
	collision_mask = 0
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.4, 1.0, 0.6, 0.35), 3.0)


static func is_in_safe_zone(pos: Vector2, tree: SceneTree) -> bool:
	for z in tree.get_nodes_in_group("safe_zone"):
		var sz := z as SafeZone
		if sz != null and pos.distance_to(sz.global_position) <= sz.radius:
			return true
	return false
