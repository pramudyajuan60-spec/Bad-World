extends Area2D
## Bank/ATM (Prompt Dasar MVP3 + base rules "BANK DAN SAFE ZONE"):
## deposits a unit's carried cash into the shared economy balance via a
## 6s cancelable channel. Bank itself is a safe zone (enforced by
## CampaignEconomy.safe_zone_points, registered by the owning map
## script) and cannot be destroyed.

const DEPOSIT_CHANNEL_SEC := 6.0

var economy: Node = null
var _units_in_range: Array = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func start_deposit(unit) -> bool:
	if unit.carried_cash <= 0:
		return false
	unit.start_interaction(self, DEPOSIT_CHANNEL_SEC)
	return true


func on_interaction_complete(unit) -> void:
	if unit.carried_cash <= 0:
		return
	var amount: int = unit.carried_cash
	unit.carried_cash = 0
	if economy:
		economy.set_money(economy.money + amount)
		economy._log_event("%s deposited $%d at the Bank." % [unit.display_name, amount])


func _on_body_entered(body: Node) -> void:
	if body is BwUnit:
		_units_in_range.append(body)


func _on_body_exited(body: Node) -> void:
	_units_in_range.erase(body)


func get_units_in_range() -> Array:
	return _units_in_range.filter(func(u): return is_instance_valid(u))
