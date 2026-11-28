-- AzPr Probe: throwaway spike addon for Azeroth Prestige (milestone M0). Never distributed.
-- Adapted from Azeroth Accord (tools/probe/AzAc_Probe/AzAc_Probe.lua), same owner, GPL-3.0 (ADR 0013).
-- The specification of every check, the commands and the record format: docs/spike/README.md.
-- Lua 5.1. Every game API call goes through pcall (Probe.Call). Every returned value is tested with issecretvalue before
-- it is used. Never print or store player, guild, channel or realm names, nor GUIDs: counts, types and shapes only.

local ADDON_NAME = ...

-- The test addon-message prefix. The real prefix of the addon is never registered or sent by the probe.
local TEST_PREFIX = "AzPrP"

local SCHEMA = 1
local DETAILS_MAX = 240
local LOG_MAX = 200

local Probe = { checks = {}, order = {}, commands = {}, help = {}, TEST_PREFIX = TEST_PREFIX }
_G.AzPr_Probe = Probe

local CHAT_PREFIX = "|cff66ccffAzPr Probe:|r "
local RESULTS = { pass = true, fail = true, info = true, todo = true }

local function out(msg)
    print(CHAT_PREFIX .. tostring(msg))
end
Probe.Print = out

--- Safe call of a game API: returns ok, ...results (never raises). A function that does not exist is never called:
--- the result is false, "absent". Use this for every game API call.
function Probe.Call(fn, ...)
    if type(fn) ~= "function" then
        return false, "absent"
    end
    return pcall(fn, ...)
end
local call = Probe.Call

--- True when the value is secret (or when the client cannot tell): test it before any other use of the value.
function Probe.IsSecret(v)
    if type(issecretvalue) ~= "function" then
        return false
    end
    local ok, secret = pcall(issecretvalue, v)
    return not ok or secret == true
end

--- The shape of a value, as written in the logs: never its text.
function Probe.Shape(v)
    if Probe.IsSecret(v) then
        return "secret"
    end
    local t = type(v)
    if t == "table" then
        local ok, n = pcall(function()
            local count = 0
            for _ in pairs(v) do
                count = count + 1
            end
            return count
        end)
        return ok and ("table(" .. n .. " keys)") or "table(? keys)"
    end
    return t
end

--- One line, at most `max` characters.
local function oneLine(text, max)
    return (tostring(text or ""):gsub("[\r\n]+", " ")):sub(1, max)
end

--- The "error: ..." text of a failed pcall.
function Probe.ErrorText(err)
    if Probe.IsSecret(err) then
        return "error: secret"
    end
    return "error: " .. oneLine(err, 80)
end

local function db()
    if type(AzPr_ProbeDB) ~= "table" then
        AzPr_ProbeDB = {}
    end
    local d = AzPr_ProbeDB
    d.schema = SCHEMA
    d.results = d.results or {}
    d.logs = d.logs or {}
    d.covered = d.covered or {}
    d.stats = d.stats or {}
    return d
end
Probe.DB = db

--- GetBuildInfo() as "<version> <build> <interface>".
local function buildString()
    local ok, version, build, _, interface = call(GetBuildInfo)
    if not ok then
        return "unknown"
    end
    local parts = {}
    for _, v in ipairs({ version, build, interface }) do
        parts[#parts + 1] = Probe.IsSecret(v) and "secret" or tostring(v)
    end
    return table.concat(parts, " ")
end
Probe.BuildString = buildString

local function now()
    local ok, t = call(time)
    return ok and t or 0
end
Probe.Time = now

--- A boolean API read safely: true or false, nil when absent, failed or secret.
local function flag(fn, ...)
    local ok, v = call(fn, ...)
    if not ok or Probe.IsSecret(v) then
        return nil
    end
    return v and true or false
end

--- The context tag the probe can detect by itself: W, WC, D, DB, R, RB, BG, an other instance type, or "?".
function Probe.Context()
    local ok, inInstance, instanceType = call(IsInInstance)
    if not ok or Probe.IsSecret(inInstance) or Probe.IsSecret(instanceType) then
        return "?"
    end
    if flag(C_PvP and C_PvP.IsBattleground) or instanceType == "pvp" then
        return "BG"
    end
    if not inInstance then
        local combat = flag(InCombatLockdown)
        if combat == nil then
            return "?"
        end
        return combat and "WC" or "W"
    end
    local boss = flag(C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress)
    if instanceType == "party" then
        return boss and "DB" or "D"
    elseif instanceType == "raid" then
        return boss and "RB" or "R"
    end
    return tostring(instanceType)
end

--- Registers a check. `contexts` lists the tags it needs (docs/spike/README.md, "Where to run"), `step` the roadmap
--- step that implements it. Without `fn` the check is a stub that records "todo".
function Probe:Register(id, description, contexts, step, fn)
    assert(type(id) == "string" and type(contexts) == "table", "Register(id, description, contexts, step, fn)")
    if not self.checks[id] then
        self.order[#self.order + 1] = id
    end
    self.checks[id] = { id = id, description = description, contexts = contexts, step = step, fn = fn }
end

--- Gives a registered check its code. fn(probe) returns result ("pass"|"fail"|"info"|"todo") and details (no names).
function Probe:Implement(id, fn)
    assert(self.checks[id] and type(fn) == "function", "Implement(registered id, fn)")
    self.checks[id].fn = fn
end

--- Marks a required context of a check as run: `tag`, or the context detected now. 2C, 2CX, HC and LS cannot be
--- detected by Probe.Context(): the check passes them explicitly.
function Probe:Cover(id, tag)
    local covered = db().covered
    covered[id] = covered[id] or {}
    covered[id][tag or Probe.Context()] = true
end

--- The required contexts of a check that have not been covered yet, in the order of the registry.
function Probe:Missing(id)
    local check, covered = self.checks[id], db().covered[id] or {}
    local missing = {}
    for _, tag in ipairs(check and check.contexts or {}) do
        if not covered[tag] then
            missing[#missing + 1] = tag
        end
    end
    return missing
end

--- Stores a result in AzPr_ProbeDB.results[id].
function Probe:Record(id, result, details)
    if not RESULTS[result] then
        result = "info"
    end
    local entry = {
        id = id,
        result = result,
        details = oneLine(details, DETAILS_MAX),
        build = buildString(),
        time = now(),
    }
    db().results[id] = entry
    return entry
end

--- Appends "<context> | <line>" to AzPr_ProbeDB.logs[id] (capped at LOG_MAX lines, oldest dropped first).
function Probe:Log(id, line)
    local logs = db().logs
    local l = logs[id] or {}
    logs[id] = l
    l[#l + 1] = Probe.Context() .. " | " .. oneLine(line, 500)
    while #l > LOG_MAX do
        table.remove(l, 1)
    end
end

--- The aggregated counters of a check, kept in AzPr_ProbeDB.stats[id] so that they survive /reload. Always ask for the
--- table again (never keep it): /azpp reset replaces it.
function Probe:Stats(id)
    local stats = db().stats
    stats[id] = stats[id] or {}
    return stats[id]
end

-- Helpers for the checks (since M0.3) ----------------------------------------------------------------------------------

--- The first value returned by a game API, read safely: its shape ("absent", "error", "secret", "nil" or the Lua type)
--- and the value itself only when it is readable. A secret value is never returned.
function Probe.Read(fn, ...)
    if type(fn) ~= "function" then
        return "absent", nil
    end
    local ok, v = pcall(fn, ...)
    if not ok then
        return "error", nil
    end
    if Probe.IsSecret(v) then
        return "secret", nil
    end
    if v == nil then
        return "nil", nil
    end
    return type(v), v
end

--- A readable boolean as "true" / "false", anything else as its shape ("secret", "nil", "absent", ...).
function Probe.BoolText(fn, ...)
    local shape, v = Probe.Read(fn, ...)
    if shape == "boolean" then
        return tostring(v)
    end
    return shape
end

--- Adds n (default 1) to t[key].
function Probe.Tally(t, key, n)
    key = tostring(key)
    t[key] = (t[key] or 0) + (n or 1)
end

--- A tally table as "a=1,b=2" (sorted keys), "-" when empty.
function Probe.TallyText(t)
    local keys = {}
    for k in pairs(t or {}) do
        keys[#keys + 1] = tostring(k)
    end
    table.sort(keys)
    for i, k in ipairs(keys) do
        keys[i] = k .. "=" .. tostring(t[k])
    end
    return #keys > 0 and table.concat(keys, ",") or "-"
end

--- The kind of a unit token with its digits replaced ("party3" -> "partyN", "nameplate7target" -> "nameplateNtarget"):
--- a token, never a name. Anything that does not look like a token is "other".
function Probe.TokenKind(unit)
    if Probe.IsSecret(unit) then
        return "secret"
    end
    if unit == nil then
        return "nil"
    end
    if type(unit) ~= "string" then
        return type(unit)
    end
    if unit:match("^[a-z]+%d*[a-z]*$") then
        return (unit:gsub("%d+", "N"))
    end
    return "other"
end

--- A key that may be written in a log: it looks like a field name or a unit token (it starts with a lowercase ASCII
--- letter). Player names always start with a capital letter, so they never pass.
local function fieldName(k)
    return type(k) == "string" and #k <= 32 and k:match("^[a-z][%w_]*$") ~= nil
end

--- A table described without its values: number of keys, the field names (only those that pass fieldName, the others
--- counted by type), the shapes of the values and, for nested tables, the same one level down. Returns the text and
--- the number of secret keys and values found (both levels).
function Probe.TableShape(t)
    local secrets = 0
    local function describe(tbl, nested)
        local n, names, keyKinds, values, inner = 0, {}, {}, {}, nil
        for k, v in pairs(tbl) do
            n = n + 1
            if Probe.IsSecret(k) then
                secrets = secrets + 1
                Probe.Tally(keyKinds, "secret")
            elseif fieldName(k) then
                names[#names + 1] = k
            else
                Probe.Tally(keyKinds, type(k))
            end
            if Probe.IsSecret(v) then
                secrets = secrets + 1
                Probe.Tally(values, "secret")
            else
                Probe.Tally(values, type(v))
                if type(v) == "table" and not nested then
                    local text = describe(v, true)
                    inner = inner or text -- the first nested table is written, the others only counted
                end
            end
        end
        table.sort(names)
        while #names > 12 do
            table.remove(names)
        end
        local text = string.format("table(%d keys; fields %s; other keys %s; values %s", n,
            #names > 0 and table.concat(names, ",") or "-", Probe.TallyText(keyKinds), Probe.TallyText(values))
        if inner then
            text = text .. "; first nested " .. inner
        end
        return text .. ")"
    end
    local ok, text = pcall(describe, t, false)
    if not ok then
        return "table(" .. Probe.ErrorText(text) .. ")", secrets
    end
    return text, secrets
end

--- A clock in milliseconds for delays and costs inside one session (debugprofilestop, else GetTime).
function Probe.Ms()
    local shape, ms = Probe.Read(debugprofilestop)
    if shape == "number" then
        return ms
    end
    local shapeT, s = Probe.Read(GetTime)
    return shapeT == "number" and s * 1000 or 0
end

--- Runs fn after `seconds` (C_Timer.After); an error inside fn is logged under logs.errors. False when there is no timer.
function Probe.After(seconds, fn)
    if not (C_Timer and type(C_Timer.After) == "function") then
        return false
    end
    return (pcall(C_Timer.After, seconds, function()
        local ok, err = pcall(fn)
        if not ok then
            Probe:Log("errors", "timer " .. Probe.ErrorText(err))
        end
    end))
end

--- A frame that calls handler(event, ...) for `events` (and for `unitEvents` = { EVENT = "unit" }, registered with
--- RegisterUnitEvent when the client has it). The handler runs in pcall; its errors go to logs.errors.
function Probe:Watch(events, handler, unitEvents)
    local ok, f = call(CreateFrame, "Frame")
    if not ok or not f then
        return nil
    end
    for _, event in ipairs(events) do
        pcall(f.RegisterEvent, f, event)
    end
    for event, unit in pairs(unitEvents or {}) do
        local done = type(f.RegisterUnitEvent) == "function" and pcall(f.RegisterUnitEvent, f, event, unit)
        if not done then
            pcall(f.RegisterEvent, f, event)
        end
    end
    pcall(f.SetScript, f, "OnEvent", function(_, event, ...)
        local okH, err = pcall(handler, event, ...)
        if not okH then
            Probe:Log("errors", tostring(event) .. " " .. Probe.ErrorText(err))
        end
    end)
    return f
end

--- The unit tokens of the other group members (never "player"), the group kind ("solo", "party", "raid") and its size.
function Probe.GroupUnits()
    local _, inRaid = Probe.Read(IsInRaid)
    local _, inGroup = Probe.Read(IsInGroup)
    local _, size = Probe.Read(GetNumGroupMembers)
    size = type(size) == "number" and size or 0
    local units, kind = {}, "solo"
    if inRaid == true then
        kind = "raid"
        for i = 1, math.min(size, 40) do
            local unit = "raid" .. i
            local _, isMe = Probe.Read(UnitIsUnit, unit, "player")
            if isMe ~= true then
                units[#units + 1] = unit
            end
        end
    elseif inGroup == true or size > 1 then
        kind = "party"
        for i = 1, math.min(math.max(size - 1, 0), 4) do
            units[#units + 1] = "party" .. i
        end
    end
    return units, kind, size
end

-- Helpers for the tracker sources (since M0.6) -------------------------------------------------------------------------

--- A value already in hand as it may be written in a log: numbers and booleans as values, everything else as its
--- shape ("string", "secret", "nil", "table(3 keys)"). The text of a string is never written.
function Probe.Value(v)
    if Probe.IsSecret(v) then
        return "secret"
    end
    local t = type(v)
    if t == "number" or t == "boolean" then
        return tostring(v)
    end
    if t == "table" then
        return Probe.Shape(v)
    end
    return t
end

--- The first return of a game API as it may be written in a log: Probe.Value of it, or why there is none ("absent",
--- "error", "secret", "nil").
function Probe.ReadValue(fn, ...)
    local shape, v = Probe.Read(fn, ...)
    if v == nil then
        return shape
    end
    return Probe.Value(v)
end

--- A string that is a fixed identifier of the game ("seller", "elite", "party", "ERR_ZONE_EXPLORED"), else nil. Only
--- for values that can never be a name typed by a person: the caller says which return it is.
function Probe.Token(v)
    if Probe.IsSecret(v) or type(v) ~= "string" or #v > 48 then
        return nil
    end
    return (v:match("^[a-z][a-z_%-]*$") or v:match("^[A-Z][A-Z0-9_]+$")) and v or nil
end

--- Every return of a game API: ok, a list of the returns and their count (nils kept). The values are not tested for
--- secrets here: pass them to Probe.Value, or test each one with Probe.IsSecret before any other use.
function Probe.Returns(fn, ...)
    local function pack(ok, ...)
        return ok, { ... }, select("#", ...)
    end
    return pack(Probe.Call(fn, ...))
end

--- The returns of a game API as "name=<value>" pairs; "absent" or "error" when the call fails. `names` lists the
--- documented returns in order; further ones are written by position.
function Probe.ReturnsText(names, fn, ...)
    local ok, res, n = Probe.Returns(fn, ...)
    if not ok then
        return res[1] == "absent" and "absent" or "error"
    end
    local parts = {}
    for i = 1, math.max(n, #names) do
        parts[#parts + 1] = (names[i] or ("r" .. i)) .. "=" .. Probe.Value(res[i])
    end
    return #parts > 0 and table.concat(parts, " ") or "no return"
end

--- The fields of a returned table as "field=<value>" for the listed fields; the shape when it is not a table.
function Probe.Fields(t, names)
    if Probe.IsSecret(t) or type(t) ~= "table" then
        return Probe.Value(t)
    end
    local parts = {}
    for _, name in ipairs(names) do
        local ok, v = pcall(function()
            return t[name]
        end)
        parts[#parts + 1] = name .. "=" .. (ok and Probe.Value(v) or "error")
    end
    return table.concat(parts, " ")
end

--- The key of an enumeration value ("Complete" for Enum.PvPMatchState and 5), else the number or shape. Enum is a
--- Blizzard Lua table: it is read at run time and may be missing.
function Probe.EnumKey(enumName, value)
    if Probe.IsSecret(value) then
        return "secret"
    end
    local ok, key = pcall(function()
        for k, v in pairs(Enum[enumName]) do
            if v == value then
                return k
            end
        end
    end)
    if ok and type(key) == "string" then
        return key
    end
    return Probe.Value(value)
end

--- A format global string ("%1$s has defeated %2$s in a duel", "Discovered %s: %d experience gained") as an anchored
--- Lua pattern, and the argument index of each capture. Nil when the text is not a usable format.
function Probe.FormatPattern(format)
    if Probe.IsSecret(format) or type(format) ~= "string" or format == "" then
        return nil
    end
    local parts, order, nextIndex, pos = { "^" }, {}, 0, 1
    local function literal(text)
        parts[#parts + 1] = (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
    end
    while true do
        local first, last, index, kind = format:find("%%(%d*)%$?([sd])", pos)
        if not first then
            break
        end
        literal(format:sub(pos, first - 1))
        nextIndex = nextIndex + 1
        order[#order + 1] = tonumber(index) or nextIndex
        parts[#parts + 1] = kind == "d" and "(%d+)" or "(.-)"
        pos = last + 1
    end
    literal(format:sub(pos))
    parts[#parts + 1] = "$"
    return table.concat(parts), order
end

--- Matches a message against the global string `globalName`. Returns the captures by argument index (empty when the
--- string has none), or nil. The second return says why it cannot match: "secret", "absent" (the global is missing).
--- The captures may hold names: compare them and drop them, never log or store them.
function Probe.MatchGlobal(message, globalName)
    if Probe.IsSecret(message) then
        return nil, "secret"
    end
    local pattern, order = Probe.FormatPattern(_G[globalName])
    if not pattern then
        return nil, "absent"
    end
    if type(message) ~= "string" then
        return nil
    end
    local found = { message:match(pattern) }
    if found[1] == nil then
        return nil
    end
    local captures = {}
    for i, argument in ipairs(order) do
        captures[argument] = found[i]
    end
    return captures
end

local sessionLines, sessionCount = {}, {}
local SESSION_LINES = 80 -- lines Probe:LogOnce writes per check in one session

--- Like Probe:Log, but each `key` once per session and at most SESSION_LINES lines per check: for frequent events (the
--- counters keep everything else). False when nothing was written.
function Probe:LogOnce(id, key, line)
    sessionLines[id] = sessionLines[id] or {}
    key = self.Context() .. "|" .. tostring(key)
    if sessionLines[id][key] or (sessionCount[id] or 0) >= SESSION_LINES then
        return false
    end
    sessionLines[id][key] = true
    sessionCount[id] = (sessionCount[id] or 0) + 1
    self:Log(id, line)
    return true
end

--- The result of a check from its list of revise conditions, the contexts and observations still missing, and its
--- summary: fail, else todo, else pass.
function Probe.Verdict(problems, missing, summary)
    if #problems > 0 then
        return "fail", "revise: " .. table.concat(problems, ", ") .. " | " .. summary
    end
    if #missing > 0 then
        return "todo", "missing: " .. table.concat(missing, ", ") .. " | " .. summary
    end
    return "pass", summary
end

local RECORD_DELAY = 5 -- seconds between an event and the record it updates

--- Returns touch(): an event marks check `id` as changed, and its record is written once, RECORD_DELAY seconds later,
--- from evaluate() (which returns result and details).
function Probe:Toucher(id, evaluate)
    local pending = false
    local function write()
        pending = false
        self:Record(id, evaluate())
    end
    return function()
        if pending then
            return
        end
        pending = Probe.After(RECORD_DELAY, write)
        if not pending then
            write()
        end
    end
end

--- Runs one check inside pcall and stores its result.
function Probe:Run(id)
    local check = self.checks[id]
    if not check then
        out("unknown check (try /azpp list)")
        return
    end
    local ok, result, details
    if check.fn then
        ok, result, details = pcall(check.fn, self)
        if not ok then
            result, details = "info", Probe.ErrorText(result)
        end
    else
        local missing = table.concat(self:Missing(id), " ")
        result = "todo"
        details = "not implemented yet (step " .. check.step .. "); contexts missing: " .. missing
    end
    local entry = self:Record(id, result, details)
    out(id .. " [" .. entry.result .. "] " .. entry.details)
    return entry
end

function Probe:List()
    for _, id in ipairs(self.order) do
        local check, last = self.checks[id], db().results[id]
        local missing = self:Missing(id)
        out(string.format("%s - %s - missing: %s - %s", id, check.description,
            #missing > 0 and table.concat(missing, " ") or "none", last and last.result or "no result"))
    end
end

local function isoTime(t)
    local ok, text = call(date, "!%Y-%m-%dT%H:%M:%SZ", t)
    return ok and text or tostring(t)
end

--- Every result (one line per check) followed by the logs, as plain text.
function Probe:ExportText()
    local d = db()
    local lines = { "AzPr Probe export (build " .. buildString() .. ")" }
    for _, id in ipairs(self.order) do
        local r = d.results[id]
        if r then
            lines[#lines + 1] = table.concat({ id, r.result, r.details, r.build, isoTime(r.time) }, " | ")
        else
            lines[#lines + 1] = id .. " | no result"
        end
    end
    -- the logs of the checks in registry order, then any other log (for example "taint"), sorted
    local names, others = {}, {}
    for _, id in ipairs(self.order) do
        if d.logs[id] then
            names[#names + 1] = id
        end
    end
    for name in pairs(d.logs) do
        if not self.checks[name] then
            others[#others + 1] = name
        end
    end
    table.sort(others)
    for _, name in ipairs(others) do
        names[#names + 1] = name
    end
    for _, name in ipairs(names) do
        lines[#lines + 1] = "-- log: " .. name
        for _, line in ipairs(d.logs[name]) do
            lines[#lines + 1] = line
        end
    end
    return table.concat(lines, "\n")
end

function Probe:Reset()
    AzPr_ProbeDB = nil
    db()
    out("results and logs cleared")
end

local exportFrame

local function buildExportFrame()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "AzPr_ProbeExportFrame", UIParent, template)
    f:SetSize(560, 340)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -14)
    title:SetText("AzPr Probe export (Ctrl+C to copy, drag to move)")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    local scroll = CreateFrame("ScrollFrame", "AzPr_ProbeExportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -40)
    scroll:SetPoint("BOTTOMRIGHT", -36, 18)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(500)
    pcall(edit.SetMaxLetters, edit, 0) -- 0 = no limit
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
    scroll:SetScrollChild(edit)
    f.edit = edit
    return f
end

--- Opens the export frame with every result and log, already selected.
function Probe:Export()
    local ok, err = pcall(function()
        exportFrame = exportFrame or buildExportFrame()
        exportFrame.edit:SetText(self:ExportText())
        exportFrame:Show()
        exportFrame.edit:SetFocus()
        exportFrame.edit:HighlightText()
    end)
    if not ok then
        out("export " .. Probe.ErrorText(err))
    end
end

local USAGE = "/azpp [list] | run <id> | export | reset | help"

--- Adds a helper command: fn(rest) receives the text after the command name. A name typed there is never stored.
function Probe:AddCommand(name, usage, fn)
    self.commands[name] = fn
    self.help[#self.help + 1] = usage
end

function Probe:Help()
    out(USAGE)
    for _, usage in ipairs(self.help) do
        out(usage)
    end
end

function Probe:Command(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "list" then
        self:List()
    elseif cmd == "run" and rest ~= "" then
        self:Run(rest:upper())
    elseif cmd == "export" then
        self:Export()
    elseif cmd == "reset" then
        if rest:lower() == "confirm" then
            self:Reset()
        else
            out("this clears every result and log: type /azpp reset confirm")
        end
    elseif self.commands[cmd] then
        local ok, err = pcall(self.commands[cmd], rest)
        if not ok then
            out(Probe.ErrorText(err))
        end
    else
        self:Help()
    end
end

SLASH_AZPRPROBE1 = "/azpp"
SlashCmdList["AZPRPROBE"] = function(msg)
    Probe:Command(msg)
end

-- Blocked and forbidden actions are logged from login on, under logs.taint (docs/spike/README.md, "Rules").
local function onBlocked(event, addon, func)
    local who = "secret"
    if not Probe.IsSecret(addon) then
        who = addon == ADDON_NAME and "self" or "other"
    end
    local what = Probe.IsSecret(func) and "secret" or oneLine(func, 80)
    Probe:Log("taint", event .. " addon=" .. who .. " function=" .. what)
end

local ok, frame = call(CreateFrame, "Frame")
if ok then
    for _, event in ipairs({ "ADDON_LOADED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    pcall(frame.SetScript, frame, "OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            if ... == ADDON_NAME then
                db()
                out("loaded (development only). " .. USAGE)
            end
        else
            onBlocked(event, ...)
        end
    end)
end
