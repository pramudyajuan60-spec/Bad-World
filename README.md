# Bad World

Single-player, open-world, 2.5D isometric real-time strategy game built
in Godot 4.x with typed GDScript. Four asymmetric campaigns (Juan
Bellarosa, Zie Vartieri, Andrés A. Násion, Nabil Verhan) built up
incrementally through a sequence of MVPs defined in
`Prompt AI Bad World GAME -/Part 1.txt` (base rules) through
`Part 9.txt` (MVP 7, release candidate).

**Current status: MVP 2 — Combat and Unit Management.**
Main menu → campaign/difficulty select → story panel → one playable
isometric test map with real weapon-data combat (ammo, reload,
line-of-sight), Defend/Cover Mode, suppression/retreat, downed/revive/
execution, Recruitment + Gun Shop + Inspect panels, payroll, and safe
zones. See docs/IMPLEMENTATION_PLAN.md for the full roadmap and what
each MVP delivered.

## Controls (MVP 1 gameplay)

- Left click: select one unit. Shift+click: add/remove from selection.
  Drag: box select. Double-click: select all visible units of that tier.
- Right click ground: move (formation-spaced). Right click enemy: attack.
- `A` then right click: attack-move. `S`: stop.
- `D`: Defend/Cover Mode (moves to nearest cover, takes reduced damage
  from the blocked direction only).
- `G` then right click: throw the equipped grenade at that position.
- `R` then right click a downed enemy (with the Main Character
  selected): recruit instead of execute.
- Right click a downed ally: revive. Right click a downed enemy:
  execute (default) or recruit (with `R` armed, see above).
- `Ctrl`+1‑9: assign control group. 1‑9: recall control group.
- Arrow keys / mouse near screen edge: pan camera. Mouse wheel: zoom.
- `Escape`: pause menu (resume / restart / save / load / quit to menu).
- HUD buttons (top-right): **Recruitment** (hire B1/B2/B3, Special
  locked), **Gun Shop** (buy weapons/armor into a shared pool),
  **Inspect** (view the selected unit and manually assign purchased
  equipment — nothing auto-equips).

## Running the project

1. Install **Godot 4.3 stable** (or a later 4.x stable release) from
   https://godotengine.org/download/ — do not use a beta/preview build.
2. Open this repository's root folder as the Godot project (it contains
   `project.godot`), or run headlessly:

   ```sh
   # Open in the editor
   godot4 --path . --editor

   # Or just boot the (currently minimal) main scene once and quit
   godot4 --headless --path . --quit
   ```

## Automated checks

```sh
# Regenerate the asset manifest after any change under Assets/
python3 tools/generate_asset_manifest.py

# Validate the manifest + data-driven campaign references (headless)
godot4 --headless --path . --script res://tools/validate_asset_manifest.gd

# Run the MVP 0 data-layer smoke tests (headless)
godot4 --headless --path . --script res://tests/test_campaign_data.gd
```

All three currently pass. See docs/TEST_PLAN.md for exact expected
output.

## Documentation

- `docs/REPO_AUDIT.md` — commit confirmation, asset inventory summary,
  known naming/asset mismatches.
- `docs/ASSET_MANIFEST.md` — full generated per-file asset catalog.
- `docs/TECH_DECISIONS.md` — engine/version/renderer/layout choices.
- `docs/ARCHITECTURE.md` — module breakdown and stable ID conventions.
- `docs/BALANCE.md` — transcribed reference numbers (not yet implemented
  in gameplay).
- `docs/IMPLEMENTATION_PLAN.md` — the 8-MVP roadmap and current status.
- `docs/PLACEHOLDER_REGISTER.md` — placeholder policy and known gaps.
- `docs/TEST_PLAN.md` — how MVP 0 (and later MVPs) are verified.

## Repository layout

```
Assets/                 Original art, story text, and reference maps (untouched)
Prompt AI Bad World GAME -/   Base rules + one prompt per MVP (0-7)
Prompt SpritSheet/      Prompts used to generate the sprite-sheet art
project.godot           Godot project settings
scenes/, scripts/       Godot scenes and typed GDScript
data/                   Data-driven Resource instances (campaigns, factions, difficulty)
tools/, tests/          Asset-manifest tooling and headless smoke tests
docs/                   Project documentation (see above)
```
