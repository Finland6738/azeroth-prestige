# 0013. Reuse the foundations of Azeroth Accord and Azeroth Unspoken

- Status: Accepted
- Date: 2026-11-26 (as Azeroth Accord did with Azeroth Guild Finder, ADR 0018 there)

## Context

Azeroth Accord and Azeroth Unspoken, by the same owner and under GPL-3.0, already have working, tested foundations for WoW Forever: the Compat layer, Config with schema versions, the event bus, the Codec on `C_EncodingUtil`, the transport with lockdown queue, diagnostics, the theme and widget kit in the style of FDCP, the lupa test harness, the mock client and the network simulator, and the repository tooling (docs checks, ship script, wiki sync, release notes, packaging, media, fonts and mockups).

## Decision

1. Azeroth Prestige starts from **copies** of those files, renamed to its own namespace, and adapts them. Accord is the main source (process, CI, roadmap, code foundations); Unspoken is the source for the licence split and its media and mockup tools.
2. The copies are independent: no shared library and no runtime dependency, so the addons can be installed together and evolve separately ([ADR 0019](0019-integrations-public-api-only.md)).
3. Each copied file says in its header where it comes from; a fix found in one project is ported to the other by hand when it applies.
4. The bootstrap copied the repository tooling and workflows; the code foundations arrive in M1 and the UI kit in M3.

## Consequences

- Positive: M1 and M3 are mostly adaptation; the test harness and the shipping flow exist from day one.
- Negative: several copies of similar code to keep in mind.
