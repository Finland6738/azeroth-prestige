-- AzPr Probe, M0.6: V9 exploration and flight paths. The explored overlays and area ids of the current map before and
-- after a discovery, the "Discovered" message, the cost of reading the position (for the secret polling of
-- PAT_SECRET), the maps of the continent, and the flight nodes at a flight master and on the maps.
-- Specification: docs/spike/README.md, V9. Lua 5.1. Every game API call goes through pcall (Probe.Call / Probe.Read);
-- every value is tested with issecretvalue before any other use. Zone, area and node names are never written (only
-- whether the discovered name matches the zone or the sub-zone), nor the player's coordinates. The probe never takes a
-- flight.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local Read, IsSecret, Value, Tally, TallyText = Probe.Read, Probe.IsSecret, Probe.Value, Probe.Tally, Probe.TallyText

local V9 = "V9"

local DIFF_DELAY = 2 -- seconds after a discovery or a new flight path at which the state is read again
local TAXI_DELAY = 0.5 -- seconds after TAXIMAP_OPENED
local ID_WINDOW = 5 -- seconds before a discovery message in which a diff with a new id still belongs to it
local IDS_WRITTEN = 12 -- ids written per line
local NODES_MAX = 300 -- flight node ids remembered
local POSITION_CALLS = 100
local GRID = 20 -- GRID x GRID positions sampled for the explored area ids
local FLIGHT_STATE = { [0] = "Current", [1] = "Reachable", [2] = "Unreachable" } -- the dump's values
local CONTINENT, ZONE = 2, 3 -- Enum.UIMapType when it is missing at run time

local baseline = {} -- uiMapID -> { textures, files = {}, areas = {} } (this session)
local taxiOpen = false
local lastIdMs = -math.huge -- Probe.Ms() of the last diff that found a new overlay file or area id

local function count(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function stats()
    return Probe:Stats(V9)
end

local evaluate
local touch = Probe:Toucher(V9, function()
    return evaluate()
end)

local function idList(ids)
    local n = #ids
    local parts = {}
    for i = 1, math.min(n, IDS_WRITTEN) do
        parts[i] = tostring(ids[i])
    end
    return n == 0 and "-" or (table.concat(parts, ",") .. (n > IDS_WRITTEN and ",..." or ""))
end

local function currentMap()
    local shape, map = Read(C_Map and C_Map.GetBestMapForUnit, "player")
    return shape == "number" and map or nil, shape
end

--- The explored overlays of a map and the explored area ids at the player's position.
local function snapshot()
    local map, mapShape = currentMap()
    local s = { map = map, mapShape = mapShape, textures = 0, files = {}, areas = {} }
    if not map then
        return s
    end
    local E = C_MapExplorationInfo or {}
    local texShape, overlays = Read(E.GetExploredMapTextures, map)
    s.textureShape = texShape
    if texShape == "table" then
        pcall(function()
            for _, overlay in ipairs(overlays) do
                s.textures = s.textures + 1
                if not IsSecret(overlay) and not IsSecret(overlay.fileDataIDs) then
                    for _, file in ipairs(overlay.fileDataIDs) do
                        if not IsSecret(file) then
                            s.files[file] = true
                        end
                    end
                else
                    s.textureShape = "secret entries"
                end
            end
        end)
    end
    local posShape, position = Read(C_Map.GetPlayerMapPosition, map, "player")
    s.positionShape = posShape
    if posShape == "table" then
        local xShape = Read(position.GetXY, position)
        if xShape ~= "number" then
            s.positionShape = "table with " .. xShape .. " x"
        end
        local areaShape, areas = Read(E.GetExploredAreaIDsAtPosition, map, position)
        s.areaShape = areaShape
        if areaShape == "table" then
            pcall(function()
                for _, id in ipairs(areas) do
                    if not IsSecret(id) then
                        s.areas[#s.areas + 1] = id
                    end
                end
            end)
        end
    end
    return s
end

local function snapshotText(s)
    if not s.map then
        return "uiMapID=" .. s.mapShape
    end
    return string.format("uiMapID=%d overlays=%s (%d) position=%s area ids at position=%s [%s]", s.map,
        s.textureShape or "-", s.textures, s.positionShape or "-", s.areaShape or "-", idList(s.areas))
end

--- Remembers the state of the snapshot's map; returns the number of overlay files and area ids it did not know, and
--- the difference in the number of overlays (nil when the map had no baseline).
local function compare(s)
    if not s.map then
        return nil
    end
    local known = baseline[s.map]
    local newFiles, newAreas, delta = {}, {}, nil
    if known then
        delta = s.textures - known.textures
        for file in pairs(s.files) do
            if not known.files[file] then
                newFiles[#newFiles + 1] = file
            end
        end
        for _, id in ipairs(s.areas) do
            if not known.areas[id] then
                newAreas[#newAreas + 1] = id
            end
        end
    end
    local entry = known or { files = {}, areas = {} }
    entry.textures = s.textures
    for file in pairs(s.files) do
        entry.files[file] = true
    end
    for _, id in ipairs(s.areas) do
        entry.areas[id] = true
    end
    baseline[s.map] = entry
    if not known then
        return nil
    end
    table.sort(newFiles)
    return newFiles, newAreas, delta
end

--- A baseline for a map seen for the first time (a known map keeps its older state, to compare a discovery with it).
local function remember(why)
    local s = snapshot()
    if s.map and not baseline[s.map] then
        compare(s)
        Probe:LogOnce(V9, "map" .. s.map, why .. " | baseline " .. snapshotText(s))
    end
end

-- Flight paths ---------------------------------------------------------------------------------------------------------

local function taxiMapID()
    local shape, id = Read(GetTaxiMapID)
    if shape == "number" and id > 0 then
        return id, "GetTaxiMapID"
    end
    return currentMap(), "GetBestMapForUnit (GetTaxiMapID " .. shape .. ")"
end

local function nodeTallies(nodes, fields)
    local t = { n = 0, states = {}, ids = {}, secrets = 0 }
    pcall(function()
        for _, node in ipairs(nodes) do
            t.n = t.n + 1
            if IsSecret(node) then
                t.secrets = t.secrets + 1
            else
                for _, key in ipairs(fields) do
                    if IsSecret(node[key]) then
                        t.secrets = t.secrets + 1
                    end
                end
                local id, state, undiscovered = node.nodeID, node.state, node.isUndiscovered
                if not IsSecret(id) and type(id) == "number" then
                    t.ids[#t.ids + 1] = id
                end
                if not IsSecret(state) and state ~= nil then
                    local key = Probe.EnumKey("FlightPathState", state)
                    Tally(t.states, tonumber(key) and (FLIGHT_STATE[state] or key) or key)
                end
                if not IsSecret(undiscovered) and undiscovered ~= nil then
                    Tally(t.states, "undiscovered " .. tostring(undiscovered))
                end
            end
        end
    end)
    return t
end

--- C_TaxiMap.GetTaxiNodesForMap: what a map tells away from a flight master.
local function mapNodes(map)
    local shape, nodes = Read(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap, map)
    if shape ~= "table" then
        return string.format("GetTaxiNodesForMap(%d)=%s", map, shape)
    end
    local t = nodeTallies(nodes, { "nodeID", "isUndiscovered", "faction" })
    if t.n > 0 then
        stats().mapNodes = math.max(stats().mapNodes or 0, t.n)
    end
    return string.format("GetTaxiNodesForMap(%d): %d nodes, %s, secret %d, ids %s", map, t.n, TallyText(t.states),
        t.secrets, idList(t.ids))
end

local function taxiRead(why)
    local st = stats()
    local map, how = taxiMapID()
    if not map then
        Probe:Log(V9, why .. " | no map for the flight nodes (" .. how .. ")")
        return
    end
    local shape, nodes = Read(C_TaxiMap and C_TaxiMap.GetAllTaxiNodes, map)
    if shape ~= "table" then
        count(st, "taxiBad")
        Probe:Log(V9, string.format("%s | GetAllTaxiNodes(%d)=%s", why, map, shape))
        return
    end
    local t = nodeTallies(nodes, { "nodeID", "state", "slotIndex" })
    if t.n == 0 or t.secrets > 0 then
        count(st, "taxiBad")
    else
        count(st, "taxiReads")
        Probe:Cover(V9)
    end
    st.nodes = st.nodes or {}
    local known, new = 0, {}
    for _ in pairs(st.nodes) do
        known = known + 1
    end
    for _, id in ipairs(t.ids) do
        if not st.nodes[tostring(id)] and known < NODES_MAX then
            st.nodes[tostring(id)] = true
            known = known + 1
            new[#new + 1] = id
        end
    end
    local first = "-"
    pcall(function()
        if nodes[1] ~= nil then
            first = Probe.TableShape(nodes[1])
        end
    end)
    Probe:LogOnce(V9, why .. map .. TallyText(t.states) .. #new, string.format("%s | GetAllTaxiNodes(%d) via %s: %d "
        .. "nodes, %s, secret %d, ids %s, new ids %d [%s] | first node %s", why, map, how, t.n, TallyText(t.states),
        t.secrets, idList(t.ids), #new, idList(new), first))
    Probe:LogOnce(V9, "mapNodes" .. map, why .. " | " .. mapNodes(map))
end

-- Discoveries ----------------------------------------------------------------------------------------------------------

local function matchesText(captured, fn)
    local shape, text = Read(fn)
    return shape == "string" and not IsSecret(captured) and captured == text
end

local function discoveryDiff(why)
    local st = stats()
    local s = snapshot()
    local newFiles, newAreas, delta = compare(s)
    if not newFiles then
        Probe:Log(V9, why .. " | no earlier state of this map | " .. snapshotText(s))
        return nil
    end
    local line = string.format("%s | overlays delta %d, new overlay files %d [%s], new area ids %d [%s] | %s", why,
        delta, #newFiles, idList(newFiles), #newAreas, idList(newAreas), snapshotText(s))
    Probe:LogOnce(V9, line, line)
    if #newFiles + #newAreas > 0 then
        count(st, "diffWithId")
        lastIdMs = Probe.Ms()
        return true
    end
    return false
end

local function onDiscovery(globalName, captured)
    local st = stats()
    count(st, "discoveries")
    Probe:Cover(V9)
    local matches = matchesText(captured, GetSubZoneText) and "the sub-zone"
        or matchesText(captured, GetZoneText) and "the zone" or "neither"
    Probe:Log(V9, string.format("discovery message %s, the name matches %s", globalName, matches))
    local at = Probe.Ms()
    Probe.After(DIFF_DELAY, function()
        local found = discoveryDiff(DIFF_DELAY .. " s after the discovery")
        -- MAP_EXPLORATION_UPDATED, around the message, may already have taken the new ids into the baseline
        if lastIdMs >= at - ID_WINDOW * 1000 then
            count(stats(), "withId")
        elseif found == false then
            count(stats(), "noId")
        end
        touch()
    end)
    touch()
end

local function onInfoMessage(errorType, message)
    local name = "-"
    if not IsSecret(errorType) and type(errorType) == "number" then
        local _, key = Read(GetGameMessageInfo, errorType)
        name = Probe.Token(key) or "-"
    end
    if IsSecret(message) then
        count(stats(), "messageSecret")
        Probe:LogOnce(V9, "secret" .. name, "UI_INFO_MESSAGE with a secret text, errorType " .. name)
        return
    end
    for _, globalName in ipairs({ "ERR_ZONE_EXPLORED_XP", "ERR_ZONE_EXPLORED" }) do
        local captures = Probe.MatchGlobal(message, globalName)
        if captures then
            Probe:Log(V9, "UI_INFO_MESSAGE errorType=" .. Value(errorType) .. " " .. name)
            onDiscovery(globalName, captures[1])
            return
        end
    end
    if Probe.MatchGlobal(message, "ERR_NEWTAXIPATH") then
        count(stats(), "newPaths")
        Probe:Log(V9, "new flight path message (ERR_NEWTAXIPATH), errorType " .. name)
        Probe.After(DIFF_DELAY, function()
            if taxiOpen then
                taxiRead("after the new flight path")
            end
            touch()
        end)
    end
end

-- The position, the area grid and the continent ------------------------------------------------------------------------

local function positionCost()
    local map = currentMap()
    local fn = C_Map and C_Map.GetPlayerMapPosition
    if not map or type(fn) ~= "function" then
        return "position cost: not measured"
    end
    local before = Probe.Ms()
    for _ = 1, POSITION_CALLS do
        pcall(fn, map, "player")
    end
    return string.format("GetPlayerMapPosition x%d in %.2f ms", POSITION_CALLS, Probe.Ms() - before)
end

--- The explored area ids over a grid of the current map: what the client lists of a zone (never the total).
local function areaGrid()
    local map = currentMap()
    local fn = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredAreaIDsAtPosition
    if not map or type(fn) ~= "function" or type(CreateVector2D) ~= "function" then
        return "area grid: not measured (CreateVector2D=" .. type(CreateVector2D) .. ")"
    end
    local seen, ids, errors = {}, {}, 0
    local before = Probe.Ms()
    for ix = 1, GRID do
        for iy = 1, GRID do
            local shape, point = Read(CreateVector2D, (ix - 0.5) / GRID, (iy - 0.5) / GRID)
            if shape == "table" then
                local areaShape, areas = Read(fn, map, point)
                if areaShape == "table" then
                    pcall(function()
                        for _, id in ipairs(areas) do
                            if not IsSecret(id) and not seen[id] then
                                seen[id] = true
                                ids[#ids + 1] = id
                            end
                        end
                    end)
                elseif areaShape ~= "nil" then
                    errors = errors + 1
                end
            end
        end
    end
    table.sort(ids)
    return string.format("area grid %dx%d on uiMapID %d: %d explored area ids [%s], failed %d, %.1f ms", GRID, GRID,
        map, #ids, idList(ids), errors, Probe.Ms() - before)
end

--- The parents of the current map up to its continent, and the number of zones of that continent.
local function continent()
    local map = currentMap()
    local fn = C_Map and C_Map.GetMapInfo
    local continentType, zoneType = CONTINENT, ZONE
    pcall(function()
        continentType, zoneType = Enum.UIMapType.Continent, Enum.UIMapType.Zone
    end)
    local chain = {}
    for _ = 1, 6 do
        if not map or map == 0 then
            break
        end
        local shape, info = Read(fn, map)
        if shape ~= "table" or IsSecret(info.mapType) or IsSecret(info.parentMapID) then
            chain[#chain + 1] = map .. ":" .. shape
            break
        end
        chain[#chain + 1] = map .. ":" .. Probe.EnumKey("UIMapType", info.mapType)
        if info.mapType == continentType then
            local childShape, children = Read(C_Map.GetMapChildrenInfo, map, zoneType, true)
            return string.format("maps %s | zones of continent %d: %s | %s", table.concat(chain, " > "), map,
                childShape == "table" and tostring(#children) or childShape, mapNodes(map))
        end
        map = info.parentMapID
    end
    return "maps " .. table.concat(chain, " > ") .. " | no continent found"
end

evaluate = function()
    local st = stats()
    local problems = {}
    local function problem(key, text)
        if (st[key] or 0) > 0 then
            problems[#problems + 1] = text .. " x" .. st[key]
        end
    end
    problem("noId", "discovery with no new overlay or area id")
    problem("positionBad", "position unreadable in W")
    problem("taxiBad", "flight nodes empty, secret or unreadable")
    local nodes = 0
    for _ in pairs(st.nodes or {}) do
        nodes = nodes + 1
    end
    local summary = string.format("discoveries %d, with a new id %d, without %d (diffs with id %d); flight map reads %d, "
        .. "node ids %d, new path messages %d, nodes away from a master %d", st.discoveries or 0, st.withId or 0,
        st.noId or 0, st.diffWithId or 0, st.taxiReads or 0, nodes, st.newPaths or 0, st.mapNodes or 0)
    local missing = Probe:Missing(V9)
    if (st.withId or 0) == 0 then
        missing[#missing + 1] = "a discovery with a new id"
    end
    if (st.taxiReads or 0) == 0 then
        missing[#missing + 1] = "a flight map read"
    end
    return Probe.Verdict(problems, missing, summary)
end

Probe:Watch({ "PLAYER_LOGIN", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
    "MAP_EXPLORATION_UPDATED", "UI_INFO_MESSAGE", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "TAXI_NODE_STATUS_CHANGED" },
    function(event, ...)
        if event == "UI_INFO_MESSAGE" then
            onInfoMessage(...)
        elseif event == "PLAYER_LOGIN" then
            Probe.After(DIFF_DELAY * 2, function()
                remember("login")
            end)
        elseif event == "MAP_EXPLORATION_UPDATED" then
            count(stats(), "explorationUpdates")
            discoveryDiff("MAP_EXPLORATION_UPDATED")
            touch()
        elseif event == "TAXIMAP_OPENED" then
            taxiOpen = true
            Probe:Log(V9, "TAXIMAP_OPENED system=" .. Value((...)))
            Probe.After(TAXI_DELAY, function()
                taxiRead("flight map open")
                touch()
            end)
        elseif event == "TAXIMAP_CLOSED" then
            taxiOpen = false
        elseif event == "TAXI_NODE_STATUS_CHANGED" then
            count(stats(), "nodeStatus")
            if taxiOpen then
                taxiRead(event)
            end
        else
            Probe.After(DIFF_DELAY, function()
                remember(event)
            end)
        end
    end)

Probe:Implement(V9, function(probe)
    local st = stats()
    local s = snapshot()
    probe:Log(V9, string.format("run | %s | events: MAP_EXPLORATION_UPDATED %d, TAXI_NODE_STATUS_CHANGED %d",
        snapshotText(s), st.explorationUpdates or 0, st.nodeStatus or 0))
    if s.map and not baseline[s.map] then
        compare(s)
    end
    local tag = probe.Context()
    if tag == "W" or tag == "D" then
        if tag == "W" and s.positionShape ~= "table" then
            count(st, "positionBad")
        end
        probe:Cover(V9, tag)
    end
    local functions = {}
    pcall(function()
        for name in pairs(C_MapExplorationInfo) do
            functions[#functions + 1] = tostring(name)
        end
    end)
    table.sort(functions)
    probe:Log(V9, "run | " .. positionCost() .. " | C_MapExplorationInfo: " .. table.concat(functions, ","))
    probe:Log(V9, "run | " .. areaGrid())
    probe:Log(V9, "run | " .. continent())
    if taxiOpen then
        taxiRead("run")
    end
    return evaluate()
end)
