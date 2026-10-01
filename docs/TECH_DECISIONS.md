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

### MVP6: tutorial "seen" state and audio/keybind prefs are install-wide, not per-save

Prompt Dasar's acceptance criterion is "pemain baru dapat memahami
loop dasar melalui tutorial" (a *new player* can learn the loop) — not
"every new campaign re-teaches the loop". `TutorialController`'s "seen
hint" set, and `UserPrefsService`'s volume/keybind overrides, are
stored in a small separate `user://user_prefs.json` file keyed by
nothing but the local install, not inside `SaveService`'s per-slot
save data. A returning player who starts a second campaign (or loads a
different save slot) does not see the same 10 hints again; a brand new
player does, exactly once, regardless of which campaign they pick
first. Documented assumption, not a bug.

### MVP6 victory condition is implemented and tested, but not reachable by playing yet

Prompt Dasar's VICTORY DAN DEFEAT rule (cartel wins when every rival
MC is dead; Nabil additionally needs every cartel factory shut down)
is implemented in full in `open_world_map.gd::_check_victory_condition`
against a generic `_enemy_mc_registry: Array`. Nothing in the live
open-world scene ever appends to that registry, because no rival
faction MC is spawned there yet (`PLACEHOLDER_rival_faction_hqs`,
docs/PLACEHOLDER_REGISTER.md) — the exact same gap MVP5 already
documented for its own mobile AI. `tests/test_mvp6_victory_defeat.gd`
proves the rule itself is correct (including Nabil's extra factory
condition) by registering a fake enemy MC directly, via a narrow
`register_enemy_mc_for_test()`/`force_check_victory_for_test()` seam
(same pattern as the pre-existing `gather_save_data_for_test()`).
DEFEAT (the player's own MC dying) has no such gap and is fully
reachable by actually playing.

### Fixed: `BwUnit.died` signal double-argument bug broke all death cleanup

`signal died(unit)` already carries the dying unit as its own
argument (emitted as `died.emit(self)`). Three call sites connected it
as `u.died.connect(_on_x.bind(u))` — `SelectionManager.register_unit`,
and two enemy-unit spawn paths in `open_world_map.gd`
(`_spawn_fresh`'s dummy squad and `_apply_save_data`'s loaded enemy
units). Godot delivers the signal's own argument *and* the bound one,
so a 1-parameter handler received 2 arguments; the connection fails
silently (Godot logs a swallowed `Method expected 1 arguments, but
called with 2` error, the callback body never runs). In practice this
meant **no player or enemy unit was ever actually removed from
`SelectionManager.player_units`/`selected`/control groups, or from the
map's enemy-units cache, on death** — a real, pre-existing correctness
bug, not something introduced by MVP6. Found by
`tests/test_mvp6_victory_defeat.gd` (the first test to call
`BwUnit._die()` directly on a `SelectionManager`-registered unit and
assert on the resulting state). Fixed at all three sites by dropping
the redundant `.bind(...)` — the signal's own argument already is the
unit every one of these handlers needed.

### MVP7: real rival factions now spawn in the live open world (fixes "VICTORY unreachable")

MVP6 documented that `_enemy_mc_registry` was never populated by the
live game, so VICTORY (unlike DEFEAT) could only be exercised via a
test-only fake registry. MVP7 adds `open_world_map.gd::_spawn_rival_factions()`,
called from `_spawn_fresh()`: the other 3 campaigns' real Main
Characters (their own `mc_unit` stats, not the player's) plus a
2-unit guard squad each, at their respective HQ region. Deliberately
**stationary** (`can_move = false`, `auto_defend = true`) — the same
"fixed hostile encounter" design already established for the starting
dummy squad and DEA response waves (see "MVP5 live-game AI scope"
above), not full mobile STRATEGIC/TACTICAL AI, which remains proven
separately in `AiMatchArena`. Save/load reconstructs them generically
through the existing non-player-unit deserialization path, with one
addition: a rival MC's own campaign-specific `mc_unit` must be
re-applied on load (the generic `_make_unit()` "MC" branch otherwise
defaults to `current_campaign.mc_unit`, which is only correct for the
player's own MC).

### Fixed: Nabil's VICTORY factory-check looked at the wrong factory

`_check_victory_condition()`'s Nabil branch (Prompt Dasar: "Tidak ada
pabrik cartel aktif") checked `factory.is_destroyed` — but `factory`
is the **player's own** factory node (always built in
`_build_buildings()`, including for Nabil, who starts at
`starting_factory_level = 0`). The rule is actually about the *rival
cartels'* factories, which didn't exist in the live game at all before
this MVP7 pass. Fixed alongside `_spawn_rival_factions()`, which
builds a destructible Factory per rival cartel HQ (skipping DEA, which
has no Factory/Dealer loop) into a new `_rival_cartel_factories`
array, and updated the victory check to look at that array instead.

### Fixed: safe-zone "weapons lowered" only protected the target, never the attacker

Prompt Dasar's "BANK DAN SAFE ZONE" section is explicit: *"Di dalam
safe zone: Tidak ada attack ... Senjata diturunkan"* (no attack,
weapons lowered) for whoever is standing inside it — and closes with
*"Musuh tidak boleh menunggu tepat di batas safe zone dan menembak
tanpa counterplay"* (an enemy must not be able to sit at the safe-zone
boundary and shoot with no counterplay). The existing implementation
only ever checked the **target's** position (`take_damage()` blocks
damage to a unit standing in a safe zone) — a unit standing *inside*
the zone could still fire outward at an unprotected target indefinitely,
exactly the forbidden exploit. Fixed in `unit.gd` by adding the
attacker/caster's own `economy.is_position_safe(global_position)`
check at every lethal/capture action: `_try_fire_stationary` (the
actual damage-dealing act), `order_use_grenade`, `order_execute`, and
`order_recruit_downed`. Covered by
`tests/test_mvp7_release_validation.gd`.

### MVP7 balance-report income metric: gross earned, not net balance delta

An early version of `tools/run_balance_report.gd` computed "income per
minute" as `(final money - starting money) / minutes` — this is a net
cash-flow delta, not income, and read as *negative* for every single
faction/difficulty in the first captured run purely because AI
spending (recruitment, ammo, vehicles, factory upgrades) outpaced
sales within a ~100s match. Fixed to use the existing
`CampaignEconomy.lifetime_money_earned` field (MVP6, tracks gross
earnings via `set_money()`'s increase-only accounting) instead. This
surfaced the same "starting money counts as earned" bug `open_world_map.gd`
had already been fixed for in MVP6 — `AiMatchArena._build_faction()`
also calls `economy.set_money(campaign.starting_money)` and needed the
identical one-line `lifetime_money_earned = 0` reset.

### MVP7: Wine cannot run any Windows binary under this sandbox's gVisor kernel

The Windows export itself succeeds cleanly (valid PE32+ x86-64
executable, official 4.3-stable export templates, embedded `.pck`).
Installing `wine64` via `apt` also succeeds. But *every* invocation —
including `wineboot --init` and a minimal `wine cmd.exe /c echo hello`
with no relation to this project's build — fails identically and
immediately, before any prefix-specific or game-specific code ever
runs:
```
err:seh:segv_handler Got unexpected trap 0   (repeated ~20-30x)
err:virtual:virtual_setup_exception stack overflow 1664 bytes ...
```
`uname -a` confirms a `gvisor`-suffixed kernel. This is a known class
of Wine/gVisor incompatibility: Wine's own NT-emulation bootstrap
relies on raw SIGSEGV-based exception trampolines and
`sigaltstack`/hardware-fault semantics that gVisor's user-space
syscall emulation does not reproduce faithfully — a sandbox platform
limitation, not something fixable via export settings, `ulimit`, or a
fresh `WINEPREFIX` (all tried). Reported via `report_platform_issue`.
Workaround: the Windows `.exe` was verified structurally (`file`
confirms valid PE32+ x86-64) but not executed; the equivalent Linux
x86_64 export was built and *actually run* headful under Xvfb instead
(screenshot-verified rendering the real Content Warning screen), as
the closest feasible "run the exported build, not just the editor"
substitute available in this environment. See
docs/RELEASE_CANDIDATE_REPORT.md.

### Confirmed pre-existing test flakiness (not introduced by MVP6/MVP7)

Several suites intermittently fail on an unrelated RNG/timing roll and
pass consistently on rerun with zero code changes to the files they
exercise — confirmed by reproducing on the pre-MVP7 commit before any
of this MVP's edits:
- `tests/test_mvp5_tactical_ai.gd`, `tests/test_mvp5_diplomacy.gd`,
  `tests/test_mvp5_arena.gd` — already noted in MVP6's own report.
- `tests/test_mvp3_vehicle.gd`'s moving-vs-stationary turret accuracy
  comparison — same root cause (an unseeded `randf()` accuracy roll
  can occasionally produce a moving-turret sample that, by chance,
  outscores a stationary one over a short window). Reproduced on
  `vehicle.gd` completely unmodified by this MVP7 pass.
These are accepted as known, harmless flakiness (not re-seeded or
otherwise hardened in this pass, to keep MVP7's own change scope to
what it actually needed) rather than silently ignored — see
docs/RELEASE_CANDIDATE_REPORT.md "Known bugs/technical risks".

## Release Candidate Fix Pass (post-MVP7)

Per a dedicated fix-pass request targeting the issues
`docs/RELEASE_CANDIDATE_REPORT.md` itself identified. Full write-up:
`docs/RELEASE_CANDIDATE_REPORT.md` "Release Candidate Fix Pass"
section. Key technical decisions:

### Main Character death consequences: tier weights derived from the existing payroll-desertion precedent

Prompt Dasar gives no exact flee/surrender/rogue odds ("Unit tersisa
dapat kabur, menyerah, atau menjadi rogue **berdasarkan tier**" — based
on tier, no numbers given). Rather than invent arbitrary numbers, this
fix pass derived weights from the one tier-based loyalty precedent the
project already has — the payroll-desertion rule ("Dua siklus: B1
dapat desertir; B2/B3/Special tetap ada tetapi mendapat penalti
combat"): the cheapest/weakest tier (B1) is the most likely to
abandon the fight, the toughest regular tier (B3) the least:
```
B1: 50% flee / 30% surrender / 20% rogue
B2: 30% flee / 35% surrender / 35% rogue
B3: 15% flee / 35% surrender / 50% rogue
```
Special is deliberately excluded from the roll entirely — Prompt Dasar
states outright "Special tidak menyerah" (never surrenders) and
"Special terus bertempur" (keeps fighting), so a Special's fate is
fixed at ROGUE (unchanged combat behavior, just flagged
`has_gone_rogue = true` for inspectability), not rolled.

### Surrender reuses the existing DOWNED state end-to-end, not a new state

"Menyerah" (surrender) transitions a unit directly into `State.DOWNED`
via the same `_enter_downed()` every combat-induced down already uses
— same `downed_timer` countdown, same execute/recruit/revive
interactivity, same HUD treatment. This reuses 100% of existing,
already-tested state machinery (the explicit instruction: "If the
project already has state types for... reuse them instead of creating
duplicate systems"). The only genuinely new field is `BwUnit.has_gone_rogue:
bool`, used purely for the ROGUE outcome (which needs no new combat
logic at all — a rogue unit already behaves exactly as before via its
existing `auto_defend`).

One real pre-existing assumption this broke and required fixing:
`open_world_map.gd`'s save/load path only re-entered `DOWNED` on load
when `saved_hp <= 0.0`, because before this fix pass a unit could only
ever reach `DOWNED` via lethal combat damage (hp always exactly 0). A
surrendered unit is now `DOWNED` with whatever hp it had when it gave
up (not necessarily 0) — loading with the old hp-gated condition would
have silently "stood them back up" instead of preserving the surrender
across a save/load cycle. Fixed by re-entering `DOWNED` whenever
`saved_state == DOWNED`, regardless of hp, setting `hp` directly
(bypassing `set_hp()`'s own auto-downed-trigger to avoid a redundant
double-entry) before doing so.

### "Kabur" (flee): a short, bounded, generic escape — not full pathfinding to a map edge

A fleeing unit gets `can_move` temporarily re-enabled (these are
stationary `can_move = false` fixed encounters by design — see "MVP5
live-game AI scope" above), is ordered away from `player_hq_position`
by a fixed distance (clamped to `MAP_BOUNDS`), and despawns after a
flat `FLEE_DESPAWN_SEC` (8s) regardless of whether it precisely
reached that point — "kabur" means the player no longer has to deal
with them, not that the player must watch them path exactly to a
coordinate. Flee timers are deliberately not persisted across save/
load (pure runtime bookkeeping), matching the existing fidelity level
of the save system (patrol points aren't reconstructed on load either).

### Main Character death consequences only ever apply to the losing side, never the player's own

Prompt Dasar describes two *distinct* branches: player MC death →
immediate DEFEAT (unchanged, already correct since MVP6); enemy MC
death → that faction eliminated + flee/surrender/rogue for survivors.
`_apply_mc_death_consequences(faction_side)` is written generically (not
hardcoded "enemy only") so it would work correctly if ever invoked for
the player's side, but it is only ever actually invoked from
`_on_enemy_died` — the player's own MC death goes through the entirely
separate `_on_player_mc_died` → `victory_defeat_screen.show_result(false, ...)`
path and never reaches this function. "Where applicable" (this fix's
own phrasing) therefore correctly excludes the player's side here.

### Fixed: Fauzi (Zie/Vartieri) AI never bought a vehicle — root cause was tick-order priority, not a wiring bug

Investigated the full purchase pipeline end-to-end with a standalone
probe script driving just her `FactionStrategicAI` in isolation,
logging money/vehicle-count every ~10 simulated seconds.
`_manage_vehicles()` itself was always correct (`owned.size() >= 1:
return`; `economy.can_afford(cheapest.price)` gate) — the real cause
was `_physics_process()`'s call order: `_manage_recruitment()` ran
*before* `_manage_vehicles()` every decision tick, with no reserve set
aside for the one-time vehicle purchase. Zie's recruitment costs
(B1 $330/B2 $850/B3 $1900/Special $6500) are the highest of the three
cartel factions (Juan's and Andrés's are both lower at every tier),
so her cash almost never idled above the Compact's $1800 price by the
time the vehicle check ran — confirmed directly: the probe showed her
money oscillating $440-$1100 for the entire ~100s match while
recruitment/factory-upgrade repeatedly consumed it first. This matches
"incorrect AI priority," one of the root-cause categories this fix
pass was explicitly asked to check for, rather than "purchase
threshold too high" or a wiring/affordability bug.

Fix: moved `_manage_vehicles()` to run *first* in the decision order,
before recruitment/factory-upgrade compete for the same cash. No
change to either function's own logic/thresholds. Verified: the same
probe now shows Zie buying the Compact on her very first decision tick
using starting capital (before recruitment ever touches it); the full
balance report (3 trials × 4 campaigns × 3 difficulties = 36 total AI
matches) now shows **100% vehicle presence across all 12
faction/difficulty cells** (previously 0% for all 3 Fauzi rows, 100%
for everyone else). Deliberately did not special-case Zie — the fix
is a single, faction-agnostic reorder, and every other faction's
vehicle-purchase success rate was already 100% either way, so this
could not have been "faked" by targeting her specifically.

### Fixed: `CampaignDatabase`/`CampaignEconomy` never loaded any data in an actual export — the most serious bug this fix pass found

This fix pass's Windows/Linux export verification (Issue 3/5) surfaced
a critical, pre-existing, **export-only** bug that had silently gone
undetected through every prior MVP (0-7): an exported/PCK build's
`DirAccess.get_next()` lists resource files with Godot's own internal
redirection suffix appended — `"faction_bellarosa.tres"` is listed as
`"faction_bellarosa.tres.remap"` — but `CampaignDatabase._load_dir()`,
`CampaignEconomy._load_weapon_catalog()`, and
`tools/validate_asset_manifest.gd._validate_campaign_references()` all
matched filenames with a literal `file_name.ends_with(".tres")` check,
which **never matches** the `.remap`-suffixed form. Every single
campaign/faction/difficulty/weapon resource therefore silently failed
to load in any real export — confirmed directly by running the actual
exported Linux binary (not the editor) headful under Xvfb: console
printed `[CampaignDatabase] loaded 0 faction(s), 0 campaign(s), 0
difficulty(ies)`, and a scripted smoke-test driver hit a null-MC crash
loop trying to enter gameplay. This had been invisible through every
previous MVP's own verification because every single one of them ran
via `godot4 --headless --path .` (editor/script mode), which reads the
real on-disk filesystem directly with no `.remap` indirection layer at
all — the bug could only ever be observed by running an actual export,
which this fix pass's Issue 5 ("make the game actually playable on
Windows/export") was the first to require.

Fix: at all 3 call sites, strip a trailing `".remap"` suffix before the
`.ends_with(".tres")` check and before calling `load()` (which must be
given the real, un-suffixed resource path regardless of which form
`DirAccess` reported — confirmed empirically: `load()` and
`ResourceLoader.exists()` both work correctly on the un-suffixed path
inside the export; Godot's own loader internally consults the remap
table). Verified end-to-end against the real rebuilt exported Linux
binary: `[CampaignDatabase] loaded 4 faction(s), 4 campaign(s), 3
difficulty(ies)`, followed by a full scripted playthrough (launch →
menu → campaign select → gameplay with the real MC + 3 real rival MCs
→ move order → rival MC death → flee/surrender/rogue fired for real →
player MC death → DEFEAT screen with full campaign summary → clean
exit) screenshotted at every step. New regression test:
`tests/test_rc_export_remap_resilience.gd` asserts the *symptom*
directly (non-empty `factions`/`campaigns`/`difficulties`/
`weapon_catalog`) so this specific class of regression is caught even
though the test itself runs in editor/script mode (which cannot
reproduce the PCK remap layer directly — an actual export + run, as
done for this verification, remains the only way to observe the real
bug class itself; see `docs/RELEASE_CANDIDATE_REPORT.md` for the full
before/after evidence).

## Final Playable-Build Verification Pass (post-RC-fix)

A follow-up request specifically asked to confirm MVP0-7 + the RC Fix
Pass is actually ready to download/open/play on Windows, with an
explicit instruction to search the whole repository for any other
instance of the `.remap` resource-loading pattern before declaring
completion. Full write-up: `docs/RELEASE_CANDIDATE_REPORT.md` "Final
Playable-Build Verification Pass". Two findings:

### One more unfixed `.remap`-vulnerable instance found: `tests/test_campaign_data.gd`

A repository-wide search (`grep -rn "DirAccess\|list_dir_begin\|ends_with(\".tres\")"`)
found exactly 4 files using directory-enumeration resource discovery;
3 were already fixed in the prior RC Fix Pass
(`campaign_database.gd`, `campaign_economy.gd`,
`validate_asset_manifest.gd`), but `tests/test_campaign_data.gd`'s own
`_load_campaigns()`/`_test_difficulties_load()` helpers still used the
unfixed literal `ends_with(".tres")` pattern. This instance was never
actually reachable through the real bug (this script is dev-only,
always invoked directly via `--script` against the real project
filesystem, never auto-run as part of a shipped export's own boot
path the way the `CampaignDatabase`/`CampaignEconomy` autoloads are)
— but it is textually the exact same vulnerable pattern, in the same
family of already-partially-fixed data-validation tooling. Fixed for
consistency with the identical minimal `.remap`-suffix-stripping
approach, so every directory-scanning resource loader in the
repository now handles both forms identically — closing the loop on
"search the entire repository for similar patterns" rather than
leaving one instance of the same bug class unaddressed by happenstance.

### Windows export rcedit/Wine noise (cosmetic, fixed via a one-line export-preset change)

Re-exporting the Windows build in this verification pass surfaced a
new, unrelated console warning not present in the earlier RC Fix Pass
export: `rcedit (...): it looks like wine32 is missing` followed by
dozens of the same Wine/gVisor `segv_handler`/`stack overflow` traces
already reported for Windows runtime execution. Root cause: this
sandbox session had `wine64` installed (for the earlier, separate
attempt to execute the Windows `.exe` directly) between the RC Fix
Pass's export and this one; Godot's Windows export pipeline detects
Wine's presence and automatically attempts to invoke `rcedit` through
it to embed the `.exe`'s Windows file-icon/version-info metadata
(`application/modify_resources` in `export_presets.cfg`) — a
cross-compilation convenience when exporting to Windows from a Linux
host. `rcedit` itself needs 32-bit Wine support (`wine32`), which was
never installed, so the attempt immediately fails, hitting the exact
same Wine/gVisor incompatibility already reported. **This is not a
project defect**: the export still completed successfully every time
(exit 0, correct `file`-reported type, consistent `.pck`-embedded
size) — `modify_resources` only affects the `.exe`'s Windows Explorer
file icon/version metadata, never the game's actual resources,
scripts, or runtime behavior (the game's own in-game icon is a
separate, unaffected `project.godot config/icon` setting). On a real
developer's machine (native Windows export, or a Linux host with a
complete, non-gVisor Wine install), this step either doesn't need
Wine at all or would simply succeed. Fixed by setting
`application/modify_resources=false` in the committed
`export_presets.cfg` — this avoids a step that cannot functionally
succeed in *this specific sandbox's* partial Wine setup, producing a
completely clean, warning-free export log, without touching any
setting that affects the actual shipped game.

### Full end-to-end vertical-slice smoke test against the rebuilt exported binary

Re-ran the complete scripted playthrough against a freshly rebuilt
Linux export (same source as the Windows export, both rebuilt after
the fixes above): Content Warning → Main Menu → Campaign Select (4
cards rendered) → Difficulty Select → Story Panel → real gameplay
(real MC + 3 real rival MCs + starting vehicle present) → a core
player action (move order, confirmed `State.MOVING`) → a real rival
MC's combat death → flee/surrender/rogue fired for real → the
player's own MC death → DEFEAT with a full campaign summary → clean
exit (code 0). Screenshotted at every step. This is the same flow as
the RC Fix Pass's own verification, re-run end-to-end once more after
this pass's additional fixes, confirming nothing regressed.
