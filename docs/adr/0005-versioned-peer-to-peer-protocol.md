# 0005. A versioned peer-to-peer protocol on addon messages

- Status: Accepted
- Date: 2026-11-26 ([SPEC-06](../specs/SPEC-06-network-protocol.md))

## Context

WoW Forever has one mega-realm per ruleset and region, so thousands of addon users can share a realm. Addon messages are limited to 255 bytes, throttled per prefix and blocked during chat lockdown; trial accounts cannot send them.

## Decision

1. One prefix, `AZPRES`, and an envelope `<ver><type><seq><payload>`; messages longer than 255 bytes are split with AceComm and every send goes through ChatThrottleLib with priorities.
2. Message types: `HEL` beacon, `PRQ`/`PRF` profile request and reply, `ATT`/`ATQ`/`ATA` attestations, `RLY` relays of offline profiles, `LBD` apex digests, `CMD` commendations, `EVT` Prestige Events, `CTR` contracts. An unknown type or a higher protocol version is ignored, never an error.
3. **Discovery** beyond guild and group uses a hidden custom channel, with rare beacons, lazy profile fetch on demand and, above a traffic threshold, longer beacon intervals and channel sharding.
4. A **lockdown queue** keeps outgoing messages (TTL 30 minutes) while `C_ChatInfo.InChatMessagingLockdown()` is true or a send returns `AddOnMessageLockdown`.
5. First-hand data always wins; second-hand data is accepted only when two distinct relays agree and can never lower known points.
6. Trial accounts track locally and receive, but never send.

## Consequences

- Positive: bounded traffic, tolerant of old and new clients, proven offline in the network simulator before any in-game test.
- Negative: the channel limits on Forever are unknown until M0 (V4, V5); the design may need a revision there.
