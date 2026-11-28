# M1 — Foundations: points computed locally

**Goal:** the addon skeleton and the pure core of the scoring: ladder, rulesets, ledger, anti-boost, saved data with schema versions, all tested offline, with English and Italian from the first string.

**Exit criterion (in game):** the addon loads on Forever without errors; `/azp sim DEL_BOSS 5` (debug mode) adds five events to the ledger that survive `/reload` without duplicates; `/azp stats` shows the points, the rank of each category and the Global Prestige computed from them; in an Italian client the commands answer in Italian.

**Release:** `v0.1.0` after M1.12 (commands only, no window yet).

| Step | Title | Kind | Model | Effort |
|---|---|---|---|---|
| M1.1 | Specification of the foundations | specification, architecture | Opus | high |
| M1.2 | Addon skeleton, libraries, locales, package checks | standard on existing foundations | Sonnet | medium |
| M1.3 | Offline test harness and mock client | heavy tests | Sonnet | high |
| M1.4 | Compat, Restrictions, Log, EventBus, Scheduler | secret values, protected APIs | Opus | high |
| M1.5 | Config: SavedVariables, schema 1, migrations, own characters | data migrations | Opus | high |
| M1.6 | Ladder and Scoring | non-trivial data logic | Opus | medium |
| M1.7 | Ruleset v1 and versioning | non-trivial data logic | Opus | medium |
| M1.8 | Ledger: idempotency, compaction, recompute | data integrity | Opus | high |
| M1.9 | Boost: the anti-boost and low-level rules | security, many edge cases | Opus | high |
| M1.10 | Commands and diagnostics | standard features | Sonnet | medium |
| M1.11 | M1 in-game checklist | checklist | Sonnet | low |
| M1.12 | Release preparation `v0.1.0` | release preparation | Sonnet | medium |

### M1.1 — Specification of the foundations
- Branch: `step/m1-1-spec`
- Model: Opus · high
- Depends on: the bootstrap (M0 may still be running)
- Spec: SPEC-01 §9, SPEC-02, SPEC-04, SPEC-05 §11.2, the ADRs 0003, 0006, 0010, 0011, 0017
- Scope: in SPEC-01 and SPEC-04 (Italian): the module list of M1 with their public functions and the events of the internal bus; the exact shape of `AzerothPrestigeDB` and `AzerothPrestigeCharDB` schema 1 and the migration contract; the ruleset file format (`rules[ruleId] = { cat, points = function(ctx), once, family, window, cap }`), the `eventId` hash and its time bucket; the feature switches of M1 (none visible yet) and of later milestones; the locale key naming; which Accord files are copied (Compat, Config, Bus, Hash, Diagnostics, the test harness) and what changes in each.
- Done when:
  - [x] Every module of M1.2-M1.10 has its interface written; schema 1 is complete; the ruleset format is fixed.
  - [x] Open questions that block M1 are in SPEC-11 with a proposal.
  - *Done:* SPEC-01 §9.7-§9.11 (module interfaces, load order and life cycle, bus events, feature switches, locale keys, the files copied from Accord) and SPEC-04 §10 (schema 1 of both variables, compaction, the ledger event, `eventId`, the migration contract, the ruleset format and the exact scoring chain); new questions Q22 (debug mode and `/azp sim`) and Q23 (start of the week of the caps); ADR 0006 updated (AceDB not loaded). Parts that depend on the probe are marked 🔍. No code.
- Tests: `check_docs.py`.
- Docs: SPEC-01, SPEC-04, SPEC-11, CHANGELOG.
- Real client: nothing.

### M1.2 — Addon skeleton, libraries, locales, package checks
- Branch: `step/m1-2-skeleton`
- Model: Sonnet · medium
- Depends on: M1.1
- Spec: SPEC-01 §9.3-§9.6, ADR 0002, 0006, 0010
- Scope: `AzerothPrestige/AzerothPrestige.toc` (Interface 16001, `Notes-itIT`, SavedVariables, `IconTexture` placeholder until M3.2, `X-License`), `embeds.xml`, `Core/Init.lua` (addon object, Forever check, `/prestige` and `/azp` with help), `Core/Features.lua`, `Locales/enUS.lua` and `Locales/itIT.lua` with the same keys; `tools/fetch_libs.py`, `tools/install_addon.py`, `tools/check_addon.py` (TOC fields, file list, locale keys in both tables), `tools/check_package.py` (what `.pkgmeta` ships: `LICENSE`, `LICENSING.md`, `LICENSE-CONTENT.md` in, development files out), all adapted from Accord.
- Done when:
  - [ ] `check_docs.py` runs `check_addon` and `check_package` and both pass.
  - [ ] `/azp help` lists the commands in English and Italian. *(in game)*
- Tests: the Python checks; the first Lua tests arrive with M1.3.
- Docs: README status, CONTRIBUTING (install for developers), wiki *Installation* and *Commands* (both languages), CHANGELOG.
- Real client: loading on Forever, the TOC name.

### M1.3 — Offline test harness and mock client
- Branch: `step/m1-3-test-harness`
- Model: Sonnet · high
- Depends on: M1.2
- Spec: ADR 0011, SPEC-10 §20.1
- Scope: `Tests/run_tests.py`, `Tests/lib/` (assert, harness), `Tests/mock/` (core, clock, frames, timers, chat and addon messages with lockdown, group, client info, encoding, secret values) adapted from Accord; `/reload` simulation; `Tests/test_addon.lua`, `Tests/test_locales.lua` (ADR 0010 point 7), `Tests/test_features.lua`.
- Done when:
  - [ ] `python -X utf8 Tests/run_tests.py` runs locally and in CI, and the CI job installs lupa and fetches the libraries.
  - [ ] The locale test fails on a missing key, a placeholder mismatch or an unknown key (proved by its own cases).
- Tests: the above.
- Docs: CONTRIBUTING §4, CHANGELOG.
- Real client: nothing.

### M1.4 — Compat, Restrictions, Log, EventBus, Scheduler
- Branch: `step/m1-4-core`
- Model: Opus · high
- Depends on: M1.3
- Spec: SPEC-01 §3.2, §9.2 (`Core`, `Restrictions`), §9.6
- Scope: `Core/Compat.lua` (every game API through one place, `pcall` on 🔍 APIs, the dump checked), `Core/Restrictions.lua` (combat, encounter, chat lockdown, restricted map, trial; `SafeGet(fn, ...)` with `issecretvalue`/`canaccessvalue` returning `nil`), `Core/Log.lua`, `Core/EventBus.lua` (internal pub/sub), `Core/Scheduler.lua` (`C_Timer` only, no permanent `OnUpdate`).
- Done when:
  - [ ] A secret value never raises: every accessor returns `nil` and the caller skips.
  - [ ] Restrictions state changes are published on the bus.
- Tests: `test_compat.lua`, `test_restrictions.lua` (secret values, lockdown, trial), `test_bus.lua`.
- Docs: SPEC-01 if anything changed, CHANGELOG.
- Real client: secret values and lockdown states (in the M1 checklist).

### M1.5 — Config: SavedVariables, schema 1, migrations, own characters
- Branch: `step/m1-5-config`
- Model: Opus · high
- Depends on: M1.4
- Spec: SPEC-04 §10.1-§10.2, ADR 0006, SPEC-02 §8.5 (`myChars`)
- Scope: `Core/Config.lua`: defaults, schema 1 of both variables, the migration runner, read-only mode for a newer schema, `charKey` (`Name-NormalizedRealm`) and GUID, registration in `myChars` at login.
- Done when:
  - [ ] A fresh install, a `/reload`, an older schema (fake 0) and a newer schema (fake 99, read-only) behave as specified.
  - [ ] `myChars` lists every character of the account that logged in.
- Tests: `test_config.lua` with the `/reload` simulation.
- Docs: SPEC-04, CHANGELOG.
- Real client: account-wide variables shared by characters of the same account.

### M1.6 — Ladder and Scoring
- Branch: `step/m1-6-ladder-scoring`
- Model: Opus · medium
- Depends on: M1.3
- Spec: SPEC-02 §6.3-§6.5, §8.1-§8.2, §8.7
- Scope: `Data/Ladder.lua` (22 tiers × 4 divisions from the formula, the 7 apex thresholds, Global × 4; Q2, Q11), `Domain/Scoring.lua` (pure: rank from PP, PP to the next division, GP with the variety bonus, DR multipliers, cap remaining, the low-level divisor, `floor`).
- Done when:
  - [ ] The thresholds equal the table of §6.3 (all 88 values) and the Global ones are × 4.
  - [ ] The examples of §6.4 and §8.7 and the cases A12, A14, A15b, A16 pass.
- Tests: `test_ladder.lua`, `test_scoring.lua`.
- Docs: SPEC-02 if anything changed, CHANGELOG.
- Real client: nothing.

### M1.7 — Ruleset v1 and versioning
- Branch: `step/m1-7-ruleset`
- Model: Opus · medium
- Depends on: M1.6
- Spec: SPEC-02 §8.1, SPEC-03 §7 (all rule ids), ADR 0003
- Scope: `Data/Ruleset_v1.lua` with every `ruleId` of SPEC-03 (points functions, one-time flags, families with DR and caps, windows), `APEX_MIN_VR` (Q10); `Domain/Ruleset.lua` (lookup by `rv`, unknown rule → 0 and logged); a test that every rule of SPEC-03 exists.
- Done when:
  - [ ] Every rule id of SPEC-03 is in the ruleset with its values; DR and caps only on the families of §8.2.
  - [ ] An event with `rv = 1` gives the same points whatever newer ruleset is loaded.
- Tests: `test_ruleset.lua`.
- Docs: SPEC-03 if a value was unclear, CHANGELOG.
- Real client: nothing.

### M1.8 — Ledger: idempotency, compaction, recompute
- Branch: `step/m1-8-ledger`
- Model: Opus · high
- Depends on: M1.5, M1.7
- Spec: SPEC-02 §8.4, SPEC-04 §10.1, §10.3, SPEC-05 §11.2
- Scope: `Domain/Ledger.lua`: append with `eventId` (hash, 60 s bucket, one-time keys without time), duplicates dropped, `oneTime` set, day and week caps, compaction of events older than 30 days or beyond 5 000 into `compact`, full recompute from ledger plus `compact`, `peak` never decreasing, a digest for the network (M4), the promotion events on the bus.
- Done when:
  - [ ] A2 (no duplicate after `/reload`) and A12 pass; compaction keeps totals identical.
  - [ ] Points and peaks never go down across recompute, compaction and migration.
- Tests: `test_ledger.lua` (thousands of events, compaction, recompute, promotions).
- Docs: SPEC-04, CHANGELOG.
- Real client: nothing.

### M1.9 — Boost: the anti-boost and low-level rules
- Branch: `step/m1-9-boost`
- Model: Opus · high
- Depends on: M1.4, M1.8
- Spec: SPEC-02 §8.6 (all), §8.7
- Scope: `Domain/Boost.lua`: the BOOSTED state with trigger G (group levels, `-1` as +10), A1-A4 as hooks fed by Compat (A1/A2 scan at 2 Hz only in combat, outside instances, player level ≤ 50), the 60 s window (Q12), voiding per event kind (§8.6.2), the quest-progress flags, `why = "BOOST:G"`; one-time events consumed (Q13); the context fields `pl` and `gmx` on every event.
- Done when:
  - [ ] A15, A16, A17, A18, A19 pass offline.
  - [ ] A player of level 51 or more is never BOOSTED.
- Tests: `test_boost.lua`.
- Docs: SPEC-02 if anything changed, CHANGELOG.
- Real client: A1-A3 detection (M1 checklist).

### M1.10 — Commands and diagnostics
- Branch: `step/m1-10-commands`
- Model: Sonnet · medium
- Depends on: M1.9
- Spec: SPEC-10 §20.2, SPEC-01 §9.6
- Scope: `/azp stats` (points, rank and next division per category, GP, ledger size), `/azp debug` (copy box with version, client, locale, realm type, restrictions, sizes, last errors; no names), `/azp sim <ruleId> [n]` only in debug mode (events with `tl = 0`, never sent), `Core/Diagnostics.lua` adapted from Accord.
- Done when:
  - [ ] Every command answers in English and Italian; `sim` is refused outside debug mode.
- Tests: `test_commands.lua`, `test_diagnostics.lua`.
- Docs: wiki *Commands* (both languages), CHANGELOG.
- Real client: the commands in game.

### M1.11 — M1 in-game checklist
- Branch: `step/m1-11-checklist`
- Model: Sonnet · low
- Depends on: M1.10
- Scope: `docs/checklists/M1.md`: load, `/azp help` in both languages, `sim` and `/reload`, `stats`, a group with a higher-level player (BOOSTED), the secret-value and lockdown states seen in `/azp debug`.
- Done when:
  - [ ] The checklist covers the exit criterion and the "real client" items of M1.2-M1.10.
- Tests: `check_docs.py`.
- Docs: `docs/checklists/README.md`, CHANGELOG.
- Real client: the owner runs it.

### M1.12 — Release preparation `v0.1.0`
- Branch: `step/m1-12-release-prep`
- Model: Sonnet · medium
- Depends on: M1.11
- Scope: switches of later milestones off; `python -I -X utf8 tools/release_notes.py --promote 0.1.0`; status in both READMEs and the wiki *Home*; Release workflow dry run (Actions → Release → Run workflow) and its zip inspected. After the merge, the coordinator tags `v0.1.0` (annotated, noreply), pushes it, and checks the GitHub Release and the zip.
- Done when:
  - [ ] The dry run is green and the zip holds only the addon, its libraries and the licence files.
  - [ ] The changelog section `0.1.0` exists.
- Tests: the whole suite.
- Docs: CHANGELOG, READMEs, wiki *Home*.
- Real client: the zip installs and loads (in the checklist).
