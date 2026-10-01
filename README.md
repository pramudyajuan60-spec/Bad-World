# Bad World

Single-player, open-world, 2.5D isometric real-time strategy game built
in Godot 4.x with typed GDScript. Four asymmetric campaigns (Juan
Bellarosa, Zie Vartieri, Andrés A. Násion, Nabil Verhan) built up
incrementally through a sequence of MVPs defined in
`Prompt AI Bad World GAME -/Part 1.txt` (base rules) through
`Part 9.txt` (MVP 7, release candidate).

**Current status: MVP 5 — Intelligent AI and Diplomacy.**
Layered AI is implemented: a per-unit TACTICAL layer (target priority,
flanking, proactive retreat, revive, protect-MC, grenade avoidance) and
a per-faction STRATEGIC layer (recruitment, ammo/weapon resupply,
factory upgrades, dealer selection, cash-running to the Bank,
vehicle purchase/repair, HQ defense, scouting, and utility-gated
raid/attack-MC decisions), both driven by real fog-of-war
(`FactionKnowledge` — enemies are only known if actually seen, with
last-known-position memory and staleness). A separate `AmbushController`
arms and triggers ambushes only with intel + a real tactical advantage,
and a `DiplomacyController` handles neutral encounters, trust, temporary
alliances with a trade bonus, and betrayal. Difficulty (Easy/Medium/
Hard) only changes decision quality/timing, never money or vision — a
same-faction cross-difficulty test shows Hard beating Medium 3/3 and
Medium beating Easy 3/3. A dev-only F3 debug overlay (structurally
absent from release exports) shows live AI state/objective/utility, and
a headless `AiMatchArena` runs full AI-vs-AI matches with a win-rate
report per faction/difficulty — see docs/BALANCE.md. Layered on top of
MVP4's four asymmetric campaigns, MVP3's open-world economy/vehicle
loop, and MVP1/2's RTS controls and weapon-data combat.
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
- `Escape`: pause menu (resume / restart / save / load / quit to menu).
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
