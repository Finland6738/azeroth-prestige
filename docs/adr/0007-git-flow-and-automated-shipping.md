# 0007. Git flow and automated shipping of milestone steps

- Status: Accepted
- Date: 2026-11-26 (the rules of Azeroth Accord, ADR 0012 there, without its deferred tests)

## Context

The project is developed in milestone steps by automated sessions, often while the owner is away. The owner asked that every finished step is committed, pushed, opened as a pull request and merged **automatically**, that the wiki follows every change, and that the history carries only the GitHub noreply address.

## Decision

1. `main` is always working; nobody commits to it directly. The only exception is the first commit of the empty repository (the technical specification, re-authored with the noreply address before its first push).
2. One branch per step from an up-to-date `main`: `step/m<N>-<k>-<name>` for roadmap steps, `fix/…`, `docs/…`, `chore/…` for the rest.
3. Commit messages, pull requests and issues in English.
4. **Authorized automation**: when a step is finished, `python -I -X utf8 tools/ship_step.py --title … --body-file … [--commit …]` runs `tools/check_docs.py` and the **whole offline suite**, merges `origin/main` if needed, squashes the step into **one commit authored and committed by the noreply address**, pushes, opens the pull request, **waits for the required CI checks** on that exact commit and, only if they are green, fast-forwards `main` to it and deletes the branch. On any failure it stops and the pull request stays open with the reason.
5. Unlike Accord (its ADR 0012 point 9) there is **no option to skip the tests**: every step runs them and waits for CI (owner, 2026-11-26).
6. Every pull request says honestly what was **not** verified, especially anything that needs the real client.
7. Never `--force` on `main`, never rewrite published history, never skip hooks. Never `gh pr merge` and never a merge from GitHub's web interface: GitHub would author the commit with the account's personal email.
8. Choices that belong to the owner (licence, names, scope, deleting their data) are not made autonomously: they are asked, or opened as an issue with the options, and listed as open questions in [SPEC-11](../specs/SPEC-11-risks-open-questions.md) with a proposed answer that the code applies until the owner decides.

## Consequences

- Positive: one readable, tested commit per step on `main`, no manual merge work, CI as the gate.
- Negative: no human review before merge; the checks must be good enough to be trusted.
