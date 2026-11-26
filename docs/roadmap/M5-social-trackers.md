# M5 — Social trackers: Vanguard, Merchant, Diplomat, Steward

**Goal:** the four categories that involve other players, with the commendations and the Prestige Events that make the social ones measurable, and the Hardcore memorial.

**Exit criterion (in game):** a battleground win and its killing blows count for Vanguard; a duel series hits the diminishing returns; a trade between two characters of the same account gives 0 points with reason `ALT` (A11); a commendation reaches its target; a Prestige Event with five participants gives Steward points to the organiser and Diplomat points to the participants; a death on a Hardcore realm freezes the profile with the "Fallen" seal (A13).

**Release:** `v0.5.0` after M5.11.

| Step | Title | Kind | Model | Effort |
|---|---|---|---|---|
| M5.1 | Specification of the social trackers | specification | Opus | high |
| M5.2 | Vanguard | many edge cases | Sonnet | high |
| M5.3 | Merchant and crafting for others | many edge cases | Sonnet | high |
| M5.4 | Commendations (`CMD`) | security, network | Opus | high |
| M5.5 | Diplomat | many edge cases | Sonnet | high |
| M5.6 | Prestige Events (`EVT`) | network protocol | Opus | high |
| M5.7 | Steward | many edge cases | Sonnet | high |
| M5.8 | Events tab | UI | Sonnet | medium |
| M5.9 | Hardcore memorial | non-trivial data logic | Opus | medium |
| M5.10 | M5 in-game checklist | checklist | Sonnet | medium |
| M5.11 | Release preparation `v0.5.0` | release preparation | Sonnet | medium |

### M5.1 — Specification of the social trackers
- Branch: `step/m5-1-spec`
- Model: Opus · high
- Depends on: M4
- Spec: SPEC-03 §7.1, §7.5, §7.7, §7.8; SPEC-02 §8.2, §8.5; SPEC-07 §13.5; M0 results V8, V11, V17, V18
- Scope: final sources and context keys of the four categories; the `CMD` and `EVT` message layouts; the Commendation rules (Q18), the Event rules (Q19), the Diplomat/Steward border (Q20), `VAN_MIL_OBJ` (Q17); switches `vanguard`, `merchant`, `diplomat`, `steward`, `hardcore`.
- Done when:
  - [ ] Every rule of the four categories has a source and a test case listed.
- Tests: `check_docs.py`.
- Docs: SPEC-03, SPEC-06, SPEC-11, CHANGELOG.
- Real client: nothing.

### M5.2 — Vanguard
- Branch: `step/m5-2-vanguard`
- Model: Sonnet · high
- Depends on: M5.1
- Spec: SPEC-03 §7.1
- Scope: `Trackers/Vanguard.lua` behind `vanguard`: battleground win, loss, first match per battleground (≥ 70% of the duration), killing blows from the scoreboard, HK deltas of the lifetime counter, world PvP bonus, duels with DR, the daily cap per opponent and the level rule; anti-alt and anti-boost.
- Done when:
  - [ ] Leaving a battleground early gives nothing; duel DR follows §8.2.
- Tests: `test_vanguard.lua`.
- Docs: wiki *Categories* (Vanguard), CHANGELOG.
- Real client: battlegrounds and duels (checklist).

### M5.3 — Merchant and crafting for others
- Branch: `step/m5-3-merchant`
- Model: Sonnet · high
- Depends on: M5.1
- Spec: SPEC-03 §7.7, §7.6 (`ART_CRAFT_FOR_OTHER`), SPEC-02 §8.6.1 (A4)
- Scope: `Trackers/Merchant.lua` behind `merchant`: auction sales from invoices (log scale, distinct buyers, caps), new buyers, item variety, weekly streak, bilateral trades; `ART_CRAFT_FOR_OTHER` from a trade of a recently crafted item; zero points with characters in `myChars`; the A4 boost trigger on trades.
- Done when:
  - [ ] A11 passes; caps and distinct-buyer rules hold.
- Tests: `test_merchant.lua`.
- Docs: wiki *Categories* (Merchant, Artisan), CHANGELOG.
- Real client: auction house and trades (checklist).

### M5.4 — Commendations
- Branch: `step/m5-4-commendations`
- Model: Opus · high
- Depends on: M5.1
- Spec: SPEC-03 §7.5 (rules), SPEC-06 §12.2 (`CMD`)
- Scope: `Domain/Commendations.lua` behind `diplomat`: eligibility (15 min of group and a shared completed event in 24 h, level ≥ 20, profile ≥ 7 days), 5 per week, 1 per target per 7 days, value after 10 per week, anti-collusion after 5 from the same giver, types for Diplomat and Steward; `CMD` by whisper; the unit menu entry "Give a commendation".
- Done when:
  - [ ] Every limit is enforced by the giver and checked again by the receiver.
- Tests: `test_commendations.lua`.
- Docs: wiki *Commendations* (both languages), CHANGELOG.
- Real client: two clients (checklist).

### M5.5 — Diplomat
- Branch: `step/m5-5-diplomat`
- Model: Sonnet · high
- Depends on: M5.4
- Spec: SPEC-03 §7.5
- Scope: `Trackers/Diplomat.lua`: `DIP_HELP_LOW` (the mirror of the anti-boost rule), `DIP_MENTOR` attested by the helped player, `DIP_COMMEND`, `DIP_EVENT_ATTEND` and `DIP_RP_EVENT` (with M5.6), `DIP_GUILD_WELCOME`.
- Done when:
  - [ ] A15 passes on the helper's side; no Diplomat point between characters of the same account.
- Tests: `test_diplomat.lua`.
- Docs: wiki *Categories* (Diplomat), CHANGELOG.
- Real client: a low-level group (checklist).

### M5.6 — Prestige Events
- Branch: `step/m5-6-events`
- Model: Opus · high
- Depends on: M5.1
- Spec: SPEC-03 §7.8 (Prestige Events), SPEC-06 §12.2 (`EVT`)
- Scope: `Domain/Events.lua`: create, announce on guild and the channel, check-in near the organiser with mutual confirmation by whisper, close after 20 min-4 h, `EVT_ATTEND` attestations, organiser's alts not counted.
- Done when:
  - [ ] An event below 5 participants or 20 minutes gives nothing; check-ins far away are refused.
- Tests: `test_events.lua` (with the simulator).
- Docs: wiki *Prestige Events* (both languages), CHANGELOG.
- Real client: an event with several players (checklist).

### M5.7 — Steward
- Branch: `step/m5-7-steward`
- Model: Sonnet · high
- Depends on: M5.6
- Spec: SPEC-03 §7.8 (rules)
- Scope: `Trackers/Steward.lua` behind `steward`: event host, event series, recruits still in the guild after 14 days, guild role weekly, commendations, group leader of a completed instance or won battleground.
- Done when:
  - [ ] No action gives points to both Diplomat and Steward (Q20).
- Tests: `test_steward.lua`.
- Docs: wiki *Categories* (Steward), CHANGELOG.
- Real client: guild invite and roster (checklist).

### M5.8 — Events tab
- Branch: `step/m5-8-events-tab`
- Model: Sonnet · medium
- Depends on: M5.6, M5.4
- Spec: SPEC-08 §14.1 (Eventi)
- Scope: `UI/EventsView.lua`: create and run an event, check in, commendations given and received.
- Done when:
  - [ ] The whole event flow works from the tab in both languages.
- Tests: `test_events_view.lua`.
- Docs: wiki *Prestige Events*, previews, CHANGELOG.
- Real client: the tab.

### M5.9 — Hardcore memorial
- Branch: `step/m5-9-hardcore`
- Model: Opus · medium
- Depends on: M5.1
- Spec: SPEC-07 §13.5
- Scope: Hardcore detection (V17), `hc.dead` published with date and zone, points frozen and later events refused, the "Fallen" seal on badges and profile.
- Done when:
  - [ ] A13 passes in the simulator.
- Tests: `test_hardcore.lua`.
- Docs: wiki *Hardcore* (both languages), CHANGELOG.
- Real client: a Hardcore death (checklist).

### M5.10 — M5 in-game checklist
- Branch: `step/m5-10-checklist`
- Model: Sonnet · medium
- Depends on: M5.9
- Scope: `docs/checklists/M5.md`: battlegrounds, duels, auction house, trades between alts, commendations, an event, a low-level group, a Hardcore death.
- Done when:
  - [ ] The checklist covers the exit criterion and the "real client" items of M5.
- Tests: `check_docs.py`.
- Docs: `docs/checklists/README.md`, CHANGELOG.
- Real client: the owner runs it.

### M5.11 — Release preparation `v0.5.0`
- Branch: `step/m5-11-release-prep`
- Model: Sonnet · medium
- Depends on: M5.10
- Scope: as M1.12, for `0.5.0`; the M5 switches on.
- Done when:
  - [ ] Dry run green, zip inspected, changelog section `0.5.0`.
- Tests: the whole suite and the long tests.
- Docs: CHANGELOG, READMEs, wiki *Home*.
- Real client: the zip loads.
