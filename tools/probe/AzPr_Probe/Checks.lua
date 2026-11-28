-- AzPr Probe: the check registry (V1-V21 and L); steps M0.3-M0.7 give every check its code.
-- Adapted from Azeroth Accord (the stub table of tools/probe/AzAc_Probe/AzAc_Probe.lua), same owner, GPL-3.0 (ADR 0013).
-- Ids, areas and required contexts come from docs/spike/README.md. The Checks_<area>.lua files, listed in the TOC after
-- this one, give the checks their code with Probe:Implement(id, fn).

local Probe = _G.AzPr_Probe
if not Probe then
    return
end

-- { id, step that implements it, required contexts, short description }
local CHECKS = {
    { "V1", "M0.3", "DB RB LS", "ENCOUNTER_END and BOSS_KILL with readable values" },
    { "V2", "M0.4", "W WC D DB R BG", "Player identity on nameplates and tooltips" },
    { "V3", "M0.4", "W WC D DB R BG", "Nameplates: forbidden or not, anchored texture, taint" },
    { "V4", "M0.5", "W D BG 2C 2CX", "Addon messages on a custom channel, size and throttle" },
    { "V5", "M0.5", "W WC D DB R RB BG LS 2C", "When AddOnMessageLockdown applies" },
    { "V6", "M0.6", "W D", "Quest turn-in and completed quests" },
    { "V7", "M0.6", "W", "Legacy system data source" },
    { "V8", "M0.6", "W BG 2C", "Honour, battlegrounds and duels" },
    { "V9", "M0.6", "W D", "Exploration and flight paths" },
    { "V10", "M0.6", "W", "Professions, skill-ups and recipes" },
    { "V11", "M0.6", "W 2C", "Auction House, mail invoices and trades" },
    { "V12", "M0.4", "W WC D DB BG", "Chat message filters" },
    { "V13", "M0.4", "W WC D BG", "Unit tooltip and unit menu" },
    { "V14", "M0.5", "W WC 2C", "C_EncodingUtil round trips" },
    { "V15", "M0.7", "W LS", "Interactions, transports, cinematics, calendar" },
    { "V16", "M0.7", "W", "A CVar that forces the restrictions" },
    { "V17", "M0.7", "W HC", "Hardcore realm and permanent death" },
    { "V18", "M0.6", "BG", "Battleground scoreboard" },
    { "V19", "M0.3", "W D R BG", "UnitLevel of group members and far higher hostile players" },
    { "V20", "M0.3", "W WC D DB 2C", "sourceUnit of the auras on the player" },
    { "V21", "M0.3", "W WC D 2C", "nameplateNtarget and targettarget comparisons" },
    { "L", "M0.6", "W DB RB", "Content levels of bosses, quests and zones" },
}

for _, check in ipairs(CHECKS) do
    local contexts = {}
    for tag in check[3]:gmatch("%S+") do
        contexts[#contexts + 1] = tag
    end
    Probe:Register(check[1], check[4], contexts, check[2])
end
