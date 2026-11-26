# Instructions for development sessions

The owner speaks Italian: talk to them in Italian. Code, comments, commits, pull requests, issues, README and ADRs are in English; the wiki is bilingual (every `docs/wiki/<Page>.md` has an Italian twin `<Page>-it.md`, same images, and `tools/check_docs.py` checks it); the specification in `docs/specs/` is in Italian; the interface is multilingual, English by default with Italian, one locale file per language ([ADR 0010](docs/adr/0010-interface-and-documentation-languages.md)).

## Where things are

- Specification: `docs/specs/` (SPEC-00…SPEC-11; the § numbers are those of the original v0.4 document). Decisions: `docs/adr/` (index in `docs/adr/README.md`). User manual: `docs/wiki/`. Plan: `ROADMAP.md` and the milestone files in `docs/roadmap/` (take the **first unticked step**, tick it in the same PR with a short *Done* note).
- Open questions for the owner: `docs/specs/SPEC-11-risks-open-questions.md` (Q1, Q2, …). The code applies the proposed answer until the owner decides, and each answer is changed in one place only (the "punto unico" column).
- WoW Forever API dump: `../WoW-Addons/docs/api.json` (consult only, never copy, [ADR 0002](docs/adr/0002-wow-forever-target-and-api-dump.md)).
- Sibling projects to copy foundations from (same owner, GPL-3.0, [ADR 0013](docs/adr/0013-reuse-azeroth-accord-and-unspoken-foundations.md)): `../azeroth-accord` (process, CI, code foundations, UI kit) and `../azeroth-unspoken` (licences, media and mockup tools). Read them, never modify them; each copied file says where it comes from.
- Unfinished features stay behind their switch in `AzerothPrestige/Core/Features.lua` ([ADR 0017](docs/adr/0017-feature-switches.md)).

## Git automation (authorized by the owner, ADR 0007)

For every milestone step or fix:

1. Branch from an up-to-date `main`: `step/m<N>-<k>-<name>` (or `fix/…`, `docs/…`, `chore/…`). Never commit to `main`.
2. Do the work, **with tests** (no change without a test). In the same branch update `CHANGELOG.md` ("Unreleased"), the affected specs and ADRs (and the ADR index), `README.md` + `README.it.md` when features or status change, `docs/wiki/` in both languages for anything user-visible, and the step's checkbox in its milestone file.
3. Run `python -I -X utf8 tools/check_docs.py` and the whole offline suite `python -X utf8 Tests/run_tests.py` (from M1.3). Both must pass.
4. Write the pull request body (what and why, what was **not** verified in the real client) and ship **without asking**:
   `python -I -X utf8 tools/ship_step.py --title "M<N>: <summary>" --body-file <file> --commit "<message>"`
   It squashes the step into one noreply commit, pushes, opens the PR, waits for CI and fast-forwards `main`. If it stops, leave the PR open and report why.
5. **Never** `gh pr merge` and never merge from the GitHub web interface: GitHub would author the commit with the owner's personal email.
6. The wiki is published by the `Wiki sync` workflow after the merge: never edit the wiki on GitHub, and **never run `tools/sync_wiki.py`** (not even with `--help`: it publishes).

Do not decide alone what belongs to the owner (licence, names, scope, deleting their data): ask, or open an issue with the options, and add the question to SPEC-11 with a proposed answer.

## Step sessions (ADR 0018)

Each step runs in its own fresh session started by a coordinating session, one at a time. A step session does **only its step**, follows this file, reads the step's section in its milestone file and the specs it lists, respects the feature switches, and ends with a report **in Italian**: the pull request, the commit on `main`, the number of tests, and what was not verified in the game. The model and effort of each step are in its milestone file.

## Privacy

No personal data in the repository: no real names, emails (only GitHub noreply addresses), or personal paths (use `<WoW folder>` and similar). `tools/check_docs.py` fails on them; the owner's real names are listed only in the git-ignored `tools/local.ini`. This includes git authorship: this repository's git identity is the noreply address (`git config user.email`), and `ship_step.py` authors and commits every step with it. `prompt.txt` and `.gpt-ideas/` hold the owner's notes and private design chats and are git-ignored; never add them.
