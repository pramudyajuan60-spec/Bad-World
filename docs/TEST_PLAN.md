# Test Plan

## Testing strategy across MVPs

MVP 0 has no gameplay, so it is verified with headless data/boot checks
only. As gameplay systems are added, this plan grows to cover: scripted
gameplay scenarios (selection/movement/combat), headless AI simulations
(win-rate/balance), save/load round-trips, and eventually an exported
Windows build smoke test (MVP 7). Each later MVP's own acceptance
criteria (see `Prompt AI Bad World GAME -/Part 3.txt`..`Part 9.txt`) is
the authoritative source for what that MVP must additionally test.

## MVP 0 automated checks (all run and passing at time of writing)

1. **Project boot check** — proves "project.godot dapat dibuka" and "Main
   scene kosong/minimal dapat dijalankan" with zero missing
   script/resource errors:
   ```
   godot4 --headless --path . --quit
   ```
   Result: exit code 0, log shows
   `[CampaignDatabase] loaded 4 faction(s), 4 campaign(s), 3 difficulty(ies).`
   and `[MVP0] Loaded 4 campaign(s) from data.` with no `ERROR`/
   `SCRIPT ERROR` lines.

2. **Asset manifest validation** — proves "Asset manifest dapat
   divalidasi":
   ```
   godot4 --headless --path . --script res://tools/validate_asset_manifest.gd
   ```
   Result: exit code 0. Verified 306/306 cataloged files still exist on
   disk, and all asset paths referenced by the 4 `CampaignData` resources
   (story, portrait, main-character sprite, concept map) resolve to real
   files. Exit code is non-zero if manifest drift or a broken data
   reference is introduced later.

3. **Data-layer smoke tests** — proves "Empat campaign dapat dimuat dari
   data" plus a couple of spec-fidelity regressions:
   ```
   godot4 --headless --path . --script res://tests/test_campaign_data.gd
   ```
   Result: exit code 0, `[Tests] All MVP0 smoke tests passed.` Covers:
   exactly 4 campaigns load; all 4 expected campaign IDs are present;
   `campaign_fauzi`'s main character name stays `"Zie Vartieri"` (not
   "Valtieri") and its faction display name stays `"Vartieri Cartel"`;
   `campaign_nabil.starting_money == 6500` (BALANCE V0.1); exactly 3
   difficulty presets load.

4. **Asset manifest generator idempotency** — re-running the Python
   generator should reproduce the same 306-entry manifest:
   ```
   python3 tools/generate_asset_manifest.py
   ```

## How to reproduce these results

Godot 4.3 stable must be available (see docs/TECH_DECISIONS.md for the
download link/flags). No sandbox/CI runner is configured yet — running
the three `godot4 --headless ...` commands above manually is the current
"test suite". Wiring these into CI is left for a later MVP once there is
a stable place to run them from (this environment downloaded the engine
binary ad hoc for this session; it is not committed to the repo).

## Known gaps not covered by MVP 0 tests

- No visual/rendering verification (no camera, no sprites drawn yet).
- No UI interaction testing (Main.tscn has no buttons yet).
- No performance/FPS measurement (nothing renders continuously yet).
- No export/build test (Windows export is MVP 7 scope).
