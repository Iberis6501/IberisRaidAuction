-- IberisRaidAuction: namespace + 부팅 + SavedVariables + 슬래시
IberisRaidAuction = IberisRaidAuction or {}
local IA = IberisRaidAuction

IA.name = "IberisRaidAuction"
IA.version = (C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata)("IberisRaidAuction", "Version") or "0.0"
IA.modules = IA.modules or {}
IA.ui = IA.ui or {}

local function ensureDB()
    IberisRaidAuctionDB = IberisRaidAuctionDB or {}
    IberisRaidAuctionDB.ledger   = IberisRaidAuctionDB.ledger   or {}   -- {time, player, link, count, quality, gold}
    IberisRaidAuctionDB.bidders  = IberisRaidAuctionDB.bidders  or {}   -- name -> count
    IberisRaidAuctionDB.settings = IberisRaidAuctionDB.settings or {}
    local s = IberisRaidAuctionDB.settings
    if s.minQuality   == nil then s.minQuality   = 3 end        -- 0=poor 4=epic
    if s.widgetPos    == nil then s.widgetPos    = nil end
    if s.ledgerPos    == nil then s.ledgerPos    = nil end
    if s.ledgerShown  == nil then s.ledgerShown  = false end
    if s.widgetHidden == nil then s.widgetHidden = false end

    IberisRaidAuctionCharDB = IberisRaidAuctionCharDB or {}
    IA.db     = IberisRaidAuctionDB
    IA.charDB = IberisRaidAuctionCharDB
end

SLASH_IBERISRAIDAUCTION1 = "/ira"
SLASH_IBERISRAIDAUCTION2 = "/iberisraidauction"
SlashCmdList.IBERISRAIDAUCTION = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""
    if msg == "" or msg == "toggle" then
        if IA.ui.Ledger then IA.ui.Ledger:Toggle() end
    elseif msg == "show" then
        if IA.ui.Ledger then IA.ui.Ledger:Show() end
    elseif msg == "hide" then
        if IA.ui.Ledger then IA.ui.Ledger:Hide() end
    elseif msg == "widget" then
        if IA.ui.Widget then IA.ui.Widget:Toggle() end
    elseif msg == "clear" then
        wipe(IberisRaidAuctionDB.ledger)
        wipe(IberisRaidAuctionDB.bidders)
        if IA.ui.Ledger and IA.ui.Ledger.Refresh then IA.ui.Ledger:Refresh() end
        print("|cff91d7f2[IberisRaidAuction]|r 장부/낙찰자 초기화")
    else
        print("|cff91d7f2[IberisRaidAuction]|r 사용: /ia (toggle), /ia widget, /ia clear")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == "IberisRaidAuction" then
        ensureDB()
        for _, m in pairs(IA.modules) do
            if m.OnLoaded then m:OnLoaded() end
        end
        for _, u in pairs(IA.ui) do
            if u.OnLoaded then u:OnLoaded() end
        end
    elseif event == "PLAYER_LOGIN" then
        print(string.format("|cff91d7f2[IberisRaidAuction v%s]|r /ia 로 장부 열기", tostring(IA.version)))
        for _, m in pairs(IA.modules) do
            if m.OnLogin then m:OnLogin() end
        end
        for _, u in pairs(IA.ui) do
            if u.OnLogin then u:OnLogin() end
        end
    end
end)
