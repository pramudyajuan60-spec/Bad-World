# Asset inventory (verified)

Snapshot generated from `git ls-files` at PR commit `7b062e2`, before the MVP 0
bootstrap added Godot project files and per-asset `.import` metadata. The counts
below cover the original source assets, lore, and prompts only; they are not the
current repository-wide file count. Quoted non-ASCII paths are counted by their
real extension.

## Totals

- Tracked files: **322**
- Images: **302** (262 PNG, 40 JPG — the 5 quote-wrapped non-ASCII paths are
  real `.png` files, not a separate extension)
- Text: **19 TXT** (9 game-plan parts, 6 spritesheet prompts, 4 `Story.txt`)
- Docs: **1 MD** (`README.md`)

## Where the files live

- `Assets/Campaign/`: **291**
  - Bellarosa Syndicate: 86
  - DEA Administrator: 59
  - Nasion Familia: 75 (includes 5 non-ASCII `Andrés A. Násion` paths)
  - Valtieri Cartel: 71
- `Assets/Game Maps/`: 8 (World, Bank, Gun Shop, Garage, Recruitment Place,
  Drug Dealer 1–3)
- `Assets/Character Inspect/`: 4 (Juan, Fauzi, Atha, Nabil)
- `Assets/Gun/`: 3 (B1, B2, B3 Gun)
- Prompts: 15 (`Prompt AI Bad World GAME -/` Parts 1–9,
  `Prompt SpritSheet/` Dasar, Part 1 MC, Part 1 Minion, Part 2, Part 3, Weapon)
- Root docs: 1 (`README.md`)

## Anchor assets per faction

- Bellarosa: `Main Character/Juan Bellarosa.png`, `Maps/Juan Maps (Mafia).jpg`,
  `Vehicle/Bellarosa Syndicate Vehicle.jpg`
- DEA: `Main Character/Nabil Verhan.png`, `Maps/Nabil Maps (DEA).jpg`,
  `Vehicle/DEA Vehicle.jpg`
- Nasion: `Main Character/Andrés A. Násion.png` (non-ASCII path, quotes needed),
  `Maps/Atha Maps (Cartel).jpg`, `Vehicle/Nasion Familia Vehicle.jpg`
- Valtieri: `Main Character/Zie Vartieri.png`, `Maps/Fauzi Maps (Cartel).jpg`,
  `Vehicle/Valtieri Vehicle.jpg`

## Known naming mismatches (do not silently rename; fix deliberately)

- `Sprit...` directory spelling (not `Sprite...`) appears in all four campaigns
  (247 tracked paths).
- 321 of 322 tracked paths contain a space or comma — always quote paths in
  scripts and docs.
- Spritesheet basenames repeat across folders (e.g. ~51× `SEMUA SENJATA DAN
  VFX.png` (52×), `PERGERAKAN DAN KONDISI KARAKTER.png` (50×),
  `MELEE, GRANAT, COVER, DAN ABILITY.png` (49×),
  `SEMUA SENJATA API.png` (47×), so a bare filename
  never identifies an asset.
- 44 `Screenshot <date> <time>.png` files are mixed in with final art; treat
  them as reference captures until triaged.
- `Valtieri Cartel/Spritsheet/ZIe Vartieri/` (capital `I`) vs
  `Main Character/Zie Vartieri.png` (lowercase `i`).
- 5 Nasion paths contain non-ASCII `é`/`á` and appear quoted in `git ls-files`
  output — copy them with quoting or tab-completion.
- `Story.txt` files are single-line walls of text (~5.3–5.7 KB each, Indonesian
  lore). Read with wrapping on; do not reformat the originals.

## MVP 0 additions since this snapshot

- `project.godot`, scenes, typed GDScript, data resources, automated checks,
  and additional project documentation are now present; see `README.md` and
  `docs/REPO_AUDIT.md` for the current project entry points.
- Godot `.import` metadata is generated project support and is excluded from
  this source-art inventory.
- `.gitattributes` and `.gitignore` provide binary/text and local-file hygiene.
