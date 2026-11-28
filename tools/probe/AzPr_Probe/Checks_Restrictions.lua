-- AzPr Probe, M0.7: V16 a CVar that forces the addon restrictions in tests. Specification: docs/spike/README.md, V16.
-- Lua 5.1. Every game API call goes through pcall (Probe.Call / Probe.Read); every value is tested with issecretvalue
-- before any other use. The probe NEVER changes a CVar: it reads them, prints the console command the owner types by
-- hand, and compares what the client restricts before, while and after. Never a name: of the target only the shape of
-- its name is read.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local Read, IsSecret, Value = Probe.Read, Probe.IsSecret, Probe.Value

local V16 = "V16"

-- The two names of SPEC-01, then variants by analogy (guesses: CVar names are not in the API dump). Only the names the
-- client knows are used.
local CANDIDATES = { "addonCombatRestrictionsForced", "secretCombatRestrictionsForced" }
for _, family in ipairs({ "addon", "secret" }) do
    for _, kind in ipairs({ "Encounter", "ChallengeMode", "PvPMatch", "Map" }) do
        CANDIDATES[#CANDIDATES + 1] = family .. kind .. "RestrictionsForced"
    end
end
local INFO_NAMES = { "value", "defaultValue", "isStoredServerAccount", "isStoredServerCharacter", "isLockedFromUser",
    "isSecure", "isReadOnly" }
local NAME_MAX, ADDED_MAX, SCAN_MAX = 64, 10, 30
local CVAR_DELAY = 1 -- seconds after CVAR_UPDATE before the state is read

local function stats()
    return Probe:Stats(V16)
end

local evaluate
local touch = Probe:Toucher(V16, function()
    return evaluate()
end)

--- A CVar value as it may be written: a short number or word, else its shape.
local function cvarText(v)
    if IsSecret(v) then
        return "secret"
    end
    if type(v) == "string" and #v <= 16 and v:match("^[%w%.%-]*$") then
        return v
    end
    return type(v)
end

--- C_CVar.GetCVarInfo(name): nil when the client does not know the name, else { value, default, text }.
local function cvarInfo(name)
    local ok, res = Probe.Returns(C_CVar and C_CVar.GetCVarInfo, name)
    if not ok then
        return nil, res[1] == "absent" and "absent" or "error"
    end
    if not IsSecret(res[1]) and res[1] == nil then
        return nil, "nil"
    end
    local parts = {}
    for i, field in ipairs(INFO_NAMES) do
        parts[#parts + 1] = field .. "=" .. (i <= 2 and cvarText(res[i]) or Value(res[i]))
    end
    return { value = cvarText(res[1]), default = cvarText(res[2]), text = table.concat(parts, " ") }
end

local function names()
    local list = {}
    for _, name in ipairs(CANDIDATES) do
        list[#list + 1] = name
    end
    for _, name in ipairs(stats().added or {}) do
        list[#list + 1] = name
    end
    return list
end

--- The known CVars: name -> info.
local function existing()
    local found, order = {}, {}
    for _, name in ipairs(names()) do
        local info = cvarInfo(name)
        if info and not found[name] then
            found[name] = info
            order[#order + 1] = name
        end
    end
    return found, order
end

--- Console commands of the client whose name looks like a forced restriction (identifiers of the game).
local function scanCommands()
    local shape, list = Read(ConsoleGetAllCommands)
    if type(list) ~= "table" then
        return "ConsoleGetAllCommands=" .. shape
    end
    local found = {}
    pcall(function()
        for _, entry in ipairs(list) do
            local name = type(entry) == "table" and entry.command
            if not IsSecret(name) and type(name) == "string" and #name <= NAME_MAX and name:match("^[%a_]+$") then
                local lower = name:lower()
                if lower:find("restrictionsforced", 1, true) or lower:find("^secret")
                    or (lower:find("restrict", 1, true) and lower:find("force", 1, true)) then
                    found[#found + 1] = name
                end
            end
        end
    end)
    table.sort(found)
    while #found > SCAN_MAX do
        table.remove(found)
    end
    return "console commands like a forced restriction: " .. (#found > 0 and table.concat(found, " ") or "none")
end

--- What the client restricts now: a list of the indicators that are on, and the full text.
local function state()
    local on, parts = {}, {}
    local function note(label, text, isOn)
        parts[#parts + 1] = label .. "=" .. text
        if isOn then
            on[#on + 1] = label
        end
    end
    local function predicate(label, fn, ...)
        local text = Probe.BoolText(fn, ...)
        note(label, text, text == "true")
    end
    local S = C_Secrets or {}
    predicate("HasSecretRestrictions", S.HasSecretRestrictions)
    predicate("ShouldAurasBeSecret", S.ShouldAurasBeSecret)
    predicate("ShouldUnitIdentityBeSecret(target)", S.ShouldUnitIdentityBeSecret, "target")
    predicate("InChatMessagingLockdown", C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)
    local R = C_RestrictedActions or {}
    local kinds = {}
    pcall(function()
        for key, value in pairs(Enum.AddOnRestrictionType) do
            kinds[#kinds + 1] = { tostring(key), value }
        end
    end)
    table.sort(kinds, function(a, b) return a[1] < b[1] end)
    for _, kind in ipairs(kinds) do
        predicate("active " .. kind[1], R.IsAddOnRestrictionActive, kind[2])
        local shape, current = Read(R.GetAddOnRestrictionState, kind[2])
        local text = current == nil and shape or Probe.EnumKey("AddOnRestrictionState", current)
        note("state " .. kind[1], text, text ~= "Inactive" and current ~= nil and current ~= 0)
    end
    local nameShape = Read(UnitName, "target")
    note("name(target)", nameShape, nameShape == "secret")
    parts[#parts + 1] = "target exists=" .. Probe.BoolText(UnitExists, "target")
    table.sort(on)
    return on, table.concat(parts, " ")
end

local function difference(a, b)
    local has, out = {}, {}
    for _, label in ipairs(b) do
        has[label] = true
    end
    for _, label in ipairs(a) do
        if not has[label] then
            out[#out + 1] = label
        end
    end
    return out
end

--- Reads the CVars and the state, out of combat, and files the observation: baseline (all at their default), forced
--- (exactly one away from it) or restored (all back, after a forced one).
local function snapshot(why)
    if Probe.Context() ~= "W" then
        Probe:Log(V16, why .. " | skipped: needs the open world, out of combat")
        return
    end
    local st = stats()
    local found, order = existing()
    st.known = #order
    st.scanned = true
    local forced, values = {}, {}
    for _, name in ipairs(order) do
        local info = found[name]
        values[#values + 1] = name .. "=" .. info.value .. " (default " .. info.default .. ")"
        if info.value ~= info.default then
            forced[#forced + 1] = name
        end
    end
    Probe:Cover(V16, "W")
    if #order == 0 then
        Probe:Log(V16, why .. " | no candidate CVar exists")
        touch()
        return
    end
    local on, text = state()
    local line = table.concat(values, "; ") .. " | " .. text
    Probe:LogOnce(V16, line, why .. " | " .. line)
    st.effects = st.effects or {}
    if #forced == 0 then
        if st.pending then
            -- back to the default: the state must be what it was before
            local left = difference(on, st.baseline or {})
            local effect = st.effects[st.pending] or {}
            st.effects[st.pending] = effect
            effect.restored = #left == 0 and "clean" or ("left on: " .. table.concat(left, ","))
            Probe:Log(V16, "restored after " .. st.pending .. ": " .. effect.restored)
            if #left == 0 then
                st.pending = nil -- else a later run reads it again, and the baseline is kept
            end
        else
            st.baseline = on
        end
    elseif #forced == 1 then
        if not st.baseline then
            Probe:Log(V16, "forced " .. forced[1] .. " without a baseline: set it back, run V16, then force it again")
        else
            local added = difference(on, st.baseline)
            local effect = st.effects[forced[1]] or {}
            st.effects[forced[1]] = effect
            if #added > 0 then
                effect.added = table.concat(added, ",")
            end
            effect.tried = true
            st.pending = forced[1]
            Probe:Log(V16, "forced " .. forced[1] .. " turns on: " .. (#added > 0 and table.concat(added, ",") or "nothing"))
        end
    else
        Probe:Log(V16, "more than one candidate forced (" .. table.concat(forced, " ") .. "): force one at a time")
    end
    touch()
end

evaluate = function()
    local st = stats()
    local problems, missing = {}, Probe:Missing(V16)
    if st.scanned and st.known == 0 then
        problems[#problems + 1] = "no candidate CVar exists"
        return Probe.Verdict(problems, missing, "restricted states are tested with real content")
    end
    local works, tried, effects = {}, 0, {}
    for name, effect in pairs(st.effects or {}) do
        if effect.tried then
            tried = tried + 1
            if effect.added and effect.restored == "clean" then
                works[#works + 1] = name
            elseif effect.added and effect.restored then
                problems[#problems + 1] = name .. " does not go back cleanly"
            end
            effects[#effects + 1] = name .. ": " .. (effect.added or "no effect")
        end
    end
    table.sort(effects)
    table.sort(works)
    if #works == 0 then
        if not st.baseline then
            missing[#missing + 1] = "a snapshot with every CVar at its default"
        end
        if (st.known or 0) > 0 and tried >= st.known and #problems == 0 and not st.pending then
            problems[#problems + 1] = "no CVar forces a restriction"
        else
            missing[#missing + 1] = st.pending and "set it back to its default" or "force a CVar by hand"
        end
    else
        problems = {} -- one CVar that works and goes back is enough
    end
    local summary = string.format("CVars known %d, forced by hand %d; working %s; %s", st.known or 0, tried,
        #works > 0 and table.concat(works, ",") or "-", #effects > 0 and table.concat(effects, " / ") or "-")
    return Probe.Verdict(problems, missing, summary)
end

--- Prints the commands the owner may type: the probe never types them.
local function printCommands()
    local found, order = existing()
    if #order == 0 then
        Probe.Print("V16: the client knows none of the candidate CVars (add a name with /azpp cvar <name>)")
        return
    end
    Probe.Print("V16: target a friendly NPC, then type one command at a time, run /azpp run V16, and set it back:")
    for _, name in ipairs(order) do
        Probe.Print("  /console " .. name .. " 1    then    /console " .. name .. " " .. found[name].default)
    end
end

Probe:AddCommand("cvar", "/azpp cvar [name] (V16: lists the commands to type; a name adds a candidate)", function(rest)
    if rest ~= "" then
        local st = stats()
        st.added = st.added or {}
        if #rest > NAME_MAX or not rest:match("^[%a_]+$") or not cvarInfo(rest) then
            Probe.Print("the client knows no CVar with that name; nothing stored")
        elseif #st.added < ADDED_MAX then
            local known = existing()
            if not known[rest] then
                st.added[#st.added + 1] = rest
            end
        end
    end
    printCommands()
end)

Probe:Watch({ "CVAR_UPDATE" }, function(_, name)
    if IsSecret(name) or type(name) ~= "string" then
        return
    end
    for _, candidate in ipairs(names()) do
        if candidate:lower() == name:lower() then
            Probe.After(CVAR_DELAY, function()
                snapshot("CVAR_UPDATE " .. candidate)
            end)
            return
        end
    end
end)

Probe:Implement(V16, function(probe)
    for _, name in ipairs(names()) do
        local info, why = cvarInfo(name)
        probe:LogOnce(V16, "info" .. name .. (info and info.text or why), name .. " | " .. (info and info.text or why))
    end
    local scan = scanCommands()
    probe:LogOnce(V16, scan, scan)
    snapshot("run")
    printCommands()
    return evaluate()
end)
