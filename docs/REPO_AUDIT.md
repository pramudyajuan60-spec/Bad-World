# Repository Audit (MVP 0)

## Commit confirmation

See docs/TECH_DECISIONS.md → "Repository / commit confirmation". Summary:
the commit token named in the Prompt Dasar is not a resolvable Git SHA in
this repo; MVP 0 work is pinned against `HEAD` short hash `974acb1`
("first commit") on branch `hoplite/delos-9da1c4dc`.

## Starting state

Before MVP 0, the repository was **asset-only**: 306 files under
`Assets/`, two prompt-document folders (`Prompt AI Bad World GAME -/`,
`Prompt SpritSheet/`), and a one-line `README.md`. No `project.godot`, no
scenes, no scripts, no tests, no docs — confirmed by a full non-image file
listing prior to this MVP.

## Story files read

All four canonical `Story.txt` files were read in full before any data
was written, per rule 7:

- `Assets/Campaign/Bellarosa Syndicate/Main Character/Story.txt` (Juan Bellarosa)
- `Assets/Campaign/Valtieri Cartel/Main Character/Story.txt` (Zie Vartieri)
- `Assets/Campaign/Nasion Familia/Main Character/Story.txt` (Andrés A. Násion)
- `Assets/Campaign/DEA Administrator/Main Character/Story.txt` (Nabil Verhan)

Their `id`/`main_character_name`/`faction` mapping is codified in
`data/campaigns/*.tres` and cross-checked by `tests/test_campaign_data.gd`.

## Asset inventory

Full generated inventory: `docs/ASSET_MANIFEST.md` (human-readable) and
`data/manifest/asset_manifest.json` (machine-readable, consumed by
`tools/validate_asset_manifest.gd`). Regenerate both with
`python3 tools/generate_asset_manifest.py` after any change under
`Assets/`.

| Group | Files |
|---|---|
| Bellarosa Syndicate | 86 |
| Valtieri Cartel (see naming mismatch below) | 71 |
| Nasion Familia | 75 |
| DEA Administrator | 59 |
| Shared (Character Inspect, Game Maps, Gun) | 15 |
| **Total** | **306** |

## Known mismatches and gaps

### Already documented in Prompt Dasar (confirmed present)

1. **Drug Dealer 4 missing.** `Assets/Game Maps/` only has
   `Drug Dealer 1.png`..`Drug Dealer 3.png`. A 4th dealer is required by
   the world design. Registered in docs/PLACEHOLDER_REGISTER.md.
2. **Nabil/DEA has only 2 B2 portrait designs, needs 3.**
   `Assets/Campaign/DEA Administrator/Unit/B2/` has `Unit 1.jpg`,
   `Unit 2.jpg` only (note: the *spritesheet* side,
   `Spritsheet/B2/Char 1..3/`, does have 3 folders — the shortage is
   specifically in the `Unit/` portrait set).
3. **Juan's concept map mislabeled "Nasion Familia".** Not yet corrected;
   flagged for the MVP that actually builds the playable map (MVP 3),
   since MVP 0 does not touch concept art.
4. **Recruitment Place map visually labeled "ARMORY".**
   `Assets/Game Maps/Recruitment Place.png` — same as above, deferred to
   the MVP that builds the recruitment building.
5. **Nabil's Special units numbered 1, 2, 8, 4 in some source material.**
   In the current `Assets/Campaign/DEA Administrator/Spritsheet/Special
   Unit/` tree the four folders are already named
   `Ghost Operative`, `Shadow Runner`, `Pursuit Interceptor`,
   `Armored Bulwark` (no bare numbers) — the numbering issue lives in
   `Assets/Campaign/DEA Administrator/Unit/Special Unit/Special Unit.jpg`,
   a single contact-sheet-style image. Treat "8" as the 3rd unit
   (`Pursuit Interceptor`) per Prompt Dasar until that sheet is corrected.
6. **Vartieri concept art doesn't consistently show axe/sniper/machine
   gun.** Not re-derivable from file listings alone; flagged for the MVP
   that builds Zie's Special units (MVP 4) to re-check against the actual
   art before implementing `Axe Assault` / `Sniper Specialist` /
   `Machine Gunner` visuals.

### Newly found during this audit

7. **Valtieri vs. Vartieri naming is inconsistent on disk.** The campaign
   folder is `Assets/Campaign/Valtieri Cartel/`, and
   `Assets/Campaign/Valtieri Cartel/Vehicle/Valtieri Vehicle.jpg` uses
   "Valtieri" too — but the character portrait and spritesheet use
   "Vartieri": `Main Character/Zie Vartieri.png` and
   `Spritsheet/ZIe Vartieri/` (note also the stray capital "I" in "ZIe").
   Prompt Dasar is explicit: the canonical form is
   **"Zie Vartieri — Vartieri Cartel"**. Resolution taken in MVP 0: the
   internal faction id/display name use the canonical **"Vartieri
   Cartel"** (`faction_vartieri` in `data/factions/faction_vartieri.tres`),
   while `asset_folder` points at the literal on-disk folder name
   `"Valtieri Cartel"` so no original asset path is renamed. Logged for a
   future non-destructive rename pass (copy/alias, not delete) if this
   becomes confusing in the editor's FileSystem dock.
8. **Bellarosa `Unit/Unit B3/` only has `Unit 3.jpg`.** No `Unit 1.jpg`/
   `Unit 2.jpg`; only one B3 portrait design exists for that faction,
   oddly numbered "3". Registered in docs/PLACEHOLDER_REGISTER.md as a
   gap the same way as the Nabil B2 shortage above.
9. **An extra, unlisted `Dog` spritesheet exists** at
   `Assets/Campaign/DEA Administrator/Spritsheet/Dog/Dog Animation.png`.
   Not mentioned anywhere in Prompt Dasar/MVP prompts. Not used by any
   MVP 0 data; left as-is for a later MVP to decide its purpose (K9 unit?
   flavor animation?).
10. **Nasion Familia `Spritsheet/B1/Char 4/` includes an extra file**
    `ChatGPT Image 26 Sep 2026, 17.18.09.png` alongside the standard four
    sprite-sheet PNGs — likely a stray export from the generation
    process, not one of the four documented sheet categories (MELEE/
    GRANAT/..., PERGERAKAN/..., SEMUA SENJATA API, SEMUA SENJATA DAN VFX).
    Left untouched; flag for cleanup when this character is imported into
    gameplay.

None of the above block MVP 0 (no gameplay depends on the missing/odd
assets yet); they are recorded so later MVPs don't have to re-discover
them.

## MVP 0 file changes

See the pull request diff for the exact file list. In summary: added
`project.godot`, `scenes/Main.tscn`, `scripts/**`, `data/**` (8 schema
scripts + 11 populated `.tres` resources + generated manifest JSON),
`tools/**`, `tests/**`, `docs/**`, updated `README.md`, added `.gitignore`
and a placeholder `icon.svg`. Original `Assets/` content is unmodified
(only Godot's own `*.png.import`/`*.jpg.import` sidecar metadata files
were added next to each asset by the editor import pass — standard Godot
behavior, no source bytes changed).
