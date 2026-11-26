# 0008. The GitHub wiki: a user manual generated from `docs/wiki/`

- Status: Accepted
- Date: 2026-11-26 (as in Azeroth Accord, ADR 0013 there)

## Decision

1. `docs/wiki/*.md` is the **only source** of the wiki; the wiki is a generated mirror and is **never edited on GitHub**.
2. `tools/sync_wiki.py` clones the wiki, copies the pages with a "generated, do not edit here" note and the images they show, removes what is gone and pushes as `github-actions[bot]`. Development sessions never run it: only the **Wiki sync** workflow does, on every push to `main` that changes `docs/wiki/`.
3. GitHub creates the wiki repository only after its first page is saved in the browser by the owner; until then the sync passes with a warning.
4. Developer documentation (specs, ADRs, roadmap) stays in the repository.

## Consequences

- Positive: one reviewed source; the manual cannot drift from the repository.
- Negative: user-visible changes must update `docs/wiki/` in both languages in the same pull request.
