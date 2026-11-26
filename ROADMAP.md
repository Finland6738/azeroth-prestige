# Roadmap

This page is the short version and the rules every step follows. **The development steps of each milestone are in [docs/roadmap/](docs/roadmap/README.md)**, one file per milestone, each with the model and effort of its steps; the behaviour is in the [specification](docs/specs/README.md) (Italian).

## Milestones

| Milestone | Branch prefix | Content | Exit criterion (in game) | Version |
|---|---|---|---|---|
| **[M0 – Spike](docs/roadmap/M0-spike.md)** | `step/m0-…` | A probe addon (never distributed) answers the risky API checks V1-V21: encounters and secret values, nameplates and tooltips, addon messages and the discovery channel, tracker sources, Hardcore | `docs/spike/M0-results.md`, specs and ADRs revised, go / revise per area | — |
| **[M1 – Foundations](docs/roadmap/M1-foundations.md)** | `step/m1-…` | Skeleton (TOC 16001, Ace3, enUS + itIT), offline tests, Compat and Restrictions, Config with schema versions, Ladder, Scoring, Ruleset v1, Ledger, anti-boost, commands | points computed locally survive `/reload`; `/azp stats` in both languages | `v0.1.0` |
| **[M2 – Objective trackers](docs/roadmap/M2-objective-trackers.md)** | `step/m2-…` | Delver, Adventurer, Pathfinder, Artisan, backfill | a dungeon clear, a quest, a flight path, a skill-up counted | `v0.2.0` |
| **[M3 – UI and celebrations](docs/roadmap/M3-ui-celebrations.md)** | `step/m3-…` | The ecosystem look (Prestige, Nebula, Aurora), placeholder badges, window, profile, history, settings, celebration queue | celebrations wait for combat and NPC windows; one combined celebration | `v0.3.0` |
| **[M4 – Network and badges](docs/roadmap/M4-network-badges.md)** | `step/m4-…` | Codec, transport, beacons, profiles, attestations, simulator; badges on tooltip, nameplates, frames, chat, menu | two players see each other's badge; witnessed boss kills | `v0.4.0` (public beta) |
| **[M5 – Social trackers](docs/roadmap/M5-social-trackers.md)** | `step/m5-…` | Vanguard, Merchant, commendations, Diplomat, Prestige Events, Steward, Hardcore memorial | an event rewards organiser and participants; no points between alts | `v0.5.0` |
| **[M6 – Leaderboards and apex](docs/roadmap/M6-leaderboards-apex.md)** | `step/m6-…` | Leaderboards, relays, weekly apex cascade, consensus, reigns, Hall of Prestige, rewards | two clients agree on the apex seats after a reset | `v0.6.0` |
| **[M7 – Extensions](docs/roadmap/M7-extensions-release.md)** | `step/m7-…` | Public API, Prestige Contracts, adapters, guild and friends lists, final art, translation kit, hardening, full release check | the full release checklist passes | `v1.0.0` |

**Versions** ([ADR 0015](docs/adr/0015-one-version-per-milestone.md)): every milestone N from M1 to M6 is released as `v0.N.0`; M7 is released as **`v1.0.0`** (the owner's choice, 2026-11-26); fixes raise only the last number. M0 is a probe and is never released.

## Rules for every step

1. Take the **first unticked step** of the current milestone file and start its branch from an up-to-date `main` (`step/m<N>-<k>-<name>`). One step, one fresh session, one at a time ([ADR 0018](docs/adr/0018-one-fresh-session-per-step.md)).
2. Keep the step small; open an issue for anything outside it.
3. Update in the same branch: `CHANGELOG.md`, the affected specs and ADRs (and the ADR index), `README.md` and `README.it.md` when features or status change, **`docs/wiki/` in both languages for anything a user can see**, and the step's checkboxes with a short *Done* note.
4. Run `python -I -X utf8 tools/check_docs.py` and the whole offline suite (from M1.3). No change without a test.
5. Ship: `python -I -X utf8 tools/ship_step.py --title "M<N>: <summary>" --body-file <pr.md> --commit "<message>"` squashes the step into one noreply commit, pushes, opens the pull request, waits for CI and fast-forwards `main` ([ADR 0007](docs/adr/0007-git-flow-and-automated-shipping.md)). Never `gh pr merge`, never a merge from the GitHub web interface. The wiki is published automatically after the merge.
6. The pull request says honestly what was **not** verified in the real client.
7. Each milestone opens with its specification step and closes with its in-game checklist and a release-preparation step; no half-finished feature ships ([ADR 0017](docs/adr/0017-feature-switches.md)).
