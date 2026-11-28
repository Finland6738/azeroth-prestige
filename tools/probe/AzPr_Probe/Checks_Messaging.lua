-- AzPr Probe, M0.5: the network checks of SPEC-06 section 12. V4 addon messages on GUILD, PARTY, RAID, INSTANCE_CHAT,
-- WHISPER and a hidden custom channel: pings and pong replies, bursts that measure the throttle per distribution with
-- every Enum.SendAddonMessageResult, a size test up to 300 bytes, the channel joined with JoinTemporaryChannel, its
-- member count, cross-faction delivery and its removal from the chat frames. V5 snapshots of
-- C_ChatInfo.InChatMessagingLockdown() and of the addon restrictions in every context, with one test send per
-- distribution and the time between the end of a fight or an encounter and the end of the lockdown. V14 round trips of
-- C_EncodingUtil (CBOR, JSON, compression, Base64, hex) with sizes and milliseconds, and one encoded profile sent to a
-- second client.
-- Specification: docs/spike/README.md, V4, V5, V14. Lua 5.1. Every game API call goes through pcall (Probe.Call /
-- Probe.Read); every value is tested with issecretvalue before any other use. Only the test prefix (Probe.TEST_PREFIX)
-- is registered or sent. Never a name: own messages are told apart by a random token of this session, never by the
-- sender's name; the sender of a message is passed once to the reply of a WHISPER ping and never kept; a character name
-- typed in a command is kept in memory only while its burst runs. Test messages are capped per burst and per session,
-- and a burst stops with /azpp burst stop or after REFUSALS_STOP refusals in a row.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local call, Read, IsSecret, Tally, TallyText, BoolText = Probe.Call, Probe.Read, Probe.IsSecret, Probe.Tally,
    Probe.TallyText, Probe.BoolText

local V4 = "V4"
local V5 = "V5"
local V14 = "V14"

local PREFIX = Probe.TEST_PREFIX -- "AzPrP": the real prefix of the addon is never registered or sent
local TEST_CHANNEL = PREFIX .. "Probe" -- the hidden custom channel of the probe (never the addon's channel)
local MAX_BYTES = 255 -- the documented limit of one addon message
local BURST_MAX = 50 -- messages in one burst
local GAP_MAX = 5 -- seconds between two messages of a burst
local SESSION_CAP = 400 -- test messages one session may send (pings, bursts, sizes, lockdown tests, encoded chunks)
local REFUSALS_STOP = 10 -- a burst stops after this many refused sends in a row
local REPLY_WINDOW, REPLY_MAX = 10, 8 -- automatic replies (pong, acknowledgements): at most 8 in 10 seconds
local END_DELAY, END_RETRIES = 2, 5 -- seconds before the end marker of a burst, and its retries when refused
local ACK_WAIT = 5 -- seconds the sender waits for the acknowledgements of a burst
local SIZES = { 100, 200, 254, 255, 256, 300 } -- the size test (bytes of the whole message)
local CHUNK = 200 -- Base64 characters per encoded chunk
local CHUNKS_MAX = 30
local CHUNK_GAP = 1 -- seconds between two chunks: the documented refill rate, so that the throttle never drops one
local CHUNK_RETRIES = 3 -- tries of a refused chunk, 2 seconds apart
local POLL_MAX = 3600 -- one-second polls of the lockdown flag while it is on (one hour)
local SIGNAL_WINDOW = 2500 -- ms around the end of a lockdown in which an ADDON_RESTRICTION_STATE_CHANGED counts
local IDLE_GRACE = 30 -- seconds after ENCOUNTER_END or PLAYER_REGEN_ENABLED in which a lockdown is still the fight's
local AUTO_GAP = 30 -- seconds between two automatic lockdown test sets
local FLUSH_DELAY = 5 -- seconds between an event and the record it updates
local LOG_CAP = 120 -- event lines a check logs in one session (identical lines once)
local RUNS_MAX = 50 -- runs of other clients remembered by the receiver
local SMALL, LARGE = 40, 400 -- ledger entries of the invented profiles (about 2 KB and 20 KB of CBOR)

local DISTS = {
    guild = "GUILD", party = "PARTY", raid = "RAID", instance = "INSTANCE_CHAT", whisper = "WHISPER",
    channel = "CHANNEL",
}
local DIST_WORDS = "guild|party|raid|instance|whisper <name>|channel"
local ECHOED = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true, CHANNEL = true }

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

local function verdict(problems, missing, summary)
    if #problems > 0 then
        return "fail", "revise: " .. table.concat(problems, ", ") .. " | " .. summary
    end
    if #missing > 0 then
        return "todo", "missing: " .. table.concat(missing, ", ") .. " | " .. summary
    end
    return "pass", summary
end

local function ms1(v)
    return string.format("%.1f", v or 0)
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

-- Identity of this session, faction, enumerations ---------------------------------------------------------------------

--- A random four-digit hex token of this session: own messages are recognised by it, never by the sender's name.
local function newToken()
    local seed = math.floor(Probe.Ms()) + (Probe.Time() % 100000) * 7919
    local ok, r = pcall(math.random, 0, 65535)
    if ok and type(r) == "number" then
        seed = seed + r
    end
    return string.format("%04x", seed % 65536)
end
local token = newToken()

local factionCache
--- The probe character's faction as one letter (A, H, N, U = unknown): carried in every message, so that the receiver
--- tells same-faction from cross-faction delivery without any name.
local function faction()
    if not factionCache then
        local s, f = Read(UnitFactionGroup, "player")
        if s == "string" then
            factionCache = (f == "Alliance" and "A") or (f == "Horde" and "H") or (f == "Neutral" and "N") or "U"
        end
    end
    return factionCache or "U"
end

local enumMaps, enumTexts = {}, {}
--- Enum.<name> read at run time (the dump does not define SendAddonMessageResult, RegisterAddonMessagePrefixResult,
--- AddOnRestrictionType, AddOnRestrictionState): a map value -> key, and the text "key=value,..." for the log.
local function enumMap(name)
    if enumMaps[name] then
        return enumMaps[name], enumTexts[name]
    end
    local map, parts = {}, {}
    local ok = pcall(function()
        for k, v in pairs(Enum[name]) do
            if not IsSecret(k) and not IsSecret(v) then
                map[v] = tostring(k)
                parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
            end
        end
    end)
    table.sort(parts)
    enumMaps[name] = map
    enumTexts[name] = ok and (#parts > 0 and table.concat(parts, ",") or "empty") or "absent"
    return map, enumTexts[name]
end

--- One value of Enum.<name>.<key>, or `fallback` (the value in the API dump) when the enumeration is missing.
local function enumValue(name, key, fallback)
    local ok, v = pcall(function()
        return Enum[name][key]
    end)
    if ok and not IsSecret(v) and type(v) == "number" then
        return v, "enum"
    end
    return fallback, "dump"
end

--- The result of a send as a name: the Enum.SendAddonMessageResult key, the number when unknown, true / false for
--- clients that return a boolean, or absent / error / secret / nil.
local function codeText(ok, v)
    if not ok then
        return v == "absent" and "absent" or "error"
    end
    if IsSecret(v) then
        return "secret"
    end
    if v == nil then
        return "nil"
    end
    if type(v) == "boolean" then
        return v and "true" or "false"
    end
    if type(v) == "number" then
        return enumMap("SendAddonMessageResult")[v] or tostring(v)
    end
    return type(v)
end

--- ok (accepted), lockdown, throttle or refused.
local function classify(code)
    if code == "Success" or code == "true" or code == "0" then
        return "ok"
    end
    if code:find("Lockdown") or code == "11" then
        return "lockdown"
    end
    if code:lower():find("throttl") then
        return "throttle"
    end
    return "refused"
end

-- Prefix registration and the account ---------------------------------------------------------------------------------

local registerCode
local function ensureRegistered()
    if registerCode then
        return registerCode
    end
    local ok, r = call(C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    if not ok then
        registerCode = r == "absent" and "absent" or "error"
    elseif IsSecret(r) then
        registerCode = "secret"
    elseif type(r) == "number" then
        registerCode = enumMap("RegisterAddonMessagePrefixResult")[r] or tostring(r)
    else
        registerCode = tostring(r)
    end
    local st = Probe:Stats(V4)
    st.register = registerCode
    local _, regText = enumMap("RegisterAddonMessagePrefixResult")
    local _, sendText = enumMap("SendAddonMessageResult")
    local s, list = Read(C_ChatInfo and C_ChatInfo.GetRegisteredAddonMessagePrefixes)
    local n = "-"
    if s == "table" then
        local okN, count = pcall(function()
            local c = 0
            for _ in pairs(list) do
                c = c + 1
            end
            return c
        end)
        n = okN and tostring(count) or "?"
    end
    logOnce(V4, "register", string.format("RegisterAddonMessagePrefix of the test prefix -> %s; "
        .. "IsAddonMessagePrefixRegistered %s; registered prefixes %s (count only) | "
        .. "Enum.RegisterAddonMessagePrefixResult %s | Enum.SendAddonMessageResult %s",
        registerCode, BoolText(C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered, PREFIX), n, regText, sendText))
    return registerCode
end

local trialFlag
--- The trial and restricted-account flags and the realm switch on outgoing addon messages.
local function accountText()
    local trial = BoolText(IsTrialAccount)
    local veteran = BoolText(IsVeteranTrialAccount)
    local restricted = BoolText(IsRestrictedAccount)
    trialFlag = trial == "true" or veteran == "true" or restricted == "true"
    local s = Read(GetRestrictedAccountData)
    return string.format("IsTrialAccount %s IsVeteranTrialAccount %s IsRestrictedAccount %s "
        .. "GetRestrictedAccountData %s "
        .. "AreOutgoingAddonChatMessagesRestricted %s", trial, veteran, restricted, s,
        BoolText(C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted))
end

-- Sending -------------------------------------------------------------------------------------------------------------

local sessionSent = 0
local runCounter = 0

local function newRun()
    runCounter = runCounter + 1
    return runCounter
end

--- "<kind>|<token>|<run>|<seq>|<arg>|<faction>|<rest>", padded with "x" to `size` bytes.
local function payload(kind, run, seq, arg, size, rest)
    local text = string.format("%s|%s|%d|%d|%s|%s|%s", kind, token, run, seq, tostring(arg or ""), faction(),
        rest or "")
    if size and size > #text then
        text = text .. string.rep("x", size - #text)
    end
    return text
end

local function parse(text)
    return text:match("^(%u%u)|(%x%x%x%x)|(%d+)|(%d+)|([^|]*)|(%u)|(.*)$")
end

local function capLeft()
    return SESSION_CAP - sessionSent
end

--- Sends one message with the test prefix and counts its result code. `test` marks the messages of a command (they
--- count towards the session cap and cover the context of V4); replies are not tests. `target` is the WHISPER name or
--- the channel number, used for this call only.
local function send(dist, text, target, test)
    ensureRegistered()
    local ok, r = call(C_ChatInfo and C_ChatInfo.SendAddonMessage, PREFIX, text, dist, target)
    local code = codeText(ok, r)
    local kind = classify(code)
    local st = Probe:Stats(V4)
    Tally(sub(st, "codes"), dist .. " " .. code)
    local c = ctxStats(V4)
    Tally(sub(c, "sends"), dist .. ":" .. kind)
    if trialFlag then
        Tally(sub(st, "trialCodes"), code)
    end
    if test then
        sessionSent = sessionSent + 1
        Probe:Cover(V4)
    end
    return code, kind
end

--- The number of the test channel on this client, or nil when not joined.
local function channelId()
    local ok, id = call(GetChannelName, TEST_CHANNEL)
    if ok and not IsSecret(id) and type(id) == "number" and id > 0 then
        return id
    end
    return nil
end

--- The distribution of a command word ("guild", "whisper <name>", ...): dist, target, the rest of the text; or nil and
--- the reason.
local function resolve(word, rest)
    local dist = DISTS[(word or ""):lower()]
    if not dist then
        return nil, "distribution: " .. DIST_WORDS
    end
    if dist == "WHISPER" then
        local name, after = (rest or ""):match("^(%S+)%s*(.-)$")
        if not name then
            return nil, "whisper needs a character name (used once, never stored)"
        end
        return dist, name, after
    elseif dist == "CHANNEL" then
        local id = channelId()
        if not id then
            return nil, "not in the test channel: /azpp channel join"
        end
        return dist, tostring(id), rest
    end
    return dist, nil, rest
end

local replyTimes = {}
--- Automatic replies share one budget: at most REPLY_MAX in REPLY_WINDOW seconds.
local function replyAllowed()
    local now = Probe.Ms()
    while #replyTimes > 0 and now - replyTimes[1] > REPLY_WINDOW * 1000 do
        table.remove(replyTimes, 1)
    end
    if #replyTimes >= REPLY_MAX then
        return false
    end
    replyTimes[#replyTimes + 1] = now
    return true
end

local function pongOn()
    local sw = Probe.DB().switches
    return not (sw and sw.pong == false)
end

-- Lockdown (V5) -------------------------------------------------------------------------------------------------------

local function sortedValues(map)
    local values = {}
    for v in pairs(map) do
        values[#values + 1] = v
    end
    table.sort(values, function(a, b)
        if type(a) == "number" and type(b) == "number" then
            return a < b
        end
        return tostring(a) < tostring(b)
    end)
    return values
end

--- Every Enum.AddOnRestrictionType with IsAddOnRestrictionActive and GetAddOnRestrictionState: "Name=active/state".
local function restrictionText()
    local R = C_RestrictedActions
    local types = enumMap("AddOnRestrictionType")
    local states = enumMap("AddOnRestrictionState")
    local parts = {}
    for _, v in ipairs(sortedValues(types)) do
        local active = BoolText(R and R.IsAddOnRestrictionActive, v)
        local s, state = Read(R and R.GetAddOnRestrictionState, v)
        local stateText = s == "number" and (states[state] or tostring(state)) or s
        parts[#parts + 1] = types[v] .. "=" .. active .. "/" .. stateText
    end
    return #parts > 0 and table.concat(parts, " ") or "restriction types unknown"
end

local lockState, lockSince, lockTag -- last flag seen ("true" / "false"), since when (ms), in which context
local lastTrigger -- { event, ms }: the last ENCOUNTER_END or PLAYER_REGEN_ENABLED
local lastRestrictionEvent = -1e12
local polls = 0
local polling = false
local snapshot -- forward declaration (the poll calls it)
local autoSends -- forward declaration (the end of a lockdown calls it)

local function poll()
    polling = false
    if lockState ~= "true" or polls >= POLL_MAX then
        return
    end
    polls = polls + 1
    snapshot("poll")
end

local function ensurePolling()
    if not polling and lockState == "true" and polls < POLL_MAX then
        polling = Probe.After(1, poll)
    end
end

--- The end of a lockdown, decided 2 seconds later: was it signalled by ADDON_RESTRICTION_STATE_CHANGED?
local function decideEnd(endMs, duration, since, tag, trigger)
    local signalled = math.abs(lastRestrictionEvent - endMs) <= SIGNAL_WINDOW
    local st = Probe:Stats(V5)
    Tally(sub(st, "ends"), signalled and "event" or "noEvent")
    local delay = "-"
    if trigger and trigger.ms >= since then
        delay = trigger.event .. " +" .. string.format("%.0f", endMs - trigger.ms) .. " ms"
    end
    Probe:Log(V5, string.format("lockdown off after %.1f s (on since %s); after %s; ADDON_RESTRICTION_STATE_CHANGED "
        .. "within %.1f s: %s", duration / 1000, tag or "?", delay, SIGNAL_WINDOW / 1000, signalled and "yes" or "no"))
    touch(V5)
end

local function noteLock(lock, trigger)
    local now = Probe.Ms()
    if lock == "true" and lockState ~= "true" then
        lockSince, lockTag, polls = now, Probe.Context(), 0
        Probe:Log(V5, "lockdown on at " .. trigger)
    elseif lock == "false" and lockState == "true" then
        local duration, since, tag, trig = now - (lockSince or now), lockSince or now, lockTag, lastTrigger
        if not Probe.After(2, function()
            decideEnd(now, duration, since, tag, trig)
        end) then
            decideEnd(now, duration, since, tag, trig)
        end
        autoSends("lockdown end", 1)
    end
    if lock == "true" or lock == "false" then
        lockState = lock
    end
    ensurePolling()
end

--- One lockdown snapshot in the current context: the flags, the restriction states, counters per context.
snapshot = function(trigger)
    local c, _, tag = ctxStats(V5)
    local lock = BoolText(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)
    local combat = BoolText(InCombatLockdown)
    local encounter = BoolText(C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress)
    local restr = restrictionText()
    c.snaps = (c.snaps or 0) + 1
    Tally(sub(c, "lock"), lock)
    -- out of combat and out of an encounter, and not just after one: the lockdown would last the whole stay
    local settled = not lastTrigger or Probe.Ms() - lastTrigger.ms > IDLE_GRACE * 1000
    if lock == "true" and combat == "false" and encounter == "false" and settled then
        c.idleLocked = (c.idleLocked or 0) + 1
    end
    local line = string.format("%s | InChatMessagingLockdown %s | InCombatLockdown %s UnitAffectingCombat %s "
        .. "IsEncounterInProgress %s IsBattleground %s HasSecretRestrictions %s "
        .. "AreOutgoingAddonChatMessagesRestricted %s | %s", trigger, lock, combat,
        BoolText(UnitAffectingCombat, "player"), encounter, BoolText(C_PvP and C_PvP.IsBattleground), BoolText(C_Secrets and C_Secrets.HasSecretRestrictions),
        BoolText(C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted), restr)
    logOnce(V5, tag .. "|" .. trigger .. "|" .. lock .. "|" .. combat .. "|" .. encounter .. "|" .. restr, line)
    Probe:Cover(V5, tag)
    noteLock(lock, trigger)
    touch(V5)
    return lock, tag
end

local function inGroup(category)
    local s, v = Read(IsInGroup, category)
    return s == "boolean" and v
end

--- One test send per distribution available here, compared with the lockdown flag read just before.
local function lockdownSends(trigger)
    local lock, tag = snapshot(trigger)
    if capLeft() < 6 then
        Probe.Print("session cap of test messages reached: /reload to reset")
        return
    end
    local list = {}
    local _, guild = Read(IsInGuild)
    if guild == true then
        list[#list + 1] = { "GUILD" }
    end
    local _, raid = Read(IsInRaid)
    if raid == true then
        list[#list + 1] = { "RAID" }
    elseif inGroup(LE_PARTY_CATEGORY_HOME or 1) then
        list[#list + 1] = { "PARTY" }
    end
    if inGroup(LE_PARTY_CATEGORY_INSTANCE or 2) then
        list[#list + 1] = { "INSTANCE_CHAT" }
    end
    local id = channelId()
    if id then
        list[#list + 1] = { "CHANNEL", tostring(id) }
    end
    local s, me = Read(UnitName, "player")
    if s == "string" then
        list[#list + 1] = { "WHISPER", me } -- to the probe character itself: the name is only passed to this call
    end
    local run = newRun()
    local c, st = ctxStats(V5, tag)
    local parts = {}
    for i, item in ipairs(list) do
        local code, kind = send(item[1], payload("LK", run, i, tag, nil, lock), item[2], true)
        Tally(sub(c, "sends"), item[1] .. ":" .. kind)
        if (lock == "true" and kind == "ok") or (lock == "false" and kind == "lockdown") then
            st.disagree = (st.disagree or 0) + 1
        end
        parts[#parts + 1] = item[1] .. " " .. code
    end
    me = nil
    local line = string.format("%s test sends with lockdown %s: %s", trigger, lock,
        #parts > 0 and table.concat(parts, ", ") or "no distribution available")
    Probe:Log(V5, line)
    touch(V5)
    return line
end

local lastAuto = -1e12
local function autoOn()
    local sw = Probe.DB().switches
    return sw and sw.lockdownAuto == true
end

--- With /azpp lockdown auto on, a test set `delay` seconds after a fight, a pull or the end of a lockdown.
autoSends = function(trigger, delay)
    if not autoOn() then
        return
    end
    Probe.After(delay, function()
        local now = Probe.Ms()
        if now - lastAuto < AUTO_GAP * 1000 then
            return
        end
        lastAuto = now
        lockdownSends("auto " .. trigger)
    end)
end

-- The hidden channel (V4) ---------------------------------------------------------------------------------------------

local function inCombat()
    local s, v = Read(InCombatLockdown)
    return s ~= "boolean" or v
end

local function windowCount()
    return type(NUM_CHAT_WINDOWS) == "number" and NUM_CHAT_WINDOWS or 10
end

local function isOurs(name)
    return not IsSecret(name) and type(name) == "string" and name:lower() == TEST_CHANNEL:lower()
end

--- Whether chat window i lists the test channel (GetChatWindowChannels returns name1, zone1, name2, zone2, ...).
local function windowHas(i)
    local function scan(ok, ...)
        if not ok then
            return nil
        end
        for k = 1, select("#", ...), 2 do
            if isOurs((select(k, ...))) then
                return true
            end
        end
        return false
    end
    return scan(call(GetChatWindowChannels, i))
end

local function framesListing()
    local n = 0
    for i = 1, windowCount() do
        if windowHas(i) then
            n = n + 1
        end
    end
    return n
end

--- Removes the test channel from every chat frame that lists it (ChatFrame_RemoveChannel, else
--- RemoveChatWindowChannel).
local function removeFromFrames()
    local removed, failed = 0, 0
    for i = 1, windowCount() do
        if windowHas(i) then
            local frame = _G["ChatFrame" .. i]
            local ok = frame and call(ChatFrame_RemoveChannel, frame, TEST_CHANNEL)
            if not ok then
                ok = call(RemoveChatWindowChannel, i, TEST_CHANNEL)
            end
            if ok then
                removed = removed + 1
            else
                failed = failed + 1
            end
        end
    end
    return removed, failed
end

--- The display index of the test channel in the channel list and its member count.
local function displayEntry()
    local s, n = Read(GetNumDisplayChannels)
    if s ~= "number" then
        return nil, "GetNumDisplayChannels " .. s
    end
    for i = 1, math.min(n, 60) do
        local ok, name, _, _, _, count = call(GetChannelDisplayInfo, i)
        if ok and isOurs(name) then
            return i, count
        end
    end
    return nil, "not in the channel list"
end

local function memberCount(why)
    local st = Probe:Stats(V4)
    local idx, count = displayEntry()
    if not idx then
        logOnce(V4, "count|" .. tostring(count), "member count (" .. why .. "): " .. tostring(count))
        return nil
    end
    if IsSecret(count) then
        st.countSecret = (st.countSecret or 0) + 1
        logOnce(V4, "count|secret", "member count (" .. why .. "): secret")
        return nil
    end
    if type(count) == "number" then
        st.members = count
        st.membersMax = math.max(st.membersMax or 0, count)
    end
    logOnce(V4, "count|" .. why .. "|" .. tostring(count), string.format("member count (%s): GetChannelDisplayInfo "
        .. "count %s (display index %d)", why, type(count) == "number" and tostring(count) or type(count), idx))
    touch(V4)
    return idx
end

--- Counts the roster entries of the test channel (GetChannelRosterInfo): readable and secret names, both discarded.
local function countRoster(idx)
    local n, secret = 0, 0
    for r = 1, 1000 do
        local ok, name = call(C_ChatInfo and C_ChatInfo.GetChannelRosterInfo, idx, r)
        if not ok then
            break
        end
        if IsSecret(name) then
            secret = secret + 1
        elseif name == nil then
            break
        else
            n = n + 1
        end
    end
    local st = Probe:Stats(V4)
    st.roster = n
    if secret > 0 then
        st.countSecret = (st.countSecret or 0) + 1
    end
    Probe:Log(V4, string.format("roster of the test channel: %d readable entries, %d secret (names discarded)", n,
        secret))
    touch(V4)
end

local function verifyRemoval(why)
    local st = Probe:Stats(V4)
    local left = framesListing()
    st.framesLeft = left
    Probe:Log(V4, string.format("chat frames listing the test channel %s: %d", why, left))
    touch(V4)
end

--- After a join: is the channel there, then remove it from the chat frames and read the member count.
local function afterJoin(why)
    local st = Probe:Stats(V4)
    local id = channelId()
    if not id then
        st.joinFailed = (st.joinFailed or 0) + 1
        Probe:Log(V4, "test channel not joined " .. why)
        touch(V4)
        return
    end
    st.joined = true
    local before = framesListing()
    local removed, failed = removeFromFrames()
    local s, info = Read(C_ChatInfo and C_ChatInfo.GetChannelInfoFromIdentifier, TEST_CHANNEL)
    local infoText = s == "table" and (Probe.TableShape(info)) or s
    local _, active = Read(C_ChatInfo and C_ChatInfo.GetNumActiveChannels)
    Probe:Log(V4, string.format("test channel joined (%s): number %d, active channels %s, info %s; chat frames listing "
        .. "it %d, removed from %d, failed %d", why, id, tostring(active or "?"), infoText, before, removed, failed))
    if not Probe.After(2, function()
        verifyRemoval("2 s after the removal")
        memberCount("after join")
    end) then
        verifyRemoval("after the removal")
    end
end

local function joinChannel()
    if inCombat() then
        Probe.Print("join and leave only out of combat")
        return
    end
    local st = Probe:Stats(V4)
    local fn, label = JoinTemporaryChannel, "JoinTemporaryChannel"
    if type(fn) ~= "function" then
        fn, label = JoinChannelByName, "JoinChannelByName"
    end
    local ok, a, b = call(fn, TEST_CHANNEL)
    st.joinApi = label
    Probe:Log(V4, string.format("%s(test channel): %s, returns %s %s", label, ok and "called" or Probe.ErrorText(a),
        ok and Probe.Shape(a) or "-", ok and Probe.Shape(b) or "-"))
    Probe.Print(label .. " called; the probe removes the channel from the chat frames in 3 seconds")
    if not Probe.After(3, function()
        afterJoin("3 s after the join")
    end) then
        afterJoin("after the join")
    end
end

local function leaveChannel()
    if inCombat() then
        Probe.Print("join and leave only out of combat")
        return
    end
    local ok, err = call(LeaveChannelByName, TEST_CHANNEL)
    Probe:Log(V4, "LeaveChannelByName(test channel): " .. (ok and "called" or Probe.ErrorText(err)))
    Probe.After(2, function()
        local left = channelId() == nil
        Probe:Stats(V4).left = left
        Probe:Log(V4, "test channel left 2 s after the command: " .. tostring(left))
        Probe.Print("test channel left: " .. tostring(left))
        touch(V4)
    end)
end

-- Chat filter: hides the notices of the test channel ("Joined Channel", "Left Channel") and counts them, once per line
-- (every chat frame calls the filter).
local seenNotices, seenNoticeCount = {}, 0

local function noticeFilter(_, _, text, _, _, channelName, _, _, _, _, baseName, _, lineID)
    local ours = isOurs(baseName)
    if not ours and not IsSecret(channelName) and type(channelName) == "string" then
        ours = channelName:lower():find(TEST_CHANNEL:lower(), 1, true) ~= nil
    end
    if not ours then
        return false
    end
    local line = (not IsSecret(lineID) and type(lineID) == "number") and lineID or nil
    if not line or not seenNotices[line] then
        if line and seenNoticeCount < 200 then
            seenNotices[line] = true
            seenNoticeCount = seenNoticeCount + 1
        end
        local kind = (not IsSecret(text) and type(text) == "string" and text:match("^[%u_]+$")) and text or "other"
        Tally(sub(Probe:Stats(V4), "noticesHidden"), kind)
    end
    return true
end

local function installNoticeFilter()
    local add
    local okU, utilAdd = pcall(function()
        return ChatFrameUtil.AddMessageEventFilter
    end)
    if okU and type(utilAdd) == "function" then
        add = utilAdd
    elseif type(ChatFrame_AddMessageEventFilter) == "function" then
        add = ChatFrame_AddMessageEventFilter
    end
    local done = 0
    if add then
        for _, event in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER" }) do
            if pcall(add, event, noticeFilter) then
                done = done + 1
            end
        end
    end
    Probe:Stats(V4).noticeFilter = done
end

-- Bursts and sizes (V4) -----------------------------------------------------------------------------------------------

local burst -- the burst running now, or nil
local myBursts = {} -- run -> the burst (this session)
local pings = {} -- run -> { ms, dist }

local function summary(b)
    local st = Probe:Stats(V4)
    local ack = b.acks > 0 and string.format("%d ack(s): received %s intact %s longest %s", b.acks, b.ackN, b.ackIntact,
        b.ackMax) or "no ack"
    local line = string.format("%s %s n=%d gap=%.2fs bytes=%s: sent %d, accepted %d, codes {%s}, first refusal %s; own "
        .. "echoes %s; %s; end marker %s%s", b.sizes and "size test" or "burst", b.dist, b.n, b.gap,
        b.sizes and "100-300" or tostring(b.size), b.i, b.ok, TallyText(b.codes),
        b.firstRefusal and string.format("#%d after %.0f ms (%s)", b.firstRefusal, b.firstMs, b.firstCode) or "none",
        ECHOED[b.dist] and tostring(b.echo) or "n/a", ack, tostring(b.endCode),
        b.why and (", stopped: " .. b.why) or "")
    if b.sizes then
        line = line .. " | sizes " .. table.concat(b.sizeCodes, " ")
        if b.code255 == "refused" then -- a lockdown or a throttle is not a size limit
            st.refused255 = (st.refused255 or 0) + 1
        end
    end
    Probe:Log(V4, line)
    Probe.Print(line)
    st.bursts = (st.bursts or 0) + 1
    b.target = nil
    if burst == b then
        burst = nil
    end
    touch(V4)
end

local function sendEnd(b, tries)
    local code, kind = send(b.dist, payload("BE", b.run, b.i, b.ok), b.target, false)
    if kind ~= "ok" and tries < END_RETRIES and Probe.After(END_DELAY, function()
        sendEnd(b, tries + 1)
    end) then
        return
    end
    b.endCode = code .. (tries > 1 and (" after " .. tries .. " tries") or "")
    if not Probe.After(ACK_WAIT, function()
        summary(b)
    end) then
        summary(b)
    end
end

local function finishBurst(b)
    if b.ending then
        return
    end
    b.ending = true
    if not Probe.After(END_DELAY, function()
        sendEnd(b, 1)
    end) then
        sendEnd(b, 1)
    end
end

--- Sends the next message of a burst; false when the burst is over (done, stopped or capped).
local function sendOne(b)
    if b.stop or b.i >= b.n then
        return false
    end
    if capLeft() <= 0 then
        b.why = "session cap"
        return false
    end
    b.i = b.i + 1
    local size = b.sizes and b.sizes[b.i] or b.size
    local code, kind = send(b.dist, payload("BU", b.run, b.i, size, size), b.target, true)
    Tally(b.codes, code)
    if b.sizes then
        b.sizeCodes[#b.sizeCodes + 1] = size .. ":" .. code
        if size == MAX_BYTES then
            b.code255 = kind
        end
    end
    if kind == "ok" then
        b.ok = b.ok + 1
        b.refusedRow = 0
    else
        b.refusedRow = b.refusedRow + 1
        if not b.firstRefusal then
            b.firstRefusal, b.firstMs, b.firstCode = b.i, Probe.Ms() - b.t0, code
        end
        if b.refusedRow >= REFUSALS_STOP then
            b.stop, b.why = true, REFUSALS_STOP .. " refusals in a row"
        end
    end
    return true
end

local function step()
    local b = burst
    while b and not b.ending and sendOne(b) do
        if b.gap > 0 and Probe.After(b.gap, step) then
            return
        end
    end
    if b and not b.ending then
        finishBurst(b)
    end
end

local function startBurst(dist, target, n, gap, size, sizes)
    if burst then
        Probe.Print("a burst is already running: /azpp burst stop")
        return
    end
    if capLeft() <= 0 then
        Probe.Print("session cap of " .. SESSION_CAP .. " test messages reached: /reload to reset")
        return
    end
    local b = {
        dist = dist, target = target, n = n, gap = gap, size = size, sizes = sizes, sizeCodes = {}, run = newRun(),
        i = 0, ok = 0, codes = {}, refusedRow = 0, echo = 0, acks = 0, ackN = "-", ackIntact = "-", ackMax = "-",
        t0 = Probe.Ms(),
    }
    burst = b
    myBursts[b.run] = b
    Probe.Print(string.format("%s on %s: %d messages, gap %.2f s; /azpp burst stop ends it", sizes and "size test"
        or "burst", dist, n, gap))
    step()
end

-- Receiving (V4, V5, V14) ---------------------------------------------------------------------------------------------

local recvRuns, recvRunCount = {}, 0
local encParts = {} -- token:run -> { n, got, parts }
local verifyEncoded -- forward declaration (V14)

local function reply(dist, kind, run, arg, rest, sender)
    if not replyAllowed() then
        Tally(sub(Probe:Stats(V4), "repliesSkipped"), kind)
        return "skipped"
    end
    local target
    if dist == "WHISPER" then
        if IsSecret(sender) or type(sender) ~= "string" then
            return "no target"
        end
        target = sender -- passed to this call only, never kept
    elseif dist == "CHANNEL" then
        local id = channelId()
        if not id then
            return "not in the channel"
        end
        target = tostring(id)
    end
    return (send(dist, payload(kind, run, 0, arg, nil, rest), target, false))
end

local function onAddonMessage(event, prefix, text, dist, sender)
    if IsSecret(prefix) then
        Tally(sub(Probe:Stats(V4), "secretPrefix"), Probe.Context())
        return
    end
    if prefix ~= PREFIX then
        return
    end
    local st = Probe:Stats(V4)
    if IsSecret(text) or IsSecret(dist) then
        Tally(sub(st, "recvSecret"), Probe.Context())
        return
    end
    if type(text) ~= "string" or type(dist) ~= "string" then
        return
    end
    local kind, tok, run, seq, arg, fac, rest = parse(text)
    if not kind then
        Tally(sub(st, "recv"), "unparsed")
        return
    end
    run, seq = tonumber(run), tonumber(seq)
    local mine = tok == token
    local relation = mine and "self" or (fac == faction() and "same" or "cross")
    local c, _, tag = ctxStats(V4)
    Tally(sub(c, "recv"), dist .. ":" .. relation .. (event == "CHAT_MSG_ADDON_LOGGED" and ":logged" or ""))
    local lock = BoolText(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)
    Tally(sub(ctxStats(V5, tag), "recvLock"), lock)
    if not mine then
        if relation == "same" then
            Probe:Cover(V4, "2C")
        elseif relation == "cross" and dist == "CHANNEL" then
            Probe:Cover(V4, "2CX")
        end
        logOnce(V4, "recv|" .. tag .. "|" .. dist .. "|" .. relation .. "|" .. kind, string.format("received %s on %s "
            .. "from another client (%s faction), lockdown here %s", kind, dist, relation, lock))
    end
    if mine then
        local b = myBursts[run]
        if kind == "BU" and b then
            b.echo = b.echo + 1
        end
    elseif kind == "PI" then
        if pongOn() then
            reply(dist, "PO", run, tok, nil, sender)
        end
    elseif kind == "PO" and arg == token then
        local p = pings[run]
        local rtt = p and (Probe.Ms() - p.ms) or nil
        local r = sub(sub(st, "rtt"), dist)
        if rtt then
            r.n, r.sum, r.max = (r.n or 0) + 1, (r.sum or 0) + rtt, math.max(r.max or 0, rtt)
        end
        local line = string.format("pong on %s from another client (%s faction) after %s ms", dist, relation,
            rtt and string.format("%.0f", rtt) or "?")
        Probe:Log(V4, line)
        Probe.Print(line)
        touch(V4)
    elseif kind == "BU" then
        local key = tok .. ":" .. run
        local r = recvRuns[key]
        if not r then
            if recvRunCount >= RUNS_MAX then
                return
            end
            recvRunCount = recvRunCount + 1
            r = { n = 0, intact = 0, maxLen = 0 }
            recvRuns[key] = r
        end
        r.n = r.n + 1
        local declared = tonumber(arg)
        if declared and declared == #text then
            r.intact = r.intact + 1
            r.maxLen = math.max(r.maxLen, #text)
            if #text >= MAX_BYTES then
                st.intact255 = true
            end
        elseif declared then
            st.truncated = (st.truncated or 0) + 1
        end
    elseif kind == "BE" then
        local r = recvRuns[tok .. ":" .. run] or { n = 0, intact = 0, maxLen = 0 }
        local line = string.format("burst of another client on %s (%s faction): received %d of %s accepted, intact %d, "
            .. "longest %d bytes", dist, relation, r.n, arg, r.intact, r.maxLen)
        Probe:Log(V4, line)
        reply(dist, "BA", run, tok, r.n .. "," .. r.intact .. "," .. r.maxLen, sender)
        touch(V4)
    elseif kind == "BA" and arg == token then
        local b = myBursts[run]
        local n, intact, maxLen = rest:match("^(%d+),(%d+),(%d+)")
        n, intact, maxLen = tonumber(n), tonumber(intact), tonumber(maxLen)
        if b and n then
            b.acks = b.acks + 1
            b.ackN, b.ackIntact, b.ackMax = n, intact, maxLen
            st.acked = true
            if n < b.ok then
                st.silentLoss = (st.silentLoss or 0) + (b.ok - n)
            end
            if maxLen >= MAX_BYTES then
                st.intact255 = true
            end
            if intact < n then
                st.truncated = (st.truncated or 0) + (n - intact)
            end
        end
    elseif kind == "LK" then
        Probe:Cover(V5, "2C")
        Probe:Log(V5, string.format("lockdown test of another client received on %s: sent from %s with lockdown %s; "
            .. "lockdown here %s", dist, arg, rest, lock))
        touch(V5)
    elseif kind == "EN" then
        local key = tok .. ":" .. run
        local e = encParts[key]
        local n = tonumber(arg)
        if not e then
            if not n or n > CHUNKS_MAX then
                return
            end
            e = { n = n, got = 0, parts = {} }
            encParts[key] = e
        end
        if seq and seq >= 1 and seq <= e.n and not e.parts[seq] then
            e.parts[seq] = rest
            e.got = e.got + 1
        end
        if e.got == e.n and not e.done then
            e.done = true
            local result = verifyEncoded(table.concat(e.parts), dist, relation)
            reply(dist, "EA", run, tok, result, sender)
        end
    elseif kind == "EA" and arg == token then
        local s14 = Probe:Stats(V14)
        Tally(sub(s14, "acks2C"), rest)
        if rest == "ok" then
            Probe:Cover(V14, "2C")
        end
        Probe:Log(V14, "encoded profile acknowledged by another client on " .. dist .. ": " .. rest)
        Probe.Print("encoded profile acknowledged: " .. rest)
        touch(V14)
    end
end

-- V14: C_EncodingUtil -------------------------------------------------------------------------------------------------

local NON_ASCII = "\195\160\195\168\195\172\195\178\195\185 \195\159 \206\169" -- a e i o u with grave, sharp s, omega
local KINDS = { "DLV", "ADV", "PTH", "ART", "VAN", "MER", "LEG", "HC" }

--- An invented profile (no real data): nested tables, integers, floats, strings with "|" and non-ASCII letters.
local function buildProfile(entries)
    local p = {
        v = 7, schema = 3, ruleset = "PvP", gp = 123456, ratio = 0.125, third = 1 / 3, negative = -42, big = 2 ^ 40,
        zero = 0, flag = true, off = false, empty = "", pipe = "a|b||c", text = "Prestige " .. NON_ASCII,
        peaks = {}, ledger = {}, sparse = { [1] = "one", [3] = "three", [10] = "ten" },
        nested = { a = { b = { c = { d = "deep" } } } },
    }
    for i = 1, 9 do
        p.peaks[i] = i * 111
    end
    for i = 1, entries do
        p.ledger[i] = {
            t = 1764300000 + i * 37, k = KINDS[(i % #KINDS) + 1], id = 1000 + i, d = i % 4, w = (i % 7) / 8,
            note = (i % 5 == 0) and ("x|" .. NON_ASCII) or "ok",
        }
    end
    return p
end

--- Differences between two values (types, values, missing keys), and the path of the first one.
local function diff(a, b, path, depth, first)
    if IsSecret(a) or IsSecret(b) then
        first[1] = first[1] or path
        return 1
    end
    if type(a) ~= type(b) then
        first[1] = first[1] or path
        return 1
    end
    if type(a) ~= "table" then
        if a ~= b then
            first[1] = first[1] or path
            return 1
        end
        return 0
    end
    if depth > 8 then
        return 0
    end
    local n = 0
    for k, v in pairs(a) do
        n = n + diff(v, b[k], path .. "." .. tostring(k), depth + 1, first)
    end
    for k in pairs(b) do
        if IsSecret(k) or a[k] == nil then
            first[1] = first[1] or (path .. ".+")
            n = n + 1
        end
    end
    return n
end

--- A C_EncodingUtil call with its time: shape, value (never secret), milliseconds.
local function timed(fn, ...)
    local t0 = Probe.Ms()
    local ok, v = call(fn, ...)
    local ms = Probe.Ms() - t0
    if not ok then
        return v == "absent" and "absent" or "error", nil, ms
    end
    if IsSecret(v) then
        return "secret", nil, ms
    end
    if v == nil then
        return "nil", nil, ms
    end
    return type(v), v, ms
end

local function hasNul(s)
    return s:find("\0", 1, true) ~= nil
end

--- One round trip of the profile with `entries` ledger entries: lines for the log, problems, the size summary.
local function roundTrip(label, entries, problems)
    local E = C_EncodingUtil
    local lines = {}
    local profile = buildProfile(entries)
    local function problem(text)
        problems[#problems + 1] = label .. " " .. text
    end
    -- CBOR, the planned codec
    local s, cbor, ms = timed(E and E.SerializeCBOR, profile)
    if s ~= "string" then
        problem("SerializeCBOR " .. s)
        return lines, label .. " no CBOR"
    end
    local s2, cbor2 = timed(E.SerializeCBOR, profile)
    local same = s2 == "string" and cbor2 == cbor
    local ds, back, dms = timed(E.DeserializeCBOR, cbor)
    local first = {}
    local d = ds == "table" and diff(profile, back, "p", 0, first) or -1
    if not same then
        problem("CBOR differs twice")
    end
    if d ~= 0 then
        problem("CBOR " .. (d < 0 and ("DeserializeCBOR " .. ds) or (d .. " diffs")))
    end
    lines[#lines + 1] = string.format("%s CBOR %d B in %s ms, back in %s ms: %s, same bytes twice %s, NUL %s", label,
        #cbor, ms1(ms), ms1(dms), d == 0 and "exact" or (d < 0 and ds or (d .. " diffs, first " .. first[1])),
        tostring(same), tostring(hasNul(cbor)))
    -- JSON: only reported (not the planned codec; floats, sparse tables and big numbers may not survive it)
    local js, json, jms = timed(E.SerializeJSON, profile)
    local jopt = ""
    if js ~= "string" then
        js, json, jms = timed(E.SerializeJSON, profile, { ignoreSerializationErrors = true })
        jopt = " (with ignoreSerializationErrors)"
    end
    if js == "string" then
        local jds, jback, jdms = timed(E.DeserializeJSON, json)
        local jfirst = {}
        local jd = jds == "table" and diff(profile, jback, "p", 0, jfirst) or -1
        lines[#lines + 1] = string.format("%s JSON%s %d B in %s ms, back in %s ms: %s", label, jopt, #json, ms1(jms),
            ms1(jdms), jd == 0 and "exact" or (jd < 0 and jds or (jd .. " diffs, first " .. jfirst[1])))
    else
        if js == "absent" then
            problem("SerializeJSON absent")
        end
        lines[#lines + 1] = label .. " JSON: SerializeJSON " .. js
    end
    -- compression: every method and level
    local parts, deflate = {}, nil
    for _, m in ipairs({ { "Deflate", 0 }, { "Zlib", 1 }, { "Gzip", 2 } }) do
        local method, src = enumValue("CompressionMethod", m[1], m[2])
        for _, l in ipairs({ { "Default", 0 }, { "OptimizeForSpeed", 1 }, { "OptimizeForSize", 2 } }) do
            local level = enumValue("CompressionLevel", l[1], l[2])
            local cs, comp, cms = timed(E.CompressString, cbor, method, level)
            if cs ~= "string" then
                problem("CompressString " .. m[1] .. " " .. cs)
                parts[#parts + 1] = m[1] .. "/" .. l[1] .. " " .. cs
            else
                local cs2, comp2 = timed(E.CompressString, cbor, method, level)
                local us, raw, ums = timed(E.DecompressString, comp, method)
                local exact = us == "string" and raw == cbor
                if not exact then
                    problem(m[1] .. " lossy")
                end
                if not (cs2 == "string" and comp2 == comp) then
                    problem(m[1] .. " differs twice")
                end
                parts[#parts + 1] = string.format("%s/%s %d B %s+%s ms%s", m[1], l[1], #comp, ms1(cms), ms1(ums),
                    exact and "" or " LOSSY")
                if m[1] == "Deflate" and l[1] == "Default" then
                    deflate = comp
                end
            end
            if src == "dump" and l[1] == "Default" then
                parts[#parts] = parts[#parts] .. " (enum absent)"
            end
        end
    end
    lines[#lines + 1] = label .. " compress (bytes, compress+decompress ms): " .. table.concat(parts, ", ")
    -- Base64 and hex of the Deflate output
    local b64Size = "-"
    if deflate then
        local bparts = {}
        for _, var in ipairs({ { "Standard", 0 }, { "StandardUrlSafe", 1 } }) do
            local variant = enumValue("Base64Variant", var[1], var[2])
            local bs, b64, bms = timed(E.EncodeBase64, deflate, variant)
            if bs ~= "string" then
                problem("EncodeBase64 " .. var[1] .. " " .. bs)
                bparts[#bparts + 1] = var[1] .. " " .. bs
            else
                local dbs, raw = timed(E.DecodeBase64, b64, variant)
                local exact = dbs == "string" and raw == deflate
                local clean = b64:find("[^%w%+/=_%-]") == nil
                if not exact then
                    problem("Base64 " .. var[1] .. " lossy")
                end
                if not clean or hasNul(b64) then
                    problem("Base64 " .. var[1] .. " unexpected characters")
                end
                bparts[#bparts + 1] = string.format("%s %d B %s ms%s%s", var[1], #b64, ms1(bms),
                    exact and "" or " LOSSY", clean and "" or " DIRTY")
                if var[1] == "Standard" then
                    b64Size = tostring(#b64)
                end
            end
        end
        local hs, hex = timed(E.EncodeHex, deflate)
        local hexText = "EncodeHex " .. hs
        if hs == "string" then
            local hds, raw = timed(E.DecodeHex, hex)
            local exact = hds == "string" and raw == deflate
            if not exact then
                problem("hex lossy")
            end
            hexText = string.format("hex %d B %s", #hex, exact and "exact" or "LOSSY")
        else
            problem("EncodeHex " .. hs)
        end
        lines[#lines + 1] = label .. " Base64 of Deflate: " .. table.concat(bparts, ", ") .. "; " .. hexText
    end
    return lines, string.format("%s cbor %d defl %s b64 %s", label, #cbor, deflate and tostring(#deflate) or "-",
        b64Size)
end

--- The encoded profile sent by /azpp encsend: CBOR, Deflate, Base64 (Standard). Nil and the reason when it fails.
local function encodeSmall()
    local E = C_EncodingUtil
    local s, cbor = timed(E and E.SerializeCBOR, buildProfile(SMALL))
    if s ~= "string" then
        return nil, "SerializeCBOR " .. s
    end
    local cs, comp = timed(E.CompressString, cbor, enumValue("CompressionMethod", "Deflate", 0))
    if cs ~= "string" then
        return nil, "CompressString " .. cs
    end
    local bs, b64 = timed(E.EncodeBase64, comp, enumValue("Base64Variant", "Standard", 0))
    if bs ~= "string" then
        return nil, "EncodeBase64 " .. bs
    end
    return b64
end

--- The receiving side of /azpp encsend: decode the chunks and compare with the same invented profile built here.
verifyEncoded = function(b64, dist, relation)
    local E = C_EncodingUtil
    local result
    local bs, comp = timed(E and E.DecodeBase64, b64, enumValue("Base64Variant", "Standard", 0))
    if bs ~= "string" then
        result = "bad:DecodeBase64 " .. bs
    else
        local us, cbor = timed(E.DecompressString, comp, enumValue("CompressionMethod", "Deflate", 0))
        if us ~= "string" then
            result = "bad:DecompressString " .. us
        else
            local ds, back = timed(E.DeserializeCBOR, cbor)
            local first = {}
            local d = ds == "table" and diff(buildProfile(SMALL), back, "p", 0, first) or -1
            result = d == 0 and "ok" or (d < 0 and ("bad:DeserializeCBOR " .. ds) or ("bad:" .. d .. " diffs"))
        end
    end
    local st = Probe:Stats(V14)
    Tally(sub(st, "recv2C"), result)
    if result == "ok" then
        Probe:Cover(V14, "2C")
    end
    Probe:Log(V14, string.format("encoded profile of another client (%s faction) on %s: %d Base64 bytes, %s", relation,
        dist, #b64, result))
    touch(V14)
    return result
end

local function encSend(dist, target)
    local b64, why = encodeSmall()
    if not b64 then
        Probe.Print("encoding failed: " .. why)
        return
    end
    local n = math.ceil(#b64 / CHUNK)
    if n > CHUNKS_MAX or capLeft() < n then
        Probe.Print("too many chunks or session cap reached")
        return
    end
    local run = newRun()
    local codes = {}
    local function chunk(i, try)
        local code, kind = send(dist, payload("EN", run, i, n, nil, b64:sub((i - 1) * CHUNK + 1, i * CHUNK)), target,
            true)
        Tally(codes, code)
        if kind ~= "ok" and try < CHUNK_RETRIES and capLeft() > 0 and Probe.After(2, function()
            chunk(i, try + 1)
        end) then
            return
        end
        if i < n then
            if not Probe.After(CHUNK_GAP, function()
                chunk(i + 1, 1)
            end) then
                chunk(i + 1, 1)
            end
        else
            target = nil
            local line = string.format("encoded profile sent on %s: %d Base64 bytes in %d chunks, codes {%s}", dist,
                #b64, n, TallyText(codes))
            Probe:Log(V14, line)
            Probe.Print(line .. "; the other client answers with an acknowledgement")
        end
    end
    Probe.Print(string.format("sending the encoded profile on %s: %d chunks, one per second", dist, n))
    chunk(1, 1)
end

-- Results -------------------------------------------------------------------------------------------------------------

local function ctxTallies(st, field, tags)
    local parts = {}
    for _, tag in ipairs(tags) do
        local c = st.ctx and st.ctx[tag]
        if c and c[field] then
            parts[#parts + 1] = tag .. " " .. TallyText(c[field])
        end
    end
    return #parts > 0 and table.concat(parts, "; ") or "-"
end

local ALL_TAGS = { "W", "WC", "D", "DB", "R", "RB", "BG" }

local function evaluateV4()
    local st = Probe:Stats(V4)
    local problems, missing = {}, {}
    local reg = st.register
    if reg and classify(reg) ~= "ok" and not reg:find("Duplicate") and not reg:find("Already") then
        problems[#problems + 1] = "prefix not registered (" .. reg .. ")"
    end
    if st.joinFailed and not st.joined then
        problems[#problems + 1] = "channel not joined"
    end
    if (st.framesLeft or 0) > 0 then
        problems[#problems + 1] = "channel still in " .. st.framesLeft .. " chat frame(s)"
    end
    if (st.silentLoss or 0) > 0 then
        problems[#problems + 1] = st.silentLoss .. " accepted messages lost"
    end
    if (st.truncated or 0) > 0 then
        problems[#problems + 1] = st.truncated .. " messages truncated"
    end
    if (st.refused255 or 0) > 0 then
        problems[#problems + 1] = "255 bytes refused outside lockdown"
    end
    if (st.countSecret or 0) > 0 then
        problems[#problems + 1] = "member count secret"
    end
    for _, tag in ipairs(Probe:Missing(V4)) do
        missing[#missing + 1] = tag
    end
    if not st.joined then
        missing[#missing + 1] = "channel join"
    elseif st.framesLeft == nil then
        missing[#missing + 1] = "removal check"
    end
    if not st.intact255 then
        missing[#missing + 1] = "255 B received"
    end
    if not st.acked then
        missing[#missing + 1] = "burst ack"
    end
    if not st.members and not st.roster then
        missing[#missing + 1] = "member count"
    end
    local rtt = {}
    for dist, r in pairs(st.rtt or {}) do
        rtt[dist] = string.format("%.0f", (r.sum or 0) / math.max(1, r.n or 1))
    end
    -- sends per distribution and kind of result, all contexts together (the logs keep them per context)
    local perDist = {}
    for key, n in pairs(st.codes or {}) do
        local dist, code = key:match("^(%S+) (.+)$")
        if dist then
            local kind = classify(code)
            Tally(perDist, dist .. ":" .. (kind == "throttle" and "thr" or kind == "lockdown" and "lck" or kind), n)
        end
    end
    local summaryText = string.format("rtt ms %s | bursts %d | members %s | trial %s | sends %s", TallyText(rtt),
        st.bursts or 0, tostring(st.members or st.roster or "-"), tostring(trialFlag), TallyText(perDist))
    return verdict(problems, missing, summaryText)
end
EVALUATE[V4] = evaluateV4

local function evaluateV5()
    local st = Probe:Stats(V5)
    local problems = {}
    for _, tag in ipairs({ "W", "WC" }) do
        local c = st.ctx and st.ctx[tag]
        if c and c.lock and (c.lock["true"] or 0) > 0 then
            problems[#problems + 1] = "lockdown in " .. tag
        end
    end
    for _, tag in ipairs({ "D", "R" }) do
        local c = st.ctx and st.ctx[tag]
        if c and (c.idleLocked or 0) > 0 then
            problems[#problems + 1] = "lockdown out of combat in " .. tag
        end
    end
    if st.ends and (st.ends.noEvent or 0) > 0 then
        problems[#problems + 1] = st.ends.noEvent .. " lockdown end(s) without an event"
    end
    if (st.disagree or 0) > 0 then
        problems[#problems + 1] = st.disagree .. " flag/code disagreements"
    end
    local summaryText = string.format("lock %s | ends %s", ctxTallies(st, "lock", ALL_TAGS), TallyText(st.ends))
    return verdict(problems, Probe:Missing(V5), summaryText)
end
EVALUATE[V5] = evaluateV5

local function evaluateV14()
    local st = Probe:Stats(V14)
    local problems = {}
    for p in pairs(st.problems or {}) do
        problems[#problems + 1] = p
    end
    for _, field in ipairs({ "recv2C", "acks2C" }) do
        for result in pairs(st[field] or {}) do
            if result ~= "ok" then
                problems[#problems + 1] = "encoded profile " .. result
            end
        end
    end
    table.sort(problems)
    while #problems > 4 do
        table.remove(problems)
    end
    local summaryText = string.format("%s; %s | 2C recv %s ack %s", st.small or "-", st.large or "-",
        TallyText(st.recv2C), TallyText(st.acks2C))
    return verdict(problems, Probe:Missing(V14), summaryText)
end
EVALUATE[V14] = evaluateV14

Probe:Implement(V4, function(probe)
    ensureRegistered()
    local id = channelId()
    probe:Log(V4, string.format("run | %s | test channel %s, chat frames listing it %d, notice filter on %s event(s), "
        .. "hidden notices %s | session messages %d of %d, token of this session %s, faction %s", accountText(),
        id and ("joined, number " .. id) or "not joined", framesListing(), tostring(Probe:Stats(V4).noticeFilter or 0),
        TallyText(Probe:Stats(V4).noticesHidden), sessionSent, SESSION_CAP, token, faction()))
    if id then
        memberCount("run")
    end
    return evaluateV4()
end)

Probe:Implement(V5, function()
    lockdownSends("run")
    return evaluateV5()
end)

Probe:Implement(V14, function(probe)
    local st = Probe:Stats(V14)
    st.problems = st.problems or {}
    local problems = {}
    local E = C_EncodingUtil
    local names = { "SerializeCBOR", "DeserializeCBOR", "SerializeJSON", "DeserializeJSON", "CompressString",
        "DecompressString", "EncodeBase64", "DecodeBase64", "EncodeHex", "DecodeHex" }
    local absent = {}
    for _, name in ipairs(names) do
        local ok, fn = pcall(function()
            return E[name]
        end)
        if not ok or type(fn) ~= "function" then
            absent[#absent + 1] = name
            problems[#problems + 1] = name .. " absent"
        end
    end
    local _, methods = enumMap("CompressionMethod")
    local _, levels = enumMap("CompressionLevel")
    local _, variants = enumMap("Base64Variant")
    probe:Log(V14, string.format("run | C_EncodingUtil %s, absent: %s | Enum.CompressionMethod %s | "
        .. "Enum.CompressionLevel %s | Enum.Base64Variant %s", Probe.Shape(E), #absent > 0 and table.concat(absent, ",")
        or "none", methods, levels, variants))
    if type(E) == "table" then
        local small, sizeSmall = roundTrip("2K", SMALL, problems)
        local large, sizeLarge = roundTrip("20K", LARGE, problems)
        for _, line in ipairs(small) do
            probe:Log(V14, line)
        end
        for _, line in ipairs(large) do
            probe:Log(V14, line)
        end
        st.small, st.large = sizeSmall, sizeLarge
    end
    for _, p in ipairs(problems) do
        st.problems[p] = true
    end
    local c = ctxStats(V14)
    c.runs = (c.runs or 0) + 1
    c.problems = (c.problems or 0) + #problems
    probe:Cover(V14)
    return evaluateV14()
end)

-- Events --------------------------------------------------------------------------------------------------------------

Probe:Watch({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON", "CHAT_MSG_ADDON_LOGGED",
    "ADDON_RESTRICTION_STATE_CHANGED", "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "CHAT_MSG_CHANNEL_NOTICE",
    "CHANNEL_COUNT_UPDATE", "CHANNEL_ROSTER_UPDATE" }, function(event, ...)
    if event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
        onAddonMessage(event, ...)
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        local rtype, rstate = ...
        lastRestrictionEvent = Probe.Ms()
        local typeText = IsSecret(rtype) and "secret" or (enumMap("AddOnRestrictionType")[rtype] or tostring(rtype))
        local stateText = IsSecret(rstate) and "secret"
            or (enumMap("AddOnRestrictionState")[rstate] or tostring(rstate))
        Tally(sub(Probe:Stats(V5), "restrictionEvents"), typeText .. "=" .. stateText)
        logOnce(V5, "event|" .. Probe.Context() .. "|" .. typeText .. "|" .. stateText, string.format(
            "ADDON_RESTRICTION_STATE_CHANGED type %s state %s (payload); InChatMessagingLockdown during dispatch %s",
            typeText, stateText, BoolText(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)))
        Probe.After(0, function()
            snapshot("after ADDON_RESTRICTION_STATE_CHANGED")
        end)
    elseif event == "ENCOUNTER_END" or event == "PLAYER_REGEN_ENABLED" then
        lastTrigger = { event = event, ms = Probe.Ms() }
        snapshot(event)
    elseif event == "ENCOUNTER_START" or event == "PLAYER_REGEN_DISABLED" then
        snapshot(event)
        Probe.After(2, function()
            snapshot(event .. " +2s")
        end)
        autoSends(event, event == "ENCOUNTER_START" and 5 or 3)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local initial, reloading = ...
        local crossed = not IsSecret(initial) and not IsSecret(reloading) and initial == false and reloading == false
        snapshot(crossed and "after a loading screen" or "entering world")
        if crossed then
            Probe:Cover(V5, "LS")
        end
        Probe.After(3, function()
            local id = channelId()
            if id then
                local listed = framesListing()
                logOnce(V4, "pew|" .. tostring(crossed) .. "|" .. listed, string.format("test channel still joined "
                    .. "%s; chat frames listing it %d", crossed and "after a loading screen" or "after login or reload",
                    listed))
                if listed > 0 then
                    Probe:Stats(V4).readded = (Probe:Stats(V4).readded or 0) + 1
                    removeFromFrames()
                end
            end
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "GROUP_ROSTER_UPDATE" then
        snapshot(event)
    elseif event == "CHAT_MSG_CHANNEL_NOTICE" then
        local text, _, _, _, _, _, _, _, baseName = ...
        if isOurs(baseName) then
            local kind = (not IsSecret(text) and type(text) == "string" and text:match("^[%u_]+$")) and text or "other"
            logOnce(V4, "notice|" .. kind, "CHAT_MSG_CHANNEL_NOTICE of the test channel: " .. kind)
            if kind == "YOU_JOINED" or kind == "YOU_CHANGED" then
                Probe.After(1, function()
                    removeFromFrames()
                end)
            end
        end
    elseif event == "CHANNEL_COUNT_UPDATE" or event == "CHANNEL_ROSTER_UPDATE" then
        local index, count = ...
        local idx = displayEntry()
        if idx and not IsSecret(index) and index == idx then
            local st = Probe:Stats(V4)
            if IsSecret(count) then
                st.countSecret = (st.countSecret or 0) + 1
            elseif type(count) == "number" then
                st.members = count
                st.membersMax = math.max(st.membersMax or 0, count)
                logOnce(V4, event .. "|" .. count, event .. " of the test channel: count " .. count)
            end
            if event == "CHANNEL_ROSTER_UPDATE" then
                countRoster(idx)
            end
            touch(V4)
        end
    elseif event == "PLAYER_LOGIN" then
        ensureRegistered()
        installNoticeFilter()
        logOnce(V4, "account", "account | " .. accountText())
        local _, types = enumMap("AddOnRestrictionType")
        local _, states = enumMap("AddOnRestrictionState")
        logOnce(V5, "enums", "Enum.AddOnRestrictionType " .. types .. " | Enum.AddOnRestrictionState " .. states)
    end
end)

-- Commands ------------------------------------------------------------------------------------------------------------

Probe:AddCommand("ping", "/azpp ping " .. DIST_WORDS .. " - one ping; a client with the probe answers with a pong "
    .. "(round trip in ms)", function(rest)
    local word, after = rest:match("^(%S*)%s*(.-)$")
    local dist, target = resolve(word, after)
    if not dist then
        Probe.Print("usage: /azpp ping " .. DIST_WORDS .. " (" .. tostring(target) .. ")")
        return
    end
    if capLeft() <= 0 then
        Probe.Print("session cap of " .. SESSION_CAP .. " test messages reached: /reload to reset")
        return
    end
    local run = newRun()
    pings[run] = { ms = Probe.Ms(), dist = dist }
    local code = send(dist, payload("PI", run, 1, ""), target, true)
    target = nil
    local line = string.format("ping on %s: %s", dist, code)
    Probe:Log(V4, line)
    Probe.Print(line)
    touch(V4)
end)

Probe:AddCommand("pong", "/azpp pong [on|off] - automatic pong replies to the pings of other clients (on by default)",
    function(rest)
        local word = rest:lower()
        if word == "on" or word == "off" then
            local d = Probe.DB()
            d.switches = d.switches or {}
            d.switches.pong = word == "on"
        end
        Probe.Print("automatic pong replies: " .. (pongOn() and "on" or "off"))
    end)

Probe:AddCommand("burst", "/azpp burst " .. DIST_WORDS .. " [n] [gap] [bytes] | stop - n messages (default 10, at "
    .. "most " .. BURST_MAX .. ") every gap seconds (default 0, at most " .. GAP_MAX .. ") of bytes (default 200, "
    .. "at most " .. MAX_BYTES .. ")", function(rest)
    local word, after = rest:match("^(%S*)%s*(.-)$")
    if word:lower() == "stop" then
        if burst and not burst.stop then
            burst.stop, burst.why = true, "by command"
            Probe.Print("burst stopping")
        else
            Probe.Print("no burst running")
        end
        return
    end
    local dist, target, tail = resolve(word, after)
    local n, gap, size
    if dist then
        n, gap, size = (tail or ""):match("^(%d*)%s*([%d%.]*)%s*(%d*)%s*$")
    end
    if not dist or not n then
        Probe.Print("usage: /azpp burst " .. DIST_WORDS .. " [n] [gap] [bytes] | stop" .. (dist and "" or
            (" (" .. tostring(target) .. ")")))
        return
    end
    n = math.max(1, math.min(tonumber(n) or 10, BURST_MAX))
    gap = math.max(0, math.min(tonumber(gap) or 0, GAP_MAX))
    size = math.max(40, math.min(tonumber(size) or 200, MAX_BYTES))
    startBurst(dist, target, n, gap, size, nil)
end)

Probe:AddCommand("size", "/azpp size " .. DIST_WORDS .. " - messages of 100, 200, 254, 255, 256 and 300 bytes; the "
    .. "receiver reports which arrived intact", function(rest)
    local word, after = rest:match("^(%S*)%s*(.-)$")
    local dist, target = resolve(word, after)
    if not dist then
        Probe.Print("usage: /azpp size " .. DIST_WORDS .. " (" .. tostring(target) .. ")")
        return
    end
    startBurst(dist, target, #SIZES, 0.5, nil, SIZES)
end)

Probe:AddCommand("channel", "/azpp channel join|leave|status|count - the hidden test channel (join and leave out of "
    .. "combat)", function(rest)
    local word = rest:lower()
    if word == "join" then
        joinChannel()
    elseif word == "leave" then
        leaveChannel()
    elseif word == "status" or word == "" then
        local id = channelId()
        local line = string.format("test channel %s; chat frames listing it %d; active channels %s", id and
            ("joined, number " .. id) or "not joined", framesListing(), select(2, Read(C_ChatInfo and
            C_ChatInfo.GetNumActiveChannels)) or "?")
        Probe:Log(V4, line)
        Probe.Print(line)
        if id then
            memberCount("status")
        end
    elseif word == "count" then
        local idx = memberCount("count")
        if idx then
            call(SetSelectedDisplayChannel, idx) -- asks the server for the roster: CHANNEL_ROSTER_UPDATE follows
            Probe.After(3, function()
                countRoster(idx)
            end)
            Probe.Print("member count requested; the roster is counted in 3 seconds")
        end
    else
        Probe.Print("usage: /azpp channel join|leave|status|count")
    end
end)

Probe:AddCommand("lockdown", "/azpp lockdown [auto on|off] - a lockdown snapshot with one test send per distribution; "
    .. "auto: the same after each pull and fight start (off by default)", function(rest)
    local word, state = rest:lower():match("^(%S*)%s*(%S*)$")
    if word == "auto" then
        if state == "on" or state == "off" then
            local d = Probe.DB()
            d.switches = d.switches or {}
            d.switches.lockdownAuto = state == "on"
        end
        Probe.Print("automatic lockdown tests: " .. (autoOn() and "on" or "off"))
        return
    end
    local line = lockdownSends("command")
    if line then
        Probe.Print(line)
    end
end)

Probe:AddCommand("encsend", "/azpp encsend " .. DIST_WORDS .. " - sends the 2 KB invented profile (CBOR, Deflate, "
    .. "Base64) in chunks; the other client decodes and acknowledges it", function(rest)
    local word, after = rest:match("^(%S*)%s*(.-)$")
    local dist, target = resolve(word, after)
    if not dist then
        Probe.Print("usage: /azpp encsend " .. DIST_WORDS .. " (" .. tostring(target) .. ")")
        return
    end
    encSend(dist, target)
end)

Probe:AddCommand("msgs", "/azpp msgs - the message counters (codes, received, round trips, lockdown)", function()
    local st4, st5 = Probe:Stats(V4), Probe:Stats(V5)
    Probe.Print("result codes: " .. TallyText(st4.codes))
    Probe.Print("received: " .. ctxTallies(st4, "recv", ALL_TAGS))
    Probe.Print("lockdown: " .. ctxTallies(st5, "lock", ALL_TAGS) .. " | ends " .. TallyText(st5.ends))
    Probe.Print(string.format("session: %d of %d test messages, burst %s, pong %s, lockdown auto %s", sessionSent,
        SESSION_CAP, burst and "running" or "none", pongOn() and "on" or "off", autoOn() and "on" or "off"))
end)
