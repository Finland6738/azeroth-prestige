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
