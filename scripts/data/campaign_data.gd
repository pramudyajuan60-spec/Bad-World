class_name CampaignData
extends Resource
## One playable campaign slot (Prompt Dasar "IDENTITAS DAN NAMA RESMI").
## `id` is the stable internal identifier; `menu_name` is the display-only
## name shown in the UI and may differ from the main character's real name
## (e.g. "Campaign Fauzi" plays as Zie Vartieri).

@export var id: StringName = &""
@export var menu_name: String = ""
@export var main_character_name: String = ""
@export var faction: FactionData
@export var starting_money: int = 0
## res:// path to the campaign's canonical Story.txt. Never rewritten.
@export_file("*.txt") var story_path: String = ""
## res:// path to the menu/loading-screen portrait.
@export_file("*.png", "*.jpg", "*.jpeg") var portrait_path: String = ""
@export_file("*.png", "*.jpg", "*.jpeg") var main_character_sprite_path: String = ""
## Concept art map for this faction's home territory (not collision-ready).
@export_file("*.png", "*.jpg", "*.jpeg") var concept_map_path: String = ""

## MVP4: faction-specific roster/ability data, so open_world_map.gd's
## spawn logic reads from data instead of a hardcoded per-campaign
## match statement (rule 10: gameplay numbers/config must be
## data-driven). `b1_unit` is null for Nabil (Prompt Dasar: no B1 tier).
@export var mc_unit: UnitData
@export var b1_unit: UnitData
@export var b2_unit: UnitData
@export var b3_unit: UnitData
@export var special_units: Array[UnitData] = []
@export var abilities: Array[AbilityData] = []
## Starting vehicle class for this campaign (Prompt Dasar "STARTING
## RESOURCES"): Juan/Andrés get a "kendaraan utilitas" (mapped to
## Compact — no distinct utility class exists), Zie an armored SUV,
## Nabil a "patrol van" (also mapped to Compact, documented assumption).
@export var starting_vehicle: VehicleData
