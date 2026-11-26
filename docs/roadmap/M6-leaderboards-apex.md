# M6 — Leaderboards, apex ranks and the Hall of Prestige

**Goal:** the nine leaderboards with their filters, the relays that keep offline profiles alive, the weekly cascade that assigns the 7 × 100 apex seats per category and for the Global, the consensus between clients, the title roll with its reigns, and the cosmetic rewards.

**Exit criterion (in game):** the leaderboard shows "Known profiles" and the player's own position; after a weekly reset two clients agree on the apex seats of a category (consensus); an apex entry plays the cinematic and a dethroning shows a toast (A10); the Hall of Prestige lists current holders and past reigns.

**Release:** `v0.6.0` after M6.12.

| Step | Title | Kind | Model | Effort |
|---|---|---|---|---|
| M6.1 | Specification of leaderboards and apex | specification | Opus | high |
| M6.2 | Leaderboard indices and filters | non-trivial data logic | Opus | medium |
| M6.3 | Relays of offline profiles (`RLY`) | network protocol, security | Opus | high |
| M6.4 | Weekly reset and the apex cascade | non-trivial data logic, security | Opus | high |
| M6.5 | Apex consensus (`LBD`) | network protocol | Opus | high |
| M6.6 | Reigns, title roll and notifications | data migrations | Opus | high |
| M6.7 | Leaderboards tab | UI | Sonnet | medium |
| M6.8 | Hall of Prestige and Hall of the Fallen | UI | Sonnet | medium |
| M6.9 | Rewards: titles, frames, seals | standard features | Sonnet | medium |
| M6.10 | Performance and saved-data size at scale | heavy tests | Sonnet | high |
| M6.11 | M6 in-game checklist | checklist | Sonnet | medium |
| M6.12 | Release preparation `v0.6.0` | release preparation | Sonnet | medium |

### M6.1 — Specification of leaderboards and apex
- Branch: `step/m6-1-spec`
- Model: Opus · high
- Depends on: M5
- Spec: SPEC-02 §6.3-§6.5, SPEC-06 §12.2 (`RLY`, `LBD`), SPEC-07 (all), SPEC-08 §16
- Scope: the leaderboard index structures, the `RLY` and `LBD` layouts and rates, the tie-break, the reset detection, the consensus window, the reign transitions table, the reward list; switches `leaderboards` and `apex`.
- Done when:
  - [ ] Every transition of §13.3 has a test case listed; message sizes are bounded.
- Tests: `check_docs.py`.
- Docs: SPEC-06, SPEC-07, CHANGELOG.
- Real client: nothing.

### M6.2 — Leaderboard indices and filters
- Branch: `step/m6-2-leaderboard`
- Model: Opus · medium
- Depends on: M6.1
- Spec: SPEC-07 §13.1-§13.2
- Scope: `Domain/Leaderboard.lua`: sorted indices per category and Global, filters (scope, faction with the Vanguard default, Hardcore, class, trust, activity), the weekly delta, the player's own position.
- Done when:
  - [ ] Sorting 20 000 profiles stays within the CPU budget; filters compose.
- Tests: `test_leaderboard.lua`.
- Docs: CHANGELOG.
- Real client: nothing.

### M6.3 — Relays of offline profiles
- Branch: `step/m6-3-relays`
- Model: Opus · high
- Depends on: M6.1
- Spec: SPEC-06 §12.4-§12.5
- Scope: `RLY` of offline profiles of value (top, apex holders and past holders, guild), 20 per 10 minutes, `src` 2 and 3, never lowering known data; A7.
- Done when:
  - [ ] A7 passes in the simulator; a single relay never makes a profile apex-eligible.
- Tests: `test_relays.lua`, simulator scenario.
- Docs: CHANGELOG.
- Real client: nothing.

### M6.4 — Weekly reset and the apex cascade
- Branch: `step/m6-4-apex-cascade`
- Model: Opus · high
- Depends on: M6.2
- Spec: SPEC-02 §6.3 (cascade), SPEC-07 §13.3
- Scope: reset detection (`C_DateAndTime.GetSecondsUntilWeeklyReset`, or first login after it), eligibility (`vr`, `src`, flagged, fallen), the cascade from Legend to Master, the Global with thresholds × 4, weekly snapshots.
- Done when:
  - [ ] A10b passes; ties are resolved as §6.3; empty bands are allowed.
- Tests: `test_apex.lua`.
- Docs: CHANGELOG.
- Real client: a weekly reset (checklist).

### M6.5 — Apex consensus
- Branch: `step/m6-5-consensus`
- Model: Opus · high
- Depends on: M6.3, M6.4
- Spec: SPEC-07 §13.3 point 2, SPEC-06 §12.2 (`LBD`)
- Scope: `LBD` digests (63 hashes), majority over the first 24 h, full band download by whisper only when the own hash differs, own result when no digest arrives.
- Done when:
  - [ ] Clients with slightly different profile sets converge in the simulator.
- Tests: `test_consensus.lua`, simulator scenario.
- Docs: SPEC-07 (measured numbers), CHANGELOG.
- Real client: two clients after a reset (checklist).

### M6.6 — Reigns, title roll and notifications
- Branch: `step/m6-6-reigns`
- Model: Opus · high
- Depends on: M6.5
- Spec: SPEC-02 §6.5, SPEC-07 §13.3 point 3-4
- Scope: `apexReigns` opened and closed at each reset, repeated reigns, the "Ex-" seals, the historic best title, the Hall of Prestige store, the cinematic for entries and promotions and the toast for dethronings; Config migration for the new tables.
- Done when:
  - [ ] A10 and A10c pass; migrations keep every reign.
- Tests: `test_reigns.lua`, `test_config.lua` (migration).
- Docs: SPEC-04, CHANGELOG.
- Real client: a cinematic after a reset (checklist).

### M6.7 — Leaderboards tab
- Branch: `step/m6-7-leaderboards-tab`
- Model: Sonnet · medium
- Depends on: M6.2
- Spec: SPEC-07 §13.1-§13.2
- Scope: `UI/LeaderboardView.lua`: the nine leaderboards, filters, columns, header with known profiles and last sync, own row pinned at the bottom.
- Done when:
  - [ ] Every filter works in both languages; a list of 20 000 scrolls smoothly.
- Tests: `test_leaderboard_view.lua`.
- Docs: wiki *Leaderboards* (both languages), previews, CHANGELOG.
- Real client: the tab.

### M6.8 — Hall of Prestige and Hall of the Fallen
- Branch: `step/m6-8-hall`
- Model: Sonnet · medium
- Depends on: M6.6
- Spec: SPEC-07 §13.4-§13.5
- Scope: `UI/HallOfPrestige.lua`: current holders per band ("Aspect 37/100"), Legend of Azeroth, past reigns with durations, search, records; the Hall of the Fallen on Hardcore realms.
- Done when:
  - [ ] Every view shows invented data in the previews and real data in game.
- Tests: `test_hall_view.lua`.
- Docs: wiki *Hall of Prestige* (both languages), previews, CHANGELOG.
- Real client: the tab.

### M6.9 — Rewards: titles, frames, seals
- Branch: `step/m6-9-rewards`
- Model: Sonnet · medium
- Depends on: M6.6
- Spec: SPEC-08 §16 (Q8)
- Scope: profile frames for Gold, Diamond, Dragonite; animated apex frames and the Legend glow (placeholders until M7.6); the selectable Prestige title in the tooltip and profile; "Hero of Azeroth" and "Renaissance".
- Done when:
  - [ ] Every reward of §16 appears when earned and nothing gives a gameplay advantage.
- Tests: `test_rewards.lua`.
- Docs: wiki *Ranks and Rewards* (both languages), CHANGELOG.
- Real client: the visuals.

### M6.10 — Performance and saved-data size at scale
- Branch: `step/m6-10-performance`
- Model: Sonnet · high
- Depends on: M6.9
- Spec: SPEC-01 §17, SPEC-04 §10.3
- Scope: measure CPU, memory and saved-data size with 10 000 and 20 000 profiles and a 30-day ledger in the long tests; fix what exceeds the budget; `/azp stats` reports sizes.
- Done when:
  - [ ] Every budget of §17 and §10.3 holds in the long scenario, with the numbers written in SPEC-01.
- Tests: long scenarios.
- Docs: SPEC-01, SPEC-11 R9, CHANGELOG.
- Real client: memory in a crowded city (checklist).

### M6.11 — M6 in-game checklist
- Branch: `step/m6-11-checklist`
- Model: Sonnet · medium
- Depends on: M6.10
- Scope: `docs/checklists/M6.md`: leaderboards, a weekly reset with two clients, the cinematic and the toast, the Hall, rewards, memory.
- Done when:
  - [ ] The checklist covers the exit criterion and A10-A10c.
- Tests: `check_docs.py`.
- Docs: `docs/checklists/README.md`, CHANGELOG.
- Real client: the owner runs it.

### M6.12 — Release preparation `v0.6.0`
- Branch: `step/m6-12-release-prep`
- Model: Sonnet · medium
- Depends on: M6.11
- Scope: as M1.12, for `0.6.0`; switches `leaderboards` and `apex` on.
- Done when:
  - [ ] Dry run green, zip inspected, changelog section `0.6.0`.
- Tests: the whole suite and the long tests.
- Docs: CHANGELOG, READMEs, wiki *Home*.
- Real client: the zip loads.
