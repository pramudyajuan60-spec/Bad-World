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

## MVP 1 automated checks (all run and passing at time of writing)

4. **Formation + selection math** (`tests/test_formation_and_selection.gd`):
   proves formation-spaced positions are always distinct and at least
   `spacing` apart (units never stack at a shared destination), and that
   the box-select / same-tier / control-group helpers in
   `SelectionManager` behave correctly, using real `BwUnit` instances
   (not mocks). Exit 0, `[Tests] formation_and_selection: all passed.`

5. **Save/load round trip** (`tests/test_save_service.gd`): saves a
   payload with 2 units to a dedicated test slot, reloads it, and checks
   every field round-trips exactly; also proves a missing slot and a
   deliberately corrupted JSON file both return `null` instead of
   crashing (the `ERROR: Parse JSON failed` / `SaveService: corrupt
   save ...` lines in the log are the *expected* output of that specific
   sub-test, not a failure). Exit 0, `[Tests] save_service: all passed.`

6. **Combat + navigation** (`tests/test_combat_and_navigation.gd`):
   builds a real `NavigationRegion2D` + navmesh, spawns real `BwUnit`
   instances, and drives several seconds of physics frames to prove (a)
   an `order_move()` unit actually travels via pathfinding to
   `State.IDLE`, not a teleport, and (b) `order_attack_move()` acquires a
   nearby hostile unit, closes to range, and kills it (a deliberately
   guaranteed one-hit-kill setup for determinism). Exit 0,
   `[Tests] combat_and_navigation: all passed.`

   Implementation note found while writing this test: GDScript lambda
   closures capture outer local variables **by value**, not by
   reference — a `signal.connect(func(): outer_var = true)` pattern does
   not let the callback flip a caller-visible flag. The test instead
   polls `is_instance_valid(enemy)` directly each frame. Worth knowing
   before relying on that pattern elsewhere.

## Manual visual verification (MVP 1)

Godot has no GPU in this sandbox by default; `Xvfb` + Mesa `llvmpipe`
software rendering was used to run the real (non-headless) binary and
capture screenshots via `get_viewport().get_texture().get_image()` for
each menu screen and the gameplay scene. Confirmed: Main Menu (Continue
correctly disabled with no save), Campaign Select (only Juan enabled,
others visibly "Locked — playable in a later MVP", correct canonical
names including "Zie Vartieri"), Story Panel (real portrait + full
`Story.txt` text), and the gameplay scene (Juan + 3 B1 as blue markers
with green health bars and tier labels, 4 red "ENEMY" dummies, obstacle
rectangles, and the Bellarosa concept map as a dimmed background). These
screenshots are not committed to the repository; they were shared
directly in the pull request/chat as verification evidence.

## Known gaps not covered by MVP 1 tests

- No simulated mouse/keyboard input test for `CommandController` itself
  (box-select drag, double-click, hotkeys) — its logic delegates to the
  tested `SelectionManager`/`FormationUtils` helpers, but the raw
  `_unhandled_input` glue is only manually/visually verified.
- No automated camera pan/zoom/clamp-to-bounds test (visual-only check).
- No FPS/performance measurement at the "unit count near cap" scale
  required by later MVPs' acceptance criteria.

## MVP 2 automated checks (all run and passing at time of writing)

7. **Weapon combat** (`tests/test_weapon_combat.gd`): a magazine
   genuinely depletes round-by-round, triggers a reload once empty (with
   reserve remaining) that refills correctly, and — once both magazine
   and reserve are exhausted — the unit falls back to its equipped
   melee secondary rather than "fake" firing forever. A separate case
   places a solid obstacle directly between attacker and target and
   proves zero shots are fired and zero damage lands despite the target
   being technically in range (line-of-sight blocks the shot). Exit 0,
   `[Tests] weapon_combat: all passed.`

8. **Downed / revive / execution** (`tests/test_downed_revive_execute.gd`):
   lethal damage downs a unit instead of freeing it instantly; an ally
   channeling revive on a downed unit restores it to `IDLE` with partial
   HP; an uninterrupted execution channel (the explicit 6s from Prompt
   Dasar) permanently kills a downed hostile, while damaging the
   executor mid-channel cancels it, leaving the target still downed; a
   downed unit whose timer reaches zero without intervention dies
   permanently. Exit 0, `[Tests] downed_revive_execute: all passed.`

9. **Cover + suppression** (`tests/test_cover_and_suppression.gd`): the
   same 100-damage hit is reduced when the attacker is on a defending
   unit's covered side and full when on the open flank; taking fire
   measurably reduces effective accuracy; and heavy suppression while
   actively attacking triggers the simple retreat behavior. One real bug
   was caught and fixed here during development: placing two units
   closer together than their combined collision radius let
   `move_and_slide()`'s physical collision resolution push them apart
   every frame, silently drifting a unit out of its own weapon range
   mid-test — worth remembering when placing units in any future test.
   Exit 0, `[Tests] cover_and_suppression: all passed.`

10. **Economy + safety** (`tests/test_economy_and_safety.gd`):
    recruiting a unit deducts its price immediately but only joins the
    roster after its full recruitment timer elapses; recruiting past
    `max_roster` is rejected even with unlimited money; a payroll cycle
    with insufficient funds is marked missed and applies the
    accuracy/speed/morale penalty, while a subsequent funded cycle pays
    and recovers morale; a unit standing inside a safe-zone radius takes
    zero damage while an identical unit far outside takes full damage;
    and an explosive hit on both an ally and a hostile inside its blast
    radius deals strictly less damage to the ally (limited friendly
    fire) and logs a warning. Exit 0,
    `[Tests] economy_and_safety: all passed.`

## MVP 2 manual visual verification

Same Xvfb + Mesa llvmpipe approach as MVP1. Confirmed: the HUD topbar
(money/roster) and three building buttons render; the Recruitment panel
shows correct per-tier price/salary with Special locked; the Gun Shop
panel lists all 10 weapons with correct prices and updates "owned
(unassigned)" counts after a purchase (money deducted accordingly); the
Inspect panel shows Juan's pre-equipped Pistol/Knife and offers newly
purchased items for manual assignment to primary/secondary/grenade/armor
slots. Screenshots shared in the pull request, not committed to the repo.

## Known gaps not covered by MVP 2 tests

- No automated test for the Recruitment/Gun Shop/Inspect HUD panels
  themselves (button wiring) — verified manually/visually only.
- No automated test for recruiting a downed enemy through to full
  roster conversion (`bellarosa_test_map.gd::_on_recruit_completed`) —
  the underlying channel mechanics (`order_recruit_downed`) share the
  same tested code path as revive, but the economy-side conversion
  (cost check, reparenting, roster increment) is manual/visual-only.
- No automated test for grenade-throwing via the `G`-armed hotkey path
  itself (the underlying explosive/AoE/friendly-fire mechanic it calls
  is tested directly in test_economy_and_safety.gd).
