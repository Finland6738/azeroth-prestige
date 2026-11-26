# M3 — Interface and celebrations

**Goal:** the window of the addon in the look of the owner's addon family, with placeholder badges, the profile at three levels, the readable history, the settings, and the celebration queue with all its blocking conditions.

**Exit criterion (in game):** `/prestige` opens the window with the Profile, History and Settings tabs in the Prestige theme (and in Nebula and Aurora); a promotion during combat or with an NPC window open is celebrated only afterwards (A3, A4); three promotions at once give one combined celebration with the Global first (A5); skip works after 2 s; the boost indicator shows on the minimap button while BOOSTED.

**Release:** `v0.3.0` after M3.12.

| Step | Title | Kind | Model | Effort |
|---|---|---|---|---|
| M3.1 | Specification of the interface (`ui-style.md`) | specification | Opus | high |
| M3.2 | Theme, assets, motion and widgets from Accord | standard on existing foundations | Sonnet | medium |
| M3.3 | Placeholder badges and emblems | standard tooling | Sonnet | medium |
| M3.4 | Main window, minimap, compartment, boost indicator, About | UI | Sonnet | medium |
| M3.5 | Profile view, three levels | UI | Sonnet | medium |
| M3.6 | History view | UI | Sonnet | medium |
| M3.7 | Settings, accessibility options | UI | Sonnet | medium |
| M3.8 | Celebration queue and blocking conditions | many edge cases | Sonnet | high |
| M3.9 | Celebration renderers, skip and sounds | UI, protected input | Opus | high |
| M3.10 | Design previews and wiki pictures | documentation tooling | Sonnet | medium |
| M3.11 | M3 in-game checklist | checklist | Sonnet | low |
| M3.12 | Release preparation `v0.3.0` | release preparation | Sonnet | medium |

### M3.1 — Specification of the interface
- Branch: `step/m3-1-spec`
- Model: Opus · high
- Depends on: M2
- Spec: SPEC-08 §14, SPEC-09 §15, ADR 0014, 0016; Accord's `docs/specs/ui-style.md` (read only)
- Scope: `docs/specs/ui-style.md` (Italian): only the differences from Accord's: names and prefixes, the Prestige theme's colour tokens from the logo, the window layout (~820×560) and its tabs, badge sizes, the celebration panel and cinematic layers, accessibility (high contrast, reduce effects); views and switches of M3 (`ui`, `celebrations`); Q3-Q7 and Q14 applied as proposed.
- Done when:
  - [ ] Every view of M3 is laid out; the theme tokens are listed; every setting of §14.6 that M3 delivers is named.
- Tests: `check_docs.py`.
- Docs: `ui-style.md`, SPEC-08, SPEC-09, specs index, CHANGELOG.
- Real client: nothing.

### M3.2 — Theme, assets, motion and widgets from Accord
- Branch: `step/m3-2-theme-widgets`
- Model: Sonnet · medium
- Depends on: M3.1
- Spec: ADR 0016, `ui-style.md`
- Scope: copy and rename `UI/Theme.lua` (Nebula, Aurora, Prestige; `DEFAULT_THEME`), `UI/Assets.lua`, `UI/Motion.lua`, `UI/Widgets/*`, `tools/make_media.py` (logo `logo_64`/`logo_256` from `assets/logo-source.png`, shapes, icons), `tools/make_fonts.py` and the three font families with their licences; `AzerothPrestige/Media/NOTICE.md` (ADR 0012); `docs/third-party.md` rows.
- Done when:
  - [ ] Switching theme needs no `/reload`; no colour outside `UI/Theme.lua` (`check_addon.py`).
- Tests: `test_theme.lua`, `test_widgets.lua`, a media check (every file listed, every font with its licence).
- Docs: `docs/third-party.md`, CHANGELOG.
- Real client: fonts and textures render.

### M3.3 — Placeholder badges and emblems
- Branch: `step/m3-3-placeholder-badges`
- Model: Sonnet · medium
- Depends on: M3.2
- Spec: SPEC-08 §14.5, §14.7 (placeholders)
- Scope: `tools/make_badges.py`: shield per tier in its palette colour with the tier initial, star per apex, 1-4 pips for divisions, "Ex-apex" seals, 9 emblems, 64×64 and 16×16 `.tga`; `Badges/Provider.lua` (texture, coordinates and label for a rank, high-contrast variant).
- Done when:
  - [ ] Every rank, division, seal and emblem has a texture; silhouettes differ in greyscale.
- Tests: `test_badges_provider.lua`, a check that every texture file exists.
- Docs: `docs/third-party.md` (drawn by the project's tool), CHANGELOG.
- Real client: readability at 16 px.

### M3.4 — Main window, minimap, compartment, boost indicator, About
- Branch: `step/m3-4-main-window`
- Model: Sonnet · medium
- Depends on: M3.3
- Spec: SPEC-08 §14.1, §14.8
- Scope: `UI/MainFrame.lua` (window, title bar with logo, tabs), `UI/Minimap.lua` (LibDBIcon, LDB broker), the addon compartment, the boost indicator and toast with reasons, `UI/About.lua` (credits per Q14, licences), `/prestige` toggles the window.
- Done when:
  - [ ] The window opens, moves, remembers its position; the boost indicator follows the BOOSTED state with its tooltip.
- Tests: `test_ui_shell.lua`, `test_boost_indicator.lua`.
- Docs: wiki *Interface Tour*, *About* (both languages), CHANGELOG.
- Real client: the window and the minimap button.

### M3.5 — Profile view, three levels
- Branch: `step/m3-5-profile`
- Model: Sonnet · medium
- Depends on: M3.4
- Spec: SPEC-08 §14.2 (Q3)
- Scope: `UI/ProfileView.lua`: Overview (Global badge, 8 categories with progress bars, `vr` placeholder until M4), Category Details (rank timeline, PP to the next division and to the apex threshold), the title roll (empty until M6), Statistics (counters per rule).
- Done when:
  - [ ] Every level shows the local character's data in both languages and all themes.
- Tests: `test_profile_view.lua`.
- Docs: wiki *Profile* (both languages), CHANGELOG.
- Real client: the profile.

### M3.6 — History view
- Branch: `step/m3-6-history`
- Model: Sonnet · medium
- Depends on: M3.4
- Spec: SPEC-08 §14.1 (Cronologia), §14.8
- Scope: `UI/HistoryView.lua`: the ledger with filters per category, the rule explained, PP, voided events struck through with their reason (`BOOST:G`, `ALT`), compacted totals.
- Done when:
  - [ ] A ledger of 5 000 events scrolls without stalls (pooled rows).
- Tests: `test_history_view.lua`.
- Docs: wiki *History* (both languages), CHANGELOG.
- Real client: scrolling.

### M3.7 — Settings, accessibility options
- Branch: `step/m3-7-settings`
- Model: Sonnet · medium
- Depends on: M3.4
- Spec: SPEC-08 §14.6 (the parts of M3), §18
- Scope: `UI/Settings.lua` in the window and in the game's settings (`Settings.RegisterCanvasLayoutCategory`): appearance (theme, font, animations), celebrations (duration 3-15 s, skip, blocking conditions, preview), sounds, accessibility (high contrast, reduce effects), debug; settings saved with a Config migration if needed.
- Done when:
  - [ ] Every setting changes behaviour without `/reload`; defaults match the spec.
- Tests: `test_settings.lua`.
- Docs: wiki *Settings* (both languages), CHANGELOG.
- Real client: the game's settings window.

### M3.8 — Celebration queue and blocking conditions
- Branch: `step/m3-8-celebration-queue`
- Model: Sonnet · high
- Depends on: M3.4
- Spec: SPEC-09 §15.2-§15.3 (Q4, Q6, Q7)
- Scope: `Celebrations/Queue.lua` (the state machine IDLE, QUEUED, WAITING, PLAYING, SUSPENDED; combining within 3 s; persistence in `celebrationQueue`; older than 24 h → one toast), `Celebrations/Conditions.lua` (combat, encounter, NPC interaction, blocking panels, map → suspend, automatic transports, cinematics, loading screens, dead or ghost).
- Done when:
  - [ ] Every transition of the state machine is tested; A3, A4, A5 pass offline.
- Tests: `test_celebration_queue.lua`.
- Docs: SPEC-09 if anything changed, CHANGELOG.
- Real client: each blocking condition (checklist).

### M3.9 — Celebration renderers, skip and sounds
- Branch: `step/m3-9-celebration-render`
- Model: Opus · high
- Depends on: M3.8
- Spec: SPEC-09 §15.4, SPEC-08 §18 (reduce effects)
- Scope: `Celebrations/PanelView.lua` (420×260 panel, timings of §15.4), `Celebrations/CinematicView.lua` (`FULLSCREEN_DIALOG`, dimmed background), skip after 2 s with an `OnKeyDown` frame that propagates every key but ESC and is active only out of combat (`SetPropagateKeyboardInput`), `Celebrations/Sounds.lua` (two sets, audio channel; placeholder `.ogg` made by the project or none), `/azp celebrate test <tier>`.
- Done when:
  - [ ] Skip never swallows a key other than ESC and never runs in combat; reduce effects removes particles and flashes.
- Tests: `test_celebration_views.lua`.
- Docs: wiki *Celebrations* (both languages), CHANGELOG.
- Real client: keyboard propagation, full-screen layer, sounds.

### M3.10 — Design previews and wiki pictures
- Branch: `step/m3-10-previews`
- Model: Sonnet · medium
- Depends on: M3.5-M3.9
- Spec: ADR 0014
- Scope: `tools/mockup_lib.py`, `tools/make_mockups.py` adapted from Accord and Unspoken: previews of the window, profile, history, settings, a panel and a cinematic celebration, in English and Italian, invented data; `check_docs.py` runs its check; README and wiki show them.
- Done when:
  - [ ] Every preview is up to date (`check_docs.py`) and every wiki page with a picture has its Italian twin with the same picture name.
- Tests: `check_docs.py`.
- Docs: READMEs, wiki, CHANGELOG.
- Real client: nothing.

### M3.11 — M3 in-game checklist
- Branch: `step/m3-11-checklist`
- Model: Sonnet · low
- Depends on: M3.10
- Scope: `docs/checklists/M3.md`: window, themes, profile, history, settings, every blocking condition, skip, sounds, boost indicator.
- Done when:
  - [ ] The checklist covers the exit criterion and the "real client" items of M3.
- Tests: `check_docs.py`.
- Docs: `docs/checklists/README.md`, CHANGELOG.
- Real client: the owner runs it.

### M3.12 — Release preparation `v0.3.0`
- Branch: `step/m3-12-release-prep`
- Model: Sonnet · medium
- Depends on: M3.11
- Scope: as M1.12, for `0.3.0`; switches `ui` and `celebrations` on.
- Done when:
  - [ ] Dry run green, zip inspected (fonts and media with `NOTICE.md`), changelog section `0.3.0`.
- Tests: the whole suite.
- Docs: CHANGELOG, READMEs, wiki *Home*.
- Real client: the zip loads.
