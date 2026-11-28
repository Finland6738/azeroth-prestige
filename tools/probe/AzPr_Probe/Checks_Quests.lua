-- AzPr Probe, M0.6: V6 quest turn-ins (QUEST_TURNED_IN, the completed flag and list, the quest's tags and levels) and
-- V7 the Legacy system (global and namespace names before and after the load-on-demand UI, the achievement API, the
-- events fired while a Legacy is earned).
-- Specification: docs/spike/README.md, V6 and V7. Lua 5.1. Every game API call goes through pcall (Probe.Call /
-- Probe.Read); every value is tested with issecretvalue before any other use. Never a name of a player: quest, category
-- and achievement names are written as their type, achievement "earned by" and criteria character names too. The probe
-- never accepts, turns in or abandons a quest: it only listens and reads.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local call, Read, IsSecret, Value = Probe.Call, Probe.Read, Probe.IsSecret, Probe.Value

local V6 = "V6"
local V7 = "V7"

local LIST_MS = 50 -- the completed quest list must be returned faster than this
local CHECK_DELAY = 1 -- seconds after a turn-in at which the completed flag is read again
local DUPLICATE_WAIT = 5 -- a second turn-in of the same quest within this many seconds is a duplicate
local NAMES_MAX = 60 -- global and function names written per list
local TABLES_MAX = 12 -- Legacy tables whose function names are listed
local CATEGORIES_MAX = 200
local CATEGORY_LINES = 40
local ENTRIES_MAX = 10 -- achievements read per Legacy category
local WATCH_DEFAULT, WATCH_MAX = 30, 300 -- seconds of /azpp legacy watch
local WATCH_LINES = 40

-- V6: quests -----------------------------------------------------------------------------------------------------------

local lastTurnIn = {} -- questID -> milliseconds (this session)

local function questStats()
    local st = Probe:Stats(V6)
    st.ctx = st.ctx or {}
    return st
end

local function count(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function flagged(questID)
    return Probe.BoolText(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, questID)
end

--- The tags and levels of a quest, from the quest log when it is still there.
local function questTraits(questID)
    local Q = C_QuestLog or {}
    local tagShape, tag = Read(Q.GetQuestTagInfo, questID)
    local tagText = tagShape == "table"
        and Probe.Fields(tag, { "tagID", "tagName", "isElite", "worldQuestType", "quality" }) or tagShape
    local text = string.format("difficultyLevel=%s tag{%s} repeatable=%s replayable=%s suggestedGroup=%s",
        Probe.ReadValue(Q.GetQuestDifficultyLevel, questID), tagText, Probe.BoolText(Q.IsRepeatableQuest, questID),
        Probe.BoolText(Q.IsQuestReplayable, questID), Probe.ReadValue(Q.GetSuggestedGroupSize, questID))
    local indexShape, index = Read(Q.GetLogIndexForQuestID, questID)
    if indexShape ~= "number" then
        return text .. " log=" .. indexShape
    end
    local infoShape, info = Read(Q.GetInfo, index)
    if infoShape ~= "table" then
        return text .. " logInfo=" .. infoShape
    end
    local frequency = "error"
    pcall(function()
        frequency = Probe.EnumKey("QuestFrequency", info.frequency)
    end)
    return text .. " log{" .. Probe.Fields(info, { "level", "difficultyLevel", "suggestedGroup", "isScaling",
        "isStory", "questClassification" }) .. " frequency=" .. frequency .. "}"
end

local function evaluateV6()
    local st = questStats()
    local problems = {}
    local function problem(key, text)
        if (st[key] or 0) > 0 then
            problems[#problems + 1] = text .. " x" .. st[key]
        end
    end
    problem("idSecret", "questID secret or missing")
    problem("notFlagged", "not flagged completed 1 s after the turn-in")
    problem("dupTurnIn", "turn-in event twice")
    if st.listState and st.listState ~= "table" then
        problems[#problems + 1] = "completed list " .. st.listState
    elseif (st.listMs or 0) >= LIST_MS then
        problems[#problems + 1] = string.format("completed list took %.0f ms", st.listMs)
    end
    local summary = string.format("turn-ins %d (W %d, D %d), flagged after 1 s %d, completed list %s ids in %s ms; "
        .. "accepted %d, removed %d", st.turnIns or 0, (st.ctx.W or 0) + (st.ctx.WC or 0), (st.ctx.D or 0)
        + (st.ctx.DB or 0), st.flaggedLater or 0, tostring(st.listCount or "-"),
        st.listMs and string.format("%.1f", st.listMs) or "-", st.accepted or 0, st.removed or 0)
    local missing = Probe:Missing(V6)
    if (st.turnIns or 0) == 0 then
        missing[#missing + 1] = "a turn-in"
    end
    if not st.listState then
        missing[#missing + 1] = "the completed list (/azpp run V6)"
    end
    return Probe.Verdict(problems, missing, summary)
end

local touchV6 = Probe:Toucher(V6, evaluateV6)

--- GetAllCompletedQuestIDs: how many ids, how long, how many unreadable.
local function completedList()
    local st = questStats()
    local fn = C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs
    local before = Probe.Ms()
    local shape, ids = Read(fn)
    local ms = Probe.Ms() - before
    st.listState, st.listMs = shape, ms
    local total, secret = 0, 0
    if shape == "table" then
        pcall(function()
            for _, id in ipairs(ids) do
                total = total + 1
                if IsSecret(id) then
                    secret = secret + 1
                end
            end
        end)
        st.listCount = total
        if secret > 0 then
            st.listState = "secret ids"
        end
    end
    Probe:Log(V6, string.format("GetAllCompletedQuestIDs: %s, %d ids (%d secret) in %.1f ms | classic "
        .. "GetQuestsCompleted=%s GetQuestLogTitle=%s", shape, total, secret, ms, type(GetQuestsCompleted),
        type(GetQuestLogTitle)))
end

--- A turn-in covers W (also from combat) or D (also during a boss).
local function coverQuest()
    local tag = Probe.Context()
    if tag == "WC" then
        tag = "W"
    elseif tag == "DB" then
        tag = "D"
    end
    Probe:Cover(V6, tag)
end

local function onTurnIn(questID, xpReward, moneyReward)
    local st = questStats()
    count(st, "turnIns")
    count(st.ctx, Probe.Context())
    coverQuest()
    local text = string.format("QUEST_TURNED_IN questID=%s xpReward=%s moneyReward=%s group=%s", Value(questID),
        Probe.Shape(xpReward), Probe.Shape(moneyReward), select(2, Probe.GroupUnits()))
    if IsSecret(questID) or type(questID) ~= "number" then
        count(st, "idSecret")
        Probe:Log(V6, text)
        touchV6()
        return
    end
    local ms = Probe.Ms()
    if lastTurnIn[questID] and ms - lastTurnIn[questID] < DUPLICATE_WAIT * 1000 then
        count(st, "dupTurnIn")
        text = text .. " DUPLICATE"
    end
    lastTurnIn[questID] = ms
    Probe:Log(V6, text .. " | flagged now=" .. flagged(questID) .. " | " .. questTraits(questID))
    Probe.After(CHECK_DELAY, function()
        local later = flagged(questID)
        if later == "true" then
            count(questStats(), "flaggedLater")
        else
            count(questStats(), "notFlagged")
        end
        Probe:Log(V6, string.format("quest %d %d s after the turn-in: flagged=%s | %s", questID, CHECK_DELAY, later,
            questTraits(questID)))
        touchV6()
    end)
end

--- QUEST_ACCEPTED: the dump has questId only, older clients (logIndex, questId): the last number is taken as the id.
local function onAccepted(...)
    local st = questStats()
    count(st, "accepted")
    local parts, id = {}, nil
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[#parts + 1] = "arg" .. i .. "=" .. Value(v)
        if not IsSecret(v) and type(v) == "number" then
            id = v
        end
    end
    Probe:Log(V6, "QUEST_ACCEPTED " .. table.concat(parts, " ") .. (id and (" | " .. questTraits(id)) or ""))
    touchV6()
end

local function onRemoved(questID, wasReplay)
    local st = questStats()
    count(st, "removed")
    local readable = not IsSecret(questID) and type(questID) == "number"
    Probe:Log(V6, string.format("QUEST_REMOVED questID=%s wasReplayQuest=%s flagged=%s", Value(questID),
        Value(wasReplay), readable and flagged(questID) or "-"))
    touchV6()
end

Probe:Watch({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE" }, function(event, ...)
    if event == "QUEST_TURNED_IN" then
        onTurnIn(...)
    elseif event == "QUEST_ACCEPTED" then
        onAccepted(...)
    elseif event == "QUEST_REMOVED" then
        onRemoved(...)
    elseif event == "QUEST_LOG_UPDATE" then
        count(questStats(), "logUpdates")
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        local st = questStats()
        count(st, "unitLogChanged")
        Probe:LogOnce(V6, "unitLogChanged", "UNIT_QUEST_LOG_CHANGED(player) received (objective progress)")
    end
end, { UNIT_QUEST_LOG_CHANGED = "player" })

Probe:Implement(V6, function(probe)
    local st = questStats()
    local ok, shown, quests = call(C_QuestLog and C_QuestLog.GetNumQuestLogEntries)
    probe:Log(V6, string.format("run | quest log entries=%s quests=%s | events: accepted %d, turned in %d, removed %d, "
        .. "QUEST_LOG_UPDATE %d, UNIT_QUEST_LOG_CHANGED %d", ok and Value(shown) or "error",
        ok and Value(quests) or "error", st.accepted or 0, st.turnIns or 0, st.removed or 0, st.logUpdates or 0,
        st.unitLogChanged or 0))
    completedList()
    return evaluateV6()
end)

-- V7: the Legacy system ------------------------------------------------------------------------------------------------

local function legacyStats()
    return Probe:Stats(V7)
end

local function mentionsLegacy(text)
    return not IsSecret(text) and type(text) == "string" and text:lower():find("legacy", 1, true) ~= nil
end

--- A global or field name that can only be a code identifier.
local function identifier(name)
    return not IsSecret(name) and type(name) == "string" and #name <= 64 and name:match("^[%a_][%w_]*$") ~= nil
end

local function nameList(set)
    local names = {}
    for name in pairs(set) do
        names[#names + 1] = name
    end
    table.sort(names)
    local total = #names
    while #names > NAMES_MAX do
        table.remove(names)
    end
    return total, #names > 0 and table.concat(names, ",") or "-"
end

--- The globals that mention Legacy and every C_* namespace, by name.
local function globalSnapshot()
    local legacy, namespaces = {}, {}
    pcall(function()
        for name, value in pairs(_G) do
            if identifier(name) then
                if mentionsLegacy(name) then
                    legacy[name] = type(value)
                end
                if name:sub(1, 2) == "C_" and type(value) == "table" then
                    namespaces[name] = value
                end
            end
        end
    end)
    return legacy, namespaces
end

local function functionNames(t, onlyLegacy)
    local names = {}
    pcall(function()
        for name, value in pairs(t) do
            if identifier(name) and type(value) == "function" and (not onlyLegacy or mentionsLegacy(name)) then
                names[name] = true
            end
        end
    end)
    return names
end

--- Blizzard addons whose name mentions Legacy, and whether they are loaded.
local function legacyAddons()
    local found = {}
    local A = C_AddOns or {}
    local shape, n = Read(A.GetNumAddOns)
    if shape ~= "number" then
        return "GetNumAddOns=" .. shape
    end
    for i = 1, math.min(n, 500) do
        local _, name = Read(A.GetAddOnInfo, i)
        if identifier(name) and name:sub(1, 9) == "Blizzard_" and mentionsLegacy(name) then
            local ok, _, loaded = call(A.IsAddOnLoaded, name)
            found[#found + 1] = name .. " loaded=" .. (ok and Value(loaded) or "error")
        end
    end
    return #found > 0 and table.concat(found, ", ") or "none"
end

--- The category of an achievement, and whether its name mentions Legacy (the name itself is not written).
local function categoryInfo(categoryID)
    local ok, name, parent = call(GetCategoryInfo, categoryID)
    if not ok then
        return false, "error", Value(nil)
    end
    return mentionsLegacy(name), Probe.Shape(name), Value(parent)
end

--- One achievement: GetAchievementInfo(...) without any text, and its first criterion. Returns the line and whether
--- id, points and completion were readable.
local function achievementText(...)
    local ok, res = Probe.Returns(GetAchievementInfo, ...)
    if not ok then
        return "GetAchievementInfo=" .. (res[1] == "absent" and "absent" or "error"), false
    end
    local id, points, completed = res[1], res[3], res[4]
    local readable = not IsSecret(id) and type(id) == "number" and not IsSecret(points) and type(points) == "number"
        and not IsSecret(completed) and type(completed) == "boolean"
    local text = string.format("id=%s name=%s points=%s completed=%s flags=%s isGuild=%s wasEarnedByMe=%s earnedBy=%s "
        .. "isStatistic=%s", Value(id), Probe.Shape(res[2]), Value(points), Value(completed), Value(res[9]),
        Value(res[12]), Value(res[13]), Probe.Shape(res[14]), Value(res[15]))
    if not IsSecret(id) and type(id) == "number" then
        local _, criteria = Read(GetAchievementNumCriteria, id)
        text = text .. " criteria=" .. Value(criteria)
        if not IsSecret(criteria) and type(criteria) == "number" and criteria > 0 then
            local okC, c = Probe.Returns(GetAchievementCriteriaInfo, id, 1)
            if okC then
                -- 1 text, 2 type, 3 completed, 4 quantity, 5 required, 6 character name, 7 flags, 8 asset, 10 id
                text = text .. string.format(" first{text=%s type=%s completed=%s quantity=%s required=%s charName=%s "
                    .. "assetID=%s criteriaID=%s}", Probe.Shape(c[1]), Value(c[2]), Value(c[3]), Value(c[4]),
                    Value(c[5]), Probe.Shape(c[6]), Value(c[8]), Value(c[10]))
            else
                text = text .. " first=error"
            end
        end
    end
    return text, readable
end

local function scanAchievements(probe)
    local st = legacyStats()
    local shape, categories = Read(GetCategoryList)
    probe:Log(V7, string.format("achievements: GetCategoryList=%s GetTotalAchievementPoints=%s "
        .. "GetNumCompletedAchievements{%s} C_Traits.GetTraitCurrencyForAchievement=%s", shape,
        Probe.ReadValue(GetTotalAchievementPoints),
        Probe.ReturnsText({ "total", "completed" }, GetNumCompletedAchievements),
        type(C_Traits and C_Traits.GetTraitCurrencyForAchievement)))
    if shape ~= "table" then
        return
    end
    local total, legacy, entries, lines = 0, {}, 0, {}
    pcall(function()
        for i, categoryID in ipairs(categories) do
            if i > CATEGORIES_MAX or IsSecret(categoryID) then
                break
            end
            total = total + 1
            local isLegacy, nameShape, parent = categoryInfo(categoryID)
            local ok, n = call(GetCategoryNumAchievements, categoryID)
            n = (ok and not IsSecret(n) and type(n) == "number") and n or nil
            if isLegacy then
                legacy[#legacy + 1] = { id = categoryID, n = n or 0 }
            end
            if #lines < CATEGORY_LINES or isLegacy then
                lines[#lines + 1] = string.format("%s(parent %s, %s, %s%s)", Value(categoryID), parent, nameShape,
                    n or "?", isLegacy and ", LEGACY" or "")
            end
        end
    end)
    st.categories, st.legacyCategories = total, #legacy
    for i = 1, #lines, 10 do
        probe:Log(V7, "categories id(parent, name, achievements): " .. table.concat(lines, " ", i,
            math.min(i + 9, #lines)))
    end
    for c = 1, math.min(#legacy, 5) do
        for index = 1, math.min(legacy[c].n, ENTRIES_MAX) do
            local text, readable = achievementText(legacy[c].id, index)
            if readable then
                entries = entries + 1
            end
            probe:Log(V7, string.format("Legacy category %s entry %d: %s", Value(legacy[c].id), index, text))
        end
    end
    st.entries = entries
    probe:Log(V7, string.format("categories read %d, mentioning Legacy %d, Legacy entries readable %d", total, #legacy,
        entries))
end

local function evaluateV7()
    local st = legacyStats()
    if not st.ran then
        return "todo", "run /azpp run V7 out of combat in the open world"
    end
    local summary = string.format("UI load %s; Legacy globals %d (new %d), new C_ namespaces %d, Legacy C_ functions %d; "
        .. "categories %d, Legacy %d, readable entries %d; Legacy/achievement events %d", st.load or "-",
        st.globals or 0, st.newGlobals or 0, st.newNamespaces or 0, st.functions or 0, st.categories or 0,
        st.legacyCategories or 0, st.entries or 0, st.events or 0)
    local missing = Probe:Missing(V7)
    if (st.entries or 0) > 0 and (st.events or 0) > 0 then
        return Probe.Verdict({}, missing, summary)
    end
    -- Fail only when there is nothing left to read. A UI that loaded may hold the source under any name, and the
    -- Legacy functions the dump lists (loot, reputation, friends, raid difficulty) are not one: those cases are "info".
    if (st.load == "absent" or st.load == "error") and (st.legacyCategories or 0) == 0
        and (st.newNamespaces or 0) == 0 then
        return "fail", "revise: no Legacy UI and no Legacy category | " .. summary
    end
    return "info", "needs reading: entries with id, points, completion and an event not both seen | " .. summary
end

local touchV7 = Probe:Toucher(V7, evaluateV7)

Probe:Implement(V7, function(probe)
    local st = legacyStats()
    local combatShape, combat = Read(InCombatLockdown)
    local before, namespacesBefore = globalSnapshot()
    if combatShape == "boolean" and combat == false then
        local ok, err = call(LegacySystemFrame_LoadUI)
        st.load = ok and "ok" or (err == "absent" and "absent" or "error")
        local outcome = st.load == "error" and Probe.ErrorText(err) or st.load
        probe:Log(V7, "LegacySystemFrame_LoadUI(): " .. outcome .. " ToggleLegacySystemUI="
            .. type(ToggleLegacySystemUI))
    else
        probe:Log(V7, "in combat (or unknown): LegacySystemFrame_LoadUI not called")
    end
    local after, namespaces = globalSnapshot()
    local fresh, freshNamespaces = {}, {}
    for name, kind in pairs(after) do
        if not before[name] then
            fresh[name .. ":" .. kind] = true
        end
    end
    for name, t in pairs(namespaces) do
        if not namespacesBefore[name] then
            freshNamespaces[name] = t
        end
    end
    local all = {}
    for name, kind in pairs(after) do
        all[name .. ":" .. kind] = true
    end
    local nAll, allText = nameList(all)
    local nFresh, freshText = nameList(fresh)
    if st.load == "ok" then
        -- a second run finds nothing new: keep the largest count seen
        st.newGlobals = math.max(st.newGlobals or 0, nFresh)
    end
    st.globals = nAll
    probe:Log(V7, string.format("globals mentioning Legacy %d: %s", nAll, allText))
    probe:Log(V7, string.format("new after the load %d: %s", nFresh, freshText))
    probe:Log(V7, "Blizzard addons mentioning Legacy: " .. legacyAddons())
    local newCount = 0
    for name, t in pairs(freshNamespaces) do
        newCount = newCount + 1
        probe:Log(V7, "new namespace " .. name .. ": " .. select(2, nameList(functionNames(t))))
    end
    st.newNamespaces = math.max(st.newNamespaces or 0, newCount)
    local functions = {}
    for name, t in pairs(namespaces) do
        for fn in pairs(functionNames(t, true)) do
            functions[name .. "." .. fn] = true
        end
    end
    local nFunctions, functionText = nameList(functions)
    st.functions = nFunctions
    probe:Log(V7, string.format("C_ functions mentioning Legacy %d: %s", nFunctions, functionText))
    local tables = 0
    for name, kind in pairs(after) do
        if kind == "table" and tables < TABLES_MAX then
            tables = tables + 1
            local n, text = nameList(functionNames(_G[name]))
            probe:Log(V7, string.format("table %s: %d functions %s", name, n, text))
        end
    end
    scanAchievements(probe)
    st.ran = true
    if Probe.Context() == "W" then
        probe:Cover(V7)
    end
    return evaluateV7()
end)

--- ACHIEVEMENT_EARNED, watched from login on: the id, and whether its category mentions Legacy.
Probe:Watch({ "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE" }, function(event, achievementID, alreadyEarned)
    if event == "CRITERIA_UPDATE" then
        Probe:LogOnce(V7, event, "CRITERIA_UPDATE received") -- too frequent to count as "a Legacy was earned"
    else
        local st = legacyStats()
        st.events = (st.events or 0) + 1
        local category, legacy = "-", false
        if not IsSecret(achievementID) and type(achievementID) == "number" then
            local _, c = Read(GetAchievementCategory, achievementID)
            if type(c) == "number" then
                category, legacy = tostring(c), (categoryInfo(c))
            end
        end
        Probe:Log(V7, string.format("ACHIEVEMENT_EARNED achievementID=%s alreadyEarned=%s category=%s legacy=%s | %s",
            Value(achievementID), Value(alreadyEarned), category, tostring(legacy),
            (not IsSecret(achievementID) and type(achievementID) == "number") and (achievementText(achievementID))
            or "-"))
    end
    touchV7()
end)

-- /azpp legacy watch: every event whose name mentions Legacy, achievements or criteria, for a short window.
local watcher, watchId = nil, 0

local function stopWatch(why)
    if not watcher then
        return
    end
    local w = watcher
    watcher = nil
    pcall(w.frame.UnregisterAllEvents, w.frame)
    Probe:Log(V7, string.format("watch ended (%s): matching events %d | %s", why, w.matched, Probe.TallyText(w.byName)))
    Probe.Print(string.format("legacy watch ended (%s): %d matching events", why, w.matched))
end

local function onWatched(event, ...)
    if not watcher then
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        stopWatch("combat")
        return
    end
    if IsSecret(event) or type(event) ~= "string" then
        return
    end
    if not (event:find("LEGACY", 1, true) or event:find("ACHIEVEMENT", 1, true) or event:find("CRITERIA", 1, true)) then
        return
    end
    watcher.matched = watcher.matched + 1
    Probe.Tally(watcher.byName, event)
    -- ACHIEVEMENT_EARNED is already counted by the watch from login on, CRITERIA_UPDATE is too frequent
    if event ~= "ACHIEVEMENT_EARNED" and event ~= "CRITERIA_UPDATE" then
        local st = legacyStats()
        st.events = (st.events or 0) + 1
    end
    if watcher.byName[event] <= 3 and watcher.matched <= WATCH_LINES then
        local parts = {}
        for i = 1, select("#", ...) do
            parts[#parts + 1] = Probe.Shape((select(i, ...))) -- shapes only: a payload may hold a player name
        end
        Probe:Log(V7, "watched " .. event .. "(" .. table.concat(parts, ", ") .. ")")
    end
    touchV7()
end

local function startWatch(seconds)
    local shape, combat = Read(InCombatLockdown)
    if not (shape == "boolean" and combat == false) then
        Probe.Print("legacy watch: out of combat only")
        return
    end
    stopWatch("restarted")
    watchId = watchId + 1
    local mine = watchId
    local frame = Probe:Watch({}, onWatched)
    if not frame or not pcall(frame.RegisterAllEvents, frame) then
        Probe.Print("legacy watch: the client cannot register every event")
        return
    end
    watcher = { frame = frame, matched = 0, byName = {} }
    Probe:Log(V7, "watch started for " .. seconds .. " s")
    Probe.Print("legacy watch on for " .. seconds .. " s: earn the Legacy now")
    Probe.After(seconds, function()
        if watchId == mine then
            stopWatch("time over")
        end
    end)
end

Probe:AddCommand("legacy", "/azpp legacy watch [seconds] | stop - (V7) log the Legacy and achievement events",
    function(rest)
        local word, number = rest:lower():match("^(%a*)%s*(%d*)$")
        if word == "stop" then
            stopWatch("stopped")
        elseif word == "watch" then
            startWatch(math.max(5, math.min(tonumber(number) or WATCH_DEFAULT, WATCH_MAX)))
        else
            Probe.Print("usage: /azpp legacy watch [seconds] | stop; /azpp run V7 for the lists")
        end
    end)
