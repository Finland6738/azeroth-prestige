# 0015. One version per milestone; `v1.0.0` after M7

- Status: Accepted
- Date: 2026-11-26 (as in Azeroth Accord, ADR 0020 there; the owner placed `v1.0.0` after M7)

## Decision

1. Milestone M0 is a probe and is never released.
2. Every milestone N from M1 to M6 is released as **`v0.N.0`** after its last step: `v0.1.0` to `v0.6.0`. **M7 is released as `v1.0.0`**, after the full release check ([checklists](../checklists/README.md)).
3. Fixes to a released milestone raise only the last number (`v0.3.1`).
4. Pre-release suffixes (`-alpha.N`, `-beta.N`, `-rc.N`) stay available.
5. **No half-finished feature in a release**: before each tag a release-preparation step hides what later milestones left in the code behind its switch ([ADR 0017](0017-feature-switches.md)), promotes the changelog with `tools/release_notes.py --promote`, updates the status in both READMEs and runs the Release workflow as a dry run. The tag is annotated, made with the noreply identity, and the GitHub Release and its zip are checked afterwards ([RELEASING](../RELEASING.md)).
6. The milestone tags have the owner's standing approval once the release-preparation step is on `main`; any other tag is asked first.

## Consequences

- Positive: a predictable rhythm; every version is complete in what it shows.
- Negative: `v0.1.0` (M1) has no window yet: only commands and local points.
