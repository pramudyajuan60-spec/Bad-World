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
