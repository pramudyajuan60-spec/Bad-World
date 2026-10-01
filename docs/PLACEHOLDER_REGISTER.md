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
| PLACEHOLDER_unit_body | Animated top/isometric-down unit sprite | Active (MVP 1) | No | `scripts/gameplay/unit.gd` draws a procedural colored `Polygon2D` circle (blue = player, red = enemy) + a `TierLabel` text tag instead of a real sprite. Real animated sprites depend on the sprite-sheet pipeline described in `Prompt SpritSheet/`, out of scope until an MVP actually imports those frames. |
| PLACEHOLDER_selection_ring | Themed selection-ring sprite/shader | Active (MVP 1) | No | `scripts/gameplay/selection_ring.gd` draws a plain circle outline via `_draw()`. |
| PLACEHOLDER_health_bar | Themed health-bar UI sprite | Active (MVP 1) | No | `scripts/gameplay/health_bar.gd` draws two flat-color rects via `_draw()`. |
| PLACEHOLDER_destination_marker | Themed move-order marker VFX | Active (MVP 1) | No | `scripts/gameplay/destination_marker.gd` draws a plain X-in-circle, auto-frees after ~0.9s. |
| PLACEHOLDER_dummy_enemy_squad | A real hostile faction encounter | Active (MVP 1) | No | `bellarosa_test_map.gd` spawns 4 units named "Hostile (PLACEHOLDER)", faction_side `enemy_dummy`, with no faction identity, art, or AI beyond firing back if approached. Exists purely so MVP 1's "basic attack-move and target acquisition" criterion is testable. Replace with a real faction encounter once MVP 4/5 AI exists. |
| PLACEHOLDER_hud_panels | Themed Recruitment/Gun Shop/Inspect building UI | Active (MVP 2) | No | `scripts/ui/recruitment_panel.gd`, `gun_shop_panel.gd`, `inspect_panel.gd` are built entirely from generic `Button`/`Label` controls in code, not themed art or a `.tscn` layout. Functionally complete and tested; MVP 6 replaces the visuals. |
| PLACEHOLDER_building_interaction | In-world walk-up building interaction | Active (MVP 2) | No | Recruitment/Gun Shop/Bank are opened via always-visible HUD buttons, not by clicking a building placed in the world (no real buildings exist on this test map yet). Deferred until MVP 3 places actual buildings from `Assets/Game Maps/` in the open world. |
| PLACEHOLDER_explosive_projectile_flight | Visible grenade/RPG flight arc | Active (MVP 2) | No | `WeaponData.is_hitscan = false` triggers a timed delay (distance / projectile speed) before the AoE applies, with no moving visual node — see docs/TECH_DECISIONS.md. The *mechanical* hitscan-vs-projectile distinction is real and tested; only the visual flight is deferred. |
| PLACEHOLDER_region_hq_markers | Functional DEA/Nasion/Vartieri HQ buildings | Active (MVP 3) | No | `open_world_map.gd::_add_region_marker` draws a plain tinted rectangle + label for the DEA, Nasion, and Vartieri HQs (each named with "(PLACEHOLDER)"). They exist purely as world landmarks matching Prompt Dasar's world-structure description; no recruitment/economy/combat function until MVP4 makes those campaigns playable. |
| PLACEHOLDER_dea_responder_visuals | Real DEA unit sprites/identity | Active (MVP 3) | No | DEA response-wave units spawn with `display_name` "DEA Responder (PLACEHOLDER)" / "DEA Commander (PLACEHOLDER)", reusing the same procedural-shape `BwUnit` visuals as the MVP1 dummy squad. Real DEA identity/art arrives with Campaign Nabil in MVP4. |
| PLACEHOLDER_minimap | Rendered minimap texture (e.g. SubViewport-based) | Active (MVP 3) | No | `open_world_map.gd::_draw_minimap` is a schematic `_draw()` of scaled dot positions (units/buildings), not a real rendered top-down view. Functionally correct (proportionally accurate positions) but visually simplified — MVP6 UI polish territory. |
| PLACEHOLDER_alert_log_panel | Themed alert/toast UI | Active (MVP 3) | No | The Alerts panel is a plain scrollable `Label` fed directly from `CombatLog.entries`, not a toast/notification system. |
| PLACEHOLDER_rival_faction_hqs | Functional rival-faction HQs/AI in the same playthrough | Active (MVP 4/5/6) | No | Whichever HQ belongs to the *other* 3 factions in a given playthrough (e.g. Bellarosa/Nasion/DEA when playing as Zie) remains a non-functional landmark marker labeled "(PLACEHOLDER)". MVP5 built the full TACTICAL/STRATEGIC/INFORMATION/AMBUSH/DIPLOMACY AI layers and proved them in a dedicated headless multi-faction arena (`AiMatchArena`). MVP6 built the full "VICTORY DAN DEFEAT" rule (`open_world_map.gd::_check_victory_condition`, Prompt Dasar: all rival MCs dead, +no active cartel factory for Nabil) and covered it with `tests/test_mvp6_victory_defeat.gd` using a fake registered enemy MC — but the live open-world scene still never registers a real one, so the VICTORY outcome (unlike DEFEAT, which fires for real on the player's own MC) cannot yet be reached by actually playing; only DEFEAT is reachable in the live build today. Wiring a real rival faction into the open world is deferred to MVP7. |
| PLACEHOLDER_neutral_faction_identity | Real "Riverside Crew" neutral-faction identity/art | Active (MVP 5) | No | `data/neutral/neutral_riverside_crew.tres` (Prompt Dasar "Neutral encounter"/"Diplomacy") is a small independent local outfit with no dedicated art/sprites of its own yet — the diplomacy system (trust/alliance/trade bonus/betrayal) is fully real and tested, only its visual identity is placeholder. |
| PLACEHOLDER_dea_allied_agent_visuals | Real allied-DEA-agent sprites/identity | Active (MVP 4) | No | Nabil's "Dispatch Allies" spawns units named "Allied DEA Agent", reusing the same procedural-shape `BwUnit` visuals as every other placeholder squad. |
| PLACEHOLDER_ability_bar_ui | Themed ability-bar/HUD art | Active (MVP 4) | No | `ability_bar.gd` is a plain generic `Button` column with tooltip text for description/counterplay, not final art — MVP6 UI polish territory. |
| PLACEHOLDER_ai_debug_overlay_ui | Themed debug-overlay styling | Active (MVP 5) | No | `ai_debug_overlay.gd` is a plain `Label` in a `PanelContainer`, dev-only and release-gated by design (Prompt Dasar explicitly asks for a debug overlay, not final-art UI) — not a gap that needs fixing, just noted for completeness. |
| PLACEHOLDER_mvp6_ui_art | Themed Settings/Save-Load/Victory-Defeat/campaign-card/tutorial-toast art | Active (MVP 6) | No | All MVP6 UI (`settings_panel.gd`, `save_slot_panel.gd`, `victory_defeat_screen.gd`/`.tscn`, `campaign_select.gd` cards, `tutorial_controller.gd` toast, `content_warning.gd`) is built from generic `Control`/`Button`/`Label`/`HSlider`/`TabContainer` nodes, not final themed art. Functionally complete and tested. |
| PLACEHOLDER_audio_content | Real sound effects/music | Active (since MVP 0, explicit in MVP6) | No | MVP6 wires real `Master`/`Music`/`SFX` `AudioServer` buses with working volume sliders (`UserPrefsService`), but nothing in the project plays an `AudioStream` through them yet — there is no sound content to mix. The controls themselves are real and functional, not placeholders; the audio content routed through them is what's still pending. |

The gaps below are **known asset shortages** (not created as placeholder
files yet, since no gameplay currently needs them), tracked here so the
MVP that first needs each one creates the actual placeholder file per
the policy above, instead of rediscovering the gap.

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
