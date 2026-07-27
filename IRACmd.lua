local _, ADDONSELF = ...

local L = ADDONSELF.L
local GUI = ADDONSELF.gui
local Database = ADDONSELF.db
local Print = ADDONSELF.print
local deformat = ADDONSELF.deformat
local RegEvent = ADDONSELF.regevent

local function IberisRaidAuctionSyncBlocksEdits()
    local s = ADDONSELF.sync
    return s and IsInRaid() and s.enabled and not s:IsLedgerEditor()
end

--- 품질 기준 미달: 채팅 대신 화면 상단 토스트(채팅은 잘 안 볼 때)
local function ToastLedgerQualityReject(titleTag)
    local body = "|cffff9933" .. (titleTag or "[IberisRaidAuction]") .. "|r\n|cffffffff희귀(파랑) 이상, 또는 녹색(고급) 도안·제작법만 장부에 넣을 수 있습니다.|r\n|cffffffff채팅 자동 수집(고급+ 기준)과 동일합니다.|r"
    if ADDONSELF.showToast then
        ADDONSELF.showToast(body, 4.5, "danger")
    else
        Print((titleTag or "[IberisRaidAuction]") .. " 희귀(파랑) 이상, 또는 녹색(고급) 도안·제작법만 장부에 넣을 수 있습니다.")
    end
end

local function ToastManualItemAddedOk(itemLink)
    if ADDONSELF.showToast then
        ADDONSELF.showToast("|cFF88FF88[+아이템]|r\n|cffffffff" .. L["Toast manual item added note"] .. "|r\n" .. itemLink, 5, "success")
    else
        Print("|cFF00FF00[+아이템]|r " .. itemLink)
    end
end

local function ToastIberisRaidAuctionItemAddedOk(itemLink)
    if ADDONSELF.showToast then
        ADDONSELF.showToast("|cFF88FF88[IberisRaidAuction]|r\n|cffffffff" .. L["Toast manual item added note"] .. "|r\n" .. itemLink, 5, "success")
    else
        Print(L["Item added"] .. " " .. itemLink)
    end
end

--- 거래 완료 후 `ApplyPlayerToTargetTradeSnap` 성공 시 (판매·구매·마력추출 인계·득자 갱신)
local function ToastTradeLedgerApplied(snap, code)
    if not ADDONSELF.showToast or not snap or not code or code == "" then
        return
    end
    local item = snap.item or ""
    local name = snap.name or "?"
    local money = math.floor(tonumber(snap.money) or 0)
    local body
    if code == "trade_purchase" then
        body = "|cFF88FF88[IberisRaidAuction]|r\n|cffffffff" .. L["Toast trade ledger purchase"] .. "|r\n" .. item .. "\n|cffffffff" .. string.format(L["Toast trade ledger gold and beneficiary"], money, name) .. "|r"
    elseif code == "trade_sale_add" or code == "trade_sale_merge" then
        body = "|cFF88FF88[IberisRaidAuction]|r\n|cffffffff" .. L["Toast trade ledger sale"] .. "|r\n" .. item .. "\n|cffffffff" .. string.format(L["Toast trade ledger buyer gold"], name, money) .. "|r"
    elseif code == "trade_de_add" then
        body = "|cFF88FF88[IberisRaidAuction]|r\n|cffffffff" .. L["Toast trade ledger de add"] .. "|r\n" .. item
    elseif code == "trade_de_retarget" then
        body = "|cFF88FF88[IberisRaidAuction]|r\n|cffffffff" .. L["Toast trade ledger de retarget"] .. "|r\n" .. item
    elseif code == "trade_beneficiary_retarget" then
        body = "|cFF88FF88[IberisRaidAuction]|r\n|cffffffff" .. L["Toast trade ledger beneficiary retarget"] .. "|r\n" .. item .. "\n|cffffffff" .. string.format(L["Toast trade ledger new beneficiary"], name) .. "|r"
    end
    if body then
        ADDONSELF.showToast(body, 5.5, "success")
    end
end

-- SetItemRef는 비활성화하여 가방 클릭과 중복 방지
-- hooksecurefunc("SetItemRef", function(link)
--     -- 에러 처리: GUI가 초기화되지 않았을 경우
--     if not GUI or not GUI.mainframe then
--         return
--     end

--     if GUI.mainframe:IsShown() and IsControlKeyDown() then
--         -- 입력 검증: 링크가 유효한지 확인
--         if not link or link == "" then
--             return
--         end

--         local success, linkType, target = pcall(strsplit, ":", link)
--         if not success then
--             Print("Invalid link format")
--             return
--         end

--         if linkType == "item" then
--             local success, itemLink = pcall(GetItemInfo, target)
--             if success and itemLink then
--                 Print(L["Item added"] .. " " .. itemLink)
--                 Database:AddLoot(itemLink, 1, "", 0, true)
--             else
--                 Print("Failed to get item information")
--             end
--         elseif linkType == "player" then
--             local success, playerName = pcall(strsplit, "-", target)
--             if success and playerName then
--                 Print(L["Compensation added"] .. " " .. playerName)
--                 Database:AddDebit("", playerName)
--             else
--                 Print("Invalid player name format")
--             end
--         end
--     end
-- end)

-- +아이템: 가방·HandleModifiedItemClick 등에서 같은 링크가 연달아 올 수 있어 짧게 중복 억제
local iraManualItemDedupeKey, iraManualItemDedupeT = "", 0
local function ShouldSkipManualItemDedupe(itemKey)
    if not itemKey or itemKey == "" then return false end
    local t = GetTime()
    if itemKey == iraManualItemDedupeKey and (t - iraManualItemDedupeT) < 0.4 then
        return true
    end
    iraManualItemDedupeKey = itemKey
    iraManualItemDedupeT = t
    return false
end

local function GetBagSlotItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
    return nil
end

--- SetItemRef의 link/text로 하이퍼링크 복원 (AtlasLoot·채팅 등에서 text 가 비는 경우 포함)
local function ResolveItemHyperlinkForManualAdd(link, text)
    if text and type(text) == "string" and strfind(text, "|Hitem:%d+") then
        return text
    end
    if not link or type(link) ~= "string" then
        return nil
    end
    local id = tonumber(strmatch(link, "^item:(%d+)") or strmatch(link, "item:(%d+)"))
    if not id then
        return nil
    end
    local itemName, itemLink = GetItemInfo(id)
    if itemLink and itemLink ~= "" then
        return itemLink
    end
    itemName = (itemName and itemName ~= "") and itemName or "?"
    itemName = itemName:gsub("%]", "")
    return string.format("|cffffffff|Hitem:%d::::::::60:::::|h[%s]|h|r", id, itemName)
end

local function TryManualAddFromItemHyperlink(itemLink)
    if not GUI or not itemLink or itemLink == "" then
        return
    end
    local dedupeId = strmatch(itemLink, "item:(%d+)")
    if not dedupeId then
        return
    end
    if ShouldSkipManualItemDedupe(dedupeId) then
        return
    end
    if IberisRaidAuctionSyncBlocksEdits() then
        if GUI.SetManualItemWaiting then
            GUI.SetManualItemWaiting(false)
        end
        if ADDONSELF.showToast then
            ADDONSELF.showToast("|cffff3333[+아이템]|r\n|cffffffff" .. L["Toast manual item no edit raid"] .. "|r", 4.5, "danger")
        else
            Print("|cFFFF3333[+아이템]|r " .. L["Toast manual item no edit raid"])
        end
        return
    end

    if not ADDONSELF.ItemPassesLedgerPickupQualityRules(itemLink) then
        if GUI.SetManualItemWaiting then
            GUI.SetManualItemWaiting(false)
        end
        ToastLedgerQualityReject("[+아이템]")
        return
    end
    if GUI.SetManualItemWaiting then
        GUI.SetManualItemWaiting(false)
    end
    local ok = Database:AddLoot(itemLink, 1, "", 0, false)
    if ok then
        ToastManualItemAddedOk(itemLink)
    else
        if GUI.SetManualItemWaiting then
            GUI.SetManualItemWaiting(true)
        end
        if ADDONSELF.showToast then
            ADDONSELF.showToast("|cffff9900[+아이템]|r\n|cffffffff" .. L["Toast manual item add failed"] .. "|r", 5, "warn")
        else
            Print("|cFFFF9900[+아이템]|r " .. L["Toast manual item add failed"])
        end
    end
end

-- 본섭(신 컨테이너 UI)은 ContainerFrameItemButton_OnModifiedClick가 삭제됨.
-- 가방 클릭 연동은 클래식 계열 전용 — 본섭에서는 하이퍼링크(SetItemRef) 경로만 동작.
if type(ContainerFrameItemButton_OnModifiedClick) == "function" then
hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    if button ~= "LeftButton" then return end

    if GUI and GUI.waitingForManualItem then
        if not IsShiftKeyDown() then
            return
        end
        local bag = self:GetParent():GetID()
        local slot = self:GetID()
        local itemLink = GetBagSlotItemLink(bag, slot)
        if itemLink then
            TryManualAddFromItemHyperlink(itemLink)
        end
        return
    end

    -- 기존 Ctrl+클릭 (IberisRaidAuction 창이 열려있을 때)
    if GUI and GUI.mainframe and GUI.mainframe:IsShown() and IsControlKeyDown() then
        if IberisRaidAuctionSyncBlocksEdits() then return end
        local bag = self:GetParent():GetID()
        local slot = self:GetID()
        local itemLink = GetBagSlotItemLink(bag, slot)
        if itemLink then
            if not ADDONSELF.ItemPassesLedgerPickupQualityRules(itemLink) then
                ToastLedgerQualityReject("[IberisRaidAuction]")
                return
            end
            if Database:AddLoot(itemLink, 1, "", 0, false) then
                ToastIberisRaidAuctionItemAddedOk(itemLink)
            end
        end
    end
end)
end

-- +아이템: 채팅·AtlasLoot 등 아이템 하이퍼링크 (Shift+좌클릭)
hooksecurefunc("SetItemRef", function(link, text, button)
    if not GUI or not GUI.waitingForManualItem or not link then
        return
    end
    if button and button ~= "LeftButton" then
        return
    end
    if not IsShiftKeyDown() then
        return
    end
    if strsplit(":", link) ~= "item" then
        return
    end
    local h = ResolveItemHyperlinkForManualAdd(link, text)
    if h then
        TryManualAddFromItemHyperlink(h)
    end
end)

-- +아이템: AtlasLoot 등에서 item 링크로 HandleModifiedItemClick 이 오는 경우 (Shift+클릭과 동일 조건)
hooksecurefunc("HandleModifiedItemClick", function(itemLink)
    if not GUI or not GUI.waitingForManualItem or not itemLink then
        return
    end
    if not IsShiftKeyDown() then
        return
    end
    if type(itemLink) ~= "string" or not strfind(itemLink, "item:%d+") then
        return
    end
    TryManualAddFromItemHyperlink(itemLink)
end)


 
local ls_targetName = ""
local ll_targetMoney = 0
local playerItem = ""
local targetItem = ""
-- 내 거래창에 올린 아이템 수량(스택)
local lastPlayerTradeNumItems = 1
-- 거래 완료 시점에는 창이 비어 playerItem이 지워지는 경우가 있어, 마지막 유효 상태를 보관
local pendingTradeSnapshot = nil
-- 동일 거래에 완료 이벤트가 여러 번 올 때 공대 멘트 중복 방지
local lastTradeNotifyItem, lastTradeNotifyTime = "", 0
-- 거래 직후 CHAT_MSG_LOOT(획득 채팅)이 같은 아이템으로 한 줄 더 들어가는 것 방지 [id]=만료시각
local tradeLootChatIgnoreIds = {}

local function armTradeLootChatIgnore(itemLink, holdSec)
  holdSec = holdSec or 12
  local id = itemLink and tonumber(itemLink:match("item:(%d+)"))
  if not id then return end
  local exp = GetTime() + holdSec
  tradeLootChatIgnoreIds[id] = exp
  C_Timer.After(holdSec + 1, function()
    if tradeLootChatIgnoreIds[id] == exp then
      tradeLootChatIgnoreIds[id] = nil
    end
  end)
end


local AUTOADDLOOT_TYPE_ALL = 0
-- local AUTOADDLOOT_TYPE_PARTY = 1
local AUTOADDLOOT_TYPE_RAID = 1
local AUTOADDLOOT_TYPE_DISABLE = 2

-- AutoAddLoot is now accessed through ADDONSELF.cli.AutoAddLoot for GUI synchronization
local AutoAddLoot = AUTOADDLOOT_TYPE_DISABLE

-- Expose AutoAddLoot to GUI through ADDONSELF namespace
if not ADDONSELF.cli then
    ADDONSELF.cli = {}
end
ADDONSELF.cli.AutoAddLoot = AutoAddLoot

-- Function to sync AutoAddLoot from database to local
local function SyncAutoAddLootFromDB()
    AutoAddLoot = Database:GetConfigOrDefault("autoaddloot", AUTOADDLOOT_TYPE_RAID)
    ADDONSELF.cli.AutoAddLoot = AutoAddLoot
end

local merchantTrackingActive = false
local merchantTrackingMoneyBaseline = nil

local function refreshMerchantMoneyBaseline()
    if merchantTrackingActive and type(GetMoney) == "function" then
        merchantTrackingMoneyBaseline = math.floor(tonumber(GetMoney()) or 0)
    else
        merchantTrackingMoneyBaseline = nil
    end
end

local function ExtractMoneyCopperFromChatMessage(chatmsg)
    if type(chatmsg) ~= "string" or chatmsg == "" then
        return 0
    end

    local patterns = {
        _G.YOU_LOOT_MONEY,
        _G.LOOT_MONEY_SPLIT,
        _G.YOU_LOOT_MONEY_GUILD,
        _G.LOOT_MONEY_SPLIT_GUILD,
    }

    for _, pattern in ipairs(patterns) do
        if pattern and pattern ~= "" then
            local gold, silver, copper = deformat(chatmsg, pattern)
            gold = tonumber(gold) or 0
            silver = tonumber(silver) or 0
            copper = tonumber(copper) or 0
            local totalCopper = gold * 10000 + silver * 100 + copper
            if totalCopper > 0 then
                return totalCopper
            end
        end
    end

    -- Fallback for clients/messages where deformat misses because one or more
    -- denominations are omitted, bonus text is appended, or locale wording differs.
    local cleaned = tostring(chatmsg)
    cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x", "")
    cleaned = cleaned:gsub("|r", "")
    cleaned = cleaned:gsub("|T.-|t", " ")
    cleaned = cleaned:gsub("|H.-|h(.-)|h", "%1")

    local function readAmount(pattern)
        local raw = cleaned:match(pattern)
        if not raw then
            return 0
        end
        raw = tostring(raw):gsub(",", "")
        return tonumber(raw) or 0
    end

    local gold = math.max(
        readAmount("([%d,]+)%s*골드"),
        readAmount("([%d,]+)%s*골"),
        readAmount("([%d,]+)%s*[Gg]old"),
        readAmount("([%d,]+)%s*[Gg]$")
    )
    local silver = math.max(
        readAmount("([%d,]+)%s*실버"),
        readAmount("([%d,]+)%s*은"),
        readAmount("([%d,]+)%s*[Ss]ilver"),
        readAmount("([%d,]+)%s*[Ss]$")
    )
    local copper = math.max(
        readAmount("([%d,]+)%s*코퍼"),
        readAmount("([%d,]+)%s*동"),
        readAmount("([%d,]+)%s*[Cc]opper"),
        readAmount("([%d,]+)%s*[Cc]$")
    )

    local totalCopper = gold * 10000 + silver * 100 + copper
    if totalCopper > 0 then
        return totalCopper
    end

    return 0
end

RegEvent("CHAT_MSG_LOOT", function(chatmsg)
    -- Sync from database to ensure we have the latest value
    SyncAutoAddLootFromDB()

    if AutoAddLoot == AUTOADDLOOT_TYPE_DISABLE then
        return
    elseif UnitInBattleground("player") then
        return
    elseif AutoAddLoot == AUTOADDLOOT_TYPE_RAID and not IsInRaid() then
        return
    end

    do
        local s = ADDONSELF.sync
        if s and IsInRaid() and s.enabled and not s:IsLedgerEditor() then
            return
        end
    end

    local playerName, itemLink, itemCount = deformat(chatmsg, LOOT_ITEM_MULTIPLE);
    -- next try: somebody else received single loot
    if (playerName == nil) then
        itemCount = 1;
        playerName, itemLink = deformat(chatmsg, LOOT_ITEM);
    end
    -- if player == nil, then next try: player received multiple loot
    if (playerName == nil) then
        playerName = UnitName("player");
        itemLink, itemCount = deformat(chatmsg, LOOT_ITEM_SELF_MULTIPLE);
    end
    -- if itemLink == nil, then last try: player received single loot
    if (itemLink == nil) then
        itemCount = 1;
        itemLink = deformat(chatmsg, LOOT_ITEM_SELF);
    end
    -- if itemLink == nil, then there was neither a LOOT_ITEM, nor a LOOT_ITEM_SELF message
    if (itemLink == nil) then
        -- MRT_Debug("No valid loot event received.");
        return;
    end

    do
        local id = tonumber(itemLink:match("item:(%d+)"))
        local exp = id and tradeLootChatIgnoreIds[id]
        if exp and GetTime() <= exp then
            return
        end
    end

    -- if code reaches this point, we should have a valid looter and a valid itemLink
    for _ = 1, itemCount do
        Database:AddLoot(itemLink, 1, playerName, 0);
    end
end)

RegEvent("CHAT_MSG_MONEY", function(chatmsg)
    local copper = ExtractMoneyCopperFromChatMessage(chatmsg)
    if copper <= 0 then
        return
    end
    Database:AddRaidLootMoneyCopper(copper)
    if GUI and GUI.mainframe and GUI.mainframe:IsShown() and GUI.UpdateSummary then
        GUI:UpdateSummary()
    end
end)

RegEvent("MERCHANT_SHOW", function()
    merchantTrackingActive = true
    refreshMerchantMoneyBaseline()
end)

RegEvent("MERCHANT_CLOSED", function()
    merchantTrackingActive = false
    merchantTrackingMoneyBaseline = nil
end)

RegEvent("PLAYER_MONEY", function()
    if not merchantTrackingActive or merchantTrackingMoneyBaseline == nil or type(GetMoney) ~= "function" then
        return
    end
    local nowMoney = math.floor(tonumber(GetMoney()) or 0)
    local delta = nowMoney - merchantTrackingMoneyBaseline
    if delta ~= 0 then
        Database:AddMerchantMoneyDeltaCopper(delta)
        merchantTrackingMoneyBaseline = nowMoney
        if GUI and GUI.mainframe and GUI.mainframe:IsShown() and GUI.UpdateSummary then
            GUI:UpdateSummary()
        end
    end
end)

RegEvent("ADDON_LOADED", function()
    AutoAddLoot = Database:GetConfigOrDefault("autoaddloot", AUTOADDLOOT_TYPE_RAID)
    ADDONSELF.cli.AutoAddLoot = AutoAddLoot

    local ldb = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)

    if not ldb or not icon then
        return
    end

    -- 미니맵 아이콘 데이터베이스 설정
    local minimapDB = Database:GetConfig("minimapicons")
    if not minimapDB then
        minimapDB = { hide = false }
        Database:SetConfig("minimapicons", minimapDB)
    end
    minimapDB.hide = not Database:GetConfigOrDefault("minimapicon", true)

    -- 누적 수익 (골드 단위, 천단위 콤마)
    local function formatGoldComma(g)
        local s = tostring(math.floor(g or 0))
        while true do
            local k
            s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
            if k == 0 then break end
        end
        return s
    end
    local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
    local function formatRevenueText()
        local prefix = "IRA : "
        local ledger = Database and Database:GetCurrentLedger()
        if not ledger or not ledger.items or not ADDONSELF.calcavg then
            return prefix .. "0" .. GOLD_ICON
        end
        local profit = ADDONSELF.calcavg(ledger.items, 1, nil, nil, true)
        return prefix .. formatGoldComma(profit) .. GOLD_ICON
    end

    local dataObject = ldb:NewDataObject("IberisRaidAuction", {
        type  = "data source",
        text  = formatRevenueText(),
        label = "IberisRaidAuction",
        icon  = "Interface\\Icons\\INV_Misc_Coin_01",
        OnClick = function(self, button)
            if button == "LeftButton" then
                if GUI.mainframe and GUI.mainframe:IsShown() then
                    GUI.mainframe:Hide()
                elseif GUI.mainframe then
                    GUI.mainframe:Show()
                end
            elseif button == "RightButton" then
                local settingsShown = (SettingsPanel and SettingsPanel:IsShown())
                                   or (InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown())
                if settingsShown then
                    if SettingsPanel and SettingsPanel:IsShown() then
                        HideUIPanel(SettingsPanel)
                    elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
                        InterfaceOptionsFrame:Hide()
                    end
                else
                    if ADDONSELF._settingsPanel then
                        if Settings and Settings.OpenToCategory then
                            Settings.OpenToCategory(ADDONSELF._settingsCategoryID)
                        elseif InterfaceOptionsFrame_OpenToCategory then
                            InterfaceOptionsFrame_OpenToCategory(ADDONSELF._settingsPanel)
                            InterfaceOptionsFrame_OpenToCategory(ADDONSELF._settingsPanel)
                        end
                    end
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cff91d7f2IberisRaidAuction|r")
            tooltip:AddLine(" ")
            local ok, profit, avg, revenue, expense = pcall(function() return GUI:Summary() end)
            if ok and revenue then
                local ledger = Database:GetCurrentLedger()
                local manualRevenue = 0
                for _, item in pairs(ledger.items or {}) do
                    if item.type == "CREDIT" and item.cost and item.cost > 0
                            and (item.costtype == nil or item.costtype == "GOLD")
                            and not (item.detail and item.detail.item) then
                        manualRevenue = manualRevenue + item.cost
                    end
                end
                local autoRevenue  = (revenue or 0) - manualRevenue
                local distribution = profit or 0
                local function fmt(g) return formatGoldComma(g) .. "골드" end
                tooltip:AddDoubleLine("총수익",   fmt(autoRevenue),       1,1,1, 1,1,1)
                tooltip:AddDoubleLine("+수익",    "+" .. fmt(manualRevenue), 1,1,1, 0.6,1,0.6)
                tooltip:AddDoubleLine("-지출",    "-" .. fmt(expense or 0),  1,1,1, 1,0.7,0.7)
                tooltip:AddDoubleLine("총분배금", fmt(distribution),       1,1,1, 1,0.82,0)
                tooltip:AddDoubleLine("인당",     fmt(avg or 0),           1,1,1, 0.6,0.85,1)
            end
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffff00좌클릭|r 경매창", 1, 1, 1)
            tooltip:AddLine("|cffffff00우클릭|r 설정창", 1, 1, 1)
        end,
    })

    icon:Register("IberisRaidAuction", dataObject, minimapDB)

    -- 데이터 변경 시 LDB text 갱신
    if Database.RegisterChangeCallback then
        Database:RegisterChangeCallback(function()
            dataObject.text = formatRevenueText()
        end)
    end

    -- 게임 진입/리로드 직후 한 번 더 (다른 애드온 SavedVariables 로드 후 보장)
    local refreshFrame = CreateFrame("Frame")
    refreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    refreshFrame:SetScript("OnEvent", function()
        dataObject.text = formatRevenueText()
    end)

    -- 설정 패널 등록
    local panel = CreateFrame("Frame")
    panel.name = "IberisRaidAuction"

    -- ElvUI 톤 백드롭 (다크 평면 + 1px 보더)
    if BackdropTemplateMixin then
        Mixin(panel, BackdropTemplateMixin)
        panel:HookScript("OnSizeChanged", panel.OnBackdropSizeChanged)
    end
    if ADDONSELF.theme and ADDONSELF.theme.ApplyFrame then
        ADDONSELF.theme:ApplyFrame(panel)
    end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local iraVer = (ADDONSELF.GetAddOnVersion and ADDONSELF.GetAddOnVersion()) or "1.00"
    title:SetText("IberisRaidAuction Ver. " .. iraVer)

    -- 섹션 구분 가로줄 헬퍼
    local function makeDivider(aboveAnchor)
        local div = panel:CreateTexture(nil, "ARTWORK")
        div:SetColorTexture(0.4, 0.4, 0.4, 0.5)
        div:SetHeight(1)
        div:SetPoint("LEFT", panel, "LEFT", 16, 0)
        div:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
        div:SetPoint("BOTTOM", aboveAnchor, "TOP", 0, 6)
        return div
    end

    -- ====== 카운트다운 메시지 편집 UI (scroll 바로 아래) ======
    local CD_DEFAULTS = { count = "--- %d", closed = "--- 입찰 마감 ---", resume = "--- 신규 입찰 ! 재개합니다 ---" }

    local cdHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cdHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
    cdHeader:SetText("카운트다운 메시지")
    makeDivider(cdHeader)

    local cdHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cdHint:SetPoint("TOPLEFT", cdHeader, "BOTTOMLEFT", 0, -4)
    cdHint:SetWidth(560); cdHint:SetJustifyH("LEFT")
    cdHint:SetText("|cff909090경매 카운트다운 시 공격대 채팅으로 송신되는 메시지. 카운트 메시지의 %d 가 숫자로 치환됩니다.|r")

    -- 시작 카운트 입력 (임의 숫자, 1~60초)
    local cdStartLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cdStartLbl:SetPoint("TOPLEFT", cdHint, "BOTTOMLEFT", 0, -10)
    cdStartLbl:SetText("시작 카운트:")

    local cdStartEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    cdStartEdit:SetPoint("LEFT", cdStartLbl, "RIGHT", 14, 0)
    cdStartEdit:SetSize(50, 24)
    cdStartEdit:SetAutoFocus(false)
    cdStartEdit:SetNumeric(true)
    cdStartEdit:SetMaxLetters(3)
    cdStartEdit:SetScript("OnEscapePressed", cdStartEdit.ClearFocus)
    local function saveCdStart()
        local n = tonumber(cdStartEdit:GetText()) or 5
        if n < 1 then n = 1 end
        if n > 60 then n = 60 end
        Database:SetGlobalConfig("countdownStartSeconds", n)
        cdStartEdit:SetText(tostring(n))
    end
    cdStartEdit:SetScript("OnEnterPressed", function(self) saveCdStart(); self:ClearFocus() end)
    cdStartEdit:SetScript("OnEditFocusLost", saveCdStart)
    if ADDONSELF.theme and ADDONSELF.theme.ApplyEditBox then
        ADDONSELF.theme:ApplyEditBox(cdStartEdit)
    end

    local cdStartSuffix = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cdStartSuffix:SetPoint("LEFT", cdStartEdit, "RIGHT", 6, 0)
    cdStartSuffix:SetText("초 (1~60)")

    panel:HookScript("OnShow", function()
        cdStartEdit:SetText(tostring(Database:GetGlobalConfigOrDefault("countdownStartSeconds", 5)))
    end)

    local function buildCdRow(anchor, anchorOffsetY, key, labelText)
        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, anchorOffsetY)
        lbl:SetText(labelText)
        lbl:SetWidth(60); lbl:SetJustifyH("LEFT")

        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        edit:SetPoint("LEFT", lbl, "RIGHT", 14, 0)
        edit:SetSize(380, 24)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(200)
        edit:SetScript("OnEscapePressed", edit.ClearFocus)
        local function save()
            local msgs = Database:GetGlobalConfigOrDefault("countdownmessages", CD_DEFAULTS)
            msgs[key] = edit:GetText() or ""
            Database:SetGlobalConfig("countdownmessages", msgs)
        end
        edit:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
        edit:SetScript("OnEditFocusLost", save)
        if ADDONSELF.theme and ADDONSELF.theme.ApplyEditBox then
            ADDONSELF.theme:ApplyEditBox(edit)
        end
        return lbl, edit
    end

    local cdCountLbl,  cdCountEdit  = buildCdRow(cdStartLbl, -20, "count",  "카운트:")
    local cdClosedLbl, cdClosedEdit = buildCdRow(cdCountLbl,  -8, "closed", "마감:")
    local cdResumeLbl, cdResumeEdit = buildCdRow(cdClosedLbl, -8, "resume", "재개:")

    local cdResetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    cdResetBtn:SetPoint("TOPLEFT", cdResumeLbl, "BOTTOMLEFT", 0, -10)
    cdResetBtn:SetSize(110, 22)
    cdResetBtn:SetText("기본값 복원")
    cdResetBtn:SetScript("OnClick", function()
        Database:SetGlobalConfig("countdownmessages", { count = CD_DEFAULTS.count, closed = CD_DEFAULTS.closed, resume = CD_DEFAULTS.resume })
        cdCountEdit:SetText(CD_DEFAULTS.count)
        cdClosedEdit:SetText(CD_DEFAULTS.closed)
        cdResumeEdit:SetText(CD_DEFAULTS.resume)
    end)
    if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
        ADDONSELF.theme:ApplyButton(cdResetBtn)
    end

    local function refreshCdMessages()
        local msgs = Database:GetGlobalConfigOrDefault("countdownmessages", CD_DEFAULTS)
        cdCountEdit:SetText(msgs.count or CD_DEFAULTS.count)
        cdClosedEdit:SetText(msgs.closed or CD_DEFAULTS.closed)
        cdResumeEdit:SetText(msgs.resume or CD_DEFAULTS.resume)
    end
    panel:HookScript("OnShow", refreshCdMessages)

    -- ====== 경매 시작 메시지 편집 UI (스피커 버튼) ======
    local AN_DEFAULTS = { warning = "%s", auction = "=== %s 경매 시작합니다. ===" }

    local anHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    anHeader:SetPoint("TOPLEFT", cdResetBtn, "BOTTOMLEFT", 0, -22)
    anHeader:SetText("경매 시작 메시지")
    makeDivider(anHeader)

    local anHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    anHint:SetPoint("TOPLEFT", anHeader, "BOTTOMLEFT", 0, -4)
    anHint:SetWidth(560); anHint:SetJustifyH("LEFT")
    anHint:SetText("|cff909090스피커 버튼 클릭 시 송신. %s 는 아이템링크로 치환되고 장착정보는 자동으로 뒤에 붙음. 빈칸이면 해당 줄은 보내지 않음.|r")

    local function buildAnRow(anchor, anchorOffsetY, key, labelText)
        local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, anchorOffsetY)
        lbl:SetText(labelText)
        lbl:SetWidth(60); lbl:SetJustifyH("LEFT")

        local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        edit:SetPoint("LEFT", lbl, "RIGHT", 14, 0)
        edit:SetSize(380, 24)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(200)
        edit:SetScript("OnEscapePressed", edit.ClearFocus)
        local function save()
            local msgs = Database:GetGlobalConfigOrDefault("announceMessages", AN_DEFAULTS)
            msgs[key] = edit:GetText() or ""
            Database:SetGlobalConfig("announceMessages", msgs)
        end
        edit:SetScript("OnEnterPressed", function(self) save(); self:ClearFocus() end)
        edit:SetScript("OnEditFocusLost", save)
        if ADDONSELF.theme and ADDONSELF.theme.ApplyEditBox then
            ADDONSELF.theme:ApplyEditBox(edit)
        end
        return lbl, edit
    end

    local anWarnLbl,    anWarnEdit    = buildAnRow(anHint,    -10, "warning", "경고:")
    local anAuctionLbl, anAuctionEdit = buildAnRow(anWarnLbl,  -8, "auction", "채팅:")

    local anResetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    anResetBtn:SetPoint("TOPLEFT", anAuctionLbl, "BOTTOMLEFT", 0, -10)
    anResetBtn:SetSize(110, 22)
    anResetBtn:SetText("기본값 복원")
    anResetBtn:SetScript("OnClick", function()
        Database:SetGlobalConfig("announceMessages", { warning = AN_DEFAULTS.warning, auction = AN_DEFAULTS.auction })
        anWarnEdit:SetText(AN_DEFAULTS.warning)
        anAuctionEdit:SetText(AN_DEFAULTS.auction)
    end)
    if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
        ADDONSELF.theme:ApplyButton(anResetBtn)
    end

    local function refreshAnMessages()
        local msgs = Database:GetGlobalConfigOrDefault("announceMessages", AN_DEFAULTS)
        anWarnEdit:SetText(msgs.warning or AN_DEFAULTS.warning)
        anAuctionEdit:SetText(msgs.auction or AN_DEFAULTS.auction)
    end
    panel:HookScript("OnShow", refreshAnMessages)

    -- ====== autoClear 체크박스 (경매 시작 메시지 reset 아래) ======
    local autoClearCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    autoClearCheck:SetPoint("TOPLEFT", anResetBtn, "BOTTOMLEFT", -6, -18)
    autoClearCheck:SetSize(22, 22)
    makeDivider(autoClearCheck)
    local autoClearLbl = autoClearCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoClearLbl:SetPoint("LEFT", autoClearCheck, "RIGHT", 2, 0)
    autoClearLbl:SetText("공격대 첫 인스턴스 입장 시 장부 초기화 확인 (같은 공대 재입던 / 사망 후 부활은 묻지 않음)")
    autoClearCheck:SetScript("OnClick", function(self)
        Database:SetGlobalConfig("autoClearOnDungeonEnter", self:GetChecked() and true or false)
    end)
    panel:HookScript("OnShow", function()
        autoClearCheck:SetChecked(Database:GetGlobalConfigOrDefault("autoClearOnDungeonEnter", true) and true or false)
    end)

    -- ====== 자동 캡처 블랙리스트 UI (autoClear 아래) ======
    local blHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    blHeader:SetPoint("TOPLEFT", autoClearCheck, "BOTTOMLEFT", 6, -22)
    blHeader:SetText("자동 캡처 차단 목록")
    makeDivider(blHeader)

    local blHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blHint:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", 0, -4)
    blHint:SetWidth(560); blHint:SetJustifyH("LEFT")
    blHint:SetText("|cff909090아이템 이름 부분일치로 차단. 기본값: 폭풍우 요새 켈타스 P4 무기/쐐기 8종.|r")

    local addLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLbl:SetPoint("TOPLEFT", blHint, "BOTTOMLEFT", 0, -8)
    addLbl:SetText("새 항목 추가:")

    local addEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    addEdit:SetPoint("TOPLEFT", addLbl, "BOTTOMLEFT", 8, -6)
    addEdit:SetSize(380, 24)
    addEdit:SetAutoFocus(false)
    addEdit:SetMaxLetters(120)
    addEdit:SetScript("OnEscapePressed", addEdit.ClearFocus)

    if ADDONSELF.theme and ADDONSELF.theme.ApplyEditBox then
        ADDONSELF.theme:ApplyEditBox(addEdit)
    end

    local addBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addBtn:SetPoint("LEFT", addEdit, "RIGHT", 8, 0)
    addBtn:SetSize(60, 22)
    addBtn:SetText("추가")
    if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
        ADDONSELF.theme:ApplyButton(addBtn)
    end

    local listLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listLbl:SetPoint("TOPLEFT", addEdit, "BOTTOMLEFT", -8, -12)
    listLbl:SetText("등록된 아이템:")

    local listBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", listLbl, "BOTTOMLEFT", 6, -4)
    listBg:SetSize(450, 110)
    if ADDONSELF.theme and ADDONSELF.theme.ApplyFrame then
        ADDONSELF.theme:ApplyFrame(listBg)
    else
        listBg:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, tile = false,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        listBg:SetBackdropColor(0, 0, 0, 0.45)
        listBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    local blScrollFrame = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
    blScrollFrame:SetPoint("TOPLEFT", 6, -6)
    blScrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)
    if ADDONSELF.theme and ADDONSELF.theme.ApplyScrollBar then
        ADDONSELF.theme:ApplyScrollBar(blScrollFrame.ScrollBar)
    end

    local blScrollChild = CreateFrame("Frame", nil, blScrollFrame)
    blScrollChild:SetSize(1, 1)
    blScrollFrame:SetScrollChild(blScrollChild)

    -- 행 풀
    local rows = {}
    local ROW_H = 22

    local function ensureRow(i)
        local row = rows[i]
        if row then return row end
        row = CreateFrame("Frame", nil, blScrollChild)
        row:SetSize(400, ROW_H)
        row:SetPoint("TOPLEFT", blScrollChild, "TOPLEFT", 0, -(i - 1) * (ROW_H + 1))

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetTextColor(1, 1, 1)

        row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.del:SetSize(22, 20)
        row.del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.del:SetText("X")
        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(row.del)
        end

        rows[i] = row
        return row
    end

    local function rebuildBlacklist()
        local list = Database:GetItemBlacklist()
        local items = {}
        for entry in pairs(list) do table.insert(items, entry) end
        table.sort(items)

        local count = #items
        blScrollChild:SetHeight(math.max(1, count * (ROW_H + 1)))

        for i = 1, math.max(count, #rows) do
            local row = rows[i]
            local name = items[i]
            if name then
                row = ensureRow(i)
                row.label:SetText(name)
                row.del:SetScript("OnClick", function()
                    local cur = Database:GetItemBlacklist()
                    cur[name] = nil
                    Database:SetItemBlacklist(cur)
                    rebuildBlacklist()
                end)
                row:Show()
            elseif row then
                row:Hide()
            end
        end
    end

    addBtn:SetScript("OnClick", function()
        local v = (addEdit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if v == "" then return end
        local list = Database:GetItemBlacklist()
        list[v] = true
        Database:SetItemBlacklist(list)
        addEdit:SetText("")
        rebuildBlacklist()
    end)
    addEdit:SetScript("OnEnterPressed", function(self)
        addBtn:Click()
        self:ClearFocus()
    end)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", listBg, "BOTTOMLEFT", -6, -8)
    resetBtn:SetSize(110, 22)
    resetBtn:SetText("기본값 복원")
    resetBtn:SetScript("OnClick", function()
        IberisRaidAuctionGlobalConfig = IberisRaidAuctionGlobalConfig or {}
        IberisRaidAuctionGlobalConfig.itemBlacklist = nil
        Database:GetItemBlacklist()  -- 다시 호출하면 기본값 재주입됨
        rebuildBlacklist()
    end)
    if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
        ADDONSELF.theme:ApplyButton(resetBtn)
    end

    panel:HookScript("OnShow", rebuildBlacklist)

    ADDONSELF._settingsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
        ADDONSELF._settingsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)



----------------------------------------------------------------

local function copperToGold(copperAmount)
  return math.floor((tonumber(copperAmount) or 0) / 10000)
end

-- 골드확인 (구/신 API)
local function TS_UpdateMoney()
  local copper = 0
  if GetTargetTradeMoney then
    copper = tonumber(GetTargetTradeMoney()) or 0
  end
  if copper == 0 and C_TradeInfo and C_TradeInfo.GetTargetTradeMoney then
    local ok, v = pcall(function()
      return C_TradeInfo.GetTargetTradeMoney()
    end)
    if ok and v then
      copper = tonumber(v) or 0
    end
  end
  ll_targetMoney = copperToGold(copper)
end

-- 거래물품의 정보 처리
function TS_UpdateItemInfo(id, unit, item)
  local funcInfo = _G["GetTrade" .. unit .. "ItemInfo"]
  local funcLink = _G["GetTrade" .. unit .. "ItemLink"]
  if type(funcInfo) ~= "function" or type(funcLink) ~= "function" then
    return
  end

  local name, texture, numItems, quality, isUsable, enchantment

  name, texture, numItems, quality, enchantment = funcInfo(id)

  if not name then
    return
  end

  if unit == "Player" then
    lastPlayerTradeNumItems = math.max(1, tonumber(numItems) or 1)
  end

  playerItem = funcLink(id)
  if (not playerItem or playerItem == "") and C_TradeInfo and C_TradeInfo.GetTradePlayerItemHyperlink and unit == "Player" then
    local ok, link = pcall(function()
      return C_TradeInfo.GetTradePlayerItemHyperlink(id)
    end)
    if ok and link and link ~= "" then
      playerItem = link
    end
  end
end

local function tradeAutoInputEnabled()
  if GUI and GUI.GetCheckTradeButton then
    local v = GUI:GetCheckTradeButton()
    return v == 1 or v == true
  end
  return true
end

-- 공대장 또는(동기화 시) 경매담당: 골드0으로 아이템 넘김 → 장부 득자를 *마력추출* 표기로 둠
local function tradePlayerIsIberisRaidAuctionAuthorityForDeHandoff()
  if not IsInRaid() then
    return false
  end
  local s = ADDONSELF.sync
  if s and s.enabled then
    return s:IsLedgerEditor()
  end
  return UnitIsGroupLeader("player")
end

local function clearTradeState()
  playerItem = nil
  ls_targetName = ""
  ll_targetMoney = 0
end

-- 거래 완료: UI_INFO만 오지 않는 빌드·채팅 알림 대비
local function onTradeCancelledEvent()
  pendingTradeSnapshot = nil
  clearTradeState()
end

local function sendTradeRaidNotice(snap)
  local who = snap.name or "?"
  local money = math.floor(tonumber(snap.money) or 0)
  -- 단일·복수 아이템 모두 한 줄에 모두 명시 (총 가격은 마지막에 한 번)
  local items = (snap.items and #snap.items > 0) and snap.items or { { item = snap.item } }
  local parts = {}
  for _, p in ipairs(items) do
    if p and p.item and p.item ~= "" then
      parts[#parts + 1] = p.item
    end
  end
  if #parts == 0 then
    return
  end
  local line = "[IberisRaidAuction] " .. who .. "님이 " .. table.concat(parts, ", ") .. "을 " .. money .. "골드에 구매하였습니다."

  local sent = false
  pcall(function()
    if IsInRaid() then
      SendChatMessage(line, "RAID")
      sent = true
    elseif IsInGroup() then
      SendChatMessage(line, "PARTY")
      sent = true
    end
  end)
  if not sent then
    Print(line)
  end
end

local function applyTradeSnapshotToLedger(snap)
  return Database:ApplyPlayerToTargetTradeSnap(snap)
end

-- 거래창 한 슬롯에서 (링크, 수량) 추출. 빈 슬롯·취소된 슬롯은 nil 반환.
local function getTradeSlotItem(unit, slot)
  local funcInfo = _G["GetTrade" .. unit .. "ItemInfo"]
  local funcLink = _G["GetTrade" .. unit .. "ItemLink"]
  if type(funcInfo) ~= "function" or type(funcLink) ~= "function" then
    return nil, 0
  end
  local name, _, numItems = funcInfo(slot)
  if not name then
    return nil, 0
  end
  local link = funcLink(slot)
  if (not link or link == "") and unit == "Player" and C_TradeInfo and C_TradeInfo.GetTradePlayerItemHyperlink then
    local ok, l = pcall(function()
      return C_TradeInfo.GetTradePlayerItemHyperlink(slot)
    end)
    if ok and l and l ~= "" then
      link = l
    end
  end
  if not link or link == "" then
    return nil, 0
  end
  return link, math.max(1, tonumber(numItems) or 1)
end

-- 거래창 한 쪽(Player/Target)의 슬롯들을 모두 훑어 itemID 기준으로 집계한 ordered list 반환.
-- 같은 itemID가 여러 슬롯에 있으면 수량을 합산하고, 첫 등장 슬롯의 링크를 사용한다.
local function collectTradeSideItems(unit)
  local maxSlot = _G.MAX_TRADE_ITEMS or _G.NUM_TRADE_ITEMS or 8
  local list = {}
  local byRid = {}
  for slot = 1, maxSlot do
    local link, count = getTradeSlotItem(unit, slot)
    if link and link ~= "" then
      local rid = tonumber(link:match("item:(%d+)"))
      if rid then
        local existing = byRid[rid]
        if existing then
          existing.count = existing.count + count
        else
          local entry = { item = link, count = count, rid = rid }
          list[#list + 1] = entry
          byRid[rid] = entry
        end
      end
    end
  end
  return list
end

-- 거래창 아이템/골드 조합으로 스냅샷 갱신 (ACCEPT_UPDATE·골드 변경 등)
-- 일반 파티·솔로 거래는 GDKP 장부에 반영하지 않음(공격대 중만).
-- 복수 아이템(서로 다른 itemID 또는 같은 itemID의 여러 슬롯)도 함께 기록되도록 snap.items 배열을 채운다.
local function refreshPendingTradeSnapshot()
  if not IsInRaid() then
    return
  end
  if not ls_targetName or ls_targetName == "" then
    local n = UnitName("npc")
    ls_targetName = (n and (strsplit("-", n))) or ""
  end

  -- 1) 내가 거래창에 올린 아이템들 (판매·인계)
  local playerItems = collectTradeSideItems("Player")
  if #playerItems > 0 then
    TS_UpdateMoney()
    -- 골드 0이어도 스냅샷 유지: 마력추출물을 공대장에게 넘기는 거래 등
    if ls_targetName and ls_targetName ~= "" then
      local me = UnitName("player")
      local first = playerItems[1]
      pendingTradeSnapshot = {
        item = first.item,                    -- 단일 아이템 호환 필드
        count = first.count,                  -- 단일 아이템 호환 필드
        items = playerItems,                  -- 복수 아이템 본 데이터
        name = ls_targetName,
        money = ll_targetMoney,
        seller = me and (strsplit("-", me)) or "",
        -- 공대장·경매담당이 대금 없이 넘기면 득자를 거래 상대가 아닌 *마력추출* 표기로 저장
        deHandoff = (ll_targetMoney == 0) and tradePlayerIsIberisRaidAuctionAuthorityForDeHandoff(),
        t = GetTime(),
      }
      -- 거래 완료 이벤트보다 CHAT_MSG_LOOT이 먼저 오는 빌드: 완료 시점의 ignore보다 앞서서 막음
      for _, p in ipairs(playerItems) do
        armTradeLootChatIgnore(p.item, 30)
      end
    end
    return
  end

  -- 2) 상대가 아이템을 올리고 내가 골드를 내는 경우 (구매)
  local targetItems = collectTradeSideItems("Target")
  if #targetItems > 0 then
    local pc = (GetPlayerTradeMoney and tonumber(GetPlayerTradeMoney())) or 0
    if pc == 0 and C_TradeInfo and C_TradeInfo.GetPlayerTradeMoney then
      local ok, v = pcall(function()
        return C_TradeInfo.GetPlayerTradeMoney()
      end)
      if ok and v then pc = tonumber(v) or 0 end
    end
    local g = copperToGold(pc)
    if g ~= 0 then
      local me = UnitName("player")
      local first = targetItems[1]
      pendingTradeSnapshot = {
        item = first.item,
        count = first.count,
        items = targetItems,
        name = me and (strsplit("-", me)) or "",
        money = g,
        t = GetTime(),
      }
      for _, p in ipairs(targetItems) do
        armTradeLootChatIgnore(p.item, 30)
      end
    end
  end
end

local function onTradeCompleteEvent()
  local snap = pendingTradeSnapshot
  pendingTradeSnapshot = nil
  clearTradeState()

  if not snap or not snap.item or snap.item == "" then
    return
  end
  if not tradeAutoInputEnabled() then
    return
  end
  if not IsInRaid() then
    return
  end
  -- 이벤트 지연(채팅만 먼저 오는 빌드 등) 허용
  if snap.t and (GetTime() - snap.t) > 60 then
    Print("|cFFFF9900[IberisRaidAuction]|r 거래 알림·장부 반영이 너무 늦어 건너뛰었습니다. 수동 입력하세요.")
    return
  end

  do
    local s = ADDONSELF.sync
    if s and IsInRaid() and s.enabled and not s:IsLedgerEditor() then
      return
    end
  end

  -- 같은 거래(같은 아이템 묶음)로 짧은 시간 내 중복 알림 방지 (TRADE_SUCCESS + UI_INFO + 시스템채팅 등)
  local now = GetTime()
  local dedupKey
  if snap.items and #snap.items > 0 then
    local parts = {}
    for _, p in ipairs(snap.items) do
      parts[#parts + 1] = tostring(p.rid or p.item or "?")
    end
    dedupKey = table.concat(parts, ",")
  else
    dedupKey = tostring(snap.item or "")
  end
  if dedupKey == lastTradeNotifyItem and (now - lastTradeNotifyTime) < 2.5 then
    return
  end
  lastTradeNotifyItem = dedupKey
  lastTradeNotifyTime = now

  -- 거래 직후 뜨는 획득 채팅으로 같은 아이템이 한 번 더 쌓이지 않게 (송신자가 구매자인 경우 등)
  if snap.items and #snap.items > 0 then
    for _, p in ipairs(snap.items) do
      armTradeLootChatIgnore(p.item)
    end
  else
    armTradeLootChatIgnore(snap.item)
  end

  local money = math.floor(tonumber(snap.money) or 0)
  if money > 0 then
    sendTradeRaidNotice(snap)
  end

  -- 한 거래에 여러 아이템이 올라왔어도 모두 장부에 반영되도록 itemID별로 분할 적용한다.
  -- (기존: 가장 낮은 슬롯의 아이템 1건만 기록되는 버그)
  -- 골드는 모호성 회피를 위해 첫 항목에 전액, 나머지는 0으로 분배. (마부 0원 인계는 모두 0g.)
  local entries
  if snap.items and #snap.items > 0 then
    entries = snap.items
  else
    entries = { { item = snap.item, count = snap.count or 1, rid = nil } }
  end

  local function applyOnePerItem(perSnap)
    local ok, tradeCode = applyTradeSnapshotToLedger(perSnap)
    if ok then
      ToastTradeLedgerApplied(perSnap, tradeCode)
      return
    end
    C_Timer.After(0.5, function()
      local ok2, code2 = applyTradeSnapshotToLedger(perSnap)
      if ok2 then
        ToastTradeLedgerApplied(perSnap, code2)
      else
        C_Timer.After(1.0, function()
          local ok3, code3 = applyTradeSnapshotToLedger(perSnap)
          if ok3 then
            ToastTradeLedgerApplied(perSnap, code3)
          else
            Print("|cFFFF9900[IberisRaidAuction]|r 거래는 공대(파티)에 알렸지만 장부 자동 입력에 실패했습니다 (" .. (perSnap.item or "?") .. "). 해당 줄을 수동으로 추가해 주세요.")
          end
        end)
      end
    end)
  end

  for i, entry in ipairs(entries) do
    local perSnap = {
      item = entry.item,
      count = entry.count or 1,
      name = snap.name,
      seller = snap.seller,
      -- 첫 항목에 전액, 나머지는 0g (대부분의 사용 사례인 마부 0원 인계는 영향 없음)
      money = (i == 1) and snap.money or 0,
      deHandoff = snap.deHandoff,
      t = snap.t,
    }
    applyOnePerItem(perSnap)
  end
end

local function uiMessageTradeErrorName(messageType, message)
  if not GetGameMessageInfo then
    return nil
  end
  if type(messageType) == "number" then
    return select(1, GetGameMessageInfo(messageType))
  end
  if type(message) == "number" then
    return select(1, GetGameMessageInfo(message))
  end
  return nil
end

local function uiMessageLooksLikeTradeComplete(messageType, message)
  if uiMessageTradeErrorName(messageType, message) == "ERR_TRADE_COMPLETE" then
    return true
  end
  local a, b = messageType, message
  if type(a) == "string" then
    if _G.TRADE_COMPLETE and a == _G.TRADE_COMPLETE then return true end
    if _G.TRADE_TRANSACTION_SUCCEEDED and a == _G.TRADE_TRANSACTION_SUCCEEDED then return true end
  end
  if type(b) == "string" then
    if _G.TRADE_COMPLETE and b == _G.TRADE_COMPLETE then return true end
    if _G.TRADE_TRANSACTION_SUCCEEDED and b == _G.TRADE_TRANSACTION_SUCCEEDED then return true end
  end
  return false
end

local function uiMessageLooksLikeTradeCancel(messageType, message)
  if uiMessageTradeErrorName(messageType, message) == "ERR_TRADE_CANCELLED" then
    return true
  end
  local a, b = messageType, message
  if type(a) == "string" and _G.ERR_TRADE_CANCELLED and a == _G.ERR_TRADE_CANCELLED then return true end
  if type(b) == "string" and _G.ERR_TRADE_CANCELLED and b == _G.ERR_TRADE_CANCELLED then return true end
  return false
end

local function onUiTradeMessage(messageType, message)
  if uiMessageLooksLikeTradeCancel(messageType, message) then
    onTradeCancelledEvent()
    return
  end
  if uiMessageLooksLikeTradeComplete(messageType, message) then
    onTradeCompleteEvent()
  end
end

RegEvent("UI_INFO_MESSAGE", function(messageType, message)
  onUiTradeMessage(messageType, message)
end)

RegEvent("UI_ERROR_MESSAGE", function(messageType, message)
  onUiTradeMessage(messageType, message)
end)

-- 일부 빌드에서만 존재; 없으면 RegisterEvent 실패할 수 있어 pcall
pcall(function()
  RegEvent("TRADE_SUCCESS", function()
    onTradeCompleteEvent()
  end)
end)

-- 시스템 채팅 줄 (로케일 대비 짧은 키워드)
RegEvent("CHAT_MSG_SYSTEM", function(msg)
  if not msg or type(msg) ~= "string" then return end
  if msg:find("거래") and (msg:find("완료") or msg:find("성공")) then
    onTradeCompleteEvent()
    return
  end
  if msg:lower():find("trade") and msg:lower():find("complete") then
    onTradeCompleteEvent()
    return
  end
  if msg:find("거래") and msg:find("취소") then
    onTradeCancelledEvent()
  end
end)

RegEvent("TRADE_SHOW", function()
	pendingTradeSnapshot = nil
	lastTradeNotifyItem = ""
	playerItem = nil
	ll_targetMoney = 0
	lastPlayerTradeNumItems = 1
	local n = UnitName("npc")
	ls_targetName = (n and (strsplit("-", n))) or ""
end)

RegEvent("TRADE_ACCEPT_UPDATE", function()
	refreshPendingTradeSnapshot()
end)

pcall(function()
  RegEvent("TRADE_MONEY_CHANGED", function()
    refreshPendingTradeSnapshot()
  end)
end)



------------------------------------------------------------------------------

local function ShowCurrentAutoLootType()
    -- Sync from database to ensure we show the latest value
    SyncAutoAddLootFromDB()

    if AutoAddLoot == AUTOADDLOOT_TYPE_ALL then
        Print("Auto recording: Always on")
    elseif AutoAddLoot == AUTOADDLOOT_TYPE_RAID then
        Print("Auto recording: Raid only")
    elseif AutoAddLoot == AUTOADDLOOT_TYPE_DISABLE then
        Print("Auto recording: Disabled")
    end
end

-- 명령어 처리 함수
local function HandleCommand(msg)
    local cmd, what, rest
    cmd, what, rest = msg:match("^(%S+)%s+(%S+)%s*(.*)$")
    if not cmd then
        cmd = msg:match("^(%S+)$")
    end

    local function ClearManualSplitGroups(silent)
        local ledger = Database:GetCurrentLedger()
        local changed = false
        if ledger and ledger.items then
            for _, item in ipairs(ledger.items) do
                if item and (item._manualSplitGroup ~= nil or item.manualSplitGroup ~= nil) then
                    item._manualSplitGroup = nil
                    item.manualSplitGroup = nil
                    changed = true
                end
            end
        end
        if changed then
            Database:OnLedgerItemsChange()
        end
        if not silent then
            Print(changed and "임시 묶음 분리를 해제했습니다." or "해제할 임시 묶음 분리가 없습니다.")
        end
        return changed
    end

    local function SplitLargestStack(firstCount)
        firstCount = math.floor(tonumber(firstCount) or 0)
        if firstCount < 1 then
            Print("사용법: /ira splitstack <앞 묶음 개수>  또는  /ira splitstack clear")
            return
        end

        ClearManualSplitGroups(true)

        local ledger = Database:GetCurrentLedger()
        if not ledger or not ledger.items then
            Print("장부가 비어 있습니다.")
            return
        end

        local groups = {}
        local bestKey, bestSize = nil, 0

        for i, item in ipairs(ledger.items) do
            if item and item.type == "CREDIT" and item.detail and item.detail.type == "ITEM" then
                local safeItemID = item.detail.reliableItemID
                if not safeItemID then
                    local rawItemLink = tostring(item.detail.item or "")
                    local firstByte = string.byte(rawItemLink, 1) or 0
                    local lastByte = string.byte(rawItemLink, -1) or 0
                    safeItemID = string.len(rawItemLink) .. "_" .. firstByte .. "_" .. lastByte
                end

                local beneficiary = ""
                if Database.GetLedgerDisplayBeneficiary then
                    beneficiary = Database:GetLedgerDisplayBeneficiary(i) or ""
                else
                    beneficiary = item.beneficiary or ""
                end
                if ADDONSELF.NormalizeDisenchantHandoffBeneficiary then
                    beneficiary = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(beneficiary)
                end
                local normalizedCost = string.format("%.2f", tonumber(item.cost) or 0)
                local saleState = tostring(item.saleState or "open")
                local key = tostring(safeItemID) .. "_" .. beneficiary .. "_" .. normalizedCost .. "_" .. saleState
                if not groups[key] then
                    groups[key] = {
                        indices = {},
                        itemLink = item.detail.item or "",
                    }
                end
                table.insert(groups[key].indices, i)
                if #groups[key].indices > bestSize then
                    bestKey = key
                    bestSize = #groups[key].indices
                end
            end
        end

        if not bestKey or bestSize <= firstCount then
            Print(string.format("나눌 수 있는 묶음이 없습니다. 현재 가장 큰 묶음 수량: %d", bestSize or 0))
            return
        end

        local grp = groups[bestKey]
        local indices = grp.indices
        table.sort(indices, function(a, b)
            local ia = ledger.items[a]
            local ib = ledger.items[b]
            local sa = tonumber(ia and ia.seq) or a
            local sb = tonumber(ib and ib.seq) or b
            if sa ~= sb then
                return sa > sb
            end
            return a > b
        end)

        local splitId = tostring(time()) .. "_" .. tostring(indices[1]) .. "_" .. tostring(firstCount)
        for pos, idx in ipairs(indices) do
            local item = ledger.items[idx]
            if item then
                item._manualSplitGroup = (pos <= firstCount) and (splitId .. "_A") or (splitId .. "_B")
                item.manualSplitGroup = nil
                if item.type == "CREDIT" and item.detail and item.detail.type == "ITEM" then
                    item.noBeneficiary = false
                    item.confirmed = false
                    item.saleState = ((tonumber(item.cost) or 0) > 0) and "priced" or "open"
                end
            end
        end

        Database:OnLedgerItemsChange()

        local itemName = (grp.itemLink and GetItemInfo(grp.itemLink)) or (grp.itemLink and grp.itemLink:match("%[([^%]]+)%]")) or "아이템"
        Print(string.format("임시 분리: %s %d개 -> %d개 + %d개", tostring(itemName or "아이템"), bestSize, firstCount, bestSize - firstCount))
        Print("원복: /ira splitstack clear")
    end

    local function RecoverStackForItemID(itemID)
        itemID = math.floor(tonumber(itemID) or 0)
        if itemID <= 0 then
            Print("사용법: /ira recoverstack <itemID>")
            return
        end

        local ledger = Database:GetCurrentLedger()
        if not ledger or not ledger.items then
            Print("장부가 비어 있습니다.")
            return
        end

        local matchIndices = {}
        local signatures = {}
        local bestSig, bestCount = nil, 0

        for idx, item in ipairs(ledger.items) do
            local rid = item and item.detail and tonumber(item.detail.reliableItemID) or 0
            if rid == itemID then
                matchIndices[#matchIndices + 1] = idx
                local sig = table.concat({
                    tostring(item.cost or 0),
                    tostring(item.saleState or ""),
                    tostring(item.confirmed and 1 or 0),
                    tostring(item.noBeneficiary and 1 or 0),
                    tostring(item.beneficiary or ""),
                    tostring(item.looter or ""),
                    tostring(item.winner or ""),
                }, "\031")
                local bucket = signatures[sig]
                if not bucket then
                    bucket = { count = 0, sampleIdx = idx }
                    signatures[sig] = bucket
                end
                bucket.count = bucket.count + 1
                if bucket.count > bestCount then
                    bestCount = bucket.count
                    bestSig = sig
                end
            end
        end

        if #matchIndices < 2 then
            Print(string.format("itemID %d 에 대해 묶을 줄이 부족합니다. (현재 %d줄)", itemID, #matchIndices))
            return
        end
        if not bestSig or not signatures[bestSig] then
            Print("복구 기준 줄을 찾지 못했습니다.")
            return
        end

        local target = ledger.items[signatures[bestSig].sampleIdx]
        if not target then
            Print("복구 기준 줄을 읽지 못했습니다.")
            return
        end

        local changed = 0
        for _, idx in ipairs(matchIndices) do
            local row = ledger.items[idx]
            if row then
                local before = table.concat({
                    tostring(row.cost or 0),
                    tostring(row.saleState or ""),
                    tostring(row.confirmed and 1 or 0),
                    tostring(row.noBeneficiary and 1 or 0),
                    tostring(row.beneficiary or ""),
                    tostring(row.looter or ""),
                    tostring(row.winner or ""),
                }, "\031")
                if before ~= bestSig then
                    row.cost = target.cost or 0
                    row.saleState = target.saleState
                    row.confirmed = target.confirmed and true or false
                    row.noBeneficiary = target.noBeneficiary and true or false
                    row.beneficiary = tostring(target.beneficiary or "")
                    row.looter = tostring(target.looter or "")
                    row.winner = tostring(target.winner or "")
                    changed = changed + 1
                end
            end
        end

        if changed == 0 then
            Print(string.format("itemID %d 줄들은 이미 같은 상태입니다.", itemID))
            return
        end

        Database:OnLedgerItemsChange()

        local Sync = ADDONSELF.sync
        if Sync and Sync.IsLedgerEditor and Sync:IsLedgerEditor() and Sync.enabled and not Sync.suppressBroadcast and IsInRaid() then
            ledger._syncRev = (tonumber(ledger._syncRev) or 0) + 1
            if Sync.ScheduleStatBroadcast then
                Sync:ScheduleStatBroadcast()
            end
            if Sync.ScheduleSyncAck then
                Sync:ScheduleSyncAck()
            end
        end

        local itemName = (target.detail and target.detail.item and GetItemInfo(target.detail.item)) or (target.detail and target.detail.displayname) or tostring(itemID)
        Print(string.format("복구 완료: %s (itemID %d) %d줄을 같은 상태로 맞췄습니다.", tostring(itemName or itemID), itemID, #matchIndices))
    end

    if not cmd then
        GUI:Show()

        Print(L["Control + 아이템 클릭은 수익으로 추가"])
        Print(L["Right click to remove record"])
        ShowCurrentAutoLootType()
        Print("[/ira toggle] " .. L["toggle Auto recording on/off"])
        Print("[/ira countdown] 카운트다운 메시지 설정")
        Print("[/ira autoclear] 공격대 첫 입던 시 장부 초기화 확인 (on/off) — 같은 공대 재입던/사망 후 부활은 묻지 않음")
        Print("[/ira debugcost] 낙찰가 입력·탭 문제 추적(채팅 로그, 다시 입력 시 끔)")
        Print("[/ira splitstack <n>|clear] 가장 큰 묶음을 n개+나머지로 임시 분리")
        Print("[/ira recoverstack <itemID>] 같은 아이템 줄 상태를 맞춰 다시 묶이게 함(임시 복구)")
        Print("[/ira blacklist] 자동 캡처 차단 목록 보기/편집 (부분일치)")
    elseif cmd == "debugcost" then
        _G.IRA_DEBUG_COST_EDIT = not _G.IRA_DEBUG_COST_EDIT
        Print("|cFF00CCFF[IberisRaidAuction]|r 낙찰가 디버그: " .. (_G.IRA_DEBUG_COST_EDIT and "|cFF00FF00켜짐|r — 채팅창에 [IRA cost #…] 로그가 뜹니다." or "꺼짐"))
    elseif cmd == "splitstack" then
        local w = strtrim(tostring(what or ""):lower())
        if w == "clear" or w == "reset" or w == "off" then
            ClearManualSplitGroups(false)
        else
            SplitLargestStack(w)
        end
    elseif cmd == "recoverstack" then
        RecoverStackForItemID(what)
    elseif cmd == "new" then
        if not Database:NewLedger() then
            Print(ADDONSELF.L["Only the raid leader can clear the ledger."])
        end
    elseif cmd == "clear" then

    elseif cmd == "countdown" and not what then
        -- /br countdown만 입력했을 때 카운트다운 도움말 표시
        local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
            count = "--- %d",
            closed = "--- 입찰 마감 ---",
            resume = "--- 신규 입찰 ! 재개합니다 ---"
        })

        Print("=== 카운트다운 메시지 설정 ===")
        Print(string.format("카운트: %s", messages.count))
        Print(string.format("마감: %s", messages.closed))
        Print(string.format("재개: %s", messages.resume))
        Print("사용법:")
        Print("/ira countdown count <메시지> — 카운트다운 메시지 설정 (%d = 숫자)")
        Print("/ira countdown closed <메시지> — 입찰 마감 메시지 설정")
        Print("/ira countdown resume <메시지> — 재개 메시지 설정")
        Print("/ira countdown reset — 기본값으로 초기화")

    elseif cmd == "toggle" then
        AutoAddLoot = AUTOADDLOOT_TYPE_RAID
        Database:SetConfig("autoaddloot", AUTOADDLOOT_TYPE_RAID)
        Print("자동기록은 항상 켜짐으로 고정되어 있습니다.")
        local GUI = ADDONSELF and ADDONSELF.gui or nil
        if GUI and GUI.UpdateAutoLootDropdown then
            GUI:UpdateAutoLootDropdown()
        end
    elseif cmd == "countdown" then
        if what == "reset" then
            -- 기본값으로 초기화
            Database:SetGlobalConfig("countdownmessages", {
                count = "--- %d",
                closed = "--- 입찰 마감 ---",
                resume = "--- 신규 입찰 ! 재개합니다 ---"
            })
            Print("카운트다운 메시지가 기본값으로 초기화되었습니다.")

        elseif what == "count" or what == "closed" or what == "resume" then
            -- rest 변수에 이미 메시지가 저장되어 있음
            local message = rest

            -- 따옴표 제거 (양 끝에 따옴표가 있는 경우)
            if message and message:match('^".*"$') then
                message = message:sub(2, -2)
            end

            if message and message ~= "" then
                local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                    count = "--- %d",
                    closed = "--- 입찰 마감 ---",
                    resume = "--- 신규 입찰 ! 재개합니다 ---"
                })

                messages[what] = message
                Database:SetGlobalConfig("countdownmessages", messages)

                if what == "count" then
                    Print(string.format("카운트다운 메시지 설정: '%s'", message))
                elseif what == "closed" then
                    Print(string.format("입찰 마감 메시지 설정: '%s'", message))
                elseif what == "resume" then
                    Print(string.format("재개 메시지 설정: '%s'", message))
                end

            else
                Print("오류: 메시지를 입력해주세요.")
                Print(string.format("사용법: /ira countdown %s <메시지>", what))
            end
        else
            Print("오류: 알 수 없는 하위 명령어입니다.")
            Print("'/ira countdown' 를 입력하여 사용법을 확인하세요.")
        end
    elseif cmd == "blacklist" then
        -- /ira blacklist                  → 목록 표시
        -- /ira blacklist add <이름>       → 부분일치 항목 추가
        -- /ira blacklist remove <이름>    → 제거
        -- /ira blacklist clear            → 전부 비움
        if not what then
            local list = Database:GetItemBlacklist()
            Print("=== 자동 캡처 블랙리스트 ===")
            local count = 0
            for entry in pairs(list) do
                Print("  - " .. entry)
                count = count + 1
            end
            if count == 0 then Print("  (비어 있음)") end
            Print("사용법: /ira blacklist add <이름> | remove <이름> | clear | test <이름>")
            return
        end

        local arg = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local list = Database:GetItemBlacklist()

        if what == "add" then
            if arg == "" then Print("이름을 입력하세요. 예: /ira blacklist add 황천의 쐐기"); return end
            list[arg] = true
            Database:SetItemBlacklist(list)
            Print("[blacklist] 추가됨: " .. arg)
        elseif what == "remove" or what == "rm" then
            if arg == "" then Print("이름을 입력하세요"); return end
            local removed = false
            for key in pairs(list) do
                if string.lower(key) == string.lower(arg) then
                    list[key] = nil
                    removed = true
                end
            end
            if removed then
                Database:SetItemBlacklist(list)
                Print("[blacklist] 제거됨: " .. arg)
            else
                Print("[blacklist] 일치 없음: " .. arg)
            end
        elseif what == "clear" then
            Database:SetItemBlacklist({})
            Print("[blacklist] 전부 비움")
        elseif what == "test" then
            if arg == "" then Print("이름 또는 아이템 링크를 입력하세요. 예: /ira blacklist test 황천매듭 장궁"); return end
            local hit = Database:IsItemBlacklisted(arg, nil)
            if hit then
                Print(string.format("[blacklist] %s → |cFFFF6666차단됨|r (자동 캡처 X)", arg))
            else
                Print(string.format("[blacklist] %s → |cFF66FF66통과|r (자동 캡처 O)", arg))
            end
        else
            Print("사용법: /ira blacklist add <이름> | remove <이름> | clear | test <이름> | test <이름>")
        end
    elseif cmd == "autoclear" then
        -- 자동 초기화 설정
        if not what or what == "" then
            -- 현재 설정 표시
            local enabled = Database:GetGlobalConfigOrDefault("autoClearOnDungeonEnter", true)
            Print("공격대 중 인스턴스 입장 시 초기화 확인: " .. (enabled and "켜짐" or "꺼짐"))
            Print("사용법: /ira autoclear <on|off>")
        else
            local enabled = what:lower() == "on" or what:lower() == "true" or what:lower() == "1"
            Database:SetGlobalConfig("autoClearOnDungeonEnter", enabled)
            Print("공격대 중 인스턴스 입장 시 초기화 확인: " .. (enabled and "켜짐" or "꺼짐"))
        end
    else
        local _, itemLink = GetItemInfo(strtrim(msg))
        if itemLink then
            if IberisRaidAuctionSyncBlocksEdits() then
                Print("|cFFFF3333[IberisRaidAuction]|r 공격대에서 편집 권한이 없습니다.")
            elseif not ADDONSELF.ItemPassesLedgerPickupQualityRules(itemLink) then
                ToastLedgerQualityReject("[IberisRaidAuction]")
            else
                if Database:AddLoot(itemLink, 1, "", 0, false) then
                    ToastIberisRaidAuctionItemAddedOk(itemLink)
                end
            end
        end
    end

end
SLASH_IBERISRAIDAUCTION1 = "/ira"
SLASH_IBERISRAIDAUCTION2 = "/iberisraidauction"
SLASH_IBERISRAIDAUCTION3 = "/ari"
SLASH_IBERISRAIDAUCTION4 = "/ira2"
SlashCmdList["IBERISRAIDAUCTION"] = HandleCommand

-- 스케일 조절 명령어는 HandleCommand에 이미 포함됨
