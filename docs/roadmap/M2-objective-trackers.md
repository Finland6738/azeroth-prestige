# M2 — Objective trackers: Delver, Adventurer, Pathfinder, Artisan

**Goal:** the four categories whose events the game itself confirms, each with its tracker behind its switch, plus the one-time backfill at the first install.

**Exit criterion (in game):** a full dungeon clear in a group gives the Delver points of §7.2 to every member with the addon (A1, A12 without witnesses yet); a quest turn-in, a new flight path, a new sub-zone and a skill-up add their rules; a character already advanced gets its backfill with a single "Welcome" message; nothing is counted while BOOSTED.

**Release:** `v0.2.0` after M2.10.

| Step | Title | Kind | Model | Effort |
|---|---|---|---|---|
| M2.1 | Specification of the trackers (after M0) | specification | Opus | high |
| M2.2 | Tracker framework and content tables | non-trivial data logic | Opus | medium |
| M2.3 | Delver | many edge cases | Sonnet | high |
| M2.4 | Adventurer | many edge cases | Sonnet | high |
| M2.5 | Pathfinder | many edge cases | Sonnet | high |
| M2.6 | Artisan (own crafting) | many edge cases | Sonnet | high |
| M2.7 | Backfill | non-trivial data logic | Opus | medium |
| M2.8 | Switches on and `/azp stats` per category | standard | Sonnet | medium |
| M2.9 | M2 in-game checklist | checklist | Sonnet | low |
| M2.10 | Release preparation `v0.2.0` | release preparation | Sonnet | medium |

### M2.1 — Specification of the trackers
- Branch: `step/m2-1-spec`
- Model: Opus · high
- Depends on: M1, M0.9 (the results; if M0 is not done, the step writes the assumptions and marks them)
- Spec: SPEC-03 §7.2-§7.6, §7.9; SPEC-02 §8.3-§8.7; `docs/spike/M0-results.md`
- Scope: for each of the four categories, the final event sources, the eligibility rules (AFK, ≥ 50% of the encounter, same instance), the context keys, the anti-boost hooks; the source of content levels (risk R13) and the shape of `Data/Encounters.lua`, `Quests.lua`, `Zones.lua`, `Secrets.lua`; switches `delver`, `adventurer`, `pathfinder`, `artisan`, `backfill`.
- Done when:
  - [ ] Every rule of the four categories has a source confirmed by M0 or a marked assumption; the content tables are specified.
- Tests: `check_docs.py`.
- Docs: SPEC-03, SPEC-01, SPEC-11, CHANGELOG.
- Real client: nothing.

### M2.2 — Tracker framework and content tables
- Branch: `step/m2-2-tracker-framework`
- Model: Opus · medium
- Depends on: M2.1
- Spec: SPEC-03 conventions, SPEC-02 §8.3, §8.5
- Scope: `Trackers/Base.lua` (build a `PrestigeEvent` with context `pl`, `gmx`, `l`; eligibility; anti-alt hook for counterparties in `myChars`; hand-off to the Ledger), the content tables of M2.1 with their generator or curation notes (no data copied from third-party databases), the mock events they need.
- Done when:
  - [ ] An event built by the framework reaches the ledger with its context and is voided when BOOSTED.
- Tests: `test_trackers_base.lua`, mock additions.
- Docs: CHANGELOG.
- Real client: nothing.

### M2.3 — Delver
- Branch: `step/m2-3-delver`
- Model: Sonnet · high
- Depends on: M2.2
- Spec: SPEC-03 §7.2, SPEC-02 §8.6.2 (encounters, clears)
- Scope: `Trackers/Delver.lua` behind `delver`: `DEL_BOSS`, `DEL_BOSS_RAID`, `DEL_FIRST_KILL`, `DEL_CLEAR`, `DEL_FULL_CLEAR`, `DEL_FIRST_FULL_CLEAR`, `DEL_PROGRESS`, `DEL_WIPE_LEARN`; run tracking per instance; presence ≥ 50%; clears voided if a boss of the run was boosted.
- Done when:
  - [ ] The worked example of §7.2 (550 PP, then the first-time bonuses) passes; A1 (local part), A2, A12 pass.
- Tests: `test_delver.lua`.
- Docs: wiki *Categories* (both languages: Delver), CHANGELOG.
- Real client: a dungeon and a raid run (M2 checklist).

### M2.4 — Adventurer
- Branch: `step/m2-4-adventurer`
- Model: Sonnet · high
- Depends on: M2.2
- Spec: SPEC-03 §7.4, SPEC-02 §8.6.2 (quests, reputation)
- Scope: `Trackers/Adventurer.lua` behind `adventurer`: `ADV_QUEST`, `ADV_QUEST_ELITE`, `ADV_STORY`, `ADV_REP_STANDING`, `ADV_LEGACY` (only if M0 found the Legacy API); daily and repeatable quests; quest-progress boost flags.
- Done when:
  - [ ] A15 passes; accept/abandon gives nothing; a boosted objective voids the turn-in.
- Tests: `test_adventurer.lua`.
- Docs: wiki *Categories* (Adventurer), CHANGELOG.
- Real client: quests and reputation (checklist).

### M2.5 — Pathfinder
- Branch: `step/m2-5-pathfinder`
- Model: Sonnet · high
- Depends on: M2.2
- Spec: SPEC-03 §7.3, SPEC-01 §17 (polling budget)
- Scope: `Trackers/Pathfinder.lua` behind `pathfinder`: `PAT_AREA`, `PAT_ZONE_FULL`, `PAT_FLIGHT`, `PAT_SECRET` (1 Hz polling only outside instances and near a secret), `PAT_LEGACY`, `PAT_CONTINENT`; `Data/Secrets.lua` with a first curated set.
- Done when:
  - [ ] Every rule is one-time; crossing a border back and forth gives nothing; polling stops in instances.
- Tests: `test_pathfinder.lua`.
- Docs: wiki *Categories* (Pathfinder), CHANGELOG.
- Real client: discoveries and flight paths (checklist).

### M2.6 — Artisan (own crafting)
- Branch: `step/m2-6-artisan`
- Model: Sonnet · high
- Depends on: M2.2
- Spec: SPEC-03 §7.6 (without `ART_CRAFT_FOR_OTHER`, which needs trades: M5.3)
- Scope: `Trackers/Artisan.lua` behind `artisan`: `ART_SKILL`, `ART_SKILL_MAX`, `ART_RECIPE`, `ART_RECIPE_RARE`, `ART_FIRST_CRAFT`, `ART_CRAFT` with DR and the daily cap.
- Done when:
  - [ ] DR and cap apply only to `ART_CRAFT`; skill points are counted once.
- Tests: `test_artisan.lua`.
- Docs: wiki *Categories* (Artisan), CHANGELOG.
- Real client: skill-ups, recipes, crafts (checklist).

### M2.7 — Backfill
- Branch: `step/m2-7-backfill`
- Model: Opus · medium
- Depends on: M2.3-M2.6
- Spec: SPEC-03 §7.9
- Scope: `Trackers/Backfill.lua` behind `backfill`: at the first start on a character, import what the server can confirm (completed quests, reputations, skills and recipes, flight paths, exploration, lifetime HK counter saved for M5, Legacy) as `BACKFILL` events at 100%, `tl = 2`; one combined welcome message; spread over frames to stay inside the login budget of §17.
- Done when:
  - [ ] A second start imports nothing; boss kills and social events are never backfilled.
- Tests: `test_backfill.lua` (a large character, timing budget).
- Docs: wiki *Getting Started* (both languages), CHANGELOG.
- Real client: an advanced character (checklist).

### M2.8 — Switches on and `/azp stats` per category
- Branch: `step/m2-8-switches-on`
- Model: Sonnet · medium
- Depends on: M2.7
- Scope: turn on `delver`, `adventurer`, `pathfinder`, `artisan`, `backfill`; `/azp stats <category>` with the last events; README and wiki status.
- Done when:
  - [ ] `test_features.lua` proves the M2 switches on and the later ones off.
- Tests: the whole suite.
- Docs: READMEs, wiki, CHANGELOG.
- Real client: the checklist.

### M2.9 — M2 in-game checklist
- Branch: `step/m2-9-checklist`
- Model: Sonnet · low
- Depends on: M2.8
- Scope: `docs/checklists/M2.md`: dungeon and raid runs, quests, exploration, professions, backfill, a boosted run.
- Done when:
  - [ ] The checklist covers the exit criterion and the "real client" items of M2.
- Tests: `check_docs.py`.
- Docs: `docs/checklists/README.md`, CHANGELOG.
- Real client: the owner runs it.

### M2.10 — Release preparation `v0.2.0`
- Branch: `step/m2-10-release-prep`
- Model: Sonnet · medium
- Depends on: M2.9
- Scope: as M1.12, for `0.2.0`.
- Done when:
  - [ ] Dry run green, zip inspected, changelog section `0.2.0`.
- Tests: the whole suite.
- Docs: CHANGELOG, READMEs, wiki *Home*.
- Real client: the zip loads.
