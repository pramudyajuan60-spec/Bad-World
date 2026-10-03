class_name Factory
extends StaticBody2D
## MVP 3: Cartel factory. Produces cargo over time, upgradeable L1-4.
## Cargo is picked up by units/vehicles and sold to dealers.

const MAX_LEVEL := 4
# level -> {cycle_time, cargo_per_cycle, upgrade_cost}
const LEVELS := {
	1: {"cycle": 30.0, "cargo": 2, "upgrade": 1500},
	2: {"cycle": 25.0, "cargo": 3, "upgrade": 3000},
	3: {"cycle": 20.0, "cargo": 4, "upgrade": 6000},
	4: {"cycle": 15.0, "cargo": 6, "upgrade": 0},
}

var level: int = 1
var hp: float = 500.0
var max_hp: float = 500.0
var destroyed: bool = false
var stock: int = 0  # cargo waiting for pickup
var faction: String = "bellarosa"
var _timer: float = 0.0

signal production_tick(factory: Factory)


func _ready() -> void:
	add_to_group("factories")


func _process(delta: float) -> void:
	if destroyed:
		return
	var cfg: Dictionary = LEVELS[level]
	_timer += delta
	if _timer >= float(cfg["cycle"]):
		_timer = 0.0
		stock += int(cfg["cargo"])
		production_tick.emit(self)


func upgrade(game: Node) -> bool:
	if level >= MAX_LEVEL or destroyed:
		return false
	var cost: int = int(LEVELS[level]["upgrade"])
	if game.money < cost:
		return false
	game.money -= cost
	level += 1
	return true


func take_cargo(amount: int) -> int:
	var take: int = mini(amount, stock)
	stock -= take
	return take


func damage(amount: float) -> void:
	if destroyed:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		destroyed = true


func repair(game: Node) -> bool:
	if not destroyed and hp >= max_hp:
		return false
	var cost := 500
	if game.money < cost:
		return false
	game.money -= cost
	destroyed = false
	hp = max_hp
	return true
