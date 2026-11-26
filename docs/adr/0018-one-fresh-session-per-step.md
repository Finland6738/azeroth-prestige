# 0018. One fresh development session per step, coordinated

- Status: Accepted
- Date: 2026-11-26 (the owner's method)

## Decision

1. A **coordinating session** does not implement steps. For each step it starts a **new session** with fresh context, in the same folder, without a worktree, and waits for it to finish. One step session at a time: every step touches `CHANGELOG.md` and the milestone file.
2. The brief of a step session says: only this step; follow `CLAUDE.md`; ship with `tools/ship_step.py`; read the milestone section and the listed specs; respect the feature switches; never `gh pr merge`; never run `tools/sync_wiki.py`; report in Italian with the pull request, the commit on `main`, the number of tests and what was not verified in the game.
3. When a step session ends, the coordinator checks: `git fetch`, `git checkout main`, `git merge --ff-only origin/main`, the noreply author in `git log`, the step ticked, a clean checkout. Only then does the next step start.
4. If an answer of the owner changes while a step runs, the coordinator forwards it to that session instead of editing files itself. A step waiting for an answer of the owner may let a later independent step start first.
5. **Model and effort per kind of step**, written in each milestone file:

| Kind of step | Model | Effort |
|---|---|---|
| Specification, architecture, network protocol, protected or taint-sensitive APIs, security, data migrations | Opus | high |
| Non-trivial data logic | Opus | medium |
| UI views, standard features on existing foundations | Sonnet | medium |
| Features with many edge cases or heavy tests | Sonnet | high |
| Checklists, documentation, release preparation | Sonnet | low or medium |

## Consequences

- Positive: each step starts from the repository, not from a long conversation; cost matches difficulty.
- Negative: a step session must re-read the specs it needs.
