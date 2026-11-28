# Spike: the probe specification

Milestone M0 answers, in the real WoW Forever client, the questions the design cannot answer offline: the checks V1-V21 of [SPEC-01 §3.3](../specs/SPEC-01-platform-architecture.md) (in Italian). This file is the **specification of the probe addon** `AzPr_Probe`: for every check, the exact calls and events, where to run it, what counts as **go** and what as **revise**, and which spec or ADR each outcome changes. The skeleton (commands, check registry, records, export) is in place since step M0.2; the checks arrive with M0.3-M0.7 ([roadmap](../roadmap/M0-spike.md)); the results go to `docs/spike/M0-results.md` in step M0.9.

## Install

1. Copy `tools/local.example.ini` to `tools/local.ini` (git-ignored) and set `addons` to the `_forever_/Interface/AddOns` folder of your WoW installation.
2. Run:

```bash
python -I -X utf8 tools/install_probe.py
```

3. In game, `/reload` (or restart the client). The chat shows "AzPr Probe: loaded"; `/azpp list` lists the 22 checks.

Run the installer again after every update of the probe, then `/reload`: it replaces the `AzPr_Probe` folder, and the results in `AzPr_ProbeDB` survive. If the client says the addon is out of date, enable "Load out of date AddOns" and note it in the report.

| File of `tools/probe/AzPr_Probe/` | Content | Since |
|---|---|---|
| `AzPr_Probe.lua` | safe calls, shapes, context detection, records and logs, commands, export frame, blocked-action log | M0.2 |
| `Checks.lua` | the check registry V1-V21 and `L` (stubs that record `todo`) | M0.2 |

Offline, `tools/check_probe.py` (run by `tools/check_docs.py`) verifies that the TOC declares Interface 16001, that the files it lists exist and that the registry has every check.

## Rules of the probe

- It lives in `tools/probe/AzPr_Probe/` and is **never distributed**: no release, no `.pkgmeta` entry.
- Every game API call is wrapped in `pcall`. A function that does not exist is recorded as `absent`, never called.
- Every returned value is tested with `issecretvalue` **before** any comparison, arithmetic, indexing or string use. A secret value is recorded as `secret` and dropped.
- It never prints or stores player, guild, channel or realm names, nor GUIDs: only counts, types, field names, `self` / `other`, and booleans such as "matches the group member".
- It uses the test addon-message prefix `AzPrP`, never the real prefix of the addon.
- It never touches protected frames in combat and never calls protected functions. Hooks are post-hooks (`hooksecurefunc`, `HookScript`, the official callbacks); it never replaces a Blizzard function. It logs every `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` from login on, under `logs.taint` (the addon only as `self` / `other`).
- It never changes a CVar or a game setting by itself (V16 only reads them).

## Names, the API dump and "absent"

The exact names below come from the WoW Forever API dump kept next to this repository (`../WoW-Addons/docs/api.json`, consulted and never copied, [ADR 0002](../adr/0002-wow-forever-target-and-api-dump.md)): version 1.60.1, build 70170, interface 16001, exported on 2026-10-01. The live client may run a different build (SPEC-01 §3.1 says 69913): the probe records `GetBuildInfo()` with every result.

The dump has two parts, and "absent" means different things for each:

- **The documented C API** (systems, functions, events, structures, enumerations): what the client's own `/api` documentation exposes. An event or C function missing there is very likely missing in the client.
- **A snapshot of the global table**, limited to global functions and `C_*` namespaces. Blizzard Lua tables such as `Menu`, `TooltipDataProcessor`, `ChatFrameUtil`, `EventRegistry` and `Enum`, frame methods (`IsForbidden`, `HookScript`, `GetUnit`) and global strings (`ERR_ZONE_EXPLORED`, `DUEL_WINNER_KNOCKOUT`) are **never** in the snapshot, so for them "absent" only means "check at run time".

Two more limits of the dump matter for M0:

- It carries **no secret-value markers**: whether a value is secret in a given context can only be measured in game. The dump does document the `C_Secrets` predicates (`ShouldUnitIdentityBeSecret`, `ShouldUnitComparisonBeSecret`, `CanCompareUnitTokens`, `ShouldAurasBeSecret`, `ShouldUnitAuraInstanceBeSecret`, `HasSecretRestrictions`, ...); the probe records what they predict next to what it observes, so that the real addon can ask them first.
- Several types named in signatures are **not defined** in it: the enumerations `SendAddonMessageResult`, `RegisterAddonMessagePrefixResult`, `AddOnRestrictionType`, `AddOnRestrictionState`, `PlayerInteractionType`, `GameMode`, `GameRule`, and the structures `AuraData` and `UnitAuraUpdateInfo`. The probe reads them at run time (every key and value of `Enum.<Name>`, every field of a returned table) and stores their shape.

In the checks below, a name followed by *(not in the dump)* is one the dump does not list; everything else is in the dump.

## Where to run: contexts

| Tag | Context |
|---|---|
| **W** | Open world, out of combat (a city counts as W) |
| **WC** | Open world, in combat (a mob is enough; with another player around when the check says so) |
| **D** | Inside a dungeon, out of combat |
| **DB** | During a dungeon boss encounter (between `ENCOUNTER_START` and `ENCOUNTER_END`) |
| **R** / **RB** | Inside a raid (Barrow Deeps is the smallest) / during a raid boss |
| **BG** | Inside a battleground (Darkspear Islands), during the match and at its end |
| **2C** | Needs a second client or a second player running the probe (**2CX**: of the opposite faction) |
| **HC** | Needs a character on a Hardcore realm |
| **LS** | Across a loading screen (entering and leaving an instance) |

Each check stores one log line per context it was run in, tagged with the context the probe detects by itself (`IsInInstance()`, `GetInstanceInfo()`, `InCombatLockdown()`, `C_InstanceEncounter.IsEncounterInProgress()`, `C_PvP.IsBattleground()`). A check is `pass` only when all its required contexts are covered.

## Commands

| Command | What it does |
|---|---|
| `/azpp` or `/azpp list` | Lists the checks V1-V21 (plus `L` for content levels) with a short description, the contexts still missing and the last result |
| `/azpp run <id>` | Runs one check now in the current context, for example `/azpp run V3`. Checks that need an event (an encounter, a turn-in, a match end) arm a watcher and complete when the event arrives; the chat line says so |
| `/azpp export` | Opens a movable frame with every result and every log as plain text, already selected: press Ctrl+C and paste it into the *In-game test report* issue form |
| `/azpp reset` | Asks for confirmation: `/azpp reset confirm` clears every result and log (never needed between the contexts of one check) |
| `/azpp help` | Lists the commands of the installed version |

Steps M0.3-M0.7 add the helper commands their checks need (for example `/azpp ping guild|party|raid|whisper <name>|channel`, a burst and a lockdown snapshot in M0.5); they are documented in this file by those steps, and `/azpp help` always lists the ones the installed version has. A character name typed in a command is used once and never stored.

## Record format

The probe saves everything in the SavedVariable `AzPr_ProbeDB`:

```lua
AzPr_ProbeDB = {
  schema = 1,
  results = {
    V1 = { id = "V1", result = "pass", details = "DB 3 kills, RB 1 kill: 5/5 fields readable; BOSS_KILL after END",
           build = "1.60.1 70170 16001", time = 1764300000 },
  },
  logs = {
    V1 = { "DB | ENCOUNTER_END | encounterID=number encounterName=string difficultyID=number groupSize=number success=number encounterUnitStatus=table" },
  },
  covered = {
    V1 = { DB = true },
  },
}
```

`covered` holds the contexts each check has been run in, apart from the logs, so that the cap on the logs never loses them; `/azpp list` shows the required ones still missing. A check that raises an error records `info` with the `error:` text.

| Field | Content |
|---|---|
| `id` | The check id: `V1` … `V21`, or `L` (content levels, part of M0.6) |
| `result` | `pass`: the go criteria hold in every required context. `fail`: at least one revise condition was observed. `info`: data recorded, the decision needs a human reading (M0.9). `todo`: not implemented yet, or required contexts not run yet (they are listed in `details`) |
| `details` | One line, at most 240 characters: counts, shapes and the contexts covered or missing. Never a name |
| `build` | `GetBuildInfo()` as `"<version> <build> <interface>"` |
| `time` | `time()` when the record was written (seconds since the epoch) |

Values in logs are written as **shapes**: `number`, `string`, `boolean`, `table(<n> keys)`, `nil`, `secret`, `absent` (the function does not exist), `error: <first 80 characters>` (the `pcall` failed). Numbers that carry no personal data (ids, levels, counts, result codes, milliseconds) are written as values. Logs are capped at 200 lines per check, oldest dropped first. The export frame prints one line per result (`V1 | pass | <details> | <build> | <time as UTC ISO date>`), then the logs.

## Checks by probe area

| Step | Area | Checks | What they decide |
|---|---|---|---|
| M0.3 | Encounters, group levels and auras | V1, V19, V20, V21 | Delver source; anti-boost triggers G, A1, A2, A3 |
| M0.4 | Nameplates, tooltip, menus, chat | V2, V3, V12, V13 | Every badge surface |
| M0.5 | Addon messages and encoding | V4, V5, V14 | Transport, discovery, send queue, codec |
| M0.6 | Sources of the trackers | V6, V7, V8, V9, V10, V11, V18, L | Adventurer, Pathfinder, Vanguard, Artisan, Merchant, Legacy, content levels |
| M0.7 | UI state, restrictions CVar, Hardcore | V15, V16, V17 | Celebrations, QA, Hardcore memorial |

The go / revise decision of each area of the [M0 exit criterion](../roadmap/M0-spike.md) rests on: **Delver** V1 · **Adventurer** V6, V7, L · **Pathfinder** V7, V9 · **Artisan** V10 · **Vanguard** V8, V18 · **Merchant** V11 · **network** V4, V5, V14 · **badges** V2, V3, V12, V13 · **celebrations** V15 · **Hardcore** V17. V19-V21 decide the anti-boost rule of [SPEC-02 §8.6](../specs/SPEC-02-progression-scoring.md), which every area depends on; V16 decides how restricted states are tested from M1 on.

---

## M0.3: encounters, group levels and auras

### V1: `ENCOUNTER_END` with readable values

- **Calls and events:** `ENCOUNTER_START(encounterID, encounterName, difficultyID, groupSize)`; `ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success, encounterUnitStatus)` (the dump adds `encounterUnitStatus`, a table the spec does not know: record its shape); `BOSS_KILL(encounterID, encounterName)` and its order and delay relative to `ENCOUNTER_END`; `issecretvalue` on every payload field and on every field of `encounterUnitStatus`; `C_InstanceEncounter.IsEncounterInProgress()`; `GetInstanceInfo()` (`instanceType`, `difficultyID`, `maxPlayers`, `instanceID`); `UnitIsAFK(unit)` and `UnitIsConnected(unit)` for `party1..4` / `raid1..40` at `ENCOUNTER_END`; `C_Secrets.HasSecretRestrictions()`. Fallback sources measured at the same time: `UPDATE_INSTANCE_INFO` with `GetNumSavedInstances()` / `GetSavedInstanceInfo(index)`, `C_RaidLocks.IsEncounterComplete(...)`, `ENCOUNTER_LOOT_RECEIVED`, `CHAT_MSG_SYSTEM` (count only).
- **Where:** DB (a kill and, if it happens, a wipe), RB (at least one kill), across LS (does an encounter survive a disconnect or reload?).
- **Go:** `ENCOUNTER_END` arrives once per pull in dungeons and raids; the five spec fields are never secret; `success` is `1` on a kill and `0` on a wipe; `encounterID` is the same as `BOSS_KILL`'s and stable across runs; `UnitIsAFK` of group members is readable at that moment.
- **Revise:** any of the five fields secret, the event missing in a context, or `success` unreliable: Delver moves to `BOSS_KILL` plus the saved-instance or raid-lock state; `UnitIsAFK` secret: the "not AFK" eligibility is measured another way or dropped.
- **Changes:** [SPEC-03 §7.2](../specs/SPEC-03-activity-catalog.md) (Delver source and eligibility), [SPEC-02 §8.6.2](../specs/SPEC-02-progression-scoring.md) (the boss window `ENCOUNTER_START`..`END`), [SPEC-09 §15.3](../specs/SPEC-09-celebrations.md) (encounter blocking condition), risk R1 of [SPEC-11](../specs/SPEC-11-risks-open-questions.md); a Delver redesign gets a new ADR.

### V19: `UnitLevel` of group members and of far higher hostile players

- **Calls and events:** `UnitLevel(unit)` for `player`, `party1..4`, `raid1..40`, `target` and hostile `nameplateN` players; `issecretvalue` on the level; `UnitIsPlayer`, `UnitIsConnected`, `UnitInParty`, `UnitInRaid`, `IsInGroup`, `IsInRaid`, `GetNumGroupMembers`; `GROUP_ROSTER_UPDATE`, `UNIT_LEVEL(unitTarget)`, `PLAYER_LEVEL_UP(level, ...)`; the delay between `GROUP_ROSTER_UPDATE` and the first valid level of a new member (levels read 0, 1 and 3 seconds later).
- **Where:** W with a group member at least 10 levels higher, near, far (another zone) and offline; D, R and BG with the same group; W on a PvP realm (or BG) with a hostile player far above the probe character.
- **Go:** the level of every group member is a non-secret number in every context, also far away and offline, and valid within 1 second of the roster event; a hostile player 10 or more levels higher returns `-1`.
- **Revise:** levels secret, `0` or missing for far or offline members: trigger G uses the last level seen (cached per GUID) or the level the member's own client reports; `-1` never returned (or returned for other reasons): the A1 rule cannot treat `-1` as "+10".
- **Changes:** [SPEC-02 §8.6.1](../specs/SPEC-02-progression-scoring.md) (trigger G, the note on `-1`), §8.6.3 (`c.gmx` recomputed by peers), `Domain/Boost.lua` (M1.9).

### V20: `sourceUnit` of the auras on the player

- **Calls and events:** `UNIT_AURA(unitTarget, updateInfo)` for `player` (shape of `updateInfo`, *`UnitAuraUpdateInfo` not in the dump*: `addedAuras`, `isFullUpdate`, ...); `C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceID)`, `C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")`, `C_UnitAuras.GetPlayerAuraBySpellID(spellID)`; the fields `sourceUnit`, `isFromPlayerOrPlayerPet`, `spellId` of the returned aura (*`AuraData` not in the dump*), each through `issecretvalue`; `C_Secrets.ShouldAurasBeSecret()` and `C_Secrets.ShouldUnitAuraInstanceBeSecret("player", auraInstanceID)` next to the observation; for a readable source, `UnitInParty(sourceUnit)`, `UnitIsPlayer(sourceUnit)` and `UnitLevel(sourceUnit)`.
- **Where:** W (a buff from a player outside the group, out of combat), WC (a heal or buff from a player outside the group while the probe character fights), D and DB for contrast. Needs a helper: 2C or a willing stranger.
- **Go:** in the open world, in and out of combat, `sourceUnit` of a helpful aura cast by another player is readable and its level can be read.
- **Revise:** `sourceUnit` secret in combat: trigger A3 is dropped or limited to auras received in the 60 seconds before combat; secret everywhere: A3 is dropped and the rule relies on G, A1 and A2.
- **Changes:** [SPEC-02 §8.6.1](../specs/SPEC-02-progression-scoring.md) (trigger A3), question Q12 of [SPEC-11](../specs/SPEC-11-risks-open-questions.md) (the 60-second window).

### V21: `nameplateNtarget` and `targettarget` comparisons

- **Calls and events:** `UnitIsUnit("nameplateNtarget", "target")`, `UnitIsUnit("nameplateNtarget", "player")`, `UnitIsUnit("targettarget", unit)` with `unit` a nearby out-of-group player; `issecretvalue` on each result; `C_Secrets.CanCompareUnitTokens(unit1, unit2)` (the dump says comparison APIs fail when it returns false) and `C_Secrets.ShouldUnitComparisonBeSecret(unit1, unit2)`; `UnitExists`, `UnitIsPlayer`, `UnitAffectingCombat` and `UnitLevel` of the plate unit; the cost of one full scan of the visible plates measured with `debugprofilestop()`.
- **Where:** WC with a higher-level out-of-group player hitting the probe character's target (A1) and tanking it (A2); W for the baseline; D for contrast. Needs a helper (2C).
- **Go:** the comparisons are non-secret in the open world, in combat; a scan of 20 plates costs well under the 2 Hz budget of [SPEC-01 §17](../specs/SPEC-01-platform-architecture.md).
- **Revise:** comparisons secret or refused in combat: triggers A1 and A2 are dropped, the rule relies on G (and A3 if V20 passes); too expensive: lower scan rate or fewer plates.
- **Changes:** [SPEC-02 §8.6.1](../specs/SPEC-02-progression-scoring.md) (triggers A1, A2), [SPEC-01 §17](../specs/SPEC-01-platform-architecture.md) (anti-boost scan budget).

## M0.4: nameplates, tooltip, menus, chat

### V2: player identity on nameplates and tooltips

- **Calls and events:** `UnitName(unit)` and `UnitGUID(unit)` with `issecretvalue` on both returns (the dump types `UnitGUID`'s argument as `UnitTokenPvPRestrictedForAddOns`: a hint that GUIDs may be withheld in PvP contexts); `C_Secrets.ShouldUnitIdentityBeSecret(unit)` next to the observation; units from `NAME_PLATE_UNIT_ADDED(unitToken)`, `UPDATE_MOUSEOVER_UNIT` (`mouseover`), `PLAYER_TARGET_CHANGED` (`target`) and the unit of the unit tooltip (`GameTooltip:GetUnit()`, *a frame method, not in the dump*); `UnitIsPlayer`, `UnitIsUnit(unit, "partyN")` to tell group members apart; `GetNormalizedRealmName()` once for the probe character (the `charKey` of [SPEC-02](../specs/SPEC-02-progression-scoring.md)).
- **Where:** W (city: friendly and, on a PvP realm, hostile players), WC, D, DB, R, BG.
- **Go:** name and GUID of other players are readable in W and WC; in instances at least the group members' identity is readable out of combat; the `C_Secrets` predicate agrees with what is observed.
- **Revise:** identity secret in a context: there the badge lookup returns nothing (`Restrictions.SafeGet`, [SPEC-01 §9.6](../specs/SPEC-01-platform-architecture.md)) and the surface falls back to group frames keyed by the roster read out of combat; secret also in W: badges only on surfaces whose unit is the target or a group member.
- **Changes:** [SPEC-08 §14.4](../specs/SPEC-08-ui-badges.md) (surfaces per context), [SPEC-01 §3.2](../specs/SPEC-01-platform-architecture.md) items 3 and 4, [SPEC-02 §6.1](../specs/SPEC-02-progression-scoring.md) (GUID stored with the `charKey`), risk R4.

### V3: nameplates, forbidden or not

- **Calls and events:** `NAME_PLATE_CREATED(namePlateFrame)`, `NAME_PLATE_UNIT_ADDED(unitToken)`, `NAME_PLATE_UNIT_REMOVED(unitToken)`; `C_NamePlate.GetNamePlateForUnit(unitToken, includeForbidden)` called with `false` and with `true` (the dump adds the second argument); `plate:IsForbidden()` (*frame method, not in the dump*); a 16 px test texture created on the probe's own frame and anchored to a non-forbidden plate, shown and hidden as the plate comes and goes; `ADDON_ACTION_BLOCKED(isTainted, function)` and `ADDON_ACTION_FORBIDDEN(isTainted, function)` counted while doing it. Counts per context: friendly and enemy plates, returned, `nil`, forbidden.
- **Where:** W (friendly and enemy plates), WC, D, DB, R, BG.
- **Go:** outside instances friendly and enemy plates are returned and not forbidden, and the anchored texture causes no blocked or forbidden action; inside instances enemy plates are usable.
- **Revise:** friendly plates forbidden in instances (expected): the group frames and the target frame stay the main surface there, as planned; plates forbidden also outside instances, or the anchor taints: the nameplate surface is dropped or limited to enemies.
- **Changes:** [SPEC-08 §14.4](../specs/SPEC-08-ui-badges.md) (nameplate row), [SPEC-01 §3.2](../specs/SPEC-01-platform-architecture.md) item 4, risk R4.

### V12: chat message filters

- **Calls and events:** `ChatFrame_AddMessageEventFilter(event, filter)` and `ChatFrame_RemoveMessageEventFilter(event, filter)` (in the dump's globals); `ChatFrameUtil.AddMessageEventFilter` *(not in the dump: a Lua table, looked up at run time)*; a filter on `CHAT_MSG_SAY`, `CHAT_MSG_YELL`, `CHAT_MSG_GUILD`, `CHAT_MSG_PARTY`, `CHAT_MSG_RAID`, `CHAT_MSG_WHISPER`, `CHAT_MSG_CHANNEL` that tests the sender (argument 2) and the GUID (argument 12) with `issecretvalue`, compares only with the probe character (`self` / `other`) and, when both are readable, returns the message with a `|T<texture>:14|t` prefix; `C_ChatInfo.GetChatLineSenderGUID(lineID)`; `C_ChatInfo.InChatMessagingLockdown()` at each message; blocked and forbidden actions counted.
- **Where:** W (say, guild, whisper, a public channel), WC, D, DB (party chat during a boss), BG. 2C helps.
- **Go:** at least one of the two filter APIs exists; sender and GUID are readable outside lockdown; the texture shows before the line and no action is blocked afterwards.
- **Revise:** only one API: the compatibility layer picks it; sender secret in instances: chat badges switch off in lockdown, as planned; sender secret everywhere or no filter API: chat badges dropped.
- **Changes:** [SPEC-08 §14.4](../specs/SPEC-08-ui-badges.md) (chat row), [SPEC-01 §3.2](../specs/SPEC-01-platform-architecture.md) item 3, [SPEC-01 §19.1](../specs/SPEC-01-platform-architecture.md) (chat addons).

### V13: unit tooltip and unit menu

- **Calls and events:** `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, fn)` *(not in the dump: Lua table and enumeration; the dump does have `C_TooltipInfo.GetUnit` and the global `AddTooltipDataAccessor`, which point to the modern tooltip data system)*; fallback `GameTooltip:HookScript("OnTooltipSetUnit", fn)` *(not in the dump)*; in the callback, `GameTooltip:GetUnit()` and one added line. `Menu.ModifyMenu("MENU_UNIT_PLAYER", fn)` *(not in the dump: `Menu` is a Lua table)*, plus the tags `MENU_UNIT_PARTY`, `MENU_UNIT_RAID_PLAYER`, `MENU_UNIT_FRIEND`, `MENU_UNIT_TARGET`, `MENU_UNIT_SELF` to learn which one opens from the target frame, a group frame and a chat name; the dump's globals have the older `UnitPopup_OpenMenu` and `UIDropDownMenu_*`, so the probe records whether `Menu` exists at all; a harmless entry that only prints "probe menu entry"; then a Blizzard entry of the same menu (whisper, invite) to check for blocked or forbidden actions.
- **Where:** W, WC (tooltip in combat), D, BG.
- **Go:** both hooks exist and fire with the unit identified (subject to V2); the menu entry appears and the Blizzard entries still work with no blocked action.
- **Revise:** `TooltipDataProcessor` missing: the `OnTooltipSetUnit` hook; `Menu` missing: the menu surface waits for a safe alternative (no hooks on `UnitPopup` that could taint) and its feature switch stays off; a taint: the surface is dropped.
- **Changes:** [SPEC-08 §14.4](../specs/SPEC-08-ui-badges.md) (tooltip and menu rows), `Badges/Tooltip.lua` and `Badges/UnitMenu.lua` (M4), risk R14 (compatibility layer).

## M0.5: addon messages and encoding

### V4: addon messages on a custom channel

- **Calls and events:** `C_ChatInfo.RegisterAddonMessagePrefix("AzPrP")` (result *`RegisterAddonMessagePrefixResult` not in the dump*); `JoinTemporaryChannel(name)` and `JoinChannelByName(name)` (globals) with a test channel name, `GetChannelName(name)` for the channel id, `C_ChatInfo.GetChannelInfoFromIdentifier`, `C_ChatInfo.GetNumActiveChannels()`, member count through `C_ChatInfo.GetChannelRosterInfo(channelIndex, rosterIndex)` (count only), `CHAT_MSG_CHANNEL_NOTICE`, `ChatFrame_RemoveChannel(frame, name)` on every chat frame, `LeaveChannelByName(name)`; `C_ChatInfo.SendAddonMessage(prefix, message, "CHANNEL", channelID)` with every returned code mapped through `Enum.SendAddonMessageResult` *(not in the dump: all keys recorded at run time)*; `CHAT_MSG_ADDON(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)` on the other client; `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` (the dump says this is set realm by realm). Message sizes 100 to 300 bytes; bursts of 10, 20, 50 at gaps of 1, 0.5, 0.25 and 0 seconds, counting codes and missing messages on the receiver. Same sizes and bursts on `GUILD`, `PARTY`, `RAID` and `WHISPER` for the comparison, and a trial account if one is available (expected: cannot send).
- **Where:** W in a city, 2C of the same faction and 2CX of the opposite faction; one send from D and BG for contrast.
- **Go:** the channel joins without visible chat lines and stays out of the chat frames; 255-byte messages pass; the throttle is at least the documented one (10 in a burst, then 1 per second) and reported by the result code, not by silent loss; the opposite faction receives; the member count is readable.
- **Revise:** the channel cannot be joined, loses messages, has a low throttle or is not cross-faction: discovery falls back to beacons on `GUILD`, `PARTY` and `RAID` with lazy fetch over `WHISPER`, and leaderboards become more local (risk R2).
- **Changes:** [SPEC-06 §12.1 and §12.3](../specs/SPEC-06-network-protocol.md) (transport, discovery), [ADR 0005](../adr/0005-versioned-peer-to-peer-protocol.md), [SPEC-01 §3.1](../specs/SPEC-01-platform-architecture.md) (messaging and trial rows), risk R2.

### V5: when `AddOnMessageLockdown` applies

- **Calls and events:** `C_ChatInfo.InChatMessagingLockdown()`; `C_RestrictedActions.IsAddOnRestrictionActive(type)` and `C_RestrictedActions.GetAddOnRestrictionState(type)` for every value of `Enum.AddOnRestrictionType` *(enumerations not in the dump)*; `ADDON_RESTRICTION_STATE_CHANGED(type, state)` with the time of each change (the dump says `IsAddOnRestrictionActive` always returns false while this event is dispatched, so the probe reads the payload); `C_Secrets.HasSecretRestrictions()`; `InCombatLockdown()`, `UnitAffectingCombat("player")`, `IsInInstance()`, `C_InstanceEncounter.IsEncounterInProgress()`, `C_PvP.IsBattleground()`; one test send per distribution (`GUILD`, `PARTY`, `RAID`, `INSTANCE_CHAT`, `WHISPER`, `CHANNEL`) with its result code (`AddOnMessageLockdown` is 11 according to SPEC-01 §3.1); whether `CHAT_MSG_ADDON` still arrives during lockdown; the delay between `ENCOUNTER_END` or `PLAYER_REGEN_ENABLED` and the end of the lockdown.
- **Where:** W, WC, D, DB, R, RB, BG, across LS. 2C for the receiving side.
- **Go:** the lockdown is limited to encounters (and possibly combat in instances), the flag and the result code agree, and its end is signalled by an event, so the send queue can resume without polling.
- **Revise:** lockdown for the whole stay in an instance, in every combat, or with no event at its end: the queue keeps messages longer, polls `InChatMessagingLockdown()` on a timer, and instance-only features (attestations after a boss) move to after the instance.
- **Changes:** [SPEC-01 §3.2](../specs/SPEC-01-platform-architecture.md) item 2 and the `Restrictions` module of §9.2, [SPEC-06 §12.1](../specs/SPEC-06-network-protocol.md) (queue), [SPEC-05 §11.3](../specs/SPEC-05-ledger-trust.md) (when attestations can be exchanged), [ADR 0005](../adr/0005-versioned-peer-to-peer-protocol.md).

### V14: `C_EncodingUtil`

- **Calls and events:** `C_EncodingUtil.SerializeCBOR(value, options)` / `DeserializeCBOR`, `SerializeJSON` / `DeserializeJSON`, `CompressString(source, method, level)` / `DecompressString` with every `Enum.CompressionMethod` (`Deflate`, `Zlib`, `Gzip`) and `Enum.CompressionLevel` (`Default`, `OptimizeForSpeed`, `OptimizeForSize`), `EncodeBase64(source, variant)` / `DecodeBase64` with `Enum.Base64Variant` (`Standard`, `StandardUrlSafe`), `EncodeHex` / `DecodeHex`; a round trip of an invented profile of about 2 KB and 20 KB (nested tables, integers, floats, strings with `|` and non-ASCII letters), checked field by field; sizes at each stage; milliseconds with `debugprofilestop()`; whether the same input gives the same bytes twice; whether the output contains `\0` (forbidden in addon messages); one compressed and Base64-encoded chunk sent over `WHISPER` to 2C and decoded there.
- **Where:** W, and WC to check that nothing is restricted in combat. 2C for the last test.
- **Go:** every function exists, round trips are exact, the output is deterministic, the Base64 output passes through `SendAddonMessage` unchanged.
- **Revise:** functions missing or lossy: LibSerialize and LibDeflate are embedded instead.
- **Changes:** [SPEC-01 §9.5](../specs/SPEC-01-platform-architecture.md) (libraries), [ADR 0006](../adr/0006-embedded-ace3-savedvariables-and-schema-versions.md) and `.pkgmeta`, the codec of [SPEC-06 §12.1](../specs/SPEC-06-network-protocol.md).

## M0.6: sources of the trackers

### V6: quests

- **Calls and events:** `QUEST_TURNED_IN(questID, xpReward, moneyReward)` (payload through `issecretvalue`); `C_QuestLog.IsQuestFlaggedCompleted(questID)` at the event and 1 second later; `C_QuestLog.GetAllCompletedQuestIDs()` (count and milliseconds, for the backfill); `C_QuestLog.GetQuestDifficultyLevel(questID)` (see L); `C_QuestLog.GetQuestTagInfo(questID)` (elite or group flag), `C_QuestLog.IsRepeatableQuest`, `C_QuestLog.IsQuestReplayable`; `QUEST_ACCEPTED`, `QUEST_REMOVED`, `QUEST_LOG_UPDATE`, `UNIT_QUEST_LOG_CHANGED("player")` (objective progress, needed by the anti-boost rule). The classic `GetQuestsCompleted` and `GetQuestLogTitle` are *not in the dump*: the probe records whether they exist.
- **Where:** W (solo, and grouped), D (a dungeon quest), with one daily or repeatable quest if available.
- **Go:** one `QUEST_TURNED_IN` per turn-in with a readable `questID`; the completed flag is true right after; the full completed list is returned in under 50 ms.
- **Revise:** payload missing or secret: the tracker diffs `QUEST_REMOVED` with `IsQuestFlaggedCompleted`; no completed list: the backfill of quests is dropped.
- **Changes:** [SPEC-03 §7.4 and §7.9](../specs/SPEC-03-activity-catalog.md) (Adventurer source, backfill), [SPEC-02 §8.6.2](../specs/SPEC-02-progression-scoring.md) (quest row).

### V7: the Legacy system

- **Calls and events:** the dump has **no namespace for the Legacy system**: only the UI globals `ToggleLegacySystemUI` and `LegacySystemFrame_LoadUI`, and the achievement API (`GetAchievementInfo`, `GetCategoryList`, `GetCategoryNumAchievements`, `GetAchievementCriteriaInfo`, `GetTotalAchievementPoints`, `GetNumCompletedAchievements`, `ACHIEVEMENT_EARNED(achievementID, alreadyEarned)`, `CRITERIA_UPDATE`; `C_AchievementInfo` has only `AreGuildAchievementsEnabled`). The probe lists the global names containing `Legacy` (names only) before and after calling `LegacySystemFrame_LoadUI()` out of combat, so a namespace created by the load-on-demand UI shows up; tries the achievement functions on the categories and ids they return and records whether they describe Legacy entries (points, completion flag, criteria); and, while the probe character earns a Legacy, records every event whose name contains `LEGACY`, `ACHIEVEMENT` or `CRITERIA` (one frame registered for all events for 30 seconds, out of combat).
- **Where:** W, out of combat; ideally right when a Legacy is earned (exploration or quest).
- **Go:** a readable source lists Legacy entries with id, points and completion, and an event fires when one is earned.
- **Revise:** no readable source: `PAT_LEGACY` and `ADV_LEGACY` stay off behind their switch and the backfill skips Legacy.
- **Changes:** [SPEC-03 §7.3, §7.4 and §7.9](../specs/SPEC-03-activity-catalog.md), [SPEC-00](../specs/SPEC-00-vision-scope.md) (scope row on Legacy), risk R11, `AzerothPrestige/Core/Features.lua`.

### V8: honour, battlegrounds and duels

- **Calls and events:** `GetPVPLifetimeStats()` (the dump returns only `lifetimeHonorableKills` and `lifetimeMaxPVPRank`) before and after an honourable kill, with `PLAYER_PVP_KILLS_CHANGED`, `CHAT_MSG_COMBAT_HONOR_GAIN` (count only) and `HONOR_XP_UPDATE`; `PVP_MATCH_ACTIVE`, `PVP_MATCH_STATE_CHANGED`, `PVP_MATCH_COMPLETE(winner, duration)`, `C_PvP.GetActiveMatchWinner()`, `C_PvP.GetActiveMatchState()`, `C_PvP.GetActiveMatchDuration()`, `C_PvP.IsMatchComplete()`, `GetBattlefieldWinner()`, `UPDATE_BATTLEFIELD_STATUS(battleFieldIndex)` and `UnitFactionGroup("player")` to map the winner to the probe's side; time spent in the match (for the 70% rule); `C_PvP.GetZonePVPInfo()` for world PvP. Duels: `DUEL_REQUESTED(playerName)` (name never stored), `DUEL_FINISHED()` (no payload in the dump), the `CHAT_MSG_SYSTEM` line right after it matched against the global strings `DUEL_WINNER_KNOCKOUT` and `DUEL_WINNER_RETREAT` *(global strings, not in the dump)*, recording only whether the probe character won. For `VAN_MIL_OBJ` (question Q17) the dump has no "warfare" API: the probe logs `AREA_POIS_UPDATED`, `VIGNETTES_UPDATED` and `C_AreaPoiInfo.GetAreaPOIForMap(uiMapID)` counts in contested zones.
- **Where:** W (a duel with 2C; an honourable kill on a PvP realm), BG (one won and one lost match if possible).
- **Go:** the HK counter rises right after an HK; `PVP_MATCH_COMPLETE` fires with a winner that maps to the probe's faction; the duel result can be read from the system line in English and Italian clients.
- **Revise:** a source missing: its rule stays off or uses the older fallback (`GetBattlefieldWinner`, `UPDATE_BATTLEFIELD_SCORE`); no duel winner: duel rules off.
- **Changes:** [SPEC-03 §7.1](../specs/SPEC-03-activity-catalog.md) (Vanguard), [SPEC-02 §8.6.2](../specs/SPEC-02-progression-scoring.md) (PvP row), question Q17.

### V9: exploration and flight paths

- **Calls and events:** `C_MapExplorationInfo.GetExploredMapTextures(uiMapID)` (count of explored overlays, before and after a discovery), `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(uiMapID, normalizedPosition)`, `MAP_EXPLORATION_UPDATED`, `UI_INFO_MESSAGE(errorType, message)` compared with the global string `ERR_ZONE_EXPLORED` *(not in the dump)*, `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`; `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(uiMapID, "player")` (readable in instances? cost per call, for the 1 Hz secret polling), `C_Map.GetMapInfo`, `C_Map.GetMapChildrenInfo` (zones per continent); flight paths: `TAXIMAP_OPENED(system)`, `TAXI_NODE_STATUS_CHANGED`, `C_TaxiMap.GetAllTaxiNodes(uiMapID)` (the dump says "at the current flight master"; field `state`), `C_TaxiMap.GetTaxiNodesForMap(uiMapID)` (field `isUndiscovered`: may give known nodes anywhere, useful for the backfill). Whether the client tells the **total** number of areas of a zone (needed for `PAT_ZONE_FULL`) or only the explored ones.
- **Where:** W with a low-level character entering new sub-zones, at a flight master learning a new node, D for the position check.
- **Go:** a discovery is detected by an event plus a stable id from the diff; known flight nodes are listable (at the flight master at least); the position is readable in the open world at a negligible cost.
- **Revise:** no stable id: `PAT_AREA` uses the message plus the sub-zone text; no total per zone: the ruleset carries the area count per zone; nodes only at the flight master: the backfill of flight paths happens at the first visit.
- **Changes:** [SPEC-03 §7.3 and §7.9](../specs/SPEC-03-activity-catalog.md) (Pathfinder, backfill), [SPEC-01 §17](../specs/SPEC-01-platform-architecture.md) (position polling budget).

### V10: professions

- **Calls and events:** `GetProfessions()` and `GetProfessionInfo(index)` (globals: rank, max rank, skill line), `C_SkillInfo.GetNumSkillLines()` and `C_SkillInfo.GetSkillLineInfo(index)` (the classic globals `GetNumSkillLines` / `GetSkillLineInfo` are *not in the dump*), `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL` (count only); recipes: `TRADE_SKILL_SHOW`, `NEW_RECIPE_LEARNED(recipeID, recipeLevel, baseRecipeID)`, `LEARNED_SPELL_IN_SKILL_LINE(spellID, skillLineIndex, isGuildPerkSpell)` (`LEARNED_SPELL_IN_TAB` is *not in the dump*), `C_TradeSkillUI.GetAllRecipeIDs()` (in the globals, not in the documented API) and `C_TradeSkillUI.GetRecipeInfo(recipeSpellID)` (learned flag), with the profession window open and closed, count and milliseconds; `C_TradeSkillUI.GetBaseProfessionInfo()`, `C_TradeSkillUI.IsRecipeFirstCraft(...)`; crafts: `UNIT_SPELLCAST_SUCCEEDED("player", castGUID, spellID)` while crafting; `TRAINER_UPDATE` at a trainer.
- **Where:** W: at a trainer, with the profession window open and closed, gathering for a skill-up, a craft; one primary and one secondary profession.
- **Go:** rank and max rank are readable without any window; skill-up and recipe-learned events fire; recipes can be listed at least while the window is open; a craft is recognised by its spell id.
- **Revise:** recipes only with the window open: `ART_RECIPE` scans when the window opens (as planned); no skill source: Artisan stays off.
- **Changes:** [SPEC-03 §7.6 and §7.9](../specs/SPEC-03-activity-catalog.md) (Artisan, backfill).

### V11: Auction House, mail invoices and trades

- **Calls and events:** whether an Auction House exists: `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW(type)` with the auctioneer type, `C_AuctionHouse.GetNumOwnedAuctions()`, `OWNED_AUCTIONS_UPDATED`, `AUCTION_HOUSE_AUCTION_CREATED(auctionID)`; mail: `MAIL_SHOW`, `MAIL_INBOX_UPDATE`, `MAIL_CLOSED`, `GetInboxNumItems()`, `GetInboxHeaderInfo(index)` and `GetInboxInvoiceInfo(index)` (globals: shape of every return, the buyer recorded only as "present" and as "same as the previous invoice"), `C_Mail.HasInboxMoney(index)`; trades: `TRADE_SHOW`, `TRADE_PLAYER_ITEM_CHANGED(tradeSlotIndex)`, `TRADE_TARGET_ITEM_CHANGED(tradeSlotIndex)`, `TRADE_MONEY_CHANGED`, `TRADE_ACCEPT_UPDATE(playerAccepted, targetAccepted)`, `TRADE_REQUEST_CANCEL`, `TRADE_CLOSED`, the `UI_INFO_MESSAGE` that confirms the trade (global string `ERR_TRADE_COMPLETE`, *not in the dump*), `GetTradePlayerItemInfo`, `GetTradeTargetItemInfo`, `GetPlayerTradeMoney`, `GetTargetTradeMoney`, and `UnitLevel("NPC")` for the trade partner (trigger A4).
- **Where:** W: an auctioneer in a capital, a mailbox with a sale invoice (sell a cheap item first), a trade with 2C (one completed, one cancelled).
- **Go:** the Auction House exists; a sale invoice gives item, price and a buyer usable as a distinct key; a completed trade is told apart from a cancelled one and both sides' contents and the partner's level are readable.
- **Revise:** no Auction House: `MER_AH_*` stay off; no buyer in the invoice: the "distinct buyer" rules are reworked; trade completion not detectable: `MER_TRADE` and `ART_CRAFT_FOR_OTHER` off.
- **Changes:** [SPEC-03 §7.6 and §7.7](../specs/SPEC-03-activity-catalog.md), [SPEC-02 §8.5 and §8.6.1](../specs/SPEC-02-progression-scoring.md) (anti-alt rule, trigger A4), risk R11.

### V18: battleground scoreboard

- **Calls and events:** `RequestBattlefieldScoreData()`, `UPDATE_BATTLEFIELD_SCORE`, `C_PvP.GetScoreInfo(offsetIndex)` (structure `PVPScoreInfo`: `name`, `guid`, `killingBlows`, `honorableKills`, `deaths`, `honorGained`, `faction`, ...), `C_PvP.GetScoreInfoByPlayerGuid(UnitGUID("player"))`, the classic `GetNumBattlefieldScores()` / `GetBattlefieldScore(index)`; every field through `issecretvalue`; read during the match and at `PVP_MATCH_COMPLETE`. Only the probe character's own row values and the counts of the others are stored.
- **Where:** BG, during the match and at its end.
- **Go:** at `PVP_MATCH_COMPLETE` the probe finds its own row and `killingBlows` is a non-secret number.
- **Revise:** secret or missing: `VAN_KB` stays off (the combat log is not available as an alternative).
- **Changes:** [SPEC-03 §7.1](../specs/SPEC-03-activity-catalog.md) (`VAN_KB`), risk R11.

### L: content levels (risk R13)

Not a V check, but part of M0.6: the level `L` of a boss, a quest and a zone that the scoring uses.

- **Calls and events:** bosses: `UnitLevel("boss1")` to `UnitLevel("boss5")` and `UnitLevel("target")` during an encounter (a number, `-1` or secret?), `UnitClassification`; `C_EncounterJournal.GetEncountersOnMap(uiMapID)`, `EJ_GetInstanceInfo` and `EJ_GetEncounterInfo` (do they give a level or a recommended range?); quests: `C_QuestLog.GetQuestDifficultyLevel(questID)` for quests in the log and after the turn-in; zones and instances: `C_Map.GetMapLevels(uiMapID)` (returns `playerMinLevel`, `playerMaxLevel`), `GetInstanceInfo()`.
- **Where:** W (quests, zones), DB and RB (bosses).
- **Go:** each kind of content has a client source that gives a stable level.
- **Revise:** no source for a kind: hand-curated tables in the ruleset, written from what the client shows in game (never copied from third-party databases), in step M2.2.
- **Changes:** [SPEC-03 §7](../specs/SPEC-03-activity-catalog.md) (the convention on `L`), risk R13.

## M0.7: UI state, restrictions CVar, Hardcore

### V15: interactions, transports, cinematics, calendar

- **Calls and events:** `PLAYER_INTERACTION_MANAGER_FRAME_SHOW(type)` and `PLAYER_INTERACTION_MANAGER_FRAME_HIDE(type)` with the value and its key in `Enum.PlayerInteractionType` *(enumeration not in the dump)*, for gossip, quest giver, vendor, trainer, bank, auctioneer, mailbox, flight master, innkeeper; pairing of every show with its hide; `UnitOnTaxi("player")` during a flight; on a boat and a zeppelin: `PLAYER_CONTROL_LOST`, `PLAYER_CONTROL_GAINED`, `ZONE_CHANGED_NEW_AREA`, `IsMounted()`, `IsFlying()`, `UnitInVehicle("player")`, `C_Map.GetBestMapForUnit("player")`, to find any signal of a transport; `CINEMATIC_START(canBeCancelled, forcedAspectRatio)`, `CINEMATIC_STOP`, `PLAY_MOVIE`, `STOP_MOVIE`; `LOADING_SCREEN_ENABLED`, `LOADING_SCREEN_DISABLED`; `UnitIsDeadOrGhost("player")`, `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`; `GetUIPanel("left")` (global) with the main windows open; calendar: `C_Calendar.OpenCalendar()`, `CALENDAR_UPDATE_EVENT_LIST`, `C_Calendar.GetNumDayEvents(offsetMonths, monthDay)` (count only).
- **Where:** W: each NPC type, a flight, a boat, a zeppelin, a cinematic (a new character's intro or a zone cinematic), LS, a death.
- **Go:** every interaction type fires a show and a matching hide; taxi flights are detected; boats and zeppelins have at least one reliable signal; the calendar answers.
- **Revise:** types missing: the blocking condition relies on the frame whitelist only; boats and zeppelins not detectable: the transport condition covers only taxis (question Q6); calendar unavailable: Prestige Events do not use it.
- **Changes:** [SPEC-09 §15.3](../specs/SPEC-09-celebrations.md) (blocking conditions), question Q6 of [SPEC-11](../specs/SPEC-11-risks-open-questions.md), [SPEC-03 §7.8](../specs/SPEC-03-activity-catalog.md) (Prestige Events).

### V16: a CVar that forces the restrictions

- **Calls and events:** CVar names are not part of the dump. The probe calls `C_CVar.GetCVarInfo(name)` (value, default, locked, secure, read-only) for the candidates `addonCombatRestrictionsForced` and `secretCombatRestrictionsForced` named in SPEC-01, and for name variants the owner may suggest; it **never sets them**. The owner sets one by hand (`/console <name> 1`), and the probe then records out of combat `C_Secrets.HasSecretRestrictions()`, `C_Secrets.ShouldAurasBeSecret()`, `C_Secrets.ShouldUnitIdentityBeSecret("target")`, `C_ChatInfo.InChatMessagingLockdown()`, the `C_RestrictedActions` states of V5 and `issecretvalue(UnitName("target"))`, then again after setting it back to its default.
- **Where:** W, out of combat, in a safe place.
- **Go:** a CVar exists that puts the client in the restricted state out of combat and goes back cleanly.
- **Revise:** none: restricted-state checks in later milestones use real content (a training dummy, a dungeon boss).
- **Changes:** [SPEC-10 §20.2](../specs/SPEC-10-quality-release.md) (in-game tests), the in-game checklists of M1-M7.

### V17: Hardcore realm and permanent death

- **Calls and events:** `C_GameRules.IsHardcoreActive()`; `C_GameRules.GetActiveGameMode()` (*`Enum.GameMode` not in the dump*: value and key); `C_GameRules.IsGameRuleActive(rule)` for every key of `Enum.GameRule` *(not in the dump)* whose name mentions death, permadeath, Hardcore or self-found; `C_GameRules.IsSelfFoundAllowed()`; `GAME_RULES_CHANGED`, `ACTIVE_GAME_MODE_UPDATED`; at death: `PLAYER_DEAD()`, `UnitIsDeadOrGhost("player")`, `C_DeathInfo.GetSelfResurrectOptions()`, whether `PLAYER_ALIVE` or `PLAYER_UNGHOST` can follow; `HARDCORE_DEATHS(memberName)` (count only, never the name); `UnitIsFeignDeath("player")` on a hunter, to make sure a feigned death is not taken for a real one. The death is the owner's choice, with a throwaway low-level character.
- **Where:** HC (login, a death), and the same calls on a Normal realm character for the false positive.
- **Go:** `IsHardcoreActive()` is true on the Hardcore realm only and already at login; `PLAYER_DEAD` fires once at the permanent death, before the client leaves the world; nothing fires on Normal realms or for a feigned death.
- **Revise:** no reliable realm flag: the memorial is off; `PLAYER_DEAD` not reliable: the death is recorded at the next login of that character (the probe also records what a dead Hardcore character shows at login, if the owner can log in with it).
- **Changes:** [SPEC-07 §13.5](../specs/SPEC-07-leaderboards-hall.md) (Hardcore memorial, `hc.dead`), risk R11.

---

## After the run

The owner follows the M0 checklist (`docs/checklists/M0.md`, written in step M0.8) and pastes `/azpp export` into the *In-game test report* issue form, replacing any name with a placeholder. Step M0.9 writes one row per check in `docs/spike/M0-results.md` (result, evidence, consequence), updates every spec listed under **Changes** where the result contradicts it, and records the go / revise decision of each area.
