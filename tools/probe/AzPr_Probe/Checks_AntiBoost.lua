-- AzPr Probe, M0.3: the anti-boost signals of SPEC-02 section 8.6.1. V19 UnitLevel of group members (near, far, offline) and of
-- far higher hostile players (-1), with the timing of GROUP_ROSTER_UPDATE and UNIT_LEVEL; V20 sourceUnit of the auras on
-- the player, in and out of combat; V21 UnitIsUnit("nameplateNtarget", ...) and "targettarget" comparisons, and the
-- cost of one scan of the visible plates.
-- Specification: docs/spike/README.md, V19-V21. Lua 5.1. Every game API call goes through pcall (Probe.Call /
-- Probe.Read); every value is tested with issecretvalue before any other use. Never a name: units are written as token
-- kinds ("partyN", "nameplateN"), players only as counts and level differences.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local Read, IsSecret, Tally, TallyText = Probe.Read, Probe.IsSecret, Probe.Tally, Probe.TallyText

local GAP = 10 -- "+10 levels" of the anti-boost rule (SPEC-02 section 8.6.1)
local PLATES = 40 -- nameplate1..nameplate40
local ROSTER_DELAYS = { 0, 1, 3 } -- seconds after GROUP_ROSTER_UPDATE at which the levels are read again
local SCAN_BUDGET_MS = 1.0 -- the probe's reading of "well under the 2 Hz budget" for one plate scan (SPEC-01 section 17)
local ASSIST_DEFAULT, ASSIST_MAX = 60, 300 -- seconds of the /azpp assist window
local FULL_SCAN_GAP = 2 -- seconds between two full aura scans triggered by isFullUpdate

local function count(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function ctxStats(id, tag)
    local st = Probe:Stats(id)
    st.ctx = st.ctx or {}
    st.ctx[tag] = st.ctx[tag] or {}
    return st.ctx[tag], st
end

local function playerLevel()
    local shape, level = Read(UnitLevel, "player")
    if shape == "number" and level > 0 then
        return level
    end
    return nil
end

--- A level as a class: "valid", "minus1", "zero", "negative", or the shape ("secret", "nil", "error", "absent").
local function levelClass(unit)
    local shape, level = Read(UnitLevel, unit)
    if shape ~= "number" then
        return shape, nil
    end
    if level > 0 then
        return "valid", level
    elseif level == -1 then
        return "minus1", level
    elseif level == 0 then
        return "zero", level
    end
    return "negative", level
end

local function isHigh(level, mine)
    return level and mine and level >= mine + GAP
end

--- A unit that is in the player's group (party or raid).
local function inGroup(unit)
    local _, party = Read(UnitInParty, unit)
    local raidShape = Read(UnitInRaid, unit)
    return party == true or raidShape == "number"
end

local function missingText(list)
    return #list > 0 and ("missing: " .. table.concat(list, ", ")) or nil
end

-- V19: levels of the group and of hostile players -------------------------------------------------------------------

local V19 = "V19"
local BAD_LEVEL = { secret = true, zero = true, minus1 = true, negative = true, ["nil"] = true, error = true, absent = true }

--- One pass over the group members: per "where:class" tallies, the members 10+ levels higher by where, the bad ones.
local function scanGroupLevels()
    local mine = playerLevel()
    local units, kind, size = Probe.GroupUnits()
    local r = { kind = kind, size = size, mine = mine, members = 0, valid = 0, bad = 0, cat = {}, high = {} }
    for _, unit in ipairs(units) do
        local _, exists = Read(UnitExists, unit)
        if exists == true then
            r.members = r.members + 1
            local _, connected = Read(UnitIsConnected, unit)
            local _, visible = Read(UnitIsVisible, unit)
            local where = (connected == false and "offline") or (visible == true and "near")
                or (visible == false and "far") or "unknown"
            local class, level = levelClass(unit)
            Tally(r.cat, where .. ":" .. class)
            if class == "valid" then
                r.valid = r.valid + 1
                if isHigh(level, mine) then
                    Tally(r.high, where)
                end
            elseif BAD_LEVEL[class] then
                r.bad = r.bad + 1
            end
        end
    end
    return r
end

--- Hostile players on "target" and on the plates: level -1, readable and 10+ higher, readable and close, other shapes.
--- Also counts non-hostile units that return -1.
local function scanHostileLevels(mine)
    local h = { players = 0, minus1 = 0, highReadable = 0, near = 0, shapes = {}, friendlyMinus1 = 0 }
    local tokens = { "target" }
    for i = 1, PLATES do
        tokens[#tokens + 1] = "nameplate" .. i
    end
    for _, unit in ipairs(tokens) do
        local _, exists = Read(UnitExists, unit)
        if exists == true then
            local _, isPlayer = Read(UnitIsPlayer, unit)
            local _, hostile = Read(UnitCanAttack, "player", unit)
            local class, level = levelClass(unit)
            if isPlayer == true and hostile == true then
                h.players = h.players + 1
                if class == "minus1" then
                    h.minus1 = h.minus1 + 1
                elseif class == "valid" and isHigh(level, mine) then
                    h.highReadable = h.highReadable + 1
                elseif class == "valid" then
                    h.near = h.near + 1
                else
                    Tally(h.shapes, class)
                end
            elseif class == "minus1" and isPlayer == true then -- a player that is not hostile (hostile NPCs may be -1)
                h.friendlyMinus1 = h.friendlyMinus1 + 1
            end
        end
    end
    return h
end

local function groupLine(label, r)
    return string.format("%s | %s size=%d members=%d player level %s | %s | +%d: %s", label, r.kind, r.size,
        r.members, r.mine and tostring(r.mine) or "unreadable", TallyText(r.cat), GAP, TallyText(r.high))
end

--- Adds a manual (or settled, +3 s) scan to the counters of V19.
local function addGroupScan(r, h)
    local st = Probe:Stats(V19)
    st.seen = st.seen or {}
    st.high = st.high or {}
    for key, n in pairs(r.cat) do
        Tally(st.seen, key, n)
    end
    for where, n in pairs(r.high) do
        Tally(st.high, where, n)
    end
    count(st, "badLevels", r.bad)
    if h then
        count(st, "hostilePlayers", h.players)
        count(st, "hostileMinus1", h.minus1)
        count(st, "hostileHighReadable", h.highReadable)
        count(st, "friendlyMinus1", h.friendlyMinus1)
    end
end

local function evaluateV19()
    local st = Probe:Stats(V19)
    local high = st.high or {}
    local problems = {}
    if (st.badLevels or 0) > 0 then
        problems[#problems + 1] = "member level secret, 0 or -1 x" .. st.badLevels
    end
    if (st.late or 0) > 0 then
        problems[#problems + 1] = "level invalid 1 s after roster x" .. st.late
    end
    if (st.hostileHighReadable or 0) > 0 then
        problems[#problems + 1] = "hostile +" .. GAP .. " readable, not -1 x" .. st.hostileHighReadable
    end
    if (st.friendlyMinus1 or 0) > 0 then
        problems[#problems + 1] = "-1 on a non-hostile unit x" .. st.friendlyMinus1
    end
    local summary = string.format("roster events %d (+1 s late %d); hostile players %d (-1: %d); +%d %s; members %s",
        st.rosterEvents or 0, st.late or 0, st.hostilePlayers or 0, st.hostileMinus1 or 0, GAP, TallyText(high),
        TallyText(st.seen))
    if #problems > 0 then
        return "fail", "revise: " .. table.concat(problems, ", ") .. " | " .. summary
    end
    local missing = Probe:Missing(V19)
    for _, where in ipairs({ "near", "far", "offline" }) do
        if (high[where] or 0) == 0 then
            missing[#missing + 1] = "a +" .. GAP .. " member " .. where
        end
    end
    if (st.hostileMinus1 or 0) == 0 then
        missing[#missing + 1] = "a hostile -1"
    end
    if #missing > 0 then
        return "todo", missingText(missing) .. " | " .. summary
    end
    return "pass", summary
end

-- Timing of GROUP_ROSTER_UPDATE and UNIT_LEVEL
local lastRosterMs, lastSize, rosterBusyUntil = nil, nil, 0

local function onRoster()
    local st = Probe:Stats(V19)
    count(st, "rosterEvents")
    local ms = Probe.Ms()
    local _, size = Read(GetNumGroupMembers)
    size = type(size) == "number" and size or 0
    local gap = lastRosterMs and string.format("%.0f ms after the previous one", ms - lastRosterMs) or "first one"
    local grew = size > (lastSize or 0)
    Probe:Log(V19, string.format("GROUP_ROSTER_UPDATE size %s -> %d (%s)", lastSize and tostring(lastSize) or "?",
        size, gap))
    lastRosterMs, lastSize = ms, size
    if not grew or ms < rosterBusyUntil then
        return
    end
    rosterBusyUntil = ms + 3500 -- one series of delayed reads at a time
    for _, delay in ipairs(ROSTER_DELAYS) do
        Probe.After(delay, function()
            local r = scanGroupLevels()
            local invalid = r.members - r.valid
            Probe:Log(V19, string.format("roster +%d s: valid %d, invalid %d | %s", delay, r.valid, invalid,
                TallyText(r.cat)))
            local s = Probe:Stats(V19)
            s.timing = s.timing or {}
            Tally(s.timing, delay .. "s:valid", r.valid)
            Tally(s.timing, delay .. "s:invalid", invalid)
            if delay == 1 and invalid > 0 then
                count(s, "late")
            end
            if delay == 3 then
                addGroupScan(r, nil)
                Probe:Record(V19, evaluateV19())
            end
        end)
    end
end

local function onUnitLevel(unit)
    local kind = Probe.TokenKind(unit)
    local st = Probe:Stats(V19)
    st.unitLevel = st.unitLevel or {}
    Tally(st.unitLevel, kind)
    if kind ~= "player" and kind ~= "partyN" and kind ~= "raidN" then
        return -- other units (plates, target) only counted
    end
    local class, level = levelClass(unit)
    local since = lastRosterMs and string.format(", %.0f ms after GROUP_ROSTER_UPDATE", Probe.Ms() - lastRosterMs) or ""
    Probe:Log(V19, string.format("UNIT_LEVEL %s level %s%s%s", kind, class, level and ("=" .. level) or "", since))
end

local function onLevelUp(level)
    local text = IsSecret(level) and "secret" or tostring(level)
    local class, now = levelClass("player")
    Probe:Log(V19, string.format("PLAYER_LEVEL_UP level=%s, UnitLevel(\"player\") now %s%s", text, class,
        now and ("=" .. now) or ""))
end

Probe:Watch({ "GROUP_ROSTER_UPDATE", "UNIT_LEVEL", "PLAYER_LEVEL_UP" }, function(event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        onRoster()
    elseif event == "UNIT_LEVEL" then
        onUnitLevel(...)
    else
        onLevelUp(...)
    end
end)

Probe:Implement(V19, function(probe)
    local r = scanGroupLevels()
    local h = scanHostileLevels(r.mine)
    addGroupScan(r, h)
    if r.kind ~= "solo" then
        probe:Cover(V19)
    end
    probe:Log(V19, groupLine("run", r) .. string.format(" | hostile players %d: -1 %d, +%d readable %d, closer %d, "
        .. "other %s; -1 on non-hostile %d", h.players, h.minus1, GAP, h.highReadable, h.near, TallyText(h.shapes),
        h.friendlyMinus1))
    return evaluateV19()
end)

-- V20: sourceUnit of the auras on the player --------------------------------------------------------------------------

local V20 = "V20"
local lastFullScan = 0
local updateShapeLogged = false

local function auraField(aura, key)
    local ok, v = pcall(function()
        return aura[key]
    end)
    if not ok then
        return "error", nil
    end
    if IsSecret(v) then
        return "secret", nil
    end
    if v == nil then
        return "nil", nil
    end
    return type(v), v
end

--- The caster of an aura from its readable unit token: "self", "group", "other" (an out-of-group player), "npc".
local function sourceClass(unit)
    if unit == "player" then
        return "self"
    end
    local _, isMe = Read(UnitIsUnit, unit, "player")
    if isMe == true then
        return "self"
    end
    local playerShape, isPlayer = Read(UnitIsPlayer, unit)
    if playerShape ~= "boolean" then
        return "player?" .. playerShape
    end
    if not isPlayer then
        return "npc"
    end
    return inGroup(unit) and "group" or "other"
end

--- Adds one aura of the player to the counters of the current context; logs it when it does not come from the player.
local function addAura(aura, origin)
    local tag = Probe.Context()
    local c = ctxStats(V20, tag)
    local _, combat = Read(InCombatLockdown)
    count(c, "auras")
    if IsSecret(aura) or type(aura) ~= "table" then
        count(c, "auraUnreadable")
        return
    end
    local idShape, instanceID = auraField(aura, "auraInstanceID")
    local srcShape, src = auraField(aura, "sourceUnit")
    local fromShape, fromPlayer = auraField(aura, "isFromPlayerOrPlayerPet")
    local spellShape, spellId = auraField(aura, "spellId")
    local helpfulShape, helpful = auraField(aura, "isHelpful")
    local predicted = "-"
    if idShape == "number" then
        predicted = Probe.BoolText(C_Secrets and C_Secrets.ShouldUnitAuraInstanceBeSecret, "player", instanceID)
    end
    if predicted == "true" or predicted == "false" then
        local observed = srcShape == "secret"
        Tally(c, (observed == (predicted == "true")) and "predictionAgrees" or "predictionDiffers")
    end
    local class, levelText = srcShape, ""
    if srcShape == "secret" then
        count(c, "srcSecret")
    elseif srcShape == "nil" then
        count(c, "srcNil")
    elseif srcShape == "string" then
        class = sourceClass(src)
        if class == "group" or class == "other" then
            local lc, level = levelClass(src)
            local mine = playerLevel()
            levelText = " level " .. lc .. ((level and mine) and string.format(" (%+d)", level - mine) or "")
            if lc == "valid" then
                count(c, class .. "Level")
            else
                count(c, class .. "LevelUnreadable")
            end
        end
    end
    c.src = c.src or {}
    Tally(c.src, class)
    if helpfulShape == "boolean" and not helpful then
        count(c, "harmful")
    end
    if class ~= "self" then
        if class ~= "npc" then
            Probe:Cover(V20)
        end
        if class == "other" then
            Probe:Cover(V20, "2C")
        end
        Probe:Log(V20, string.format("%s aura: combat=%s source=%s (%s)%s isFromPlayerOrPlayerPet=%s spellId=%s "
            .. "isHelpful=%s predictedSecret=%s", origin, combat == nil and "?" or tostring(combat),
            srcShape == "string" and Probe.TokenKind(src) or srcShape,
            class, levelText, fromShape == "boolean" and tostring(fromPlayer) or fromShape,
            spellShape == "number" and tostring(spellId) or spellShape,
            helpfulShape == "boolean" and tostring(helpful) or helpfulShape, predicted))
    end
end

--- Every helpful aura of the player through GetAuraDataByIndex.
local function scanAuras(origin)
    local n = 0
    for i = 1, 40 do
        local shape, aura = Read(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if shape == "secret" then
            count(ctxStats(V20, Probe.Context()), "auraUnreadable")
        elseif shape ~= "table" then
            break
        else
            n = n + 1
            addAura(aura, origin)
        end
    end
    return n
end

local function onAura(unit, updateInfo)
    if IsSecret(unit) or unit ~= "player" then
        return
    end
    if IsSecret(updateInfo) or type(updateInfo) ~= "table" then
        count(ctxStats(V20, Probe.Context()), "updateInfoUnreadable")
        return
    end
    if not updateShapeLogged then
        updateShapeLogged = true
        Probe:Log(V20, "UNIT_AURA updateInfo " .. (Probe.TableShape(updateInfo)))
    end
    local fullShape, full = auraField(updateInfo, "isFullUpdate")
    if fullShape == "boolean" and full then
        local t = Probe.Time()
        if t - lastFullScan >= FULL_SCAN_GAP then
            lastFullScan = t
            scanAuras("full update")
        end
        return
    end
    local addedShape, added = auraField(updateInfo, "addedAuras")
    if addedShape ~= "table" then
        return
    end
    local ok, err = pcall(function()
        for _, aura in ipairs(added) do
            addAura(aura, "added")
        end
    end)
    if not ok then
        Probe:Log(V20, "addedAuras " .. Probe.ErrorText(err))
    end
end

Probe:Watch({}, function(event, ...)
    if event == "UNIT_AURA" then
        onAura(...)
    end
end, { UNIT_AURA = "player" })

local function evaluateV20()
    local st = Probe:Stats(V20)
    st.ctx = st.ctx or {}
    local problems, missing, parts = {}, Probe:Missing(V20), {}
    for _, tag in ipairs({ "W", "WC", "D", "DB" }) do
        local c = st.ctx[tag]
        if c then
            parts[#parts + 1] = string.format("%s %d auras src %s", tag, c.auras or 0, TallyText(c.src))
        end
    end
    for _, tag in ipairs({ "W", "WC" }) do
        local c = st.ctx[tag] or {}
        if (c.srcSecret or 0) > 0 then
            problems[#problems + 1] = "sourceUnit secret in " .. tag .. " x" .. c.srcSecret
        end
        if (c.otherLevelUnreadable or 0) > 0 then
            problems[#problems + 1] = "level of the caster unreadable in " .. tag .. " x" .. c.otherLevelUnreadable
        end
        if (c.otherLevel or 0) == 0 then
            missing[#missing + 1] = "an out-of-group buff with its level in " .. tag
        end
    end
    local summary = #parts > 0 and table.concat(parts, "; ") or "no aura seen yet"
    if #problems > 0 then
        return "fail", "revise: " .. table.concat(problems, ", ") .. " | " .. summary
    end
    if #missing > 0 then
        return "todo", missingText(missing) .. " | " .. summary
    end
    return "pass", summary
end

Probe:Implement(V20, function(probe)
    local n = scanAuras("run")
    probe:Log(V20, string.format("run | helpful auras %d | ShouldAurasBeSecret=%s HasSecretRestrictions=%s", n,
        Probe.BoolText(C_Secrets and C_Secrets.ShouldAurasBeSecret),
        Probe.BoolText(C_Secrets and C_Secrets.HasSecretRestrictions)))
    return evaluateV20()
end)

-- V21: nameplateNtarget and targettarget comparisons ------------------------------------------------------------------

local V21 = "V21"
local CMP_BAD = { secret = true, error = true, absent = true, ["nil"] = true }
local ASSIST_LINES = 20 -- lines an assist window may log (identical scans are logged once)

--- UnitIsUnit(u1, u2) tallied under `key`, with the two C_Secrets predictions tallied by value. Returns the readable
--- result or nil.
local function compare(r, key, u1, u2)
    Tally(r.can, Probe.BoolText(C_Secrets and C_Secrets.CanCompareUnitTokens, u1, u2))
    Tally(r.pred, Probe.BoolText(C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret, u1, u2))
    local shape, same = Read(UnitIsUnit, u1, u2)
    Tally(r.cmp, key .. ":" .. (shape == "boolean" and tostring(same) or shape))
    if CMP_BAD[shape] then
        r.bad = r.bad + 1
        return nil
    end
    r.readable = r.readable + 1
    return shape == "boolean" and same or nil
end

--- What a plate is: "self", "unknown", "npc", "group", "enemy" (a hostile player) or "out" (a friendly player outside
--- the group: the helper of triggers A1 and A2).
local function plateKind(unit)
    local _, isMe = Read(UnitIsUnit, unit, "player")
    if isMe == true then
        return "self", "?"
    end
    local playerShape, isPlayer = Read(UnitIsPlayer, unit)
    if playerShape ~= "boolean" then
        return "unknown", playerShape
    end
    if not isPlayer then
        return "npc", playerShape
    end
    local _, hostile = Read(UnitCanAttack, "player", unit)
    if hostile == true then
        return "enemy", playerShape
    end
    return inGroup(unit) and "group" or "out", playerShape
end

local KEY = { out = "P", group = "P", enemy = "E", npc = "N", unknown = "U" } -- short keys of the comparison tallies

--- One scan of the visible plates: every plate's target compared with "target" and "player", "targettarget" compared
--- with every friendly out-of-group player plate and with "player", the A1 / A2 signals and the cost in milliseconds.
local function scanPlates()
    local t0 = Probe.Ms()
    local mine = playerLevel()
    local r = { plates = 0, out = 0, enemy = 0, high = 0, a1 = 0, a1High = 0, a2 = 0, a2High = 0, readable = 0,
        bad = 0, cmp = {}, can = {}, pred = {}, unit = {} }
    local _, hasTarget = Read(UnitExists, "target")
    for i = 1, PLATES do
        local unit = "nameplate" .. i
        local _, exists = Read(UnitExists, unit)
        if exists == true then
            r.plates = r.plates + 1
            local who, playerShape = plateKind(unit)
            Tally(r.unit, "isPlayer:" .. playerShape)
            Tally(r.unit, "combat:" .. Probe.BoolText(UnitAffectingCombat, unit))
            local class, level = levelClass(unit)
            Tally(r.unit, "level:" .. class)
            local high = isHigh(level, mine) or class == "minus1"
            if who == "enemy" then
                r.enemy = r.enemy + 1
            elseif who == "out" then
                r.out = r.out + 1
                if high then
                    r.high = r.high + 1
                end
            end
            local _, targetExists = Read(UnitExists, unit .. "target")
            if targetExists == true and who ~= "self" then
                local onTarget = hasTarget == true and compare(r, KEY[who] .. ">tgt", unit .. "target", "target")
                local onMe = compare(r, KEY[who] .. ">me", unit .. "target", "player")
                if who == "out" and (onTarget == true or onMe == true) then
                    r.a1 = r.a1 + 1
                    if high then
                        r.a1High = r.a1High + 1
                    end
                end
            end
            if hasTarget == true and who == "out" and compare(r, "tt=P", "targettarget", unit) == true then
                r.a2 = r.a2 + 1
                if high then
                    r.a2High = r.a2High + 1
                end
            end
        end
    end
    if hasTarget == true then
        compare(r, "tt=me", "targettarget", "player")
    end
    r.ms = Probe.Ms() - t0
    return r
end

--- The scan as one log line, without the cost (so that identical scans can be recognised).
local function plateText(r)
    return string.format("plates %d (friendly out of group %d, +%d %d; enemy players %d) | A1 %d (+%d %d) A2 %d "
        .. "(+%d %d) | readable %d refused %d | UnitIsUnit %s | CanCompareUnitTokens %s | ShouldUnitComparisonBeSecret "
        .. "%s | units %s", r.plates, r.out, GAP, r.high, r.enemy, r.a1, GAP, r.a1High, r.a2, GAP, r.a2High, r.readable,
        r.bad, TallyText(r.cmp), TallyText(r.can), TallyText(r.pred), TallyText(r.unit))
end

local function plateLine(label, r)
    return string.format("%s | %.2f ms | %s", label, r.ms, plateText(r))
end

--- Adds a scan to the counters of the current context and covers it when a comparison was made.
local function addPlateScan(r)
    local tag = Probe.Context()
    local c, st = ctxStats(V21, tag)
    count(c, "scans")
    count(c, "readable", r.readable)
    count(c, "bad", r.bad)
    count(c, "a1", r.a1High)
    count(c, "a2", r.a2High)
    if r.ms > (st.maxMs or 0) then
        st.maxMs, st.maxMsPlates = r.ms, r.plates
    end
    if r.readable + r.bad > 0 then
        Probe:Cover(V21)
        if r.out > 0 and (tag == "W" or tag == "WC") then
            Probe:Cover(V21, "2C")
        end
    end
end

local function evaluateV21()
    local st = Probe:Stats(V21)
    st.ctx = st.ctx or {}
    local problems, missing, parts = {}, Probe:Missing(V21), {}
    for _, tag in ipairs({ "W", "WC", "D" }) do
        local c = st.ctx[tag]
        if c then
            parts[#parts + 1] = string.format("%s %d scans, %d readable %d refused, A1 %d A2 %d", tag, c.scans or 0,
                c.readable or 0, c.bad or 0, c.a1 or 0, c.a2 or 0)
        end
    end
    for _, tag in ipairs({ "W", "WC" }) do
        local c = st.ctx[tag] or {}
        if (c.bad or 0) > 0 then
            problems[#problems + 1] = "comparisons secret or refused in " .. tag .. " x" .. c.bad
        end
    end
    if (st.maxMs or 0) > SCAN_BUDGET_MS then
        problems[#problems + 1] = string.format("scan %.2f ms with %d plates", st.maxMs, st.maxMsPlates or 0)
    end
    local wc = st.ctx.WC or {}
    if (wc.a1 or 0) == 0 then
        missing[#missing + 1] = "an A1 signal in WC (+" .. GAP .. " helper on your target or you)"
    end
    if (wc.a2 or 0) == 0 then
        missing[#missing + 1] = "an A2 signal in WC (your target on a +" .. GAP .. " helper)"
    end
    local summary = string.format("max %.2f ms (%d plates); ", st.maxMs or 0, st.maxMsPlates or 0)
        .. (#parts > 0 and table.concat(parts, "; ") or "no comparison yet")
    if #problems > 0 then
        return "fail", "revise: " .. table.concat(problems, ", ") .. " | " .. summary
    end
    if #missing > 0 then
        return "todo", missingText(missing) .. " | " .. summary
    end
    return "pass", summary
end

Probe:Implement(V21, function(probe)
    local r = scanPlates()
    addPlateScan(r)
    probe:Log(V21, plateLine("run", r))
    return evaluateV21()
end)

-- /azpp assist [seconds | stop]: scans the plates at 2 Hz for a while (default 60 s), so that V21 can be measured in
-- combat without typing. A scan is logged when it finds an A1 / A2 signal or a refused comparison and differs from
-- the last one logged (at most ASSIST_LINES lines), and the window ends with a summary line.
local assist -- { ticker, scans, signals, bad, maxMs, lines, last }

local function stopAssist(reason)
    if not assist then
        return
    end
    local a = assist
    assist = nil
    if a.ticker and type(a.ticker.Cancel) == "function" then
        pcall(a.ticker.Cancel, a.ticker)
    end
    Probe:Log(V21, string.format("assist window %s: %d scans, %d with a signal, %d with refused comparisons, max %.2f ms",
        reason, a.scans, a.signals, a.bad, a.maxMs))
    local entry = Probe:Record(V21, evaluateV21())
    Probe.Print("V21 assist window " .. reason .. ": " .. entry.result .. " (/azpp run V21 for the summary)")
end

local function assistTick(mine, total)
    if assist ~= mine then
        return
    end
    local r = scanPlates()
    addPlateScan(r)
    mine.scans = mine.scans + 1
    mine.maxMs = math.max(mine.maxMs, r.ms)
    if r.a1 + r.a2 > 0 then
        mine.signals = mine.signals + 1
    end
    if r.bad > 0 then
        mine.bad = mine.bad + 1
    end
    if (r.a1 + r.a2 > 0 or r.bad > 0) and mine.lines < ASSIST_LINES then
        local text = plateText(r)
        if text ~= mine.last then
            mine.last, mine.lines = text, mine.lines + 1
            Probe:Log(V21, plateLine("assist", r))
        end
    end
    if mine.scans >= total then
        stopAssist("ended")
    end
end

Probe:AddCommand("assist", "/azpp assist [seconds|stop] - scan the plates at 2 Hz for V21 (default "
    .. ASSIST_DEFAULT .. " s, at most " .. ASSIST_MAX .. ")", function(rest)
    if rest:lower() == "stop" then
        stopAssist("stopped")
        return
    end
    if assist then
        Probe.Print("an assist window is already running (/azpp assist stop)")
        return
    end
    if not (C_Timer and type(C_Timer.NewTicker) == "function") then
        Probe.Print("C_Timer.NewTicker is absent: use /azpp run V21 instead")
        return
    end
    local seconds = math.floor(math.min(math.max(tonumber(rest) or ASSIST_DEFAULT, 1), ASSIST_MAX))
    local total = seconds * 2
    local mine = { scans = 0, signals = 0, bad = 0, maxMs = 0, lines = 0 }
    assist = mine
    local ok, ticker = pcall(C_Timer.NewTicker, 0.5, function()
        local okTick, err = pcall(assistTick, mine, total)
        if not okTick then
            Probe:Log("errors", "assist " .. Probe.ErrorText(err))
            stopAssist("failed")
        end
    end, total)
    if not ok then
        assist = nil
        Probe.Print("assist " .. Probe.ErrorText(ticker))
        return
    end
    mine.ticker = ticker
    Probe.Print("assist window started: " .. seconds .. " s at 2 Hz (V21)")
end)
