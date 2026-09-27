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
| 4 | Four Asymmetric Campaigns | Not started |
| 5 | Intelligent AI and Diplomacy | Not started |
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

## Next up: MVP 4 (not started)

Per `Part 6.txt`: activate all four campaigns (Zie/Andrés/Nabil become
playable alongside Juan), faction-specific bonuses/abilities, Special
units, Main Character leveling to 5. Substantially larger than MVP 3;
treat as its own effort.
