# 0019. Integrations with other addons: only a public read-only API

- Status: Accepted
- Date: 2026-11-26 (the owner's answer)

## Context

The owner also makes Azeroth Accord, Finland Dragon Credit Points and Azeroth Unspoken. Prestige could read them (for example Accord's characters per account, to strengthen the anti-alt rule across computers), but that would couple releases and installs.

## Decision

1. Azeroth Prestige **reads no other addon** and writes into none.
2. It exposes a small **public read-only API** on the global `AzerothPrestige` ([SPEC-01 §19.2](../specs/SPEC-01-platform-architecture.md)): `GetProfile`, `GetRank`, `GetBadge`, `RegisterCallback`. It is versioned and documented in the wiki (M7.2).
3. Another addon (the owner's or anyone's) may show Prestige badges through that API in a step of its own; nameplate and unit-frame adapters (Plater, ElvUI...) live inside Prestige and only anchor its own textures (M7.4).

## Consequences

- Positive: independent releases; any addon can integrate without Prestige knowing it.
- Negative: the anti-alt rule cannot see a second computer of the same player ([SPEC-02 §8.5](../specs/SPEC-02-progression-scoring.md)).
