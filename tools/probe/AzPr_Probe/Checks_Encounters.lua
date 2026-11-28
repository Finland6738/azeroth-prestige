-- AzPr Probe, M0.3: V1, boss encounters. ENCOUNTER_START / ENCOUNTER_END / BOSS_KILL payloads field by field, the AFK
-- and connection state of the group at ENCOUNTER_END, encounters across a loading screen, and the fallback sources
-- (saved instances, raid locks, encounter loot, system messages: counts only).
-- Specification: docs/spike/README.md, V1. Lua 5.1. Every game API call goes through pcall (Probe.Call / Probe.Read);
-- every value is tested with issecretvalue before any other use. Never a name: encounter and instance names are written
-- as their type, players only as counts.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local call, Read, IsSecret, Tally = Probe.Call, Probe.Read, Probe.IsSecret, Probe.Tally
local ID = "V1"

local START_FIELDS = { "encounterID", "encounterName", "difficultyID", "groupSize" }
local END_FIELDS = { "encounterID", "encounterName", "difficultyID", "groupSize", "success", "encounterUnitStatus" }
local KILL_FIELDS = { "encounterID", "encounterName" }
local LOOT_FIELDS = { "encounterID", "itemID", "itemLink", "quantity", "itemName", "fileName" }
local SPEC_FIELDS = 5 -- SPEC-03 section 7.2 uses the first five fields of ENCOUNTER_END
local KILL_WAIT = 10 -- seconds BOSS_KILL and ENCOUNTER_END may be apart and still belong together
local DUPLICATE_WAIT = 5 -- a second ENCOUNTER_END for the same encounter within this many seconds is a duplicate
local SYSTEM_WINDOW = 10 -- seconds after ENCOUNTER_END in which CHAT_MSG_SYSTEM and the loot are counted
local LOOT_LINES = 3 -- loot events written per encounter (the others only counted)
local IDS_MAX = 60 -- encounter ids kept with their kill counts

-- State of this session (the counters that must survive /reload are in Probe:Stats(ID))
local lastEnd -- { id, ms, kill }
local pendingKill -- { id, ms }: a BOSS_KILL waiting for its ENCOUNTER_END
local windowUntil = 0 -- Probe.Time() until which system messages and loot belong to the last ENCOUNTER_END
local windowSystem, windowSystemSecret, windowLoot = 0, 0, 0
local savedRequested = false

local function stats()
    local st = Probe:Stats(ID)
    st.ctx = st.ctx or {}
    st.ids = st.ids or {}
    return st
end

local function count(st, key, n)
    st[key] = (st[key] or 0) + (n or 1)
end

--- One payload field as "name=<value or shape>": numbers and booleans as values, strings as "string", tables by shape.
local function fieldText(name, v)
    if IsSecret(v) then
        return name .. "=secret", true, 0
    end
    local t = type(v)
    if t == "number" or t == "boolean" then
        return name .. "=" .. tostring(v), false, 0
    elseif t == "table" then
        local shape, inside = Probe.TableShape(v)
        return name .. "=" .. shape, false, inside
    end
    return name .. "=" .. t, false, 0
end

--- The fields of an event payload: the text, the set of secret fields, the secrets inside tables, and the readable
--- numbers by field name (strings are never kept).
local function payload(names, ...)
    local parts, secretSet, inside, numbers = {}, {}, 0, {}
    for i, name in ipairs(names) do
        local v = select(i, ...)
        local text, secret, nested = fieldText(name, v)
        parts[#parts + 1] = text
        inside = inside + nested
        if secret then
            secretSet[name] = true
        elseif type(v) == "number" then
            numbers[name] = v
        end
    end
    local extra = select("#", ...) - #names
    if extra > 0 then
        parts[#parts + 1] = "extraArgs=" .. extra
    end
    return table.concat(parts, " "), secretSet, inside, numbers
end

--- GetInstanceInfo() without the instance name: instanceType, difficultyID, maxPlayers, instanceID.
local function instanceInfo()
    local res = { call(GetInstanceInfo) }
    if not res[1] then
        return (res[2] == "absent" and "GetInstanceInfo=absent" or "GetInstanceInfo=error"), nil
    end
    local function val(i)
        local v = res[i + 1]
        if IsSecret(v) then
            return "secret"
        elseif v == nil then
            return "nil"
        elseif type(v) == "number" or type(v) == "boolean" then
            return tostring(v)
        elseif i == 2 and type(v) == "string" and v:match("^[a-z]+$") then -- the instance type: "party", "raid", ...
            return v
        end
        return type(v)
    end
    local instanceID = (not IsSecret(res[9]) and type(res[9]) == "number") and res[9] or nil
    return string.format("instanceType=%s difficultyID=%s maxPlayers=%s instanceID=%s", val(2), val(3), val(5), val(8)),
        instanceID
end

local function stateText()
    return string.format("inProgress=%s HasSecretRestrictions=%s %s",
        Probe.BoolText(C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress),
        Probe.BoolText(C_Secrets and C_Secrets.HasSecretRestrictions), (instanceInfo()))
end

--- The context tag of an encounter: DB in a dungeon, RB in a raid (at ENCOUNTER_START the "in progress" flag may not
--- be set yet), otherwise the context the probe detects.
local function encounterTag()
    local ok, inInstance, instanceType = call(IsInInstance)
    if ok and not IsSecret(inInstance) and inInstance == true and not IsSecret(instanceType) then
        if instanceType == "party" then
            return "DB"
        elseif instanceType == "raid" then
            return "RB"
        end
    end
    return Probe.Context()
end

--- UnitIsAFK, UnitIsConnected and UnitIsDeadOrGhost of the player and of every other group member, as tallies.
local function groupState(st)
    local units, kind, size = Probe.GroupUnits()
    local afk, conn, dead = {}, {}, {}
    local all = { "player" }
    for _, unit in ipairs(units) do
        all[#all + 1] = unit
    end
    for _, unit in ipairs(all) do
        local who = unit == "player" and "self" or "member"
        local afkText = Probe.BoolText(UnitIsAFK, unit)
        Tally(afk, who .. ":" .. afkText)
        Tally(conn, who .. ":" .. Probe.BoolText(UnitIsConnected, unit))
        Tally(dead, who .. ":" .. Probe.BoolText(UnitIsDeadOrGhost, unit))
        if afkText == "true" or afkText == "false" then
            count(st, "afkReadable")
        elseif afkText == "secret" or afkText == "error" then
            count(st, "afkSecret")
        end
    end
    return string.format("group %s size=%d | UnitIsAFK %s | UnitIsConnected %s | UnitIsDeadOrGhost %s", kind, size,
        Probe.TallyText(afk), Probe.TallyText(conn), Probe.TallyText(dead))
end

local function evaluate()
    local st = stats()
    local db, rb = st.ctx.DB or {}, st.ctx.RB or {}
    local problems = {}
    local function problem(key, text)
        if (st[key] or 0) > 0 then
            problems[#problems + 1] = text .. " x" .. st[key]
        end
    end
    problem("specSecret", "spec fields secret")
    problem("oddSuccess", "success not 0/1")
    problem("killMismatch", "BOSS_KILL id differs")
    problem("killNoEnd", "BOSS_KILL without END")
    problem("dupEnd", "END twice")
    problem("afkSecret", "UnitIsAFK secret")
    problem("lsLost", "encounter lost across LS")
    local summary = string.format("DB %d end %d kill %d wipe, RB %d end %d kill; START %d END %d BOSS_KILL %d "
        .. "(after END %d, before %d); AFK readable %d; LS ended %d lost %d",
        db.ends or 0, db.kills or 0, db.wipes or 0, rb.ends or 0, rb.kills or 0, st.starts or 0, st.ends or 0,
        st.bossKills or 0, st.killAfterEnd or 0, st.killBeforeEnd or 0, st.afkReadable or 0, st.lsEnded or 0,
        st.lsLost or 0)
    if #problems > 0 then
        return "fail", "revise: " .. table.concat(problems, ", ") .. " | " .. summary
    end
    local missing = Probe:Missing(ID)
    if (db.kills or 0) == 0 then
        missing[#missing + 1] = "a DB kill"
    end
    if (rb.kills or 0) == 0 then
        missing[#missing + 1] = "an RB kill"
    end
    if #missing > 0 then
        return "todo", "missing: " .. table.concat(missing, ", ") .. " | " .. summary
    end
    return "pass", summary
end

local function recordQuietly()
    local result, details = evaluate()
    Probe:Record(ID, result, details)
    return result
end

-- Events ---------------------------------------------------------------------------------------------------------------

local function onStart(...)
    local st = stats()
    local text, secretSet, _, numbers = payload(START_FIELDS, ...)
    local tag = encounterTag()
    count(st, "starts")
    if next(secretSet) then
        count(st, "startSecret")
    end
    if st.open then
        -- the previous encounter never sent ENCOUNTER_END
        if st.open.crossed then
            count(st, "lsLost")
            Probe:Cover(ID, "LS")
            Probe:Log(ID, "an encounter that crossed a loading screen never sent ENCOUNTER_END")
        else
            count(st, "startWithoutEnd")
            Probe:Log(ID, "ENCOUNTER_START while the previous encounter had no ENCOUNTER_END")
        end
    end
    st.open = { id = numbers.encounterID, t = Probe.Time(), tag = tag }
    Probe:Log(ID, "ENCOUNTER_START enc=" .. tag .. " | " .. text .. " | " .. stateText())
end

local function onEnd(...)
    local st = stats()
    local text, secretSet, inside, numbers = payload(END_FIELDS, ...)
    local tag = (st.open and st.open.tag) or encounterTag()
    local id, success = numbers.encounterID, numbers.success
    count(st, "ends")
    local specSecret = 0
    for i = 1, SPEC_FIELDS do
        if secretSet[END_FIELDS[i]] then
            specSecret = specSecret + 1
        end
    end
    if specSecret > 0 then
        count(st, "specSecret")
    end
    if inside > 0 then
        count(st, "statusSecret")
    end
    local outcome = "odd"
    if success == 1 then
        outcome = "kill"
    elseif success == 0 then
        outcome = "wipe"
    else
        count(st, "oddSuccess")
    end
    local c = st.ctx[tag] or {}
    st.ctx[tag] = c
    c.ends = (c.ends or 0) + 1
    if outcome == "kill" then
        c.kills = (c.kills or 0) + 1
    elseif outcome == "wipe" then
        c.wipes = (c.wipes or 0) + 1
    end
    -- pairing with ENCOUNTER_START, duplicates, loading screens
    local notes = {}
    if not st.open then
        count(st, "endWithoutStart")
        notes[#notes + 1] = "no START"
    else
        if id and st.open.id then
            notes[#notes + 1] = (id == st.open.id) and "START id matches" or "START id differs"
            if id ~= st.open.id then
                count(st, "startMismatch")
            end
        end
        notes[#notes + 1] = "duration " .. (Probe.Time() - (st.open.t or 0)) .. " s"
        if st.open.crossed then
            count(st, "lsEnded")
            Probe:Cover(ID, "LS")
            notes[#notes + 1] = "crossed a loading screen"
        end
    end
    local ms = Probe.Ms()
    if lastEnd and id and lastEnd.id == id and ms - lastEnd.ms < DUPLICATE_WAIT * 1000 then
        count(st, "dupEnd")
        notes[#notes + 1] = "DUPLICATE"
    end
    if pendingKill and ms - pendingKill.ms < KILL_WAIT * 1000 then
        count(st, "killBeforeEnd")
        notes[#notes + 1] = string.format("BOSS_KILL came %.0f ms before", ms - pendingKill.ms)
        if id and pendingKill.id and id ~= pendingKill.id then
            count(st, "killMismatch")
            notes[#notes + 1] = "BOSS_KILL id differs"
        end
        pendingKill = nil
    end
    if outcome == "kill" and id then
        local key, n = tostring(id), 0
        for _ in pairs(st.ids) do
            n = n + 1
        end
        if st.ids[key] or n < IDS_MAX then
            Tally(st.ids, key)
        end
    end
    st.open = nil
    lastEnd = { id = id, ms = ms, kill = outcome == "kill" }
    Probe:Cover(ID, tag)
    Probe:Log(ID, string.format("ENCOUNTER_END enc=%s %s | spec fields secret %d/%d | %s | %s", tag, outcome,
        specSecret, SPEC_FIELDS, table.concat(notes, ", "), text))
    Probe:Log(ID, "at ENCOUNTER_END | " .. groupState(st) .. " | " .. stateText())
    -- fallback sources, measured at the same time
    windowUntil, windowSystem, windowSystemSecret, windowLoot = Probe.Time() + SYSTEM_WINDOW, 0, 0, 0
    if outcome == "kill" then
        local _, instanceID = instanceInfo()
        if id and instanceID and numbers.difficultyID then
            Probe:Log(ID, "C_RaidLocks.IsEncounterComplete(instanceID, encounterID, difficultyID)="
                .. Probe.BoolText(C_RaidLocks and C_RaidLocks.IsEncounterComplete, instanceID, id, numbers.difficultyID))
        end
        savedRequested = (call(RequestRaidInfo))
    end
    Probe.After(SYSTEM_WINDOW + 1, function()
        Probe:Log(ID, string.format("within %d s of ENCOUNTER_END: CHAT_MSG_SYSTEM %d (secret text %d), "
            .. "ENCOUNTER_LOOT_RECEIVED %d", SYSTEM_WINDOW, windowSystem, windowSystemSecret, windowLoot))
    end)
    recordQuietly()
    Probe.Print("V1: ENCOUNTER_END logged (" .. outcome .. "); /azpp run V1 for the summary")
end

local function onBossKill(...)
    local st = stats()
    local text, _, _, numbers = payload(KILL_FIELDS, ...)
    local id, ms = numbers.encounterID, Probe.Ms()
    count(st, "bossKills")
    local note
    if lastEnd and ms - lastEnd.ms < KILL_WAIT * 1000 then
        count(st, "killAfterEnd")
        note = string.format("%.0f ms after ENCOUNTER_END", ms - lastEnd.ms)
        if id and lastEnd.id then
            if id ~= lastEnd.id then
                count(st, "killMismatch")
            end
            note = note .. (id == lastEnd.id and ", same id" or ", DIFFERENT id")
        end
        if not lastEnd.kill then
            note = note .. ", but that END was not a kill"
        end
    else
        note = "before any ENCOUNTER_END (waiting " .. KILL_WAIT .. " s)"
        pendingKill = { id = id, ms = ms }
        local mine = pendingKill
        Probe.After(KILL_WAIT, function()
            if pendingKill == mine then
                pendingKill = nil
                count(stats(), "killNoEnd")
                Probe:Log(ID, "BOSS_KILL without ENCOUNTER_END within " .. KILL_WAIT .. " s")
                recordQuietly()
            end
        end)
    end
    Probe:Log(ID, "BOSS_KILL | " .. text .. " | " .. note)
    recordQuietly()
end

local function onEnteringWorld(isInitialLogin, isReloadingUi)
    local st = stats()
    if not st.open then
        return
    end
    st.open.crossed = true
    Probe:Log(ID, string.format("loading screen during an encounter (started %d s ago) initialLogin=%s reload=%s | %s",
        Probe.Time() - (st.open.t or 0), IsSecret(isInitialLogin) and "secret" or tostring(isInitialLogin),
        IsSecret(isReloadingUi) and "secret" or tostring(isReloadingUi), stateText()))
    Probe.After(5, function()
        Probe:Log(ID, "5 s after the loading screen: " .. stateText())
    end)
end

local function onSavedInstances()
    if not savedRequested then
        return
    end
    savedRequested = false
    local shape, n = Read(GetNumSavedInstances)
    if shape ~= "number" then
        Probe:Log(ID, "UPDATE_INSTANCE_INFO: GetNumSavedInstances=" .. shape)
        return
    end
    local fields, secret, types = 0, 0, {}
    for i = 1, math.min(n, 50) do
        local res = { call(GetSavedInstanceInfo, i) }
        if res[1] then
            for k = 2, #res do
                fields = fields + 1
                if IsSecret(res[k]) then
                    secret = secret + 1
                end
            end
            if i == 1 then
                for k = 2, #res do
                    types[#types + 1] = IsSecret(res[k]) and "secret" or type(res[k])
                end
            end
        end
    end
    Probe:Log(ID, string.format("UPDATE_INSTANCE_INFO: saved instances %d, fields %d, secret %d, first row %s", n,
        fields, secret, #types > 0 and table.concat(types, ",") or "-"))
end

local function onLoot(...)
    if Probe.Time() > windowUntil then
        return
    end
    windowLoot = windowLoot + 1
    if windowLoot <= LOOT_LINES then
        local parts = {}
        for i, name in ipairs(LOOT_FIELDS) do
            local v = select(i, ...)
            if i == 1 then
                parts[#parts + 1] = (fieldText(name, v))
            else
                parts[#parts + 1] = name .. "=" .. Probe.Shape(v) -- shapes only: a field may hold a player name
            end
        end
        Probe:Log(ID, "ENCOUNTER_LOOT_RECEIVED | " .. table.concat(parts, " "))
    end
end

local function onSystem(text)
    if Probe.Time() > windowUntil then
        return
    end
    windowSystem = windowSystem + 1
    if IsSecret(text) then
        windowSystemSecret = windowSystemSecret + 1
    end
end

Probe:Watch({ "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "PLAYER_ENTERING_WORLD", "UPDATE_INSTANCE_INFO",
    "ENCOUNTER_LOOT_RECEIVED", "CHAT_MSG_SYSTEM" }, function(event, ...)
    if event == "ENCOUNTER_START" then
        onStart(...)
    elseif event == "ENCOUNTER_END" then
        onEnd(...)
    elseif event == "BOSS_KILL" then
        onBossKill(...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        onEnteringWorld(...)
    elseif event == "UPDATE_INSTANCE_INFO" then
        onSavedInstances()
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        onLoot(...)
    elseif event == "CHAT_MSG_SYSTEM" then
        onSystem(...)
    end
end)

-- /azpp run V1: a snapshot of the current state, then the summary of everything logged so far.
Probe:Implement(ID, function(probe)
    local st = stats()
    local open = st.open and string.format("open encounter since %d s%s", Probe.Time() - (st.open.t or 0),
        st.open.crossed and " (crossed a loading screen)" or "") or "no open encounter"
    probe:Log(ID, "run | " .. open .. " | " .. stateText() .. " | kills by id " .. Probe.TallyText(st.ids))
    return evaluate()
end)
