# 0011. Offline tests with lupa and a mock client

- Status: Accepted
- Date: 2026-11-26 (the approach of Azeroth Accord, ADR 0016 there)

## Context

The addon runs only inside WoW Forever, which cannot start in continuous integration. Most of the logic (ladder, scoring, ledger, codec, profile merge, apex assignment, celebration queue) does not depend on graphics.

## Decision

1. **Runner** `Tests/run_tests.py` with `lupa.lua51` (pinned `lupa==2.8`, Lua 5.1 like the client): it loads the real embedded libraries and the addon files in TOC order, each with the addon name and a private namespace table, like the client. It replaces the busted and luacheck plan of the first draft of the specification.
2. **Mock client** in `Tests/mock/`, one area per file (frames and events, timers and a controllable clock, addon messages with lockdown and throttle, group and raid roster, encounters, quests, map exploration, professions, PvP, mail and trade, nameplates and tooltips, secret values), each file citing the dump entries it imitates.
3. **`/reload` simulation** that serializes and restores the SavedVariables declared in the TOC.
4. **Network simulator** `Tests/sim/`: N complete clients in one Lua state, with latency, loss and lockdown, to prove that beacons, profile merge, attestations, relays and the weekly apex consensus converge. Its large scenarios run in the **Long tests** workflow.
5. **No change without a test**: every step adds tests for what it builds, and the whole suite runs before every ship ([ADR 0007](0007-git-flow-and-automated-shipping.md)).

## Consequences

- Positive: fast tests in CI; the protocol and the anti-cheat rules are proven with many clients.
- Negative: a green test shows that the code agrees with our assumptions about the client, not that the client agrees: the M0 results and the in-game checklist of each milestone stay necessary.
