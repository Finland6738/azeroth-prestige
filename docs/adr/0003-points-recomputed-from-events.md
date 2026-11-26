# 0003. Points are recomputed from events with a versioned ruleset, never declared

- Status: Accepted
- Date: 2026-11-26 ([SPEC-02 §8](../specs/SPEC-02-progression-scoring.md), [SPEC-05 §11](../specs/SPEC-05-ledger-trust.md))

## Context

Without a server anybody can edit their own SavedVariables, and the addon's code is public, so a points total sent by a client proves nothing. Balance will also change over time, and the owner decided that points, tiers and titles already earned never go down.

## Decision

1. Each character keeps an **append-only ledger** of Prestige events (`ruleId`, context, time, ruleset version `rv`, witnesses, trust level).
2. Points are a **pure function** of the events and of the **public, versioned ruleset** (`Data/Ruleset_vN.lua`): every peer can recompute them. Clients transmit events and digests, not trusted totals.
3. Each event stores the `rv` in force when it happened. A new ruleset applies only to later events: recomputing an old event with its own `rv` always gives the same result.
4. Events are **idempotent** (`eventId = hash(charKey, ruleId, contextKey, timeBucket)`): reconnects, `/reload` and double receipt add nothing.
5. Ladder, scoring, diminishing returns, caps, the anti-boost and anti-alt rules and the low-level divisor live in pure modules (`Domain/`, `Data/`) with no WoW API, tested offline.

## Consequences

- Positive: transparent and checkable points; rebalancing never takes anything away.
- Negative: old rulesets stay in the package forever; the ledger needs compaction to keep the saved data small ([SPEC-04 §10.3](../specs/SPEC-04-data-model.md)).
