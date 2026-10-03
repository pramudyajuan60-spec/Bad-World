class_name DrugDealer
extends StaticBody2D
## MVP 3: Drug dealer. Buys cargo for carried cash.
## Each dealer has separate demand; price diminishes as demand is filled.

const BASE_PRICE := 150  # per cargo unit at full demand

var dealer_name: String = "Dealer"
var demand: int = 20  # cargo wanted
var demand_max: int = 20
var is_placeholder: bool = false

signal sale_made(dealer: DrugDealer, cargo: int, cash: int)


func _ready() -> void:
	add_to_group("dealers")


## Sell cargo to this dealer. Returns {sold, cash}.
func sell_cargo(cargo: int) -> Dictionary:
	if cargo <= 0 or demand <= 0:
		return {"sold": 0, "cash": 0}
	var sold: int = mini(cargo, demand)
	# Diminishing price: price scales with remaining demand fraction.
	var price_per: float = BASE_PRICE * (0.4 + 0.6 * (float(demand) / float(demand_max)))
	var cash: int = int(sold * price_per)
	demand -= sold
	sale_made.emit(self, sold, cash)
	return {"sold": sold, "cash": cash}


func restock_demand() -> void:
	demand = demand_max
