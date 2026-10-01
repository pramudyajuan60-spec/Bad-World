class_name UpgradeData
extends Resource
## Typed schema for a purchasable upgrade (factory level, Main Character
## level, vehicle repair tier, etc). MVP 0 defines the schema only.

@export var id: StringName = &""
@export var display_name: String = ""
## Free-text target identifier, e.g. "factory", "main_character".
@export var target_type: String = ""
@export var cost: int = 0
@export_multiline var effect_description: String = ""
