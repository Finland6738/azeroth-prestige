-- AzPr Probe, M0.6: V10 professions. Ranks from GetProfessions / GetProfessionInfo and C_SkillInfo with no window
-- open, skill-ups, recipe-learned events, the recipe list with the profession window open and closed, crafts
-- recognised by their spell id, and the trainer.
-- Specification: docs/spike/README.md, V10. Lua 5.1. Every game API call goes through pcall (Probe.Call / Probe.Read);
-- every value is tested with issecretvalue before any other use. Profession, skill and recipe names are never written;
-- cast GUIDs are never stored. The probe never opens a window, learns, crafts or expands the skill list.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local Read, IsSecret, Value, Tally, TallyText = Probe.Read, Probe.IsSecret, Probe.Value, Probe.Tally, Probe.TallyText

local V10 = "V10"

local READ_DELAY = 5 -- seconds after login before the first reading
local SCAN_DELAY = 1 -- seconds after the profession window opens before the recipes are listed
local SCANS_PER_OPEN = 3 -- automatic scans per window opening (TRADE_SKILL_LIST_UPDATE can fire often)
local PROFESSION_SLOTS = 8
local SKILL_LINES_MAX = 80
local RECIPES_MAX = 3000

local windowOpen, scans = false, 0
local ranks -- skill line id -> rank at the last reading
local learnedSet = {} -- recipe spell ids seen as learned (this session)

local function count(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function stats()
    return Probe:Stats(V10)
end

local evaluate
local touch = Probe:Toucher(V10, function()
    return evaluate()
end)

--- GetProfessions and GetProfessionInfo: rank, maximum and skill line per slot (slots 1 and 2 are the primary ones).
local function professions()
    local ok, slots, n = Probe.Returns(GetProfessions)
    if not ok then
        return slots[1] == "absent" and "absent" or "error", {}
    end
    local parts, found = {}, {}
    for slot = 1, math.min(math.max(n, 2), PROFESSION_SLOTS) do
        local index = slots[slot]
        if IsSecret(index) then
            parts[#parts + 1] = "slot" .. slot .. "=secret"
            found[#found + 1] = { slot = slot, rank = index, max = index }
        elseif type(index) == "number" then
            local okI, res = Probe.Returns(GetProfessionInfo, index)
            if okI then
                -- 1 name, 2 icon, 3 rank, 4 max rank, 5 abilities, 6 spell offset, 7 skill line, 8 modifier
                parts[#parts + 1] = string.format("slot%d{name=%s rank=%s max=%s skillLine=%s modifier=%s}", slot,
                    Probe.Shape(res[1]), Value(res[3]), Value(res[4]), Value(res[7]), Value(res[8]))
                found[#found + 1] = { slot = slot, rank = res[3], max = res[4], line = res[7] }
            else
                parts[#parts + 1] = "slot" .. slot .. " GetProfessionInfo=error"
            end
        end
    end
    return #parts > 0 and table.concat(parts, " ") or "none", found
end

--- C_SkillInfo: every visible skill line as "id:rank/max(category)"; returns the text, the ranks by id and the number
--- of secret fields.
local function skillLines()
    local S = C_SkillInfo or {}
    local shape, n = Read(S.GetNumSkillLines)
    if shape ~= "number" then
        return "GetNumSkillLines=" .. shape, nil, shape == "secret" and 1 or 0
    end
    local parts, byID, headers, collapsed, secrets = {}, {}, 0, 0, 0
    for i = 1, math.min(n, SKILL_LINES_MAX) do
        local lineShape, line = Read(S.GetSkillLineInfo, i)
        if lineShape == "table" then
            pcall(function()
                if IsSecret(line.isHeader) then
                    secrets = secrets + 1
                    return
                end
                if line.isHeader == true then
                    headers = headers + 1
                    if not IsSecret(line.isCollapsed) and line.isCollapsed == true then
                        collapsed = collapsed + 1
                    end
                    return
                end
                local id, rank, max, category = line.skillID, line.rank, line.maxRank, line.skillLineCategoryID
                if IsSecret(id) or IsSecret(rank) or IsSecret(max) then
                    secrets = secrets + 1
                    return
                end
                byID[id] = rank
                parts[#parts + 1] = string.format("%s:%s/%s(%s)", Value(id), Value(rank), Value(max), Value(category))
            end)
        elseif lineShape == "secret" then
            secrets = secrets + 1
        end
    end
    local _, classic = Read(GetNumSkillLines)
    return string.format("%d lines, headers %d (collapsed %d), secret %d, classic GetNumSkillLines=%s | %s", n, headers,
        collapsed, secrets, classic == nil and "absent or nil" or Value(classic),
        #parts > 0 and table.concat(parts, " ") or "-"), byID, secrets
end

--- A reading with the current window state; the differences from the previous one are the skill-ups.
local function read(why)
    local st = stats()
    local professionText, found = professions()
    local lineText, byID, secrets = skillLines()
    local readable = 0
    for _, p in ipairs(found) do
        if IsSecret(p.rank) or IsSecret(p.max) then
            count(st, "rankSecret")
        elseif type(p.rank) == "number" and type(p.max) == "number" then
            readable = readable + 1
        end
    end
    if secrets > 0 then
        count(st, "rankSecret")
    end
    if not windowOpen then
        if readable > 0 then
            st.closedRanks = readable
            Probe:Cover(V10)
        end
        st.noSource = (professionText == "absent" or professionText == "error") and byID == nil and 1 or nil
    end
    local changes = {}
    if byID then
        if ranks then
            for id, rank in pairs(byID) do
                local before = ranks[id]
                if before and rank > before then
                    count(st, "skillUps")
                    changes[#changes + 1] = string.format("%d %d>%d", id, before, rank)
                elseif not before then
                    changes[#changes + 1] = string.format("%d new at %d", id, rank)
                end
            end
        end
        ranks = byID
    end
    local text = string.format("%s window=%s | GetProfessions %s", why, windowOpen and "open" or "closed",
        professionText)
    Probe:LogOnce(V10, text, text)
    if #changes > 0 then
        Probe:Log(V10, why .. " | skill lines changed: " .. table.concat(changes, ", "))
    end
    Probe:LogOnce(V10, "lines" .. lineText, why .. " | C_SkillInfo " .. lineText)
end

--- The recipe list and the learned flags, with the window open or closed.
local function scanRecipes(why)
    local st = stats()
    local T = C_TradeSkillUI or {}
    local state = windowOpen and "open" or "closed"
    local before = Probe.Ms()
    local shape, ids = Read(T.GetAllRecipeIDs)
    local total, learned, secret, firstLearned, firstShape = 0, 0, 0, nil, "-"
    if shape == "table" then
        pcall(function()
            for i, id in ipairs(ids) do
                if i > RECIPES_MAX then
                    break
                end
                total = total + 1
                local infoShape, info = Read(T.GetRecipeInfo, id)
                if infoShape == "table" then
                    if firstShape == "-" then
                        firstShape = Probe.TableShape(info) .. " " .. Probe.Fields(info,
                            { "recipeID", "learned", "categoryID", "numAvailable", "relativeDifficulty" })
                    end
                    if IsSecret(info.learned) then
                        secret = secret + 1
                    elseif info.learned == true and not IsSecret(id) then
                        learned = learned + 1
                        learnedSet[id] = true
                        firstLearned = firstLearned or id
                    end
                elseif infoShape == "secret" then
                    secret = secret + 1
                end
            end
        end)
    end
    local ms = Probe.Ms() - before
    if total > 0 then
        count(st, windowOpen and "listedOpen" or "listedClosed")
        st[windowOpen and "recipesOpen" or "recipesClosed"] = total
    end
    local baseShape, base = Read(T.GetBaseProfessionInfo)
    local baseText = baseShape == "table" and Probe.Fields(base, { "professionID", "profession", "professionName",
        "skillLevel", "maxSkillLevel", "isPrimaryProfession" }) or baseShape
    local line = string.format("%s window=%s | GetAllRecipeIDs=%s %d ids, learned %d, secret %d, %.1f ms | "
        .. "IsTradeSkillReady=%s IsRecipeFirstCraft(first learned)=%s | base {%s}", why, state, shape, total, learned,
        secret, ms, Probe.BoolText(T.IsTradeSkillReady),
        firstLearned and Probe.BoolText(T.IsRecipeFirstCraft, firstLearned) or "-", baseText)
    Probe:LogOnce(V10, state .. total .. ":" .. learned, line)
    if firstShape ~= "-" then
        Probe:LogOnce(V10, "firstRecipe", "first GetRecipeInfo " .. firstShape)
    end
end

--- A successful cast of the player: a craft when its spell id is a recipe.
local function onCast(unit, _, spellID)
    if IsSecret(unit) or unit ~= "player" then
        return -- the cast GUID (second argument) is never read
    end
    local st = stats()
    if IsSecret(spellID) or type(spellID) ~= "number" then
        count(st, "castSecret")
        return
    end
    local infoShape, info = Read(C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo, spellID)
    local isRecipe = learnedSet[spellID] == true
    if not isRecipe and infoShape == "table" then
        pcall(function()
            isRecipe = not IsSecret(info.learned) and info.learned == true
        end)
    end
    if isRecipe then
        count(st, "crafts")
        Probe:LogOnce(V10, "craft" .. spellID, string.format("craft recognised: spellID=%d window=%s GetRecipeInfo=%s "
            .. "known from a scan=%s", spellID, windowOpen and "open" or "closed", infoShape,
            tostring(learnedSet[spellID] == true)))
        touch()
    elseif windowOpen then
        count(st, "otherCasts")
        Probe:LogOnce(V10, "cast" .. spellID, string.format("cast with the window open, not a recipe: spellID=%d "
            .. "GetRecipeInfo=%s", spellID, infoShape))
    end
end

local function onRecipeLearned(recipeID, recipeLevel, baseRecipeID)
    count(stats(), "learnedEvents")
    Probe:Log(V10, string.format("NEW_RECIPE_LEARNED recipeID=%s recipeLevel=%s baseRecipeID=%s window=%s",
        Value(recipeID), Value(recipeLevel), Value(baseRecipeID), windowOpen and "open" or "closed"))
    touch()
end

local function onSpellLearned(spellID, skillLineIndex, isGuildPerk)
    local st = stats()
    count(st, "learnedSpells")
    local recipe = "-"
    if not IsSecret(spellID) and type(spellID) == "number" then
        recipe = Read(C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo, spellID)
    end
    Probe:Log(V10, string.format("LEARNED_SPELL_IN_SKILL_LINE spellID=%s skillLineIndex=%s isGuildPerkSpell=%s "
        .. "GetRecipeInfo=%s", Value(spellID), Value(skillLineIndex), Value(isGuildPerk), recipe))
    touch()
end

local function autoScan(why)
    if windowOpen and scans < SCANS_PER_OPEN then
        scans = scans + 1
        scanRecipes(why)
        touch()
    end
end

evaluate = function()
    local st = stats()
    local problems = {}
    if (st.rankSecret or 0) > 0 then
        problems[#problems + 1] = "skill ranks secret x" .. st.rankSecret
    end
    if st.noSource then
        problems[#problems + 1] = "no skill source"
    end
    local summary = string.format("ranks without window %d; skill-ups %d (events %d, CHAT_MSG_SKILL %d); recipes open %s "
        .. "closed %s; NEW_RECIPE_LEARNED %d, learned spells %d; crafts recognised %d; trainer %d", st.closedRanks or 0,
        st.skillUps or 0, st.linesChanged or 0, st.skillMessages or 0, tostring(st.recipesOpen or "-"),
        tostring(st.recipesClosed or "-"), st.learnedEvents or 0, st.learnedSpells or 0, st.crafts or 0,
        st.trainer or 0)
    local missing = Probe:Missing(V10)
    if (st.closedRanks or 0) == 0 then
        missing[#missing + 1] = "a rank with the window closed"
    end
    if (st.skillUps or 0) == 0 then
        missing[#missing + 1] = "a skill-up"
    end
    if (st.listedOpen or 0) == 0 then
        missing[#missing + 1] = "a recipe list with the window open"
    end
    if (st.learnedEvents or 0) == 0 then
        missing[#missing + 1] = "a recipe learned"
    end
    if (st.crafts or 0) == 0 then
        missing[#missing + 1] = "a craft"
    end
    return Probe.Verdict(problems, missing, summary)
end

Probe:Watch({ "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
    "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "NEW_RECIPE_LEARNED", "LEARNED_SPELL_IN_SKILL_LINE",
    "TRAINER_SHOW", "TRAINER_UPDATE" }, function(event, ...)
    if event == "PLAYER_LOGIN" then
        Probe.After(READ_DELAY, function()
            read("login")
        end)
    elseif event == "SKILL_LINES_CHANGED" then
        count(stats(), "linesChanged")
        read(event)
        touch()
    elseif event == "CHAT_MSG_SKILL" then
        local st = stats()
        count(st, "skillMessages")
        if IsSecret((...)) then
            count(st, "skillMessagesSecret")
        end
        Probe:LogOnce(V10, event, "CHAT_MSG_SKILL received, text " .. Probe.Shape((...)))
    elseif event == "TRADE_SKILL_SHOW" then
        windowOpen, scans = true, 0
        Probe:Log(V10, event)
        Probe.After(SCAN_DELAY, function()
            autoScan("TRADE_SKILL_SHOW")
        end)
    elseif event == "TRADE_SKILL_CLOSE" then
        windowOpen = false
        Probe:Log(V10, event)
        Probe.After(SCAN_DELAY, function()
            if not windowOpen then
                scanRecipes("after TRADE_SKILL_CLOSE")
                touch()
            end
        end)
    elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        count(stats(), event)
        autoScan(event)
    elseif event == "NEW_RECIPE_LEARNED" then
        onRecipeLearned(...)
    elseif event == "LEARNED_SPELL_IN_SKILL_LINE" then
        onSpellLearned(...)
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        count(stats(), "trainer")
        local services = Probe.ReadValue(GetNumTrainerServices)
        Probe:LogOnce(V10, event .. services, event .. " GetNumTrainerServices=" .. services)
    end
end)

Probe:Watch({}, function(event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        onCast(...)
    end
end, { UNIT_SPELLCAST_SUCCEEDED = "player" })

Probe:Implement(V10, function(probe)
    read("run")
    scanRecipes("run")
    local st = stats()
    probe:Log(V10, string.format("run | events %s | casts secret %d, not recipes with the window open %d", TallyText({
        SKILL_LINES_CHANGED = st.linesChanged, TRADE_SKILL_LIST_UPDATE = st.TRADE_SKILL_LIST_UPDATE,
        NEW_RECIPE_LEARNED = st.learnedEvents, LEARNED_SPELL_IN_SKILL_LINE = st.learnedSpells,
    }), st.castSecret or 0, st.otherCasts or 0))
    return evaluate()
end)
