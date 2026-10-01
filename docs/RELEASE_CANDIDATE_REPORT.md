# BAD WORLD — MVP7 Release Candidate Validation Report

Per `Prompt AI Bad World GAME -/Part 9.txt` ("Kerjakan MVP 7: Release
Candidate Validation. Jangan menambahkan fitur besar baru. Fokus pada
perbaikan."). This report distinguishes exactly what Prompt Dasar's
MVP7 acceptance criteria ask for: done+verified, done-but-not-fully-
verified, still placeholder, not yet done, known bugs, technical
risks, how to run from source, and how to produce a Windows build.

## Bottom line

**This build is not production-ready.** The project is a complete,
internally consistent single-player vertical slice covering MVP0-7's
scope, with 28 passing automated test suites and two real
pre-existing bugs found and fixed during this validation pass — but
at least one critical gameplay rule from Prompt Dasar's base rules
("Unit tersisa dapat kabur, menyerah, atau menjadi rogue") is not
implemented at all, the Windows export could not be executed in this
sandbox (platform limitation, not a build defect — see "Technical
risks"), and several balance/behavior observations need follow-up
investigation before any numbers should be retuned. See "Not yet
done" and "Known bugs" below for the specific list of what would need
to close before a real release.

---

## 1. Done and verified

Verified means: a passing automated test exercises the behavior
directly, or (for UI/visual items) a Xvfb screenshot was captured and
reviewed this session or in an earlier MVP's own test pass.

- **Core RTS loop** (MVP1/2): selection, formation movement,
  attack-move, cover/suppression, downed/revive/execute, weapon-data-
  driven combat (accuracy, rate of fire, reload, ammo). 8 suites.
- **Open-world economy loop** (MVP3): Factory → cargo → Drug Dealer →
  carried cash → Bank deposit, Heat Meter + DEA response waves,
  Garage + vehicles (enter/exit, moving-turret accuracy penalty),
  save/load. 4 suites.
- **Four asymmetric campaigns** (MVP4): all playable from the menu,
  correct starting resources/roster caps/faction bonuses per Prompt
  Dasar, Main Character leveling (1-5) + Special unit unlock/recruit,
  abilities. 4 suites, plus a seeded balance simulation showing the
  documented suppression-resistance fix holding under repeat trials.
- **Layered AI + diplomacy** (MVP5): TACTICAL (target priority,
  flanking, proactive retreat, revive, protect-MC, grenade avoidance),
  STRATEGIC (recruitment, resupply, factory upgrades, dealer/bank
  runs, vehicles, scouting, utility-gated raids), real fog-of-war
  (`FactionKnowledge`), ambush (arm/commit/cancel), neutral-encounter
  diplomacy (trust/alliance/trade/betrayal, no shared-victory
  concept). 6 suites + a 4-match headless arena harness.
- **Campaign presentation and UX** (MVP6): content warning, full
  campaign-selection cards, a 10-hint one-time contextual tutorial,
  payroll/low-ammo/demand/patrol/diplomacy/camera-alert HUD panels,
  real volume controls + full key rebinding, autosave + 3 manual save
  slots + schema migration, DEFEAT with campaign summary. 4 suites.
- **MVP7 fixes, all covered by new/updated tests**:
  - **VICTORY is now genuinely reachable by playing**, not just a
    test-only seam: real rival-faction Main Characters (with that
    faction's own combat stats) spawn in the open world and are
    registered with the victory check; killing all 3 ends the
    campaign in VICTORY; for Campaign Nabil, the additional "no active
    cartel factory" condition is checked against real, destructible
    rival factories. `tests/test_mvp6_victory_defeat.gd` (updated),
    verified by killing real spawned rival MCs via normal `BwUnit._die()`,
    no test-only shortcuts.
  - **Safe-zone exploit fixed**: a unit standing inside a safe zone can
    no longer fire, execute, recruit/capture, or throw a grenade out —
    only the target's own safe-zone status was ever checked before.
    `tests/test_mvp7_release_validation.gd`.
  - **Out-of-ammo behavior**: a unit that empties its magazine with
    zero reserve stops dealing damage and does not loop-reload forever.
    `tests/test_mvp7_release_validation.gd`.
  - **Orphan-node stability**: 50 spawn-then-death cycles leave the
    tree exactly where it started. `tests/test_mvp7_release_validation.gd`.
  - **Windows export preset** committed (`export_presets.cfg`); a
    Windows build was produced successfully (valid PE32+ x86-64
    executable with embedded `.pck`).
  - **60 FPS target under near-cap, all-factions-active combat**:
    measured 16.56-16.60ms average frame time (60.2-60.4 FPS budget)
    with 40 units across 4 factions + 4 vehicles in live combat, 0
    orphan nodes after. See `docs/BALANCE.md` "MVP7 performance
    report".
  - **Balance report** with every metric Prompt Dasar's MVP7 section
    asks for (match duration, win rate, income/min, army size, special
    unit and vehicle effectiveness, DEA/ambush frequency, MC survival
    rate, Easy/Medium/Hard differences). See `docs/BALANCE.md` "MVP7
    release candidate balance report".

All 28 headless test suites pass (`godot4 --headless --fixed-fps 600
--path . --script res://tests/<name>.gd`, exit 0 each). Asset manifest
validator passes (306 cataloged files verified present).

## 2. Done but not fully verified

- **Windows `.exe` runtime behavior**: the export is structurally
  valid (confirmed via `file`: PE32+ executable, x86-64, correct
  size), but it was never actually *executed* — Wine cannot run any
  Windows binary at all under this sandbox's gVisor kernel (see
  "Technical risks"). The equivalent **Linux** export was built and
  run headful under Xvfb, screenshot-confirmed rendering real gameplay
  UI (the Content Warning screen) — the closest feasible substitute
  available here, but not a substitute for someone with real Windows
  (or a non-gVisor Linux host + real Wine) actually launching the
  `.exe`.
- **Rival-faction encounters' balance weight**: they are new as of
  this MVP7 pass and use real per-faction stats, but no dedicated
  balance pass was run against them specifically (they are static
  stationary encounters, not part of the `AiMatchArena` win-rate
  sampling) — a player's actual experience fighting through all 3
  should be spot-checked before relying on their difficulty.
- **Vehicle purchase gap for Campaign Fauzi (Zie/Vartieri)**: the
  balance report shows 0% vehicle-presence across all 9 trials for
  this campaign specifically (100% for the other 3). Observed and
  reported honestly in `docs/BALANCE.md`, but the root cause was not
  investigated in this pass (out of MVP7's "don't add new features,
  focus on fixes" scope to chase without first confirming it's a real
  defect vs. a legitimate economic consequence of Zie's -5% factory
  value modifier making a vehicle purchase a lower-utility choice for
  that AI specifically).
- **Ambush-frequency-vs-difficulty direction**: Easy ambushes
  slightly *more* than Hard (2.00 vs 1.67/match) — explained
  qualitatively in `docs/BALANCE.md` (Hard's better decision quality
  picks direct attacks over ambushes more often) but not independently
  confirmed against `FactionStrategicAI`'s actual utility-comparison
  code path line-by-line.

## 3. Still placeholder

Full register + the new safe-for-MVP-vs-must-replace split:
`docs/PLACEHOLDER_REGISTER.md`. Summary: all visual/art placeholders
(unit sprites, selection ring, health bar, HUD panel styling, minimap
rendering, debug overlay styling, rival-encounter visual identity) are
**safe for this MVP** — none of them affect correctness or block any
acceptance criterion. Real functional gaps are called out separately
in section 4 below and in the Register's own "must replace" list.

## 4. Not yet done

- **Rogue/surrender/flee on enemy MC death** (Prompt Dasar base
  rules: *"Jika Main Character musuh mati: ... Unit tersisa dapat
  kabur, menyerah, atau menjadi rogue berdasarkan tier"*). This is a
  genuine missing feature — when any MC (player's or a rival's) dies
  today, that side's surviving regular units simply continue to exist
  in whatever state they were in; there is no automatic flee/
  surrender/rogue-faction transition anywhere in the codebase.
  Deliberately **not implemented in this MVP7 pass** (would be a new
  per-unit behavior system, squarely the kind of "fitur besar baru"
  Prompt Dasar's own MVP7 instructions say to avoid) — flagged here
  instead, for a future MVP.
- **Nabil's own Factory + Dealer loop** despite Prompt Dasar's "Nabil
  tidak menjual cargo" — pre-existing since MVP3/4, first documented
  in MVP6, not addressed in this pass (see
  `docs/PLACEHOLDER_REGISTER.md` "must replace" list for the
  reasoning).
- **Rival-faction AI is stationary, not mobile** in the live open
  world (by design, matching the existing "fixed hostile encounter"
  pattern — the mobile AI itself is fully built and already proven in
  `AiMatchArena`, "wiring it into the live scene with real roaming
  behavior" is the remaining gap, not the AI logic itself).
- **`PLACEHOLDER_building_interaction` register row appears stale**
  (describes a pre-MVP3 state) but was not re-verified/removed this
  pass — flagged rather than silently left inconsistent.

## 5. Known bugs

### Fixed during this MVP7 pass
1. **`BwUnit.died` signal double-argument bug** (found during MVP6,
   fixed then) — included here for completeness since it directly
   affected whether this pass's new victory/defeat tests could even
   observe correct state.
2. **Nabil's VICTORY factory check looked at the player's own
   factory instead of the rival cartels'** — fixed; see
   `docs/TECH_DECISIONS.md`.
3. **Safe-zone exploit**: a unit standing inside a safe zone could
   fire/execute/recruit/throw-grenades outward with zero counterplay
   — fixed at all 4 call sites; see `docs/TECH_DECISIONS.md`.
4. **Balance-report income metric initially reported as negative**
   for every faction (used net cash-flow delta instead of gross
   earned) — fixed before the final captured report.

### Still open (not fixed, not blocking, but real)
5. See "Not yet done" above (rogue/surrender/flee; Nabil's own
   Factory/Dealer loop).
6. The Campaign Fauzi vehicle-purchase gap (see section 2) — open,
   needs root-causing.
7. `PLACEHOLDER_building_interaction`'s Register row is likely stale
   (see section 4) — open, needs a quick re-verify+removal pass.

## 6. Technical risks

1. **Wine cannot execute any Windows binary in this sandbox** (gVisor
   kernel incompatibility with Wine's own exception-handling
   bootstrap — confirmed with a minimal `wine cmd.exe` test, not
   specific to this project's build). Reported as a platform issue.
   Risk: the Windows export's *runtime* correctness is unverified in
   this environment; it should be smoke-tested on real Windows (or a
   non-gVisor host) before being handed to a player.
2. **Performance measured on a shared/virtualized sandbox CPU**, not a
   dedicated gaming workstation. The 60 FPS average result (with P95/
   worst-case frames occasionally exceeding budget) is a reasonable
   release-candidate signal but should be re-confirmed on representative
   target hardware, especially given gVisor's own syscall-emulation
   overhead could itself be adding latency not present on a real
   Windows/Linux desktop.
3. **4 known-flaky test suites** (`test_mvp5_tactical_ai.gd`,
   `test_mvp5_diplomacy.gd`, `test_mvp5_arena.gd`,
   `test_mvp3_vehicle.gd`) occasionally fail on unseeded RNG/timing
   variance and pass on rerun — confirmed pre-existing (reproduced on
   each file completely unmodified by this pass). Low risk
   individually, but an unseeded-RNG test suite is itself a standing
   source of false-negative CI noise if this project ever adds
   continuous integration.
4. **No CI configured** for this repository — every verification in
   this report was run manually, once, in this sandbox session. A
   real release process should wire these same test commands into an
   actual CI pipeline before relying on "all tests passed" as an
   ongoing guarantee rather than a point-in-time snapshot.
5. **Export template / Wine footprint**: Godot's 4.3-stable export
   templates (~1GB) and Wine (~1.5GB installed via apt) were installed
   into this sandbox session to produce and attempt to run the builds
   this report describes; neither is committed to the repository (by
   design — see `.gitignore`), so reproducing this report's Windows/
   Linux build steps elsewhere requires repeating that setup (see
   section 8 below).

## 7. How to run from source

Requires Godot **4.3 stable** (`4.3.stable.official.77dcf97d8`), the
exact version this project is built/tested against — do not substitute
a different 4.x minor version without re-running the full test suite
first, since GDScript/engine behavior has changed between minors in
ways this project's tests have already caught once (see
`docs/TECH_DECISIONS.md`'s various Godot-quirk notes).

```bash
# Editor (interactive):
godot4 --editor --path .

# Play directly, non-interactive (same binary, no --editor flag):
godot4 --path .

# Run the full automated test suite (28 suites):
for f in tests/*.gd; do
  godot4 --headless --fixed-fps 600 --path . --script "res://$f"
done

# Asset manifest validation:
godot4 --headless --path . --script res://tools/validate_asset_manifest.gd

# AI win-rate report (MVP5) / full MVP7 balance report:
godot4 --headless --fixed-fps 600 --path . --script res://tools/run_ai_winrate_report.gd
godot4 --headless --fixed-fps 600 --path . --script res://tools/run_balance_report.gd

# Performance profiling (do NOT use --fixed-fps for these — it
# defeats the purpose of a wall-clock FPS measurement):
godot4 --headless --path . --script res://tools/profile_navigation_and_vehicles.gd
godot4 --headless --path . --script res://tools/profile_near_cap_multi_faction.gd
```

`HOME` must point at a writable directory (for Godot's own editor
cache/settings and this project's `user://` saves/prefs) — e.g.
`export HOME=/some/writable/dir` before any of the above if the
default `$HOME` isn't writable in your environment.

## 8. How to make a Windows build

1. Install Godot 4.3 stable's **export templates** (not just the
   editor/runtime binary) for the exact same version:
   ```bash
   curl -sL -o templates.tpz \
     "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
   unzip -q templates.tpz -d /tmp/godot_templates
   mkdir -p "$HOME/.local/share/godot/export_templates/4.3.stable"
   cp -r /tmp/godot_templates/templates/* \
     "$HOME/.local/share/godot/export_templates/4.3.stable/"
   ```
2. This repository's `export_presets.cfg` (committed, overriding
   Godot's default `.gitignore` template for exactly this file — see
   `.gitignore`'s own comment) already defines a **"Windows Desktop"**
   preset (x86-64, console wrapper enabled, product name "Bad World")
   and a **"Linux Verification Build"** preset used for this report's
   own run-the-exported-build step.
3. Export:
   ```bash
   godot4 --headless --path . --export-release "Windows Desktop" \
     builds/windows/BadWorld.exe
   ```
   Output is a single self-contained `.exe` with the `.pck` embedded
   (`binary_format/embed_pck=true`); `builds/` itself is gitignored
   (hundreds of MB, never committed — regenerate it from source with
   the command above whenever a build is needed).
4. **Verify the build actually runs** (Prompt Dasar: "Jalankan build
   hasil export, bukan hanya editor"), ideally on real Windows. If
   only Linux is available, confirm structural validity at minimum
   (`file builds/windows/BadWorld.exe` should report "PE32+ executable
   (GUI) x86-64 ... for MS Windows") and prefer testing under a real
   (non-gVisor) Wine installation, or build+run the "Linux
   Verification Build" preset instead as the closest available
   same-engine substitute:
   ```bash
   godot4 --headless --path . --export-release "Linux Verification Build" \
     builds/linux/BadWorld.x86_64
   chmod +x builds/linux/BadWorld.x86_64
   ./builds/linux/BadWorld.x86_64
   ```
