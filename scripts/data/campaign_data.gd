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
