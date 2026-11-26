# Contributing to Azeroth Prestige

Thank you for your interest! This guide explains how to report problems, propose ideas and change the project.

> **Licensing.** Code is GPL-3.0-or-later, artwork and sounds are all rights reserved, the documentation is CC BY 4.0 ([LICENSING.md](LICENSING.md)). Read [Licensing of contributions](#licensing-of-contributions) before opening a pull request.

## Language

Issues, pull requests, commit messages, code, comments and public documentation are in **English**. The internal specification in `docs/specs/` is in Italian; the wiki in `docs/wiki/` is in English and Italian (every page has its `-it` twin). The interface is multilingual, English by default ([ADR 0010](docs/adr/0010-interface-and-documentation-languages.md)).

## Contents

1. [Before you start](#1-before-you-start)
2. [Reporting a problem or proposing an idea](#2-reporting-a-problem-or-proposing-an-idea)
3. [Changing the code](#3-changing-the-code)
4. [Checks and tests](#4-checks-and-tests)
5. [Git, issues and pull requests](#5-git-issues-and-pull-requests)
6. [What is not accepted](#6-what-is-not-accepted)
7. [Licensing of contributions](#licensing-of-contributions)

## 1. Before you start

- Read the [specification](docs/specs/README.md) and the [ADRs](docs/adr/README.md): they explain what the addon does and why. The plan is in the [roadmap](ROADMAP.md).
- The addon targets **WoW Forever, Interface 16001**. Check every API in the Forever API dump ([ADR 0002](docs/adr/0002-wow-forever-target-and-api-dump.md)) and guard it with the Compat layer.

## 2. Reporting a problem or proposing an idea

- **Bugs**: open an issue with the *Bug report* form.
- **Ideas and questions**: start a topic in the [Feedback discussions](https://github.com/Finland6738/azeroth-prestige/discussions/categories/feedback); a concrete request can become a *Feature request* issue.
- **Checks in the real client**: use the *In-game test report* form.
- **Privacy**: never paste other players' names, whispers, account names or folder paths from your PC.

## 3. Changing the code

- Points are recomputed from events with the public ruleset, never declared ([ADR 0003](docs/adr/0003-points-recomputed-from-events.md)): domain modules (`Domain/`, `Data/`) are pure Lua with no game API, so they can be tested offline.
- Every game API call goes through `Core/Compat.lua`; every value that may be secret goes through `Restrictions.SafeGet`.
- Every visible string is an AceLocale key (`L["KEY"]`) and exists in every file of `Locales/` (English is the base).
- Saved data changes need a schema migration, and no migration lowers points, peaks or titles ([ADR 0006](docs/adr/0006-embedded-ace3-savedvariables-and-schema-versions.md)).
- Network data follows the trust rules ([ADR 0004](docs/adr/0004-trust-without-a-server.md)): first-hand wins, second-hand never lowers what is known.
- Unfinished features stay behind their switch in `Core/Features.lua` ([ADR 0017](docs/adr/0017-feature-switches.md)).
- The addon lives in `AzerothPrestige/` (Lua 5.1 only, from M1.2). Libraries are never committed: they are pinned in `.pkgmeta`.

## 4. Checks and tests

```
python -I -X utf8 tools/check_docs.py
python -m pip install lupa==2.8            # once, from M1.3
python -X utf8 Tests/run_tests.py          # all offline tests, from M1.3
```

`check_docs.py` checks relative links, the wiki sidebar, links and Italian twins, the ADR index, personal data (emails, personal paths, and the names listed in your git-ignored `tools/local.ini`, see `tools/local.example.ini`), your git identity, LF line endings and the changelog; from M1.2 also the addon TOC and the package contents. The offline tests run Lua 5.1 through lupa on a mock client ([ADR 0011](docs/adr/0011-offline-tests-with-lupa-and-a-mock-client.md)); `python -X utf8 Tests/run_tests.py <text>` runs only the tests whose name contains the text, `--long` adds the long scenarios. **No change without a test.**

## 5. Git, issues and pull requests

- One branch per step or fix from an up-to-date `main`: `step/m<N>-<k>-<name>`, `fix/<name>`, `docs/<name>`, `chore/<name>`.
- Small commits with clear messages in English. Use the GitHub noreply address as your git email in this repository.
- Every pull request updates **in the same PR**: `CHANGELOG.md` ("Unreleased"), the affected docs (specs, ADRs and the ADR index, both READMEs) and **the wiki pages in `docs/wiki/`, in both languages, for any user-visible change**. The *Docs rule* check enforces it for changes to the addon ([ADR 0009](docs/adr/0009-automatic-rules-ci-docs-rule-wiki-sync.md)).
- The wiki is **never edited on GitHub**: it is published from `docs/wiki/` after every merge ([ADR 0008](docs/adr/0008-github-wiki-generated-from-docs-wiki.md)).
- A pull request reaches `main` as one squashed commit when `Tests` and `Docs rule` are green; the maintainer squashes external contributions the same way, keeping the contributor as co-author. The maintainer's steps are shipped with `tools/ship_step.py` ([ADR 0007](docs/adr/0007-git-flow-and-automated-shipping.md)).
- A pull request that fixes an issue says `Closes #N`.

## 6. What is not accepted

- Code that sends anything outside the game, telemetry or external services.
- Files copied from the game client, from other games or from third-party databases of game data.
- Gameplay advantages, rank requirements for groups, or filters that gate players by rank.
- Personal data in the repository.

## Licensing of contributions

By opening a pull request you confirm that you wrote what you submit, or have the right to submit it, and that it copies
nothing from the game or from other projects without a compatible licence (Developer Certificate of Origin: sign off your
commits with `git commit -s`). You keep the copyright of your work, and you agree that:

- **code** you contribute is licensed under **GPL-3.0-or-later**;
- **documentation** you contribute is licensed under **CC BY 4.0**;
- for **artwork and sounds** (the files listed in [LICENSE-CONTENT.md](LICENSE-CONTENT.md)), you grant the project owner a
  perpetual, worldwide, non-exclusive, royalty-free and irrevocable licence to use, change, distribute and sublicense your
  contribution as part of Azeroth Prestige, and to change the licence under which the project's artwork is distributed.
