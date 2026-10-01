# BAD WORLD — Release Candidate Validation Report

Per `Prompt AI Bad World GAME -/Part 9.txt` ("Kerjakan MVP 7: Release
Candidate Validation. Jangan menambahkan fitur besar baru. Fokus pada
perbaikan.") plus a dedicated **Release Candidate Fix Pass** that
addressed the issues this report's own MVP7 pass identified. This
report distinguishes exactly what's required: done+verified, done-but-
not-fully-verified, still placeholder, not yet done, known bugs,
technical risks, how to run from source, and how to produce a Windows
build.

## Bottom line

**The game is fixed, exports cleanly, and is verified playable
end-to-end on the equivalent Linux build; the Windows `.exe` builds
cleanly from the identical fixed source but its runtime could not be
executed in this sandbox.** The Release Candidate Fix Pass closed
every concrete issue the original MVP7 report raised, and this
follow-up Final Playable-Build Verification Pass closed the loop on
two remaining items: one more unfixed instance of the `.remap`
resource-loading bug pattern (in dev-only test tooling, never
actually reachable through a real export, but fixed for consistency)
and a cosmetic Windows-export console-noise issue (an `rcedit`/Wine
icon-embedding step that cannot succeed in this sandbox's partial
Wine install — not a project defect, resolved by disabling that one
export option). A complete scripted playthrough against the freshly
rebuilt exported Linux binary — launch → menu → campaign select (4
cards) → difficulty → story → real gameplay (real MC + 3 real rival
MCs + starting vehicle) → a core player action → a real rival MC's
combat death → flee/surrender/rogue firing for real → the player's
own MC death → DEFEAT with a full campaign summary → clean exit —
completed successfully with zero errors, screenshotted at every step.
30/30 automated tests pass. See "Not yet done" and "Known bugs" below
for the handful of items that remain genuinely open (none of which
block launching/playing the game).

---

## Release Candidate Fix Pass: summary

Addressed, in order, the 5 issues raised against this report's own
original MVP7 findings:

1. **Main Character death consequences** (Prompt Dasar base rules:
   "Unit tersisa dapat kabur, menyerah, atau menjadi rogue berdasarkan
   tier") — **implemented**. Reuses existing state machinery end to
   end (surrender = the same `DOWNED` state every combat-downed enemy
   already uses; rogue = a unit's existing `auto_defend` combat
   behavior, just flagged `has_gone_rogue`); flee is a new, small,
   bounded "move away then despawn" behavior. Tier weights derived
   from the existing payroll-desertion precedent (documented
   assumption, not fabricated). Special is fixed at rogue per the
   explicit "Special tidak menyerah" rule, not rolled. New
   `tests/test_rc_mc_death_consequences.gd` (6 subtests) plus 2 new
   subtests in `tests/test_mvp6_victory_defeat.gd` confirming the real
   end-to-end combat-death path (not just a test seam) fires this for
   real. See `docs/TECH_DECISIONS.md` for the full design writeup.
2. **Fauzi (Zie/Vartieri) AI never bought a vehicle** — **root-caused
   and fixed**. Traced the entire purchase pipeline with a standalone
   diagnostic probe; found the cause was AI decision-tick priority
   (recruitment always ran before vehicle-purchase with no reserve for
   it, and Zie's recruitment costs are the highest of the 3 cartels),
   not an affordability/wiring/threshold bug. Fixed by reordering
   `_manage_vehicles()` before `_manage_recruitment()` — a single,
   faction-agnostic change, not a Fauzi-specific hack. Verified: full
   balance report now shows 100% vehicle presence across all 12
   faction/difficulty cells (was 0% for all 3 Fauzi rows). See
   `docs/TECH_DECISIONS.md` and `docs/BALANCE.md`.
3. **Windows `.exe` verification** — inspected the export
   configuration; found it correct, left it unmodified. Re-verified by
   rebuilding both presets after all other fixes landed.
4. **Stale `PLACEHOLDER_building_interaction` register entry** —
   investigated; confirmed genuinely stale (never a real literal
   placeholder marker in any asset/data file; MVP3 already built real
   walk-up `E`-to-interact buildings with no always-visible-button path
   left). Struck through in the Register with its resolution noted,
   per this project's own placeholder policy (never silently delete a
   row).
5. **Make the game actually playable (Windows/export)** — this is
   where the **most important finding of this entire fix pass**
   emerged: actually running the exported build (not just the editor)
   surfaced a critical, serious, pre-existing bug — see "Known bugs"
   #1 below. Found, fixed, and verified end-to-end against the real
   rebuilt exported Linux binary. README gained a "How to Play"
   section (Issue 5.8).

All 30 headless test suites pass (4 new this pass: `test_rc_mc_death_consequences.gd`,
`test_rc_export_remap_resilience.gd`, plus the 2 updated subtests in
`test_mvp6_victory_defeat.gd`). Before this pass: 28/28 passing (per
the original MVP7 report). After: 30/30 passing (confirmed 2 known-
flaky suites — `test_mvp5_diplomacy.gd`, `test_mvp5_arena.gd` —
reproduce their pre-existing intermittent RNG failures on rerun,
unrelated to any change in this pass).

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

- **Release Candidate Fix Pass additions**:
  - **Main Character death consequences** (flee/surrender/rogue),
    fully implemented and reusing existing state machinery — see
    summary above.
  - **Fauzi vehicle-purchase fix**, verified via a 100%-vehicle-
    presence balance report across all 12 cells.
  - **A critical export-only bug fixed**: `CampaignDatabase` and
    `CampaignEconomy`'s directory-scanning loaders never matched the
    `.remap`-suffixed filenames an exported PCK actually lists,
    silently loading **zero** campaigns/factions/difficulties/weapons
    in every real export produced through MVP0-7 — invisible until
    this pass ran an actual export instead of the editor. Fixed at all
    3 affected call sites (`campaign_database.gd`,
    `campaign_economy.gd`, `tools/validate_asset_manifest.gd`).
    Verified by rebuilding the Linux export and running it headful
    under Xvfb: console now correctly prints `loaded 4 faction(s), 4
    campaign(s), 3 difficulty(ies)`, and a full scripted playthrough
    (menu → campaign select → real gameplay → move order → a real
    rival MC's death triggering flee/surrender/rogue for real → the
    player's own MC death triggering DEFEAT with a full campaign
    summary → clean exit) completed successfully end to end, with a
    screenshot captured at every step.

All 30 headless test suites pass (`godot4 --headless --fixed-fps 600
--path . --script res://tests/<name>.gd`, exit 0 each). Asset manifest
validator passes (306 cataloged files verified present).

## 2. Done but not fully verified

- **Windows `.exe` runtime behavior**: the export is structurally
  valid (confirmed via `file`: PE32+ executable, x86-64, correct
  size), built from the exact same fixed source as the verified Linux
  export, but it was never actually *executed* — Wine cannot run any
  Windows binary at all under this sandbox's gVisor kernel (see
  "Technical risks"). The equivalent **Linux** export was built and
  run headful under Xvfb and this time taken all the way through a
  full scripted playthrough (not just the Content Warning screen as
  in the original MVP7 pass) — the closest feasible substitute
  available here, but not a substitute for someone with real Windows
  (or a non-gVisor Linux host + real Wine) actually launching the
  `.exe`. Given the export-remap bug fix applies identically to both
  presets (same source, same `CampaignDatabase`/`CampaignEconomy`
  code), there is good reason to expect the Windows build behaves the
  same way — but this is an expectation, not a verified fact, and
  should not be reported as such.
- **Rival-faction encounters' balance weight**: they are new as of
  the MVP7 pass and use real per-faction stats, but no dedicated
  balance pass was run against them specifically (they are static
  stationary encounters, not part of the `AiMatchArena` win-rate
  sampling) — a player's actual experience fighting through all 3
  should be spot-checked before relying on their difficulty.
- **Ambush-frequency-vs-difficulty direction**: Easy ambushes
  slightly *more* than Hard (2.00 vs 1.67/match) — explained
  qualitatively in `docs/BALANCE.md` (Hard's better decision quality
  picks direct attacks over ambushes more often) but not independently
  confirmed against `FactionStrategicAI`'s actual utility-comparison
  code path line-by-line.
- **MC death consequences' tier-weight numbers**: implemented and
  unit-tested for correctness (right state transitions, right
  exclusivity, Special always rogue), but — like every other numeric
  assumption this project documents when Prompt Dasar gives no exact
  figure — the specific 50/30/20-style percentages themselves are a
  reasonable derived assumption, not a tuned balance pass; a real
  release should sanity-check how often each outcome actually "feels
  right" in practice.

## 3. Still placeholder

Full register + the new safe-for-MVP-vs-must-replace split:
`docs/PLACEHOLDER_REGISTER.md`. Summary: all visual/art placeholders
(unit sprites, selection ring, health bar, HUD panel styling, minimap
rendering, debug overlay styling, rival-encounter visual identity) are
**safe for this MVP** — none of them affect correctness or block any
acceptance criterion. Real functional gaps are called out separately
in section 4 below and in the Register's own "must replace" list.

## 4. Not yet done

- **Nabil's own Factory + Dealer loop** despite Prompt Dasar's "Nabil
  tidak menjual cargo" — pre-existing since MVP3/4, first documented
  in MVP6, not addressed in this fix pass either (out of its stated
  scope — fixing the 5 named issues, not an open-ended sweep; see
  `docs/PLACEHOLDER_REGISTER.md` "must replace" list for the
  reasoning).
- **Rival-faction AI is stationary, not mobile** in the live open
  world (by design, matching the existing "fixed hostile encounter"
  pattern — the mobile AI itself is fully built and already proven in
  `AiMatchArena`, "wiring it into the live scene with real roaming
  behavior" is the remaining gap, not the AI logic itself).
- **Root-causing the Easy>Hard ambush-frequency direction precisely**
  (see section 2) — explained qualitatively, not traced line-by-line.

## 5. Known bugs

### Fixed during the Release Candidate Fix Pass
1. **`CampaignDatabase`/`CampaignEconomy` never loaded any data in an
   actual export** — the most serious bug found in this project to
   date. An exported PCK's `DirAccess` lists resource files with an
   extra `.remap` suffix that these loaders' literal
   `ends_with(".tres")` checks never matched, so every campaign/
   faction/difficulty/weapon resource silently failed to load in
   *every* real export produced through MVP0-7 — completely invisible
   because every prior verification ran via `godot4 --headless --path
   .` (editor/script mode, which reads the real filesystem directly
   with no remap layer). Fixed at all 3 affected call sites. Verified
   against the real rebuilt exported Linux binary end-to-end (see
   summary above). New regression test:
   `tests/test_rc_export_remap_resilience.gd`. See
   `docs/TECH_DECISIONS.md` for the full technical writeup.
2. **Fauzi (Zie/Vartieri) AI never bought a vehicle** — root cause was
   AI decision-tick priority (recruitment competing unfairly with a
   one-time vehicle purchase, worsened by her having the highest
   recruitment costs of the 3 cartels), not an affordability/wiring
   bug. Fixed by reordering two function calls in
   `faction_strategic_ai.gd`. Verified: 100% vehicle presence across
   all 12 balance-report cells (was 0% for all 3 Fauzi rows).

### Fixed during the original MVP7 pass
3. **`BwUnit.died` signal double-argument bug** (found during MVP6,
   fixed then) — included here for completeness since it directly
   affected whether this pass's new victory/defeat tests could even
   observe correct state.
4. **Nabil's VICTORY factory check looked at the player's own
   factory instead of the rival cartels'** — fixed; see
   `docs/TECH_DECISIONS.md`.
5. **Safe-zone exploit**: a unit standing inside a safe zone could
   fire/execute/recruit/throw-grenades outward with zero counterplay
   — fixed at all 4 call sites; see `docs/TECH_DECISIONS.md`.
6. **Balance-report income metric initially reported as negative**
   for every faction (used net cash-flow delta instead of gross
   earned) — fixed before the final captured report.

### Still open (not fixed, not blocking, but real)
7. Nabil's own Factory/Dealer loop despite "tidak menjual cargo" (see
   "Not yet done" above).
8. The precise code-path confirmation for the Easy>Hard ambush-
   frequency direction (see section 2) — explained, not traced.

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
3. **This fix pass is a direct, concrete lesson in why "tests pass" ≠
   "it works"**: all 28 MVP7 suites passed throughout MVP0-7 while the
   actual exported game was completely non-functional the entire time
   (see Known bugs #1) — every one of those tests ran in editor/
   script mode, which structurally cannot observe the PCK `.remap`
   layer that caused the real bug. This is not a flaw in those tests'
   own logic, but a reminder that **headless `--script` tests verify
   game logic correctness, not export/packaging correctness** — only
   actually building and running an export (as this pass finally did)
   can catch this entire bug class. Any future change to resource
   organization/loading should be spot-checked against a real export
   periodically, not assumed safe because the test suite is green.
4. **4 known-flaky test suites** (`test_mvp5_tactical_ai.gd`,
   `test_mvp5_diplomacy.gd`, `test_mvp5_arena.gd`,
   `test_mvp3_vehicle.gd`) occasionally fail on unseeded RNG/timing
   variance and pass on rerun — confirmed pre-existing (reproduced on
   each file completely unmodified by this pass, both before and after
   the fixes in this pass landed). Low risk
   individually, but an unseeded-RNG test suite is itself a standing
   source of false-negative CI noise if this project ever adds
   continuous integration.
5. **No CI configured** for this repository — every verification in
   this report was run manually, once, in this sandbox session. A
   real release process should wire these same test commands into an
   actual CI pipeline before relying on "all tests passed" as an
   ongoing guarantee rather than a point-in-time snapshot — and, per
   risk #3 above, that CI pipeline should include an actual export+run
   smoke test, not just `--script`-mode unit tests.
6. **Export template / Wine footprint**: Godot's 4.3-stable export
   templates (~1GB) and Wine (~1.5GB installed via apt) were installed
   into this sandbox session to produce and attempt to run the builds
   this report describes; neither is committed to the repository (by
   design — see `.gitignore`), so reproducing this report's Windows/
   Linux build steps elsewhere requires repeating that setup (see
   section 8 below).

## Final Playable-Build Verification Pass

A follow-up request asked for one more confirmation pass: that the
current state (MVP0-7 + the RC Fix Pass) is actually ready for a
developer to clone/download and play on Windows, with an explicit
instruction to search the whole repository once more for any other
instance of the `.remap` resource-loading pattern before declaring
completion. Two findings, both resolved:

1. **One more unfixed `.remap`-vulnerable instance**: a repository-
   wide search found `tests/test_campaign_data.gd`'s own directory-
   scanning helpers still used the unfixed `ends_with(".tres")`
   pattern — the 4th and last instance of this bug class in the repo
   (the other 3 were already fixed in the RC Fix Pass). This instance
   was never actually reachable through the real bug (dev-only test
   tooling, always invoked directly against the real filesystem, never
   auto-run inside a shipped export's own boot path) but was fixed for
   consistency — every directory-scanning resource loader in the
   repository now handles both forms identically. See
   `docs/TECH_DECISIONS.md` "Final Playable-Build Verification Pass".
2. **Cosmetic Windows-export console noise**: re-exporting surfaced a
   new `rcedit`/Wine warning (wine32 missing) followed by the same
   Wine/gVisor crash traces already reported for runtime execution.
   Root cause: `wine64` was installed in this sandbox session (for the
   earlier Windows-runtime-execution attempt) between the RC Fix
   Pass's export and this one, and Godot's export pipeline
   automatically tries to use Wine-hosted `rcedit` to embed the
   `.exe`'s Windows file-icon/version metadata whenever Wine is
   present. **Not a project defect** — confirmed the export still
   completed successfully every time with a correctly-typed,
   consistently-sized output regardless; `modify_resources` only
   affects `.exe` file-icon/version cosmetics, never game resources or
   behavior. Fixed by setting `application/modify_resources=false` in
   `export_presets.cfg`, producing a completely clean, zero-warning
   export. See `docs/TECH_DECISIONS.md` for the full writeup.

**Final end-to-end verification**, against freshly rebuilt Windows and
Linux exports (both zero-error, zero-warning):

- Windows: `file builds/windows/BadWorld.exe` → `PE32+ executable
  (GUI) x86-64 ... for MS Windows` — **BUILT, RUNTIME UNVERIFIED**
  (Wine/gVisor incompatibility persists in this sandbox; not a project
  defect — see "Technical risks").
- Linux: **BUILT, RUNTIME VERIFIED** — a complete scripted playthrough
  against the actual exported binary (not the editor) confirmed every
  stage of the vertical slice in sequence: Content Warning → Main Menu
  → Campaign Select (4 cards rendered) → Difficulty Select → Story
  Panel → real gameplay (real Main Character "Juan Bellarosa", 3 real
  rival Main Characters registered, the starting vehicle present) → a
  core player action (move order, unit state confirmed `MOVING`) → a
  real rival Main Character's combat death → flee/surrender/rogue
  firing for real on its guards → the player's own Main Character's
  death → a DEFEAT screen with a complete campaign summary (play time,
  money, roster, enemies eliminated) and working Restart/Load/Quit
  buttons → clean process exit (code 0). Screenshotted at every step.

Full regression re-run after both fixes: **30/30 passing** (1
known-flaky suite, `test_mvp5_arena.gd`, failed once on its usual
unseeded-RNG variance and passed on 3 immediate reruns with zero file
changes — confirmed pre-existing, not a regression). Balance report
re-run: Campaign Fauzi vehicle presence remains 100% across all 3
difficulties, confirming the earlier fix is stable.

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

# Run the full automated test suite (30 suites):
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
   **This step matters more than it looks**: this exact verification
   step is what caught the critical `.remap` resource-loading bug (see
   "Known bugs" #1) — a build that exports "successfully" with zero
   errors can still be completely non-functional at runtime if the
   wrong resources load. Watch the console output for
   `[CampaignDatabase] loaded 4 faction(s), 4 campaign(s), 3
   difficulty(ies).` specifically — `loaded 0 ...` means something is
   silently broken even though the export itself "succeeded."
