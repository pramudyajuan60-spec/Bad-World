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
