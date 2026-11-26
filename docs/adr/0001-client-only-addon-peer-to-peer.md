# 0001. A client-only addon; data travels peer to peer

- Status: Accepted
- Date: 2026-11-26 (the owner's decision D-02, [SPEC-00](../specs/SPEC-00-vision-scope.md))

## Context

Prestige ranks only mean something if other players can see them: badges, profiles and leaderboards need data from many clients. The first design (chat A) had an addon talking to a backend API, a database and a web portal. A WoW addon cannot open a network connection, and the owner ruled out a companion application that would upload the saved data.

## Decision

1. Azeroth Prestige is **only an addon, for good**: no backend, no companion application, no web portal.
2. Clients exchange data **peer to peer** with addon messages (`C_ChatInfo.SendAddonMessage`) on `GUILD`, `PARTY`/`RAID`, `WHISPER` and a hidden custom channel ([ADR 0005](0005-versioned-peer-to-peer-protocol.md)).
3. Three consequences are accepted and stated wherever they matter: leaderboards are **network-observed** (what the network of users knows, not a global truth); anti-cheat is **not cryptographic** ([ADR 0004](0004-trust-without-a-server.md)); badges are visible **only to players who run the addon**.
4. The addon never sends anything outside the game.

## Alternatives considered

- **Backend and web portal.** Impossible from inside the client.
- **Companion application uploading SavedVariables.** Rejected by the owner: an extra install, and data collected outside the game.

## Consequences

- Positive: zero infrastructure and running costs; nothing leaves the game; it follows Blizzard's UI Add-On Development Policy.
- Negative: no authoritative ranking; a profile lives only as long as some client keeps it ([SPEC-06 §12.5](../specs/SPEC-06-network-protocol.md)); the protocol must scale to a mega-realm.
