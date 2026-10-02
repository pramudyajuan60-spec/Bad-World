extends Node
## Autoload holding menu selections between scenes (MVP 1).
## (No class_name: accessed as the GameState autoload singleton.)

var pending_campaign: StringName = &""
var pending_difficulty: StringName = &"medium"
var load_on_start: bool = false
