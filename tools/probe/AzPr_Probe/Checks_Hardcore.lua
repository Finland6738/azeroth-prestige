-- AzPr Probe, M0.7: V17 Hardcore realm detection and the permanent death. Specification: docs/spike/README.md, V17.
-- Lua 5.1. Every game API call goes through pcall (Probe.Call / Probe.Read); every value is tested with issecretvalue
-- before any other use. Of a death only the date and the instance type are saved, never a name: the argument of
-- HARDCORE_DEATHS is not even looked at, and the killer is never read. The probe never releases, resurrects or
-- retrieves anything.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local Read, IsSecret, Value, Tally, TallyText = Probe.Read, Probe.IsSecret, Probe.Value, Probe.Tally, Probe.TallyText

local V17 = "V17"

local DEATHS_MAX = 20
local LOGIN_DELAY = 5 -- seconds after the login before a dead character is looked at

local declared -- "yes" / "no": what the owner says about this character's realm (this session only, never stored)
local loginFlag -- IsHardcoreActive() as read at PLAYER_LOGIN
local dead -- true between PLAYER_DEAD and PLAYER_ALIVE / PLAYER_UNGHOST
local feigning = false

local function stats()
    return Probe:Stats(V17)
end

local evaluate
local touch = Probe:Toucher(V17, function()
    return evaluate()
end)

local function hardcoreText()
    return Probe.BoolText(C_GameRules and C_GameRules.IsHardcoreActive)
end

--- True when this character counts as a Hardcore one: the client says so, or the owner does.
local function isHardcore()
    return declared == "yes" or hardcoreText() == "true"
end

local function gameModeText()
    local shape, mode = Read(C_GameRules and C_GameRules.GetActiveGameMode)
    if mode == nil then
        return shape
    end
    return Value(mode) .. " (" .. Probe.EnumKey("GameMode", mode) .. ")"
end

--- Every game rule whose name speaks of death, Hardcore or self-found, and whether it is active.
local function rulesText()
    local rules = {}
    local ok = pcall(function()
        for key, value in pairs(Enum.GameRule) do
            local lower = tostring(key):lower()
            if lower:find("death", 1, true) or lower:find("hardcore", 1, true) or lower:find("selffound", 1, true) then
                rules[#rules + 1] = { tostring(key), value }
            end
        end
    end)
    if not ok then
        return "Enum.GameRule unreadable"
    end
    table.sort(rules, function(a, b) return a[1] < b[1] end)
    local parts = {}
    for _, rule in ipairs(rules) do
        parts[#parts + 1] = rule[1] .. "=" .. Probe.BoolText(C_GameRules and C_GameRules.IsGameRuleActive, rule[2])
    end
    return #parts > 0 and table.concat(parts, " ") or "no rule of death, Hardcore or self-found"
end

--- Compares what the client says with what the owner says.
local function compare()
    if not declared then
        return
    end
    local flag = hardcoreText()
    local expected = declared == "yes" and "true" or "false"
    if flag ~= expected then
        Tally(stats(), declared == "yes" and "falseOnHardcore" or "trueOnNormal")
    end
    if declared == "yes" and loginFlag and loginFlag ~= "true" then
        stats().notAtLogin = 1
    end
end

local function readRealm(why)
    local st = stats()
    local flag = hardcoreText()
    if flag == "true" then
        st.flagTrue = 1
        Probe:Cover(V17, "HC")
    elseif flag == "false" then
        st.flagFalse = 1
    else
        st.flagBad = flag
    end
    if declared == "yes" then
        Probe:Cover(V17, "HC")
    end
    if Probe.Context() == "W" then
        Probe:Cover(V17, "W")
    end
    compare()
    local text = string.format("IsHardcoreActive=%s GetActiveGameMode=%s IsSelfFoundAllowed=%s declared=%s | %s", flag,
        gameModeText(), Probe.BoolText(C_GameRules and C_GameRules.IsSelfFoundAllowed), declared or "-", rulesText())
    Probe:LogOnce(V17, why .. text, why .. " | " .. text)
    touch()
end

local function today()
    local shape, text = Read(date, "!%Y-%m-%d")
    return type(text) == "string" and text or shape
end

--- The instance type of the place ("none" in the open world), never a zone name.
local function zoneType()
    local ok, res = Probe.Returns(IsInInstance)
    if not ok or IsSecret(res[2]) then
        return ok and "secret" or "error"
    end
    return Probe.Token(res[2]) or Value(res[2])
end

local function deathText()
    local shape, options = Read(C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions)
    local n = shape
    if type(options) == "table" then
        n = Probe.Shape(options)
    end
    return string.format("UnitIsDeadOrGhost=%s UnitIsGhost=%s UnitIsFeignDeath=%s selfResurrectOptions=%s",
        Probe.BoolText(UnitIsDeadOrGhost, "player"), Probe.BoolText(UnitIsGhost, "player"),
        Probe.BoolText(UnitIsFeignDeath, "player"), n)
end

local function onDead()
    local st = stats()
    local hardcore = isHardcore()
    local _, feign = Read(UnitIsFeignDeath, "player")
    local _, isDead = Read(UnitIsDeadOrGhost, "player")
    if feign == true then
        Tally(st, "deadWhileFeign")
    end
    if dead then
        Tally(st, "deadTwice")
    end
    dead = true
    if hardcore then
        Tally(st, "hardcoreDeaths")
        if isDead == false then
            Tally(st, "deadButAlive")
        end
        st.deaths = st.deaths or {}
        st.deaths[#st.deaths + 1] = { date = today(), zone = zoneType() }
        while #st.deaths > DEATHS_MAX do
            table.remove(st.deaths, 1)
        end
    else
        Tally(st, "normalDeaths")
    end
    Probe:Log(V17, string.format("PLAYER_DEAD | hardcore=%s date=%s zone=%s | %s", tostring(hardcore),
        hardcore and today() or "-", zoneType(), deathText()))
    -- recorded at once: a Hardcore character may leave the world before a delayed record
    Probe:Record(V17, evaluate())
end

local function onBack(event)
    if dead and isHardcore() then
        Tally(stats(), "after" .. event)
    end
    Probe:Log(V17, event .. " | " .. deathText())
    local _, isDead = Read(UnitIsDeadOrGhost, "player")
    if isDead == false then
        dead = false
    end
    touch()
end

local function onFeign()
    local _, feign = Read(UnitIsFeignDeath, "player")
    local now = feign == true
    if now ~= feigning then
        feigning = now
        if now then
            Tally(stats(), "feigns")
        end
        Probe:Log(V17, (now and "feign death starts" or "feign death ends") .. " | " .. deathText())
        touch()
    end
end

local function onLogin()
    loginFlag = hardcoreText()
    readRealm("PLAYER_LOGIN")
    Probe.After(LOGIN_DELAY, function()
        local _, isDead = Read(UnitIsDeadOrGhost, "player")
        if isDead == true then
            dead = true
            Tally(stats(), "deadAtLogin")
            Probe:Log(V17, "dead at login | IsHardcoreActive=" .. hardcoreText() .. " | " .. deathText())
            touch()
        end
    end)
end

evaluate = function()
    local st = stats()
    local problems, missing = {}, Probe:Missing(V17)
    local function problem(key, text)
        if (st[key] or 0) > 0 then
            problems[#problems + 1] = text .. " x" .. st[key]
        end
    end
    if st.flagBad then
        problems[#problems + 1] = "IsHardcoreActive " .. st.flagBad
    end
    problem("falseOnHardcore", "flag false on a Hardcore realm")
    problem("trueOnNormal", "flag true on a Normal realm")
    if st.notAtLogin then
        problems[#problems + 1] = "flag not true at login"
    end
    problem("deadWhileFeign", "PLAYER_DEAD during a feigned death")
    problem("deadTwice", "PLAYER_DEAD twice for one death")
    problem("deadButAlive", "Hardcore PLAYER_DEAD while not dead")
    if not st.flagTrue then
        missing[#missing + 1] = "a Hardcore realm (flag true)"
    end
    if not st.flagFalse then
        missing[#missing + 1] = "a Normal realm (flag false)"
    end
    if (st.hardcoreDeaths or 0) == 0 then
        missing[#missing + 1] = "a Hardcore death"
    end
    local summary = string.format("flag true %s false %s; deaths hardcore %d normal %d; feigns %d; HARDCORE_DEATHS %d; "
        .. "after death %s/%s; dead at login %d; logout after death %d", st.flagTrue and "seen" or "no",
        st.flagFalse and "seen" or "no", st.hardcoreDeaths or 0, st.normalDeaths or 0, st.feigns or 0,
        st.broadcasts or 0, TallyText({ ALIVE = st.afterPLAYER_ALIVE }), TallyText({ UNGHOST = st.afterPLAYER_UNGHOST }),
        st.deadAtLogin or 0, st.logoutDead or 0)
    return Probe.Verdict(problems, missing, summary)
end

Probe:AddCommand("hardcore", "/azpp hardcore yes|no (V17: is this character on a Hardcore realm?)", function(rest)
    local answer = rest:lower()
    if answer ~= "yes" and answer ~= "no" then
        Probe.Print("/azpp hardcore yes|no")
        return
    end
    declared = answer
    readRealm("declared")
    Probe.Print("V17: realm declared Hardcore=" .. answer .. ", IsHardcoreActive=" .. hardcoreText())
end)

Probe:Watch({ "PLAYER_LOGIN", "GAME_RULES_CHANGED", "ACTIVE_GAME_MODE_UPDATED", "PLAYER_DEAD", "PLAYER_ALIVE",
    "PLAYER_UNGHOST", "HARDCORE_DEATHS", "PLAYER_LOGOUT" }, function(event)
    if event == "PLAYER_LOGIN" then
        onLogin()
    elseif event == "PLAYER_DEAD" then
        onDead()
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        onBack(event)
    elseif event == "HARDCORE_DEATHS" then
        Tally(stats(), "broadcasts") -- counted only: the argument is a name
        Probe:LogOnce(V17, event .. hardcoreText(), event .. " received, IsHardcoreActive=" .. hardcoreText())
        touch()
    elseif event == "PLAYER_LOGOUT" then
        if dead then
            Tally(stats(), "logoutDead")
        end
    elseif event == "UNIT_AURA" then
        onFeign()
    else
        readRealm(event)
    end
end, { UNIT_AURA = "player" })

Probe:Implement(V17, function(probe)
    readRealm("run")
    onFeign()
    local deaths = {}
    for _, death in ipairs(stats().deaths or {}) do
        deaths[#deaths + 1] = death.date .. " " .. death.zone
    end
    probe:Log(V17, "run | " .. deathText() .. " | recorded Hardcore deaths: "
        .. (#deaths > 0 and table.concat(deaths, ", ") or "none"))
    return evaluate()
end)
