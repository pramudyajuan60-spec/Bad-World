# Technical Decisions

## Engine and version

- **Engine:** Godot 4.3 stable (`4.3.stable.official.77dcf97d8`), downloaded
  from the official `godotengine/godot` GitHub release
  (`Godot_v4.3-stable_linux.x86_64`). This satisfies the "Godot 4.x stable,
  bukan beta" requirement.
- **Why 4.3 specifically:** it was the latest stable 4.x release available
  from the official release channel at the time MVP 0 was built. Any later
  4.x stable release should also work; re-validate with
  `tools/validate_asset_manifest.gd` and `tests/test_campaign_data.gd` (see
  docs/TEST_PLAN.md) before switching.
- **Language:** typed GDScript everywhere (`class_name`, typed `@export`
  vars, typed function signatures). No C#/Mono.
- **Installing the engine locally:** the editor binary is intentionally
  *not* committed to this repository (it is a ~110 MB platform binary).
  Download the matching Linux/Windows/macOS build for 4.3 stable from
  https://godotengine.org/download/archive/ and either put it on your PATH
  as `godot4` or reference its path directly, e.g.:
  `godot4 --path . --editor` to open the project,
  `godot4 --headless --path . --script res://tools/validate_asset_manifest.gd`
  to validate assets headlessly.

## Project layout

The Godot project root **is** the repository root, so `Assets/` (already
present, untouched) becomes `res://Assets` automatically. This avoids
copying/moving any original art, per rule 5/6 in the Prompt Dasar.

```
project.godot          Godot project settings
icon.svg               PLACEHOLDER project icon (see PLACEHOLDER_REGISTER)
scenes/                Godot scenes (Main.tscn is the MVP 0 bootstrap scene)
scripts/
  data/                Typed Resource schemas (Campaign/Faction/Unit/...)
  autoload/            Singletons (CampaignDatabase)
  main/                Scene-attached scripts
data/
  campaigns/*.tres     One resource per playable campaign (data-driven)
  factions/*.tres       One resource per faction
  difficulty/*.tres     Easy/Medium/Hard presets
  manifest/asset_manifest.json  Generated, machine-readable asset catalog
tools/
  generate_asset_manifest.py    Re-run after Assets/ changes (see below)
  validate_asset_manifest.gd    Headless in-engine validator
tests/
  test_campaign_data.gd         Headless smoke tests
docs/                  This documentation set
Assets/                Original, untouched art/story/reference tree
```

## Why `.tres` Resources instead of hard-coded GDScript tables

Rule 10 requires gameplay numbers to be data-driven rather than
hard-coded across many scripts. Godot's typed `Resource` + `.tres` system
gives us: editor-inspectable data, type safety via `class_name`, and easy
diffing in version control (`.tres` is a plain text format). Each schema
(`CampaignData`, `FactionData`, `UnitData`, `WeaponData`, `VehicleData`,
`BuildingData`, `UpgradeData`, `DifficultyData`) lives in
`scripts/data/*.gd`. MVP 0 only populates `CampaignData`, `FactionData`,
and `DifficultyData` instances (per the MVP 0 scope: "masukkan data dasar
empat campaign"); `UnitData`/`WeaponData`/`VehicleData`/`BuildingData`/
`UpgradeData` are schema-only until the MVP that needs their numbers
(mostly MVP 1–3), with the source numbers already captured in
docs/BALANCE.md so they aren't re-derived later.

**Resource file quirk:** `.tres` files for a custom Resource subclass must
use `[gd_resource type="Resource" ...]` in the header (not
`type="FactionData"`) with the actual subclass wired via
`script = ExtResource(...)`. Using the custom class name directly in
`type=` fails to load outside the editor process
("Cannot get class 'FactionData'") even though the class is correctly
registered in `.godot/global_script_class_cache.cfg`. This was confirmed
by headless testing during MVP 0.

## Rendering / display target

- Renderer: **Compatibility (GL Compatibility)**, not Forward+. This is
  the recommended renderer for 2D/2.5D pixel-art isometric games and has
  the widest hardware/headless compatibility, which matters for CI-style
  headless verification in this sandbox.
- Base resolution 1920×1080, `stretch/mode = canvas_items`,
  `stretch/aspect = expand`, per the "harus responsif untuk 1366×768"
  requirement — full layout/UI scaling verification is deferred to the
  MVP that ships real UI (MVP 1/6).
- 2.5D isometric world (Y-sort, fixed three-quarter camera) is an
  **MVP 1+ concern**; MVP 0 intentionally ships only a minimal bootstrap
  `Control` scene with no world/camera yet ("Jangan membuat full gameplay
  dalam fase ini").

## Repository / commit confirmation

Prompt Dasar (`Prompt AI Bad World GAME -/Part 1.txt`) names a specific
commit to check out. That token is not a valid Git SHA present in this
repository's history (`git log` only has short hashes such as `974acb1`,
`e7c0a9d`, `c2ec775`, `f5aa92e`, `7c84ac7`). Per rule 11 ("pilih solusi
paling masuk akal dan catat asumsi"), MVP 0 was built against the actual
`HEAD` of the working branch at the time of this audit:

- Branch: `hoplite/delos-9da1c4dc`
- Short SHA: `974acb1` ("first commit" — the asset-only import)
- Full SHA: obtain locally with `git rev-parse HEAD` (omitted here because
  full 40-character hashes are redacted by this environment's transcript
  tooling; the short hash above is stable and verifiable).

## Automated validation, given no CI is configured yet

Two headless entry points exist and were both run successfully against
this MVP 0 state (see docs/TEST_PLAN.md for full logs/criteria):

```
godot4 --headless --path . --script res://tools/validate_asset_manifest.gd
godot4 --headless --path . --script res://tests/test_campaign_data.gd
godot4 --headless --path . --quit   # project boots, main scene runs once
```

## MVP 1 additions

### Camera hotkey conflict (rule 11 assumption)

The base ruleset lists "WASD atau edge-scroll" for camera panning, but
also assigns the letters S (Stop), D (Defend/Cover Mode), and A
(Attack-move) as unit hotkeys in the very same document. Godot doesn't
care that these conflict, so a choice had to be made. Resolution: the
camera pans via **arrow keys + edge-scroll**, since the ruleset already
offers edge-scroll as an alternative to WASD ("atau" = "or"), leaving the
letter keys free for unit commands. See `scripts/gameplay/rts_camera.gd`.

### NavigationPolygon construction: deprecated-but-working API

`NavigationPolygon.add_outline()` + `.make_polygons_from_outlines()` is
flagged deprecated in 4.3 in favor of
`NavigationServer2D.parse_source_geometry_data()` +
`.bake_from_source_geometry_data()`. MVP 1 uses the deprecated call
anyway: it's synchronous (no async baking callback plumbing needed for a
single static open rectangle), still functions correctly in 4.3 (proven
by `tests/test_combat_and_navigation.gd`, which drives a real unit
across the mesh), and keeps the test map's setup code short. Revisit if
a future Godot upgrade removes the deprecated method entirely.

### Obstacle avoidance: circular `NavigationObstacle2D` approximation

Rather than carving rectangular holes into the navigation mesh (which
would need the geometry-parsing/baking pipeline above), each rectangular
test-map obstacle gets one circular `NavigationObstacle2D`
(`avoidance_enabled = true`, radius sized to the rectangle's larger
dimension) alongside its `StaticBody2D` physics collider. Agents steer
around it via RVO avoidance; physics collision is the hard backstop if
avoidance alone isn't enough. This is a deliberately simplified
approximation ("navigation dan geometry sederhana" per rule 8) — it
over-blocks corners of a rectangle and under-blocks its flat edges
slightly. Fine for MVP 1's single test map; revisit if a later MVP's
map needs tighter-fitting obstacles.

### Combat in MVP 1 is a deliberate placeholder, not MVP 2's system

`BwUnit`'s combat is flat, accuracy-gated damage with no weapon
inventory, ammo, line-of-sight, or cover — just enough to satisfy MVP
1's "Basic attack-move dan target acquisition" and "Basic enemy dapat
diserang" acceptance criteria. The full weapon-data-driven system
(`WeaponData`, ammo, line-of-sight, cover damage reduction) is explicitly
MVP 2 scope ("COMBAT DAN COVER") and intentionally not built early.

## MVP 2 additions

### Autoload references in headless test scripts — a real, reproducible bug

**Bare autoload identifiers do not compile inside a `--headless
--script res://....gd` (custom `SceneTree`/`MainLoop`) invocation.**
This is not flaky/timing-dependent — it is 100% reproducible regardless
of how much the class/script cache has been "warmed" beforehand. A
script that references an autoload singleton by its bare project.godot
name (e.g. `CombatLog.log_event(...)`) fails to *compile* with
`Identifier not found: CombatLog` whenever Godot is invoked via
`--script <path>` instead of its normal main-scene bootstrap
(`run/main_scene` in project.godot). When a dependency script fails to
compile this way, `PackedScene.instantiate()` on a scene using that
script silently returns a **bare engine-base-class node with no script
attached** (e.g. a plain `CharacterBody2D` instead of a `BwUnit`) rather
than erroring loudly, which then surfaces later as a confusing
`Trying to assign value of type 'CharacterBody2D' to a variable of type
'unit.gd'` or `Nonexistent function '...' in base 'Nil'` far from the
real cause.

This was first hit in MVP1 (test scripts referencing `SaveService`) and
the fix at the time was scoped to the test files only. MVP2 hit it
again, this time inside **production gameplay code** (`unit.gd`,
`campaign_economy.gd`) referencing the new `CombatLog` autoload — which
silently broke `BwUnit` for every headless test until diagnosed.

**Durable fix applied everywhere an autoload is used from a script that
needs to run headlessly:** look the singleton up at runtime via
`get_node_or_null("/root/<AutoloadName>")` once in `_ready()`, cache it
in a plain `var`, and route all calls through a small null-safe helper
(e.g. `_log_event(text)`) instead of ever writing the bare identifier.
This works identically in normal play (real binary, real main scene)
and in every `--headless --script` test, and costs nothing at runtime.
Any *new* autoload added to this project should follow the same
pattern from the start rather than rediscovering this bug a third time.

### Cover implementation: directional damage reduction, not navmesh cutouts

Defend Mode marks a unit `in_cover = true` with a `cover_direction`
(the outward normal from the covering obstacle to the unit). On
`take_damage(amount, attacker)`, if the attacker is roughly opposite
that normal (`cover_direction.dot(attacker_dir) < -0.3`), damage is
reduced 35%; otherwise it's full. This is deliberately a damage-formula
check, not a physical shield/hitbox — simplest way to make "cover only
protects from the right direction" both true and unit-testable without
needing per-obstacle collision-shape raycasting against a firing arc.

### Line-of-sight via a dedicated obstacle collision layer

Units live on collision layer 1 (mask 1|2, so they physically collide
with both each other and obstacles). Obstacles live on a dedicated
layer 2 with an empty mask. `BwUnit._has_line_of_sight()` raycasts with
`collision_mask = 2` so it only ever hits obstacles, never other units
— avoiding false "blocked" results just because an ally is standing
between the shooter and its target.

### Projectile weapons are a timed delay, not a simulated flight

`WeaponData.is_hitscan = false` (grenades, RPG) resolves as: compute
`travel_time = distance / projectile_speed_px`, then apply the AoE
explosion after that delay via `get_tree().create_timer(...)`. There is
no moving projectile node/visual. This still makes hitscan vs.
projectile a real, testable behavioral difference (a shot lands
instantly; an RPG/grenade lands after a beat) without needing
projectile physics, arcs, or impact-detection geometry — deferred to a
later MVP if a visible flight becomes a real requirement.

### Grenade-throwing is a hotkey-armed action, not full context-menu UX

`G` + right-click throws the equipped grenade at the clicked ground
position (clamped to the weapon's range), mirroring the existing
`A` + right-click attack-move pattern. A richer targeting reticle/arc
preview is MVP6 UI polish; the underlying mechanic (consume one
charge, apply AoE with friendly-fire rules) is fully implemented and
tested now.

### Recruitment/Gun Shop/Inspect are HUD buttons, not in-world buildings

This test map has no real Recruitment/Gun Shop/Bank building placed in
the world (those come from `Assets/Game Maps/` once MVP3 builds the
actual open world). Rather than fake a building with a clickable
`Area2D` on a map that will be replaced anyway, MVP2 exposes these
systems as three always-visible HUD buttons. The underlying economy
logic (money, recruitment queue, roster cap, weapon inventory, payroll)
is the real, tested system MVP3 will attach to actual world buildings.

## MVP 3 additions

### Vehicle mounting model: units mount, vehicles aren't RTS-selectable units

A vehicle (`Vehicle`, `scripts/gameplay/vehicle.gd`) exposes the exact
same public method names `SelectionManager`/`CommandController` already
use for `BwUnit` (`set_selected`, `order_move`, `order_stop`,
`faction_side`, `global_position`) via duck typing, so it *could* have
been made directly selectable like a unit. Instead, the chosen model
is: a `BwUnit` walks up to (or is auto-routed toward) a vehicle and
"mounts" it (`mount_vehicle`) — the unit is hidden and its own physics
processing is paused, and further move/stop orders given to that
*unit* are redirected to the vehicle by `CommandController` because
the unit's own `order_move` etc. simply no-op while
`mounted_vehicle != null` (`_can_receive_orders()` returns false).
This means the player keeps selecting **units** the whole time (never
has to learn "select the vehicle instead"), and existing selection/
control-group code needed zero changes — only `CommandController`
needed a few additions (vehicle-enter routing on right-click, `X` to
exit). The trade-off: a vehicle with no driver aboard can't be
selected or ordered directly (matches real life — nobody's driving).

### Heat/DEA response: one global cluster, not spatial clustering

See docs/BALANCE.md "MVP 3 Heat/DEA response simplification" for the
full rationale — `heat_manager.gd` tracks a single heat value for the
whole mission rather than Prompt Dasar's per-~35m-cluster model, since
MVP3 only has one meaningfully contested territory.

### `get_meta(key, null)` still logs an ERROR for a missing key — a real Godot 4.3 quirk

`Object.get_meta(name, default)` is documented to return `default`
silently when `name` isn't set. In practice, when `default` is
literally `null`, Godot 4.3 **still prints** `ERROR: The object does
not have any 'meta' values with the key '...'` even though the
returned value is correct. Only a non-null default (or checking
`has_meta()` first) suppresses the message. `drug_dealer.gd` originally
used `get_meta(key, null)` / unconditional `remove_meta(key)` to pass
per-unit sale context through a channeled interaction, which spammed
this error whenever `on_interaction_complete` ran for a unit that
never actually started a sale through the normal path (caught by a
test calling it directly). Fixed by checking `has_meta()` before both
`get_meta()` and `remove_meta()`. Worth remembering for any future code
using per-instance `set_meta`/`get_meta` as ad hoc storage.

### GDScript lambda closures cannot mutate outer local variables — reconfirmed and now load-bearing

MVP1/2 already hit signal-connected lambdas silently failing to flip a
captured boolean; MVP3 re-verified this with a minimal isolated repro
(a lambda incrementing a captured `counter` on every signal emission —
`counter` remained `0` after two emits). This is not GDScript-version-
specific trivia, it is a hard rule for this codebase: **never write
`signal.connect(func(x): outer_var = ...)` and expect `outer_var` to
change.** Every MVP3 test that needed to observe a signal's fired
state or payload (`heat_manager`'s `wave_dispatched`, `BwUnit`'s
`loot_dropped`) uses a bound method on the test script itself
(`_on_wave_dispatched`, `_on_loot_dropped`) instead of an inline lambda,
which works correctly because it's ordinary method dispatch on `self`,
not a captured local.

## MVP 4 additions

### Ability system: one flexible schema, not a subclass per ability

`AbilityData` (scripts/data/ability_data.gd) covers all 7 distinct
abilities across 4 factions through a single `Category` enum (AURA /
ACTIVE_BURST / ACTIVE_SELF_BUFF / ACTIVE_SQUAD_BUFF / ACTIVE_AOE) with
a shared, generously-fielded schema rather than a GDScript subclass per
ability. With only 7 abilities total, a subclass-per-ability approach
would mean 7 near-empty scripts; a flexible shared schema means the
whole system is addable/tunable purely in `.tres` data, matching this
project's existing data-driven-numbers rule. `BwUnit.try_use_ability()`
dispatches on category; AURA abilities never go through that entry
point at all — they're continuously re-evaluated by every nearby
regular unit's own `_refresh_aura_bonuses()`, so an aura's effect is
never "sticky" past its owner's death/range (a real counterplay, not
just a description).

### Save/load must resolve the campaign before faction-specific setup

`open_world_map.gd`'s `_ready()` now peeks at a pending save slot's own
`campaign_id` *before* building any faction-specific world/UI, and only
falls back to `GameState.current_campaign_id` if there's no pending
load. Found via testing: "Continue" from the main menu only sets
`GameState.pending_load_slot`, never `current_campaign_id` — without
resolving the save's own campaign first, `_build_buildings()` would
run for Juan even when loading a Zie save, before `_apply_save_data()`
(previously `_load_from_slot`) corrected `current_campaign_id` too
late to matter. Confirmed fixed via a dedicated repro (save as Zie,
then load exactly the way "Continue" does it, assert the world that
gets built is Zie's).

### Nabil's Patrol income distance-efficiency: per-sector rank, not pairwise distance

Prompt Dasar's "distance efficiency" concept for City Patrol income
isn't given an exact formula. Implemented as a cheap per-~600px-sector
rank-based falloff (1st patroller in a sector earns 100%, 2nd 50%, 3rd+
25%) rather than true pairwise distance checks between every patrolling
unit, which would need an O(n²) scan every income tick for a rule that
only matters when units happen to cluster together anyway.

### Zie's Triad Synergy and Vehicle Commander are computed by the owning scene, not the unit itself

`BwUnit` exposes plain `synergy_damage_mult`/`synergy_armor_reduction`/
`synergy_suppression_resist_mult` fields that `open_world_map.gd`
writes to every physics frame (`_update_triad_synergy`), rather than
`BwUnit` trying to find its own two Special siblings. The owning scene
already tracks `special_unit_instances`; duplicating that bookkeeping
inside every unit instance would be redundant and harder to keep in
sync. Same reasoning for `Vehicle._vehicle_commander_bonus()`, which
scans for a nearby friendly MC with the ability every time it's needed
rather than caching a reference (Zie can move in and out of range at
any moment).

### Headless AI simulation speed: `--fixed-fps` is required, not optional

Godot's headless physics loop otherwise paces itself close to real
wall-clock time even though nothing is rendered — a simulated 200s AI
match (MVP5's `AiMatchArena`) took roughly 200 real seconds to run
without it. Passing `--fixed-fps 600` decouples simulation stepping
from wall-clock pacing: the same test that times out against a 90s
real-time budget resolves in a few real seconds. This cut MVP4's
balance-simulation suite from ~200-300s down to ~3s and made MVP5's
36-match win-rate report (`tools/run_ai_winrate_report.gd`) practical
at all. Every MVP5 test/tool that drives `await physics_frame` in a
loop documents this flag in its own run command; earlier MVP suites
still work fine without it (their simulated durations are short enough
that real-time pacing was never a problem), so this is additive
guidance, not a retroactive requirement on MVP1-4's suites.

### MVP5 live-game AI scope: fixed hostile encounters keep `auto_defend`, not the new mobile AI

The open world map's small fixed hostile encounters — the starting
"Hostile (PLACEHOLDER)" squad and DEA response waves — are deliberately
**stationary** (`can_move = false`, an MVP1/3 design choice: they are
static defenders of a position, not a roaming force). An early MVP5
pass attached `UnitTacticalAI` to them anyway; since `order_attack`/
`order_move` both no-op via `_can_receive_orders()` when `can_move` is
false, this was dead weight that did nothing but was caught by visual
(Xvfb) verification showing a hostile logged a "protecting"/"engaging"
decision reason while visibly standing still. It was removed — these
encounters keep their existing, already-tested `auto_defend` behavior
(`BwUnit._physics_process`'s own `State.IDLE` branch). The real,
fully mobile STRATEGIC+TACTICAL AI faction (recruitment, economy,
raiding, ambush, attack-MC decisions) is exercised instead by the
headless `AiMatchArena` (`scripts/simulation/ai_match_arena.gd`), which
spawns complete independent faction economies with mobile units from
scratch. A true rival cartel AI faction roaming the live open world
(the other 3 HQs becoming active factions rather than inert landmark
markers) is deferred to whichever later MVP first gives campaign
presentation a reason to populate them.

### AI debug overlay release-gating uses `OS.has_feature("release")`, not a custom project setting

Prompt Dasar requires the MVP5 debug overlay to not appear in a release
build. Godot's engine-verified way to detect an actual exported
release build at runtime is `OS.has_feature("release")` (true only in
a `release` export template, false in the editor and in a `debug`
export) — not `OS.has_feature("editor")` (which is false in *any*
export, debug or release) and not a project-settings flag (which an
exporter could forget to flip). `AiDebugOverlay._ready()` calls
`queue_free()` on itself immediately when this is true, so it
structurally cannot exist in a release export regardless of whether a
developer remembers to hide it.
