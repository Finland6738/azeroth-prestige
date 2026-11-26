# M7 — Extensions and `v1.0.0`

**Goal:** what makes the addon complete for its first stable version: the public API for other addons, Prestige Contracts, adapters for popular nameplate and unit-frame addons, badges in guild and friends lists, the final art, the translation kit, and the full release check over everything (the owner placed `v1.0.0` after M7, [ADR 0015](../adr/0015-one-version-per-milestone.md)).

**Exit criterion (in game):** another addon reads a badge through `AzerothPrestige.GetBadge`; a contract goes from request to delivered and attested; the badge shows on Plater or ElvUI plates when they are installed; the final badges are readable at 16 px; the full release checklist passes.

**Release:** `v1.0.0` after M7.11.

| Step | Title | Kind | Model | Effort |
|---|---|---|---|---|
| M7.1 | Specification of the extensions | specification | Opus | high |
| M7.2 | Public read-only API | architecture | Opus | medium |
| M7.3 | Prestige Contracts (`CTR`) | network protocol | Opus | high |
| M7.4 | Adapters for nameplate and unit-frame addons | many edge cases, taint | Sonnet | high |
| M7.5 | Badges in guild and friends lists | UI on existing foundations | Sonnet | medium |
| M7.6 | Final art: badges, emblems, frames, sounds | standard on existing foundations | Sonnet | medium |
| M7.7 | Translation kit | documentation, tooling | Sonnet | medium |
| M7.8 | Hardening pass | security | Opus | high |
| M7.9 | Full release checklist | checklist | Sonnet | medium |
| M7.10 | M7 in-game checklist | checklist | Sonnet | low |
| M7.11 | Release preparation `v1.0.0` | release preparation | Sonnet | medium |

### M7.1 — Specification of the extensions
- Branch: `step/m7-1-spec`
- Model: Opus · high
- Depends on: M6
- Spec: SPEC-01 §19, SPEC-03 §7.10, SPEC-08 §14.4 (fase 2), §14.7, ADR 0019
- Scope: the API contract and its version, callbacks and their payloads; the `CTR` layout; the list of adapters and how each is detected; the final-art acceptance rules (originality, tool terms, 16 px); the translation workflow; switches `api`, `contracts`, `adapters`, `lists`.
- Done when:
  - [ ] Every extension has its interface and test cases listed.
- Tests: `check_docs.py`.
- Docs: SPEC-01, SPEC-03, SPEC-08, CHANGELOG.
- Real client: nothing.

### M7.2 — Public read-only API
- Branch: `step/m7-2-public-api`
- Model: Opus · medium
- Depends on: M7.1
- Spec: SPEC-01 §19.2, ADR 0019
- Scope: `API/Public.lua`: `GetProfile` (read-only proxy), `GetRank`, `GetBadge`, `RegisterCallback` for `PROMOTION`, `PROFILE_UPDATED`, `LEGEND_CHANGED`; `API_VERSION`; errors in a caller's callback never break the addon.
- Done when:
  - [ ] A caller cannot change any internal table through the API.
- Tests: `test_public_api.lua`.
- Docs: wiki *For Addon Authors* (both languages), CHANGELOG.
- Real client: a small test addon (checklist).

### M7.3 — Prestige Contracts
- Branch: `step/m7-3-contracts`
- Model: Opus · high
- Depends on: M7.1
- Spec: SPEC-03 §7.10, SPEC-06 §12.2 (`CTR`)
- Scope: `Domain/Contracts.lua` and a board in the Events tab: publish a request, accept, complete with a trade of the requested item and the buyer's attestation; points per §7.10 with the Merchant caps and the anti-alt rule.
- Done when:
  - [ ] A contract between characters of the same account gives nothing; a contract without the attestation gives nothing.
- Tests: `test_contracts.lua`, simulator scenario.
- Docs: wiki *Prestige Contracts* (both languages), CHANGELOG.
- Real client: a contract between two players (checklist).

### M7.4 — Adapters for nameplate and unit-frame addons
- Branch: `step/m7-4-adapters`
- Model: Sonnet · high
- Depends on: M7.2
- Spec: SPEC-01 §19.1
- Scope: `Badges/Adapters/*.lua`: Plater, Platynator, KUI, ElvUI plates and frames, Cell, VuhDo where they expose a frame; detection by loaded addon; fall back to the base plate; no other addon's code is changed.
- Done when:
  - [ ] Each adapter is tested against a mock of the addon's frame; a missing addon is a no-op.
- Tests: `test_adapters.lua`.
- Docs: wiki *Compatibility* (both languages), CHANGELOG.
- Real client: each addon installed (checklist).

### M7.5 — Badges in guild and friends lists
- Branch: `step/m7-5-lists`
- Model: Sonnet · medium
- Depends on: M7.1
- Spec: SPEC-08 §14.4 (Inspect / Who / Friends / Guild)
- Scope: badges in the guild roster, friends list and who list, added by hooks that only observe and add textures, never replace Blizzard functions.
- Done when:
  - [ ] No taint in the guild window (`ADDON_ACTION_BLOCKED` never raised in tests with the mock).
- Tests: `test_lists.lua`.
- Docs: wiki *Badges*, CHANGELOG.
- Real client: the guild and friends windows (checklist).

### M7.6 — Final art: badges, emblems, frames, sounds
- Branch: `step/m7-6-final-art`
- Model: Sonnet · medium
- Depends on: the owner's final images (AI-generated and refined, SPEC-08 §14.7)
- Spec: SPEC-08 §14.5, §14.7, ADR 0012
- Scope: import the owner's final files into `AzerothPrestige/Media/` in the required formats (64×64, 16×16, flipbooks, `.ogg`), keep the placeholders as the high-contrast fallback if useful, update `docs/third-party.md` and the media `NOTICE.md`, regenerate the previews.
- Done when:
  - [ ] Every rank, seal and emblem has its final art, checked at 16 px and in greyscale; the originality and tool-terms check of §14.7 is recorded.
- Tests: the media check.
- Docs: `docs/third-party.md`, previews, CHANGELOG.
- Real client: readability (checklist).

### M7.7 — Translation kit
- Branch: `step/m7-7-translation-kit`
- Model: Sonnet · medium
- Depends on: M7.1
- Spec: ADR 0010 point 2, SPEC-08 §18
- Scope: `tools/locale_template.py` (exports the English keys with context to a new `Locales/<code>.lua` skeleton), CONTRIBUTING section for translators, the locale test extended to every file present; no new language is shipped unless a reviewed translation exists.
- Done when:
  - [ ] A new locale file with a few keys loads and falls back to English for the rest.
- Tests: `test_locales.lua`.
- Docs: CONTRIBUTING, wiki *Languages* (both languages), CHANGELOG.
- Real client: nothing.

### M7.8 — Hardening pass
- Branch: `step/m7-8-hardening`
- Model: Opus · high
- Depends on: M7.2-M7.5
- Spec: SPEC-05 §11.1, SPEC-06, SPEC-11 R6, R7
- Scope: a malicious-client simulator scenario (oversized messages, forged relays, inflated profiles, replayed attestations, floods), rate limits per sender, fixes for what it finds.
- Done when:
  - [ ] Every attack of the scenario is rejected or bounded, with the numbers in SPEC-05.
- Tests: `test_hardening.lua`, long scenario.
- Docs: SPEC-05, SPEC-11, CHANGELOG.
- Real client: nothing.

### M7.9 — Full release checklist
- Branch: `step/m7-9-release-checklist`
- Model: Sonnet · medium
- Depends on: M7.8
- Scope: `docs/checklists/release.md`: every milestone checklist that is still open, merged into one run over a single build, with the acceptance cases A1-A19.
- Done when:
  - [ ] Every exit criterion of M1-M7 and every acceptance case has a box.
- Tests: `check_docs.py`.
- Docs: `docs/checklists/README.md`, CHANGELOG.
- Real client: the owner runs it.

### M7.10 — M7 in-game checklist
- Branch: `step/m7-10-checklist`
- Model: Sonnet · low
- Depends on: M7.9
- Scope: `docs/checklists/M7.md`: API, contracts, adapters, lists, final art.
- Done when:
  - [ ] The checklist covers the exit criterion of M7.
- Tests: `check_docs.py`.
- Docs: CHANGELOG.
- Real client: the owner runs it.

### M7.11 — Release preparation `v1.0.0`
- Branch: `step/m7-11-release-prep`
- Model: Sonnet · medium
- Depends on: M7.10 and the owner's run of the release checklist
- Scope: as M1.12, for `1.0.0`; every switch on; the READMEs and the wiki say "stable".
- Done when:
  - [ ] Dry run green, zip inspected, changelog section `1.0.0`, the full suite, the long tests and CI green.
- Tests: the whole suite and the long tests.
- Docs: CHANGELOG, READMEs, wiki *Home*.
- Real client: the release checklist.
