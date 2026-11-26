# 0002. Target WoW Forever (Interface 16001) and use the API dump as a reference

- Status: Accepted
- Date: 2026-11-26 (same decision as Azeroth Accord, ADR 0002 there)

## Context

The addon is for **World of Warcraft: Forever** (build `1.60.1`, `## Interface: 16001`, `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`). It runs on a modern client with the restrictions of the *Midnight* era: secret values in combat, encounters and instances, the combat log closed to addons, chat lockdown ([SPEC-01 §3](../specs/SPEC-01-platform-architecture.md)). Public documentation mostly covers retail.

## Decision

1. The TOC declares `## Interface: 16001`; at load the addon checks `WOW_PROJECT_CAMELOT` (or an Interface between 16001 and 19999). The TOC file is `AzerothPrestige/AzerothPrestige.toc`, as in Accord; whether a `_Forever` TOC name is needed is checked in M0.
2. The public API dump extracted from the Forever client (`WoW-Addons/docs/api.json`, cloned next to the project) is the reference for what can be called. It declares no licence, so **none of its files enter this repository**: it is only read.
3. Every API that is missing from the dump, or whose behaviour on Forever is unknown, is marked 🔍 in the specification, guarded by the Compat layer and checked in the real client by the probe of milestone M0 (checks V1-V21).
4. No addon code uses the combat log (`COMBAT_LOG_EVENT_UNFILTERED`).

## Consequences

- Positive: fewer calls to functions that do not exist; known risks are visible early.
- Negative: every client update needs a new check of the dump.
