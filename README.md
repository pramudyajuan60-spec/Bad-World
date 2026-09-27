# Bad-World

Single-player open-world real-time strategy concept ("BAD WORLD") — currently an
**asset and lore repository**. There is no playable Godot build yet. The tracked
content is campaign art, spritesheets, maps, and the multi-part build prompts.

## Layout

- `Assets/Campaign/<Faction>/` — per-faction art: `Main Character/`, `Maps/`,
  `Sprit.../` (note the historical `Sprit` spelling), `Unit/`, `Vehicle/`.
- `Assets/Game Maps/` — shared locations: world, bank, gun shop, garage,
  recruitment place, drug dealers 1–3.
- `Assets/Character Inspect/` — portraits: Juan, Fauzi, Atha, Nabil.
- `Assets/Gun/` — gun references: B1, B2, B3.
- `Prompt AI Bad World GAME -/` — 9-part build plan (Parts 1–9).
- `Prompt SpritSheet/` — 6 spritesheet prompts (Dasar, MC, Minion, Parts 2–3, Weapon).
- `docs/ASSET_INVENTORY.md` — verified file inventory and known naming mismatches.

## Campaigns

| Faction | Main character | Map | Vehicle |
|---|---|---|---|
| Bellarosa Syndicate | Juan Bellarosa | Juan Maps (Mafia) | Bellarosa Syndicate Vehicle |
| DEA Administrator | Nabil Verhan | Nabil Maps (DEA) | DEA Vehicle |
| Nasion Familia | Andrés A. Násion | Atha Maps (Cartel) | Nasion Familia Vehicle |
| Valtieri Cartel | Zie Vartieri | Fauzi Maps (Cartel) | Valtieri Vehicle |

Each faction also has a `Main Character/Story.txt` (canonical lore, in Indonesian).
Do not rewrite lore; presentation layers should quote or summarize it.

## Working rules

- Do not modify or delete original assets destructively.
- Keep derived crops, placeholders, or processed output in a separate directory.
- Expect hostile filenames: most paths contain spaces or commas, basenames repeat
  across folders, and some paths need quoting (see `docs/ASSET_INVENTORY.md`).
- The `Sprit...` directory spelling is historical — document references to it
  instead of renaming assets in a cleanup PR.

## Status

MVP 0 (repository audit + Godot bootstrap per `Part 2.txt`) has not landed:
no `project.godot`, no scripts, no test setup. See the inventory doc for the
verified baseline before scaffolding.
