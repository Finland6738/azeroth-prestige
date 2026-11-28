-- AzPr Probe, M0.7: V15 interactions, transports, cinematics, loading screens, deaths, UI panels and the calendar.
-- Specification: docs/spike/README.md, V15. Lua 5.1. Every game API call goes through pcall (Probe.Call / Probe.Read);
-- every value is tested with issecretvalue before any other use. Never a name: NPCs, subjects, zones and calendar
-- events are never read as text; the positions of the player are only compared in memory. The probe never ends a
-- cinematic, closes a window or moves the character: it only listens and asks (C_Calendar.OpenCalendar asks the server
-- for the calendar data).

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local Read, IsSecret, Value, Tally, TallyText = Probe.Read, Probe.IsSecret, Probe.Value, Probe.Tally, Probe.TallyText

local V15 = "V15"

-- The interactions the check must see: label and the keys of Enum.PlayerInteractionType that mean it (the enumeration
-- is not in the API dump: every key is logged at the run, so that a wrong key here can be read in step M0.9).
local INTERACTIONS = {
    { "gossip", { "Gossip" } },
    { "quest giver", { "QuestGiver" } },
    { "vendor", { "Merchant" } },
    { "trainer", { "Trainer" } },
    { "bank", { "Banker" } },
    { "auctioneer", { "Auctioneer" } },
    { "mailbox", { "MailInfo" } },
    { "flight master", { "TaxiNode", "FlightMaster" } },
    { "innkeeper", { "Binder" } },
}
local PANELS = { "left", "center", "right", "doublewide" }
local RIDES = { flight = true, boat = true, zeppelin = true, panels = true }
local WATCH_DEFAULT, WATCH_MIN, WATCH_MAX = 300, 30, 900
local RIDE_SAMPLES = 30 -- a watched ride shorter than this (in seconds) decides nothing
local STALE_DELAY = 2 -- seconds after an interaction is shown before the other open ones are asked about
local CALENDAR_WAIT = 10

local open = {} -- key of the interaction -> its value, while it is open (this session)
local stale = {} -- open interactions already counted as without a hide
local watch -- the running /azpp uiwatch
local loadingSince, calendarAsked

local function stats()
    return Probe:Stats(V15)
end

local function sub(t, key)
    t[key] = t[key] or {}
    return t[key]
end

local function coverHere()
    if Probe.Context() == "W" then
        Probe:Cover(V15, "W")
    end
end

local evaluate
local touch = Probe:Toucher(V15, function()
    return evaluate()
end)

-- Interactions and UI panels -------------------------------------------------------------------------------------------

--- The name of the frame in a UI panel: only a Blizzard-like frame name ("GossipFrame"), else its shape.
local function panelName(position)
    local shape, frame = Read(GetUIPanel, position)
    if frame == nil then
        return shape
    end
    if type(frame) ~= "table" then
        return shape
    end
    local ok, getName = pcall(function()
        return frame.GetName
    end)
    local shapeName, name = Read(ok and getName or nil, frame)
    if type(name) == "string" and #name <= 40 and name:match("^%a+Frame$") then
        return name
    end
    return "frame (" .. shapeName .. ")"
end

local function panelsText()
    local parts = {}
    for _, position in ipairs(PANELS) do
        parts[#parts + 1] = position .. "=" .. panelName(position)
    end
    return "GetUIPanel " .. table.concat(parts, " ")
end

local function notePanels(why)
    local text = panelsText()
    for _, position in ipairs(PANELS) do
        local name = panelName(position)
        if name:match("^%a+Frame$") then
            sub(stats(), "panels")[name] = true
        end
    end
    Probe:LogOnce(V15, text, why .. " | " .. text)
end

--- An open interaction the client no longer reports, with no hide event: counted once as shown without a hide. It stays
--- open, so that a late hide still pairs it (a type fails only when it was never paired).
local function checkStale(except)
    local P = C_PlayerInteractionManager or {}
    for key, value in pairs(open) do
        if key ~= except then
            local shape, still = Read(P.IsInteractingWithNpcOfType, value)
            if shape == "boolean" and still == false and not stale[key] then
                stale[key] = true
                Tally(sub(stats(), "noHide"), key)
                Probe:Log(V15, "interaction " .. key .. " no longer active and no HIDE received")
                touch()
            end
        end
    end
end

local function onInteraction(event, interaction)
    local st = stats()
    if IsSecret(interaction) then
        Tally(st, "interactionSecret")
        Probe:LogOnce(V15, event .. "secret", event .. " type=secret")
        touch()
        return
    end
    local key = Probe.EnumKey("PlayerInteractionType", interaction)
    coverHere()
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        Tally(sub(st, "shows"), key)
        if open[key] ~= nil then
            Tally(sub(st, "reshown"), key)
        end
        open[key], stale[key] = interaction, nil
        Probe.After(STALE_DELAY, function()
            checkStale(key)
            notePanels("with interaction " .. key)
        end)
    else
        Tally(sub(st, open[key] ~= nil and "paired" or "loneHide"), key)
        open[key] = nil
    end
    Probe:LogOnce(V15, event .. key, string.format("%s type=%s (%s)", event, Value(interaction), key))
    touch()
end

-- Transports -----------------------------------------------------------------------------------------------------------

--- The map id and the position of the player on it (numbers kept in memory only).
local function position()
    local shape, map = Read(C_Map and C_Map.GetBestMapForUnit, "player")
    if type(map) ~= "number" then
        return shape, nil
    end
    local _, vector = Read(C_Map.GetPlayerMapPosition, map, "player")
    if type(vector) ~= "table" then
        return map, nil
    end
    local ok, x, y = pcall(function()
        return vector:GetXY()
    end)
    if not ok or IsSecret(x) or IsSecret(y) or type(x) ~= "number" or type(y) ~= "number" then
        return map, nil
    end
    return map, x, y
end

local function transportText()
    return string.format("UnitOnTaxi=%s UnitInVehicle=%s IsMounted=%s IsFlying=%s speed=%s map=%s",
        Probe.BoolText(UnitOnTaxi, "player"), Probe.BoolText(UnitInVehicle, "player"), Probe.BoolText(IsMounted),
        Probe.BoolText(IsFlying), Probe.ReadValue(GetUnitSpeed, "player"),
        Probe.ReadValue(C_Map and C_Map.GetBestMapForUnit, "player"))
end

local function ride(label)
    return sub(sub(stats(), "rides"), label)
end

--- One second of a watched ride: the signals that could tell a transport.
local function sample(w)
    local r = ride(w.label)
    Tally(r, "samples")
    local _, taxi = Read(UnitOnTaxi, "player")
    if taxi == true then
        Tally(r, "taxi")
        stats().taxiSeen = 1
    end
    local _, vehicle = Read(UnitInVehicle, "player")
    if vehicle == true then
        Tally(r, "vehicle")
    end
    local _, speed = Read(GetUnitSpeed, "player")
    local map, x, y = position()
    if x and w.x and map == w.map and speed == 0 and (math.abs(x - w.x) + math.abs(y - w.y)) > 0.0005 then
        Tally(r, "movedStill") -- the position changes while the character stands still: something carries it
    end
    if w.map and map ~= w.map then
        Tally(r, "mapChanges")
    end
    w.map, w.x, w.y = map, x, y
    local text = transportText()
    local key = text:gsub("speed=%S+", "") -- a changing speed alone writes no line
    if key ~= w.key then
        w.key = key
        Probe:Log(V15, "uiwatch " .. w.label .. " | " .. text)
    end
    notePanels("uiwatch " .. w.label)
end

local function rideText(label)
    local r = (stats().rides or {})[label]
    if not r then
        return "not watched"
    end
    return TallyText(r)
end

local function stopWatch(why)
    local w = watch
    if not w then
        Probe.Print("no ride is being watched")
        return
    end
    watch = nil
    local line = "uiwatch " .. w.label .. " " .. why .. " | totals " .. rideText(w.label)
    Probe:Log(V15, line)
    Probe.Print(line)
    Probe:Record(V15, evaluate())
end

local function tick(w)
    if watch ~= w then
        return
    end
    local ok, err = pcall(sample, w)
    if not ok then
        Probe:Log("errors", "uiwatch " .. Probe.ErrorText(err))
    end
    w.left = w.left - 1
    if w.left <= 0 then
        stopWatch("ended")
    elseif not Probe.After(1, function() tick(w) end) then
        stopWatch("ended (no timer)")
    end
end

Probe:AddCommand("uiwatch", "/azpp uiwatch flight|boat|zeppelin|panels [seconds] | stop", function(rest)
    local label, seconds = rest:lower():match("^(%a+)%s*(%d*)$")
    if label == "stop" then
        stopWatch("stopped")
        return
    end
    if not label or not RIDES[label] then
        Probe.Print("/azpp uiwatch flight|boat|zeppelin|panels [seconds] | stop")
        return
    end
    local n = math.max(WATCH_MIN, math.min(tonumber(seconds) or WATCH_DEFAULT, WATCH_MAX))
    if watch then
        stopWatch("replaced")
    end
    watch = { label = label, left = n }
    coverHere()
    Probe.Print(string.format("watching (%s) for %d s, one sample a second; /azpp uiwatch stop ends it", label, n))
    tick(watch)
end)

local function onControl(event)
    Tally(stats(), event == "PLAYER_CONTROL_LOST" and "controlLost" or "controlGained")
    if watch then
        Tally(ride(watch.label), event == "PLAYER_CONTROL_LOST" and "controlLost" or "controlGained")
    end
    Probe:Log(V15, event .. " | " .. transportText())
    -- the taxi flag may follow the loss of control
    Probe.After(1, function()
        local _, taxi = Read(UnitOnTaxi, "player")
        if taxi == true then
            stats().taxiSeen = 1
        end
        Probe:Log(V15, event .. " +1s | " .. transportText())
        touch()
    end)
    touch()
end

local function onZone(event)
    Probe:LogOnce(V15, event .. transportText(), event .. " | " .. transportText())
end

-- Cinematics, loading screens and deaths -------------------------------------------------------------------------------

local function onCinematic(event, a, b)
    local st = stats()
    Tally(sub(st, "cinematics"), event)
    local payload = ""
    if event == "CINEMATIC_START" then
        payload = " canBeCancelled=" .. Value(a) .. " forcedAspectRatio=" .. Value(b)
    elseif event == "PLAY_MOVIE" then
        payload = " movieID=" .. Value(a)
    end
    Probe:Log(V15, event .. payload .. " | InCinematic=" .. Probe.BoolText(InCinematic) .. " IsInCinematicScene="
        .. Probe.BoolText(IsInCinematicScene))
    coverHere()
    touch()
end

local function onLoading(event)
    local st = stats()
    if event == "LOADING_SCREEN_ENABLED" then
        Tally(st, "loadingEnabled")
        loadingSince = Probe.Ms()
        Probe:Log(V15, event)
    else
        Tally(st, "loadingDisabled")
        if loadingSince then
            Tally(st, "loadingPaired")
            Probe:Log(V15, string.format("%s after %d ms", event, Probe.Ms() - loadingSince))
            loadingSince = nil
            Probe:Cover(V15, "LS")
        else
            Probe:Log(V15, event .. " without a LOADING_SCREEN_ENABLED seen")
        end
    end
    touch()
end

local function onDeath(event)
    Tally(sub(stats(), "death"), event)
    Probe:Log(V15, event .. " | UnitIsDeadOrGhost=" .. Probe.BoolText(UnitIsDeadOrGhost, "player") .. " UnitIsGhost="
        .. Probe.BoolText(UnitIsGhost, "player"))
    coverHere()
    touch()
end

-- Calendar -------------------------------------------------------------------------------------------------------------

--- The number of events of today: a count, never a title.
local function readCalendar(why)
    local st = stats()
    local shape, today = Read(C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime)
    local day
    if type(today) == "table" and not IsSecret(today.monthDay) then
        day = today.monthDay
    end
    if type(day) ~= "number" then
        st.calendar = "no date (" .. shape .. ")"
        Probe:Log(V15, why .. " | GetCurrentCalendarTime=" .. shape)
    else
        local text = Probe.ReadValue(C_Calendar and C_Calendar.GetNumDayEvents, 0, day)
        st.calendar = tonumber(text) and "readable" or text
        if tonumber(text) then
            st.calendarCount = tonumber(text)
        end
        Probe:Log(V15, why .. " | GetNumDayEvents(0, today)=" .. text)
    end
    touch()
end

local function askCalendar()
    if Probe.BoolText(InCombatLockdown) == "true" then
        Probe:Log(V15, "calendar not asked: in combat")
        return
    end
    local ok, res = Probe.Returns(C_Calendar and C_Calendar.OpenCalendar)
    if not ok then
        stats().calendar = res[1] == "absent" and "absent" or "error"
        Probe:Log(V15, "OpenCalendar " .. stats().calendar)
        return
    end
    calendarAsked = Probe.Ms()
    Probe:Log(V15, "OpenCalendar called")
    local asked = calendarAsked
    Probe.After(CALENDAR_WAIT, function()
        if calendarAsked == asked then
            calendarAsked = nil
            readCalendar("no CALENDAR_UPDATE_EVENT_LIST after " .. CALENDAR_WAIT .. " s")
        end
    end)
end

local function onCalendar(event)
    Tally(stats(), "calendarUpdates")
    if calendarAsked then
        local ms = Probe.Ms() - calendarAsked
        calendarAsked = nil
        readCalendar(string.format("%s after %d ms", event, ms))
    end
end

-- The result -----------------------------------------------------------------------------------------------------------

local function shownAndPaired(st, keys)
    for _, key in ipairs(keys) do
        if ((st.paired or {})[key] or 0) > 0 then
            return true
        end
    end
    return false
end

evaluate = function()
    local st = stats()
    local problems, missing = {}, Probe:Missing(V15)
    if (st.interactionSecret or 0) > 0 then
        problems[#problems + 1] = "interaction type secret x" .. st.interactionSecret
    end
    for key, n in pairs(st.noHide or {}) do
        if ((st.paired or {})[key] or 0) == 0 then
            problems[#problems + 1] = "no HIDE for " .. key .. " x" .. n
        end
    end
    local seen = 0
    for _, entry in ipairs(INTERACTIONS) do
        if shownAndPaired(st, entry[2]) then
            seen = seen + 1
        else
            missing[#missing + 1] = entry[1]
        end
    end
    local rides = st.rides or {}
    for _, label in ipairs({ "flight", "boat", "zeppelin" }) do
        local r = rides[label]
        local signal = r and ((r.taxi or 0) + (r.vehicle or 0) + (r.controlLost or 0) + (r.movedStill or 0)) > 0
        if label == "flight" then
            if not st.taxiSeen then
                if r and (r.samples or 0) >= RIDE_SAMPLES then
                    problems[#problems + 1] = "flight not seen by UnitOnTaxi"
                else
                    missing[#missing + 1] = "a flight"
                end
            end
        elseif not r or (r.samples or 0) < RIDE_SAMPLES then
            missing[#missing + 1] = "a watched " .. label
        elseif not signal then
            problems[#problems + 1] = "no signal on the " .. label
        end
    end
    local cinematics = st.cinematics or {}
    if not (cinematics.CINEMATIC_START or cinematics.PLAY_MOVIE) then
        missing[#missing + 1] = "a cinematic"
    end
    if not (st.death or {}).PLAYER_DEAD then
        missing[#missing + 1] = "a death"
    end
    if st.calendar == nil then
        missing[#missing + 1] = "the calendar (/azpp run V15)"
    elseif st.calendar ~= "readable" then
        problems[#problems + 1] = "calendar " .. st.calendar
    end
    local summary = string.format("interactions paired %d/%d; taxi %s; boat %s; zeppelin %s; cinematics %s; loading "
        .. "%d; calendar %s", seen, #INTERACTIONS, st.taxiSeen and "yes" or "no", rideText("boat"),
        rideText("zeppelin"), TallyText(st.cinematics), st.loadingPaired or 0, tostring(st.calendar or "-"))
    return Probe.Verdict(problems, missing, summary)
end

Probe:Watch({ "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "PLAYER_CONTROL_LOST",
    "PLAYER_CONTROL_GAINED", "ZONE_CHANGED_NEW_AREA", "CINEMATIC_START", "CINEMATIC_STOP", "PLAY_MOVIE", "STOP_MOVIE",
    "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "CALENDAR_UPDATE_EVENT_LIST" }, function(event, ...)
    if event:sub(1, 19) == "PLAYER_INTERACTION_" then
        onInteraction(event, ...)
    elseif event:sub(1, 15) == "PLAYER_CONTROL_" then
        onControl(event)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        onZone(event)
    elseif event:sub(1, 15) == "LOADING_SCREEN_" then
        onLoading(event)
    elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        onDeath(event)
    elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
        onCalendar(event)
    else
        onCinematic(event, ...)
    end
end)

Probe:Implement(V15, function(probe)
    local keys = {}
    local ok = pcall(function()
        for key, value in pairs(Enum.PlayerInteractionType) do
            keys[#keys + 1] = tostring(key) .. "=" .. Value(value)
        end
    end)
    table.sort(keys)
    probe:Log(V15, "run | Enum.PlayerInteractionType " .. (ok and #keys .. " keys" or "unreadable"))
    for i = 1, #keys, 12 do
        probe:LogOnce(V15, "enum" .. i, "enum | " .. table.concat(keys, " ", i, math.min(i + 11, #keys)))
    end
    checkStale()
    probe:Log(V15, "run | " .. transportText())
    notePanels("run")
    coverHere()
    askCalendar()
    return evaluate()
end)
