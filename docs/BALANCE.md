# Balance Reference (V0.1)

This is a **direct transcription** of the "BALANCE V0.1" section of the
Prompt Dasar (`Prompt AI Bad World GAME -/Part 1.txt`). MVP 0 does not
implement any of these numbers in gameplay yet (there is no combat, no
economy, no recruitment loop) — they are captured here so later MVPs
implement the *same* numbers instead of re-deriving them from the prompt
text again. When a later MVP wires a number into `UnitData`/`WeaponData`/
`VehicleData`/etc., update this file's status column instead of deleting
the row.

## Base unit stats

| Unit | HP | Armor | Accuracy | Move speed | Recruit level |
|---|---|---|---|---|---|
| B1 | 100 | – | 55% | 3.2 | 1 |
| B2 | 170 | 2 | 68% | 3.0 | 2 |
| B3 | 250 | 4 | 76% | 2.8 | 3 |
| Special | varies per unit | – | – | – | unlock at level 4 |

## Recruitment price / salary per faction

Salary paid every **120 seconds** of gameplay time.

| Faction | B1 price/salary | B2 price/salary | B3 price/salary | Special price/salary |
|---|---|---|---|---|
| Juan (Bellarosa) | $300 / $35 | $800 / $90 | $1,800 / $180 | $5,500 / $400 |
| Zie (Vartieri) | $330 / $40 | $850 / $95 | $1,900 / $190 | $6,500 / $450 |
| Andrés (Nasion) | $250 / $30 | $650 / $75 | $1,500 / $150 | $5,000 / $350 |
| Nabil (DEA) | no B1 | $1,000 / $110 | $2,200 / $220 | $7,500 / $500 |

Unpaid salary: 1 missed cycle → accuracy −10, speed −10%, morale down.
2 missed cycles → B1 can desert; B2/B3/Special get a combat penalty
instead of leaving. Morale recovers gradually once paid; HUD must warn
before any unit is lost.

## Starting resources

| Campaign | Money | Units | Factory | Vehicle | Notes |
|---|---|---|---|---|---|
| Juan | $4,000 | Juan + 3×B1 | Level 1 | utility vehicle | |
| Zie | $4,500 | Zie + 3×B1 | Level 1 | armored SUV | |
| Andrés | $5,500 | Andrés + 3×B1 | Level 2 | utility vehicle | fastest economy |
| Nabil | $6,500 | Nabil + 3×B2 | DEA HQ | patrol van | +900 Parts, no B1 |

(These four rows are already implemented as `starting_money` in
`data/campaigns/*.tres`; unit/vehicle spawning is MVP 1.)

## Roster caps

- Juan / Zie: max 30 recruited members + the Main Character (31 total).
- Andrés: max 30 recruited members + the Main Character.
- Nabil: max 24 recruited members + Nabil (25 total).
- Special units always count against the cap.

## Main Character upgrade costs (levels 2–5)

Level 2 $1,000 → Level 3 $2,000 → Level 4 $3,500 → Level 5 $5,500.
Cumulative cap by level 5: **max** +20% HP, +8% weapon damage, −15%
ability cooldown (do not exceed).

## Weapons (Gun Shop prices) and Nabil's Armory (Parts)

| Item | Gun Shop price | Parts cost (Nabil) |
|---|---|---|
| Knife | $90 | – |
| Pistol (12 rd) | $250 | 40 |
| SMG/compact carbine (30 rd) | $500 | 70 |
| Shotgun (8 shells) | $650 | 90 |
| Assault rifle (30 rd) | $800 | 110 |
| Sniper rifle (5 rd) | $1,200 | 180 |
| LMG (60 rd) | $1,600 | 220 |
| Grenade (single use) | $120 | 30 |
| Tactical vest | $600 | – |
| RPG/heavy launcher | from $2,500 (+expensive ammo) | – |

Armory: produces 100 Parts / 90s, cap 1,500 Parts, crafting takes
5–18s depending on item; stops entirely if DEA HQ/Armory is destroyed
until repaired.

## Vehicles

| Class | Price | Seats |
|---|---|---|
| Compact/Sedan | $1,800 | 4 |
| Armored SUV | $3,500 | 6 |
| Gun Truck | $5,500 | 5 + turret |
| APC | $8,500 | 8 + heavy turret |

Moving-turret accuracy penalty: −20 points. Zie's faction modifier makes
Vartieri vehicles the strongest (not invulnerable): HP +20%, speed +12%,
turret damage +15%, repair cost −20%.

## Factory levels

| Level | Upgrade cost | Cargo interval | Quality multiplier |
|---|---|---|---|
| 1 (start) | – | 45s | 1.0 (base $700/cargo) |
| 2 | $1,500 | 38s | 1.15 |
| 3 | $3,500 | 32s | 1.35 |
| 4 | $7,000 | 28s | 1.60 |

Max 2 active factories per cartel. Faction modifiers: Andrés starts at
Level 2, +25% sale value, +10% faster production. Juan is baseline. Zie
has −5% base sale value, offset by alliances and faster/safer vehicles.

## Drug Dealer demand curve (per dealer)

1st sale to a dealer: 100% value. 2nd: 90%. 3rd: 75%. 4th+: 50%. Demand
recovers after ~45s of not selling to that dealer (encourages
route/dealer rotation). Selling requires a 5s channel.

## Patrol income (Nabil / City Patrol)

Base $110 per unit per 60s. Distance rules: <8m from another DEA
patroller → 2nd unit 50%, further units 25%; 8–15m → 80% each; >15m in a
different sector → 100%. Max 4 income-generating units per sector (5th+
earns nothing). Must be idle/patrolling ≥15s before income starts; no
income while fighting, at Bank, or at Recruitment.

## DEA response / Heat

Heat builds in ~35m combat clusters. After 120s of continuous gunfire,
DEA is called; arrives ~60s later via road/map-edge/DEA base (never
spawns on top of the player). Heat decays after 30s without gunfire. Max
2 waves per cluster, ~6 minute cooldown per cluster.

- Wave 1: 4×B2-equivalent agents + 1×B3-equivalent commander + 1 SUV.
- Wave 2 (if conflict continues): 2×B3 + 1 APC.
- On Campaign Nabil, DEA responders are allied AI instead, costing $300
  operational budget per dispatch with a 90s cooldown; no dispatch if
  budget is insufficient.

## Difficulty timing

| Difficulty | Reaction delay | Decision interval |
|---|---|---|
| Easy | ~2.5s | ~3s |
| Medium | ~1.5s | ~1.5s |
| Hard | ~0.75s (still humanlike) | ~0.75s |

(Already implemented as `data/difficulty/*.tres`; consuming AI systems
are MVP 5.)

## Special units — targets to verify via simulation, not just written balance

- Zie's Triad Synergy (all 3 Specials alive within 12m): +20% damage,
  +15% armor, +25% suppression resistance; together should beat ~8×B3 in
  a balanced simulation, per Prompt Dasar — **not yet simulated**
  (requires MVP 5+ AI/vehicle simulation tooling).
- Each Nabil Special at full health/ammo/ability should be able to handle
  ~4×B1, or ~3×B2, or ~2×B3 — same caveat, **not yet simulated**.
