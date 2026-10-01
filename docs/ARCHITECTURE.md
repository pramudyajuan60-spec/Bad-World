# Architecture

## Module breakdown (target, per Prompt Dasar "ARSITEKTUR")

The full design calls for these modules. MVP 0 only stands up the first
one (**Data**); every other module is a placeholder for later MVPs so the
eventual directory layout is decided once, up front, instead of being
reshuffled mid-project.

| Module | Status after MVP 0 | Planned MVP |
|---|---|---|
| Data (Campaign/Faction/Unit/Weapon/Vehicle/Building/Upgrade/Difficulty schemas) | **Done** (`scripts/data/`, `data/`) | 0 |
| Input & command system | Not started | 1 |
| Selection | Not started | 1 |
| Camera | Not started | 1 |
| Unit simulation | Not started | 1 |
| Navigation & formation | Not started | 1 |
| Combat | Not started | 2 |
| Weapon/ammo/inventory | Schema only | 2 |
| Vehicle | Schema only | 3 |
| Economy | Not started | 3 |
| Factory/dealer/bank | Not started | 3 |
| Faction/diplomacy | Not started | 4/7 |
| Tactical AI | Not started | 5 |
| Strategic AI | Not started | 5 |
| Objective/victory | **Done** — real VICTORY (rival faction MCs + Nabil's rival-factory condition) and DEFEAT, both reachable by playing | 4/6/7 |
| Save/load | Not started | 1 (minimal) → 6 (full) |
| UI | Bootstrap-only debug list | 1 → 6 |
| Audio/VFX | Not started (placeholder policy defined) | 6 |
| Debug tools | Asset manifest validator + smoke tests | 0 → grows every MVP |

## Stable IDs (established in MVP 0)

`StringName` identifiers are used everywhere an ID is needed, matching
Prompt Dasar's requirement for stable IDs decoupled from display names:

- Faction: `faction_bellarosa`, `faction_vartieri`, `faction_nasion`,
  `faction_dea`.
- Campaign: `campaign_juan`, `campaign_fauzi`, `campaign_atha`,
  `campaign_nabil` (menu names only; main character names are separate
  fields, see docs/REPO_AUDIT.md item 7 for the Vartieri/Valtieri note).
- Difficulty: `difficulty_easy`, `difficulty_medium`, `difficulty_hard`.

Unit/Weapon/Vehicle/Building/Upgrade/Mission/SaveData IDs are not yet
allocated (no instances exist yet beyond the schema), and will follow the
same `snake_case` convention when populated.

## Data flow (MVP 0)

```
data/factions/*.tres  ──┐
                        ├─► CampaignDatabase (autoload, scripts/autoload/campaign_database.gd)
data/campaigns/*.tres ──┤        │
data/difficulty/*.tres ─┘        ▼
                          scripts/main/main.gd (Main.tscn)
                          prints/lists loaded campaigns — proves the data
                          layer works; no real UI/gameplay yet.
```

`tools/validate_asset_manifest.gd` and `tests/test_campaign_data.gd` read
the same `data/` resources independently (as headless `SceneTree`
scripts) to catch regressions without needing the full scene tree.

## Save system (not yet implemented)

Prompt Dasar requires a versioned save schema, ≥3 manual slots, and a
separate autosave. This is explicitly out of scope until MVP 1
("Minimal save/load posisi unit dan campaign"); no save code exists yet.
Recording this here so the eventual `SaveData` schema is designed once
the first thing worth saving (unit position/campaign selection) exists.
