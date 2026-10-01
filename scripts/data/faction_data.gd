class_name FactionData
extends Resource
## Stable faction identity data (Prompt Dasar "IDENTITAS DAN NAMA RESMI").
## Balance numbers arrive with later MVPs; MVP 0 only establishes identity
## and the link to that faction's art under Assets/Campaign/<asset_folder>.

@export var id: StringName = &""
@export var display_name: String = ""
## Folder name under Assets/Campaign/ that holds this faction's art. Kept
## as the literal on-disk name even where it differs from the canonical
## display name (see docs/REPO_AUDIT.md, Valtieri/Vartieri mismatch).
@export var asset_folder: String = ""
@export_multiline var description: String = ""

## MVP4 faction-specific gameplay config (Prompt Dasar "BATAS UNIT",
## "GAMEPLAY LOOP CARTEL/NABIL", "PABRIK DAN PENJUALAN", "SURRENDER DAN
## RECRUITMENT MUSUH"). Kept on FactionData rather than hardcoded
## per-campaign-id branches in gameplay scripts, so the four factions'
## differences are declared once, in data.

## Max recruited members excluding the Main Character (Juan/Zie/Andrés:
## 30, Nabil: 24).
@export var max_roster: int = 30
## Nabil has no B1 tier at all.
@export var has_b1: bool = true
## Only Juan and Andrés can recruit a surrendered/downed regular enemy.
@export var can_recruit_enemies: bool = false
## Nabil crafts weapons from Parts at a DEA Armory instead of buying
## them with money at a Gun Shop.
@export var uses_armory_instead_of_gun_shop: bool = false
@export var starting_factory_level: int = 1
@export var factory_value_mult: float = 1.0
@export var factory_speed_mult: float = 1.0
