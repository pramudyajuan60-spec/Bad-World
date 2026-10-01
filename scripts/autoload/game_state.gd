extends Node
## Autoload singleton. Carries the player's menu choices across scene
## changes (MainMenu -> CampaignSelect -> DifficultySelect -> StoryPanel ->
## gameplay). Not persisted itself; persisted state lives in SaveService.

var current_campaign_id: StringName = &"campaign_juan"
var current_difficulty_id: StringName = &"difficulty_medium"

## >= 1 tells the next-loaded gameplay scene to load that save slot instead
## of spawning a fresh mission. Consumed (reset to -1) once read.
var pending_load_slot: int = -1
