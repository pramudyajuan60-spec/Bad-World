# Placeholder Policy and Register

## Policy (rule 6 and rule 9 of Prompt Dasar)

1. Never edit or delete an original file under `Assets/`. Placeholders,
   crops, recolors, or derived art live under a separate tree:
   `Assets_Generated/<category>/...` (created the first time a later MVP
   actually needs to produce a placeholder asset; does not exist yet
   because MVP 0 builds no gameplay that needs one).
2. Every placeholder file name and every placeholder-backed data entry
   must contain the literal string `PLACEHOLDER` (e.g.
   `PLACEHOLDER_drug_dealer_4.png`, or a `.tres` field like
   `display_name = "Drug Dealer 4 (PLACEHOLDER)"`).
3. Every placeholder gets a row in the table below the moment it is
   created, with: what it stands in for, why, where the real asset should
   eventually come from, and whether it currently blocks anything.
4. A placeholder is never silently promoted to "final" — removing a row
   from this table requires replacing the placeholder file/data and
   noting the change here.

## Register

| ID | Stands in for | Status | Blocking? | Notes |
|---|---|---|---|---|
| (none yet) | — | — | — | MVP 0 creates no gameplay placeholders. The gaps below are **known asset shortages**, tracked here so the MVP that first needs each one creates the actual placeholder file per the policy above, instead of rediscovering the gap. |

## Known future placeholder needs (tracked, not yet created)

These come from docs/REPO_AUDIT.md's mismatch list. None block MVP 0
because MVP 0 ships no playable world/units.

1. **Drug Dealer 4** — only 3 of 4 dealer map images exist. Needed by
   MVP 3 (world economy loop).
2. **Nabil B2, 3rd unit portrait** — only 2 of 3 `Unit/B2/` portraits
   exist for DEA. Needed once Nabil's roster UI is built (MVP 1/2).
3. **Bellarosa B3 unit portraits** — only `Unit 3.jpg` exists (no
   `Unit 1`/`Unit 2`). Needed when Bellarosa's B3 roster UI is built.
4. **Juan's concept map mislabeled "Nasion Familia"** — cosmetic text on
   concept art, not corrected at the concept-art level; the MVP 3
   playable map must not carry the wrong label into any in-game UI.
5. **Recruitment Place map labeled "ARMORY"** — same treatment as above,
   for the MVP that builds the Recruitment building (MVP 1 UI /
   MVP 3 world placement).
6. **Nabil Special Unit numbering (1/2/8/4) on the contact-sheet image**
   — treat "8" as unit #3 (`Pursuit Interceptor`) per Prompt Dasar until
   the sheet is corrected; needed by MVP 4 (Nabil's specials).
7. **Vartieri weapon concept coverage (axe/sniper/MG)** — re-check before
   implementing Zie's 3 Special units in MVP 4.
