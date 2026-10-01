class_name BuildingData
extends Resource
## Typed schema for a world building/facility (Prompt Dasar "STRUKTUR
## DUNIA", "BANK DAN SAFE ZONE", "PABRIK DAN PENJUALAN"). MVP 0 defines the
## schema only; world placement begins MVP 3.

enum Category { HQ, BANK, RECRUITMENT, GUN_SHOP, GARAGE, DEALER, FACTORY }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.HQ
@export var faction: FactionData
@export_file("*.png", "*.jpg", "*.jpeg") var map_asset_path: String = ""
@export var is_safe_zone: bool = false
