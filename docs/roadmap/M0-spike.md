# M0 — API spike in the real client

**Goal:** answer in the real WoW Forever client the questions the design cannot answer offline: the checks V1-V21 of [SPEC-01 §3.3](../specs/SPEC-01-platform-architecture.md).

**Who:** the owner in game (ideally with a second character or a second player for messaging and group checks, and a character on a Hardcore realm for V17); the sessions prepare the probe and read the results.

**Exit criterion (in game):** `docs/spike/M0-results.md` answers V1-V21 with evidence, every affected spec and ADR is updated, and each area (Delver, Adventurer, Pathfinder, Artisan, Vanguard, Merchant, network, badges, celebrations, Hardcore) has a **go / revise** decision.

The probe addon `AzPr_Probe` lives in `tools/probe/`, is **never distributed**, wraps every call in `pcall`, checks every value with `issecretvalue` before using it, uses the test prefix `AzPrP`, and never prints or stores player, guild or realm names (counts and shapes only).

| Step | Title | Kind | Model | Effort |
|---|---|---|---|---|
| M0.0 | Bootstrap of the repository | architecture, documentation | Opus | high |
| M0.1 | Probe specification | specification, protected APIs | Opus | high |
| M0.2 | Probe skeleton | standard tooling on existing foundations | Sonnet | medium |
| M0.3 | Encounters, group levels and auras (V1, V19, V20, V21) | secret values | Opus | high |
| M0.4 | Nameplates, tooltip, menus, chat (V2, V3, V12, V13) | taint-sensitive APIs | Opus | high |
| M0.5 | Addon messages and encoding (V4, V5, V14) | network protocol | Opus | high |
| M0.6 | Sources of the trackers (V6-V11, V18) | many edge cases | Sonnet | high |
| M0.7 | UI state, restrictions CVar, Hardcore (V15, V16, V17) | standard checks | Sonnet | medium |
| M0.8 | Checklist: how to run the probe | checklist | Sonnet | low |
| M0.9 | Results and decisions | specification, architecture | Opus | high |

### M0.0 — Bootstrap of the repository
- Branch: `chore/m0-0-bootstrap`
- Model: Opus · high (the coordinating session)
- Depends on: the technical specification v0.4 (first commit)
- Spec: all; the owner's answers of 2026-11-26 (D-42 to D-46)
- Scope: the repository skeleton adapted from Azeroth Accord and Azeroth Unspoken ([ADR 0013](../adr/0013-reuse-azeroth-accord-and-unspoken-foundations.md)): `CLAUDE.md`, READMEs, licences, CONTRIBUTING, CHANGELOG, `.gitignore`, `.gitattributes`, `.luarc.json`, `.pkgmeta`; the tools `check_docs.py` (with the owner's names from `tools/local.ini` and the git identity), `check_pr_docs.py`, `ship_step.py` (no option to skip the tests), `release_notes.py`, `sync_wiki.py`; the workflows and the issue and pull request templates; ADRs 0001-0019; the specification split into SPEC-00 to SPEC-11; the roadmap M0-M7 with model and effort per step; the wiki *Home* and *About* in both languages; the logo source in `assets/`.
- Done when:
  - [x] `check_docs.py` passes; CI is green on the pull request.
  - [x] Every milestone file has its steps with branch, spec, scope, checks and model.
  - *Done:* bootstrap shipped as one noreply commit; no addon code yet (it starts in M1.2).
- Tests: `check_docs.py` (the Lua suite starts in M1.3).
- Docs: everything above.
- Real client: nothing.

### M0.1 — Probe specification
- Branch: `step/m0-1-probe-spec`
- Model: Opus · high
- Depends on: the bootstrap
- Spec: SPEC-01 §3 (all), §9.5, §9.6; SPEC-03 sources column; SPEC-08 §14.4
- Scope: `docs/spike/README.md` (in English): for each check V1-V21 the exact calls and events, where to run it (open world, dungeon, raid, battleground, in combat, during a boss), what counts as **go** and what as **revise**, and which spec or ADR each outcome changes. Group the checks into the probe areas of M0.3-M0.7. Add the probe's command list (`/azpp list|run <id>|export|reset`) and the record format `{id, result, details, build, time}`.
- Done when:
  - [x] Every V check has calls, places, go/revise criteria and the spec it may change.
  - [x] `check_docs.py` passes.
  - *Done:* [`docs/spike/README.md`](../spike/README.md) specifies V1-V21 plus `L` (content levels, R13), grouped by the areas of M0.3-M0.7, with the commands and the record format; names checked against the API dump (build 70170), with the ones it does not list marked. No probe code yet (M0.2).
- Tests: none (documentation step); `check_docs.py`.
- Docs: `docs/spike/README.md`, SPEC-01 §3.3 links to it, CHANGELOG.
- Real client: nothing yet.

### M0.2 — Probe skeleton
- Branch: `step/m0-2-probe-skeleton`
- Model: Sonnet · medium
- Depends on: M0.1
- Spec: `docs/spike/README.md`
- Scope: `tools/probe/AzPr_Probe/` (TOC 16001, adapted from Accord's `AzAc_Probe`), `/azpp list|run <id>|export|reset`, a check registry, results in `AzPr_ProbeDB`, an export frame with all results as text; `tools/install_probe.py` (copies the probe to the AddOns folder of `tools/local.ini`); `tools/local.example.ini` already has the path.
- Done when:
  - [x] Offline: files, commands, registry and install script exist; `check_docs.py` passes.
  - [ ] The probe loads on Forever and `/azpp list` lists the checks. *(in game)*
  - *Done (offline):* [`tools/probe/AzPr_Probe/`](../../tools/probe/AzPr_Probe/) with the 22 checks as stubs, `tools/install_probe.py` and `tools/check_probe.py` (run by `check_docs.py`); nothing loaded in the real client yet.
- Tests: a Python check that the probe TOC declares Interface 16001 and lists existing files.
- Docs: `docs/spike/README.md` (how to install), CHANGELOG.
- Real client: loading the probe.

### M0.3 — Encounters, group levels and auras (V1, V19, V20, V21)
- Branch: `step/m0-3-encounters-levels`
- Model: Opus · high
- Depends on: M0.2
- Spec: §3.3 V1, V19-V21; §7.2; §8.6.1
- Scope: log `ENCOUNTER_START`/`ENCOUNTER_END` payloads with `issecretvalue` per field, `BOSS_KILL`, `UnitIsAFK`, `UnitLevel` of group members and of hostile units far above the player (`-1`), `C_UnitAuras` `sourceUnit` on the player in and out of combat, `UnitIsUnit("nameplateNtarget", ...)` and `targettarget` outside instances; timing of `GROUP_ROSTER_UPDATE` and `UNIT_LEVEL`.
- Done when:
  - [x] Offline: the checks and their commands exist; `check_docs.py` passes.
  - [ ] V1, V19, V20, V21 answered with evidence. *(in game: a dungeon run, a group with a higher-level player, open-world assist)*
  - *Done (offline):* V1 in [`Checks_Encounters.lua`](../../tools/probe/AzPr_Probe/Checks_Encounters.lua), V19-V21 and `/azpp assist` in [`Checks_AntiBoost.lua`](../../tools/probe/AzPr_Probe/Checks_AntiBoost.lua), counters in `AzPr_ProbeDB.stats`; `tools/check_probe.py` checks the load order and which checks have code. Not run in the real client yet.
- Tests: the probe's Python file check.
- Docs: `docs/spike/README.md`, CHANGELOG.
- Real client: everything.

### M0.4 — Nameplates, tooltip, menus, chat (V2, V3, V12, V13)
- Branch: `step/m0-4-badge-surfaces`
- Model: Opus · high
- Depends on: M0.2
- Spec: §3.3 V2, V3, V12, V13; §14.4
- Scope: `UnitName`/`UnitGUID` on nameplate and tooltip units inside and outside instances (secret or not); `C_NamePlate.GetNamePlateForUnit` and `IsForbidden()` for friendly and enemy plates in the world, a dungeon and a battleground; a test texture anchored to a plate; `TooltipDataProcessor.AddTooltipPostCall` for units; `Menu.ModifyMenu("MENU_UNIT_PLAYER")` with a harmless entry; `ChatFrameUtil.AddMessageEventFilter` or `ChatFrame_AddMessageEventFilter` with a `|T...|t` prefix; any `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` recorded.
- Done when:
  - [x] Offline: the checks exist; `check_docs.py` passes.
  - [ ] V2, V3, V12, V13 answered; taint events listed. *(in game)*
  - *Done (offline):* V2, V3, V12 and V13 in [`Checks_BadgeSurfaces.lua`](../../tools/probe/AzPr_Probe/Checks_BadgeSurfaces.lua), with the test texture on the plates, the chat filter, the tooltip line, the menu entry, blocked actions attributed per surface and `/azpp surfaces` to switch each one off; `tools/check_probe.py` expects their code. Not run in the real client yet.
- Tests: the probe's Python file check.
- Docs: CHANGELOG.
- Real client: everything.

### M0.5 — Addon messages and encoding (V4, V5, V14)
- Branch: `step/m0-5-messaging`
- Model: Opus · high
- Depends on: M0.2
- Spec: §3.3 V4, V5, V14; §12
- Scope: `/azpp ping guild|party|raid|whisper <name>|channel`, pong replies, bursts to measure the throttle per distribution, every `Enum.SendAddonMessageResult`; joining a hidden custom channel (`JoinTemporaryChannel`), member counts, cross-faction delivery, removal from chat frames; `InChatMessagingLockdown()` snapshots in the open world, in combat, in a dungeon, during a boss and in a battleground; `C_EncodingUtil` serialize, compress, base64 roundtrip with sizes; a trial account if available.
- Done when:
  - [ ] Offline: the checks and commands exist; `check_docs.py` passes.
  - [ ] V4, V5, V14 answered; safe send rates per distribution written. *(in game, two clients)*
- Tests: the probe's Python file check.
- Docs: CHANGELOG.
- Real client: everything (two clients, two factions for cross-faction).

### M0.6 — Sources of the trackers (V6-V11, V18)
- Branch: `step/m0-6-tracker-sources`
- Model: Sonnet · high
- Depends on: M0.2
- Spec: §3.3 V6-V11, V18; §7
- Scope: `QUEST_TURNED_IN`, `C_QuestLog.IsQuestFlaggedCompleted`, quest level APIs; the Legacy system namespace and events (search the dump first); `GetPVPLifetimeStats`, `PVP_MATCH_COMPLETE`, `C_PvP.GetActiveMatchWinner`, `C_PvP.GetScoreInfo` (`killingBlows`), `DUEL_FINISHED` with the winner's system message; `C_MapExplorationInfo`, `UI_INFO_MESSAGE` "Discovered", `C_TaxiMap.GetAllTaxiNodes`; `GetProfessions`, `GetProfessionInfo`, skill-up and recipe events; Auction House presence, `GetInboxInvoiceInfo`, `TRADE_*`; **content levels**: what the client tells about a boss's, a quest's and a zone's level (risk R13).
- Done when:
  - [ ] Offline: the checks exist; `check_docs.py` passes.
  - [ ] V6-V11 and V18 answered; the source of content levels decided. *(in game)*
- Tests: the probe's Python file check.
- Docs: CHANGELOG.
- Real client: everything.

### M0.7 — UI state, restrictions CVar, Hardcore (V15, V16, V17)
- Branch: `step/m0-7-ui-state-hardcore`
- Model: Sonnet · medium
- Depends on: M0.2
- Spec: §3.3 V15-V17; §13.5; §15.3
- Scope: `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` types, `UnitOnTaxi`, boats and zeppelins, `CINEMATIC_*`, `LOADING_SCREEN_*`, `C_Calendar` access; the CVars that force addon restrictions in tests; Hardcore realm detection (game rules API) and `PLAYER_DEAD` on a Hardcore character.
- Done when:
  - [ ] Offline: the checks exist; `check_docs.py` passes.
  - [ ] V15, V16, V17 answered. *(in game)*
- Tests: the probe's Python file check.
- Docs: CHANGELOG.
- Real client: everything.

### M0.8 — Checklist: how to run the probe
- Branch: `step/m0-8-checklist`
- Model: Sonnet · low
- Depends on: M0.3-M0.7
- Scope: `docs/checklists/M0.md`: install, the order of the runs (world, dungeon, raid, battleground, two clients, Hardcore), what to export and where to paste it (the *In-game test report* issue form); the list of V checks with a box each.
- Done when:
  - [ ] The checklist covers V1-V21 and can be followed without reading the code.
- Tests: `check_docs.py`.
- Docs: `docs/checklists/README.md` lists it, CHANGELOG.
- Real client: the owner runs it.

### M0.9 — Results and decisions
- Branch: `step/m0-9-results`
- Model: Opus · high
- Depends on: the owner's run of M0.8
- Scope: `docs/spike/M0-results.md` (one row per check: result, evidence, consequence); updates to SPEC-01 to SPEC-09 where a result contradicts them (🔍 becomes ✅ or a revised design); new ADRs for changed decisions; SPEC-11 risks closed or revised; ROADMAP and README status.
- Done when:
  - [ ] Every check V1-V21 has a result and a consequence; go / revise per area written.
  - [ ] Every 🔍 of the specs is resolved or explicitly carried to a later milestone.
- Tests: `check_docs.py`.
- Docs: specs, ADRs, ROADMAP, both READMEs, CHANGELOG.
- Real client: the results are the owner's.
