# M4 — Network and badges (public beta)

**Goal:** profiles travel between players with the addon, group events are witnessed, and badges appear on tooltips, nameplates, unit frames, chat and the unit menu.

**Exit criterion (in game):** two players with the addon see each other's badge on tooltip and nameplate outside instances, and on the party frames inside a dungeon (A8); a boss kill in a group of five with three users gives each of them two attestations (A1); a trial account tracks locally and sends nothing (A9); `/azp debug` shows the network queue emptying after a boss (lockdown queue).

**Release:** `v0.4.0` after M4.13, the **public beta**.

| Step | Title | Kind | Model | Effort |
|---|---|---|---|---|
| M4.1 | Specification of the protocol | specification, network protocol | Opus | high |
| M4.2 | Codec, envelope and chunking | network protocol | Opus | high |
| M4.3 | Comm: transport, throttle, lockdown queue, discovery channel | network protocol | Opus | high |
| M4.4 | ProfileStore: merge, plausibility, eviction | security, data | Opus | high |
| M4.5 | Beacons and profile fetch (`HEL`, `PRQ`, `PRF`) | network protocol | Opus | high |
| M4.6 | Attestations (`ATT`, `ATQ`, `ATA`) and the verified ratio | security | Opus | high |
| M4.7 | Network simulator and long tests | heavy tests | Sonnet | high |
| M4.8 | Badges on the tooltip and the unit menu | UI on existing foundations | Sonnet | medium |
| M4.9 | Badges on nameplates, target, focus and group frames | taint-sensitive | Opus | high |
| M4.10 | Badges in chat | secret values, many edge cases | Sonnet | high |
| M4.11 | Privacy and network settings, profile of others | UI | Sonnet | medium |
| M4.12 | M4 in-game checklist | checklist | Sonnet | medium |
| M4.13 | Release preparation `v0.4.0` | release preparation | Sonnet | medium |

### M4.1 — Specification of the protocol
- Branch: `step/m4-1-spec`
- Model: Opus · high
- Depends on: M3, M0.9
- Spec: SPEC-05, SPEC-06, ADR 0004, 0005; M0 results V4, V5, V14
- Scope: in SPEC-06 (Italian): the exact envelope, field encodings and sizes of `HEL`, `PRQ`, `PRF` (with the ledger digest), `ATT`, `ATQ`, `ATA`; rates and priorities; the discovery channel and its fallback if M0 said no; merge, plausibility and eviction rules made precise; switches `network` and `badges`; Q21 applied as proposed.
- Done when:
  - [ ] Every message has a byte layout and a size bound; every merge rule has a test case listed.
- Tests: `check_docs.py`.
- Docs: SPEC-05, SPEC-06, ADR update if a decision changes, CHANGELOG.
- Real client: nothing.

### M4.2 — Codec, envelope and chunking
- Branch: `step/m4-2-codec`
- Model: Opus · high
- Depends on: M4.1
- Spec: SPEC-06 §12.1
- Scope: `Network/Codec.lua` (serialize, compress and encode with `C_EncodingUtil`, or LibSerialize and LibDeflate if V14 said so), envelope with version, type and sequence; adapted from Accord's `Net/Codec.lua`.
- Done when:
  - [ ] Roundtrip of every message type; malformed, truncated and oversized input is rejected without errors.
- Tests: `test_codec.lua` (fuzzed inputs).
- Docs: CHANGELOG.
- Real client: nothing.

### M4.3 — Comm: transport, throttle, lockdown queue, discovery channel
- Branch: `step/m4-3-comm`
- Model: Opus · high
- Depends on: M4.2
- Spec: SPEC-06 §12.1, §12.3; SPEC-01 §3.2
- Scope: `Network/Comm.lua` (prefix `AZPRES`, AceComm, ChatThrottleLib priorities), the lockdown queue (TTL 30 min, retry on state change), trial accounts receive only, `Network/Discovery.lua` (hidden channel, removed from chat frames, adaptive beacon interval, sharding), `Network/Router.lua` (dispatch by type, unknown types and higher versions ignored).
- Done when:
  - [ ] Nothing is sent in lockdown or from a trial account; the queue drains when lockdown ends.
- Tests: `test_comm.lua`, `test_discovery.lua`.
- Docs: CHANGELOG.
- Real client: channel join and lockdown (checklist).

### M4.4 — ProfileStore: merge, plausibility, eviction
- Branch: `step/m4-4-profile-store`
- Model: Opus · high
- Depends on: M4.2
- Spec: SPEC-05 §11.4-§11.5, SPEC-06 §12.4, SPEC-04 §10.2-§10.3
- Scope: `Domain/ProfileStore.lua`: first-hand replaces older versions; second-hand rules (two relays, never lower); plausibility checks and `flagged`; the anti-alt check on published `alts`; G-trigger recompute (A19); LRU eviction with priorities; a Config migration for the profile table.
- Done when:
  - [ ] A6 and A19 pass; 20 000 profiles stay within the memory budget of §17.
- Tests: `test_profile_store.lua`.
- Docs: SPEC-04 if the shape changed, CHANGELOG.
- Real client: nothing.

### M4.5 — Beacons and profile fetch
- Branch: `step/m4-5-beacons`
- Model: Opus · high
- Depends on: M4.3, M4.4
- Spec: SPEC-06 §12.2-§12.3
- Scope: `Network/Sync.lua`: `HEL` at login, every 15 min with jitter and at each promotion; lazy `PRQ` when a newer hash is seen (1 per 2 s, 30 per minute, negative cache); `PRF` with the profile and the ledger digest; the self-profile builder with `profileVersion`.
- Done when:
  - [ ] Two mock clients exchange profiles; rate limits hold under a burst of 200 hashes.
- Tests: `test_sync.lua`.
- Docs: CHANGELOG.
- Real client: two clients (checklist).

### M4.6 — Attestations and the verified ratio
- Branch: `step/m4-6-attestations`
- Model: Opus · high
- Depends on: M4.5
- Spec: SPEC-05 §11.2-§11.4
- Scope: `Domain/Attestation.lua`: `ATT` after group events (sent after lockdown), received witnesses stored in `w`, the `witnessLog` (90 days), `ATQ`/`ATA` verification by whisper, witnesses of the same account dropped, the 20% weight per witness, `vr` per category and its display in the profile.
- Done when:
  - [ ] A1 passes in the simulator; an alt cannot witness its own account.
- Tests: `test_attestation.lua`.
- Docs: wiki *Trust and Verification* (both languages), CHANGELOG.
- Real client: a group boss kill (checklist).

### M4.7 — Network simulator and long tests
- Branch: `step/m4-7-simulator`
- Model: Sonnet · high
- Depends on: M4.6
- Spec: ADR 0011 point 4, SPEC-01 §17, SPEC-06 §12.3
- Scope: `Tests/sim/` adapted from Accord: N complete clients with latency, loss, lockdown and trial accounts; scenarios for convergence, traffic per client against the budget, and A7 (an uninstalled user stays visible); the large scenario under `--long`.
- Done when:
  - [ ] 50 clients converge in the normal suite; the long scenario (≥ 1 000 clients) stays within the traffic budget.
- Tests: `test_sync_sim.lua`, the long scenario.
- Docs: SPEC-06 (measured numbers), SPEC-11 R3, CHANGELOG.
- Real client: nothing.

### M4.8 — Badges on the tooltip and the unit menu
- Branch: `step/m4-8-tooltip-menu`
- Model: Sonnet · medium
- Depends on: M4.5
- Spec: SPEC-08 §14.3-§14.4 (tooltip, menu)
- Scope: `Badges/Tooltip.lua` (`TooltipDataProcessor.AddTooltipPostCall`, the "Prestige:" line and the "what it measures" line), `Badges/UnitMenu.lua` ("Open Prestige profile"), the viewer's badge mode setting.
- Done when:
  - [ ] Secret unit names are skipped silently; the viewer's mode is respected.
- Tests: `test_badges_tooltip.lua`.
- Docs: wiki *Badges* (both languages), CHANGELOG.
- Real client: tooltips and menu (checklist).

### M4.9 — Badges on nameplates, target, focus and group frames
- Branch: `step/m4-9-plates-frames`
- Model: Opus · high
- Depends on: M4.8
- Spec: SPEC-08 §14.4 (nameplate, target, party/raid), SPEC-01 §9.6 (taint)
- Scope: `Badges/Nameplates.lua` (forbidden plates skipped, pooled textures), `Badges/GroupFrames.lua` (overlays on `CompactUnitFrame` created and moved only out of combat), target and focus overlays; budget of §17 for 50 plates.
- Done when:
  - [ ] No protected frame is touched in combat; A8 passes offline with forbidden plates.
- Tests: `test_badges_frames.lua` (combat deferral, forbidden plates, pool reuse).
- Docs: wiki *Badges*, CHANGELOG.
- Real client: cities, dungeons, raids, battlegrounds (checklist).

### M4.10 — Badges in chat
- Branch: `step/m4-10-chat`
- Model: Sonnet · high
- Depends on: M4.8
- Spec: SPEC-08 §14.4 (chat), SPEC-01 §3.2 point 3
- Scope: `Badges/Chat.lua`: a message event filter that prefixes the sender with `|T...|t`, turned off when the sender is secret or during chat lockdown; compatible with other filters.
- Done when:
  - [ ] No Lua error with secret senders; channels and whispers covered; the filter can be turned off.
- Tests: `test_badges_chat.lua`.
- Docs: wiki *Badges*, CHANGELOG.
- Real client: chat in and out of instances (checklist).

### M4.11 — Privacy and network settings, profile of others
- Branch: `step/m4-11-privacy-network`
- Model: Sonnet · medium
- Depends on: M4.10
- Spec: SPEC-08 §14.6 (Rete, Privacy), §14.2 (other players), Q21
- Scope: settings for the realm channel, relays, traffic level, detailed profile sharing, hide my badge, public alts opt-in per character; the Profile tab for another player (levels 1-2 always, 3 with their digest); `/azp privacy`; the trial warning.
- Done when:
  - [ ] Every privacy switch changes what is sent, proved by the simulator.
- Tests: `test_privacy_settings.lua`.
- Docs: wiki *Privacy and Data* (both languages), *Settings*, CHANGELOG.
- Real client: the settings.

### M4.12 — M4 in-game checklist
- Branch: `step/m4-12-checklist`
- Model: Sonnet · medium
- Depends on: M4.11
- Scope: `docs/checklists/M4.md`: two or more clients, every badge surface in and out of instances, attestations, lockdown queue, trial, traffic seen in `/azp debug`.
- Done when:
  - [ ] The checklist covers the exit criterion and A1, A7, A8, A9.
- Tests: `check_docs.py`.
- Docs: `docs/checklists/README.md`, CHANGELOG.
- Real client: the owner runs it.

### M4.13 — Release preparation `v0.4.0`
- Branch: `step/m4-13-release-prep`
- Model: Sonnet · medium
- Depends on: M4.12
- Scope: as M1.12, for `0.4.0`, with the public beta wording in the READMEs and the wiki; switches `network` and `badges` on.
- Done when:
  - [ ] Dry run green, zip inspected, changelog section `0.4.0`.
- Tests: the whole suite and the long tests.
- Docs: CHANGELOG, READMEs, wiki *Home*.
- Real client: the zip loads.
