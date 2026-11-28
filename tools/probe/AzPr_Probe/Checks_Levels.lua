-- AzPr Probe, M0.6: L, content levels (risk R13). What the client tells about the level of a boss (unit levels during
-- encounters), of a quest (in the log, at the turn-in, for completed quests), of a zone (C_Map.GetMapLevels) and of an
-- instance (LFG dungeon data, encounter journal), and whether a level changes between two readings.
-- Specification: docs/spike/README.md, L. Lua 5.1. Every game API call goes through pcall (Probe.Call / Probe.Read);
-- every value is tested with issecretvalue before any other use. Boss, quest, zone and instance names are written as
-- their type; a player target is skipped. The probe only reads: it never selects anything in the encounter journal.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local call, Read, IsSecret, Value = Probe.Call, Probe.Read, Probe.IsSecret, Probe.Value
local Tally, TallyText = Probe.Tally, Probe.TallyText

local L = "L"

local BOSS_UNITS = 5
local BOSS_DELAYS = { 2, 10 } -- seconds after ENCOUNTER_START at which the boss units are read
local SETTLE = 5 -- seconds after a loading screen or a zone change
local TURN_IN_DELAY = 1
local LOG_QUESTS = 20 -- quests of the log read by /azpp run L
local DONE_QUESTS = 5 -- completed quests read by /azpp run L
local IDS_MAX = 100 -- quest and map levels remembered to detect a change
local ZONES_WRITTEN = 12
local JOURNAL_ENCOUNTERS = 15
local LFG_NAMES = { "name", "typeID", "subtypeID", "minLevel", "maxLevel", "recLevel", "minRecLevel", "maxRecLevel",
    "expansionLevel", "groupID" }

local openEncounter -- encounterID of the encounter in progress (this session)
local requested = {} -- completed quests whose data was requested

local function count(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function stats()
    local st = Probe:Stats(L)
    for _, kind in ipairs({ "boss", "quest", "zone", "instance" }) do
        st[kind] = st[kind] or { obs = 0, valid = 0, secret = 0, changed = 0, kinds = {} }
    end
    return st
end

local evaluate
local touch = Probe:Toucher(L, function()
    return evaluate()
end)

--- Counts one level observation of a kind: "valid" (above 0), "minus1", "zero", "secret" or another shape.
local function observe(kind, shape, level)
    local st = stats()[kind]
    st.obs = st.obs + 1
    local key = shape
    if shape == "number" then
        key = (level > 0 and "valid") or (level == -1 and "minus1") or (level == 0 and "zero") or "negative"
    end
    Tally(st.kinds, key)
    if key == "valid" then
        st.valid = st.valid + 1
    elseif key == "secret" then
        st.secret = st.secret + 1
    end
    return key
end

--- Remembers the level of a quest or a map; counts it as changed when it differs from the one seen before.
local function stable(kind, id, level)
    local st = stats()[kind]
    st.levels = st.levels or {}
    local key = tostring(id)
    local before = st.levels[key]
    if before == nil then
        local n = 0
        for _ in pairs(st.levels) do
            n = n + 1
        end
        if n < IDS_MAX then
            st.levels[key] = level
        end
    elseif before ~= level then
        st.changed = st.changed + 1
        st.levels[key] = level
        return string.format(" CHANGED from %s", tostring(before))
    end
    return ""
end

-- Bosses ---------------------------------------------------------------------------------------------------------------

local function unitText(unit)
    local shape, level = Read(UnitLevel, unit)
    local _, creature = Read(UnitClassification, unit)
    return string.format("%s level=%s effective=%s classification=%s contentDifficulty=%s", unit,
        level ~= nil and Value(level) or shape, Probe.ReadValue(UnitEffectiveLevel, unit),
        Probe.Token(creature) or type(creature),
        Probe.ReadValue(C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer, unit)), shape, level
end

local function bossRead(why)
    local parts = {}
    local inEncounter = openEncounter ~= nil
        or Probe.BoolText(C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress) == "true"
    for i = 1, BOSS_UNITS do
        local unit = "boss" .. i
        if Probe.BoolText(UnitExists, unit) == "true" then
            local text, shape, level = unitText(unit)
            local change = ""
            if observe("boss", shape, level) == "valid" and openEncounter and openEncounter > 0 then
                change = stable("boss", openEncounter * 10 + i, level)
            end
            parts[#parts + 1] = text .. change
        end
    end
    -- the target, unless it is a player; it counts as a boss reading only during an encounter without boss units
    if Probe.BoolText(UnitExists, "target") == "true" and Probe.BoolText(UnitIsPlayer, "target") == "false" then
        local text, shape, level = unitText("target")
        if inEncounter and #parts == 0 then
            observe("boss", shape, level)
        end
        parts[#parts + 1] = text
    end
    local tag = Probe.Context()
    if inEncounter and #parts > 0 and (tag == "DB" or tag == "RB") then
        Probe:Cover(L, tag)
    end
    local line = string.format("boss reading %s encounterID=%s own level=%s | %s", why, Value(openEncounter),
        Probe.ReadValue(UnitLevel, "player"), #parts > 0 and table.concat(parts, " | ") or "no boss unit and no target")
    Probe:LogOnce(L, line, line)
    if #parts > 0 then
        touch()
    end
end

-- Quests ---------------------------------------------------------------------------------------------------------------

local function questRead(questID, why)
    if IsSecret(questID) or type(questID) ~= "number" then
        observe("quest", "secret")
        return
    end
    local Q = C_QuestLog or {}
    local shape, level = Read(Q.GetQuestDifficultyLevel, questID)
    local key = observe("quest", shape, level)
    local change = key == "valid" and stable("quest", questID, level) or ""
    local logText = "not in the log"
    local indexShape, index = Read(Q.GetLogIndexForQuestID, questID)
    if indexShape == "number" then
        local _, info = Read(Q.GetInfo, index)
        logText = Probe.Fields(info, { "level", "difficultyLevel", "isScaling" })
    end
    Probe:Log(L, string.format("quest %d %s | GetQuestDifficultyLevel=%s%s | log %s | contentDifficulty=%s own level=%s",
        questID, why, level ~= nil and Value(level) or shape, change, logText,
        Probe.ReadValue(C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer, questID),
        Probe.ReadValue(UnitLevel, "player")))
end

--- The quests of the log, then a few completed ones (before and after asking the server for their data).
local function questsRun()
    local Q = C_QuestLog or {}
    local ok, entries = call(Q.GetNumQuestLogEntries)
    local read, inLog = 0, {}
    if ok and not IsSecret(entries) and type(entries) == "number" then
        for i = 1, math.min(entries, 60) do
            local shape, info = Read(Q.GetInfo, i)
            if shape == "table" and read < LOG_QUESTS then
                pcall(function()
                    if not IsSecret(info.isHeader) and info.isHeader == false and not IsSecret(info.questID) then
                        read = read + 1
                        inLog[info.questID] = true
                        questRead(info.questID, "in the log")
                    end
                end)
            end
        end
    end
    local shape, done = Read(Q.GetAllCompletedQuestIDs)
    local asked = 0
    if shape == "table" then
        pcall(function()
            for _, id in ipairs(done) do
                if asked >= DONE_QUESTS then
                    break
                end
                if not IsSecret(id) and not inLog[id] then
                    asked = asked + 1
                    requested[id] = true
                    questRead(id, "completed, before the data request")
                    call(Q.RequestLoadQuestByID, id)
                end
            end
        end)
    end
    Probe:Log(L, string.format("quests read: %d in the log, %d completed (data requested) | "
        .. "UnitQuestTrivialLevelRange(player)=%s", read, asked,
        Probe.ReadValue(UnitQuestTrivialLevelRange, "player")))
end

-- Zones and instances --------------------------------------------------------------------------------------------------

--- C_Map.GetMapLevels of one map: the text, and the shape and minimum level.
local function mapLevels(map)
    local ok, res = Probe.Returns(C_Map and C_Map.GetMapLevels, map)
    if not ok then
        return map .. ":error", "error"
    end
    local low, high = res[1], res[2]
    if IsSecret(low) or IsSecret(high) then
        return map .. ":secret", "secret"
    end
    return string.format("%d:%s-%s", map, Value(low), Value(high)), type(low), low, high
end

local function zoneRead(why)
    local mapShape, map = Read(C_Map and C_Map.GetBestMapForUnit, "player")
    if mapShape ~= "number" then
        Probe:LogOnce(L, "nomap" .. mapShape, "zone " .. why .. " | uiMapID=" .. mapShape)
        return
    end
    local text, shape, low, high = mapLevels(map)
    local _, inInstance = Read(IsInInstance)
    local change = ""
    -- a map without levels in an instance (or a city) is not a zone observation
    if inInstance == false then
        if observe("zone", shape, low) == "valid" then
            change = stable("zone", map, low * 1000 + (tonumber(high) or 0))
        end
        Probe:Cover(L, "W")
    end
    local zoneType, continentType = 3, 2
    pcall(function()
        zoneType, continentType = Enum.UIMapType.Zone, Enum.UIMapType.Continent
    end)
    local current, others = map, "no continent"
    for _ = 1, 6 do
        local infoShape, info = Read(C_Map.GetMapInfo, current)
        if infoShape ~= "table" or IsSecret(info.mapType) or IsSecret(info.parentMapID) then
            break
        end
        if info.mapType == continentType then
            local childShape, children = Read(C_Map.GetMapChildrenInfo, current, zoneType, true)
            if childShape == "table" then
                local withLevels, total, list = 0, 0, {}
                pcall(function()
                    for _, child in ipairs(children) do
                        if not IsSecret(child.mapID) then
                            total = total + 1
                            local childText, _, childLow = mapLevels(child.mapID)
                            if type(childLow) == "number" and childLow > 0 then
                                withLevels = withLevels + 1
                                if #list < ZONES_WRITTEN then
                                    list[#list + 1] = childText
                                end
                            end
                        end
                    end
                end)
                others = string.format("continent %d: %d of %d zones with levels [%s]", current, withLevels, total,
                    #list > 0 and table.concat(list, " ") or "-")
            end
            break
        end
        if info.parentMapID == 0 then
            break
        end
        current = info.parentMapID
    end
    local line = string.format("zone %s | GetMapLevels %s%s | %s | own level=%s", why, text, change, others,
        Probe.ReadValue(UnitLevel, "player"))
    Probe:LogOnce(L, text .. change .. others, line)
    touch()
end

--- What the client tells about the level of the instance the player is in.
local function instanceRead(why)
    local _, inInstance = Read(IsInInstance)
    if inInstance ~= true then
        return
    end
    local ok, res = Probe.Returns(GetInstanceInfo)
    if not ok then
        Probe:Log(L, "instance " .. why .. " | GetInstanceInfo=error")
        return
    end
    -- 1 name, 2 type, 3 difficulty, 4 difficulty name, 5 max players, 8 instance id, 10 LFG dungeon id
    local instanceType = Probe.Token(res[2]) or Probe.Shape(res[2])
    local instanceID, lfgID = res[8], res[10]
    local lines = { string.format("instance %s | type=%s difficultyID=%s maxPlayers=%s instanceID=%s lfgDungeonID=%s",
        why, instanceType, Value(res[3]), Value(res[5]), Value(instanceID), Value(lfgID)) }
    if not IsSecret(lfgID) and type(lfgID) == "number" and lfgID > 0 then
        local okL, info = Probe.Returns(GetLFGDungeonInfo, lfgID)
        if okL then
            local parts = {}
            for i, name in ipairs(LFG_NAMES) do
                parts[#parts + 1] = name .. "=" .. Value(info[i])
            end
            lines[#lines + 1] = "GetLFGDungeonInfo " .. table.concat(parts, " ")
            observe("instance", IsSecret(info[4]) and "secret" or type(info[4]), info[4])
        else
            lines[#lines + 1] = "GetLFGDungeonInfo=" .. (info[1] == "absent" and "absent" or "error")
        end
        local shape, dungeon = Read(C_LFGInfo and C_LFGInfo.GetDungeonInfo, lfgID)
        lines[#lines + 1] = "C_LFGInfo.GetDungeonInfo " .. (shape == "table" and Probe.TableShape(dungeon) or shape)
    end
    local J = C_EncounterJournal or {}
    if not IsSecret(instanceID) and type(instanceID) == "number" then
        local shape, journal = Read(J.GetInstanceForGameMap, instanceID)
        lines[#lines + 1] = "GetInstanceForGameMap=" .. (journal ~= nil and Value(journal) or shape)
        if shape == "number" then
            lines[#lines + 1] = "EJ_GetInstanceInfo " .. Probe.ReturnsText({}, EJ_GetInstanceInfo, journal)
            for i = 1, JOURNAL_ENCOUNTERS do
                local okE, encounter = Probe.Returns(EJ_GetEncounterInfoByIndex, i, journal)
                if not okE or (not IsSecret(encounter[1]) and encounter[1] == nil) then
                    break
                end
                -- 3 journal encounter id, 7 dungeon encounter id; the other returns by type
                lines[#lines + 1] = string.format("journal encounter %d: journalEncounterID=%s dungeonEncounterID=%s", i,
                    Value(encounter[3]), Value(encounter[7]))
                if i == 1 and not IsSecret(encounter[3]) and type(encounter[3]) == "number" then
                    lines[#lines + 1] = "EJ_GetEncounterInfo " .. Probe.ReturnsText({}, EJ_GetEncounterInfo,
                        encounter[3])
                end
            end
        end
    end
    local mapShape, map = Read(C_Map and C_Map.GetBestMapForUnit, "player")
    if mapShape == "number" then
        lines[#lines + 1] = "GetMapLevels " .. (mapLevels(map))
        local shape, encounters = Read(J.GetEncountersOnMap, map)
        local ids = {}
        if shape == "table" then
            pcall(function()
                for _, entry in ipairs(encounters) do
                    ids[#ids + 1] = Value(entry.encounterID)
                end
            end)
        end
        lines[#lines + 1] = string.format("GetEncountersOnMap(%d)=%s ids [%s]", map, shape,
            #ids > 0 and table.concat(ids, ",") or "-")
    end
    local key = table.concat(lines, "\n")
    for i, line in ipairs(lines) do
        Probe:LogOnce(L, key .. i, line)
    end
    touch()
end

evaluate = function()
    local st = stats()
    local problems, missing = {}, Probe:Missing(L)
    for _, kind in ipairs({ "boss", "quest", "zone" }) do
        local k = st[kind]
        if k.secret > 0 then
            problems[#problems + 1] = kind .. " level secret x" .. k.secret
        elseif k.obs > 0 and k.valid == 0 then
            problems[#problems + 1] = "no readable " .. kind .. " level"
        end
        if k.changed > 0 then
            problems[#problems + 1] = kind .. " level changed x" .. k.changed
        end
        if k.valid == 0 then
            missing[#missing + 1] = "a " .. kind .. " level"
        end
    end
    local function text(kind)
        return string.format("%s %d/%d (%s)", kind, st[kind].valid, st[kind].obs, TallyText(st[kind].kinds))
    end
    return Probe.Verdict(problems, missing, string.format("valid levels: %s, %s, %s, instance (LFG) %d/%d",
        text("boss"), text("quest"), text("zone"), st.instance.valid, st.instance.obs))
end

Probe:Watch({ "ENCOUNTER_START", "ENCOUNTER_END", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "QUEST_ACCEPTED",
    "QUEST_TURNED_IN", "QUEST_DATA_LOAD_RESULT", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" },
    function(event, ...)
        if event == "ENCOUNTER_START" then
            local id = ...
            openEncounter = (not IsSecret(id) and type(id) == "number") and id or 0
            for _, delay in ipairs(BOSS_DELAYS) do
                Probe.After(delay, function()
                    if openEncounter then
                        bossRead(delay .. " s after ENCOUNTER_START")
                    end
                end)
            end
        elseif event == "ENCOUNTER_END" then
            openEncounter = nil
        elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
            bossRead(event)
        elseif event == "QUEST_ACCEPTED" then
            -- the dump has questId only, older clients (logIndex, questId)
            local a, b = ...
            local id = a
            if IsSecret(b) or b ~= nil then
                id = b
            end
            Probe.After(TURN_IN_DELAY, function()
                questRead(id, "accepted")
                touch()
            end)
        elseif event == "QUEST_TURNED_IN" then
            local id = ...
            Probe.After(TURN_IN_DELAY, function()
                questRead(id, "after the turn-in")
                touch()
            end)
        elseif event == "QUEST_DATA_LOAD_RESULT" then
            local id, success = ...
            if not IsSecret(id) and id ~= nil and requested[id] then
                requested[id] = nil
                Probe:Log(L, "QUEST_DATA_LOAD_RESULT success=" .. Value(success))
                questRead(id, "completed, after the data request")
                touch()
            end
        else
            Probe.After(SETTLE, function()
                zoneRead(event)
                instanceRead(event)
            end)
        end
    end)

Probe:Implement(L, function()
    zoneRead("run")
    instanceRead("run")
    bossRead("run")
    questsRun()
    return evaluate()
end)
