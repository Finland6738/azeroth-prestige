# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- M0.1: **the probe specification** ([docs/spike/README.md](docs/spike/README.md)). For each check V1-V21 of [SPEC-01 §3.3](docs/specs/SPEC-01-platform-architecture.md), and for the content levels of risk R13: the exact calls and events, checked against the WoW Forever API dump (build 70170) with the names it does not list marked; where to run it (open world, combat, dungeon, boss, raid, battleground, two clients, Hardcore); the go and revise criteria; the specs and ADRs each outcome changes. The checks are grouped by the probe areas of steps M0.3-M0.7; the file also gives the probe's safety rules, the commands `/azpp list|run <id>|export|reset` and the record format `{id, result, details, build, time}`. SPEC-01 §3.3 links to it. No probe code yet (step M0.2).
- M0.0: **the bootstrap of the repository** ([M0](docs/roadmap/M0-spike.md)). No addon code yet: the specification, the decisions, the plan and the tooling every later step uses.
  - The technical specification v0.4 split into SPEC-00 to SPEC-11 in Italian, keeping its § numbers, with the owner's answers of 2026-11-26 in the decision register (D-42 to D-46): licences, versions (`v1.0.0` after M7), integrations (only a public read-only API), multilingual interface (English by default, Italian), the ecosystem look. Risks R1-R14 and open questions Q1-Q21, each with a proposed answer and the one place where it changes ([SPEC-11](docs/specs/SPEC-11-risks-open-questions.md)).
  - ADRs 0001-0019 ([index](docs/adr/README.md)): client-only peer-to-peer design, Forever target, points recomputed from events, trust without a server, the protocol, Ace3 and schema versions, git flow and shipping, wiki, CI rules, languages, offline tests, licensing, reuse of Accord and Unspoken, design previews, one version per milestone, ecosystem style, feature switches, one fresh session per step, integrations.
  - The roadmap M0-M7 with 90 steps, each with branch, spec, scope, checks, what only the real client can confirm, and the model and effort of its session ([roadmap](docs/roadmap/README.md)).
  - Tooling adapted from Azeroth Accord: `tools/check_docs.py` (now also the owner's real names listed in the git-ignored `tools/local.ini`, the git identity and the private notes), `check_pr_docs.py`, `ship_step.py` (without an option to skip the tests), `release_notes.py`, `sync_wiki.py`; the workflows CI, Docs rule, Long tests, Release, Wiki sync and DCO; the issue and pull request templates.
  - Licences: code GPL-3.0-or-later, documentation CC BY 4.0, artwork and sounds all rights reserved ([LICENSING.md](LICENSING.md), [LICENSE-CONTENT.md](LICENSE-CONTENT.md)).
  - The logo source in `assets/`, the READMEs in English and Italian, the wiki *Home* and *About* in both languages.
