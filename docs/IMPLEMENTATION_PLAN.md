# Implementation Plan (MVP Roadmap)

Source: `Prompt AI Bad World GAME -/Part 1.txt` (base rules) and
`Part 2.txt`..`Part 9.txt` (one file per MVP, MVP 0 through MVP 7). Work
proceeds strictly in this order; each MVP stops and reports before the
next begins (base rule 12).

| MVP | Title | Status |
|---|---|---|
| 0 | Repository Audit and Godot Bootstrap | **Done this session** — see report in the PR/handoff message. |
| 1 | Juan Bellarosa Core RTS Vertical Slice | Not started |
| 2 | Combat and Unit Management | Not started |
| 3 | Open-World Economy and Vehicle Loop | Not started |
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

## Next up: MVP 1 (not started)

Per `Part 3.txt`: main menu, Campaign Juan playable slice, one isometric
test map, Juan + 3×B1 spawn, RTS camera/selection/move/formation,
NavigationAgent2D-based movement + obstacle avoidance, one dummy enemy
group, attack-move, pause/restart, minimal save/load. This is a
substantially larger scope than MVP 0 and should be treated as its own
multi-step effort, started only after this MVP 0 report is reviewed.
