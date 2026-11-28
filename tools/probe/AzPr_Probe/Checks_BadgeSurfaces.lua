-- AzPr Probe, M0.4: the badge surfaces of SPEC-08 section 14.4. V2 player identity (UnitName, UnitGUID) on nameplate,
-- mouseover, target and tooltip units, next to C_Secrets.ShouldUnitIdentityBeSecret; V3 nameplates returned or
-- forbidden, friendly and enemy, and a test texture anchored to the plates that are not forbidden; V12 a chat message
-- filter that puts a |T...|t texture before the lines whose sender is readable; V13 a unit tooltip post-call with one
-- added line and a harmless entry in the unit menus. Blocked and forbidden actions are attributed to the surface used
-- just before them.
-- Specification: docs/spike/README.md, V2, V3, V12, V13. Lua 5.1. Every game API call goes through pcall (Probe.Call /
-- Probe.Read); every value is tested with issecretvalue before any other use. Never a name: units are written as token
-- kinds, players as "self" / "group" / "friend" / "enemy" and counts, frames only by a Blizzard frame name. Every hook
-- and the filter can be switched off with /azpp surfaces, and none of them touches a protected frame in combat.

local ADDON_NAME = ...
local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local call, Read, IsSecret, Tally, TallyText = Probe.Call, Probe.Read, Probe.IsSecret, Probe.Tally, Probe.TallyText

local V2 = "V2"
local V3 = "V3"
local V12 = "V12"
local V13 = "V13"

local PLATES = 40 -- nameplate1..nameplate40
local TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark" -- a client texture, referenced and never redistributed
local CHAT_ICON = "|T" .. TEXTURE .. ":14|t "
local MARKER_SIZE = 16
local TOOLTIP_LINE = "AzPr Probe: tooltip line"
local MENU_ENTRY = "AzPr Probe: menu entry"
local FLUSH_DELAY = 5 -- seconds between an event and the record it updates (events only mark the check dirty)
local LOG_CAP = 80 -- event lines a check logs in one session (identical lines once)
local SEEN_LINES_MAX = 200 -- chat line ids remembered to count a line once although every chat frame filters it
local SURFACES = { "plates", "tooltip", "menu", "chat" }
local SURFACE_CHECK = { plates = V3, tooltip = V13, menu = V13, chat = V12 }
-- Seconds after the last use of a surface in which a blocked or forbidden action is attributed to it. The menu window
-- is long: the owner opens the menu, then clicks a Blizzard entry (whisper, invite, set focus).
local USE_WINDOW = { plates = 3, tooltip = 3, menu = 30, chat = 3 }
local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL",
}
local MENU_TAGS = {
    "MENU_UNIT_PLAYER", "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND",
    "MENU_UNIT_TARGET", "MENU_UNIT_SELF",
}
local CONTEXTS = { "W", "WC", "D", "DB", "R", "RB", "BG" }

local function count(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function sub(t, key)
    t[key] = t[key] or {}
    return t[key]
end

--- The counters of a check for one context (the current one by default), the check's stats and the tag.
local function ctxStats(id, tag)
    local st = Probe:Stats(id)
    st.ctx = st.ctx or {}
    tag = tag or Probe.Context()
    st.ctx[tag] = st.ctx[tag] or {}
    return st.ctx[tag], st, tag
end

--- The shape of a value already in hand: "secret", "nil" or its Lua type.
local function shape(v)
    if IsSecret(v) then
        return "secret"
    end
    if v == nil then
        return "nil"
    end
    return type(v)
end

local function missingText(list)
    return #list > 0 and ("missing: " .. table.concat(list, ", ")) or nil
end

--- The result of a check from its problems, missing items and summary.
local function verdict(problems, missing, summary)
    if #problems > 0 then
        return "fail", "revise: " .. table.concat(problems, ", ") .. " | " .. summary
    end
    if #missing > 0 then
        return "todo", missingText(missing) .. " | " .. summary
    end
    return "pass", summary
end

-- Event lines: each distinct line once per session, at most LOG_CAP per check (the counters keep everything else).
local logged, loggedCount = {}, {}

local function logOnce(id, key, line)
    logged[id] = logged[id] or {}
    if logged[id][key] or (loggedCount[id] or 0) >= LOG_CAP then
        return
    end
    logged[id][key] = true
    loggedCount[id] = (loggedCount[id] or 0) + 1
    Probe:Log(id, line)
end

-- Records: an event only marks its check dirty; the record is written FLUSH_DELAY seconds later, once.
local EVALUATE = {}
local dirty, flushing = {}, false

local function flush()
    flushing = false
    for id in pairs(dirty) do
        dirty[id] = nil
        if EVALUATE[id] then
            Probe:Record(id, EVALUATE[id]())
        end
    end
end

local function touch(id)
    dirty[id] = true
    if not flushing then
        flushing = Probe.After(FLUSH_DELAY, flush)
        if not flushing then
            flush()
        end
    end
end

-- Switches: every surface is on unless /azpp surfaces turned it off (kept in AzPr_ProbeDB.switches).
local function switches()
    local d = Probe.DB()
    d.switches = d.switches or {}
    return d.switches
end

local function on(surface)
    return switches()[surface] ~= false
end

-- Blocked and forbidden actions, attributed to the surfaces used just before them ------------------------------------

local lastUse = {} -- surface -> Probe.Ms() of its last use

local function used(surface)
    lastUse[surface] = Probe.Ms()
end

--- Who the first argument of ADDON_ACTION_BLOCKED / FORBIDDEN names: "self", "other", "secret", or "tainted" when it
--- carries the isTainted flag the API dump documents instead of an addon name.
local function blockedBy(arg1)
    if IsSecret(arg1) then
        return "secret"
    end
    if arg1 == ADDON_NAME then
        return "self"
    end
    if arg1 == true or arg1 == "true" or arg1 == "1" or arg1 == 1 then
        return "tainted"
    end
    return "other"
end

local SUSPECT = { self = true, secret = true, tainted = true }

local function onBlocked(event, arg1, func)
    local who = blockedBy(arg1)
    local what = "nil"
    if IsSecret(func) then
        what = "secret"
    elseif func ~= nil then
        what = (tostring(func):gsub("[\r\n]+", " ")):sub(1, 60)
    end
    local nowMs, tag = Probe.Ms(), Probe.Context()
    for surface, t in pairs(lastUse) do
        local seconds = (nowMs - t) / 1000
        if seconds <= USE_WINDOW[surface] then
            local id = SURFACE_CHECK[surface]
            local st = Probe:Stats(id)
            st.taint = st.taint or {}
            Tally(st.taint, tag .. ":" .. surface .. ":" .. who)
            Probe:Log(id, string.format("%s %.1f s after the %s surface: addon=%s function=%s", event, seconds, surface,
                who, what))
            touch(id)
        end
    end
end

--- Blocked or forbidden actions of this addon (or of an unknown one) attributed to the given surfaces.
local function suspectTaint(id, surfaces)
    local n = 0
    for key, v in pairs(Probe:Stats(id).taint or {}) do
        local surface, who = key:match(":(%a+):(%a+)$")
        if SUSPECT[who] and surfaces[surface] then
            n = n + v
        end
    end
    return n
end

-- Units -----------------------------------------------------------------------------------------------------------------

--- In the player's group: true, false, or nil when the client does not tell.
local function inGroup(unit)
    local partyShape, party = Read(UnitInParty, unit)
    local raidShape = Read(UnitInRaid, unit)
    if partyShape == "secret" or raidShape == "secret" then
        return nil
    end
    return party == true or raidShape == "number"
end

--- "self", "group", "friend" (a friendly player outside the group), "enemy" (a hostile player), "npc" or "unknown".
local function unitClass(unit)
    local _, isMe = Read(UnitIsUnit, unit, "player")
    if isMe == true then
        return "self"
    end
    local playerShape, isPlayer = Read(UnitIsPlayer, unit)
    if playerShape ~= "boolean" then
        return "unknown"
    end
    if not isPlayer then
        return "npc"
    end
    if inGroup(unit) then
        return "group"
    end
    local hostileShape, hostile = Read(UnitCanAttack, "player", unit)
    if hostileShape ~= "boolean" then
        return "unknown"
    end
    return hostile and "enemy" or "friend"
end

--- The shapes of UnitName's two returns: the name and the realm ("empty" for the "" of a same-realm player).
local function nameShapes(unit)
    local ok, name, realm = call(UnitName, unit)
    if not ok then
        return name == "absent" and "absent" or "error", "-"
    end
    local realmShape = shape(realm)
    if realmShape == "string" and realm == "" then
        realmShape = "empty"
    end
    return shape(name), realmShape
end

--- The shape of UnitGUID, its kind (the part before the first "-", for example "Player") and the GUID itself, only to
--- compare it with another readable GUID: it is never stored or printed.
local function guidShape(unit)
    local s, guid = Read(UnitGUID, unit)
    if s ~= "string" then
        return s, "-", nil
    end
    return s, guid:match("^(%a+)%-") or "other", guid
end

-- V2: player identity on nameplates, mouseover, target and tooltips -----------------------------------------------------

--- Reads the identity of a unit and adds it to the counters of the current context. Returns the class of the unit
--- (unitClass) or nil when it does not exist.
local function observeIdentity(unit, source)
    if IsSecret(unit) or type(unit) ~= "string" then
        Tally(sub(ctxStats(V2), "unitToken"), shape(unit))
        return nil
    end
    local _, exists = Read(UnitExists, unit)
    if exists ~= true then
        return nil
    end
    local who = unitClass(unit)
    local c, _, tag = ctxStats(V2)
    Tally(sub(c, "src"), source)
    if who == "npc" or who == "self" then
        Tally(sub(c, "skipped"), who)
        return who
    end
    local name, realm = nameShapes(unit)
    local guid, kind = guidShape(unit)
    local predicted = Probe.BoolText(C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret, unit)
    local combat = Probe.BoolText(InCombatLockdown)
    local w = sub(c, who)
    count(w, "n")
    local secret = name == "secret" or guid == "secret"
    if name == "string" and guid == "string" then
        count(w, "readable")
    elseif secret then
        count(w, "secret")
        if combat == "false" then
            count(w, "secretOOC")
        end
    else
        count(w, "other")
    end
    if predicted == "true" or predicted == "false" then
        count(c, (secret == (predicted == "true")) and "predAgree" or "predDiffer")
    end
    Probe:Cover(V2)
    local line = string.format("%s %s: UnitName %s realm %s, UnitGUID %s (%s), ShouldUnitIdentityBeSecret=%s, combat=%s",
        source, who, name, realm, guid, kind, predicted, combat)
    logOnce(V2, tag .. "|" .. line, line)
    touch(V2)
    return who
end

local function evaluateV2()
    local st = Probe:Stats(V2)
    st.ctx = st.ctx or {}
    local problems, missing, parts = {}, Probe:Missing(V2), {}
    local differ, groupInInstance = 0, 0
    for _, tag in ipairs(CONTEXTS) do
        local c = st.ctx[tag]
        if c then
            differ = differ + (c.predDiffer or 0)
            local function rs(who)
                local w = c[who] or {}
                return string.format("%d/%d", w.readable or 0, w.secret or 0)
            end
            parts[#parts + 1] = string.format("%s friend %s enemy %s group %s", tag, rs("friend"), rs("enemy"),
                rs("group"))
            if tag == "W" or tag == "WC" then
                local secret = 0
                for _, who in ipairs({ "friend", "enemy", "group", "unknown" }) do
                    secret = secret + ((c[who] or {}).secret or 0)
                end
                if secret > 0 then
                    problems[#problems + 1] = "identity of other players secret in " .. tag .. " x" .. secret
                end
                if ((c.friend or {}).readable or 0) + ((c.enemy or {}).readable or 0) == 0 then
                    missing[#missing + 1] = "a readable out-of-group player in " .. tag
                end
            else
                local g = c.group or {}
                if (g.secretOOC or 0) > 0 then
                    problems[#problems + 1] = "group identity secret out of combat in " .. tag .. " x" .. g.secretOOC
                end
                groupInInstance = groupInInstance + (g.readable or 0)
            end
        end
    end
    if differ > 0 then
        problems[#problems + 1] = "ShouldUnitIdentityBeSecret disagreed x" .. differ
    end
    if groupInInstance == 0 then
        missing[#missing + 1] = "a readable group member in an instance"
    end
    local summary = "readable/secret " .. (#parts > 0 and table.concat(parts, "; ") or "nothing seen yet")
    return verdict(problems, missing, summary)
end
EVALUATE[V2] = evaluateV2

Probe:Implement(V2, function(probe)
    local tokens = { "target", "mouseover", "focus" }
    for i = 1, PLATES do
        tokens[#tokens + 1] = "nameplate" .. i
    end
    for _, unit in ipairs((Probe.GroupUnits())) do
        tokens[#tokens + 1] = unit
    end
    local seen = {}
    for _, unit in ipairs(tokens) do
        local who = observeIdentity(unit, "run")
        if who then
            Tally(seen, who)
        end
    end
    local name, realm = nameShapes("player")
    local guid, kind = guidShape("player")
    probe:Log(V2, string.format("run | units %s | player: UnitName %s realm %s, UnitGUID %s (%s), "
        .. "GetNormalizedRealmName %s, ShouldUnitIdentityBeSecret(target)=%s, HasSecretRestrictions=%s", TallyText(seen),
        name, realm, guid, kind, (Read(GetNormalizedRealmName)),
        Probe.BoolText(C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret, "target"),
        Probe.BoolText(C_Secrets and C_Secrets.HasSecretRestrictions)))
    return evaluateV2()
end)

-- V3: nameplates, forbidden or not, and an anchored texture -----------------------------------------------------------

local markers = {} -- unit token -> our own marker frame (parented to UIParent, only anchored to the plate)
local pendingHide = {} -- unit tokens whose marker is hidden after combat

local function plateReaction(unit)
    local s, hostile = Read(UnitCanAttack, "player", unit)
    if s ~= "boolean" then
        return "unknown"
    end
    return hostile and "enemy" or "friend"
end

--- plate:<method>() as "true" / "false" / "secret" / "error" (IsForbidden is one of the few methods a forbidden frame
--- answers; anything else on a forbidden frame is never called).
local function frameFlag(frame, method)
    local ok, v = pcall(function()
        return frame[method](frame)
    end)
    if not ok then
        return "error"
    end
    if IsSecret(v) then
        return "secret"
    end
    return tostring(v and true or false)
end

local function getPlate(unit, includeForbidden)
    return Read(C_NamePlate and C_NamePlate.GetNamePlateForUnit, unit, includeForbidden)
end

local function marker(unit)
    if markers[unit] then
        return markers[unit]
    end
    local ok, frame = call(CreateFrame, "Frame", nil, UIParent)
    if not ok or not frame then
        return nil
    end
    local built = pcall(function()
        frame:SetSize(MARKER_SIZE, MARKER_SIZE)
        local t = frame:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(frame)
        t:SetTexture(TEXTURE)
        frame:Hide()
    end)
    if not built then
        return nil
    end
    markers[unit] = frame
    return frame
end

--- Hides the marker of a unit; a marker anchored to a protected plate waits for the end of combat.
local function hideMarker(unit)
    local f = markers[unit]
    if not f or not f.azppAnchored then
        pendingHide[unit] = nil
        return
    end
    local _, combat = Read(InCombatLockdown)
    if combat == true and f.azppProtected then
        pendingHide[unit] = true
        return
    end
    pendingHide[unit] = nil
    pcall(function()
        f:Hide()
        f:ClearAllPoints()
    end)
    f.azppAnchored = nil
end

local function hideAllMarkers()
    for unit in pairs(markers) do
        hideMarker(unit)
    end
end

--- Anchors the 16 px test texture above a plate that is not forbidden. In combat only to a plate that says it is not
--- protected: the probe never touches a protected frame (nor anything anchored to one) in combat.
local function anchorMarker(unit, plate, c)
    if not on("plates") then
        return
    end
    local _, combat = Read(InCombatLockdown)
    local protected = frameFlag(plate, "IsProtected")
    Tally(sub(c, "protected"), protected)
    if combat == true and protected ~= "false" then
        count(c, "anchorSkipped")
        return
    end
    local f = marker(unit)
    if not f then
        count(c, "anchorFailed")
        return
    end
    used("plates")
    local ok = pcall(function()
        f:ClearAllPoints()
        f:SetPoint("BOTTOM", plate, "TOP", 0, 2)
        f:Show()
    end)
    if ok then
        pendingHide[unit] = nil
        f.azppAnchored, f.azppProtected = true, protected ~= "false"
        count(c, "anchors")
    else
        count(c, "anchorFailed")
    end
end

--- Reads the plate of a unit both ways and classes it: "ok" (returned, not forbidden), "forbidden" (only returned with
--- includeForbidden, and forbidden), "nil" (not returned at all), or the three shapes when it is anything else.
local function probePlate(unit, origin)
    if IsSecret(unit) or type(unit) ~= "string" then
        return nil
    end
    local c, _, tag = ctxStats(V3)
    local react = plateReaction(unit)
    local _, isPlayer = Read(UnitIsPlayer, unit)
    local who = react .. (isPlayer == true and "P" or "N")
    local plainShape, plate = getPlate(unit, false)
    local fullShape, plateF = getPlate(unit, true)
    local frame = (plainShape == "table" and plate) or (fullShape == "table" and plateF) or nil
    local forbidden = frame and frameFlag(frame, "IsForbidden") or "-"
    local state
    if plainShape == "table" and forbidden == "false" then
        state = "ok"
    elseif plainShape == "nil" and fullShape == "table" and forbidden == "true" then
        state = "forbidden"
    elseif plainShape == "nil" and fullShape == "nil" then
        state = "nil"
    else
        state = plainShape .. "/" .. fullShape .. "/" .. forbidden
    end
    Tally(sub(c, "plates"), react .. ":" .. state)
    Tally(sub(c, "units"), who)
    Probe:Cover(V3)
    local line = string.format("%s %s: GetNamePlateForUnit(false) %s, (true) %s, IsForbidden %s -> %s", origin, who,
        plainShape, fullShape, forbidden, state)
    logOnce(V3, tag .. "|" .. line, line)
    if state == "ok" and (origin == "added" or origin == "run") then
        anchorMarker(unit, plate, c)
    end
    touch(V3)
    return state, react
end

--- The count of plates and their states per context, from the tallies "<reaction>:<state>".
local function plateSums(c)
    local s = { okF = 0, badF = 0, okE = 0, badE = 0 }
    for key, n in pairs(c.plates or {}) do
        local react, state = key:match("^(%a+):(.+)$")
        local good = state == "ok"
        if react == "friend" then
            s[good and "okF" or "badF"] = s[good and "okF" or "badF"] + n
        elseif react == "enemy" then
            s[good and "okE" or "badE"] = s[good and "okE" or "badE"] + n
        end
    end
    return s
end

local function evaluateV3()
    local st = Probe:Stats(V3)
    st.ctx = st.ctx or {}
    local problems, missing, parts = {}, Probe:Missing(V3), {}
    for _, tag in ipairs(CONTEXTS) do
        local c = st.ctx[tag]
        if c then
            local s = plateSums(c)
            parts[#parts + 1] = string.format("%s friend %d/%d enemy %d/%d anchors %d skipped %d", tag, s.okF, s.badF,
                s.okE, s.badE, c.anchors or 0, c.anchorSkipped or 0)
            if tag == "W" or tag == "WC" then
                if s.badF + s.badE > 0 then
                    problems[#problems + 1] = "plates forbidden or missing outside instances in " .. tag .. " x"
                        .. (s.badF + s.badE)
                end
            elseif s.badE > 0 then
                problems[#problems + 1] = "enemy plates forbidden or missing in " .. tag .. " x" .. s.badE
            end
            if (c.anchorFailed or 0) > 0 then
                problems[#problems + 1] = "anchor failed in " .. tag .. " x" .. c.anchorFailed
            end
        end
    end
    local taint = suspectTaint(V3, { plates = true })
    if taint > 0 then
        problems[#problems + 1] = "blocked or forbidden actions after an anchor x" .. taint
    end
    local w = st.ctx.W or {}
    local sw = plateSums(w)
    if sw.okF == 0 then
        missing[#missing + 1] = "a friendly plate in W (friendly nameplates on)"
    end
    if sw.okE == 0 then
        missing[#missing + 1] = "an enemy plate in W"
    end
    if (w.anchors or 0) == 0 then
        missing[#missing + 1] = "an anchored texture in W"
    end
    local summary = string.format("created %d forbidden created %d; ok/not ", st.created or 0,
        st.forbiddenCreated or 0) .. (#parts > 0 and table.concat(parts, "; ") or "no plate seen yet")
    return verdict(problems, missing, summary)
end
EVALUATE[V3] = evaluateV3

--- A CVar read (never written): its value when it is a short readable string, else its shape.
local function cvarText(name)
    local s, v = Read(C_CVar and C_CVar.GetCVar, name)
    if s == "absent" then
        s, v = Read(GetCVar, name)
    end
    if s == "string" and #v <= 8 then
        return v
    end
    return s
end

Probe:Implement(V3, function(probe)
    local states = {}
    for i = 1, PLATES do
        local unit = "nameplate" .. i
        local _, exists = Read(UnitExists, unit)
        if exists == true then
            local state, react = probePlate(unit, "run")
            Tally(states, tostring(react) .. ":" .. tostring(state))
        end
    end
    local listShape, list = Read(C_NamePlate and C_NamePlate.GetNamePlates)
    if listShape == "table" then
        local ok, n = pcall(function()
            return #list
        end)
        listShape = ok and tostring(n) or "table(?)"
    end
    local shown = 0
    for _, f in pairs(markers) do
        if f.azppAnchored then
            shown = shown + 1
        end
    end
    local st = Probe:Stats(V3)
    probe:Log(V3, string.format("run | plates %s | GetNamePlates %s | nameplateShowFriends=%s nameplateShowEnemies=%s"
        .. " | markers anchored %d, waiting for the end of combat %d | created %d, forbidden created %d | switch %s",
        TallyText(states), listShape, cvarText("nameplateShowFriends"), cvarText("nameplateShowEnemies"), shown,
        (function()
            local n = 0
            for _ in pairs(pendingHide) do
                n = n + 1
            end
            return n
        end)(), st.created or 0, st.forbiddenCreated or 0, on("plates") and "on" or "off"))
    return evaluateV3()
end)

local function onPlateCreated(event, frame)
    local st = Probe:Stats(V3)
    local key = event == "NAME_PLATE_CREATED" and "created" or "forbiddenCreated"
    count(st, key)
    st.createdForbidden = st.createdForbidden or {}
    local frameShape = shape(frame)
    Tally(st.createdForbidden, key .. ":" .. (frameShape == "table" and frameFlag(frame, "IsForbidden") or frameShape))
end

local function onForbiddenAdded(unit)
    if IsSecret(unit) or type(unit) ~= "string" then
        return
    end
    Tally(sub(ctxStats(V3), "forbiddenAdded"), plateReaction(unit))
    probePlate(unit, "forbiddenAdded")
end

-- V12: chat message filters --------------------------------------------------------------------------------------------

local chatApi -- the filter API in use: "ChatFrameUtil" or "ChatFrame_AddMessageEventFilter"
local seenLines, seenCount = {}, 0
local myGuid

local function filterApis()
    local util = type(ChatFrameUtil) == "table" and ChatFrameUtil or nil
    local function fn(t, key)
        local ok, f = pcall(function()
            return t[key]
        end)
        return ok and type(f) == "function" and f or nil
    end
    return util and fn(util, "AddMessageEventFilter"), util and fn(util, "RemoveMessageEventFilter"),
        fn(_G, "ChatFrame_AddMessageEventFilter"), fn(_G, "ChatFrame_RemoveMessageEventFilter")
end

local function playerGuid()
    if not myGuid then
        local s, g = Read(UnitGUID, "player")
        myGuid = s == "string" and g or nil
    end
    return myGuid
end

--- Counts one chat line (once, although every chat frame that shows it calls the filter) and says whether it may get
--- the texture: text, sender and GUID readable and no chat lockdown.
local function onChat(event, ...)
    local msg, sender = ...
    local lineID = (select(11, ...))
    local guid = (select(12, ...))
    local lineShape = shape(lineID)
    local first = true
    if lineShape == "number" then
        if seenLines[lineID] then
            first = false
        else
            seenLines[lineID] = true
            seenCount = seenCount + 1
            if seenCount > SEEN_LINES_MAX then
                seenLines, seenCount = { [lineID] = true }, 1
            end
        end
    end
    local msgShape, senderShape, guidShape = shape(msg), shape(sender), shape(guid)
    local lockdown = Probe.BoolText(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)
    local prefix = msgShape == "string" and senderShape == "string" and guidShape == "string" and lockdown ~= "true"
    if first then
        local c, _, tag = ctxStats(V12)
        local who = "?"
        if guidShape == "string" and playerGuid() then
            who = guid == playerGuid() and "self" or "other"
        end
        local kind = (event:gsub("^CHAT_MSG_", ""))
        count(c, "messages")
        Tally(sub(c, "events"), kind)
        Tally(sub(c, "who"), who)
        if msgShape == "secret" then
            count(c, "msgSecret")
        end
        if senderShape == "secret" then
            count(c, "senderSecret")
        end
        if guidShape == "secret" then
            count(c, "guidSecret")
        end
        if lockdown == "true" then
            count(c, "lockdown")
        end
        if (senderShape == "secret" or guidShape == "secret") and lockdown ~= "true" then
            count(c, "secretOpen")
        end
        local lineGuid = "-"
        if lineShape == "number" then
            local s, g = Read(C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID, lineID)
            lineGuid = s
            if s == "string" and guidShape == "string" then
                lineGuid = g == guid and "same" or "differs"
            end
        end
        Tally(sub(c, "lineGuid"), lineGuid)
        if prefix then
            count(c, "prefixed")
            if who == "other" then
                count(c, "prefixedOther")
            end
        end
        if who ~= "self" then
            Probe:Cover(V12)
        end
        local line = string.format("%s: text %s sender %s GUID %s (%s) lineID %s GetChatLineSenderGUID %s lockdown %s"
            .. " texture %s", kind, msgShape, senderShape, guidShape, who, lineShape, lineGuid, lockdown,
            prefix and "added" or "not added")
        logOnce(V12, tag .. "|" .. line, line)
        touch(V12)
    end
    if prefix then
        used("chat")
        return CHAT_ICON .. msg
    end
    return nil
end

--- The filter: never drops a line; returns the line with the texture in front when onChat allows it.
local function chatFilter(_, event, ...)
    if not on("chat") then
        return false
    end
    local ok, text = pcall(onChat, event, ...)
    if not ok then
        Probe:Log("errors", "chat filter " .. Probe.ErrorText(text))
        return false
    end
    if text then
        return false, text, select(2, ...)
    end
    return false
end

local filterInstalled = false

local function installChat()
    if filterInstalled then
        return
    end
    local utilAdd, _, globalAdd = filterApis()
    local st = Probe:Stats(V12)
    st.api = string.format("ChatFrameUtil.AddMessageEventFilter %s, ChatFrame_AddMessageEventFilter %s",
        utilAdd and "present" or "absent", globalAdd and "present" or "absent")
    local add = utilAdd or globalAdd
    if not add then
        st.apiUsed = nil
        return
    end
    chatApi = utilAdd and "ChatFrameUtil" or "ChatFrame_AddMessageEventFilter"
    st.apiUsed = chatApi
    local failed = 0
    for _, event in ipairs(CHAT_EVENTS) do
        if not pcall(add, event, chatFilter) then
            failed = failed + 1
        end
    end
    st.addFailed = failed
    filterInstalled = true
end

local function removeChat()
    if not filterInstalled then
        return
    end
    local _, utilRemove, _, globalRemove = filterApis()
    local remove = (chatApi == "ChatFrameUtil" and utilRemove) or globalRemove
    if remove then
        for _, event in ipairs(CHAT_EVENTS) do
            pcall(remove, event, chatFilter)
        end
    end
    filterInstalled = false
end

local function evaluateV12()
    local st = Probe:Stats(V12)
    st.ctx = st.ctx or {}
    local problems, missing, parts = {}, Probe:Missing(V12), {}
    if not st.apiUsed then
        problems[#problems + 1] = "no chat filter API (" .. tostring(st.api or "not checked yet") .. ")"
    elseif (st.addFailed or 0) > 0 then
        problems[#problems + 1] = "the filter failed on " .. st.addFailed .. " events"
    end
    for _, tag in ipairs(CONTEXTS) do
        local c = st.ctx[tag]
        if c then
            parts[#parts + 1] = string.format("%s %d lines (%s) texture %d, secret text/sender/GUID %d/%d/%d, "
                .. "lockdown %d", tag, c.messages or 0, TallyText(c.who), c.prefixed or 0, c.msgSecret or 0,
                c.senderSecret or 0, c.guidSecret or 0, c.lockdown or 0)
            if (c.secretOpen or 0) > 0 then
                problems[#problems + 1] = "sender or GUID secret outside lockdown in " .. tag .. " x" .. c.secretOpen
            end
        end
    end
    local taint = suspectTaint(V12, { chat = true })
    if taint > 0 then
        problems[#problems + 1] = "blocked or forbidden actions after a line with the texture x" .. taint
    end
    if ((st.ctx.W or {}).prefixedOther or 0) == 0 then
        missing[#missing + 1] = "a line of another player with the texture in W"
    end
    local summary = "API " .. tostring(st.apiUsed or "none") .. "; "
        .. (#parts > 0 and table.concat(parts, "; ") or "no chat line yet")
    return verdict(problems, missing, summary)
end
EVALUATE[V12] = evaluateV12

Probe:Implement(V12, function(probe)
    local utilAdd, utilRemove, globalAdd, globalRemove = filterApis()
    local function p(f)
        return f and "present" or "absent"
    end
    probe:Log(V12, string.format("run | ChatFrameUtil %s: Add %s Remove %s | ChatFrame_AddMessageEventFilter %s, "
        .. "Remove %s | in use %s | filter %s | InChatMessagingLockdown=%s | switch %s", shape(ChatFrameUtil), p(utilAdd),
        p(utilRemove), p(globalAdd), p(globalRemove), tostring(chatApi or "none"),
        filterInstalled and "installed" or "not installed",
        Probe.BoolText(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown), on("chat") and "on" or "off"))
    return evaluateV12()
end)

-- V13: unit tooltip and unit menus -------------------------------------------------------------------------------------

local tooltipHooked, menuHooked = false, false
local tooltipDataLogged, menuDataLogged = false, {}

--- The unit tooltip post-call: the unit (its identity goes to V2), the GUID of the tooltip data, one added line.
local function onTooltip(tooltip, data)
    if not on("tooltip") then
        return
    end
    local c, _, tag = ctxStats(V13)
    count(c, "tooltips")
    local combat = Probe.BoolText(InCombatLockdown)
    if combat == "true" then
        count(c, "tooltipsInCombat")
    end
    local ok, name, unit = pcall(function()
        return tooltip:GetUnit()
    end)
    local nameShape = ok and shape(name) or "error"
    local unitShape = ok and shape(unit) or "error"
    local kind, who, identified = unitShape, "-", false
    if unitShape == "string" then
        kind = Probe.TokenKind(unit)
        who = observeIdentity(unit, "tooltip") or "gone"
        identified = (guidShape(unit)) == "string"
    elseif unitShape == "secret" then
        -- the tooltip hides which unit it shows: for V2 an identity that cannot be read, of an unknown unit
        local c2, _, tag2 = ctxStats(V2)
        local w = sub(c2, "unknown")
        count(w, "n")
        count(w, "secret")
        if combat == "false" then
            count(w, "secretOOC")
        end
        Probe:Cover(V2)
        local line2 = "tooltip unknown: GetUnit unit secret, name " .. nameShape .. ", combat=" .. combat
        logOnce(V2, tag2 .. "|" .. line2, line2)
        touch(V2)
    end
    Tally(sub(c, "units"), kind)
    if who == "friend" or who == "enemy" or who == "group" or who == "unknown" then
        count(c, "otherUnits")
        if identified then
            count(c, "otherIdentified")
        end
    end
    local dataGuid = "-"
    if IsSecret(data) then
        dataGuid = "data secret"
    elseif type(data) == "table" then
        local okG, g = pcall(function()
            return data.guid
        end)
        dataGuid = okG and shape(g) or "error"
        if dataGuid == "string" and unitShape == "string" then
            local s, _, ug = guidShape(unit)
            if s == "string" then
                dataGuid = ug == g and "same" or "differs"
            end
        end
        if not tooltipDataLogged then
            tooltipDataLogged = true
            Probe:Log(V13, "tooltip data " .. (Probe.TableShape(data)))
        end
    end
    local added = pcall(function()
        tooltip:AddLine(TOOLTIP_LINE, 0.4, 0.8, 1)
    end)
    count(c, added and "linesAdded" or "lineFailed")
    used("tooltip")
    Probe:Cover(V13)
    local line = string.format("tooltip: GetUnit name %s unit %s (%s), data.guid %s, combat=%s, line %s", nameShape,
        kind, who, dataGuid, combat, added and "added" or "failed")
    logOnce(V13, tag .. "|" .. line, line)
    touch(V13)
end

local function installTooltip()
    if tooltipHooked then
        return
    end
    local st = Probe:Stats(V13)
    local okT, unitType = pcall(function()
        return Enum.TooltipDataType.Unit
    end)
    local okP, postCall = pcall(function()
        return TooltipDataProcessor.AddTooltipPostCall
    end)
    local handler = function(tooltip, data)
        local ok, err = pcall(onTooltip, tooltip, data)
        if not ok then
            Probe:Log("errors", "tooltip " .. Probe.ErrorText(err))
        end
    end
    st.tooltipType = okT and shape(unitType) or "absent"
    if okP and type(postCall) == "function" and okT and unitType ~= nil and not IsSecret(unitType)
        and pcall(postCall, unitType, handler) then
        st.tooltipHook = "TooltipDataProcessor"
    elseif type(GameTooltip) == "table" and pcall(function()
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            handler(tooltip, nil)
        end)
    end) then
        st.tooltipHook = "OnTooltipSetUnit"
    else
        st.tooltipHook = nil
    end
    tooltipHooked = true
end

--- A frame name that may be written: a Blizzard frame name ("TargetFrame", "CompactPartyFrameMember1" as
--- "CompactPartyFrameMemberN"), never anything else.
local function ownerText(owner)
    local ok, n = pcall(function()
        return owner:GetName()
    end)
    if not ok then
        return "error"
    end
    if IsSecret(n) then
        return "secret"
    end
    if n == nil then
        return "unnamed"
    end
    if type(n) == "string" and #n <= 48 and n:match("^[%w_]+$") and (n:find("Frame") or n:find("Button")) then
        return (n:gsub("%d+", "N"))
    end
    return "named"
end

local function onMenuClick(tag)
    used("menu")
    local c = ctxStats(V13)
    count(c, "menuClicks")
    Probe:Log(V13, "menu entry clicked in " .. tag)
    Probe.Print("probe menu entry")
    touch(V13)
end

--- The unit menu callback: counts the menu, writes its context shape once per tag, adds a title and one entry.
local function onMenu(tag, owner, root, contextData)
    if not on("menu") then
        return
    end
    local c, _, ctxTag = ctxStats(V13)
    Tally(sub(c, "menus"), tag)
    local unitKind = "-"
    if IsSecret(contextData) then
        unitKind = "contextData secret"
    elseif type(contextData) == "table" then
        local okU, u = pcall(function()
            return contextData.unit
        end)
        unitKind = okU and Probe.TokenKind(u) or "error"
        if not menuDataLogged[tag] then
            menuDataLogged[tag] = true
            Probe:Log(V13, "menu " .. tag .. " contextData " .. (Probe.TableShape(contextData)))
        end
    end
    local added = pcall(function()
        root:CreateDivider()
        root:CreateTitle("AzPr Probe")
        root:CreateButton(MENU_ENTRY, function()
            local ok, err = pcall(onMenuClick, tag)
            if not ok then
                Probe:Log("errors", "menu entry " .. Probe.ErrorText(err))
            end
        end)
    end)
    count(c, added and "entries" or "entryFailed")
    used("menu")
    Probe:Cover(V13)
    local line = string.format("menu %s from %s: unit %s, entry %s", tag, ownerText(owner), unitKind,
        added and "added" or "failed")
    logOnce(V13, ctxTag .. "|" .. line, line)
    touch(V13)
end

local function installMenu()
    if menuHooked then
        return
    end
    menuHooked = true
    local st = Probe:Stats(V13)
    st.unitPopup = type(UnitPopup_OpenMenu) == "function" and "present" or "absent"
    local okM, modify = pcall(function()
        return Menu.ModifyMenu
    end)
    if not okM or type(modify) ~= "function" then
        st.menuApi = nil
        return
    end
    local tags = 0
    for _, tag in ipairs(MENU_TAGS) do
        local ok = pcall(modify, tag, function(owner, root, contextData)
            local okH, err = pcall(onMenu, tag, owner, root, contextData)
            if not okH then
                Probe:Log("errors", "menu " .. Probe.ErrorText(err))
            end
        end)
        if ok then
            tags = tags + 1
        end
    end
    st.menuApi = tags > 0 and "Menu.ModifyMenu" or nil
    st.menuTags = tags
end

local function evaluateV13()
    local st = Probe:Stats(V13)
    st.ctx = st.ctx or {}
    local problems, missing, parts = {}, Probe:Missing(V13), {}
    if not st.tooltipHook then
        problems[#problems + 1] = "no unit tooltip hook (TooltipDataProcessor and OnTooltipSetUnit)"
    end
    if not st.menuApi then
        problems[#problems + 1] = "Menu.ModifyMenu missing (UnitPopup_OpenMenu " .. tostring(st.unitPopup or "?") .. ")"
    end
    local menus, clicks = 0, 0
    for _, tag in ipairs(CONTEXTS) do
        local c = st.ctx[tag]
        if c then
            local opened = 0
            for _, n in pairs(c.menus or {}) do
                opened = opened + n
            end
            menus = menus + opened
            clicks = clicks + (c.menuClicks or 0)
            parts[#parts + 1] = string.format("%s tt %d/%d/%d c%d menu %d click %d", tag, c.tooltips or 0,
                c.otherUnits or 0, c.otherIdentified or 0, c.tooltipsInCombat or 0, opened, c.menuClicks or 0)
            if (c.lineFailed or 0) > 0 then
                problems[#problems + 1] = "tooltip line failed in " .. tag .. " x" .. c.lineFailed
            end
            if (c.entryFailed or 0) > 0 then
                problems[#problems + 1] = "menu entry failed in " .. tag .. " x" .. c.entryFailed
            end
        end
    end
    local taint = suspectTaint(V13, { tooltip = true, menu = true })
    if taint > 0 then
        problems[#problems + 1] = "blocked or forbidden actions after the tooltip or the menu x" .. taint
    end
    for _, tag in ipairs({ "W", "WC" }) do
        if ((st.ctx[tag] or {}).otherIdentified or 0) == 0 then
            missing[#missing + 1] = "a tooltip of another player with its unit identified in " .. tag
        end
    end
    if menus == 0 then
        missing[#missing + 1] = "a unit menu opened"
    end
    if clicks == 0 then
        missing[#missing + 1] = "the probe menu entry clicked"
    end
    -- "tt a/o/i cN": tooltips all / of other players / with the unit identified, N in combat
    local summary = string.format("tooltip %s, menu %s (%d tags); ", tostring(st.tooltipHook or "none"),
        tostring(st.menuApi or "none"), st.menuTags or 0) .. (#parts > 0 and table.concat(parts, "; ") or "nothing yet")
    return verdict(problems, missing, summary)
end
EVALUATE[V13] = evaluateV13

Probe:Implement(V13, function(probe)
    local st = Probe:Stats(V13)
    local function has(get)
        local ok, v = pcall(get)
        return ok and shape(v) or "absent"
    end
    local dataShape = "-"
    local s, data = Read(C_TooltipInfo and C_TooltipInfo.GetUnit, "target")
    if s == "table" then
        dataShape = (Probe.TableShape(data))
    else
        dataShape = s
    end
    probe:Log(V13, string.format("run | TooltipDataProcessor %s, AddTooltipPostCall %s, Enum.TooltipDataType.Unit %s, "
        .. "Menu %s, Menu.ModifyMenu %s, UnitPopup_OpenMenu %s | hooks: tooltip %s, menu %s (%d tags) | switches "
        .. "tooltip %s menu %s | C_TooltipInfo.GetUnit(target) %s",
        shape(TooltipDataProcessor), has(function() return TooltipDataProcessor.AddTooltipPostCall end),
        has(function() return Enum.TooltipDataType.Unit end), shape(Menu), has(function() return Menu.ModifyMenu end),
        shape(UnitPopup_OpenMenu), tostring(st.tooltipHook or "none"), tostring(st.menuApi or "none"),
        st.menuTags or 0, on("tooltip") and "on" or "off", on("menu") and "on" or "off", dataShape))
    return evaluateV13()
end)

-- Events and the /azpp surfaces command --------------------------------------------------------------------------------

Probe:Watch({ "PLAYER_LOGIN", "NAME_PLATE_CREATED", "FORBIDDEN_NAME_PLATE_CREATED", "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED", "FORBIDDEN_NAME_PLATE_UNIT_ADDED", "FORBIDDEN_NAME_PLATE_UNIT_REMOVED",
    "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED",
    "ADDON_ACTION_FORBIDDEN" }, function(event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        observeIdentity(unit, "plate")
        probePlate(unit, "added")
    elseif event == "NAME_PLATE_UNIT_REMOVED" or event == "FORBIDDEN_NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if not IsSecret(unit) and type(unit) == "string" then
            hideMarker(unit)
        end
    elseif event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" then
        onForbiddenAdded(...)
    elseif event == "NAME_PLATE_CREATED" or event == "FORBIDDEN_NAME_PLATE_CREATED" then
        onPlateCreated(event, ...)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        observeIdentity("mouseover", "mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        observeIdentity("target", "target")
    elseif event == "PLAYER_REGEN_ENABLED" then
        for unit in pairs(pendingHide) do
            hideMarker(unit)
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        onBlocked(event, ...)
    elseif event == "PLAYER_LOGIN" then
        installTooltip()
        installMenu()
        if on("chat") then
            installChat()
        else
            Probe:Stats(V12).api = "not checked: chat switched off"
        end
    end
end)

local function surfaceStates()
    local parts = {}
    for _, s in ipairs(SURFACES) do
        parts[#parts + 1] = s .. " " .. (on(s) and "on" or "off")
    end
    return table.concat(parts, ", ")
end

local function setSurface(surface, value)
    switches()[surface] = value
    if surface == "chat" then
        if value then
            installChat()
        else
            removeChat()
        end
    elseif surface == "plates" and not value then
        hideAllMarkers()
    end
end

Probe:AddCommand("surfaces", "/azpp surfaces [plates|tooltip|menu|chat|all on|off] - show or switch the M0.4 hooks "
    .. "(all on by default; tooltip and menu stay registered and do nothing when off)", function(rest)
    local name, state = rest:lower():match("^(%S*)%s*(%S*)$")
    if name == "" then
        Probe.Print("surfaces: " .. surfaceStates())
        return
    end
    local list = name == "all" and SURFACES or (SURFACE_CHECK[name] and { name }) or nil
    if not list or (state ~= "on" and state ~= "off") then
        Probe.Print("usage: /azpp surfaces [plates|tooltip|menu|chat|all on|off]")
        return
    end
    for _, s in ipairs(list) do
        setSurface(s, state == "on")
    end
    Probe.Print("surfaces: " .. surfaceStates())
end)
