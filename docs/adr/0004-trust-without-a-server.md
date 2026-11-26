# 0004. Trust without a server: witnesses, trust levels and network-observed leaderboards

- Status: Accepted
- Date: 2026-11-26 ([SPEC-05](../specs/SPEC-05-ledger-trust.md), [SPEC-07](../specs/SPEC-07-leaderboards-hall.md))

## Context

Two facts are the only strong guarantees available to an addon: the **sender name of an addon message is set by the server**, and some game data can be queried (level, class, guild, server counters). Checksums or signatures with keys inside public code are worthless.

## Decision

1. **Witness attestations**: after a group event, every client with the addon that was present sends an `ATT` message; a third party can ask the witness directly (`ATQ`/`ATA`), and the answer cannot be forged by the owner of the profile.
2. Each event has a **trust level**: 3 Witnessed, 2 Corroborated (server-side data), 1 Self-reported, 0 Flagged. A profile's **verified ratio** `vr` is the share of its points with level 2 or more.
3. **Plausibility checks** run on every profile received (maximum rates, one-time counters, monotonic versions); a failing profile is flagged and shown with a warning, never deleted.
4. Threshold tiers need no `vr`; the seven **apex ranks** need `vr` of at least 0.6 and a first-hand or corroborated profile.
5. Leaderboards state how many profiles they know and when they last synced. Weekly apex seats are a **majority consensus** of digests (`LBD`), not an authority.
6. Limits are declared, not hidden: two accounts of one person can witness each other; a modified client can ignore the anti-alt rule. Mitigations (witness weighting, caps on farmable families) are in the specification.

## Consequences

- Positive: honest about what can and cannot be proven; solo players are not punished on threshold tiers.
- Negative: apex seats can differ slightly between clients; a determined cheater with several accounts can inflate self-reported categories.
