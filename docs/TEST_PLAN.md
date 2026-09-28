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

## MVP 3 automated checks (all run and passing at time of writing)

11. **Economy loop** (`tests/test_mvp3_economy_loop.gd`): a factory
    produces cargo over simulated time (capped at its on-site max); a
    unit picks up cargo, sells it at a dealer through the real 5s
    channel, and deposits the resulting carried cash at the Bank
    through the real 6s channel, with bank balance verified to
    increase by exactly the deposited amount and never touched before
    that point; two independent dealers are proven to track separate
    demand curves; and a destroyed factory is proven to halt
    production until repaired, then resume. Exit 0,
    `[Tests] mvp3_economy_loop: all passed.`

12. **Vehicles** (`tests/test_mvp3_vehicle.gd`): a 4-seat vehicle
    accepts exactly 4 of 5 attempted entries; entering hides the unit
    and marks it mounted/driver correctly, exiting restores it; a
    moving turret is proven to deal measurably less damage than an
    identical stationary one over the same duration; and repairing a
    damaged vehicle restores full HP for a reported positive cost.
    Exit 0, `[Tests] mvp3_vehicle: all passed.`

13. **Heat + loot** (`tests/test_mvp3_heat_and_loot.gd`): a DEA wave
    dispatches only after both the full 120s combat timer and the 60s
    travel delay elapse (not before); heat decays instead of
    eventually dispatching on its own if combat stops early; exactly 2
    waves dispatch and a 3rd is blocked by the cluster cooldown; the
    picked spawn point is always far from the player; and a downed
    carrier is proven to drop its exact cargo/cash amounts as loot,
    emptying itself. Exit 0, `[Tests] mvp3_heat_and_loot: all passed.`

14. **Save/load extension** (`tests/test_mvp3_save_load.gd`): loads
    the real `OpenWorldMap` scene, mutates money/factory level+cargo/
    Heat wave count/a unit's carried cargo+cash, adds a placed vehicle,
    saves to a dedicated test slot, reloads the scene from that slot,
    and checks every one of those fields round-trips correctly. Exit 0,
    `[Tests] mvp3_save_load: all passed.`

Two real bugs were caught and fixed while writing these (both now
documented in `docs/TECH_DECISIONS.md`): `Object.get_meta(key, null)`
still logs a spurious `ERROR` for a missing key in Godot 4.3 even
though it correctly returns the null default (fixed with a `has_meta()`
guard in `drug_dealer.gd`); and a from-scratch isolated repro
reconfirmed that GDScript lambdas connected to a signal cannot mutate
an outer captured local (a test counter incremented inside such a
lambda stayed at 0 after two signal emissions) — every MVP3 signal-
payload assertion uses a bound method on the test script instead.

## MVP 3 manual visual verification

Same Xvfb + Mesa llvmpipe approach as MVP1/2. Confirmed via screenshots
at three camera positions: the Bellarosa region (Juan + 3×B1 spawned,
enemy squad, HQ marker, Factory building, all correctly placed and
rendered); Central City (Bank/Recruitment/Gun Shop/Garage all placed
and labeled); and a zoomed-out full-world view confirming all 5 regions
sit in the correct compass positions relative to each other (Bellarosa
NW, DEA NE, Nasion SW, Vartieri SE, Central City center) matching the
layout `Assets/Game Maps/World.png` describes, with the minimap in the
corner showing proportionally correct dot positions for the same
buildings. Screenshots shared in the pull request, not committed to
the repo.

## Known gaps not covered by MVP 3 tests

- No automated test drives the actual `E`-key interaction path
  end-to-end through `CommandController`/`open_world_map.gd`'s
  `_handle_interact()` — the underlying building methods it calls
  (`try_pickup`, `start_sell`, `start_deposit`, `try_repair`) are each
  tested directly.
- No automated test for the DEA response wave's actual unit/vehicle
  composition once spawned into a live scene (only the *timing* and
  *spawn-point* logic in `heat_manager.gd` are tested in isolation).
- No automated test for Patrol Mode's return-to-route-after-combat
  behavior (manually reasoned through the same tested state-machine
  code path as attack-move, but not scripted end-to-end).
- Navigation/vehicle profiling (`tools/profile_navigation_and_vehicles.gd`)
  was run once headlessly for this report (see docs/IMPLEMENTATION_PLAN.md
  "MVP 3 delivered scope"); it is not a repeated/automated regression
  check, and its headless-pacing caveat means it's a sanity check, not
  a strict unpaced CPU benchmark.

## MVP 4 automated checks (all run and passing at time of writing)

15. **Campaign spawn differences** (`tests/test_mvp4_campaign_spawn.gd`):
    menu names ("Campaign Fauzi"/"Campaign Atha") stay distinct from
    the actual character names (Zie Vartieri/Andrés A. Násion) per
    Prompt Dasar; each of the 4 campaigns spawns its own correct
    starting money, MC, and starting squad (3xB1, or 3xB2 for Nabil);
    Andrés's factory starts at Level 2 and his B1 is proven weaker
    (lower HP) than Juan's; Nabil's roster cap is 24 (not 30), has no
    "B1" key in `economy.unit_data_by_tier` at all, spawns zero B1
    units, and cannot recruit enemies. Exit 0,
    `[Tests] mvp4_campaign_spawn: all passed.`

16. **Abilities** (`tests/test_mvp4_abilities.gd`): an ability is
    usable once, then genuinely blocked by its own cooldown (not just
    described as having one); using an ability produces real
    `CombatLog` feedback; Assassinate is proven to cap damage against
    an MC/Special target (survives at >= the documented floor) while
    dealing full, uncapped damage against a regular target (the
    counterplay is conditional on tier, not a universal nerf); Command
    Surge is proven to buff at most `max_targets` allies and to refresh
    rather than stack its multiplier on reuse; Deceptive Assault's
    self-buff is proven to actually expire back to baseline, not
    silently persist; a Tactical-Link-style aura is proven to apply
    only within its radius (a unit placed just outside gets nothing —
    the counterplay is real, not just narrated). Exit 0,
    `[Tests] mvp4_abilities: all passed.`

17. **MC leveling + Special unlock** (`tests/test_mvp4_leveling_and_specials.gd`):
    all 4 upgrade costs match Prompt Dasar's table exactly; capped
    bonuses at level 5 are exact (+20% HP, +8% damage, -15% cooldown,
    checked via `is_equal_approx`, not just "greater than 1"); a
    6th upgrade attempt is refused; Special recruitment is proven
    locked below MC level 4 and unlocked at exactly level 4; recruiting
    the same Special index twice is proven to fail (uniqueness); the
    exact `recruit_price` is proven deducted. Exit 0,
    `[Tests] mvp4_leveling_and_specials: all passed.`

18. **Nabil specifics** (`tests/test_mvp4_nabil_specifics.gd`): a
    downed, surrendered enemy is proven to NOT join Nabil's roster
    (roster count unchanged, faction_side unchanged) when the normal
    MVP2 recruit-completion path is invoked; Armory crafting is proven
    to deduct Parts (not money) and to fail with insufficient Parts;
    a completed craft is proven to land in the shared
    `gun_shop_inventory` pool; City Patrol income is proven to withhold
    entirely before the 15s minimum idle time, to start accruing after
    it, and — the actual "distance efficiency" mechanic, not just its
    existence — an isolated patroller is proven to earn strictly more
    per-unit than one of several patrollers clustered in the same
    sector. Exit 0, `[Tests] mvp4_nabil_specifics: all passed.`

19. **Balance simulation** (`tests/test_mvp4_balance_simulation.gd`,
    the MVP's explicit "diuji melalui simulasi" requirement): many
    real, seeded headless skirmishes between actual `BwUnit` instances
    (real weapon data, real accuracy/suppression/downed resolution).
    Zie's Triad-Synergy-buffed trio is proven to beat 7xB3 in a
    genuinely competitive share of trials (not 0%, not 100%); a lone
    Nabil Special is proven to beat 4xB1 in a genuinely competitive
    share of trials. See docs/BALANCE.md "MVP4 balance simulation
    calibration" for the full calibration story, including a real bug
    this simulation caught (suppression-lock made any 1-vs-2+ fight
    unwinnable regardless of stats, fixed with a disclosed
    `SPECIAL_TIER_SUPPRESSION_RESIST` addition) and why the exact
    enemy-count numbers were tuned away from Prompt Dasar's literal
    "~8 B3" figure. Exit 0,
    `[Tests] mvp4_balance_simulation: all passed.` This suite takes
    noticeably longer to run than the others (many seconds of
    simulated combat per trial across ~30 trials) — run it standalone
    with a generous timeout rather than folding it into a quick smoke
    pass.

## MVP4 manual visual verification

Same Xvfb + Mesa llvmpipe approach as MVP1-3. Confirmed via
screenshots: Zie's HQ correctly labeled "Vartieri Cartel HQ" (not
"(PLACEHOLDER)" — it's the active campaign) with her starting Armored
SUV parked nearby and her real B1 squad; the Recruitment panel showing
all 3 of Zie's Specials correctly locked with "MC level 4 required,
currently 1"; Nabil's Central City showing a "DEA Armory" building (not
a Gun Shop) and the Armory panel listing every craftable weapon's real
Parts cost; Nabil's topbar showing "Roster: 0/24 + MC" and a "Dispatch
Allies" HUD button in place of the other factions' Heat/DEA mechanic.

## Known gaps not covered by MVP4 tests

- No automated test drives the ability bar UI's actual button-press ->
  `CommandController.arm_ability_targeting` -> ground-right-click flow
  for Throw Drug Bottle end-to-end through input events; the
  underlying `try_use_ability`/`_use_ability_aoe` path it calls is
  tested directly.
- No automated test for the "Dispatch Allies" HUD button's own click
  handler; `CampaignEconomy.try_dispatch_allies()` (the budget/cooldown
  logic it calls) is tested directly.
- Triad Synergy's *trigger condition* (all 3 alive within 12m,
  evaluated by `open_world_map.gd::_update_triad_synergy`) is exercised
  live by the balance simulation (which sets the synergy fields
  directly to isolate combat-power testing) but has no dedicated unit
  test proving the 12m radius boundary itself.
