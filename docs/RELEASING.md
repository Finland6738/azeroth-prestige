# Releasing

> Adapted from Azeroth Accord (docs/RELEASING.md), same owner, GPL-3.0 ([ADR 0013](adr/0013-reuse-azeroth-accord-and-unspoken-foundations.md)).

How a version of Azeroth Prestige is built and published. The workflow is [release.yml](../.github/workflows/release.yml); the decisions are in [ADR 0006](adr/0006-embedded-ace3-savedvariables-and-schema-versions.md) and [ADR 0015](adr/0015-one-version-per-milestone.md). **Nothing has been released yet.**

## The versions

| Tag | When | The in-game check |
|---|---|---|
| — | M0, the probe: never released | [M0 checklist](checklists/README.md) |
| `v0.1.0` … `v0.6.0` | after the release-preparation step of M1 … M6 | the milestone's own checklist, written in its last steps |
| `v0.<N>.<F>` | the F-th fix release of milestone N | the checks the fix touches |
| `v1.0.0` | after M7, when the full release checklist has passed | `docs/checklists/release.md` (step M7.9) |

**No half-finished features.** Before each tag, whatever a later milestone left in the addon is hidden behind its switch in `AzerothPrestige/Core/Features.lua` (checked by `Tests/test_features.lua`), and switched on when that milestone is complete ([ADR 0017](adr/0017-feature-switches.md)). A pre-release suffix (`-alpha`, `-beta`, `-rc`) makes the GitHub Release a pre-release.

## What a tag does

Pushing a tag `vMAJOR.MINOR.PATCH` (optionally `-alpha`, `-beta` or `-rc`, with `.N`) starts the workflow **Release**, which:

1. checks what the package will contain (`tools/check_package.py`, from M1.2);
2. builds the zip with the [BigWigs packager](https://github.com/BigWigsMods/packager): libraries from `.pkgmeta`, `## Version` filled in with the tag, `Tests/`, `docs/`, `tools/`, `assets/` and the development Markdown left out, the licence files kept;
3. checks the zip itself and keeps it as a workflow artifact for 14 days;
4. creates the **GitHub Release** with that zip; its body is the section of `CHANGELOG.md` for the version (`tools/release_notes.py`);
5. uploads to **CurseForge** only if the `CF_API_KEY` secret and the project ID in the TOC are both set ([SPEC-11](specs/SPEC-11-risks-open-questions.md) Q15: GitHub only for now). Otherwise it says "CurseForge skipped" and the run stays green.

## Try it without publishing anything

1. **Dry run**: Actions → *Release* → *Run workflow* on `main`, leave `draft_tag` empty. It builds and checks the zip; download it from the run's artifacts and look inside. Nothing is published. Every release-preparation step does this.
2. **Draft release**: run it again with `draft_tag` = `v0.0.1-alpha.1`. It creates a **draft** GitHub Release with the zip; only the owner can see drafts. Delete the draft afterwards.

## Releasing a version

1. The release-preparation step of the milestone is on `main` (CI green, switches checked, changelog promoted with `python -I -X utf8 tools/release_notes.py --promote 0.<N>.0`, READMEs and wiki updated, dry run inspected).
2. **Check your git identity first**: an annotated tag records the tagger's name and email, and this repository's rule is the GitHub noreply address. `git config user.email` must print an `@users.noreply.github.com` address; then:

   ```bash
   git switch main && git pull --ff-only origin main
   git tag -a v0.1.0 -m "Azeroth Prestige 0.1.0"
   git push origin v0.1.0
   ```

3. Watch the *Release* run, open the GitHub Release, download the zip and check that it holds one `AzerothPrestige/` folder with the TOC, the libraries and the licence files, and that the TOC says the right version.

The milestone tags `v0.<N>.0` and `v1.0.0` have the owner's standing approval once the release-preparation step is on `main`; any other tag (a fix or a pre-release) is asked first.
