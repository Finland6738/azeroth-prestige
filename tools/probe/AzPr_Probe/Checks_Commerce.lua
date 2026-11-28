-- AzPr Probe, M0.6: V11 Auction House presence, mail invoices and trades. The auctioneer, the inbox headers and the
-- invoices, a completed trade told apart from a cancelled one, what both sides give and the partner's level.
-- Specification: docs/spike/README.md, V11. Lua 5.1. Every game API call goes through pcall (Probe.Call / Probe.Read);
-- every value is tested with issecretvalue before any other use. Never a name: senders, subjects and item names are
-- written as their type, a buyer only as present and as the same as the previous invoice (compared in memory, never
-- stored); money only as its type and whether it is above zero. The probe never reads a mail body (that would mark it
-- read), takes mail, posts auctions, or touches a trade: it only listens and reads.

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

local Read, IsSecret, Value, Tally, TallyText = Probe.Read, Probe.IsSecret, Probe.Value, Probe.Tally, Probe.TallyText

local V11 = "V11"

local MAIL_MAX = 50
local MAIL_DELAY = 1 -- seconds after MAIL_INBOX_UPDATE (it fires many times) before the inbox is read
local TRADE_SLOTS = 7 -- six traded slots and the "will not be traded" one
local TRADED_SLOTS = 6
local TRADE_SETTLE = 3 -- seconds after TRADE_CLOSED in which the confirming message may still arrive
local HEADER_NAMES = { "packageIcon", "stationeryIcon", "sender", "subject", "money", "CODAmount", "daysLeft",
    "itemCount", "wasRead", "wasReturned", "textCreated", "canReply", "isGM" }
local INVOICE_NAMES = { "invoiceType", "itemName", "playerName", "bid", "buyout", "deposit", "consignment",
    "moneyDelay", "etaHour", "etaMin", "count", "commerceAuction" }
local MONEY_RETURNS = { bid = true, buyout = true, deposit = true, consignment = true }
local AUCTION_FUNCTIONS = { "GetNumOwnedAuctions", "GetOwnedAuctionInfo", "QueryOwnedAuctions", "PostItem" }
local TRADE_MESSAGES = { "ERR_TRADE_COMPLETE", "ERR_TRADE_CANCELLED" }

local mailOpen, mailPending = false, false
local trade -- the current trade of this session

local function count(t, key, n)
    t[key] = (t[key] or 0) + (n or 1)
end

local function stats()
    return Probe:Stats(V11)
end

local function coverHere()
    local tag = Probe.Context()
    Probe:Cover(V11, tag == "WC" and "W" or tag)
end

local evaluate
local touch = Probe:Toucher(V11, function()
    return evaluate()
end)

-- The Auction House ----------------------------------------------------------------------------------------------------

local function auctionApi()
    local parts = {}
    for _, name in ipairs(AUCTION_FUNCTIONS) do
        parts[#parts + 1] = name .. "=" .. type(C_AuctionHouse and C_AuctionHouse[name])
    end
    return string.format("C_AuctionHouse=%s (%s); classic GetNumAuctionItems=%s", type(C_AuctionHouse),
        table.concat(parts, " "), type(GetNumAuctionItems))
end

local function ownedText()
    local H = C_AuctionHouse or {}
    return string.format("GetNumOwnedAuctions=%s HasFullOwnedAuctionResults=%s",
        Probe.ReadValue(H.GetNumOwnedAuctions), Probe.BoolText(H.HasFullOwnedAuctionResults))
end

local function onAuction(event, arg)
    local st = stats()
    if event == "AUCTION_HOUSE_SHOW" then
        count(st, "ahShown")
        coverHere()
        Probe:Log(V11, "AUCTION_HOUSE_SHOW | " .. auctionApi() .. " | " .. ownedText())
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        count(st, "auctionsCreated")
        Probe:Log(V11, "AUCTION_HOUSE_AUCTION_CREATED auctionID=" .. Value(arg))
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        local text = event .. " | " .. ownedText()
        Probe:LogOnce(V11, text, text)
    else
        Probe:LogOnce(V11, event, event)
    end
    touch()
end

local function onInteraction(event, interaction)
    local key = Probe.EnumKey("PlayerInteractionType", interaction)
    if key == "Auctioneer" then
        stats().auctioneer = 1
    end
    Probe:LogOnce(V11, event .. key, string.format("%s type=%s (%s)", event, Value(interaction), key))
end

-- Mail -----------------------------------------------------------------------------------------------------------------

--- A header return: its type only (numbers and booleans may be money or flags: booleans keep their value).
local function headerText(i)
    local ok, res, n = Probe.Returns(GetInboxHeaderInfo, i)
    if not ok then
        return "error", 0
    end
    local parts, secrets = {}, 0
    for k = 1, math.max(n, #HEADER_NAMES) do
        local v = res[k]
        local text
        if IsSecret(v) then
            text, secrets = "secret", secrets + 1
        elseif type(v) == "boolean" then
            text = tostring(v)
        else
            text = type(v)
        end
        parts[#parts + 1] = (HEADER_NAMES[k] or ("r" .. k)) .. "=" .. text
    end
    return table.concat(parts, " "), secrets
end

local function positive(v)
    if type(v) == "number" then
        return v > 0 and "number>0" or "number=0"
    end
    return type(v)
end

--- The itemID of a link, or of a name the item cache knows; the link and the name are never written.
local function itemID(text, pattern)
    if IsSecret(text) or type(text) ~= "string" then
        return nil
    end
    if pattern then
        return tonumber(text:match("item:(%d+)"))
    end
    local shape, id = Read(C_Item and C_Item.GetItemInfoInstant, text)
    return shape == "number" and id or nil
end

--- One invoice. `previous` holds the buyer of the invoice before, to say "same" or "different" and nothing else.
local function invoiceText(i, previous)
    local ok, res, n = Probe.Returns(GetInboxInvoiceInfo, i)
    if not ok then
        return res[1] == "absent" and "absent" or "error", nil
    end
    if not IsSecret(res[1]) and res[1] == nil then
        return nil, nil
    end
    local st = stats()
    local invoiceType = Probe.Token(res[1])
    if IsSecret(res[1]) then
        count(st, "invoiceSecret")
    end
    local parts, secrets = {}, 0
    for k = 1, math.max(n, #INVOICE_NAMES) do
        local key, v = INVOICE_NAMES[k] or ("r" .. k), res[k]
        local text
        if IsSecret(v) then
            text, secrets = "secret", secrets + 1
        elseif key == "invoiceType" then
            text = invoiceType or type(v)
        elseif key == "playerName" then
            if type(v) == "string" and v ~= "" then
                text = "present"
                if previous.buyer then
                    text = text .. (previous.buyer == v and ", same as the previous invoice"
                        or ", different from the previous invoice")
                end
                previous.buyer = v
            else
                text = type(v) == "string" and "empty" or type(v)
            end
        elseif MONEY_RETURNS[key] then
            text = positive(v)
        elseif key == "count" or key == "commerceAuction" then
            text = Value(v)
        else
            text = type(v)
        end
        parts[#parts + 1] = key .. "=" .. text
    end
    local linkID = itemID(select(2, Read(GetInboxItemLink, i, 1)), true)
    local nameID = itemID(res[2])
    parts[#parts + 1] = "itemID from attachment=" .. tostring(linkID or "none")
        .. " itemID from itemName=" .. tostring(nameID or "none")
    parts[#parts + 1] = "HasInboxMoney=" .. Probe.BoolText(C_Mail and C_Mail.HasInboxMoney, i)
    if secrets > 0 then
        count(st, "invoiceSecret")
    end
    if invoiceType == "seller" then
        local buyer = not IsSecret(res[3]) and type(res[3]) == "string" and res[3] ~= ""
        if buyer then
            st.sellerBuyer = 1
            if linkID or nameID then
                st.sellerItem = 1
            end
        elseif not IsSecret(res[3]) then
            count(st, "sellerNoBuyer")
        end
    end
    return table.concat(parts, " "), invoiceType or "unknown"
end

local function readInbox(why)
    local st = stats()
    local ok, res = Probe.Returns(GetInboxNumItems)
    local n, total = res[1], res[2]
    if not ok or IsSecret(n) or type(n) ~= "number" then
        Probe:Log(V11, why .. " | GetInboxNumItems=" .. (ok and Value(n) or "error"))
        return
    end
    local invoices, previous, headerSecrets, lines = {}, {}, 0, {}
    for i = 1, math.min(n, MAIL_MAX) do
        local header, secrets = headerText(i)
        headerSecrets = headerSecrets + secrets
        if i == 1 then
            Probe:LogOnce(V11, "header" .. header, "first inbox header | " .. header)
        end
        local text, kind = invoiceText(i, previous)
        if text then
            Tally(invoices, kind or text)
            if kind then
                lines[#lines + 1] = { key = text, line = "invoice | " .. text }
            end
        end
    end
    if n > 0 then
        coverHere()
    end
    for kind, k in pairs(invoices) do
        st.invoices = st.invoices or {}
        st.invoices[kind] = math.max(st.invoices[kind] or 0, k)
    end
    if headerSecrets > 0 then
        count(st, "headerSecret")
    end
    local summary = string.format("inbox items %d of %s, invoices %s, header secrets %d", n, Value(total),
        TallyText(invoices), headerSecrets)
    Probe:LogOnce(V11, summary, why .. " | " .. summary)
    for _, entry in ipairs(lines) do
        Probe:LogOnce(V11, entry.key, entry.line)
    end
    touch()
end

local function onMail(event)
    if event == "MAIL_SHOW" then
        mailOpen = true
        Probe:LogOnce(V11, event, event .. " | GetInboxInvoiceInfo=" .. type(GetInboxInvoiceInfo))
    elseif event == "MAIL_CLOSED" then
        mailOpen = false
    elseif mailOpen and not mailPending then
        mailPending = Probe.After(MAIL_DELAY, function()
            mailPending = false
            if mailOpen then
                readInbox("MAIL_INBOX_UPDATE")
            end
        end)
    end
end

-- Trades ---------------------------------------------------------------------------------------------------------------

--- One side of the trade window: filled slots, item ids, money above zero, secrets.
local function side(info, link, money)
    local s = { items = 0, ids = {}, secrets = 0 }
    for slot = 1, TRADE_SLOTS do
        local ok, res = Probe.Returns(info, slot)
        if not ok then
            s.error = res[1] == "absent" and "absent" or "error"
            break
        end
        if IsSecret(res[1]) then
            s.secrets = s.secrets + 1
        elseif res[1] ~= nil and res[1] ~= "" then
            if slot <= TRADED_SLOTS then
                s.items = s.items + 1
                local id = itemID(select(2, Read(link, slot)), true)
                s.ids[#s.ids + 1] = tostring(id or "?")
            else
                s.extra = true
            end
            if not s.shape then
                local parts = {}
                for k = 1, 6 do
                    parts[#parts + 1] = Probe.Shape(res[k])
                end
                s.shape = table.concat(parts, ",")
            end
        end
    end
    local shape, amount = Read(money)
    if shape == "secret" then
        s.secrets = s.secrets + 1
    end
    s.money = amount == nil and shape or positive(amount)
    s.gives = s.items > 0 or s.money == "number>0"
    return s
end

local function sideText(label, s)
    return string.format("%s items %d [%s]%s money %s secret %d%s%s", label, s.items,
        #s.ids > 0 and table.concat(s.ids, ",") or "-", s.extra and " +slot 7" or "", s.money, s.secrets,
        s.shape and (" returns " .. s.shape) or "", s.error and (" " .. s.error) or "")
end

local function readTrade(why)
    if not trade or trade.closed then
        return
    end
    trade.mine = side(GetTradePlayerItemInfo, GetTradePlayerItemLink, GetPlayerTradeMoney)
    trade.theirs = side(GetTradeTargetItemInfo, GetTradeTargetItemLink, GetTargetTradeMoney)
    if trade.mine.secrets + trade.theirs.secrets > 0 and not trade.secret then
        trade.secret = true
        count(stats(), "tradeSecret")
    end
    local text = sideText("mine", trade.mine) .. " | " .. sideText("partner", trade.theirs)
    Probe:LogOnce(V11, text, why .. " | " .. text)
end

local function finishTrade(t)
    if not t or t.done then
        return
    end
    t.done = true
    local st = stats()
    local outcome = (t.complete and "completed") or ((t.cancelMessage or t.requestCancel) and "cancelled") or "unknown"
    if outcome == "completed" then
        count(st, "tradeCompleted")
    elseif outcome == "cancelled" then
        count(st, "tradeCancelled")
    else
        count(st, "tradeUnknown")
        if t.bothAccepted then
            count(st, "completedNoMessage")
        end
    end
    local mine, theirs = t.mine or {}, t.theirs or {}
    Probe:Log(V11, string.format("trade %s: both accepted %s, TRADE_COMPLETE message %s, cancel message %s, "
        .. "TRADE_REQUEST_CANCEL %s, bilateral %s, partner level %s", outcome, tostring(t.bothAccepted == true),
        tostring(t.complete == true), tostring(t.cancelMessage == true), tostring(t.requestCancel == true),
        tostring(mine.gives == true and theirs.gives == true), t.level or "-"))
    touch()
end

local function onTradeShow()
    if trade and trade.closed then
        finishTrade(trade)
    end
    trade = {}
    local st = stats()
    count(st, "tradesShown")
    coverHere()
    Probe:Cover(V11, "2C")
    local level = Probe.ReadValue(UnitLevel, "NPC") -- the trade partner's unit token
    trade.level = level
    if (tonumber(level) or 0) > 0 then
        st.partnerLevel = 1
    else
        count(st, "partnerLevelBad")
    end
    Probe:Log(V11, string.format("TRADE_SHOW | partner exists=%s isPlayer=%s level=%s own level=%s",
        Probe.BoolText(UnitExists, "NPC"), Probe.BoolText(UnitIsPlayer, "NPC"), level,
        Probe.ReadValue(UnitLevel, "player")))
    readTrade("TRADE_SHOW")
end

local function onTradeEvent(event, a, b)
    if event == "TRADE_SHOW" then
        onTradeShow()
        return
    end
    if not trade then
        return
    end
    if event == "TRADE_ACCEPT_UPDATE" then
        if not IsSecret(a) and not IsSecret(b) and a == 1 and b == 1 then
            trade.bothAccepted = true
        end
        Probe:Log(V11, string.format("TRADE_ACCEPT_UPDATE playerAccepted=%s targetAccepted=%s", Value(a), Value(b)))
        readTrade(event)
    elseif event == "TRADE_REQUEST_CANCEL" then
        trade.requestCancel = true
        Probe:Log(V11, event)
    elseif event == "TRADE_CLOSED" then
        Probe:LogOnce(V11, event .. (trade.closed and "again" or ""),
            event .. (trade.closed and " (again for the same trade)" or ""))
        if not trade.closed then
            trade.closed = true
            local mine = trade
            Probe.After(TRADE_SETTLE, function()
                finishTrade(mine)
            end)
        end
    else
        local slot = Value(a)
        readTrade(event .. (slot ~= "nil" and (" slot " .. slot) or ""))
    end
end

--- The line that confirms (or cancels) a trade, from whichever message event carries it.
local function onMessage(event, a, b)
    if not trade or trade.done then
        return
    end
    local message = a
    if event ~= "CHAT_MSG_SYSTEM" then
        message = b
    end
    if IsSecret(message) then
        count(stats(), "messageSecret")
        return
    end
    for _, name in ipairs(TRADE_MESSAGES) do
        if Probe.MatchGlobal(message, name) then
            if name == "ERR_TRADE_COMPLETE" then
                trade.complete = true
            else
                trade.cancelMessage = true
            end
            Probe:Log(V11, string.format("%s received by %s%s", name, event,
                trade.closed and " after TRADE_CLOSED" or ""))
        end
    end
end

evaluate = function()
    local st = stats()
    local problems = {}
    local function problem(key, text)
        if (st[key] or 0) > 0 then
            problems[#problems + 1] = text .. " x" .. st[key]
        end
    end
    problem("invoiceSecret", "invoice values secret")
    problem("sellerNoBuyer", "seller invoice without a buyer")
    problem("tradeSecret", "trade contents secret")
    problem("completedNoMessage", "trade accepted by both with no confirming message")
    problem("partnerLevelBad", "trade partner level unreadable")
    local summary = string.format("auction house opened %d (created %d); invoices %s; trades %d: completed %d, cancelled "
        .. "%d, unknown %d; partner level read %s", st.ahShown or 0, st.auctionsCreated or 0, TallyText(st.invoices),
        st.tradesShown or 0, st.tradeCompleted or 0, st.tradeCancelled or 0, st.tradeUnknown or 0,
        st.partnerLevel and "yes" or "no")
    local missing = Probe:Missing(V11)
    if (st.ahShown or 0) == 0 then
        missing[#missing + 1] = "an auction house"
    end
    if not st.sellerItem then
        missing[#missing + 1] = "a seller invoice with buyer and item"
    end
    if (st.tradeCompleted or 0) == 0 then
        missing[#missing + 1] = "a completed trade"
    end
    if (st.tradeCancelled or 0) == 0 then
        missing[#missing + 1] = "a cancelled trade"
    end
    return Probe.Verdict(problems, missing, summary)
end

Probe:Watch({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_AUCTION_CREATED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "MAIL_SHOW",
    "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED",
    "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE", "TRADE_REQUEST_CANCEL", "TRADE_CLOSED", "UI_INFO_MESSAGE",
    "UI_ERROR_MESSAGE", "CHAT_MSG_SYSTEM" }, function(event, ...)
    if event == "UI_INFO_MESSAGE" or event == "UI_ERROR_MESSAGE" or event == "CHAT_MSG_SYSTEM" then
        onMessage(event, ...)
    elseif event:sub(1, 6) == "TRADE_" then
        onTradeEvent(event, ...)
    elseif event:sub(1, 5) == "MAIL_" then
        onMail(event)
    elseif event:sub(1, 19) == "PLAYER_INTERACTION_" then
        onInteraction(event, ...)
    else
        onAuction(event, ...)
    end
end)

Probe:Implement(V11, function(probe)
    probe:Log(V11, "run | " .. auctionApi() .. " | " .. ownedText())
    if mailOpen then
        readInbox("run")
    else
        probe:Log(V11, "run | mailbox closed: open it (and the invoice mail) to read the invoices")
    end
    readTrade("run")
    return evaluate()
end)
