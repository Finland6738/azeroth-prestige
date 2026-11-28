-- AzPr Probe, M0.6: V8 honour, battlegrounds and duels, and V18 the battleground scoreboard. The honourable-kill
-- counter, the match events and winner, the time spent in the match, the duel result read from the system line, area
-- POIs and vignettes (question Q17), and the scoreboard rows with their fields tested one by one.
-- Specification: docs/spike/README.md, V8 and V18. Lua 5.1. Every game API call goes through pcall (Probe.Call /
-- Probe.Read); every value is tested with issecretvalue before any other use. Never a name: player names are only
-- compared with the probe character's, GUIDs only compared; only the probe character's own scoreboard values are
-- written, the other rows are counted by shape. The probe never queues, joins, leaves or duels.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local Read, IsSecret, Value, Tally, TallyText = Probe.Read, Probe.IsSecret, Probe.Value, Probe.Tally, Probe.TallyText

local V8 = "V8"
local V18 = "V18"

local HK_DELAY = 5 -- seconds after PLAYER_PVP_KILLS_CHANGED at which the counter is read again
local DUEL_WAIT = 5 -- seconds DUEL_FINISHED and the winner's system line may be apart
local SCORE_DELAY = 3 -- seconds after the match end, or after a request, at which the scoreboard is read
local SCORE_AUTO = 60 -- seconds after PVP_MATCH_ACTIVE at which the scoreboard is read once during the match
local SCORE_THROTTLE = 10 -- seconds between two readings caused by UPDATE_BATTLEFIELD_SCORE
local SCORE_ROWS = 100
local SCORE_FIELDS = { "name", "guid", "killingBlows", "honorableKills", "deaths", "honorGained", "faction",
    "damageDone", "healingDone", "classToken" }
local OWN_FIELDS = { "killingBlows", "honorableKills", "deaths", "honorGained", "faction" }
local DUEL_STRINGS = { "DUEL_WINNER_KNOCKOUT", "DUEL_WINNER_RETREAT" }

local function count(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function pvpStats()
    return Probe:Stats(V8)
end

local function scoreStats()
    return Probe:Stats(V18)
end

-- Session state (the counters that must survive /reload are in Probe:Stats)
local lastKills -- the honourable-kill counter last read
local matchStartMs, enteredMs
local lastDuelLine -- { ms, role }: the last duel result line about the probe character
local pendingDuel -- { ms }: a DUEL_FINISHED waiting for its line
local lastSecretLine = -math.huge
local lastScoreMs = -math.huge
local match -- { ok }: the scoreboard readings at the end of the current match

-- V8: honourable kills -------------------------------------------------------------------------------------------------

local evaluateV8
local touchV8 = Probe:Toucher(V8, function()
    return evaluateV8()
end)

local function lifetimeKills()
    local shape, kills = Read(GetPVPLifetimeStats)
    if shape == "number" then
        return kills, shape
    end
    return nil, shape
end

local function readKills(why)
    local st = pvpStats()
    local kills, shape = lifetimeKills()
    if not kills then
        count(st, "hkUnreadable")
        Probe:Log(V8, why .. " | GetPVPLifetimeStats=" .. shape)
        return
    end
    local delta = lastKills and (kills - lastKills) or nil
    if delta and delta > 0 then
        count(st, "hkRose")
        Probe:Cover(V8)
    end
    lastKills = kills
    local line = string.format("%s | lifetime HK %d%s", why, kills,
        delta and string.format(" (delta %d)", delta) or " (baseline)")
    if delta ~= 0 then
        Probe:Log(V8, line)
    else
        Probe:LogOnce(V8, why, line)
    end
end

local function onKillsChanged(unit)
    if IsSecret(unit) or unit ~= "player" then
        return
    end
    count(pvpStats(), "killsChanged")
    local at = Probe.Ms()
    readKills("PLAYER_PVP_KILLS_CHANGED")
    Probe.After(HK_DELAY, function()
        readKills(string.format("%.0f ms after PLAYER_PVP_KILLS_CHANGED", Probe.Ms() - at))
        touchV8()
    end)
    touchV8()
end

-- V18: the scoreboard --------------------------------------------------------------------------------------------------

local evaluateV18
local touchV18 = Probe:Toucher(V18, function()
    return evaluateV18()
end)

--- The probe character's own GUID and name, only to compare with: they never leave this file.
local function ownIdentity()
    local _, guid = Read(UnitGUID, "player")
    local _, name = Read(UnitName, "player")
    return type(guid) == "string" and guid or nil, type(name) == "string" and name or nil
end

--- True when `other` (a name from the game) is the probe character, with or without the realm suffix.
local function isMyName(other, name)
    if not name or IsSecret(other) or type(other) ~= "string" then
        return false
    end
    return other == name or other:sub(1, #name + 1) == name .. "-"
end

local function field(row, key)
    local ok, v = pcall(function()
        return row[key]
    end)
    if not ok then
        return nil, "error"
    end
    if IsSecret(v) then
        return nil, "secret"
    end
    return v, type(v)
end

--- Reads every scoreboard row. Returns ownKB (the own killingBlows number, or nil), ownFaction (number or nil) and
--- the number of rows read.
local function readScore(why)
    local st = scoreStats()
    local myGuid, myName = ownIdentity()
    local countShape, total = Read(GetNumBattlefieldScores)
    local P = C_PvP or {}
    local shapes, rows, secrets, ownRow = {}, 0, 0, nil
    for i = 1, math.min(type(total) == "number" and total or SCORE_ROWS, SCORE_ROWS) do
        local shape, row = Read(P.GetScoreInfo, i)
        if shape ~= "table" then
            if shape ~= "nil" then
                Tally(shapes, "row:" .. shape)
            end
            break
        end
        rows = rows + 1
        for _, key in ipairs(SCORE_FIELDS) do
            local _, kind = field(row, key)
            Tally(shapes, key .. ":" .. kind)
            if kind == "secret" then
                secrets = secrets + 1
            end
        end
        local guid = field(row, "guid")
        if myGuid and guid == myGuid then
            ownRow = row
        end
    end
    local how = ownRow and "by index" or "not found by index"
    local byGuidShape, byGuid = "-", nil
    if myGuid then
        byGuidShape, byGuid = Read(P.GetScoreInfoByPlayerGuid, myGuid)
        if not ownRow and byGuidShape == "table" then
            ownRow, how = byGuid, "by GetScoreInfoByPlayerGuid"
        end
    end
    local own, ownKB, ownFaction = "-", nil, nil
    if ownRow then
        own = Probe.Fields(ownRow, OWN_FIELDS)
        local kb = field(ownRow, "killingBlows")
        ownKB = type(kb) == "number" and kb or nil
        local faction = field(ownRow, "faction")
        ownFaction = type(faction) == "number" and faction or nil
    end
    -- the classic API: name first, then killingBlows, honorableKills, deaths, honorGained, faction
    local classic = "not found"
    for i = 1, math.min(type(total) == "number" and total or 0, SCORE_ROWS) do
        local ok, res = Probe.Returns(GetBattlefieldScore, i)
        if not ok then
            classic = res[1] == "absent" and "absent" or "error"
            break
        end
        if IsSecret(res[1]) then
            classic = "names secret"
        elseif isMyName(res[1], myName) then
            classic = string.format("killingBlows=%s honorableKills=%s deaths=%s faction=%s", Value(res[2]),
                Value(res[3]), Value(res[4]), Value(res[6]))
            break
        end
    end
    st.maxRows = math.max(st.maxRows or 0, rows)
    st.secrets = (st.secrets or 0) + secrets
    count(st, "reads")
    if ownKB then
        count(st, "ownKBReads")
    end
    if rows > 0 or Probe.Context() == "BG" then
        if Probe.Context() == "BG" then
            Probe:Cover(V18)
        end
        local text = string.format("rows %d (GetNumBattlefieldScores=%s %s) own row %s {%s} ByPlayerGuid=%s | classic own "
            .. "{%s} | field shapes %s", rows, countShape, Value(total), how, own, byGuidShape, classic,
            TallyText(shapes))
        Probe:LogOnce(V18, why .. text, why .. " | " .. text)
    else
        Probe:LogOnce(V18, why, string.format("%s | no scoreboard rows (GetNumBattlefieldScores=%s %s)", why,
            countShape, Value(total)))
    end
    return ownKB, ownFaction, rows
end

local function requestScore(why, after)
    local ok, err = Probe.Call(RequestBattlefieldScoreData)
    if not ok then
        Probe:LogOnce(V18, "request", "RequestBattlefieldScoreData: "
            .. (err == "absent" and "absent" or Probe.ErrorText(err)))
    end
    Probe.After(SCORE_DELAY, function()
        readScore(why .. " +" .. SCORE_DELAY .. " s after the request")
        if after then
            after()
        end
        touchV18()
    end)
end

evaluateV18 = function()
    local st = scoreStats()
    local problems = {}
    if (st.endFail or 0) > 0 then
        problems[#problems + 1] = "own row or killingBlows unreadable at the match end x" .. st.endFail
    end
    local summary = string.format("readings %d, own killingBlows readable %d, match ends ok %d failed %d, rows up to %d, "
        .. "secret fields %d", st.reads or 0, st.ownKBReads or 0, st.endOk or 0, st.endFail or 0, st.maxRows or 0,
        st.secrets or 0)
    local missing = Probe:Missing(V18)
    if (st.endOk or 0) == 0 then
        missing[#missing + 1] = "a reading at a match end"
    end
    return Probe.Verdict(problems, missing, summary)
end

-- V8: the match --------------------------------------------------------------------------------------------------------

local function matchState()
    local _, state = Read(C_PvP and C_PvP.GetActiveMatchState)
    return state == nil and "nil" or Probe.EnumKey("PvPMatchState", state)
end

local function factionTag()
    local _, group = Read(UnitFactionGroup, "player")
    return group == "Alliance" and "A" or group == "Horde" and "H" or "unknown"
end

local function timeText(ms)
    return ms and string.format("%.0f s", (Probe.Ms() - ms) / 1000) or "unknown"
end

local function onMatchComplete(winner, duration)
    local st = pvpStats()
    local P = C_PvP or {}
    count(st, "matchEnds")
    Probe:Cover(V8, "BG")
    local activeShape, activeWinner = Read(P.GetActiveMatchWinner)
    local battlefieldShape, battlefieldWinner = Read(GetBattlefieldWinner)
    Probe:Log(V8, string.format("PVP_MATCH_COMPLETE winner=%s duration=%s | GetActiveMatchWinner=%s %s "
        .. "GetBattlefieldWinner=%s %s GetActiveMatchDuration=%s IsMatchComplete=%s state=%s "
        .. "GetBattlefieldInstanceRunTime=%s | since match active %s, since entering %s | faction %s", Value(winner),
        Value(duration), activeShape, Value(activeWinner), battlefieldShape, Value(battlefieldWinner),
        Probe.ReadValue(P.GetActiveMatchDuration), Probe.BoolText(P.IsMatchComplete), matchState(),
        Probe.ReadValue(GetBattlefieldInstanceRunTime), timeText(matchStartMs), timeText(enteredMs),
        factionTag()))
    local winnerReadable = not IsSecret(winner) and type(winner) == "number"
    if not winnerReadable and type(activeWinner) ~= "number" then
        count(st, "winnerUnreadable")
    end
    local final = winnerReadable and winner or activeWinner
    local current = { ok = false }
    match = current
    local function mapWinner(ownFaction, source)
        if current.mapped or type(final) ~= "number" then
            return
        end
        if not ownFaction then
            local tag = factionTag()
            ownFaction, source = (tag == "H" and 0) or (tag == "A" and 1) or nil, "UnitFactionGroup"
        end
        if ownFaction then
            current.mapped = true
            count(pvpStats(), "mapped")
            Probe:Log(V8, string.format("winner %d against own faction %d (from %s): %s", final, ownFaction, source,
                final == ownFaction and "won" or "not won"))
        end
    end
    local function reading(ownKB, ownFaction)
        if ownKB then
            current.ok = true
        end
        if ownFaction then
            mapWinner(ownFaction, "the scoreboard row")
        end
    end
    reading(readScore("at PVP_MATCH_COMPLETE"))
    requestScore("match end", function()
        reading(readScore("after PVP_MATCH_COMPLETE"))
        mapWinner(nil)
        if current.ok then
            count(scoreStats(), "endOk")
        else
            count(scoreStats(), "endFail")
        end
        touchV8()
    end)
    touchV8()
    touchV18()
end

-- V8: duels ------------------------------------------------------------------------------------------------------------

local function duelResult(role)
    local st = pvpStats()
    count(st, role == "won" and "duelWon" or "duelLost")
    Probe:Cover(V8, "2C")
    local tag = Probe.Context()
    Probe:Cover(V8, tag == "WC" and "W" or tag)
end

local function onSystem(text)
    if IsSecret(text) then
        lastSecretLine = Probe.Ms()
        if pendingDuel then
            count(pvpStats(), "duelSecret")
        end
        return
    end
    for _, name in ipairs(DUEL_STRINGS) do
        local captures = Probe.MatchGlobal(text, name)
        if captures then
            local _, myName = ownIdentity()
            -- argument 1 is the winner and argument 2 the loser in both strings
            local role = isMyName(captures[1], myName) and "won" or isMyName(captures[2], myName) and "lost" or nil
            if not role then
                count(pvpStats(), "duelOthers")
                Probe:LogOnce(V8, name .. "others", name .. " matched a duel of two other players")
                return
            end
            local ms = Probe.Ms()
            local note = "before DUEL_FINISHED"
            if pendingDuel and ms - pendingDuel.ms < DUEL_WAIT * 1000 then
                note = string.format("%.0f ms after DUEL_FINISHED", ms - pendingDuel.ms)
                pendingDuel = nil
                duelResult(role)
            else
                lastDuelLine = { ms = ms, role = role }
            end
            Probe:Log(V8, string.format("%s: the probe character %s (%s)", name, role, note))
            touchV8()
            return
        end
    end
end

local function onDuelFinished()
    local st = pvpStats()
    count(st, "duelsFinished")
    local ms = Probe.Ms()
    if lastDuelLine and ms - lastDuelLine.ms < DUEL_WAIT * 1000 then
        Probe:Log(V8, string.format("DUEL_FINISHED %.0f ms after the winner line", ms - lastDuelLine.ms))
        duelResult(lastDuelLine.role)
        lastDuelLine = nil
    else
        Probe:Log(V8, "DUEL_FINISHED before any winner line (waiting " .. DUEL_WAIT .. " s)")
        local mine = { ms = ms }
        pendingDuel = mine
        if ms - lastSecretLine < DUEL_WAIT * 1000 then
            count(st, "duelSecret")
        end
        Probe.After(DUEL_WAIT, function()
            if pendingDuel == mine then
                pendingDuel = nil
                count(pvpStats(), "duelNoLine")
                Probe:Log(V8, "no winner line within " .. DUEL_WAIT .. " s (a cancelled or declined duel has none)")
                touchV8()
            end
        end)
    end
    touchV8()
end

local function duelStrings()
    local parts = {}
    for _, name in ipairs(DUEL_STRINGS) do
        local pattern, order = Probe.FormatPattern(_G[name])
        parts[#parts + 1] = name .. (pattern and (" present, arguments " .. table.concat(order, ",")) or " ABSENT")
        if not pattern then
            pvpStats().stringsMissing = 1
        end
    end
    local _, locale = Read(GetLocale)
    parts[#parts + 1] = "locale " .. (type(locale) == "string" and locale:match("^%a%a%u%u$") or "unknown")
    return table.concat(parts, "; ")
end

evaluateV8 = function()
    local st = pvpStats()
    local problems = {}
    local function problem(key, text)
        if (st[key] or 0) > 0 then
            problems[#problems + 1] = text .. " x" .. st[key]
        end
    end
    problem("hkUnreadable", "HK counter unreadable")
    problem("winnerUnreadable", "match winner unreadable")
    problem("duelSecret", "system line secret at a duel end")
    problem("stringsMissing", "duel global strings absent")
    local summary = string.format("HK rose %d (events %d); match ends %d, winner mapped %d; duels finished %d: won %d "
        .. "lost %d, no line %d, others %d; honour lines %d, honour XP %d", st.hkRose or 0, st.killsChanged or 0,
        st.matchEnds or 0, st.mapped or 0, st.duelsFinished or 0, st.duelWon or 0, st.duelLost or 0,
        st.duelNoLine or 0, st.duelOthers or 0, st.honorLines or 0, st.honorXp or 0)
    local missing = Probe:Missing(V8)
    if (st.hkRose or 0) == 0 then
        missing[#missing + 1] = "an HK counted"
    end
    if (st.mapped or 0) == 0 then
        missing[#missing + 1] = "a match winner mapped"
    end
    if (st.duelWon or 0) + (st.duelLost or 0) == 0 then
        missing[#missing + 1] = "a duel result"
    end
    return Probe.Verdict(problems, missing, summary)
end

--- World PvP and the military objectives of question Q17: what the zone and the map tell.
local function zoneText()
    local P = C_PvP or {}
    local ok, res = Probe.Returns(P.GetZonePVPInfo)
    local zone = ok and string.format("pvpType=%s isSubZonePvP=%s factionName=%s",
        Probe.Token(res[1]) or Probe.Shape(res[1]), Value(res[2]), Probe.Shape(res[3])) or "error"
    local _, map = Read(C_Map and C_Map.GetBestMapForUnit, "player")
    local pois = "-"
    if type(map) == "number" then
        local shape, ids = Read(C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap, map)
        pois = shape == "table" and tostring(#ids) or shape
    end
    local vShape, vignettes = Read(C_VignetteInfo and C_VignetteInfo.GetVignettes)
    return string.format("GetZonePVPInfo %s | uiMapID=%s area POIs=%s vignettes=%s IsPVPMap=%s IsWarModeActive=%s", zone,
        Value(map), pois, vShape == "table" and tostring(#vignettes) or vShape, Probe.BoolText(P.IsPVPMap),
        Probe.BoolText(P.IsWarModeActive))
end

local function onBattlefieldStatus(index)
    if IsSecret(index) or type(index) ~= "number" then
        return
    end
    local _, status = Read(GetBattlefieldStatus, index)
    local token = Probe.Token(status) or type(status)
    Probe:LogOnce(V8, "status" .. index .. token, string.format("UPDATE_BATTLEFIELD_STATUS index=%d status=%s", index,
        token))
end

Probe:Watch({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_PVP_KILLS_CHANGED", "CHAT_MSG_COMBAT_HONOR_GAIN",
    "HONOR_XP_UPDATE", "PVP_MATCH_ACTIVE", "PVP_MATCH_STATE_CHANGED", "PVP_MATCH_COMPLETE",
    "UPDATE_BATTLEFIELD_STATUS", "UPDATE_BATTLEFIELD_SCORE", "DUEL_REQUESTED", "DUEL_FINISHED", "CHAT_MSG_SYSTEM",
    "AREA_POIS_UPDATED", "VIGNETTES_UPDATED" }, function(event, ...)
    if event == "CHAT_MSG_SYSTEM" then
        onSystem((...))
    elseif event == "PLAYER_LOGIN" then
        Probe.After(HK_DELAY, function()
            readKills("login")
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        Probe.After(1, function()
            if Probe.Context() == "BG" then
                enteredMs = enteredMs or Probe.Ms()
                Probe:Log(V8, "entered a battleground, state=" .. matchState())
            else
                enteredMs, matchStartMs = nil, nil
            end
        end)
    elseif event == "PLAYER_PVP_KILLS_CHANGED" then
        onKillsChanged(...)
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        local st = pvpStats()
        count(st, "honorLines")
        if IsSecret((...)) then
            count(st, "honorSecret")
        end
        touchV8()
    elseif event == "HONOR_XP_UPDATE" then
        count(pvpStats(), "honorXp")
    elseif event == "PVP_MATCH_ACTIVE" then
        matchStartMs = Probe.Ms()
        Probe:Log(V8, "PVP_MATCH_ACTIVE state=" .. matchState())
        local mine = matchStartMs
        Probe.After(SCORE_AUTO, function()
            if matchStartMs == mine and Probe.Context() == "BG" then
                requestScore("during the match")
            end
        end)
    elseif event == "PVP_MATCH_STATE_CHANGED" then
        Probe:Log(V8, "PVP_MATCH_STATE_CHANGED state=" .. matchState() .. " since active " .. timeText(matchStartMs))
    elseif event == "PVP_MATCH_COMPLETE" then
        onMatchComplete(...)
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        onBattlefieldStatus(...)
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        local ms = Probe.Ms()
        if ms - lastScoreMs >= SCORE_THROTTLE * 1000 then
            lastScoreMs = ms
            local ownKB = readScore("UPDATE_BATTLEFIELD_SCORE")
            if ownKB and match then
                match.ok = true
            end
            touchV18()
        end
    elseif event == "DUEL_REQUESTED" then
        count(pvpStats(), "duelRequests") -- the payload is a player name: never read
        Probe:LogOnce(V8, event, "DUEL_REQUESTED received")
    elseif event == "DUEL_FINISHED" then
        onDuelFinished()
    elseif event == "AREA_POIS_UPDATED" or event == "VIGNETTES_UPDATED" then
        count(pvpStats(), event)
        Probe:LogOnce(V8, event, event .. " | " .. zoneText())
    end
end)

Probe:Implement(V8, function(probe)
    local st = pvpStats()
    probe:Log(V8, "run | " .. duelStrings())
    probe:Log(V8, string.format("run | %s | AREA_POIS_UPDATED %d VIGNETTES_UPDATED %d | match state %s faction %s",
        zoneText(), st.AREA_POIS_UPDATED or 0, st.VIGNETTES_UPDATED or 0, matchState(), factionTag()))
    readKills("run")
    return evaluateV8()
end)

Probe:Implement(V18, function(probe)
    probe:Log(V18, "run | " .. string.format("GetScoreInfo=%s RequestBattlefieldScoreData=%s state=%s",
        type(C_PvP and C_PvP.GetScoreInfo), type(RequestBattlefieldScoreData), matchState()))
    readScore("run")
    if Probe.Context() == "BG" then
        requestScore("run")
    end
    return evaluateV18()
end)
