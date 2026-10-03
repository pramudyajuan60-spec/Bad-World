# Bad World

Single-player, open-world, 2.5D isometric real-time strategy game built
in Godot 4.x with typed GDScript. Four asymmetric campaigns (Juan
Bellarosa, Zie Vartieri, Andrés A. Násion, Nabil Verhan) built up
incrementally through a sequence of MVPs defined in
`Prompt AI Bad World GAME -/Part 1.txt` (base rules) through
`Part 9.txt` (MVP 7, release candidate).

**Current status: MVP 0 — Repository Audit and Godot Bootstrap.**
No gameplay exists yet; see docs/IMPLEMENTATION_PLAN.md for the roadmap
and docs/REPO_AUDIT.md for what MVP 0 actually verified.

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

See docs/TEST_PLAN.md for exact expected output.

## Documentation

- `docs/REPO_AUDIT.md` — commit confirmation, asset inventory summary,
  known naming/asset mismatches.
- `docs/ASSET_INVENTORY.md` — source-art inventory snapshot and path hazards.
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

## Asset handling

- Do not modify or delete original assets destructively; keep derived crops,
  placeholders, and processed output in separate directories.
- Many asset names contain spaces or commas, repeated basenames occur across
  folders, and `Spritsheet/` is the historical on-disk spelling. Quote paths
  in scripts and consult `docs/ASSET_INVENTORY.md` before referring to assets.
- The four `Main Character/Story.txt` files contain canonical Indonesian lore;
  do not rewrite them when building campaign presentation.
