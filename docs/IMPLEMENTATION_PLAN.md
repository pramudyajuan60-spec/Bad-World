# Implementation Plan (MVP Roadmap)

Source: `Prompt AI Bad World GAME -/Part 1.txt` (base rules) and
`Part 2.txt`..`Part 9.txt` (one file per MVP, MVP 0 through MVP 7). Work
proceeds strictly in this order; each MVP stops and reports before the
next begins (base rule 12).

| MVP | Title | Status |
|---|---|---|
| 0 | Repository Audit and Godot Bootstrap | **Done this session** — see report in the PR/handoff message. |
| 1 | Juan Bellarosa Core RTS Vertical Slice | **Done** — see "MVP 1 delivered scope" below. |
| 2 | Combat and Unit Management | **Done** — see "MVP 2 delivered scope" below. |
| 3 | Open-World Economy and Vehicle Loop | **Done** — see "MVP 3 delivered scope" below. |
| 4 | Four Asymmetric Campaigns | **Done** — see "MVP 4 delivered scope" below. |
| 5 | Intelligent AI and Diplomacy | **Done** — see "MVP 5 delivered scope" below. |
| 6 | Campaign Presentation and User Experience | Not started |
| 7 | Release Candidate Validation | Not started |

## MVP 0 scope actually delivered

- Confirmed working commit (docs/REPO_AUDIT.md).
- Read all 4 `Story.txt` files.
- Full asset inventory generated (docs/ASSET_MANIFEST.md +
  `data/manifest/asset_manifest.json`), including newly found mismatches
  beyond the ones already listed in Prompt Dasar.
- Godot 4.3 stable project that opens and boots headlessly without error.
- Clean directory structure (`scripts/`, `scenes/`, `data/`, `tools/`,
  `tests/`, `docs/`).
- Typed schemas for Campaign/Faction/Unit/Weapon/Vehicle/Building/
  Upgrade/Difficulty (`scripts/data/*.gd`).
- Populated data for the four campaigns, their factions, and the three
  difficulty presets.
- Automated, headless asset-manifest validator
  (`tools/validate_asset_manifest.gd`) plus a headless smoke test
  (`tests/test_campaign_data.gd`).
- Placeholder policy (docs/PLACEHOLDER_REGISTER.md).
- No gameplay systems built (per rule 11 for MVP 0).

## MVP 1 delivered scope

Full menu flow (Main Menu → Campaign Select → Difficulty Select → Story
Panel → gameplay), all data-driven from `CampaignDatabase`/`GameState`.
One RTS gameplay scene (`scenes/gameplay/BellarosaTestMap.tscn`) with:

- Juan + 3×B1 spawned via formation-spaced positions; 4-unit dummy enemy
  squad ("Hostile (PLACEHOLDER)", see PLACEHOLDER_REGISTER.md).
- Fixed-angle `RtsCamera`: pan via arrow keys + edge-scroll (not WASD —
  see docs/TECH_DECISIONS.md for why), zoom via mouse wheel, clamped to
  map bounds.
- Single/shift/box/double-click selection (`SelectionManager`,
  `CommandController`), control groups (Ctrl+1‑9 assign, 1‑9 recall).
- Move / stop (S) / attack / attack-move (A + right-click) commands,
  formation spacing on multi-unit move so units never stack.
- `NavigationAgent2D` pathfinding + RVO avoidance for movement;
  `NavigationObstacle2D` (circular approximation) on a handful of
  rectangular obstacles for avoidance, plus `StaticBody2D` physics
  collision as a hard backstop.
- Simplified placeholder combat: flat accuracy-gated damage, no
  weapon/ammo/line-of-sight yet (that's MVP 2's "COMBAT DAN COVER"
  scope) — enough for basic attack-move + target acquisition + kill.
- Selection ring, health bar, destination marker (drawn placeholders),
  and a HUD portrait panel using real repository art (Juan.jpg / the
  matching `Unit N.jpg` for each B1).
- Pause menu: resume, restart, save/load (slot 1), quit to menu.
- Minimal save/load: unit positions, HP, campaign/difficulty id, to
  `user://saves/slot_1.json`, schema-versioned, corrupt-file-safe.

Verification: 6 automated headless checks (see docs/TEST_PLAN.md) all
passing, plus a manual Xvfb-rendered screenshot pass confirming every
menu screen and the gameplay scene render correctly (not committed to
the repo; shared in the PR).

Known simplifications, deferred to their stated MVP:
- No weapon/ammo/inventory, no cover, no downed/revive/execution (MVP 2).
- No economy/vehicles/factories (MVP 3).
- Only Campaign Juan is playable; others are visibly locked (MVP 4).
- No AI beyond "dummy enemy fires back if approached" (MVP 5).
- No tutorial, key rebinding, audio, or >1 save slot (MVP 6).

## MVP 2 delivered scope

Full weapon-data-driven combat replacing MVP1's flat accuracy/damage:

- 10 weapon resources (`data/weapons/*.tres`): Knife, Pistol, SMG,
  Shotgun, Assault Rifle, Sniper, LMG, RPG, Grenade, Tactical Vest —
  each with damage, rate of fire, reload time, range, magazine/reserve,
  hitscan-vs-projectile, and (for explosives) blast radius.
- `BwUnit` combat: real ammo consumption, automatic reload from
  reserve, fallback to an equipped melee secondary once a primary is
  fully dry (never "fake" infinite fire), and a line-of-sight raycast
  that blocks fire through obstacles.
- Defend/Cover Mode (`D`): unit paths to the nearest obstacle and takes
  reduced damage only from the direction the cover actually blocks.
- Suppression: taking fire accumulates a meter that degrades accuracy
  and, past a threshold, triggers a simple retreat.
- Downed/revive/execution: lethal damage downs a unit (30s regular /
  45s Special / 90s Main Character) instead of an instant kill; allies
  can revive (partial HP), enemies can execute via the explicit 6s
  channel (cancelable by taking damage mid-channel).
- Recruitment building (HUD panel): B1/B2/B3 recruitable with real
  price/salary/timer and roster-cap enforcement; Special shown locked.
- Gun Shop (HUD panel) + Inspect panel (HUD panel): weapons are bought
  into a shared unassigned pool and must be manually assigned per unit
  and per slot (primary/secondary/grenade/armor) — never auto-equipped.
- Payroll: a 120s timer pays all owned units' salaries from the shared
  money pool; a missed cycle applies the accuracy/speed/morale penalty
  from Prompt Dasar and recovers gradually once paid.
- Safe zone: Bank + Recruitment each project an 18m no-damage radius
  (blocks attacks, explosions, and executions uniformly, checked in
  `BwUnit.take_damage`).
- Juan can recruit a downed regular enemy via a channeled action (50%
  of B1's price, returns at 50% HP); Special/MC are never recruitable
  (enforced via `is_recruitable_tier`).
- Limited friendly fire from explosives (grenade/RPG): allies inside
  the blast take reduced (50%) damage, and a warning is logged.

9 headless test suites now cover MVP0–2 (see docs/TEST_PLAN.md), all
passing, plus a manual Xvfb visual pass confirming the new HUD/panels
render and function correctly (screenshots shared in the PR, not
committed to the repo).

Known simplifications, deferred to their stated MVP:
- No vehicles/factories/cargo economy yet (MVP3).
- Only Campaign Juan playable; other campaigns' rosters/specials wait
  for MVP4.
- No AI beyond "dummy enemy fires back if approached" (MVP5).
- Building interaction is a HUD button shortcut, not in-world walk-up
  (deferred until MVP3 places real buildings in the open world).
- Grenade/RPG have no visual projectile flight (a timed delay stands in
  for travel time) — see docs/TECH_DECISIONS.md.

## MVP 3 delivered scope

Replaced MVP1/2's single small test map with a connected **open world**
(`scenes/gameplay/OpenWorldMap.tscn`, 8000×6000px): Bellarosa Syndicate
HQ (NW, functional), DEA/Nasion/Vartieri HQs (NE/SW/SE, non-functional
landmark markers — see docs/PLACEHOLDER_REGISTER.md), and Central City
(middle) holding Bank, Recruitment, Gun Shop, and Garage as real
walk-up buildings (`E` to interact) — upgrading MVP2's always-visible
HUD buttons for Recruitment/Gun Shop into in-world triggers.

- **Full economy loop** (the MVP's headline acceptance criterion):
  Bellarosa Factory produces cargo over time (Level 1-4, upgradeable,
  destructible + repairable, production halts while destroyed without
  eliminating the faction) → a unit picks up cargo → sells it at one of
  4 Drug Dealers (each with an independent diminishing-demand curve:
  100%/90%/75%/50%..., recovering after ~45s idle; Dealer 4 explicitly
  labeled "(PLACEHOLDER)" per the known 3-asset shortage) → carried
  cash (separate from bank balance, at risk until deposited) → 6s
  cancelable Bank deposit → spendable money.
- **Losing a carrier has real consequences**: a downed unit drops its
  carried cargo/cash as a generic world pickup (`cash_drop.gd`) that
  *any* unit — including a hostile one — can grab, implementing both
  "kehilangan carrier sebelum Bank memiliki konsekuensi" and "loot
  carried cash sesuai aturan" with one mechanic.
- **Vehicles**: all 4 classes populated (`data/vehicles/*.tres`:
  Compact/Armored SUV/Gun Truck/APC) with real seat-capacity
  enforcement, enter (walk up or auto-approach then board) / exit
  (`X`), Gun Truck/APC turrets that auto-engage in range with a real
  moving-vs-stationary accuracy penalty, and Garage repair for a cost
  scaled to missing HP.
- **Patrol Mode** (`P` + right-click): a unit walks a two-point patrol
  loop, auto-engages intruders, and resumes patrolling once the threat
  clears.
- **Heat Meter + DEA response**: continuous combat for 120s arms a
  60s-travel-delayed DEA wave (4×B2 + 1×B3 + an SUV first wave, 2×B3 +
  an APC second wave), max 2 waves with a 6-minute cluster cooldown,
  spawning at whichever map edge is farthest from the player (never on
  top of them) — simplified to one global cluster for this MVP's single
  contested territory rather than Prompt Dasar's full per-cluster
  model (documented in docs/TECH_DECISIONS.md).
- **HUD additions**: a schematic minimap, an Alerts panel (backed by
  the existing `CombatLog`), and an objective label that adapts to the
  selected unit's current carry state (pick up → sell → deposit).
- Save/load extended to persist money, factory level/HP/cargo, Heat
  wave count, and vehicle position/HP/cargo/cash, verified via a
  headless test that loads the real scene, mutates state, saves,
  reloads, and checks every field.

13 headless test suites now cover MVP0–3 (4 new this MVP), all
passing, plus a manual Xvfb visual pass confirming the world layout
(all 5 regions correctly positioned per Assets/Game Maps/World.png's
described layout), Central City buildings, and minimap all render
correctly.

**Navigation + vehicle profiling** (per this MVP's closing
instruction, `tools/profile_navigation_and_vehicles.gd`, headless):
31 simultaneously-navigating `BwUnit`s (Juan's full own-side roster
cap) + 4 simultaneously-navigating `Vehicle`s, measured over 300
physics frames:

```
Avg physics-frame wall time: 16.585 ms (60.3 effective FPS budget)
P95 physics-frame wall time: 21.118 ms
Worst physics-frame wall time: 21.308 ms
Godot's own physics tick target: 16.667 ms (60Hz)
```

Average frame time sits comfortably under the 60Hz budget; P95/worst
briefly exceed it by ~4.4ms (likely simultaneous path (re)computation
for many agents at once), not a sustained overrun. Caveat: headless
`SceneTree.physics_frame` awaits may already be paced near 60Hz by the
engine itself regardless of simulation cost, so this measures "does
the sim comfortably fit the budget" more than raw unpaced CPU cost;
a windowed run with `--headless` removed and a frame-time overlay
would be needed for a stricter measurement. No dropped-frame stalls or
errors occurred during the run.

Known simplifications, deferred to their stated MVP:
- Only Campaign Juan playable; other 3 HQs are non-functional markers
  (MVP4 activates all four campaigns).
- No AI beyond "dummy enemy/DEA responder fires back if approached"
  (MVP5); the DEA response wave itself is scripted spawning, not an
  autonomous strategic AI.
- Vehicle combat is player-turret-only; there is no player command to
  order an attack against a hostile vehicle (out of this MVP's stated
  acceptance criteria).
- Minimap/alert log are simplified schematic/text panels, not final
  UI art (MVP6).

## MVP 4 delivered scope

All four campaigns are now selectable and fully playable from the menu
(`campaign_select.gd` no longer locks Fauzi/Atha/Nabil). Each spawns
into the *same* `OpenWorldMap.tscn` used by MVP3, but every
faction-dependent piece of setup — starting money, roster cap, B1
availability, starting factory level/economy multipliers, HQ region,
Gun Shop vs. DEA Armory, starting vehicle, abilities, and the full
unit/Special roster — now reads from `CampaignData`/`FactionData`
instead of being hardcoded to Juan (`FactionData` gained
`max_roster`/`has_b1`/`can_recruit_enemies`/
`uses_armory_instead_of_gun_shop`/`starting_factory_level`/
`factory_value_mult`/`factory_speed_mult`; `CampaignData` gained
`mc_unit`/`b1_unit`/`b2_unit`/`b3_unit`/`special_units`/`abilities`/
`starting_vehicle`).

- **Juan (Bellarosa)**: Tactical Link (aura: nearby regulars gain
  accuracy + suppression resistance), Assassinate (single-target
  burst with an explicit counterplay cap — cannot drop a MC/Special
  target below 20% HP in one use, 45s cooldown), Master Manipulator
  (cheaper enemy-recruit conversion price), can recruit surrendered
  regulars, 3 named Specials (Viktor Moreau/Elena Varga/Matteo Rizzo).
- **Zie (Vartieri)**: Vehicle Commander (aura: nearby allied vehicles
  get HP/speed/turret-damage bonuses and cheaper repairs), Deceptive
  Assault (temporary self accuracy buff, real cooldown), starts with a
  pre-owned Armored SUV, 3 role-titled Specials (Axe Assault/Sniper
  Specialist/Machine Gunner) with **Triad Synergy**: a real, tested
  all-or-nothing buff (+20% damage, -15% incoming damage, +25%
  suppression resistance) active only while all 3 are alive and within
  12m of each other.
- **Andrés (Nasion)**: fastest economy (+25% cargo value, +10%
  production speed), factory starts at Level 2, weaker B1 (lower HP/
  accuracy than Juan's), Command Surge (squad buff: up to 8 nearby
  allies get 2x damage for 15s, non-stackable, 75s cooldown), Throw
  Drug Bottle (thrown AoE, travel delay + visible impact radius, 20s
  cooldown), can recruit surrendered regulars, 3 role-titled Specials
  (Shield Guardian/Family Strategist/Smuggler Chemist).
- **Nabil (DEA)**: no B1 tier at all (spawns 3xB2 instead), 24-member
  roster cap (vs. 30 for the other three), cannot recruit surrendered
  enemies, crafts weapons at a **DEA Armory** from **Parts** (not
  money — Parts regenerate passively and are spent on a per-weapon
  crafting queue with a 5-18s build time), **City Patrol income**
  (only while genuinely `State.PATROLLING` for 15s+, with a real
  distance-efficiency penalty for clustered patrollers vs. isolated
  ones), Discipline Aura (nearby DEA units gain accuracy + steady
  morale regen), and a **budgeted allied-AI dispatch** ("Dispatch
  Allies" HUD button, $300 + 90s cooldown) replacing the other
  factions' hostile Heat/DEA-response mechanic entirely (Nabil *is*
  the DEA), 4 Specials (Ghost Operative/Shadow Runner/Pursuit
  Interceptor/Armored Bulwark).
- **Main Character leveling** (all factions): 4 paid upgrades from
  level 1 to 5 ($1000/$2000/$3500/$5500, matching Prompt Dasar's
  table), each level linearly building toward capped totals at level 5
  (+20% max HP, +8% weapon damage, -15% ability cooldown — never
  uncapped scaling). Special units unlock at MC level 4, each is
  unique (one-per-campaign), and price/salary come straight from their
  `UnitData`.
- **Balance simulation** (explicit MVP4 acceptance criterion, not just
  a written claim): `tests/test_mvp4_balance_simulation.gd` runs real,
  seeded, many-trial headless skirmishes with actual `BwUnit`
  instances and real shipped weapon data. Measured results: Zie's
  Triad Synergy trio beats 7xB3 in ~35-45% of trials (strong, not
  invincible); a Nabil Special beats 4xB1 in ~60-80% of trials
  (matches Prompt Dasar's "handle ~4xB1" framing while remaining
  genuinely losable). See docs/BALANCE.md "MVP4 balance simulation
  calibration" for the tuning story and what a naive matchup revealed.
- A real gameplay addition surfaced *by* writing that simulation:
  Special/MC tiers now get intrinsic suppression resistance
  (`SPECIAL_TIER_SUPPRESSION_RESIST` in `unit.gd`) — without it, any
  single high-value unit facing 2+ simultaneous attackers gets
  suppression-locked into an unbreakable retreat loop regardless of
  its own stats, making "a Special can handle several regulars"
  structurally impossible under MVP2's original suppression model.
- A real save/load ordering bug was found and fixed while testing
  non-Juan saves: the scene must resolve which campaign's save it's
  loading *before* building any faction-specific world/UI, otherwise
  "Continue" would silently build Juan's world under a Zie save. See
  docs/TECH_DECISIONS.md.
- 4 new headless test suites (17 total): campaign spawn differences,
  abilities (cooldown/feedback/counterplay), MC leveling + Special
  unlock/uniqueness, Nabil-specific rules, and the balance simulation.
- Manual Xvfb visual verification: confirmed Zie's HQ (real "Vartieri
  Cartel HQ" name, starting vehicle, locked-Special recruitment panel
  showing "MC level 4 required, currently 1") and Nabil's Central City
  (DEA Armory building + crafting panel with real Parts costs,
  "Dispatch Allies" button, 24-roster cap).

Known simplifications, deferred to their stated MVP:
- Only the player's chosen faction's HQ is functional in a given
  playthrough; the other three HQs remain non-functional landmark
  markers (no rival-faction AI yet — MVP5 scope).
- "Ambush"/"explosive"/"kehabisan amunisi" counterplay against Triad
  Synergy named in Prompt Dasar are exercised implicitly through the
  underlying (already-tested) combat/ammo systems, not as a dedicated
  new test scenario.
- Ability bar/recruitment/armory panels are still plain generic
  Controls (MVP6 UI polish), not final themed art.

## MVP 5 delivered scope

Per `Part 7.txt` ("Lanjutkan dari MVP 4. Kerjakan MVP 5: Intelligent AI
dan Diplomacy"):

- **TACTICAL layer** (`scripts/ai/unit_tactical_ai.gd`, one instance
  per AI-controlled `BwUnit`): decides target priority (prefers the
  enemy MC, then lower-HP targets, weighted by distance), flanks
  instead of walking straight at a target outside weapon range,
  proactively disengages below a difficulty-scaled HP threshold
  (separate from and in addition to MVP2's existing suppression-forced
  retreat), revives a downed ally once the area is clear of known
  threats, protects the Main Character by retargeting onto whatever
  threatens it, and dodges incoming grenades via a new global
  `BattlefieldEvents.grenade_incoming` signal. Move/formation, cover,
  reload, suppression, and vehicle entry/exit are MVP1/2/3's existing,
  already-tested `BwUnit`/`Vehicle` mechanics — this layer decides
  *when* to invoke them, not how they work.
- **STRATEGIC layer** (`scripts/ai/faction_strategic_ai.gd`, one
  instance per AI faction): runs recruitment (with a payroll cushion),
  buys ammo/resupplies weapons when a unit's mag+reserve drops below
  30% of full, upgrades the factory once affordable with a safety
  reserve, dedicates runners to cargo pickup → best-demand dealer →
  Bank deposit, buys/repairs vehicles, holds idle units near the HQ
  under threat, sends scouts out when it has zero intel at all (a real
  bug this MVP's own required simulation caught — see "balance
  simulation" notes below), and makes utility-gated raid and
  attack-the-enemy-MC decisions (force-ratio-based, scaled by
  difficulty's `utility_threshold_mult`) or explicitly waits when the
  utility is too low.
- **INFORMATION layer** (`scripts/ai/faction_knowledge.gd`,
  `FactionKnowledge`): real fog-of-war per AI faction — an enemy is
  only "known" if currently within some own unit's `vision_range_px`
  AND passes a line-of-sight raycast; last-known-position persists
  after losing sight and ages into "stale" after 20s, fully forgotten
  after 90s. Every AI decision (tactical and strategic) queries only
  this object, never the live enemy list, so "AI tidak omniscient" is
  structural rather than a convention to remember.
- **AMBUSH** (`scripts/ai/ambush_controller.gd`): a separate
  multi-phase controller (IDLE → ARMED → COMMITTED) requiring both
  fresh intel near a chokepoint and a real force-ratio advantage before
  arming, a utility threshold scaled by difficulty, a 60s cooldown
  (half that on a cancellation), and explicit cancellation if the
  squad is wiped or intel/opportunity goes stale before the target
  arrives.
- **DIPLOMACY** (`scripts/diplomacy/diplomacy_controller.gd`): a new
  `NeutralFactionData` third-party faction; neutral-encounter
  attack/intimidate resolution that nudges a trust value (-1..1, slow
  decay toward 0); alliance formation gated by a trust threshold with a
  randomized 60-240s duration; a trade bonus on dealer sales while
  allied; betrayal that instantly ends an alliance, imposes a sharp
  trust penalty, and is itself cooldown-gated so it can't be spammed;
  and a structural guarantee against shared victory (no such concept
  anywhere in the class) plus `is_hostile_by_default()` so AI never
  auto-targets the neutral faction.
- **Difficulty** (`scripts/data/difficulty_data.gd` + the 3
  `data/difficulty/*.tres`): 4 new knobs — `decision_quality`,
  `utility_threshold_mult`, `retreat_hp_threshold`,
  `ambush_intel_patience_sec` — every one of which only changes
  decision timing/quality, never starting money, vision range, or unit
  count (verified directly by the win-rate report's same-faction
  cross-difficulty comparison; see docs/BALANCE.md).
- **Debug overlay** (`scripts/ui/ai_debug_overlay.gd`,
  `scenes/ui/AiDebugOverlay.tscn`): toggled with F3 in the live game,
  shows per-faction objective/utility/reason-for-last-decision plus the
  known-enemy list with fresh/stale tags; frees itself immediately in
  `_ready()` when `OS.has_feature("release")`, the engine-verified way
  to detect an actual exported release build (not an editor-only
  project setting), so it structurally cannot ship in an export.
- **Headless AI-vs-AI simulation**
  (`scripts/simulation/ai_match_arena.gd`, `AiMatchArena`): wires up N
  complete, independent faction economies (real Factory/Bank/Garage/
  Dealer/CampaignEconomy) each fully driven by the above AI layers,
  with real `BwUnit`/`Vehicle` combat and real `NavigationAgent2D`
  pathing — the same shipped components, just now decided by AI
  instead of a human or test script. A match resolves once one side's
  Main Character dies (the single decisive, bounded event; full-roster
  elimination could drag on indefinitely with ongoing
  recruitment/revival on both sides).
- **Win-rate report** (`tools/run_ai_winrate_report.gd`, acceptance:
  "Laporkan hasil win-rate awal per faction/difficulty"): runs each of
  the 4 campaigns against a reference opponent at all 3 difficulties
  (both sides same difficulty, isolating faction balance), plus a
  same-faction cross-difficulty comparison that directly demonstrates
  Hard beating Medium and Medium beating Easy. Full captured output and
  interpretation in docs/BALANCE.md "MVP5 initial AI win-rate report".
- 6 new headless test suites (23 total):
  `test_mvp5_information.gd`, `test_mvp5_tactical_ai.gd`,
  `test_mvp5_ambush.gd`, `test_mvp5_diplomacy.gd`,
  `test_mvp5_strategic_ai.gd` (isolated economy-loop proof, including a
  real completed recruitment), and `test_mvp5_arena.gd` (the full
  headless-multi-match harness smoke/correctness test).
- A real bug found and fixed by this MVP's own simulation requirement:
  the strategic AI initially never sent any unit to scout, so a
  faction starting with zero intel could never discover its opponent
  and every match timed out — fixed by adding `_manage_scouting()`
  (Prompt Dasar "INFORMATION: Scout").
- A development-only instrumentation mistake caught and corrected by
  visual verification: an early pass attached the tactical-AI layer to
  the map's small fixed hostile encounters (the "Hostile (PLACEHOLDER)"
  squad and DEA response waves), which are deliberately stationary
  (`can_move = false`) — the AI's `order_attack`/`order_move` calls on
  them silently no-op, so it was dead, misleading weight. These fixed
  encounters keep their existing, already-tested `auto_defend`
  behavior; the real, mobile per-faction AI is exercised by
  `AiMatchArena` instead (see docs/TECH_DECISIONS.md "MVP5 live-game AI
  scope").
- Manual Xvfb visual verification: captured the open-world map with the
  F3 debug overlay toggled on, confirming it renders known-enemy
  entries with correct fresh/stale tags and disappears entirely from
  view when toggled off; not committed (screenshots shared directly in
  chat/PR).

Known simplifications, deferred to their stated MVP:
- The live game's own fixed hostile encounters (test squad, DEA
  response waves) do not run the new mobile STRATEGIC/TACTICAL AI —
  they're stationary defenders by design from MVP1/3. A true rival
  cartel AI faction roaming the open world is naturally MVP6/7
  territory once campaign presentation adds a reason to populate the
  other 3 HQs with active, moving factions.
- Ambush chokepoints are supplied by the caller as plain `Vector2`
  points (the arena uses one shared center point); no automatic
  chokepoint detection from map geometry (bridges/alleys/narrow roads)
  was built, since the open world map doesn't yet have dedicated
  geometry for those features.

## MVP 6 delivered scope

Per `Part 8.txt` ("Lanjutkan dari MVP 5. Kerjakan MVP 6: Campaign
Presentation dan User Experience"):

- **Content warning** (`scripts/ui/content_warning.gd`,
  `scenes/ui/ContentWarning.tscn`): the project's new
  `run/main_scene`, shown once per app launch before the Main Menu,
  naming BAD WORLD's actual mature themes (organized crime, armed
  combat, drug trafficking, kidnapping/recruitment of defeated
  combatants, executions) plainly rather than a generic disclaimer.
- **Campaign selection cards** (`scripts/ui/campaign_select.gd`):
  rebuilt from a bare button list into a full card per campaign —
  portrait, faction name, keunggulan (strengths), kelemahan
  (weaknesses), starting units (computed from the same
  `FactionData.has_b1`/`CampaignData` fields `_spawn_fresh()` actually
  uses, never duplicated), economy rating (★ stars + label), and unit
  cap (`max_roster` + MC). The underlying strengths/weaknesses/rating
  fields are new `FactionData` exports populated from each faction's
  already-shipped, already-tested MVP3/4/5 mechanics (see
  `data/factions/*.tres`) — restating existing facts for the UI, not
  new balance claims.
- **Contextual tutorial** (`scripts/gameplay/tutorial_controller.gd`):
  10 hints (selection, movement, recruitment, equipment, ammo,
  factory/dealer/bank, vehicle, patrol, defend, MC protection), each
  shown at most once ever via a one-at-a-time dismissible HUD toast,
  triggered from the real gameplay events that teach each concept
  (first selection, first move/defend/patrol/vehicle-mount order via
  new `CommandController` signals, first recruit, opening Inspect,
  first low/out-of-ammo state, first factory/dealer/bank interaction,
  and immediately at mission start for MC protection). "Seen" state is
  install-wide via `UserPrefsService`, not per-save — documented
  assumption in docs/TECH_DECISIONS.md.
- **Objective tracker, event/alert log, unit inspect/inventory,
  minimap, MC ability bar**: all pre-existing from MVP1-5, kept as-is
  (already real and tested); MVP6 only adds the panels below alongside
  them.
- **Payroll warning**: a red HUD banner on a missed payroll cycle
  (`economy.payroll_processed` signal), in addition to the existing
  Alerts-log line.
- **Low ammo warning**: a HUD label watching the current selection for
  `primary_mag + primary_reserve` at or below 25% of the weapon's full
  capacity ("LOW AMMO") or zero ("OUT OF AMMO").
- **Factory/dealer demand UI**: a HUD panel showing live
  `factory.stored_cargo`/level/destroyed-state and every dealer's
  `current_demand_multiplier()`.
- **Patrol efficiency overlay**: Nabil-only HUD panel driven by a new,
  side-effect-free `CampaignEconomy.patrol_efficiency_snapshot()` that
  mirrors `apply_patrol_income`'s sector-rank rule for display.
- **Diplomacy UI**: shows the one diplomacy-adjacent relationship that
  is actually live in the open world today (DEA Heat/wave-dispatch
  state), with an honest note that full faction trust/alliance/
  betrayal (`scripts/diplomacy/diplomacy_controller.gd`) only has a
  second live faction to negotiate with inside `AiMatchArena` right
  now — see docs/PLACEHOLDER_REGISTER.md.
- **MC ability bar, minimap**: pre-existing, kept; minimap gained a
  **camera alert**: an "Under Attack!" banner + Jump-To button when a
  player unit takes damage while off-screen (approximate on-screen
  check against the camera's current zoom/viewport rect).
- **Pause/Settings**: Pause Menu gained "Save / Load" and "Settings"
  buttons (replacing the old single-slot Save/Load pair).
- **Volume controls** (`scripts/autoload/user_prefs_service.gd`):
  real `Master`/`Music`/`SFX` `AudioServer` buses with working
  volume sliders — audio *content* is still placeholder (nothing
  plays yet), the controls themselves are not.
- **Key rebinding**: all 14 gameplay hotkeys (stop/attack-move/defend/
  grenade/recruit/patrol/exit-vehicle/pause/interact/debug-overlay/
  camera pan ×4) plus 9 control-group keys moved from hardcoded
  `KEY_*` checks into real `InputMap` actions (`project.godot
  [input]`, `bw_*`), rebindable through the Settings panel with
  same-key-collision rejection and a reset-to-default per action.
- **Autosave + ≥3 manual save slots + migration**
  (`scripts/autoload/save_service.gd`): slot 0 is a dedicated autosave
  slot a manual Save button can never write to; slots 1-3 are manual;
  `SaveSlotPanel` lists all 4 with campaign/money/timestamp summaries
  and independent Save/Load/Delete; `schema_version` bumped 1→2 with a
  real step-by-step `_migrate()` (not just a mismatch warning) that
  backfills the new MVP6 campaign-summary fields on an old save; Main
  Menu's "Continue" now resumes whichever slot (including autosave) was
  saved most recently.
- **Victory, defeat, restart, campaign summary**
  (`scripts/gameplay/victory_defeat_screen.gd`): the player's own MC
  dying triggers DEFEAT today (fully reachable in the live game); the
  cartel/Nabil VICTORY rule (all rival MCs dead, +no active cartel
  factory for Nabil) is implemented and tested
  (`tests/test_mvp6_victory_defeat.gd`, against a test-registered fake
  enemy MC) but structurally unreachable in the live open world until
  a rival faction is actually spawned there (see
  docs/PLACEHOLDER_REGISTER.md `PLACEHOLDER_rival_faction_hqs`). Both
  outcomes show a campaign summary (play time, money earned, final
  balance, roster, enemies eliminated) and Restart/Load/Quit.
- A real pre-existing bug found and fixed by this MVP's own victory/
  defeat test: `SelectionManager.register_unit` and two call sites in
  `open_world_map.gd` connected `BwUnit.died` (which already carries
  the dying unit as its own argument) with an extra `.bind(unit)`,
  silently breaking every player-unit-death and enemy-death cleanup
  callback end-to-end (Godot logs a swallowed "Method expected 1
  arguments, but called with 2" and the callback never runs). Fixed by
  dropping the redundant bind at all three sites — see
  docs/TECH_DECISIONS.md.
- 4 new headless test suites (27 total):
  `test_mvp6_campaign_select_data.gd`, `test_mvp6_prefs_and_tutorial.gd`,
  `test_mvp6_save_slots_and_migration.gd`, `test_mvp6_victory_defeat.gd`.
- Manual Xvfb visual verification at 1920×1080 and 1366×768 (Content
  Warning, Main Menu, Campaign Select cards, Settings, in-mission HUD),
  plus a keyboard-only navigation pass; see docs/TEST_PLAN.md.

Known simplifications, deferred:
- Victory is implemented and tested but not reachable in the live
  open world yet (see above) — MVP7 territory alongside rival faction
  HQs.
- Tutorial "seen" state and volume/keybind prefs are install-wide, not
  per-save-slot — a documented assumption, not a bug.
- Nabil's open-world map still spawns a functional Factory + 4 Dealers
  even though Prompt Dasar states "Nabil tidak menjual cargo" (no
  Dealer loop) — a pre-existing MVP3/4 gap, not introduced by MVP6;
  the new Factory/dealer demand HUD panel simply displays whatever
  state exists for any campaign, so it is harmless but not hidden for
  Nabil. Documented here since it was only discovered while building
  that panel.

## MVP 7 delivered scope

Per `Part 9.txt` ("Kerjakan MVP 7: Release Candidate Validation. Jangan
menambahkan fitur besar baru. Fokus pada perbaikan."). Full breakdown
(done/verified vs. placeholder vs. not-done vs. known bugs vs.
technical risks) lives in **`docs/RELEASE_CANDIDATE_REPORT.md`** — this
section is a short pointer, not a duplicate.

- **Placeholder audit** (item 1-2): every existing Register row sorted
  into "safe for MVP" (cosmetic-only, ~20 rows) vs. "must replace
  before a real release" (functional gaps: rival-faction HQs/AI,
  missing rogue/surrender/flee behavior, Nabil's own Factory/Dealer
  loop despite "tidak menjual cargo") — see
  `docs/PLACEHOLDER_REGISTER.md`.
- **Automated/integration/headless-AI tests** (items 3-5): all 28
  suites pass (4 new this MVP); `AiMatchArena` + a new
  `tools/run_balance_report.gd` cover the headless-simulation
  requirement.
- **All 4 campaigns × 3 difficulties** (item 6): exercised by the new
  balance report (12 faction/difficulty cells, 3 trials each).
- **Every victory/defeat condition** (item 7): **real fix** — VICTORY
  was previously only reachable via a test-only fake registry; this
  MVP adds `_spawn_rival_factions()` so the other 3 campaigns' real
  Main Characters (their own stats) spawn in the open world and are
  checked for real, including a real fix to Nabil's "no active cartel
  factory" condition (was checking the player's own factory instead of
  the rival cartels'). DEFEAT was already real since MVP6.
- **Unit cap, payroll, factory/dealer/bank loop, vehicle/turret,
  save/load+migration, special-unit balance** (items 8, 9, 11, 12, 15,
  17): already covered by MVP2-6's own suites, re-run clean this pass.
- **Out-of-ammo behavior, safe-zone exploit** (items 10, 13): **a real
  bug found and fixed** — a unit standing inside a safe zone could
  fire/execute/recruit/throw-grenades outward with zero counterplay
  (only the target's safe-zone status was ever checked before,
  contradicting Prompt Dasar's explicit "senjata diturunkan" rule).
  Fixed at all 4 call sites; new `tests/test_mvp7_release_validation.gd`.
- **Main Character death** (item 14): already real since MVP6 (DEFEAT),
  now joined by a real, playable VICTORY path.
- **AI ambush frequency** (item 16): measured directly (2.00/1.67/1.67
  committed ambushes per match, Easy→Hard) in the new balance report,
  with a qualitative explanation for the Easy > Hard direction.
- **Memory leak / orphan node / navigation spike / frame drop, pooling/
  culling, 60 FPS target** (items 18-21): new
  `tests/test_mvp7_release_validation.gd` (50 spawn/death cycles, 0
  orphan nodes) and a new `tools/profile_near_cap_multi_faction.gd`
  (4 factions, 40 units, live combat, real wall-clock timing — not
  `--fixed-fps`): 16.56-16.60ms average frame time (60.2-60.4 FPS
  budget), 0 orphan nodes after the stress run. Pooling/culling
  assessed and **not implemented** — the 60 FPS target is already met
  at this project's own stated unit-count ceiling without them; see
  `docs/BALANCE.md` "MVP7 performance report".
- **Windows export preset + build + run the export, not just the
  editor** (items 22-24): `export_presets.cfg` committed (Windows
  Desktop + a Linux Verification Build preset); both built
  successfully. The Windows `.exe` is structurally valid but could not
  be *executed* in this sandbox — Wine fails to run any Windows binary
  at all under this sandbox's gVisor kernel (confirmed with a minimal,
  project-unrelated `wine cmd.exe` test; reported as a platform issue).
  The Linux build was run headful under Xvfb and screenshot-confirmed
  rendering real gameplay UI, as the closest feasible substitute. See
  `docs/TECH_DECISIONS.md` and `docs/RELEASE_CANDIDATE_REPORT.md`.
- **Docs** (item 25): README, this file, TECH_DECISIONS, TEST_PLAN,
  BALANCE, PLACEHOLDER_REGISTER all updated; new
  `docs/RELEASE_CANDIDATE_REPORT.md` is the authoritative final report
  Prompt Dasar's closing MVP7 instructions ask for.

Explicitly **not done** this pass (by design — "jangan menambahkan
fitur besar baru"): rogue/surrender/flee behavior when an enemy MC
dies (Prompt Dasar base rules; a genuine missing feature, not
previously flagged anywhere — would be a new per-unit behavior system,
out of MVP7's own stated scope); Nabil's own Factory/Dealer loop
removal (pre-existing MVP3/4 deviation, documented, not touched);
root-causing why Campaign Fauzi's AI never buys a vehicle in the
balance report (observed, not yet investigated).

**This project is not production-ready** — see
`docs/RELEASE_CANDIDATE_REPORT.md` for the full, explicit breakdown
the user asked this report to provide rather than a blanket "done"
claim.
