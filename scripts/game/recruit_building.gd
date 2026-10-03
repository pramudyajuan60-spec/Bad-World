class_name RecruitBuilding
extends StaticBody2D
## MVP 2d: Recruitment building. Trains B1/B2/B3 over time for money.
## Player selects it and uses the recruit UI (or hotkeys 1/2/3).

# tier -> {price, salary, time, hp, weapon}
const RECRUIT_DATA := {
	1: {"price": 300, "salary": 35, "time": 8.0, "hp": 100.0, "weapon": &"rifle", "name": "B1"},
	2: {"price": 800, "salary": 90, "time": 14.0, "hp": 170.0, "weapon": &"rifle", "name": "B2"},
	3: {"price": 1800, "salary": 180, "time": 22.0, "hp": 250.0, "weapon": &"lmg", "name": "B3"},
}

# MVP 4: Special units per campaign (tier 4, locked until MC level 4).
const SPECIAL_DATA := {
	&"campaign_juan": [
		{"price": 5500, "salary": 400, "time": 30.0, "hp": 300.0, "weapon": &"sniper", "name": "Viktor Moreau"},
		{"price": 5500, "salary": 400, "time": 30.0, "hp": 280.0, "weapon": &"smg", "name": "Elena Varga"},
		{"price": 5500, "salary": 400, "time": 30.0, "hp": 320.0, "weapon": &"lmg", "name": "Matteo Rizzo"},
	],
	&"campaign_fauzi": [
		{"price": 6500, "salary": 450, "time": 32.0, "hp": 350.0, "weapon": &"lmg", "name": "Axe Assault"},
		{"price": 6500, "salary": 450, "time": 32.0, "hp": 250.0, "weapon": &"sniper", "name": "Sniper Specialist"},
		{"price": 6500, "salary": 450, "time": 32.0, "hp": 300.0, "weapon": &"lmg", "name": "Machine Gunner"},
	],
	&"campaign_atha": [
		{"price": 5000, "salary": 350, "time": 28.0, "hp": 400.0, "weapon": &"shotgun", "name": "Shield Guardian"},
		{"price": 5000, "salary": 350, "time": 28.0, "hp": 260.0, "weapon": &"rifle", "name": "Family Strategist"},
		{"price": 5000, "salary": 350, "time": 28.0, "hp": 280.0, "weapon": &"smg", "name": "Smuggler Chemist"},
	],
	&"campaign_nabil": [
		{"price": 7500, "salary": 500, "time": 35.0, "hp": 280.0, "weapon": &"sniper", "name": "Ghost Operative"},
		{"price": 7500, "salary": 500, "time": 35.0, "hp": 260.0, "weapon": &"smg", "name": "Shadow Runner"},
		{"price": 7500, "salary": 500, "time": 35.0, "hp": 320.0, "weapon": &"rifle", "name": "Pursuit Interceptor"},
		{"price": 7500, "salary": 500, "time": 35.0, "hp": 450.0, "weapon": &"lmg", "name": "Armored Bulwark"},
	],
}

var queue: Array[int] = []  # tiers waiting
var progress: float = 0.0  # current training progress (seconds)
var rally_point: Vector2 = Vector2.INF

signal recruit_complete(tier: int)
signal queue_changed


func _ready() -> void:
	add_to_group("recruit_building")


func queue_recruit(tier: int, game: Node) -> bool:
	if not RECRUIT_DATA.has(tier):
		return false
	var data: Dictionary = RECRUIT_DATA[tier]
	# Unit cap check (30 + MC for Juan).
	if game.get_unit_count() >= 31:
		return false
	if game.money < data["price"]:
		return false
	game.money -= data["price"]
	queue.append(tier)
	queue_changed.emit()
	return true


func _process(delta: float) -> void:
	if queue.is_empty():
		progress = 0.0
		return
	var tier: int = queue[0]
	var train_time: float
	if tier == 4:
		# Special: get time from meta queue.
		var sq: Array = get_meta("special_queue", [])
		train_time = float(sq[0]["time"]) if not sq.is_empty() else 30.0
	else:
		var data: Dictionary = RECRUIT_DATA[tier]
		train_time = float(data["time"])
	progress += delta
	if progress >= train_time:
		progress = 0.0
		queue.pop_front()
		recruit_complete.emit(tier)
		queue_changed.emit()


func cancel_queue() -> void:
	queue.clear()
	progress = 0.0
	queue_changed.emit()
