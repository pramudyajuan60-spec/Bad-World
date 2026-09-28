extends Node
## Lightweight global signal bus for events that many independent AI
## controllers need to react to without each one wiring a direct
## connection to every other unit (Prompt Dasar tactical AI: "Grenade
## avoidance"). Kept intentionally tiny — this is not a general event
## system, just the one cross-cutting broadcast MVP5 needs.
##
## Like every other autoload, access via get_node_or_null("/root/...")
## and cache the result rather than the bare identifier: bare
## autoload references fail to compile under `--headless --script`
## (see docs/TECH_DECISIONS.md "Autoload singletons under --script").

## Emitted the instant a grenade/thrown-explosive leaves a thrower's
## hand, before it lands — lets nearby tactical AI react during the
## fuse/travel window instead of only after the explosion.
signal grenade_incoming(thrower_faction: StringName, impact_pos: Vector2, radius: float, fuse_sec: float)
