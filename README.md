# Bad World

Single-player, open-world, 2.5D isometric real-time strategy game built
in Godot 4.x with typed GDScript. Four asymmetric campaigns (Juan
Bellarosa, Zie Vartieri, Andrés A. Násion, Nabil Verhan) built up
incrementally through a sequence of MVPs defined in
`Prompt AI Bad World GAME -/Part 1.txt` (base rules) through
`Part 9.txt` (MVP 7, release candidate).

**Current status: MVP 7 — Release Candidate Validation (not
production-ready — see docs/RELEASE_CANDIDATE_REPORT.md for the full
breakdown of what's verified, what's still placeholder, and what's not
yet done).**
VICTORY is now reachable by playing, not just testable in isolation:
real rival-faction Main Characters (their own faction's combat stats)
spawn at the other 3 HQs and are checked by the win condition,
including Nabil's extra "no active cartel factory" requirement against
real, destructible rival factories. This pass also found and fixed two
real pre-existing bugs (Nabil's victory check was looking at the wrong
factory; a unit standing inside a safe zone could attack/execute/
recruit/throw-grenades outward with zero counterplay), added a
release-candidate balance report (match duration, win rate, income/
min, army size, ambush/DEA frequency, MC survival, Easy/Medium/Hard
differences — see docs/BALANCE.md), confirmed 60 FPS with all 4
factions active and units near the roster cap, and produced Windows +
Linux export builds (the Linux one verified actually running
headful; Windows could not be executed in this sandbox due to a
Wine/gVisor incompatibility — see docs/RELEASE_CANDIDATE_REPORT.md).
A content warning now opens the app, followed by a Main Menu →
Campaign Select (full cards: portrait, faction, strengths/weaknesses,
starting units, economy rating, unit cap) → Difficulty → Story → the
open world. A contextual tutorial teaches the core loop (selection,
movement, recruitment, equipment, ammo, factory/dealer/bank, vehicle,
patrol, defend, protecting the Main Character) with each hint shown
once. The HUD gained payroll/low-ammo warnings, a factory/dealer
demand readout, a Nabil-only patrol-efficiency overlay, a diplomacy
panel, and an off-screen "Under Attack" camera alert. Settings now has
real volume sliders (Master/Music/SFX) and full key rebinding; saves
gained a dedicated autosave slot plus 3 independent manual slots with
schema migration; and the player's Main Character dying now shows a
DEFEAT screen with a full campaign summary (the matching VICTORY rule
is implemented and tested the same way, but isn't reachable yet since
rival faction HQs aren't live in the open world — see
docs/PLACEHOLDER_REGISTER.md). Layered on top of MVP5's layered
TACTICAL/STRATEGIC/INFORMATION/AMBUSH/DIPLOMACY AI, MVP4's four
asymmetric campaigns, MVP3's open-world economy/vehicle loop, and
MVP1/2's RTS controls and weapon-data combat.
See docs/IMPLEMENTATION_PLAN.md for the full roadmap and what each MVP
delivered.

## Controls (gameplay)

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
- `P` then right click: Patrol Mode (walks a loop between the current
  position and the clicked point, auto-engaging intruders).
- Right click your own vehicle (with a free seat): selected units walk
  over and board it (first arrival drives). `X`: exit a mounted vehicle.
- `E`: interact with whatever building/vehicle the selected unit is
  standing at (pick up factory cargo, sell to a dealer, deposit at the
  Bank, repair at the Garage, or open the Recruitment/Gun Shop panel).
- Ability bar (bottom-left, when a Main Character is selected): each
  faction's active abilities as buttons, showing live cooldown
  countdowns. AoE abilities (Throw Drug Bottle) arm a targeting mode —
  click a button, then right-click the ground.
- **Upgrade MC** (top-right HUD button): spend money to level the
  Main Character up to level 5.
- Nabil's campaign replaces the Gun Shop with a **DEA Armory** (craft
  weapons from Parts, not money) and replaces the hostile Heat/DEA
  mechanic with a **Dispatch Allies** HUD button (budgeted, on a
  cooldown).
- `Ctrl`+1‑9: assign control group. 1‑9: recall control group.
- Arrow keys / mouse near screen edge: pan camera. Mouse wheel: zoom.
- `Escape`: pause menu (resume / restart / Save-Load slot picker /
  Settings / quit to menu).
- All of the above letter-key hotkeys are rebindable (Pause → Settings
  → Controls tab, or Main Menu → Settings), via real `InputMap`
  actions rather than hardcoded keys; this list shows each action's
  default key.
- HUD buttons (top-right): **Inspect** (view the selected unit and
  manually assign purchased equipment — nothing auto-equips) and
  **Alerts** (recent combat/economy log). Recruitment and Gun Shop are
  now real in-world buildings in Central City (walk up + `E`), not
  always-visible buttons.
- A minimap (bottom-right) shows unit/building positions.
- `F3`: toggle the AI debug overlay (dev builds only — shows live
  AI objective/utility/decision-reason and known-enemy intel; freed on
  startup and structurally absent in a release export).

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
- `docs/RELEASE_CANDIDATE_REPORT.md` — MVP7 release-candidate
  validation: what's done+verified, placeholder, not yet done, known
  bugs, technical risks, and how to run from source / build Windows.

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
