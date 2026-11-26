# 0006. Embedded Ace3, SavedVariables and schema versions

- Status: Accepted
- Date: 2026-11-26 (as in Azeroth Accord, ADR 0011 there)

## Context

The addon needs events, comms with throttling, a database with defaults, localization and configuration, and its saved data will change shape over the milestones.

## Decision

1. Ace3 (AceAddon, AceEvent, AceComm with ChatThrottleLib, AceDB, AceLocale, AceConsole), LibDataBroker and LibDBIcon are **embedded**, pinned by tag in `.pkgmeta` and never committed: `tools/fetch_libs.py` downloads them for development and CI. LibSerialize and LibDeflate are added only if `C_EncodingUtil` is missing on Forever (M0 check V14).
2. Two saved variables: `AzerothPrestigeDB` (account-wide: known profiles, own characters for the anti-alt rule, weekly snapshots, Hall of Prestige, witness log, settings) and `AzerothPrestigeCharDB` (per character: ledger, points, peaks, caps, celebration queue).
3. Every saved table has a `schema` number; one migration function per version runs at `ADDON_LOADED` and is tested offline; an unknown future version is kept untouched and the addon runs **read-only**.
4. Migrations never lower points, peaks or titles ([ADR 0003](0003-points-recomputed-from-events.md)).

## Consequences

- Positive: proven libraries, safe upgrades.
- Negative: a few hundred KB of libraries in the package.
