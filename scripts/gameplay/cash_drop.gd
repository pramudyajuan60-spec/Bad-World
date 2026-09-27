extends Area2D
## World-pickup created when a carrying unit goes down (Prompt Dasar:
## "Kehilangan carrier sebelum Bank memiliki konsekuensi", "Loot carried
## cash sesuai aturan"). Any unit — including a hostile one — that walks
## over it picks it up, so losing a carrier is a real, generic risk, not
## a scripted cutscene. Auto-frees once emptied.

var cargo: int = 0
var cash: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true


func _on_body_entered(body: Node) -> void:
	if not (body is BwUnit) or not is_instance_valid(body):
		return
	if body.state == BwUnit.State.DEAD or body.state == BwUnit.State.DOWNED:
		return
	body.pickup_loot(cargo, cash)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(0.9, 0.8, 0.2, 0.85))
