-- IberisRaidAuction/IRAGui.lua
local _, ADDONSELF = ...

local strbyte = string.byte

-- 낙찰가 입력·탭 이슈 진단: /ira debugcost 로 켠 뒤 채팅창 로그 확인
local iraCostDbgSeq = 0
local function IRADebugCost(fmt, ...)
    if not _G.IRA_DEBUG_COST_EDIT then
        return
    end
    iraCostDbgSeq = iraCostDbgSeq + 1
    local msg
    if select("#", ...) > 0 then
        msg = string.format(fmt, ...)
    else
        msg = tostring(fmt)
    end
    print(string.format("|cFF00CCFF[IRA cost #%d]|r %s", iraCostDbgSeq, msg))
end

-- 낙찰가 EditBox: Blizzard strtrim()이 "60"/"600"을 "6"으로 깎는 빌드가 있음(/ira debugcost 로 확인).
-- 콤마·ASCII 공백(탭·LF·CR·스페이스)만 제거하고 strtrim 은 쓰지 않는다.
local function IRACostEditNormalizeDigits(s)
    if s == nil then
        return ""
    end
    s = tostring(s)
    s = s:gsub(",", "")
    s = s:gsub("^[\009\010\013\032]+", ""):gsub("[\009\010\013\032]+$", "")
    return s
end

ADDONSELF.gui = {}
local GUI = ADDONSELF.gui

-- 관련 모듈 및 함수 불러오기
local L = ADDONSELF.L
local ScrollingTable = ADDONSELF.st
local RegEvent = ADDONSELF.regevent
local Database = ADDONSELF.db
local Print = ADDONSELF.print
local calcavg = ADDONSELF.calcavg
local GenExport = ADDONSELF.genexport
local GenReport = ADDONSELF.genreport
-- checkf 변수는 더 이상 사용하지 않음 (GUI.roundingLevel 사용)
local checkTrade = 1
local LedgerItemSaleState
local LedgerItemIsConfirmed
local LedgerEntrySignalState
local LedgerSignalColor
local BENEFICIARY_HEADER_TEXT = "|cff909090획득자|r|cffffffff/|r|cff33cc33낙찰자|r"
local function BeneficiaryDisplayColor(entry)
    if entry and entry.type == "CREDIT" and entry.detail and entry.detail.type == "ITEM" then
        local st = LedgerItemSaleState and LedgerItemSaleState(entry) or entry.saleState
        if st == "priced" or st == "confirmed" then
            return 0.20, 0.82, 0.20
        end
        return 0.65, 0.65, 0.65
    end
    return 1.0, 1.0, 1.0
end
local function GetReadonlyVisualAlpha(isConfirmed, isNoBene)
    if isConfirmed or isNoBene then
        return 0.65
    end
    return 1.0
end

local function GetReadonlyActionAlpha(isConfirmed, isNoBene)
    if isConfirmed or isNoBene then
        return 0.65
    end
    return 1.0
end

local function ApplyConfirmedTextBoxVisual(textBox, isConfirmed, r, g, b)
    if not textBox then
        return
    end
    textBox:SetTextColor(r or 1.0, g or 1.0, b or 1.0)
end

local function GetLedgerEntryRecord(entry, idx)
    if entry and entry.realItemData then
        return entry.realItemData, entry.realItemIdx or idx
    end
    if entry and (entry.type ~= nil or entry.detail ~= nil or entry.beneficiary ~= nil) then
        return entry, idx
    end
    if idx and Database and Database.GetCurrentLedger then
        local ledger = Database:GetCurrentLedger()
        if ledger and ledger.items and ledger.items[idx] then
            return ledger.items[idx], idx
        end
    end
    return entry, idx
end

local function GetEntryDisplayBeneficiary(entry, idx)
    local row, rowIdx = GetLedgerEntryRecord(entry, idx)
    if Database and Database.GetLedgerDisplayBeneficiary then
        if rowIdx then
            return Database:GetLedgerDisplayBeneficiary(rowIdx)
        end
        return Database:GetLedgerDisplayBeneficiary(row)
    end
    return tostring(row and row.beneficiary or "")
end

local function GetEntryEditBeneficiaryRole(entry)
    if entry and entry.type == "CREDIT" and entry.detail and entry.detail.type == "ITEM" then
        local st = LedgerItemSaleState and LedgerItemSaleState(entry) or entry.saleState
        if st == "priced" or st == "confirmed" then
            return "winner"
        end
        return "looter"
    end
    return "beneficiary"
end

local function GetEntryEditBeneficiaryValue(entry, idx)
    local row, rowIdx = GetLedgerEntryRecord(entry, idx)
    local role = GetEntryEditBeneficiaryRole(entry or row)
    if Database and rowIdx then
        if role == "winner" and Database.GetLedgerEntryWinner then
            return Database:GetLedgerEntryWinner(rowIdx)
        end
        if role == "looter" and Database.GetLedgerEntryLooter then
            return Database:GetLedgerEntryLooter(rowIdx)
        end
    end
    if role == "winner" then
        return tostring(row and row.winner or row and row.beneficiary or "")
    end
    if role == "looter" then
        return tostring(row and row.looter or row and row.beneficiary or "")
    end
    return tostring(row and row.beneficiary or "")
end

local function SetEntryBeneficiaryValue(entry, idx, value)
    local row, rowIdx = GetLedgerEntryRecord(entry, idx)
    if not row then
        return false, tostring(value or ""), "beneficiary"
    end
    local role = GetEntryEditBeneficiaryRole(entry or row)
    local text = tostring(value or "")
    local changed = false
    if rowIdx and Database then
        if role == "winner" and Database.SetLedgerEntryWinner then
            changed = Database:SetLedgerEntryWinner(rowIdx, text, true)
        elseif role == "looter" and Database.SetLedgerEntryLooter then
            changed = Database:SetLedgerEntryLooter(rowIdx, text, true)
        elseif tostring(row.beneficiary or "") ~= text then
            row.beneficiary = text
            changed = true
        end
    else
        if role == "winner" then
            if tostring(row.winner or "") ~= text then
                row.winner = text
                changed = true
            end
        elseif role == "looter" then
            if tostring(row.looter or "") ~= text then
                row.looter = text
                changed = true
            end
        elseif tostring(row.beneficiary or "") ~= text then
            row.beneficiary = text
            changed = true
        end
    end
    return changed, GetEntryDisplayBeneficiary(row, rowIdx), role
end

local function BroadcastEntryBeneficiaryChange(idx, value, role)
    if not idx or not ADDONSELF.sync then
        return
    end
    local ledger = Database:GetCurrentLedger()
    local item = ledger and ledger.items and ledger.items[idx]
    local rid = item and item.detail and item.detail.reliableItemID
    local iLink = item and item.detail and item.detail.item
    if role == "winner" and ADDONSELF.sync.BroadcastWinner then
        ADDONSELF.sync:BroadcastWinner(idx, rid, value, iLink)
    elseif role == "looter" and ADDONSELF.sync.BroadcastLooter then
        ADDONSELF.sync:BroadcastLooter(idx, rid, value, iLink)
    else
        ADDONSELF.sync:BroadcastBeneficiary(idx, rid, value, iLink)
    end
end

local function LedgerRowMatchesPendingOnlyFilter(item, idx)
    if not GUI._showPendingOnly then
        return true
    end
    if not item or item.type ~= "CREDIT" or not item.detail or item.detail.type ~= "ITEM" then
        return false
    end
    if Database:GetItemNoBeneficiary(idx) then
        return false
    end
    return not Database:IsLedgerEntryConfirmed(idx)
end

-- 미확정 버튼: 무득이 아니고 아직 확정되지 않은 아이템 줄(표시상 묶음은 1회) 개수 집계.

local IRA_ITEM_CLASS_TRADE_GOOD = (type(_G.LE_ITEM_CLASS_TRADEGOODS) == "number" and _G.LE_ITEM_CLASS_TRADEGOODS) or 7
local IRA_ITEM_SUBCLASS_ENCHANTING_TRADE_GOOD = 12
local IRA_ITEM_SUBCLASS_ARMOR_ENCHANTMENT_TRADE_GOOD = 14
local IRA_ITEM_SUBCLASS_WEAPON_ENCHANTMENT_TRADE_GOOD = 15

local function ItemLooksLikeEnchantingTradeGood(itemRef)
    if type(itemRef) ~= "string" or itemRef == "" then
        return false
    end

    if type(GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, classID, subClassID = pcall(GetItemInfoInstant, itemRef)
        if ok and tonumber(classID) == IRA_ITEM_CLASS_TRADE_GOOD then
            local sc = tonumber(subClassID)
            if sc == IRA_ITEM_SUBCLASS_ENCHANTING_TRADE_GOOD
                or sc == IRA_ITEM_SUBCLASS_ARMOR_ENCHANTMENT_TRADE_GOOD
                or sc == IRA_ITEM_SUBCLASS_WEAPON_ENCHANTMENT_TRADE_GOOD then
                return true
            end
        end
    end

    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemRef)
    local typeText = tostring(itemType or "")
    local subTypeText = tostring(itemSubType or "")
    local lowerType = strlower(typeText)
    local lowerSubType = strlower(subTypeText)
    local isTradeGoodType = (typeText == TRADE_GOODS)
        or typeText:find("무역품", 1, true)
        or lowerType:find("trade goods", 1, true)
    if not isTradeGoodType then
        return false
    end

    return lowerSubType:find("enchant", 1, true)
        or subTypeText:find("마법부여", 1, true)
        or lowerSubType:find("armor enchantment", 1, true)
        or lowerSubType:find("weapon enchantment", 1, true)
end

local function LedgerItemIsDisenchantResult(item)
    if not item or item.type ~= "CREDIT" or not item.detail or item.detail.type ~= "ITEM" then
        return false
    end
    if item.detail.isDisenchantResult == true then
        return true
    end
    return ItemLooksLikeEnchantingTradeGood(item.detail.item)
end

local function LedgerEntryDisplayItemCount(entry)
    local rowCount = tonumber(entry and entry.stackCount) or 1
    local itemCount = tonumber(entry and entry.detail and entry.detail.count) or 1
    if rowCount < 1 then rowCount = 1 end
    if itemCount < 1 then itemCount = 1 end
    return rowCount * itemCount
end

local IRA_TEST_RECIPE_ITEM_IDS = {
    [23809] = true, -- Schematic: Stabilized Eternium Scope
    [22559] = true, -- Formula: Enchant Weapon - Mongoose
    [21903] = true, -- Pattern: Soulcloth Shoulders
    [21904] = true, -- Pattern: Soulcloth Vest
}

local function BuildQualityColoredItemName(itemLink, fallbackName)
    local itemName, _, quality = GetItemInfo(itemLink or "")
    local name = itemName or fallbackName or "?"
    local q = tonumber(quality) or 0
    local r, g, b, colorExtra = GetItemQualityColor(q)
    local color = "|cffffffff"
    if type(colorExtra) == "string" then
        if colorExtra:match("^%x%x%x%x%x%x%x%x$") then
            color = "|c" .. colorExtra
        elseif colorExtra:find("|c", 1, true) then
            color = colorExtra
        end
    elseif r and g and b then
        local function byte(x)
            x = tonumber(x) or 0
            if x <= 1 then x = x * 255 end
            if x < 0 then x = 0 elseif x > 255 then x = 255 end
            return math.floor(x + 0.5)
        end
        color = string.format("|cff%02x%02x%02x", byte(r), byte(g), byte(b))
    elseif ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
        local c = ITEM_QUALITY_COLORS[q]
        color = string.format("|cff%02x%02x%02x",
            math.floor(((c.r or 1) * 255) + 0.5),
            math.floor(((c.g or 1) * 255) + 0.5),
            math.floor(((c.b or 1) * 255) + 0.5))
    end
    return string.format("%s%s|r", color, name)
end

-- 무득(분배 제외): 체크박스·경매안함 집계·행 어두움 동일 기준 (IRAData RawNoBeneficiary와 일치)
local function LedgerItemIsMarkedNoBeneficiary(item)
    return Database:IsNoBeneficiarySetOnRow(item)
end

-- 목록 품질 필터: 2=고급+(희귀 이상 + 녹색 도안·제작법만, 백색·하급·비도안 녹색 숨김 — 자동 수집과 동일), 3=희귀+, 4=영웅+. 예전 1·5 저장값은 2·4로 맞춤
local function NormalizeQualityFilterLevel(fl)
    fl = tonumber(fl) or 3
    if fl < 2 then
        return 2
    end
    if fl > 4 then
        return 4
    end
    return fl
end

-- 고급+(2): 희귀 이상 표시 + 녹색은 도안류만. 희귀+(3)·영웅+(4): 최소 품질 이상
local function ItemHiddenByQualityFilter(itemQuality, filterLevel, itemLink)
    filterLevel = NormalizeQualityFilterLevel(filterLevel)
    if filterLevel == 2 then
        local q = tonumber(itemQuality)
        if not q then
            return false
        end
        if q >= 3 then
            return false
        end
        if q == 2 then
            if itemLink and ADDONSELF.ItemLooksRecipeLikeForAutoLoot and ADDONSELF.ItemLooksRecipeLikeForAutoLoot(itemLink) then
                return false
            end
            return true
        end
        return true
    end
    if not itemQuality then
        return false
    end
    return itemQuality < filterLevel
end

--- 동기화 잠금에 따른 상세/요약/기록저장/기록삭제 버튼 상태 갱신
function GUI:RefreshLockedButtons()
    local locked = self._uiLocked and true or false
    local alphaLocked = locked and 0.4 or 1.0

    local function applyReportStyle(bt)
        if not bt then
            return
        end
        if locked then
            bt:Disable()
            bt:SetAlpha(alphaLocked)
        else
            bt:Enable()
            bt:SetAlpha(1.0)
        end
    end

    applyReportStyle(self.reportButton)
    applyReportStyle(self.summaryButton)
    applyReportStyle(self.exportButton)

    if self.clearLogButton then
        local raidSync = ADDONSELF.sync and ADDONSELF.sync.enabled and IsInRaid()
        local clearAllowed = not raidSync or UnitIsGroupLeader("player")
        if locked or not clearAllowed then
            self.clearLogButton:Disable()
            self.clearLogButton:SetAlpha(locked and alphaLocked or 0.4)
        else
            self.clearLogButton:Enable()
            self.clearLogButton:SetAlpha(1.0)
        end
    end
end

local EQUIP_LOC_KR = {
    INVTYPE_HEAD = "머리", INVTYPE_NECK = "목", INVTYPE_SHOULDER = "어깨",
    INVTYPE_CHEST = "가슴", INVTYPE_ROBE = "가슴", INVTYPE_WAIST = "허리",
    INVTYPE_LEGS = "다리", INVTYPE_FEET = "발", INVTYPE_WRIST = "손목",
    INVTYPE_HAND = "손", INVTYPE_FINGER = "손가락", INVTYPE_TRINKET = "장신구",
    INVTYPE_CLOAK = "등", INVTYPE_WEAPON = "한손 무기", INVTYPE_2HWEAPON = "양손 무기",
    INVTYPE_WEAPONMAINHAND = "주장비", INVTYPE_WEAPONOFFHAND = "보조장비",
    INVTYPE_SHIELD = "방패", INVTYPE_RANGED = "원거리", INVTYPE_HOLDABLE = "보조장비",
    INVTYPE_THROWN = "투척", INVTYPE_RANGEDRIGHT = "원거리", INVTYPE_RELIC = "유물",
}

local function GetEquipInfoText(link)
    if not link then return "" end
    local _, _, _, _, _, _, itemSubType, _, itemEquipLoc = GetItemInfo(link)
    if not itemEquipLoc or itemEquipLoc == "" then return "" end
    local slotKR = EQUIP_LOC_KR[itemEquipLoc]
    if not slotKR then return "" end
    if itemSubType and itemSubType ~= "" then
        return " (" .. itemSubType .. ", " .. slotKR .. ")"
    end
    return " (" .. slotKR .. ")"
end


local function FormatNumberWithComma(n)
    local formatted = tostring(math.floor(n))
    while true do
        local k
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

local function GetMoneyStringComma(gold)
    return FormatNumberWithComma(gold) .. "골드"
end

local function FormatGoldOnly(gold)
    return FormatNumberWithComma(math.floor(gold)) .. "골드"
end

local function CopperToGoldFloor(copper)
    return math.floor((tonumber(copper) or 0) / 10000)
end

-- AutoAddLoot 상수 정의
local AUTOADDLOOT_TYPE_ALL = 0
local AUTOADDLOOT_TYPE_RAID = 1
local AUTOADDLOOT_TYPE_DISABLE = 2


local function GetRosterNumber()
    local all = {}
    local dict = {}
    for i = 1, MAX_RAID_MEMBERS do
        local name = GetRaidRosterInfo(i)

        if name then
            dict[name] = 1
        end
    end

    dict[UnitName("player")] = 1

    for k in pairs(dict) do
        tinsert(all, k)
    end

    return #all
end

function GUI:Show()
    self.mainframe:Show()
    if self.UpdateLootTableFromDatabase then
        self:UpdateLootTableFromDatabase()
    end
    if self.UpdateSummary then
        self:UpdateSummary()
    end
    if self.UpdateNoBidCount then
        self:UpdateNoBidCount()
    end
    if UpdateAllDistributeLabel then
        UpdateAllDistributeLabel()
    end
    self:RefreshLockedButtons()
    if ADDONSELF.sync and IsInRaid() then
        ADDONSELF.sync:SendHello()
        ADDONSELF.sync:UpdateHostStatus()
        self:RefreshRaidSyncUI()
    end
end

function GUI:Hide()
    self.mainframe:Hide()
end

function GUI:ApplyEditorLock()
    local s = ADDONSELF.sync
    if not s then return end
    local locked = s.enabled and IsInRaid() and not s:IsLedgerEditor()
    self._receiverLocked = locked
    self:SetUILocked(locked)
end

function GUI:SetUILocked(locked)
    local alpha = locked and 0.4 or 1.0

    local buttons = {
        self.addItemBtn,
        self.noBidCountBtn,
        self.checkAllDistributeButton,
        self.recipeNoBeneficiaryButton,
        self.testModeButton,
        self.creditButton,
        self.debitButton,
        self.autoCountBtn,
        self.countdownMainBtn,
        self.countdownStopBtn,
        self.distAssignButton,
    }
    for _, btn in ipairs(buttons) do
        if btn then
            if locked then btn:Disable() else btn:Enable() end
            btn:SetAlpha(alpha)
        end
    end

    if self.qualityFilterButton then
        self.qualityFilterButton:Enable()
        self.qualityFilterButton:SetAlpha(1.0)
    end

    if self.countEdit then
        if locked then self.countEdit:Disable() else self.countEdit:Enable() end
        self.countEdit:SetAlpha(alpha)
    end
    if self.exportEditbox then
        if locked then self.exportEditbox:Disable() else self.exportEditbox:Enable() end
        self.exportEditbox:SetAlpha(alpha)
    end

    self._uiLocked = locked
    if self.lootLogFrame and self.lootLogFrame.Refresh then
        self.lootLogFrame:Refresh()
    end

    self:RefreshLockedButtons()
end

function GUI:RefreshRaidSyncUI()
    if self.UpdateSyncToggleButton then
        self:UpdateSyncToggleButton()
    end
    if self.UpdateDistAssignButton then
        self:UpdateDistAssignButton()
    end
    self:ApplyEditorLock()
end

function GUI:Summary()
    local items = self:GetItemsForTextOutput()

    -- 현재 체크박스 상태 읽기
    local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
    local checkAllDistribute = true
    if checkbox then
        local rawValue = checkbox:GetChecked()
        checkAllDistribute = (rawValue == true) or (rawValue == 1)
    end

    -- checkAllDistribute가 true이면 전체 분배, false이면 득자 제외
    return ADDONSELF.calcavg(items, GUI:GetSplitNumber(), nil, nil, checkAllDistribute)
end

function GUI:GetItemsForTextOutput()
    local ledger = Database:GetCurrentLedger()
    local items = {}
    if not ledger or not ledger.items then
        return items
    end

    local filterLevel = NormalizeQualityFilterLevel(Database:GetConfigOrDefault("filterlevel", 3))
    for i = 1, #ledger.items do
        local item = ledger.items[i]
        if item then
            local include = false
            if item.type == "DEBIT" then
                include = true
            elseif item.type == "CREDIT" and (not item.detail or item.detail.type ~= "ITEM") then
                include = true
            elseif item.detail and item.detail.type == "ITEM" and LedgerRowMatchesPendingOnlyFilter(item, i) then
                local _, _, itemQuality = GetItemInfo(item.detail.item or "")
                if not ItemHiddenByQualityFilter(itemQuality, filterLevel, item.detail and item.detail.item) then
                    include = true
                end
            end

            if include then
                items[#items + 1] = item
            end
        end
    end
    return items
end

local CRLF = ADDONSELF.CRLF

local function iraShowLocalReportInExportBox(text)
    local GUI = ADDONSELF.gui
    if not GUI or not GUI.exportEditbox then
        return
    end
    if GUI.lootLogFrame then
        GUI.lootLogFrame:Hide()
    end
    if GUI.countEdit then
        GUI.countEdit:Hide()
    end
    local scrollFrame = GUI.exportEditbox:GetParent()
    if scrollFrame then
        scrollFrame:Show()
    end
    if GUI.exportButton then
        GUI.exportButton:SetText(L["Close text export"])
    end
    GUI.exportEditbox:SetText(text or "")
    GUI.exportEditbox:SetCursorPosition(0)
    GUI.exportEditbox:HighlightText(0, 0)
end

local function iraGetSpendSummaryTexts(items)
    local totals = {}
    local topName = nil
    local topCost = 0
    local myCost = 0
    local playerName = tostring(UnitName("player") or "")
    local playerShort = playerName:match("^([^%-]+)") or playerName

    for _, item in ipairs(items or {}) do
        local cost = tonumber(item and item.cost) or 0
        if item and item.type == "CREDIT" and cost > 0 then
            local winner = ""
            if ADDONSELF.GetLedgerWinnerName then
                winner = ADDONSELF.GetLedgerWinnerName(item) or ""
            else
                winner = item.winner or item.beneficiary or ""
            end
            winner = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(winner or "")
            if winner ~= "" then
                totals[winner] = (totals[winner] or 0) + cost
                local winnerShort = winner:match("^([^%-]+)") or winner
                if playerShort ~= "" and winnerShort == playerShort then
                    myCost = myCost + cost
                end
                if totals[winner] > topCost then
                    topName = winner
                    topCost = totals[winner]
                end
            end
        end
    end

    local topText = nil
    if topName and topCost > 0 then
        topText = string.format("최다 지출자: %s (%s)", ADDONSELF.FormatBeneficiaryForDisplay(topName), FormatGoldOnly(topCost))
    end

    local myText = nil
    if playerName ~= "" then
        myText = string.format("내 경매지출: %s (%s)", ADDONSELF.FormatBeneficiaryForDisplay(playerName), FormatGoldOnly(myCost))
    end
    return topText, myText
end

local function iraShowBottomRevenueTooltip(anchor, audit, showMoneyAudit)
    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    if not showMoneyAudit or not audit then
        GameTooltip:SetText("총수익", 1.0, 0.84, 0.0)
        GameTooltip:AddLine("이상 여부 실시간 검사는 공격대 상태에서만 표시됩니다.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
        return
    end

    if audit.anomaly then
        GameTooltip:SetText("총수익 이상 감지", 1.0, 0.35, 0.35)
    else
        GameTooltip:SetText("총수익 정상", 0.2, 1.0, 0.2)
    end

    GameTooltip:AddLine("시작 소지금: " .. FormatGoldOnly(CopperToGoldFloor(audit.startMoneyCopper or 0)), 0.9, 0.9, 0.9)
    GameTooltip:AddLine("경매 수입 합계: " .. FormatGoldOnly(CopperToGoldFloor(audit.receivedAuctionCopper or 0)), 0.9, 0.9, 0.9)
    GameTooltip:AddLine("레이드 중 골드 변동: 계산 제외", 0.65, 0.65, 0.65)
    if (tonumber(audit.explicitExpenseCopper) or 0) > 0 then
        GameTooltip:AddLine("기록된 지출 합계: " .. FormatGoldOnly(CopperToGoldFloor(audit.explicitExpenseCopper or 0)), 0.9, 0.9, 0.9)
    end
    GameTooltip:AddLine("예상 소지금(분배 전): " .. FormatGoldOnly(CopperToGoldFloor(audit.preDistributionExpectedMoneyCopper or 0)), 1.0, 0.82, 0.2)
    if (tonumber(audit.distributionEligibleCount) or 0) > 0 then
        local modeText = (audit.myEligibleForDistribution and "내 분배 포함" or "내 분배 제외")
        GameTooltip:AddLine("예상 소지금(분배 후): " .. FormatGoldOnly(CopperToGoldFloor(audit.postDistributionExpectedMoneyCopper or 0)), 1.0, 0.82, 0.2)
        GameTooltip:AddLine("분배 기준: " .. modeText .. " / 개인당 " .. FormatGoldOnly(CopperToGoldFloor(audit.myDistributionShareCopper or 0)), 0.8, 0.88, 1.0, true)
        GameTooltip:AddLine("판정 기준: 현재 골드에 더 가까운 쪽(" .. ((audit.usePostDistribution and true or false) and "분배 후" or "분배 전") .. ")", 0.75, 0.82, 0.95, true)
    else
        GameTooltip:AddLine("예상 소지금: " .. FormatGoldOnly(CopperToGoldFloor(audit.expectedMoneyCopper or 0)), 1.0, 0.82, 0.2)
    end
    GameTooltip:AddLine("현재 소지금: " .. FormatGoldOnly(CopperToGoldFloor(audit.currentMoneyCopper or 0)), 1.0, 0.82, 0.2)

    local diffCopper = math.floor(tonumber(audit.diffCopper) or 0)
    local diffText = FormatGoldOnly(CopperToGoldFloor(math.abs(diffCopper)))
    if diffCopper > 0 then
        GameTooltip:AddLine("차이: +" .. diffText, 1.0, 0.35, 0.35)
    elseif diffCopper < 0 then
        GameTooltip:AddLine("차이: -" .. diffText, 1.0, 0.35, 0.35)
    else
        GameTooltip:AddLine("차이: 0골드", 0.2, 1.0, 0.2)
    end

    local thresholdText = FormatGoldOnly(CopperToGoldFloor(audit.anomalyThresholdCopper or 0))
    if audit.anomaly then
        GameTooltip:AddLine(thresholdText .. " 이상 차이가 나서 '(이상)'으로 표시됩니다.", 0.95, 0.8, 0.8, true)
    else
        GameTooltip:AddLine("현재 장부 기준 금액과 소지금이 " .. thresholdText .. " 미만 차이입니다.", 0.8, 0.95, 0.8, true)
    end
    GameTooltip:Show()
end

function GUI:UpdateSummary()
    if not self.summaryLabel or not self.countEdit then
        return
    end
    local profit, avg, revenue, expense = self:Summary()
    local displayItems = self.GetItemsForTextOutput and self:GetItemsForTextOutput() or nil
    local splitNumber = self.GetSplitNumber and self:GetSplitNumber() or 0
    local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
    local checkAllDistribute = true
    if checkbox then
        local rawValue = checkbox:GetChecked()
        checkAllDistribute = (rawValue == true) or (rawValue == 1)
    end
    local audit = Database.GetMoneyAuditState and Database:GetMoneyAuditState(displayItems, splitNumber, checkAllDistribute) or nil
    local topSpenderText, mySpendText = iraGetSpendSummaryTexts(displayItems)
    local showMoneyAudit = audit and IsInRaid()
    self.bottomRevenueAudit = audit
    self.bottomRevenueShowMoneyAudit = showMoneyAudit and true or false
    local anomalyTag = ""
    if showMoneyAudit and audit.anomaly then
        anomalyTag = " |cffff4444(이상)|r"
    end

    local avgColor = (GUI._checkAllDistributeState and "|cFF00FF00" or "|cFF4D9BFF")
    self.summaryLabel:SetText(
        L["Revenue"] .. " " .. FormatGoldOnly(revenue) .. anomalyTag
        .. "  ·  " .. L["Expense"] .. " " .. FormatGoldOnly(expense)
        .. "  ·  " .. L["Net Profit"] .. " " .. FormatGoldOnly(profit)
        .. CRLF
        .. avgColor .. "개인당 " .. FormatGoldOnly(avg) .. "|r"
        .. "  ·  파티당 " .. FormatGoldOnly(avg*5)
        .. CRLF
        .. "4명당 " .. FormatGoldOnly(avg*4)
        .. "  ·  3명당 " .. FormatGoldOnly(avg*3)
        .. "  ·  2명당 " .. FormatGoldOnly(avg*2)
    )
    if self.bottomRevenueLabel then
        self.bottomRevenueLabel:SetText("총수익 " .. FormatGoldOnly(revenue))
    end
    if self.bottomRevenueAnomalyLabel then
        if showMoneyAudit and audit.anomaly then
            self.bottomRevenueAnomalyLabel:SetText(string.format("|cffff6666(이상) [%s]|r", FormatGoldOnly(CopperToGoldFloor(math.abs(audit.diffCopper)))))
            self.bottomRevenueAnomalyLabel:Show()
        else
            self.bottomRevenueAnomalyLabel:SetText("")
            self.bottomRevenueAnomalyLabel:Hide()
        end
    end
    if self.bottomRevenueTooltipHitbox and self.bottomRevenueLabel then
        self.bottomRevenueTooltipHitbox:ClearAllPoints()
        self.bottomRevenueTooltipHitbox:SetPoint("TOPLEFT", self.bottomRevenueLabel, "TOPLEFT", -4, 4)
        if self.bottomRevenueAnomalyLabel and self.bottomRevenueAnomalyLabel:IsShown() then
            self.bottomRevenueTooltipHitbox:SetPoint("BOTTOMRIGHT", self.bottomRevenueAnomalyLabel, "BOTTOMRIGHT", 4, -2)
        else
            self.bottomRevenueTooltipHitbox:SetPoint("BOTTOMRIGHT", self.bottomRevenueLabel, "BOTTOMRIGHT", 4, -4)
        end
    end
    if self.bottomTopSpenderLabel then
        if topSpenderText then
            self.bottomTopSpenderLabel:SetText("|cffd8d8d8" .. topSpenderText .. "|r")
            self.bottomTopSpenderLabel:Show()
        else
            self.bottomTopSpenderLabel:SetText("")
            self.bottomTopSpenderLabel:Hide()
        end
    end
    if self.bottomMySpendLabel then
        if mySpendText then
            self.bottomMySpendLabel:SetText("|cffb8d8ff" .. mySpendText .. "|r")
            self.bottomMySpendLabel:Show()
        else
            self.bottomMySpendLabel:SetText("")
            self.bottomMySpendLabel:Hide()
        end
    end
    if self.bottomStartGoldLabel then
        local startGoldText = nil
        if audit and audit.startMoneyCopper ~= nil then
            startGoldText = "레이드 시작시 내 골드: " .. FormatGoldOnly(CopperToGoldFloor(audit.startMoneyCopper or 0))
        end
        if startGoldText then
            self.bottomStartGoldLabel:SetText("|cffc8c8a0" .. startGoldText .. "|r")
            self.bottomStartGoldLabel:Show()
        else
            self.bottomStartGoldLabel:SetText("")
            self.bottomStartGoldLabel:Hide()
        end
    end
    checkTrade = 1

    if self.UpdateNoBidCount then self:UpdateNoBidCount() end
end

function GUI:GetSplitNumber()
    return tonumber(self.countEdit:GetText()) or 0
end

function GUI:GetBeneficiaryCount()
    local ledger = Database:GetCurrentLedger()
    local beneficiaries = {}

    for _, item in pairs(ledger["items"]) do
        -- genexport/genreport 와 동일 로직: 자동 캡처(detail.item 있음) 아이템의 beneficiary 만 카운트.
        local bene = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(item.beneficiary or "")
        if bene and bene ~= "" and item.type == "CREDIT" and item.cost and item.cost > 0
                and item.noBeneficiary ~= true
                and item.detail and item.detail.item then
            beneficiaries[bene] = true
        end
    end

    local count = 0
    for _ in pairs(beneficiaries) do
        count = count + 1
    end

    return count
end


function GUI:UpdateLootTableFromDatabase()
    if not self.mainframe or not self.lootLogFrame then
        return  -- 아직 초기화되지 않았으면 무시
    end
    if not self.mainframe:IsShown() then
        return  -- 아직 초기화되지 않았으면 무시
    end

    local data = {}
    local ledger = Database:GetCurrentLedger()
    Database:ApplyDisenchantHandoffNoBeneficiaryFlagsIfNeeded()

    -- 현재 UI의 DEBIT 아이템 득자 정보 보존
    local currentDebitBeneficiaries = {}

    -- 현재 UI 테이블에서 DEBIT 득자 정보 수집 (실시간 동기화용)
    if self.lootLogFrame and self.lootLogFrame.data then
        for _, entry in ipairs(self.lootLogFrame.data) do
            if entry.realItemIdx then
                local ledgerItem = ledger["items"][entry.realItemIdx]
                if ledgerItem and ledgerItem.type == "DEBIT" then
                    -- entry.beneficiary와 cols[5].value 모두 확인하여 최신 값 수집
                    local uiBeneficiary = entry.beneficiary or (entry.cols and entry.cols[5] and entry.cols[5].value) or ""
                    -- [알수없음]을 빈 문자열로 변환하여 DEBIT 초기값 문제 해결
                    if uiBeneficiary == L["[Unknown]"] then
                        uiBeneficiary = ""
                    end
                    if uiBeneficiary ~= "" then
                        currentDebitBeneficiaries[entry.realItemIdx] = uiBeneficiary
                    end
                end
            end
        end
    end

    -- fallback: 데이터베이스에서 보존 (UI에 없는 경우)
    for i = 1, #ledger["items"] do
        local item = ledger["items"][i]
        if item and item.type == "DEBIT" and item.beneficiary and item.beneficiary ~= "" and not currentDebitBeneficiaries[i] then
            currentDebitBeneficiaries[i] = item.beneficiary
        end
    end

    -- 아이템 그룹화를 위한 맵: {아이템ID_수혜자_거래금액 = {count, itemIndices, item}}
    local itemGroups = {}

    -- 1단계: 모든 CREDIT 및 DEBIT 아이템 그룹화
    for i = 1, #ledger["items"] do
        local item = ledger["items"][i]

        -- CREDIT 또는 DEBIT 타입이고 detail이 ITEM 타입인 것만 그룹화
        if item and (item.type == "CREDIT" or item.type == "DEBIT") and item.detail and item.detail.type == "ITEM" and LedgerRowMatchesPendingOnlyFilter(item, i) then
            local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemIcon, _, itemSellPrice = GetItemInfo(item.detail.item)

            itemName = itemName or "Unknown Item"
            local itemRarity = itemQuality or 0

            local filterLevel = NormalizeQualityFilterLevel(Database:GetConfigOrDefault("filterlevel", 3))
            if ItemHiddenByQualityFilter(itemQuality, filterLevel, item.detail and item.detail.item) then
                -- skip: 품질 필터(고급+=희귀+·녹색 도안만)
            else
            local beneficiary = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(GetEntryDisplayBeneficiary(item, i) or "")
            local cost = item.cost or 0
            local saleState = item.saleState or "open"
            -- 금액 정규화
            local normalizedCost = string.format("%.2f", tonumber(cost) or 0)

            -- 저장된 reliableItemID를 항상 우선적으로 사용
            local safeItemID = item.detail.reliableItemID

            if not safeItemID then
                -- 링크가 비어 있거나 손상된 레거시 row 도 안전하게 그룹 키를 만들 수 있어야 한다.
                local rawItemLink = tostring(item.detail.item or "")
                local firstByte = string.byte(rawItemLink, 1) or 0
                local lastByte = string.byte(rawItemLink, -1) or 0
                safeItemID = string.len(rawItemLink) .. "_" .. firstByte .. "_" .. lastByte
            end

            local splitTag = tostring(item._manualSplitGroup or item.manualSplitGroup or "")
            local key = tostring(safeItemID) .. "_" .. beneficiary .. "_" .. normalizedCost .. "_" .. saleState .. "_" .. splitTag

            if not itemGroups[key] then
                itemGroups[key] = {
                    count = 0,
                    itemIndices = {},
                    itemData = item,
                    displaySeq = tonumber(item.seq) or i,
                }
            end

            itemGroups[key].count = itemGroups[key].count + 1
            table.insert(itemGroups[key].itemIndices, i)
            itemGroups[key].displaySeq = math.max(tonumber(itemGroups[key].displaySeq) or 0, tonumber(item.seq) or i)
            end -- else (품질 필터)
        end
    end

    -- DEBIT 항목 및 그룹화되지 않은 CREDIT 항목 추가
    for i = #ledger["items"], 1, -1 do
        local item = ledger["items"][i]
        if item then
            local shouldShow = false
            local uiBeneficiary = ""

            -- 미확정만 보기에서는 장비/도안 CREDIT ITEM 줄만 표시한다.
            if GUI._showPendingOnly then
                shouldShow = false
            -- DEBIT 항목은 항상 표시
            elseif item.type == "DEBIT" then
                shouldShow = true
                -- UI에서 수집된 최신 beneficiary 값을 우선 적용
                -- 빈 문자열인 경우 그대로 사용 (L["[Unknown]"]으로 변환하지 않음)
                uiBeneficiary = currentDebitBeneficiaries[i] or item.beneficiary or ""
                -- [알수없음]을 빈 문자열로 변환하여 DEBIT 초기값 문제 해결
                if uiBeneficiary == L["[Unknown]"] then
                    uiBeneficiary = ""
                end
            -- CREDIT 항목 중 ITEM 타입이 아닌 것들만 표시 (ITEM 타입은 위에서 그룹화 처리됨)
            elseif item.type == "CREDIT" and (not item.detail or item.detail.type ~= "ITEM") then
                shouldShow = true
            end

            if shouldShow then
                table.insert(data, {
                    ["cols"] = {
                        { ["value"] = i },
                        { ["value"] = "" },  -- 마이크 열
                        { ["value"] = tonumber(item.seq) or i },
                        { ["value"] = "" },  -- 아이콘+항목 병합 열(표시용 셀 데이터 없음)
                        { ["value"] = uiBeneficiary },
                        { ["value"] = LedgerEntrySignalState(item) },
                        { ["value"] = "" },
                        { ["value"] = item.noBeneficiary or false },
                        { ["value"] = item.confirmed and true or false }
                    },
                    ["realItemIdx"] = i,
                    ["realItemData"] = item,
                    ["type"] = item.type,
                    ["detail"] = item.detail,
                    ["cost"] = item.cost,
                    ["noBeneficiary"] = item.noBeneficiary,
                    ["isStacked"] = false,
                    ["beneficiary"] = uiBeneficiary,  -- entry.beneficiary 필드에 UI 값 초기화
                    ["saleState"] = item.saleState or "open",
                    ["confirmed"] = item.confirmed and true or false,
                })
            end
        end
    end

    -- 그룹화된 아이템 추가 (최신순)
    local sortedGroups = {}
    for key, group in pairs(itemGroups) do
        table.insert(sortedGroups, {key = key, group = group})
    end
    -- 그룹을 대표 행의 seq(없으면 인덱스) 기준 최신순으로 정렬
    table.sort(sortedGroups, function(a, b)
        local aSeq = tonumber(a.group and a.group.displaySeq) or 0
        local bSeq = tonumber(b.group and b.group.displaySeq) or 0
        return aSeq > bSeq
    end)

    for _, sortedData in ipairs(sortedGroups) do
        local group = sortedData.group
        -- 그룹의 첫 번째 아이템으로 표시 (원본 데이터는 수정하지 않음)
        local firstItem = group.itemData
        local firstItemIdx = group.itemIndices[1]

        -- UI에서 수집된 최신 beneficiary 값을 우선 적용
        local uiBeneficiary = currentDebitBeneficiaries[firstItemIdx] or GetEntryDisplayBeneficiary(firstItem, firstItemIdx) or ""
        -- [알수없음]을 빈 문자열로 변환하여 DEBIT 초기값 문제 해결
        if uiBeneficiary == L["[Unknown]"] then
            uiBeneficiary = ""
        end

                table.insert(data, {
            ["cols"] = {
                { ["value"] = firstItemIdx },
                { ["value"] = "" },
                { ["value"] = tonumber(group.displaySeq) or tonumber(firstItem.seq) or firstItemIdx },
                { ["value"] = "" },
                { ["value"] = uiBeneficiary },
                { ["value"] = LedgerEntrySignalState(firstItem) },
                { ["value"] = "" },
                { ["value"] = firstItem.noBeneficiary or false },
                { ["value"] = firstItem.confirmed and true or false }
            },
            ["realItemIdx"] = firstItemIdx,
            ["realItemData"] = firstItem,  -- 원본 데이터 참조 (수정 안 함)
            ["type"] = firstItem.type,
            ["detail"] = firstItem.detail,
            ["cost"] = firstItem.cost,
            ["noBeneficiary"] = firstItem.noBeneficiary,
            ["isStacked"] = true,
            ["stackCount"] = group.count,  -- 표시 데이터에만 저장
            ["stackIndices"] = group.itemIndices,  -- 표시 데이터에만 저장
            ["beneficiary"] = uiBeneficiary,  -- entry.beneficiary 필드에 UI 값 초기화
            ["saleState"] = firstItem.saleState or "open",
            ["confirmed"] = firstItem.confirmed and true or false,
        })
    end

    table.sort(data, function(a, b)
        local aSeq = tonumber(a and a.cols and a.cols[3] and a.cols[3].value) or 0
        local bSeq = tonumber(b and b.cols and b.cols[3] and b.cols[3].value) or 0
        if aSeq ~= bSeq then
            return aSeq > bSeq
        end
        return (tonumber(a and a.realItemIdx) or 0) > (tonumber(b and b.realItemIdx) or 0)
    end)

    
    -- ScrollingTable에 데이터 설정
    self.lootLogFrame:SetData(data)
    self:RefreshLockedButtons()

    -- UI 업데이트 후 보존한 DEBIT 득자 정보를 데이터베이스에 복원
    C_Timer.After(0.1, function()
        for idx, beneficiary in pairs(currentDebitBeneficiaries) do
            if ledger.items[idx] and ledger.items[idx].type == "DEBIT" then
                ledger.items[idx].beneficiary = beneficiary

                -- UI에도 다시 적용
                if self.lootLogFrame and self.lootLogFrame.data then
                    for _, entry in ipairs(self.lootLogFrame.data) do
                        if entry.realItemIdx == idx then
                            entry.cols[5].value = beneficiary
                            entry.realItemData.beneficiary = beneficiary
                            break
                        end
                    end
                end
            end
        end
    end)

    self:UpdateSummary()
    UpdateAllDistributeLabel() -- 전리품 업데이트 시 라벨도 업데이트 (득자 수 변경 가능성)
end

function GUI:StringToMoney(lootedCurrencyAsText)
    local digits = {}
    local digitsCounter = 0;
    lootedCurrencyAsText:gsub("%d+",
        function(i)
            table.insert(digits, i)
            digitsCounter = digitsCounter + 1
        end
    )
    local gold = 0
    if not IsInGroup() then
        if digitsCounter >= 3 then
            gold = digits[1]
        end
    else
        if digitsCounter >= 4 then
            gold = digits[1]
        end
    end

    return gold
end



local function GetEntryFromUI(rowFrame, cellFrame, data, cols, row, realrow, column, table)
    local rowdata = table:GetRow(realrow)
    if not rowdata then
        return nil
    end
    local idx = rowdata.realItemIdx or (rowdata["cols"] and rowdata["cols"][1] and rowdata["cols"][1].value)
    -- Return the display row so stacked metadata (stackCount/stackIndices) survives
    -- rendering, while helpers can still reach the real ledger row via realItemData.
    local entry = rowdata
    return entry, idx
end

local function CopyIndexList(indices)
    if type(indices) ~= "table" or #indices == 0 then
        return nil
    end
    local copied = {}
    for i, v in ipairs(indices) do
        copied[i] = v
    end
    return copied
end

local function BeneficiaryEditIndices(entry, idx, stackIndices)
    local copied = CopyIndexList(stackIndices)
    if copied then
        return copied
    end
    copied = CopyIndexList(entry and entry.stackIndices)
    if copied then
        return copied
    end
    if idx then
        return { idx }
    end
    return {}
end

--- 득자가 *마력추출* 이고 낙찰 0인 CREDIT 줄에 무득 플래그·동기화 반영.
local function SyncNoBeneficiaryForDisenchantHandoffCredit(entry, indicesList, savedBeneficiary)
    if entry.type ~= "CREDIT" then
        return
    end
    if (tonumber(entry.cost) or 0) ~= 0 then
        return
    end
    if not ADDONSELF.IsDisenchantHandoffBeneficiary(savedBeneficiary) then
        return
    end
    local ledger = Database:GetCurrentLedger()
    if not ledger or not ledger.items then
        return
    end
    local changed = false
    for _, sid in ipairs(indicesList) do
        local row = ledger.items[sid]
        if row and row.type == "CREDIT" and not Database:IsNoBeneficiarySetOnRow(row) then
            row.noBeneficiary = true
            changed = true
            if ADDONSELF.sync then
                local rid = row.detail and row.detail.reliableItemID
                local iLink = row.detail and row.detail.item
                ADDONSELF.sync:BroadcastNoBeneficiary(sid, rid, true, iLink)
            end
        end
    end
    if changed then
        Database:OnLedgerItemsChange()
    end
end

LedgerItemSaleState = function(entry)
    local row = entry and entry.realItemData or entry
    if not row or row.type ~= "CREDIT" or not row.detail or row.detail.type ~= "ITEM" then
        return nil
    end
    return row.saleState
end

LedgerItemIsConfirmed = function(entry)
    local row = entry and entry.realItemData or entry
    local st = LedgerItemSaleState(row)
    return st == "confirmed" or (row and row.confirmed and true or false)
end

LedgerEntrySignalState = function(entry)
    if LedgerItemIsConfirmed(entry) then
        return "confirmed"
    end
    if entry and entry.type == "CREDIT" and entry.detail and entry.detail.type == "ITEM" then
        local st = LedgerItemSaleState(entry)
        if st == "priced" then
            return "ready"
        end
        return "draft"
    end
    local cost = tonumber(entry and entry.cost) or 0
    local bene = tostring(entry and entry.beneficiary or "")
    local hasDisplay = entry and entry.detail and tostring(entry.detail.displayname or "") ~= ""
    if cost > 0 or (bene ~= "" and bene ~= L["[Unknown]"]) or hasDisplay then
        return "ready"
    end
    return "draft"
end

LedgerSignalColor = function(state)
    if state == "confirmed" then
        return 0.20, 0.82, 0.20
    end
    if state == "ready" then
        return 0.96, 0.78, 0.12
    end
    return 0.88, 0.22, 0.22
end

local function CreateCellUpdate(cb)
    return function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
        if not fShow then
            return
        end

        local rowdata = table:GetRow(realrow)
        cellFrame._iraStackIndices = CopyIndexList(rowdata and rowdata.stackIndices) or nil

        local entry, idx = GetEntryFromUI(rowFrame, cellFrame, data, cols, row, realrow, column, table)

        if entry then
            cb(cellFrame, entry, idx, rowdata)
        end
    end
end

-- tricky way to clear all editbox focus
local clearAllFocus = (function()
    local fedit = CreateFrame("EditBox")
    fedit:SetAutoFocus(false)
    fedit:SetScript("OnEditFocusGained", fedit.ClearFocus)

    return function()
        local focusFrame = GetCurrentKeyBoardFocus()

        if not focusFrame then
            return
        end

        local p = focusFrame:GetParent()
        local owned = false
        while p ~= nil do
            if p == GUI.mainframe then
                fedit:SetFocus()
                fedit:ClearFocus()
                return
            end
            p = p:GetParent()
        end
    end
end)()

function GUI:ShowSyncTransmitProgress(total)
    if not self.syncTransmitOverlay then return end
    total = math.max(1, math.floor(tonumber(total) or 1))
    self._syncTransmitTotal = total
    self.syncTransmitTitle:SetText(L["Raid sync sending"])
    self.syncTransmitStatusBar:SetMinMaxValues(0, total)
    self.syncTransmitStatusBar:SetValue(0)
    self.syncTransmitCountText:SetFormattedText("%d / %d", 0, total)
    self.syncTransmitOverlay:Show()
end

function GUI:SetSyncTransmitProgress(sent, total)
    if not self.syncTransmitOverlay then return end
    total = total or self._syncTransmitTotal or 1
    total = math.max(1, math.floor(tonumber(total) or 1))
    sent = math.max(0, math.floor(tonumber(sent) or 0))
    if sent > total then sent = total end
    self.syncTransmitStatusBar:SetMinMaxValues(0, total)
    self.syncTransmitStatusBar:SetValue(sent)
    self.syncTransmitCountText:SetFormattedText("%d / %d", sent, total)
end

function GUI:HideSyncTransmitProgress()
    if self.syncTransmitOverlay then
        self.syncTransmitOverlay:Hide()
    end
    self._syncTransmitTotal = nil
end

function GUI:Init()
    checkf = 0;
    checkTrade = 1;
    Database:SetConfig("autoaddloot", AUTOADDLOOT_TYPE_RAID)

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetWidth(715)
    f:SetHeight(543)
    if ADDONSELF.theme and ADDONSELF.theme.ApplyFrame then
        ADDONSELF.theme:ApplyFrame(f)
    else
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            tile = false,
            tileSize = 32,
            edgeSize = 1,
            insets = {left = 0, right = 0, top = 0, bottom = 0}
        })
        f:SetBackdropColor(0, 0, 0)
    end
    -- TOP 앵커: 화면 중앙 +284 위(원래 CENTER 568 높이의 TOP 위치)에 고정 → 높이 줄여도 TOP 유지, 하단만 잘림
    f:SetPoint("TOP", UIParent, "CENTER", 0, 284)
    f:SetToplevel(true)
    f:EnableMouse(true)

    -- extraBg 제거됨 (메인 프레임 내에 모든 UI 배치)

    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnMouseDown", function()
        clearAllFocus()
        -- 모든 커스텀 드롭다운 닫기
        if GUI.customDropdowns then
            for _, dropdown in pairs(GUI.customDropdowns) do
                dropdown:Hide()
            end
        end
    end)
    f:Hide()
    f:SetScript("OnHide", function()
        if GUI.waitingForManualItem then
            GUI.SetManualItemWaiting(false)
        end
    end)
    f:HookScript("OnShow", function()
        if GUI.UpdateLootTableFromDatabase then
            GUI:UpdateLootTableFromDatabase()
        end
        if GUI.UpdateSummary then
            GUI:UpdateSummary()
        end
        if GUI.UpdateNoBidCount then
            GUI:UpdateNoBidCount()
        end
        if UpdateAllDistributeLabel then
            UpdateAllDistributeLabel()
        end
        if GUI.RefreshLockedButtons then
            GUI:RefreshLockedButtons()
        end
        if ADDONSELF.sync and IsInRaid() then
            ADDONSELF.sync:SendHello()
            ADDONSELF.sync:UpdateHostStatus()
            if GUI.RefreshRaidSyncUI then
                GUI:RefreshRaidSyncUI()
            end
        end
    end)

    self.mainframe = f

    do
        local holder = CreateFrame("Frame", "IberisRaidAuctionSyncTransmitOverlay", f, "BackdropTemplate")
        holder:SetSize(340, 62)
        holder:SetPoint("CENTER", f, "CENTER", 0, 50)
        holder:SetFrameStrata("DIALOG")
        holder:SetFrameLevel(f:GetFrameLevel() + 80)
        holder:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        holder:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
        holder:SetBackdropBorderColor(0.35, 0.55, 0.85, 1)
        holder:Hide()
        holder:EnableMouse(true)

        local title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", holder, "TOP", 0, -10)
        title:SetTextColor(0.85, 0.9, 1)

        local sb = CreateFrame("StatusBar", nil, holder)
        sb:SetFrameLevel(2)
        sb:SetSize(300, 16)
        sb:SetPoint("TOP", holder, "TOP", 0, -30)
        sb:SetMinMaxValues(0, 1)
        sb:SetValue(0)
        sb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        local tex = sb:GetStatusBarTexture()
        if tex then
            tex:SetVertexColor(0.25, 0.75, 0.35)
        end

        local countWrap = CreateFrame("Frame", nil, holder)
        countWrap:SetSize(300, 16)
        countWrap:SetPoint("TOP", holder, "TOP", 0, -30)
        countWrap:SetFrameLevel(sb:GetFrameLevel() + 15)
        local countFs = countWrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countFs:SetPoint("CENTER", countWrap, "CENTER", 0, 0)
        countFs:SetTextColor(1, 1, 1)
        countFs:SetShadowOffset(1, -1)
        countFs:SetShadowColor(0, 0, 0, 0.85)

        self.syncTransmitOverlay = holder
        self.syncTransmitTitle = title
        self.syncTransmitStatusBar = sb
        self.syncTransmitCountText = countFs
    end

    -- 우측 상단 최소화 버튼 (테마: 호버 녹색 강조)
    do
        local minimizeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        minimizeBtn:SetWidth(24)
        minimizeBtn:SetHeight(22)
        minimizeBtn:SetPoint("TOPRIGHT", f, -37, -7)
        minimizeBtn:SetFrameStrata("HIGH")

        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(minimizeBtn, {
                bgHover     = { 0.20, 0.80, 0.20, 0.95 },
                borderHover = { 0.40, 1.00, 0.40, 1.00 },
                bgPressed   = { 0.10, 0.60, 0.10, 1.00 },
            })
        else
            minimizeBtn:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            minimizeBtn:SetBackdropColor(0.6, 0.4, 0.05, 0.9)
            minimizeBtn:SetBackdropBorderColor(0.8, 0.6, 0.1, 1.0)
        end

        local text = minimizeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetTextColor(1, 1, 1)
        text:SetText("-")
        text:SetPoint("CENTER", 0, 0)

        minimizeBtn:SetScript("OnClick", function()
            f:Hide()
            if GUI.minimizeIcon then
                GUI.minimizeIcon:Show()
            end
        end)
    end

    -- 우측 상단 X 닫기 버튼 (테마: 호버 빨강 강조)
    do
        local closeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        closeBtn:SetWidth(24)
        closeBtn:SetHeight(22)
        closeBtn:SetPoint("TOPRIGHT", f, -12, -7)
        closeBtn:SetFrameStrata("HIGH")

        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(closeBtn, {
                bgHover     = { 0.80, 0.20, 0.20, 0.95 },
                borderHover = { 1.00, 0.40, 0.40, 1.00 },
                bgPressed   = { 0.60, 0.10, 0.10, 1.00 },
            })
        else
            closeBtn:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            closeBtn:SetBackdropColor(0.55, 0.1, 0.1, 0.9)
            closeBtn:SetBackdropBorderColor(0.8, 0.2, 0.2, 1.0)
        end

        local text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetTextColor(1, 1, 1)
        text:SetText("X")
        text:SetPoint("CENTER", 0, 0)

        closeBtn:SetScript("OnClick", function() f:Hide() end)
    end

    -- 제목 (좌측 x=13: 아이템 리스트 좌측 정렬)
    do
        local titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -10)
        titleText:SetTextColor(1, 0.82, 0, 1)
        local _ver = (ADDONSELF.GetAddOnVersion and ADDONSELF.GetAddOnVersion()) or "1.00"
        titleText:SetText("|cff91d7f2IberisRaidAuction|r  |cff909090made by 서약선  ver. " .. _ver .. "|r")
        self.mainTitleText = titleText
    end

    -- 메인 창 카운트다운 버튼들
    do
        GUI.autoCountEnabled = true

        local function stopAndResume()
            if GUI.countdownActive then
                GUI.countdownActive = false
                if GUI.countdownTimer then
                    GUI.countdownTimer = nil
                end
                local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                    count = "--- %d",
                    closed = "--- 입찰 마감 ---",
                    resume = "--- 신규 입찰 ! 재개합니다 ---"
                })
                SendChatMessage(messages.resume, "RAID_WARNING")
            end
        end

        local numberPattern = "%d+"
        local koreanNumbers = { "일", "이", "삼", "사", "오", "육", "칠", "팔", "구", "십",
            "백", "천", "만", "억", "원" }

        local function msgContainsNumber(msg)
            if msg:match(numberPattern) then return true end
            for _, kn in ipairs(koreanNumbers) do
                if msg:find(kn, 1, true) then return true end
            end
            return false
        end

        local function isCountdownMessage(msg)
            local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                count = "--- %d",
                closed = "--- 입찰 마감 ---",
                resume = "--- 신규 입찰 ! 재개합니다 ---"
            })
            local countEsc = messages.count:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%d", "%%d+")
            if msg:match("^" .. countEsc .. "$") then return true end
            if msg == messages.closed then return true end
            if msg == messages.resume then return true end
            return false
        end

        local autoCountFrame = CreateFrame("Frame")
        autoCountFrame:SetScript("OnEvent", function(_, _, msg, sender)
            if not GUI.autoCountEnabled then return end
            if not GUI.countdownActive then return end
            if isCountdownMessage(msg) then return end
            if msgContainsNumber(msg) then
                stopAndResume()
            end
        end)

        -- 자동카운트 버튼
        local autoBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        autoBtn:SetWidth(80)
        autoBtn:SetHeight(50)
        autoBtn:SetPoint("BOTTOMLEFT", f, 450, 18)
        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            autoBtn:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
        else
            autoBtn:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
        end
        autoBtn:SetBackdropColor(0.20, 0.10, 0.30, 0.90)
        autoBtn:SetBackdropBorderColor(0.65, 0.45, 1.00, 1.0)

        local autoBtnText = autoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        autoBtnText:SetTextColor(0.85, 0.70, 1.00)
        autoBtnText:SetText("자동")
        autoBtnText:SetPoint("CENTER", 0, 0)

        local function updateAutoBtnStyle()
            if GUI.autoCountEnabled then
                autoBtn:SetBackdropColor(0.20, 0.10, 0.30, 0.90)
                autoBtn:SetBackdropBorderColor(0.65, 0.45, 1.00, 1.0)
                autoBtnText:SetTextColor(0.85, 0.70, 1.00)
                autoBtnText:SetText("자동")
                autoCountFrame:RegisterEvent("CHAT_MSG_RAID")
                autoCountFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
                autoCountFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
            else
                autoBtn:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                autoBtn:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
                autoBtnText:SetTextColor(0.5, 0.5, 0.5)
                autoBtnText:SetText("수동")
                autoCountFrame:UnregisterAllEvents()
            end
        end

        autoBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("자동 카운트다운 정지")
            GameTooltip:AddLine("활성화 시, 카운트다운 중 누군가 채팅에", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("숫자(100, 백 등)를 포함한 메시지를 보내면", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("자동으로 정지 후 재개 메시지를 전송합니다.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        autoBtn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        autoBtn:SetScript("OnClick", function()
            GUI.autoCountEnabled = not GUI.autoCountEnabled
            updateAutoBtnStyle()
        end)
        updateAutoBtnStyle()

        -- 카운트다운 시작 버튼
        local countdownBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        countdownBtn:SetWidth(80)
        countdownBtn:SetHeight(50)
        countdownBtn:SetPoint("LEFT", autoBtn, "RIGHT", 5, 0)
        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            countdownBtn:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
        else
            countdownBtn:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
        end
        countdownBtn:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
        countdownBtn:SetBackdropBorderColor(0.15, 0.50, 0.15, 1.0)

        local btnText = countdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetTextColor(0.2, 0.9, 0.2)
        btnText:SetText("카운트시작")
        btnText:SetPoint("CENTER", 0, 0)

        countdownBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
            self:SetBackdropBorderColor(0.20, 0.80, 0.20, 1.0)
            btnText:SetTextColor(0.3, 1, 0.3)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("카운트다운 시작 (5>1)")
            GameTooltip:Show()
        end)
        countdownBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
            self:SetBackdropBorderColor(0.15, 0.50, 0.15, 1.0)
            btnText:SetTextColor(0.2, 0.9, 0.2)
            GameTooltip:Hide()
        end)
        countdownBtn:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.05, 0.05, 0.07, 1.0)
            btnText:SetTextColor(0.1, 0.6, 0.1)
        end)
        countdownBtn:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
            btnText:SetTextColor(0.3, 1, 0.3)
        end)

        countdownBtn:SetScript("OnClick", function()
            if not GUI.countdownActive then
                GUI.countdownActive = true
                GUI.currentCount = 5

                local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                    count = "--- %d",
                    closed = "--- 입찰 마감 ---",
                    resume = "--- 신규 입찰 ! 재개합니다 ---"
                })

                SendChatMessage(string.format(messages.count, GUI.currentCount), "RAID_WARNING")

                local function countStep()
                    if GUI.countdownActive and GUI.currentCount > 1 then
                        GUI.currentCount = GUI.currentCount - 1
                        SendChatMessage(string.format(messages.count, GUI.currentCount), "RAID_WARNING")
                        GUI.countdownTimer = C_Timer.After(1.0, countStep)
                    else
                        if GUI.countdownActive then
                            SendChatMessage(messages.closed, "RAID_WARNING")
                        end
                        GUI.countdownActive = false
                        GUI.countdownTimer = nil
                    end
                end

                GUI.countdownTimer = C_Timer.After(1.0, countStep)
            end
        end)

        -- 카운트다운 중지 버튼
        local stopBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        stopBtn:SetWidth(80)
        stopBtn:SetHeight(50)
        stopBtn:SetPoint("LEFT", countdownBtn, "RIGHT", 5, 0)
        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            stopBtn:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
        else
            stopBtn:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
        end
        stopBtn:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
        stopBtn:SetBackdropBorderColor(0.60, 0.15, 0.15, 1.0)

        local stopBtnText = stopBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stopBtnText:SetTextColor(0.9, 0.2, 0.2)
        stopBtnText:SetText("카운트중지")
        stopBtnText:SetPoint("CENTER", 0, 0)

        stopBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
            self:SetBackdropBorderColor(1.00, 0.25, 0.25, 1.0)
            stopBtnText:SetTextColor(1, 0.3, 0.3)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("카운트다운 중지 및 재개")
            GameTooltip:Show()
        end)
        stopBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
            self:SetBackdropBorderColor(0.60, 0.15, 0.15, 1.0)
            stopBtnText:SetTextColor(0.9, 0.2, 0.2)
            GameTooltip:Hide()
        end)
        stopBtn:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.05, 0.05, 0.07, 1.0)
            stopBtnText:SetTextColor(0.6, 0.1, 0.1)
        end)
        stopBtn:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
            stopBtnText:SetTextColor(1, 0.3, 0.3)
        end)

        stopBtn:SetScript("OnClick", function()
            stopAndResume()
        end)

        GUI.autoCountBtn = autoBtn
        GUI.countdownMainBtn = countdownBtn
        GUI.countdownStopBtn = stopBtn

        -- 총수익 강조 라벨 (크게) — 하단 startGoldLabel이 자동 버튼 라인 하단(y=46)에 정렬되도록 위치
        do
            local revLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            revLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 61)
            revLabel:SetJustifyH("LEFT")
            revLabel:SetTextColor(1.0, 0.84, 0.0)
            revLabel:SetText("총수익 0골드")
            GUI.bottomRevenueLabel = revLabel

            local revAnomalyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            revAnomalyLabel:SetPoint("LEFT", revLabel, "RIGHT", 6, -2)
            revAnomalyLabel:SetJustifyH("LEFT")
            revAnomalyLabel:SetTextColor(1.0, 0.4, 0.4)
            revAnomalyLabel:SetText("")
            revAnomalyLabel:Hide()
            GUI.bottomRevenueAnomalyLabel = revAnomalyLabel

            local spenderLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            spenderLabel:SetPoint("TOPLEFT", revLabel, "BOTTOMLEFT", 0, -4)
            spenderLabel:SetJustifyH("LEFT")
            spenderLabel:SetTextColor(0.85, 0.85, 0.85)
            spenderLabel:SetText("")
            spenderLabel:Hide()
            GUI.bottomTopSpenderLabel = spenderLabel

            local mySpendLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            mySpendLabel:SetPoint("TOPLEFT", spenderLabel, "BOTTOMLEFT", 0, -4)
            mySpendLabel:SetJustifyH("LEFT")
            mySpendLabel:SetTextColor(0.72, 0.85, 1.0)
            mySpendLabel:SetText("")
            mySpendLabel:Hide()
            GUI.bottomMySpendLabel = mySpendLabel

            local startGoldLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            startGoldLabel:SetPoint("TOPLEFT", mySpendLabel, "BOTTOMLEFT", 0, -4)
            startGoldLabel:SetJustifyH("LEFT")
            startGoldLabel:SetTextColor(0.78, 0.78, 0.63)
            startGoldLabel:SetText("")
            startGoldLabel:Hide()
            GUI.bottomStartGoldLabel = startGoldLabel

            local revHitbox = CreateFrame("Button", nil, f)
            revHitbox:SetPoint("TOPLEFT", revLabel, "TOPLEFT", -4, 4)
            revHitbox:SetPoint("BOTTOMRIGHT", revLabel, "BOTTOMRIGHT", 4, -4)
            revHitbox:SetScript("OnEnter", function(self)
                iraShowBottomRevenueTooltip(self, GUI.bottomRevenueAudit, GUI.bottomRevenueShowMoneyAudit)
            end)
            revHitbox:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            GUI.bottomRevenueTooltipHitbox = revHitbox
        end
    end

    local menuFrame = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")

    -- title
    -- do
    --     local t = f:CreateTexture(nil, "ARTWORK")
    --     t:SetTexture("Interface/DialogFrame/UI-DialogBox-Header")
    --     t:SetWidth(256)
    --     t:SetHeight(64)
    --     t:SetPoint("TOP", f, 0, 12)
    --     f.texture = t
    -- end

    -- do
    --     local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    --     t:SetText("경매 장부")
    --     t:SetPoint("TOP", f.texture, 0, -14)
    -- end
    -- title


    local mustnumber = function(self, char)
        local b = char and strbyte(char)
        -- Tab/Enter 등: 숫자가 아니라서 마지막 글자를 지우는 분기로 들어가면 "600"+Tab → "60" → "6" 로 깨짐
        if not b or b < 32 then
            return
        end
        local t = self:GetText()
        if (48 <= b and b <= 57) then
            return
        end
        if char == "." and string.find(t, ".", 1, true) == #t then
            return
        end
        if _G.IRA_DEBUG_COST_EDIT then
            IRADebugCost("mustnumber STRIP byte=%s text_before=%q (분배인원 등 숫자칸)", tostring(b), t)
        end
        self:SetText(string.sub(t, 0, #t - 1))
    end    

    -- split member info label + editbox
    do
        local infoLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        infoLabel:SetPoint("BOTTOMLEFT", f, 14, 101)
        infoLabel:SetText("분배인원 설정 :")

        local function updateInfoLabel()
            local rosterN = GetRosterNumber()
            local benN = 0
            if GUI.GetBeneficiaryCount then benN = GUI:GetBeneficiaryCount() end
            infoLabel:SetText("분배인원 설정 : 현재 " .. rosterN .. " 명 , 득자 " .. benN .. " 명 , 총분배인원")
        end
        updateInfoLabel()
        RegEvent("GROUP_ROSTER_UPDATE", updateInfoLabel)
        RegEvent("CHAT_MSG_SYSTEM", updateInfoLabel)
        GUI._updateSplitInfoLabel = updateInfoLabel

        local t = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        t:SetWidth(28)
        t:SetHeight(22)
        t:SetPoint("LEFT", infoLabel, "RIGHT", 8, 0)
        t:SetAutoFocus(false)
        t:SetMaxLetters(2)
        t:SetJustifyH("CENTER")
        t:SetFontObject("GameFontNormal")
        t:SetTextColor(1.0, 0.82, 0.0)
        -- InputBoxTemplate 좌/중/우 텍스처 제거 후 평면 백드롭
        for i = 1, t:GetNumRegions() do
            local r = select(i, t:GetRegions())
            if r and r.GetObjectType and r:GetObjectType() == "Texture" then
                r:SetTexture(nil)
                r:Hide()
            end
        end
        if BackdropTemplateMixin and not t.SetBackdrop then
            Mixin(t, BackdropTemplateMixin)
        end
        if t.SetBackdrop then
            if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
                t:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
            else
                t:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false, tileSize = 0, edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
            end
            t:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
            t:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
            t:HookScript("OnEditFocusGained", function(self)
                self:SetBackdropBorderColor(0.20, 0.65, 1.00, 1.0)
            end)
            t:HookScript("OnEditFocusLost", function(self)
                self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
            end)
        end
        t:SetTextInsets(4, 4, 2, 2)
        t:SetScript("OnTextChanged", function()
            local currentValue = tonumber(t:GetText()) or 10
            Database:SetConfig("splitcount", currentValue)

            self:UpdateSummary()
            UpdateAllDistributeLabel()

            if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                local checkAllDistribute = true
                if checkbox then
                    local rawValue = checkbox:GetChecked()
                    checkAllDistribute = (rawValue == true) or (rawValue == 1)
                end
                GUI.exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), currentValue, nil, checkAllDistribute))
            end
        end)
        t:SetScript("OnEnterPressed", clearAllFocus)
        t:SetScript("OnTabPressed", clearAllFocus)
        t:SetScript("OnChar", mustnumber)

        local defaultSplit = 10
        if IsInRaid() then
            local raidSize = 0
            for i = 1, MAX_RAID_MEMBERS do
                if GetRaidRosterInfo(i) then raidSize = raidSize + 1 end
            end
            if raidSize > 25 then defaultSplit = 40
            elseif raidSize > 10 then defaultSplit = 25 end
        end
        local savedSplitCount = Database:GetConfigOrDefault("splitcount", defaultSplit)
        t:SetText(savedSplitCount)
        self.countEdit = t

        local suffixLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        suffixLabel:SetPoint("LEFT", t, "RIGHT", 2, 0)
        suffixLabel:SetText("명")
        GUI._splitSuffixLabel = suffixLabel
    end
    --

    --[[
    -- dropbox filter (분배 단위) - 커스텀 드롭다운 (분배 인원 수 설정 드롭다운) - 주석 처리
    -- 분배 인원 설정은 직접 입력 필드 사용
    do
        local container = CreateFrame("Frame", nil, f)
        container:SetWidth(80)
        container:SetHeight(28)
        container:SetPoint("BOTTOMLEFT", f, 410, 10)

        -- 메인 버튼
        local button = CreateFrame("Button", nil, container, "BackdropTemplate")
        button:SetAllPoints(container)
        button:SetText("40인 ▼")

        -- 현대적인 버튼 스타일 적용
        button:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        button:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
        button:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)

        -- 텍스트 색상 흰색으로 설정
        button:SetNormalFontObject("GameFontNormal")
        local fontString = button:GetFontString()
        if fontString then
            fontString:SetTextColor(1, 1, 1)
        end

        -- 호버 효과
        button:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.25, 0.25, 0.35, 0.95)
            self:SetBackdropBorderColor(0.6, 0.6, 0.7, 1.0)
        end)

        button:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            self:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end)

        -- 드롭다운 메뉴 프레임
        local dropdown = CreateFrame("Frame", nil, container, "BackdropTemplate")
        dropdown:SetWidth(80)
        dropdown:SetPoint("TOP", container, "BOTTOM", 0, -2)
        dropdown:Hide()

        -- 메뉴 스타일
        dropdown:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        dropdown:SetBackdropColor(0.15, 0.15, 0.2, 0.95)
        dropdown:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)

        -- 메뉴 아이템들
        local menuItems = {
            {text = "40인", value = 40},
            {text = "20인", value = 20},
            {text = "10인", value = 10},
            {text = "5인", value = 5},
            {text = "분배안함", value = 0}
        }

        local selectedValue = 40

        -- 메뉴 아이템 생성
        for i, item in ipairs(menuItems) do
            local itemButton = CreateFrame("Button", nil, dropdown, "BackdropTemplate")
            itemButton:SetWidth(76)
            itemButton:SetHeight(22)
            itemButton:SetPoint("TOP", dropdown, "TOP", 0, -(i-1)*24)
            itemButton:SetText(item.text)

            -- 메뉴 아이템 스타일
            itemButton:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "",
                tile = false,
                tileSize = 0,
                edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            itemButton:SetBackdropColor(0.1, 0.1, 0.15, 0.8)

            -- 텍스트 설정
            itemButton:SetNormalFontObject("GameFontNormalSmall")
            local itemFontString = itemButton:GetFontString()
                if itemFontString then
                    itemFontString:SetTextColor(1, 1, 1)
                end

            -- 호버 효과
            itemButton:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.3, 0.3, 0.4, 0.9)
            end)

            itemButton:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.1, 0.1, 0.15, 0.8)
            end)

            -- 클릭 이벤트
            itemButton:SetScript("OnClick", function()
                selectedValue = item.value
                button:SetText(item.text .. " ▼")
                dropdown:Hide()
                Database:SetConfig("dividelevel", item.value)
                checkf = item.value

                -- UI 요약 정보 실시간 업데이트 (총수익, 개인당 골드, 파티당 골드)
                GUI:UpdateSummary()
            end)
        end

        dropdown:SetHeight(#menuItems * 24 + 4)

        -- 메인 버튼 클릭 시 메뉴 토글
        button:SetScript("OnClick", function()
            if dropdown:IsShown() then
                dropdown:Hide()
            else
                dropdown:Show()
                -- 다른 드롭다운들 닫기
                if GUI.customDropdowns then
                    for _, dd in pairs(GUI.customDropdowns) do
                        if dd ~= dropdown then
                            dd:Hide()
                        end
                    end
                end
            end
        end)

        -- 전역 드롭다운 리스트에 추가
        if not GUI.customDropdowns then
            GUI.customDropdowns = {}
        end
        table.insert(GUI.customDropdowns, dropdown)

        -- 다른 곳 클릭 시 닫기
        container:SetScript("OnHide", function()
            dropdown:Hide()
        end)

        -- 커스텀 드롭다운으로 교체됨
        -- checkf 변수는 더 이상 사용하지 않음 (GUI.roundingLevel 사용)

    end
    --]]

    -- 골드 단위 절삭 고정
    GUI.roundingLevel = 0


    -- 올분/무득분 토글 버튼
    do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetWidth(100)
        btn:SetHeight(22)
        btn:SetPoint("LEFT", GUI._splitSuffixLabel, "RIGHT", 6, 0)
        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            btn:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
        else
            btn:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
        end

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetPoint("CENTER", 0, 0)

        local savedState = Database:GetConfigOrDefault("checkAllDistribute", true)
        GUI._checkAllDistributeState = savedState

        -- 라벨 텍스트 갱신 (전체분배/무득분배 + 인원수)
        local function refreshLabelText()
            local totalMembers = 10
            if GUI.countEdit and GUI.countEdit.GetText then
                totalMembers = tonumber(GUI.countEdit:GetText()) or 10
            end
            if GUI._checkAllDistributeState then
                btnText:SetText("전체분배 (" .. totalMembers .. ")")
            else
                local bn = (GUI.GetBeneficiaryCount and GUI:GetBeneficiaryCount()) or 0
                local actual = math.max(1, totalMembers - bn)
                btnText:SetText("무득분배 (" .. actual .. ")")
            end
        end

        local function updateDistBtnStyle()
            if GUI._checkAllDistributeState then
                btn:SetBackdropColor(0.20, 0.08, 0.16, 0.90)
                btn:SetBackdropBorderColor(1.00, 0.40, 0.70, 1.0)
                btnText:SetTextColor(1.00, 0.70, 0.85)
            else
                btn:SetBackdropColor(0.18, 0.10, 0.14, 0.90)
                btn:SetBackdropBorderColor(0.70, 0.35, 0.55, 1.0)
                btnText:SetTextColor(0.85, 0.55, 0.70)
            end
            refreshLabelText()
        end

        updateDistBtnStyle()

        btn.GetChecked = function()
            return GUI._checkAllDistributeState
        end

        btn:SetScript("OnClick", function()
            GUI._checkAllDistributeState = not GUI._checkAllDistributeState
            Database:SetConfig("checkAllDistribute", GUI._checkAllDistributeState)
            updateDistBtnStyle()
            UpdateAllDistributeLabel()
            GUI:UpdateSummary()

            if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                local splitNumber = GUI:GetSplitNumber()
                GUI.exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), splitNumber, nil, GUI._checkAllDistributeState))
            end
        end)

        GUI.checkAllDistributeButton = btn
        _G.IberisRaidAuctionCheckAllDistributeButton = btn
        GUI.allDistributeLabel = btnText
        GUI._updateDistBtnStyle = updateDistBtnStyle

        -- 즉시 동기 호출 (countEdit 이미 초기화됨)
        UpdateAllDistributeLabel()
        C_Timer.After(0.1, function()
            UpdateAllDistributeLabel()
        end)
    end

    local function LedgerItemLooksRecipeForToggle(item)
        if not item or item.type ~= "CREDIT" or not item.detail then
            return false
        end
        local isTestRow = item.isTestMode == true or (item.detail and item.detail.isTestMode == true)
        if isTestRow then
            local rid = tonumber(item.detail.reliableItemID) or 0
            if rid > 0 then
                return IRA_TEST_RECIPE_ITEM_IDS[rid] == true
            end
            return item.detail.isRecipeTest == true
        end
        local itemIDRef = nil
        if item.detail.reliableItemID then
            itemIDRef = "item:" .. tostring(item.detail.reliableItemID)
        end
        local itemRef = item.detail.item
        if type(itemRef) ~= "string" or itemRef == "" then
            itemRef = itemIDRef
        end
        if type(itemRef) ~= "string" or itemRef == "" then
            return false
        end

        -- 도안무득 토글은 느슨한 이름 추측 대신 실제 itemClassID 또는 공용 도안 판정만 사용한다.
        if type(GetItemInfoInstant) == "function" then
            local instantRef = itemIDRef or itemRef
            local ok, _, _, _, _, _, classID = pcall(GetItemInfoInstant, instantRef)
            if ok and tonumber(classID) ~= nil then
                return tonumber(classID) == 9
            end
        end
        if ADDONSELF.ItemLooksRecipeLikeForAutoLoot and ADDONSELF.ItemLooksRecipeLikeForAutoLoot(itemRef) then
            return true
        end
        return false
    end

    -- 도안무득 토글 버튼 (제목창, 품질필터와 테스트모드 사이)
    do
        local function applyRecipeNoBeneficiary(checked)
            local ledger = Database:GetCurrentLedger()
            if not ledger or not ledger["items"] then return end
            local want = checked and true or false
            local changedAny = false
            for i, item in ipairs(ledger["items"]) do
                if item and item.type == "CREDIT" and item.detail then
                    local isRecipeRow = LedgerItemLooksRecipeForToggle(item)
                    local isTestRow = item.isTestMode == true or (item.detail and item.detail.isTestMode == true)
                    local isDisenchantHandoff = (tonumber(item.cost) or 0) == 0
                        and ADDONSELF.IsDisenchantHandoffBeneficiary
                        and ADDONSELF.IsDisenchantHandoffBeneficiary(item.beneficiary or "")
                    local isDisenchantResult = item.detail and item.detail.isDisenchantResult == true
                    local desired = item.noBeneficiary and true or false

                    if isRecipeRow then
                        desired = want
                    elseif isTestRow then
                        -- 테스트모드에서는 도안무득 토글 적용 후 비도안 행의 잔존 무득 상태를 정리한다.
                        desired = (isDisenchantHandoff or isDisenchantResult) and true or false
                    end

                    if (item.noBeneficiary and true or false) ~= desired then
                        Database:SetItemNoBeneficiary(i, desired, true)
                        changedAny = true
                    end
                end
            end
            if changedAny then
                Database:OnLedgerItemsChange()
            else
                GUI:UpdateLootTableFromDatabase()
                GUI:UpdateSummary()
                UpdateAllDistributeLabel()
            end
        end

        GUI.applyRecipeNoBeneficiary = applyRecipeNoBeneficiary

        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetWidth(55)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 515, -7)
        btn:SetFrameStrata("HIGH")
        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            btn:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
        else
            btn:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
        end

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetText("도안무득")
        btnText:SetPoint("CENTER", 0, 0)

        local savedRecipe = Database:GetConfigOrDefault("recipeNoBeneficiary", true)
        GUI.recipeNoBeneficiaryEnabled = savedRecipe

        local function updateRecipeBtnStyle()
            if GUI.recipeNoBeneficiaryEnabled then
                btn:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                btn:SetBackdropBorderColor(0.15, 0.7, 0.15, 1.0)
                btnText:SetTextColor(0.1, 0.85, 0.1)
            else
                btn:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                btn:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
                btnText:SetTextColor(0.5, 0.5, 0.5)
            end
        end
        updateRecipeBtnStyle()

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("도안 무득처리 토글")
            GameTooltip:AddLine("활성화 시 모든 도안(레시피) 아이템을", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("자동으로 무득처리합니다.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:SetScript("OnClick", function()
            GUI.recipeNoBeneficiaryEnabled = not GUI.recipeNoBeneficiaryEnabled
            Database:SetConfig("recipeNoBeneficiary", GUI.recipeNoBeneficiaryEnabled)
            applyRecipeNoBeneficiary(GUI.recipeNoBeneficiaryEnabled)
            updateRecipeBtnStyle()
        end)

        GUI.recipeNoBeneficiaryButton = btn
        GUI.recipeNoBeneficiaryButton.GetChecked = function()
            return GUI.recipeNoBeneficiaryEnabled
        end
    end

    -- 테스트모드 버튼
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(70)
        b:SetHeight(22)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 576, -7)
        b:SetFrameStrata("HIGH")
        b:SetText("테스트모드")
        b:SetNormalFontObject("GameFontNormal")
        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            b:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
            b:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
            b:SetBackdropBorderColor(0.6, 0.3, 0.8, 1.0)
        else
            b:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            b:SetBackdropColor(0.2, 0.1, 0.3, 0.9)
            b:SetBackdropBorderColor(0.6, 0.3, 0.8, 1.0)
        end
        local fs = b:GetFontString()
        if fs then fs:SetTextColor(0.9, 0.7, 1) end

        b:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
            self:SetBackdropBorderColor(0.8, 0.5, 1.0, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local td = ADDONSELF.testData
            local count = (td and td.count) or 0
            local label = (td and td.label) or "테스트 데이터"
            GameTooltip:SetText(string.format("테스트 아이템 %d건 추가", count))
            GameTooltip:AddLine(label .. "를 장부에 추가합니다.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
            self:SetBackdropBorderColor(0.6, 0.3, 0.8, 1.0)
            GameTooltip:Hide()
        end)
        b:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.05, 0.05, 0.07, 1.0)
        end)
        b:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
        end)

        b:SetScript("OnClick", function()
            local ok, err = xpcall(function()
                -- IRATestData.lua 가 ADDONSELF.testData 에 박은 실측 entries 그대로 재생.
                -- 시작골드/머니 변동은 박지 않고, 블랙리스트(켈타스 P4 + 황천의 쐐기 더미)는 추출 단계에서 이미 제외됨.
                local data = ADDONSELF.testData
                if not data or type(data.entries) ~= "table" or #data.entries == 0 then
                    ADDONSELF.print("|cFFFF4444[테스트모드 오류]|r 테스트 데이터(IRATestData)가 로드되지 않았습니다.")
                    return
                end

                for _, e in ipairs(data.entries) do
                    local itemLink = e.item
                    if not itemLink or itemLink == "" then
                        itemLink = "|cffffffff|Hitem:" .. tostring(e.reliableItemID or 0) .. "::::::::70:::::|h[?]|h|r"
                    end
                    local detail = {
                        item = itemLink,
                        type = "ITEM",
                        count = e.count or 1,
                        reliableItemID = e.reliableItemID,
                        looter = e.looter or "",
                        winner = e.winner or "",
                        isTestMode = true,
                    }
                    Database:AddEntry("CREDIT", detail, e.beneficiary or "", e.cost or 0, e.saleState or "confirmed", true)
                    -- SV에 박혀있던 noBeneficiary 값 그대로 보존 (AddEntry 의 자동 계산 덮어씀)
                    local ledger = Database:GetCurrentLedger()
                    if ledger and ledger.items and #ledger.items > 0 then
                        ledger.items[#ledger.items].noBeneficiary = e.noBeneficiary and true or false
                    end
                end

                Database:OnLedgerItemsChange()
                ADDONSELF.print(string.format("|cFF9966FF[테스트모드]|r %s — %d건 추가됨.", data.label or "테스트 데이터", #data.entries))
            end, function(caughtErr)
                return tostring(caughtErr or "unknown")
            end)

            if not ok then
                ADDONSELF.print("|cFFFF4444[테스트모드 오류]|r " .. tostring(err))
            end
        end)
        GUI.testModeButton = b
    end

    -- sum 총수익 총지출 최종수입 개인당 골드 파티당 골드 — 3줄 중 가운데 줄이 분배인원(y=96) 라인에 정렬, 줄간격 +4px
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        t:SetPoint("BOTTOMRIGHT", f, -20, 83)
        t:SetJustifyH("RIGHT")
        t:SetSpacing(4)

        self.summaryLabel = t
    end

    -- export editbox — 위치/크기 lootLogFrame과 동일하게 + ElvUI 테마
    do
        -- ScrollFrame 자체에 BackdropTemplate Mixin (lootLogFrame.frame 과 동일 위치/크기)
        local t = CreateFrame("ScrollFrame", "IberisRaidAuctionExportScroll", f, "BackdropTemplate,UIPanelScrollFrameTemplate")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -62)
        t:SetWidth(690)
        t:SetHeight(310)
        if ADDONSELF.theme and ADDONSELF.theme.ApplyFrame then
            ADDONSELF.theme:ApplyFrame(t)
        end

        local edit = CreateFrame("EditBox", nil, t)
        edit:SetWidth(645)
        edit:SetHeight(320)
        edit:SetPoint("TOPLEFT", t, 4, -3)
        edit:SetTextInsets(10, 10, 8, 8)
        edit:SetAutoFocus(false)
        edit:EnableMouse(true)
        edit:SetMaxLetters(99999999)
        edit:SetMultiLine(true)
        edit:SetFontObject(GameTooltipText)
        edit:SetScript("OnTextChanged", function(self)
            ScrollingEdit_OnTextChanged(self, t)
        end)
        edit:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
        edit:SetScript("OnEscapePressed", edit.ClearFocus)
        edit:SetScript("OnEnterPressed", edit.ClearFocus)
        self.exportEditbox = edit

        t:SetScrollChild(edit)

        -- ScrollBar 를 t 내부 우측으로 재앵커 (lootLogFrame 의 scrolltrough 와 동일 위치: 우측 -12 inset)
        local sb = t.ScrollBar or _G["IberisRaidAuctionExportScrollScrollBar"]
        if sb then
            sb:ClearAllPoints()
            sb:SetPoint("TOPRIGHT", t, "TOPRIGHT", -12, -20)
            sb:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -12, 20)
            if ADDONSELF.theme and ADDONSELF.theme.ApplyScrollBar then
                ADDONSELF.theme:ApplyScrollBar(sb)
            end
        end

        -- scrolltrough/border 텍스처 제거 (있다면)
        for _, child in ipairs({ t:GetChildren() }) do
            if child.background and child.background.SetTexture then
                child.background:SetTexture(nil)
                child.background:Hide()
            end
        end

        t:Hide()
    end

    -- close btn (닫기 버튼)
    -- do
    --     local b = CreateFrame("Button", nil, f, "BackdropTemplate")
    --     b:SetWidth(100)
    --     b:SetHeight(28)
    --     b:SetPoint("BOTTOMRIGHT", -40, 10)
    --     b:SetText(L["Close"])

    --     -- 현대적인 버튼 스타일 적용
    --     b:SetBackdrop({
    --         bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    --         edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    --         tile = true,
    --         tileSize = 16,
    --         edgeSize = 12,
    --         insets = { left = 2, right = 2, top = 2, bottom = 2 }
    --     })
    --     b:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
    --     b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)

    --     -- 텍스트 색상 흰색으로 설정
    --     b:SetNormalFontObject("GameFontNormal")
    --     b:SetHighlightFontObject("GameFontHighlight")
    --     b:GetNormalFontObject():SetTextColor(1, 1, 1)
    --     b:GetHighlightFontObject():SetTextColor(1, 1, 1)

    --     -- 호버 효과
    --     b:SetScript("OnEnter", function(self)
    --         self:SetBackdropColor(0.25, 0.25, 0.35, 0.95)
    --         self:SetBackdropBorderColor(0.6, 0.6, 0.7, 1.0)
    --     end)

    --     b:SetScript("OnLeave", function(self)
    --         self:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
    --         self:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
    --     end)

    --     -- 눌렸을 때 효과
    --     b:SetScript("OnMouseDown", function(self)
    --         self:SetBackdropColor(0.1, 0.1, 0.15, 1.0)
    --         self:SetBackdropBorderColor(0.3, 0.3, 0.4, 1.0)
    --     end)

    --     b:SetScript("OnMouseUp", function(self)
    --         self:SetBackdropColor(0.25, 0.25, 0.35, 0.95)
    --         self:SetBackdropBorderColor(0.6, 0.6, 0.7, 1.0)
    --     end)

    --     b:SetScript("OnClick", function() f:Hide() end)
    -- end

    -- clear btn (기록지우기) — 테마 적용, 요약출력 옆 배치
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(70)
        b:SetHeight(25)
        b:SetPoint("BOTTOMLEFT", 548, 133)
        b:SetText("기록지우기")

        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(b)
        else
            b:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            b:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1, 1, 1)
        end

        b:SetScript("OnClick", function()
            StaticPopup_Show("IBERISRAIDAUCTION_CLEARMSG")
        end)
        GUI.clearLogButton = b
    end

    -- credit (+수익 버튼) — 테마 + 하늘색 강조, 아이템 리스트 좌측 정렬
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(60)
        b:SetHeight(25)
        b:SetPoint("BOTTOMLEFT", 14, 133)
        b:SetText("+" .. L["Credit"])

        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(b, {
                bgColor     = { 0.05, 0.15, 0.25, 0.90 },
                borderColor = { 0.10, 0.50, 0.85, 1.00 },
                bgHover     = { 0.08, 0.22, 0.35, 0.95 },
                borderHover = { 0.20, 0.65, 1.00, 1.00 },
                bgPressed   = { 0.03, 0.10, 0.18, 1.00 },
            })
        else
            b:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            b:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(0.4, 0.75, 1.0)
        end

        b:SetScript("OnClick", function()
            Database:AddCredit("")
            FauxScrollFrame_SetOffset(self.lootLogFrame.scrollframe, 0) -- move to top
            local toast = ADDONSELF.showToast
            if toast then
                local cred = L["Credit"]
                cred = (type(cred) == "string" and cred) or "Credit"
                toast("|cFF88FF88[+" .. cred .. "]|r\n|cffffffff" .. L["Toast ledger credit added"] .. "|r", 4, "success")
            end
        end)
        GUI.creditButton = b
    end

    -- debit (-지출 버튼) — 테마 + 주황 강조
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(60)
        b:SetHeight(25)
        b:SetPoint("BOTTOMLEFT", 80, 133)
        b:SetText("-" .. L["Debit"])

        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(b, {
                bgColor     = { 0.30, 0.18, 0.08, 0.90 },
                borderColor = { 1.00, 0.55, 0.10, 1.00 },
                bgHover     = { 0.40, 0.25, 0.10, 0.95 },
                borderHover = { 1.00, 0.70, 0.25, 1.00 },
                bgPressed   = { 0.20, 0.12, 0.05, 1.00 },
            })
        else
            b:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            b:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1.0, 0.7, 0.2)
        end

        b:SetScript("OnClick", function()
            Database:AddDebit(L["Compensation"], "", 0)
            FauxScrollFrame_SetOffset(self.lootLogFrame.scrollframe, 0) -- move to top
            local toast = ADDONSELF.showToast
            if toast then
                local deb = L["Debit"]
                deb = (type(deb) == "string" and deb) or "Debit"
                toast("|cFF88FF88[-" .. deb .. "]|r\n|cffffffff" .. L["Toast ledger debit added"] .. "|r", 4, "success")
            end
        end)
        GUI.debitButton = b
    end

    -- +아이템 (수동 아이템 추가) 버튼
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(62)
        b:SetHeight(25)
        b:SetPoint("BOTTOMLEFT", 170, 133)
        b:SetText("+아이템")

        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            b:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
        else
            b:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
        end
        b:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
        b:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1, 1, 1)
        end

        local promptText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        promptText:SetPoint("BOTTOM", f, "BOTTOM", 0, 148)
        promptText:SetTextColor(0.2, 1.0, 0.2)
        promptText:SetText("가방·채팅·AtlasLoot 등 아이템을 Shift+클릭 (버튼 재클릭으로 취소)")
        promptText:Hide()
        GUI.addItemPrompt = promptText

        local function SetWaitingState(waiting)
            GUI.waitingForManualItem = waiting
            if waiting then
                b:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                b:SetBackdropBorderColor(0.20, 0.80, 0.20, 1.0)
                local fs = b:GetFontString() if fs then fs:SetTextColor(0.2, 1.0, 0.2) end
                promptText:Show()
            else
                b:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                b:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
                local fs = b:GetFontString() if fs then fs:SetTextColor(1, 1, 1) end
                promptText:Hide()
            end
        end
        GUI.SetManualItemWaiting = SetWaitingState

        b:SetScript("OnEnter", function(self2)
            if not GUI.waitingForManualItem then
                self2:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
                self2:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
                local fs = self2:GetFontString() if fs then fs:SetTextColor(1, 1, 0, 1) end
            end
            GameTooltip:SetOwner(self2, "ANCHOR_RIGHT")
            GameTooltip:SetText("+아이템 수동 추가")
            GameTooltip:AddLine("클릭 후 가방·채팅·다른 애드온(AtlasLoot 등)\n아이템 링크를 Shift+클릭하면 수익 항목으로 추가됩니다.", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("희귀(파랑) 이상, 또는 녹색 도안·제작법만 등록됩니다(채팅 자동 수집과 동일).", 0.85, 0.7, 0.5)
            GameTooltip:Show()
        end)

        b:SetScript("OnLeave", function(self2)
            if not GUI.waitingForManualItem then
                self2:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                self2:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
                local fs = self2:GetFontString() if fs then fs:SetTextColor(1, 1, 1, 1) end
            end
            GameTooltip:Hide()
        end)

        b:SetScript("OnMouseDown", function(self2)
            if not GUI.waitingForManualItem then
                self2:SetBackdropColor(0.05, 0.05, 0.07, 1.0)
            end
        end)

        b:SetScript("OnMouseUp", function(self2)
            if not GUI.waitingForManualItem then
                self2:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
            end
        end)

        b:SetScript("OnClick", function()
            SetWaitingState(not GUI.waitingForManualItem)
        end)

        GUI.addItemBtn = b
    end

    -- 미경매 (낙찰가격 미입력) 카운트 버튼
    do
        local nb = CreateFrame("Button", nil, f, "BackdropTemplate")
        nb:SetWidth(120)
        nb:SetHeight(25)
        nb:SetPoint("BOTTOMLEFT", 235, 133)
        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            nb:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
        else
            nb:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
        end
        nb:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
        nb:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
        nb:SetNormalFontObject("GameFontNormal")
        local nbFs = nb:GetFontString()
        if nbFs then nbFs:SetTextColor(1, 0.8, 0.2) end

        nb:SetScript("OnEnter", function(self2)
            self2:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
        end)
        nb:SetScript("OnLeave", function(self2)
            self2:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
        end)
        nb:SetScript("OnClick", function()
            GUI._showPendingOnly = not GUI._showPendingOnly
            GUI:UpdateLootTableFromDatabase()
            GUI:UpdateSummary()
        end)

        GUI.noBidCountBtn = nb

        function GUI:UpdateNoBidCount()
            if not GUI.mainframe or not GUI.mainframe:IsShown() then
                return
            end
            local pendingCount = 0
            local uiRows = GUI.lootLogFrame and GUI.lootLogFrame.data or nil
            if uiRows and #uiRows > 0 then
                for _, entry in ipairs(uiRows) do
                    if entry and entry.type == "CREDIT" and entry.detail and entry.detail.type == "ITEM" then
                        local isNoBene = entry.noBeneficiary and true or false
                        local isConfirmed = (entry.saleState == "confirmed") or (entry.confirmed and true or false)
                        if not isNoBene and not isConfirmed then
                            pendingCount = pendingCount + 1
                        end
                    end
                end
            else
                local items = Database:GetCurrentLedger()["items"] or {}
                for i = 1, #items do
                    local item = items[i]
                    if item and item.type == "CREDIT" and item.detail and item.detail.type == "ITEM" then
                        local isNoBene = Database:GetItemNoBeneficiary(i)
                        local isConfirmed = Database:IsLedgerEntryConfirmed(i)
                        if not isNoBene and not isConfirmed then
                            pendingCount = pendingCount + 1
                        end
                    end
                end
            end
            if pendingCount > 0 then
                local fs = nb:GetFontString()
                if GUI._showPendingOnly then
                    nb:SetText("전체 보기")
                    nb:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                    nb:SetBackdropBorderColor(0.25, 0.50, 0.90, 1.0)
                    if fs then fs:SetTextColor(0.75, 0.88, 1.0) end
                else
                    nb:SetText(string.format("미확정 %d", pendingCount))
                    nb:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                    nb:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
                    if fs then fs:SetTextColor(1, 0.3, 0.3) end
                end
            else
                local fs = nb:GetFontString()
                if GUI._showPendingOnly then
                    nb:SetText("전체 보기")
                    nb:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                    nb:SetBackdropBorderColor(0.25, 0.50, 0.90, 1.0)
                    if fs then fs:SetTextColor(0.75, 0.88, 1.0) end
                else
                    nb:SetText("미확정 0")
                    nb:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
                    nb:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
                    if fs then fs:SetTextColor(0.1, 0.85, 0.1) end
                end
            end

            if GUI.UpdateDisenchantResultCount then
                GUI:UpdateDisenchantResultCount()
            end
        end
        GUI._showPendingOnly = false
        nb:SetText("미확정 0")
    end

    do
        local deWrap = CreateFrame("Frame", nil, f)
        deWrap:SetWidth(160)
        deWrap:SetHeight(20)
        -- 큰 총수익 라벨의 (이상)[xx골드] 우측에 배치
        deWrap:SetPoint("LEFT", GUI.bottomRevenueAnomalyLabel or GUI.bottomRevenueLabel, "RIGHT", 8, 0)
        deWrap:SetFrameStrata("HIGH")
        GUI.deResultCountWrap = deWrap

        local deFs = deWrap:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        deFs:SetAllPoints(deWrap)
        deFs:SetJustifyH("LEFT")
        deFs:SetText("")
        GUI.deResultCountLabel = deFs

        function GUI:UpdateDisenchantResultCount()
            if not GUI.mainframe or not GUI.mainframe:IsShown() then
                return
            end
            local items = Database:GetCurrentLedger()["items"] or {}
            local deGroups = {}
            for i = 1, #items do
                local item = items[i]
                if LedgerItemIsDisenchantResult(item) then
                    local itemName = ""
                    if item.detail and item.detail.item then
                        itemName = (GetItemInfo(item.detail.item)) or ""
                    end
                    if itemName == "" then
                        itemName = (item.detail and item.detail.displayname) or ""
                    end
                    if itemName == "" then
                        itemName = "뽀각 결과"
                    end
                    local key = tostring((item.detail and item.detail.reliableItemID) or itemName)
                    local group = deGroups[key]
                    if not group then
                        group = {
                            name = itemName,
                            count = 0,
                            itemLink = item.detail and item.detail.item,
                        }
                        deGroups[key] = group
                    end
                    group.count = group.count + (tonumber(item.detail and item.detail.count) or 1)
                end
            end

            local topGroup = nil
            local groupCount = 0
            for _, group in pairs(deGroups) do
                groupCount = groupCount + 1
                if not topGroup or group.count > topGroup.count or (group.count == topGroup.count and tostring(group.name) < tostring(topGroup.name)) then
                    topGroup = group
                end
            end

            if topGroup then
                local coloredName = BuildQualityColoredItemName(topGroup.itemLink, topGroup.name)
                if groupCount == 1 then
                    deFs:SetText(string.format("%s |cff80d0ff%d|r", coloredName, tonumber(topGroup.count) or 0))
                else
                    deFs:SetText(string.format("%s |cff80d0ff%d|r |cff808080외 %d종|r", coloredName, tonumber(topGroup.count) or 0, groupCount - 1))
                end
            else
                deFs:SetText("")
            end
        end
    end

    -- dropbox filter (아이템 등급) - 커스텀 드롭다운 (아이템 품질 필터링 드롭다운)
    do
        local container = CreateFrame("Frame", nil, f)
        container:SetWidth(92)
        container:SetHeight(22)
        container:SetPoint("TOPLEFT", f, "TOPLEFT", 417, -7)
        container:SetFrameStrata("HIGH")

        -- 메인 버튼
        local button = CreateFrame("Button", nil, container, "BackdropTemplate")
        button:SetAllPoints(container)
        button:SetText("|cff0070dd희귀+|r \226\150\188")
        GUI.qualityFilterButton = button

        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            button:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
            button:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
            button:SetBackdropBorderColor(0.00, 0.00, 0.00, 1.00)
        else
            button:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            button:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            button:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end

        -- 텍스트 색상 흰색으로 설정
        button:SetNormalFontObject("GameFontNormal")
        local fontString = button:GetFontString()
        if fontString then
            fontString:SetTextColor(1, 1, 1)
        end

        -- 호버 효과 + 툴팁(목록 표시 필터 안내)
        button:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
            self:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("목록 표시 품질", 1, 1, 1)
            GameTooltip:AddLine("|cff1eff00고급+|r : 고급 도안류", 0.85, 0.85, 0.85)
            GameTooltip:AddLine("|cff0070dd희귀+|r : 희귀, 영웅, 전설", 0.85, 0.85, 0.85)
            GameTooltip:AddLine("|cffa335ee영웅+|r : 영웅, 전설", 0.85, 0.85, 0.85)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            self:SetBackdropColor(0.15, 0.15, 0.18, 0.90)
            self:SetBackdropBorderColor(0.00, 0.00, 0.00, 1.00)
        end)

        -- 드롭다운 메뉴 프레임
        local dropdown = CreateFrame("Frame", nil, container, "BackdropTemplate")
        dropdown:SetWidth(110)
        dropdown:SetPoint("TOP", container, "BOTTOM", 0, -2)
        dropdown:Hide()
        dropdown:SetFrameStrata("DIALOG")

        -- 메뉴 스타일
        if ADDONSELF.theme and ADDONSELF.theme.Backdrop then
            dropdown:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))
            dropdown:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
            dropdown:SetBackdropBorderColor(0.00, 0.00, 0.00, 1.00)
        else
            dropdown:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            dropdown:SetBackdropColor(0.15, 0.15, 0.2, 0.95)
            dropdown:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end

        local qualityColors = {
            [2] = {r=0.12, g=1.00, b=0.00, hex="ff1eff00"},  -- 고급+ (희귀+녹색도안, 자동수집과 동일)
            [3] = {r=0.00, g=0.44, b=0.87, hex="ff0070dd"},  -- 희귀+
            [4] = {r=0.64, g=0.21, b=0.93, hex="ffa335ee"},  -- 영웅+(전설 포함)
        }
        local menuItems = {
            {text = "고급+", value = 2},
            {text = "희귀+", value = 3},
            {text = "영웅+", value = 4},
        }

        local function coloredFilterText(val, label)
            local c = qualityColors[val]
            if c then
                return "|c" .. c.hex .. label .. "|r"
            end
            return label
        end

        for i, item in ipairs(menuItems) do
            local itemButton = CreateFrame("Button", nil, dropdown, "BackdropTemplate")
            itemButton:SetWidth(100)
            itemButton:SetHeight(22)
            itemButton:SetPoint("TOP", dropdown, "TOP", 0, -(i-1)*24)

            if ADDONSELF.theme and ADDONSELF.theme.GetBackground then
                itemButton:SetBackdrop({
                    bgFile = ADDONSELF.theme:GetBackground(),
                    edgeFile = "",
                    tile = false, tileSize = 0, edgeSize = 0,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
                })
            else
                itemButton:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "",
                    tile = false, tileSize = 0, edgeSize = 0,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 }
                })
            end
            itemButton:SetBackdropColor(0.10, 0.10, 0.10, 0.0)  -- 평소 투명, 호버 시만 강조

            itemButton:SetNormalFontObject("GameFontNormalSmall")
            itemButton:SetText(coloredFilterText(item.value, item.text))
            local itemFontString = itemButton:GetFontString()
            if itemFontString then
                itemFontString:SetTextColor(1, 1, 1)
            end

            itemButton:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.22, 0.22, 0.28, 0.95)
            end)
            itemButton:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.10, 0.10, 0.10, 0.0)
            end)

            itemButton:SetScript("OnClick", function()
                button:SetText(coloredFilterText(item.value, item.text) .. " \226\150\188")
                dropdown:Hide()
                Database:SetConfig("filterlevel", item.value)
                GUI:UpdateLootTableFromDatabase()
                GUI:UpdateSummary()
            end)
        end

        dropdown:SetHeight(#menuItems * 24 + 4)

        -- 메인 버튼 클릭 시 메뉴 토글
        button:SetScript("OnClick", function()
            if dropdown:IsShown() then
                dropdown:Hide()
            else
                dropdown:Show()
                -- 다른 드롭다운들 닫기
                if GUI.customDropdowns then
                    for _, dd in pairs(GUI.customDropdowns) do
                        if dd ~= dropdown then
                            dd:Hide()
                        end
                    end
                end
            end
        end)

        -- 전역 드롭다운 리스트에 추가
        if not GUI.customDropdowns then
            GUI.customDropdowns = {}
        end
        table.insert(GUI.customDropdowns, dropdown)

        -- 다른 곳 클릭 시 닫기
        container:SetScript("OnHide", function()
            dropdown:Hide()
        end)

        local rawFilter = Database:GetConfigOrDefault("filterlevel", 3)
        local savedFilterLevel = NormalizeQualityFilterLevel(rawFilter)
        if savedFilterLevel ~= rawFilter then
            Database:SetConfig("filterlevel", savedFilterLevel)
        end
        local filterLabels = { [2] = "고급+", [3] = "희귀+", [4] = "영웅+" }
        local label = filterLabels[savedFilterLevel] or "희귀+"
        button:SetText(coloredFilterText(savedFilterLevel, label) .. " \226\150\188")
    end

    do
        -- 아이템 링크는 전역 GameTooltip 사용 (다른 애드온의 툴팁 확장이 동작하도록)
        self.commtooltip = CreateFrame("GameTooltip", "IberisRaidAuctionTooltipComm" .. random(10000) , UIParent, "GameTooltipTemplate")
    end

    -- logframe
    do

        local CONVERT = L["#Try to convert to item link"]
        local autoCompleteDebit = function(text)
            text = string.upper(text)

            local data = {}

            for _, name in pairs({
                L["Compensation: Tank"],
                L["Compensation: Healer"],
                -- L["Compensation: Aqual Quintessence"],
                -- L["Compensation: Repait Bot"],
                L["Compensation: DPS"],
                L["Compensation: Other"],
            }) do
                local b = text == ""
                b = b or (text == "#ONFOCUS")
                b = b or (strfind(string.upper(name), text))

                if b then
                    tinsert(data, {
                        ["name"] = name,
                        ["priority"] = LE_AUTOCOMPLETE_PRIORITY_IN_GROUP,
                    })
                end
            end

            return data
        end

        local autoCompleteCredit = function(text)
            local data = {}

            text = strtrim(text or "")
            text = strtrim(text, "[]")
            local name = GetItemInfo(text)

            if name then
                tinsert(data, {
                    ["name"] = CONVERT,
                    ["priority"] = LE_AUTOCOMPLETE_PRIORITY_IN_GROUP,
                })
            end

            return data
        end

        local autoCompleteRaidRoster = function(text)
            local data = {}

            for i = 1, MAX_RAID_MEMBERS do
                local name, _, subgroup, _, class = GetRaidRosterInfo(i)

                if name then
                    name = string.lower(name)
                    class = string.lower(class)

                    local b = text == ""
                    b = b or (text == "#ONFOCUS")
                    b = b or (strfind(name, string.lower(text)))
                    b = b or (tonumber(text) == subgroup)
                    b = b or (strfind(class, string.lower(text)))

                    if b then
                        tinsert(data, {
                            ["name"] = name,
                            ["priority"] = LE_AUTOCOMPLETE_PRIORITY_IN_GROUP,
                        })
                    end
                end
            end

            return data
        end

        local popOnFocus = function(edit)
            edit:SetScript("OnTextChanged", function(self, userInput)

                AutoCompleteEditBox_OnTextChanged(self, userInput)

                local t = self:GetText()

                -- 콜백 함수가 있는지 확인
                if edit.customTextChangedCallback then
                    edit.customTextChangedCallback(t)
                end

                if t == "" then
                    t = "#ONFOCUS"
                end
                AutoComplete_Update(self, t, 1);
            end)

            edit:SetScript("OnEditFocusGained", function(self)
                local t = self:GetText()
                if t == "" then
                    t = "#ONFOCUS"
                end
                AutoComplete_Update(self, t, 1);
            end)
        end

        -- 인라인 아이콘 + 글꼴: 획득자 InputBox는 보통 ChatFontNormal이라 GameFontHighlight보다 크게 보이는 경우가 많음 → 동일 FontObject로 통일
        local IRA_LEDGER_ITEM_ICON = 18
        local IRA_LEDGER_ENTRY_FONT = ChatFontNormal or GameFontNormal
        local function IRAFormatItemLineLootRollStyle(itemLink, detailItem, displayCount, displayNameOverride)
            local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemLink)
            if not texture and detailItem then
                texture = GetItemIcon(detailItem)
            end
            texture = texture or 134400
            local q = tonumber(quality) or 0
            local r, g, b, colorExtra = GetItemQualityColor(q)
            local color = "|cffffffff"
            if type(colorExtra) == "string" then
                if colorExtra:match("^%x%x%x%x%x%x%x%x$") then
                    color = "|c" .. colorExtra
                elseif colorExtra:find("|c", 1, true) then
                    color = colorExtra
                end
            elseif r and g and b then
                local function byte(x)
                    x = (tonumber(x) or 0)
                    if x <= 1 then x = x * 255 end
                    if x < 0 then x = 0 elseif x > 255 then x = 255 end
                    return math.floor(x + 0.5)
                end
                color = string.format("|cff%02x%02x%02x", byte(r), byte(g), byte(b))
            elseif ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
                local c = ITEM_QUALITY_COLORS[q]
                color = string.format("|cff%02x%02x%02x",
                    math.floor(((c.r or 1) * 255) + 0.5),
                    math.floor(((c.g or 1) * 255) + 0.5),
                    math.floor(((c.b or 1) * 255) + 0.5))
            end
            name = name or displayNameOverride or "?"
            local icon = string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", tostring(texture), IRA_LEDGER_ITEM_ICON, IRA_LEDGER_ITEM_ICON)
            local line = string.format("%s %s%s|r", icon, color, name)
            if displayCount and displayCount > 1 then
                line = line .. string.format(" |cffffffff×%d|r", displayCount)
            end
            return line
        end

        local function IRAFormatPendingItemLine(detailItem, stackCount)
            local texture = (detailItem and GetItemIcon(detailItem)) or 134400
            local icon = string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", tostring(texture), IRA_LEDGER_ITEM_ICON, IRA_LEDGER_ITEM_ICON)
            local line = icon .. " |cffffffff...|r"
            if stackCount and stackCount > 1 then
                line = line .. string.format(" |cffffffff×%d|r", stackCount)
            end
            return line
        end

        local function IRAFormatLedgerTypeLine(isDebit)
            local tex = isDebit and 135768 or 135769
            local icon = string.format("|T%d:%d:%d:0:0:64:64:5:59:5:59|t ", tex, IRA_LEDGER_ITEM_ICON, IRA_LEDGER_ITEM_ICON)
            local label = isDebit and L["Debit"] or L["Credit"]
            return string.format("%s|cffffffff%s|r", icon, label)
        end

        -- 일부 클라(기념판 등)에서 GameTooltip:IsOwned(FontString)은 "Wrong object type" 오류 — 셀 이탈 시 그대로 숨김
        local function IRAHideItemTooltip()
            GameTooltip:Hide()
        end

        -- 아이템 줄: 표시 문자열 끝(이름 끝)에 1px 앵커 → 툴팁은 그 지점의 우측·위(BOTTOMLEFT→TOPRIGHT)
        local function IRAUpdateItemNameTooltipAnchor(cellFrame)
            if not cellFrame or not cellFrame.text then
                return
            end
            if not cellFrame._itemTipAnchor then
                cellFrame._itemTipAnchor = CreateFrame("Frame", nil, cellFrame)
                cellFrame._itemTipAnchor:SetSize(1, 1)
            end
            local sw = cellFrame.text:GetStringWidth() or 0
            if sw < 1 then
                sw = 1
            end
            cellFrame._itemTipAnchor:ClearAllPoints()
            cellFrame._itemTipAnchor:SetPoint("TOPLEFT", cellFrame.text, "TOPLEFT", sw, 0)
            cellFrame._itemTipAnchor:Show()
        end

        local function IRAApplyItemTooltipAnchor(cellFrame)
            if not (GameTooltip and GameTooltip.ClearAllPoints and cellFrame) then
                return
            end
            GameTooltip:ClearAllPoints()
            if cellFrame._itemTipAnchor and cellFrame._itemTipAnchor:IsShown() then
                GameTooltip:SetPoint("BOTTOMLEFT", cellFrame._itemTipAnchor, "TOPRIGHT", 4, 4)
                return
            end
            if cellFrame.announceBtn and cellFrame.announceBtn:IsShown() then
                GameTooltip:SetPoint("BOTTOMLEFT", cellFrame.announceBtn, "TOPRIGHT", 6, 4)
            else
                GameTooltip:SetPoint("BOTTOMLEFT", cellFrame, "TOPRIGHT", 6, 4)
            end
        end

        local function IRAAnnounceAuction(itemLink)
            if not itemLink or itemLink == "" then
                return
            end
            local equipInfo = GetEquipInfoText(itemLink)
            local warningMsg = itemLink .. equipInfo
            local auctionMsg = "=== " .. itemLink .. equipInfo .. " 경매 시작합니다. ==="
            if IsInRaid() then
                local myRank = 0
                local pName = UnitName("player")
                for i = 1, MAX_RAID_MEMBERS do
                    local name, rank = GetRaidRosterInfo(i)
                    if name == pName then myRank = rank or 0; break end
                end
                if myRank > 0 then
                    SendChatMessage(warningMsg, "RAID_WARNING")
                    SendChatMessage(auctionMsg, "RAID")
                else
                    SendChatMessage(warningMsg, "RAID")
                    SendChatMessage(auctionMsg, "RAID")
                end
            else
                ADDONSELF.print(warningMsg)
                ADDONSELF.print(auctionMsg)
            end
        end

        local micColumnUpdate = CreateCellUpdate(function(cellFrame, entry)
            local btn = cellFrame.announceBtn
            if not btn then
                btn = CreateFrame("Button", nil, cellFrame)
                btn:SetSize(18, 18)
                btn:SetPoint("CENTER", cellFrame, "CENTER")
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints(btn)
                tex:SetTexture("Interface\\Common\\VoiceChat-Speaker")
                tex:SetVertexColor(1, 0.82, 0)
                btn.tex = tex
                btn:SetScript("OnEnter", function(self)
                    self.tex:SetVertexColor(1, 1, 0.5)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("공대 경보로 알리기")
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    self.tex:SetVertexColor(1, 0.82, 0)
                    GameTooltip:Hide()
                end)
                cellFrame.announceBtn = btn
            end

            local detail = entry and entry.detail
            local itemLink = nil
            if detail and detail.type == "ITEM" and type(detail.item) == "string" and detail.item ~= "" then
                _, itemLink = GetItemInfo(detail.item)
            end
            local enabled = detail and detail.type == "ITEM" and itemLink and itemLink ~= ""
            btn:SetShown(enabled and true or false)
            btn:SetEnabled((not GUI._uiLocked) and enabled)
            btn:SetAlpha(enabled and 1 or 0.25)
            if enabled then
                btn:SetScript("OnClick", function()
                    IRAAnnounceAuction(itemLink)
                end)
            else
                btn:SetScript("OnClick", nil)
            end
        end)

        local iconEntryMergedUpdate = CreateCellUpdate(function(cellFrame, entry, idx)
            if not cellFrame.announceBtn then
                local btn = CreateFrame("Button", nil, cellFrame)
                btn:SetSize(22, 22)
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints(btn)
                tex:SetTexture("Interface\\Common\\VoiceChat-Speaker")
                tex:SetVertexColor(1, 0.82, 0)
                btn.tex = tex
                btn:SetScript("OnEnter", function(self)
                    self.tex:SetVertexColor(1, 1, 0.5)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("공대 경보로 알리기")
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    self.tex:SetVertexColor(1, 0.82, 0)
                    GameTooltip:Hide()
                end)
                cellFrame.announceBtn = btn
            end

            cellFrame:SetScript("OnEnter", nil)
            cellFrame:SetScript("OnLeave", nil)
            cellFrame.announceBtn:ClearAllPoints()
            cellFrame.announceBtn:SetPoint("LEFT", cellFrame, "LEFT", 2, 0)
            cellFrame.announceBtn:SetPoint("TOP", cellFrame, "TOP", 0, -4)
            cellFrame.announceBtn:Hide()

            local function layoutPrimaryTextAfterSpeaker()
                cellFrame.text:ClearAllPoints()
                cellFrame.text:SetJustifyH("LEFT")
                cellFrame.text:SetJustifyV("MIDDLE")
                cellFrame.text:SetWordWrap(false)
                if cellFrame.announceBtn:IsShown() then
                    cellFrame.text:SetPoint("LEFT", cellFrame.announceBtn, "RIGHT", 4, 0)
                else
                    cellFrame.text:SetPoint("LEFT", cellFrame, "LEFT", 2, 0)
                end
                cellFrame.text:SetPoint("RIGHT", cellFrame, "RIGHT", -4, 0)
            end

            local function layoutDebitCreditTextAndEdit()
                cellFrame.text:ClearAllPoints()
                cellFrame.text:SetJustifyH("LEFT")
                cellFrame.text:SetJustifyV("MIDDLE")
                cellFrame.text:SetWordWrap(false)
                cellFrame.text:SetPoint("LEFT", cellFrame, "LEFT", 2, 0)
                cellFrame.text:SetPoint("TOP", cellFrame, "TOP", 0, 0)
                cellFrame.text:SetPoint("BOTTOM", cellFrame, "BOTTOM", 0, 0)
                cellFrame.text:SetWidth(62)
                cellFrame.textBox:ClearAllPoints()
                cellFrame.textBox:SetPoint("LEFT", cellFrame.text, "RIGHT", 0, 0)
                cellFrame.textBox:SetPoint("RIGHT", cellFrame, "RIGHT", -57, 0)
                cellFrame.textBox:SetHeight(28)
                cellFrame.textBox:SetPoint("TOP", cellFrame, "TOP", 0, -1)
                cellFrame.textBox:SetPoint("BOTTOM", cellFrame, "BOTTOM", 0, 1)
            end

            local function applySpeakerRowDim()
                local isBidded = LedgerItemIsConfirmed(entry)
                local isNoBene = LedgerItemIsMarkedNoBeneficiary(entry)
                local textAlpha = GetReadonlyVisualAlpha(isBidded, isNoBene)
                local actionAlpha = GetReadonlyActionAlpha(isBidded, isNoBene)
                if cellFrame.announceBtn then cellFrame.announceBtn:SetAlpha(actionAlpha) end
                return textAlpha
            end

            local detail = entry["detail"]

            if detail["type"] == "ITEM" then
                local _, itemLink = GetItemInfo(detail["item"])

                if itemLink then
                    layoutPrimaryTextAfterSpeaker()
                    cellFrame.text:SetFontObject(IRA_LEDGER_ENTRY_FONT)
                    local displayCount = LedgerEntryDisplayItemCount(entry)
                    cellFrame.text:SetText(IRAFormatItemLineLootRollStyle(itemLink, detail["item"], displayCount, detail["displayname"]))
                    local textAlpha = applySpeakerRowDim()
                    cellFrame.text:SetAlpha(textAlpha)

                    if not cellFrame.textBox then
                        cellFrame.textBox = CreateFrame("EditBox", nil, cellFrame, "InputBoxTemplate,AutoCompleteEditBoxTemplate")
                        cellFrame.textBox:SetAutoFocus(false)
                        cellFrame.textBox:SetScript("OnEscapePressed", cellFrame.textBox.ClearFocus)
                        popOnFocus(cellFrame.textBox)
                        cellFrame.textBox:SetFontObject(IRA_LEDGER_ENTRY_FONT)
                    end
                    cellFrame.textBox:Hide()

                    cellFrame:SetScript("OnEnter", function()
                        IRAUpdateItemNameTooltipAnchor(cellFrame)
                        GameTooltip:SetOwner(cellFrame, "ANCHOR_NONE")
                        GameTooltip:SetHyperlink(itemLink)
                        if displayCount and displayCount > 1 then
                            local itemName = GetItemInfo(itemLink)
                            local cost = entry.cost or 0
                            GameTooltip:AddLine(string.format("%s x%d", itemName or "?", displayCount), 1, 1, 1)
                            GameTooltip:AddLine(string.format("낙찰: %s /개", GetMoneyStringComma(cost)), 0.75, 0.75, 0.8)
                            GameTooltip:AddLine(string.format("합계: %s", GetMoneyStringComma(cost * displayCount)), 0.75, 0.75, 0.8)
                            GameTooltip:AddLine("묶음 수량은 목록의 ×숫자로 표시됩니다.", 0.5, 0.5, 0.55, true)
                        end
                        GameTooltip:Show()
                        IRAUpdateItemNameTooltipAnchor(cellFrame)
                        IRAApplyItemTooltipAnchor(cellFrame)
                    end)

                    cellFrame:SetScript("OnLeave", function()
                        IRAHideItemTooltip()
                    end)

                    return
                end

                cellFrame.announceBtn:Hide()
                layoutPrimaryTextAfterSpeaker()
                cellFrame.text:SetFontObject(IRA_LEDGER_ENTRY_FONT)
                cellFrame.text:SetText(IRAFormatPendingItemLine(detail["item"], entry.stackCount))
                local textAlpha = applySpeakerRowDim()
                cellFrame.text:SetAlpha(textAlpha)

                if not cellFrame.textBox then
                    cellFrame.textBox = CreateFrame("EditBox", nil, cellFrame, "InputBoxTemplate,AutoCompleteEditBoxTemplate")
                    cellFrame.textBox:SetAutoFocus(false)
                    cellFrame.textBox:SetScript("OnEscapePressed", cellFrame.textBox.ClearFocus)
                    popOnFocus(cellFrame.textBox)
                    cellFrame.textBox:SetFontObject(IRA_LEDGER_ENTRY_FONT)
                end
                cellFrame.textBox:Hide()

                cellFrame:SetScript("OnEnter", function()
                    IRAUpdateItemNameTooltipAnchor(cellFrame)
                    GameTooltip:SetOwner(cellFrame, "ANCHOR_NONE")
                    GameTooltip:SetText("아이템 정보를 불러오는 중입니다.", 0.85, 0.85, 0.85)
                    GameTooltip:Show()
                    IRAUpdateItemNameTooltipAnchor(cellFrame)
                    IRAApplyItemTooltipAnchor(cellFrame)
                end)
                cellFrame:SetScript("OnLeave", function()
                    IRAHideItemTooltip()
                end)
                return
            end

            cellFrame.announceBtn:Hide()
            applySpeakerRowDim()

            if cellFrame._itemTipAnchor then
                cellFrame._itemTipAnchor:Hide()
            end

            if not cellFrame.textBox then
                cellFrame.textBox = CreateFrame("EditBox", nil, cellFrame, "InputBoxTemplate,AutoCompleteEditBoxTemplate")
                cellFrame.textBox:SetAutoFocus(false)
                cellFrame.textBox:SetScript("OnEscapePressed", cellFrame.textBox.ClearFocus)
                popOnFocus(cellFrame.textBox)
                cellFrame.textBox:SetFontObject(IRA_LEDGER_ENTRY_FONT)
            end

            layoutDebitCreditTextAndEdit()
            cellFrame.text:SetFontObject(IRA_LEDGER_ENTRY_FONT)

            if entry["type"] == "DEBIT" then
                cellFrame.text:SetText(IRAFormatLedgerTypeLine(true))
                AutoCompleteEditBox_SetAutoCompleteSource(cellFrame.textBox, autoCompleteDebit)
            else
                cellFrame.text:SetText(IRAFormatLedgerTypeLine(false))
                AutoCompleteEditBox_SetAutoCompleteSource(cellFrame.textBox, autoCompleteCredit)
            end
            cellFrame.text:SetAlpha(1)

            popOnFocus(cellFrame.textBox)

            local editTimer = nil
            local isUpdating = false

            cellFrame.textBox.customTextChangedCallback = function(t)
                if isUpdating then return end
                if t == nil then t = "" end
                if editTimer then
                    editTimer:Cancel()
                end

                entry["detail"]["displayname"] = t
                if entry["type"] == "DEBIT" then
                    entry["beneficiary"] = t
                end

                if entry.beneficiary ~= t then
                    editTimer = C_Timer.NewTimer(0.8, function()
                        isUpdating = true

                        if entry.type == "DEBIT" and idx then
                            local ledger = Database:GetCurrentLedger()
                            if ledger and ledger.items[idx] then
                                ledger.items[idx].beneficiary = t
                            end
                        end

                        UpdateAllDistributeLabel()
                        GUI:UpdateSummary()

                        if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                            local splitNumber = GUI:GetSplitNumber()
                            local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                            local checkAllDistribute = true
                            if checkbox then
                                local rawValue = checkbox:GetChecked()
                                checkAllDistribute = (rawValue == true) or (rawValue == 1)
                            end
                            GUI.exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), splitNumber, nil, checkAllDistribute))
                        end

                        C_Timer.After(0, function()
                            GUI:UpdateLootTableFromDatabase()
                        end)

                        isUpdating = false
                    end)
                end
            end

            cellFrame.textBox:Show()
            cellFrame.textBox:SetText(detail["displayname"] or "")
            if GUI._uiLocked then
                cellFrame.textBox:Disable()
                cellFrame.textBox:SetAlpha(0.5)
                ApplyConfirmedTextBoxVisual(cellFrame.textBox, false)
            else
                local isConfirmed = LedgerItemIsConfirmed(entry)
                if isConfirmed then
                    cellFrame.textBox:Disable()
                    cellFrame.textBox:SetAlpha(0.65)
                    ApplyConfirmedTextBoxVisual(cellFrame.textBox, true)
                else
                    cellFrame.textBox:Enable()
                    cellFrame.textBox:SetAlpha(1)
                    ApplyConfirmedTextBoxVisual(cellFrame.textBox, false)
                end
            end
        end)

        local beneficiaryUpdate = CreateCellUpdate(function(cellFrame, entry, idx)

            if not (cellFrame.textBox) then
                cellFrame.textBox = CreateFrame("EditBox", nil, cellFrame, "InputBoxTemplate,AutoCompleteEditBoxTemplate")
                cellFrame.textBox:SetPoint("CENTER", cellFrame, "CENTER", -20, 0)
                cellFrame.textBox:SetWidth(120)
                cellFrame.textBox:SetHeight(30)
                cellFrame.textBox:SetAutoFocus(false)
                cellFrame.textBox:SetScript("OnEscapePressed", cellFrame.textBox.ClearFocus)
                AutoCompleteEditBox_SetAutoCompleteSource(cellFrame.textBox, autoCompleteRaidRoster)
                popOnFocus(cellFrame.textBox)
            end
            cellFrame.textBox:SetFontObject(IRA_LEDGER_ENTRY_FONT)

            cellFrame.textBox.customAutoCompleteFunction = function(editBox, newText, info)
                local n = newText ~= "" and newText or info.name
                n = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(n)

                local currentValue = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(GetEntryEditBeneficiaryValue(entry, idx) or "")
                if n ~= "" and n ~= currentValue then
                    -- 자동완성으로 데이터 직접 업데이트 (SetText 호출하지 않음)
                    local changed, displayValue, role = SetEntryBeneficiaryValue(entry, idx, n)
                    entry["beneficiary"] = displayValue

                    SyncNoBeneficiaryForDisenchantHandoffCredit(entry, BeneficiaryEditIndices(entry, idx, cellFrame._iraStackIndices), n)

                    -- ScrollingTable UI 데이터 강제 업데이트 (autoComplete)
                    if GUI.lootLogFrame and GUI.lootLogFrame.data and idx then
                        -- UI 테이블에서 해당 행 찾아서 업데이트
                        for _, rowData in ipairs(GUI.lootLogFrame.data) do
                            if rowData.realItemIdx == idx then
                                rowData.beneficiary = displayValue
                                if rowData.cols and rowData.cols[5] then
                                    rowData.cols[5].value = displayValue
                                end
                                break
                            end
                        end
                    end
                    if changed then
                        BroadcastEntryBeneficiaryChange(idx, n, role)
                    end

                    -- 실시간 업데이트: 요약 정보, 라벨, 텍스트 도출 업데이트
                    UpdateAllDistributeLabel() -- 득자 수 실시간 업데이트
                    GUI:UpdateSummary() -- 총수익, 개인당 골드 등 업데이트

                    -- 텍스트 도출 모드가 열려있으면 텍스트 내용도 업데이트
                    if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                        local splitNumber = GUI:GetSplitNumber()
                        local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                        local checkAllDistribute = true
                        if checkbox then
                            local rawValue = checkbox:GetChecked()
                            checkAllDistribute = (rawValue == true) or (rawValue == 1)
                        end
                        GUI.exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), splitNumber, nil, checkAllDistribute))
                    end

                    -- UI 업데이트는 다음 프레임에 지연시켜 무한 루프 방지
                    C_Timer.After(0, function()
                        GUI:UpdateLootTableFromDatabase()
                    end)
                end

                return true
            end

            -- DEBIT 아이템의 경우 entry.beneficiary가 cols[5].value에서 설정되도록 보장
            if entry.type == "DEBIT" then
                if not entry.beneficiary then
                    entry.beneficiary = entry.cols[5].value or ""
                end
                -- 빈 문자열인 경우 L["[Unknown]"]으로 설정하지 않고 그대로 유지
                if entry.beneficiary == L["[Unknown]"] then
                    entry.beneficiary = ""
                    if entry.cols[5] then
                        entry.cols[5].value = ""
                    end
                end
            end

            -- 디바운스 타이머를 저장할 변수
            local editTimer = nil
            local isUpdating = false  -- 재귀 호출 방지 플래그

            cellFrame.textBox.customTextChangedCallback = function(t)
                -- 업데이트 중이면 무시 (재귀 호출 방지)
                if isUpdating then return end

                -- 데이터 검증: 빈 문자열이나 nil 방지
                if t == nil then t = "" end
                t = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(t)

                -- 기존 타이머 취소
                if editTimer then
                    editTimer:Cancel()
                end

                -- 득자가 변경된 경우에만 타이머 설정

                local currentValue = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(GetEntryEditBeneficiaryValue(entry, idx) or "")
                if currentValue ~= t then
                    -- 0.8초 후에 업데이트 실행 (사용자가 입력을 마칠 때까지 기다림)
                    editTimer = C_Timer.NewTimer(0.8, function()
                        isUpdating = true  -- 업데이트 시작 표시

                        local itemName = "Unknown"
                        if entry.detail and entry.detail.item then
                            _, itemName = GetItemInfo(entry.detail.item)
                            itemName = itemName or "Unknown"
                        end

                        local tSave = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(cellFrame.textBox:GetText() or "")
                        local changed, displayValue, role = SetEntryBeneficiaryValue(entry, idx, tSave)
                        entry["beneficiary"] = displayValue
                        -- DEBIT 아이템의 경우 cols[5].value도 동기화 (ScrollingTable 데이터 일관성)
                        if entry.cols and entry.cols[5] then
                            entry.cols[5].value = displayValue
                        end

                        -- ScrollingTable UI 데이터 강제 업데이트
                        if self.lootLogFrame and self.lootLogFrame.data and idx then
                            -- UI 테이블에서 해당 행 찾아서 업데이트
                            for _, rowData in ipairs(self.lootLogFrame.data) do
                                if rowData.realItemIdx == idx then
                                    rowData.beneficiary = displayValue
                                    if rowData.cols and rowData.cols[5] then
                                        rowData.cols[5].value = displayValue
                                    end
                                    break
                                end
                            end
                        end
                        if changed then
                            BroadcastEntryBeneficiaryChange(idx, tSave, role)
                        end

                        SyncNoBeneficiaryForDisenchantHandoffCredit(entry, BeneficiaryEditIndices(entry, idx, cellFrame._iraStackIndices), tSave)

                        UpdateAllDistributeLabel()
                        GUI:UpdateSummary()

                        if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                            local splitNumber = GUI:GetSplitNumber()
                            local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                            local checkAllDistribute = true
                            if checkbox then
                                local rawValue = checkbox:GetChecked()
                                checkAllDistribute = (rawValue == true) or (rawValue == 1)
                            end
                            GUI.exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), splitNumber, nil, checkAllDistribute))
                        end

                        if entry.type ~= "DEBIT" then
                            GUI:UpdateLootTableFromDatabase()
                        end
                        editTimer = nil
                        isUpdating = false  -- 업데이트 완료
                    end)
                end
            end

            -- 초기 텍스트 설정 (콜백 트리거 방지)
            local currentText = cellFrame.textBox:GetText() or ""
            local newText = ADDONSELF.FormatBeneficiaryForDisplay(GetEntryDisplayBeneficiary(entry, idx) or "")
            if currentText ~= newText then
                isUpdating = true
                cellFrame.textBox:SetText(newText)
                isUpdating = false
            end
            do
                local r, g, b = BeneficiaryDisplayColor(entry)
                ApplyConfirmedTextBoxVisual(cellFrame.textBox, LedgerItemIsConfirmed(entry), r, g, b)
            end

            if GUI._uiLocked then
                cellFrame.textBox:Disable()
                cellFrame.textBox:SetAlpha(0.5)
            else
                local isBidded = LedgerItemIsConfirmed(entry)
                local isNoBene = LedgerItemIsMarkedNoBeneficiary(entry)
                local dimAlpha = GetReadonlyVisualAlpha(isBidded, isNoBene)
                if isBidded then
                    cellFrame.textBox:Disable()
                else
                    cellFrame.textBox:Enable()
                end
                cellFrame.textBox:SetAlpha(dimAlpha)
                if cellFrame.text then cellFrame.text:SetAlpha(dimAlpha) end
            end
        end)


        local valueTypeMenuCtx = {}
        local setCostType = function(t)
            local entry = valueTypeMenuCtx.entry
            entry["costtype"] = t
            self:UpdateLootTableFromDatabase()
        end

        local valueTypeMenu = {
            {   
                costtype = "GOLD",
                text = GOLD_AMOUNT_TEXTURE_STRING:format(""), 
                func = function() 
                    setCostType("GOLD")
                end, 
            },
            { 
                costtype = "PROFIT_PERCENT",
                text = " % " .. L["Net Profit"], 
                func = function() 
                    setCostType("PROFIT_PERCENT")
                end, 
            },
            { 
                costtype = "MUL_AVG",
                text = " * " .. L["Per Member credit"], 
                func = function() 
                    setCostType("MUL_AVG")
                end, 
            },
        }        

        -- 낙찰가 원장·동기화 반영(포커스 끝날 때 한 번). 타이핑마다 쓰면 mustnumber/Refresh와 겹쳐 중간값(6)이 저장됨.
        local function iraPersistLedgerCost(idx, v)
            if not idx then
                return
            end
            if v < 0.0001 then
                v = 0
            end
            local ledger = Database:GetCurrentLedger()
            if not ledger or not ledger.items[idx] then
                return
            end
            local ent = ledger.items[idx]
            if Database:IsLedgerEntryConfirmed(idx) then
                return
            end
            if (ent.cost or 0) == v then
                return
            end
            local newSaleState = ent.saleState
            if ent.type == "CREDIT" and ent.detail and ent.detail.type == "ITEM" then
                if ent.saleState == "confirmed" then
                    if v <= 0 and not LedgerItemIsMarkedNoBeneficiary(ent) then
                        newSaleState = "open"
                    else
                        newSaleState = "confirmed"
                    end
                else
                    newSaleState = (v > 0) and "priced" or "open"
                end
            end
            if _G.IRA_DEBUG_COST_EDIT then
                IRADebugCost("persist WRITE idx=%s v=%s (was cost=%s type=%s)", tostring(idx), tostring(v), tostring(ent.cost), tostring(ent.type))
            end
            if ent.type == "DEBIT" then
                ledger.items[idx].beneficiary = ent.beneficiary
                ledger.items[idx].cost = v
                IberisRaidAuctionDatabase = IberisRaidAuctionDatabase or {}
                if not IberisRaidAuctionDatabase["ledgers"] then
                    IberisRaidAuctionDatabase["ledgers"] = {}
                end
                if not IberisRaidAuctionDatabase["current"] then
                    IberisRaidAuctionDatabase["current"] = #IberisRaidAuctionDatabase["ledgers"] + 1
                    IberisRaidAuctionDatabase["ledgers"][IberisRaidAuctionDatabase["current"]] = ledger
                end
                local curLedger = IberisRaidAuctionDatabase["ledgers"][IberisRaidAuctionDatabase["current"]]
                curLedger.items = ledger.items
            else
                ledger.items[idx].cost = v
                ledger.items[idx].saleState = newSaleState
                ADDONSELF.db:OnLedgerItemsChange()
            end
            local rid = ledger.items[idx].detail and ledger.items[idx].detail.reliableItemID
            local iLink = ledger.items[idx].detail and ledger.items[idx].detail.item
            if ADDONSELF.sync then
                ADDONSELF.sync:BroadcastCost(idx, rid, v, iLink)
                if ent.type == "CREDIT" and ent.detail and ent.detail.type == "ITEM" then
                    ADDONSELF.sync:BroadcastSaleState(idx, rid, ledger.items[idx].saleState, iLink)
                end
            end
            UpdateAllDistributeLabel()
            GUI:UpdateSummary()
            if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                local splitNumber = GUI:GetSplitNumber()
                local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                local checkAllDistribute = true
                if checkbox then
                    local rawValue = checkbox:GetChecked()
                    checkAllDistribute = (rawValue == true) or (rawValue == 1)
                end
                GUI.exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), splitNumber, nil, checkAllDistribute))
            end
            if ent.type ~= "DEBIT" then
                C_Timer.After(0, function()
                    GUI:UpdateLootTableFromDatabase()
                end)
            end
        end

        local valueUpdate = CreateCellUpdate(function(cellFrame, entry, idx)
            local tooltip = self.commtooltip
            if not (cellFrame.textBox) then
                cellFrame.textBox = CreateFrame("EditBox", nil, cellFrame, "InputBoxTemplate")
                cellFrame.textBox:SetPoint("RIGHT", cellFrame, "RIGHT", -4, 0)
                cellFrame.textBox:SetWidth(70)
                cellFrame.textBox:SetJustifyH("RIGHT")
                cellFrame.textBox:SetHeight(30)
                cellFrame.textBox:SetAutoFocus(false)
                cellFrame.textBox:SetMaxLetters(15)
                cellFrame.textBox:SetTextInsets(4, 8, 0, 0)  -- 우측 텍스트 내부 패딩 8px
                if not cellFrame.textBox._iraDebugHookSetText then
                    cellFrame.textBox._iraDebugHookSetText = true
                    local box = cellFrame.textBox
                    local _SetText = box.SetText
                    box.SetText = function(self, textArg, ...)
                        if _G.IRA_DEBUG_COST_EDIT then
                            local hasF = (GetCurrentKeyBoardFocus() == self)
                            local stk = ""
                            if debugstack then
                                local ok, s = pcall(debugstack, 3, 5, 0)
                                if ok and s and s ~= "" then
                                    stk = strtrim((s:gsub("\n%s*", " | ")))
                                end
                            end
                            IRADebugCost("SetText(%q) idx=%s edit=%s focus=%s", tostring(textArg), tostring(self._iraIdx), tostring(self._iraUserIsEditing), hasF and "Y" or "N")
                            if stk ~= "" then
                                IRADebugCost("  stack: %s", stk)
                            end
                        end
                        return _SetText(self, textArg, ...)
                    end
                end
                -- 낙찰가는 mustnumber 쓰지 않음(Tab이 OnChar로 오면 마지막 글자 삭제)
                cellFrame.textBox:SetScript("OnChar", function(self, char)
                    local tAfter = self:GetText() or ""
                    local b = char and strbyte(char)
                    if _G.IRA_DEBUG_COST_EDIT then
                        IRADebugCost("OnChar byte=%s charLen=%s GetText=%q norm=%q idx=%s", tostring(b), tostring(char and #char or 0), tAfter, IRACostEditNormalizeDigits(tAfter), tostring(self._iraIdx))
                    end
                    self._iraCommitText = IRACostEditNormalizeDigits(tAfter)
                end)
                cellFrame.textBox:SetScript("OnMouseDown", function(self)
                    self._iraUserIsEditing = true
                end)
                cellFrame.textBox:SetScript("OnKeyDown", function(self)
                    self._iraUserIsEditing = true
                end)
                local function iraCostTabEnter(self)
                    local g = IRACostEditNormalizeDigits(self:GetText())
                    local s = IRACostEditNormalizeDigits(self._iraCommitText or "")
                    if _G.IRA_DEBUG_COST_EDIT then
                        IRADebugCost("TabEnter/Enter g=%q s=%q rawGetText=%q idx=%s", g, s, self:GetText() or "", tostring(self._iraIdx))
                    end
                    if #g >= #s then
                        self._iraCommitText = g
                    end
                    clearAllFocus()
                end
                cellFrame.textBox:SetScript("OnEnterPressed", iraCostTabEnter)
                cellFrame.textBox:SetScript("OnTabPressed", iraCostTabEnter)

                local hintLabel = cellFrame.textBox:CreateFontString(nil, "OVERLAY")
                hintLabel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
                hintLabel:SetPoint("BOTTOM", cellFrame.textBox, "TOP", 0, -6)
                hintLabel:SetTextColor(0.6, 0.6, 0.6, 0.9)
                hintLabel:Hide()
                cellFrame.textBox._hintLabel = hintLabel

                cellFrame.textBox:SetScript("OnEditFocusGained", function(self)
                    self._iraUserIsEditing = true
                    if _G.IRA_DEBUG_COST_EDIT then
                        IRADebugCost("FocusGained rawValue=%s idx=%s", tostring(self._rawValue), tostring(self._iraIdx))
                    end
                    local raw = self._rawValue or 0
                    if raw > 0 then
                        self._hintLabel:SetText(FormatNumberWithComma(raw))
                        self._hintLabel:Show()
                    end
                    self:SetScript("OnTextChanged", nil)
                    self:SetText("")
                    self._iraCommitText = ""
                    self:SetScript("OnTextChanged", function(sel, userInput)
                        if userInput == false then
                            return
                        end
                        sel._iraCommitText = IRACostEditNormalizeDigits(sel:GetText())
                        if _G.IRA_DEBUG_COST_EDIT then
                            IRADebugCost("OnTextChanged user raw=%q commit=%q idx=%s", sel:GetText() or "", sel._iraCommitText or "", tostring(sel._iraIdx))
                        end
                    end)
                end)
                cellFrame.textBox:SetScript("OnEditFocusLost", function(self)
                    self._hintLabel:Hide()
                    local parent = cellFrame
                    local fromBox = IRACostEditNormalizeDigits(self:GetText())
                    local fromSnap = IRACostEditNormalizeDigits(self._iraCommitText or "")
                    if _G.IRA_DEBUG_COST_EDIT then
                        IRADebugCost("FocusLost fromBox=%q fromSnap=%q rawGet=%q idx=%s edit=%s", fromBox, fromSnap, self:GetText() or "", tostring(self._iraIdx), tostring(self._iraUserIsEditing))
                    end
                    local rawPick
                    if #fromSnap > #fromBox then
                        rawPick = fromSnap
                    elseif #fromBox > #fromSnap then
                        rawPick = fromBox
                    else
                        rawPick = (fromSnap ~= "") and fromSnap or fromBox
                    end
                    local txt = (IRACostEditNormalizeDigits(rawPick or "")):gsub("[^0-9%.]", "")
                    local v
                    if txt == "" then
                        v = 0
                    else
                        v = tonumber(txt)
                        if v == nil then
                            v = self._rawValue or 0
                        end
                    end
                    if v < 0.0001 then
                        v = 0
                    end
                    if _G.IRA_DEBUG_COST_EDIT then
                        IRADebugCost("FocusLost parsed v=%s rawPick=%q txt=%q", tostring(v), tostring(rawPick), tostring(txt))
                    end
                    self._iraUserIsEditing = false
                    self._rawValue = v
                    self:SetScript("OnTextChanged", nil)
                    self:SetText(FormatNumberWithComma(v))
                    self:SetScript("OnTextChanged", function(sel, userInput)
                        if userInput == false then
                            return
                        end
                        sel._iraCommitText = IRACostEditNormalizeDigits(sel:GetText())
                        if _G.IRA_DEBUG_COST_EDIT then
                            IRADebugCost("OnTextChanged user(raw) raw=%q commit=%q idx=%s", sel:GetText() or "", sel._iraCommitText or "", tostring(sel._iraIdx))
                        end
                    end)
                    local fixIdx = self._iraIdx
                    if fixIdx then
                        iraPersistLedgerCost(fixIdx, v)
                    end
                    self._iraCommitText = nil
                end)
            end
            local cost = entry["cost"] or 0
            cellFrame.textBox._rawValue = cost
            local tb = cellFrame.textBox
            if _G.IRA_DEBUG_COST_EDIT then
                local foc = GetCurrentKeyBoardFocus()
                if foc == tb or tb._iraUserIsEditing then
                    IRADebugCost("valueUpdate idx=%s entry.cost=%s editing=%s focusThis=%s curText=%q", tostring(idx), tostring(cost), tostring(tb._iraUserIsEditing), tostring(foc == tb), tb:GetText() or "")
                end
            end
            if not tb._iraUserIsEditing then
                cellFrame.textBox._iraIdx = idx
                cellFrame.textBox:SetScript("OnTextChanged", nil)
                cellFrame.textBox:SetText(FormatNumberWithComma(cost))
                cellFrame.textBox:SetScript("OnTextChanged", function(sel, userInput)
                    if userInput == false then
                        return
                    end
                    sel._iraCommitText = IRACostEditNormalizeDigits(sel:GetText())
                    if _G.IRA_DEBUG_COST_EDIT then
                        IRADebugCost("OnTextChanged user(valueUpd) raw=%q commit=%q idx=%s", sel:GetText() or "", sel._iraCommitText or "", tostring(sel._iraIdx))
                    end
                end)
            end

            if GUI._uiLocked then
                cellFrame.textBox._iraUserIsEditing = false
                cellFrame.textBox:Disable()
                cellFrame.textBox:SetAlpha(0.5)
                if cellFrame.text then cellFrame.text:SetAlpha(0.5) end
                ApplyConfirmedTextBoxVisual(cellFrame.textBox, false)
            else
                local isBidded = LedgerItemIsConfirmed(entry)
                local isNoBene = LedgerItemIsMarkedNoBeneficiary(entry)
                local dimAlpha = GetReadonlyVisualAlpha(isBidded, isNoBene)
                if isBidded then
                    cellFrame.textBox._iraUserIsEditing = false
                    cellFrame.textBox:Disable()
                else
                    cellFrame.textBox:Enable()
                end
                cellFrame.textBox:SetAlpha(dimAlpha)
                if cellFrame.text then cellFrame.text:SetAlpha(dimAlpha) end
                ApplyConfirmedTextBoxVisual(cellFrame.textBox, isBidded)
            end

            local type = entry["costtype"] or "GOLD"

            if type == "PROFIT_PERCENT" then
                cellFrame.text:SetText("%")
            elseif type == "MUL_AVG" then
                cellFrame.text:SetText("*")
            else
                -- GOLD by default — 동전 아이콘 제거 (사용자 요청)
                cellFrame.text:SetText("")
            end

            cellFrame:SetScript("OnClick", nil)
            cellFrame:SetScript("OnEnter", nil)

            if entry["type"] == "DEBIT" then
                cellFrame:SetScript("OnClick", function()
                    if GUI._uiLocked then return end
                    valueTypeMenuCtx.entry = entry
                    for _, m in pairs(valueTypeMenu) do
                        m.checked = m.costtype == type
                    end

                    EasyMenu(valueTypeMenu, menuFrame, "cursor", 0 , 0, "MENU")
                end)

            end

            if entry["costcache"] then
                cellFrame:SetScript("OnEnter", function()
                    tooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
                    tooltip:SetText(GetMoneyStringComma(entry["costcache"]))
                    tooltip:Show()
                end)

                cellFrame:SetScript("OnLeave", function()
                    tooltip:Hide()
                    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                end)
            end

        end)

        self.lootLogFrame = ScrollingTable:CreateST({
            {
                ["name"] = "",
                ["width"] = 1,
            },
            {
                ["name"] = "",
                ["width"] = 26,
                ["align"] = "CENTER",
                ["DoCellUpdate"] = micColumnUpdate,
            },
            {
                ["name"] = "순번",
                ["width"] = 42,
                ["align"] = "CENTER",
            },
            {
                ["name"] = L["Entry"],
                ["width"] = 220,
                ["DoCellUpdate"] = iconEntryMergedUpdate,
            },
            {
                ["name"] = BENEFICIARY_HEADER_TEXT,
                ["width"] = 150,
                ["DoCellUpdate"] = beneficiaryUpdate,
            },
            {
                ["name"] = L["Status"],
                ["width"] = 28,
                ["align"] = "CENTER",
                ["DoCellUpdate"] = CreateCellUpdate(function(cellFrame, entry, idx)
                    local signalButton = cellFrame.signalButton
                    if not signalButton then
                        signalButton = CreateFrame("Button", nil, cellFrame, "BackdropTemplate")
                        signalButton:SetSize(40, 14)
                        signalButton:SetPoint("CENTER", cellFrame, "CENTER")
                        signalButton:SetBackdrop({
                            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                            tile = true,
                            tileSize = 16,
                            edgeSize = 10,
                            insets = { left = 2, right = 2, top = 2, bottom = 2 }
                        })
                        signalButton:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
                        signalButton:SetBackdropBorderColor(0.35, 0.35, 0.38, 1.0)

                        local function createLamp(offsetX)
                            local lamp = signalButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                            lamp:SetPoint("CENTER", signalButton, "CENTER", offsetX, 0)
                            lamp:SetText("●")
                            if STANDARD_TEXT_FONT then
                                lamp:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
                            end
                            return lamp
                        end

                        signalButton.redLamp = createLamp(-10)
                        signalButton.yellowLamp = createLamp(0)
                        signalButton.greenLamp = createLamp(10)
                        cellFrame.signalButton = signalButton
                    end

                    local function setLamp(lamp, active, r, g, b)
                        if not lamp then
                            return
                        end
                        if active then
                            lamp:SetTextColor(r, g, b, 1)
                            lamp:SetAlpha(1)
                        else
                            lamp:SetTextColor(r * 0.35, g * 0.35, b * 0.35, 1)
                            lamp:SetAlpha(0.45)
                        end
                    end

                    local itemIdx = idx
                    local isRowConfirmable = itemIdx and entry and true or false
                    local signalState = LedgerEntrySignalState(entry)
                    if isRowConfirmable then
                        signalState = LedgerEntrySignalState(entry)
                    end
                    setLamp(signalButton.redLamp, signalState == "draft", 0.88, 0.22, 0.22)
                    setLamp(signalButton.yellowLamp, signalState == "ready", 0.96, 0.78, 0.12)
                    setLamp(signalButton.greenLamp, signalState == "confirmed", 0.20, 0.82, 0.20)
                    signalButton:SetShown(isRowConfirmable and true or false)
                    signalButton:SetEnabled(false)
                    signalButton:SetAlpha(isRowConfirmable and 1 or 0.45)
                    signalButton:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        if signalState == "confirmed" then
                            GameTooltip:SetText("초록불: 확정")
                        elseif signalState == "ready" then
                            GameTooltip:SetText("노란불: 낙찰가 입력됨")
                        else
                            GameTooltip:SetText("빨간불: 미확정")
                        end
                        GameTooltip:Show()
                    end)
                    signalButton:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                end),
            },
            {
                ["name"] = L["Value"],
                ["width"] = 100,
                ["align"] = "RIGHT",
                ["DoCellUpdate"] = valueUpdate,
            },
            {
                ["name"] = L["No Beneficiary"],
                ["width"] = 34,
                ["align"] = "CENTER",
                ["DoCellUpdate"] = CreateCellUpdate(function(cellFrame, entry, value)
                    -- 항상 체크박스 생성
                    local checkbox = cellFrame.checkbox
                    if not checkbox then
                        checkbox = CreateFrame("CheckButton", nil, cellFrame, "UICheckButtonTemplate")
                        checkbox:SetWidth(24)
                        checkbox:SetHeight(24)
                        checkbox:SetPoint("CENTER", cellFrame, "CENTER")
                        cellFrame.checkbox = checkbox
                    end
                    
                    local itemIdx = entry and entry.realItemIdx or (value and type(value) == "number" and value)
                    local checkboxValue = Database and Database.IsNoBeneficiarySetOnRow and Database:IsNoBeneficiarySetOnRow(entry) or (entry and entry.noBeneficiary and true or false)
                    checkbox:SetChecked(checkboxValue)
                    local isConfirmedRow = itemIdx and LedgerItemIsConfirmed(entry)
                    local canToggleNoBene = itemIdx and (not GUI._uiLocked) and (not isConfirmedRow)
                    checkbox:SetEnabled(canToggleNoBene and true or false)
                    
                    checkbox:SetScript("OnClick", function()
                        if not itemIdx then
                            return
                        end
                        if Database:IsLedgerEntryConfirmed(itemIdx) then
                            checkbox:SetChecked(Database:GetItemNoBeneficiary(itemIdx))
                            return
                        end
                        local cur = Database:GetItemNoBeneficiary(itemIdx)
                        local newVal = not cur
                        local indices = BeneficiaryEditIndices(entry, itemIdx, cellFrame._iraStackIndices)
                        local ledger = Database:GetCurrentLedger()
                        checkbox:SetChecked(newVal)
                        local changed = false
                        for _, sid in ipairs(indices) do
                            local itm3 = ledger and ledger.items[sid]
                            local before = itm3 and (itm3.noBeneficiary and true or false) or false
                            Database:SetItemNoBeneficiary(sid, newVal, true)
                            if ADDONSELF.sync then
                                local rid = itm3 and itm3.detail and itm3.detail.reliableItemID
                                local iLink = itm3 and itm3.detail and itm3.detail.item
                                ADDONSELF.sync:BroadcastNoBeneficiary(sid, rid, newVal, iLink)
                            end
                            if before ~= newVal then
                                changed = true
                            end
                        end

                        if changed then
                            if GUI._showPendingOnly then
                                GUI:UpdateLootTableFromDatabase()
                            elseif GUI.lootLogFrame then
                                GUI.lootLogFrame:Refresh()
                            end
                            UpdateAllDistributeLabel()
                            GUI:UpdateSummary()
                            GUI:UpdateNoBidCount()
                        else
                            checkbox:SetChecked(Database:GetItemNoBeneficiary(itemIdx))
                        end

                        if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                            local splitNumber = GUI:GetSplitNumber()
                            local distChk = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                            local checkAllDistribute = true
                            if distChk then
                                local rawValue = distChk:GetChecked()
                                checkAllDistribute = (rawValue == true) or (rawValue == 1)
                            end
                            GUI.exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), splitNumber, nil, checkAllDistribute))
                        end
                    end)

                    checkbox:SetEnabled(canToggleNoBene and true or false)
                    if not itemIdx then
                        checkbox:SetAlpha(0.45)
                    elseif GUI._uiLocked then
                        checkbox:SetAlpha(0.45)
                    elseif isConfirmedRow then
                        checkbox:SetAlpha(0.9)
                    else
                        checkbox:SetAlpha(1.0)
                    end
                    checkbox:Show()
                end),
            },
            {
                ["name"] = L["Confirmed"],
                ["width"] = 34,
                ["align"] = "CENTER",
                ["DoCellUpdate"] = CreateCellUpdate(function(cellFrame, entry, idx)
                    local checkbox = cellFrame.checkbox
                    if not checkbox then
                        checkbox = CreateFrame("CheckButton", nil, cellFrame, "UICheckButtonTemplate")
                        checkbox:SetWidth(24)
                        checkbox:SetHeight(24)
                        checkbox:SetPoint("CENTER", cellFrame, "CENTER")
                        cellFrame.checkbox = checkbox
                    end

                    local itemIdx = idx
                    local checked = itemIdx and LedgerItemIsConfirmed(entry) or false
                    checkbox:SetChecked(checked)
                    checkbox:SetShown(itemIdx and true or false)
                    checkbox:SetEnabled((not GUI._uiLocked) and itemIdx and true or false)
                    checkbox:SetAlpha(((not GUI._uiLocked) and itemIdx) and 1 or 0.45)

                    if not itemIdx then
                        return
                    end

                    checkbox:SetScript("OnClick", function()
                        clearAllFocus()
                        local indices = BeneficiaryEditIndices(entry, itemIdx, cellFrame._iraStackIndices)
                        local ledger = Database:GetCurrentLedger()
                        local wantConfirmed = not Database:IsLedgerEntryConfirmed(itemIdx)
                        local changed = false
                        checkbox:SetChecked(wantConfirmed)
                        for _, sid in ipairs(indices) do
                            local row = ledger and ledger.items and ledger.items[sid]
                            if row then
                                local oneChanged = Database:SetLedgerEntryConfirmed(sid, wantConfirmed, true)
                                if oneChanged and ADDONSELF.sync then
                                    local rid = row.detail and row.detail.reliableItemID
                                    local iLink = row.detail and row.detail.item
                                    ADDONSELF.sync:BroadcastConfirmed(sid, rid, row.confirmed, iLink)
                                    if row.type == "CREDIT" and row.detail and row.detail.type == "ITEM" then
                                        ADDONSELF.sync:BroadcastSaleState(sid, rid, row.saleState, iLink)
                                    end
                                end
                                changed = oneChanged or changed
                            end
                        end
                        if changed then
                            local sync = ADDONSELF.sync
                            if sync and sync.IsLedgerEditor and sync:IsLedgerEditor() and sync.enabled and not sync.suppressBroadcast then
                                local curLedger = Database:GetCurrentLedger()
                                if curLedger then
                                    curLedger._syncRev = (tonumber(curLedger._syncRev) or 0) + 1
                                end
                                if sync.ScheduleStatBroadcast then
                                    sync:ScheduleStatBroadcast()
                                end
                                if sync.ScheduleSyncAck then
                                    sync:ScheduleSyncAck()
                                end
                                if GUI.UpdateLedgerSyncMatchIndicator then
                                    GUI:UpdateLedgerSyncMatchIndicator()
                                end
                            end
                            -- Confirmed state changes the stack grouping key, so the table
                            -- must be rebuilt instead of only repainting visible rows.
                            Database:OnLedgerItemsChange()
                        else
                            checkbox:SetChecked(Database:IsLedgerEntryConfirmed(itemIdx))
                        end
                    end)
                end),
            }
        }, 10, 30, nil, f)

        self.lootLogFrame.head:SetHeight(15)
        self.lootLogFrame.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -62)

        -- 헤더 텍스트 미세 조정: 아이템(4번) 10px 우측, 낙찰가(7번) 20px 좌측
        do
            local function shiftHeaderText(colIdx, leftDelta, rightDelta, justify)
                local col = self.lootLogFrame.head and self.lootLogFrame.head.cols and self.lootLogFrame.head.cols[colIdx]
                if not col then return end
                for _, r in ipairs({ col:GetRegions() }) do
                    if r:GetObjectType() == "FontString" then
                        r:ClearAllPoints()
                        r:SetPoint("LEFT", col, "LEFT", 2.5 + (leftDelta or 0), 0)
                        r:SetPoint("RIGHT", col, "RIGHT", -2.5 - (rightDelta or 0), 0)
                        if justify then r:SetJustifyH(justify) end
                        return
                    end
                end
            end
            shiftHeaderText(4, 10, 0, "LEFT")    -- 아이템: 좌측 패딩 +10 (텍스트 우측 10px)
            shiftHeaderText(5, 15, 0, "LEFT")    -- 획득자/낙찰자: 좌측 패딩 +15 (텍스트 우측 15px)
            shiftHeaderText(7, 0, 20, "RIGHT")   -- 낙찰가: 우측 패딩 +20 (텍스트 좌측 20px)
        end

        -- head를 frame top 위로 4px 띄움 (item list와 header 사이 4px 간격)
        if self.lootLogFrame.head and self.lootLogFrame.head.ClearAllPoints then
            self.lootLogFrame.head:ClearAllPoints()
            self.lootLogFrame.head:SetPoint("BOTTOMLEFT", self.lootLogFrame.frame, "TOPLEFT", 4, 4)
            self.lootLogFrame.head:SetPoint("BOTTOMRIGHT", self.lootLogFrame.frame, "TOPRIGHT", -4, 4)
        end

        if ADDONSELF.theme then
            if ADDONSELF.theme.ApplyFrame and self.lootLogFrame.frame then
                ADDONSELF.theme:ApplyFrame(self.lootLogFrame.frame)
            end
            if ADDONSELF.theme.ApplyScrollBar and self.lootLogFrame.scrollframe and self.lootLogFrame.scrollframe.ScrollBar then
                ADDONSELF.theme:ApplyScrollBar(self.lootLogFrame.scrollframe.ScrollBar)
            end
            -- lib-st 가 scrollframe 안에 만든 scrolltrough/scrolltroughborder 배경 텍스처 투명화
            -- (스크롤바 뒤 진한 검정 배경 제거)
            if self.lootLogFrame.scrollframe and self.lootLogFrame.scrollframe.GetChildren then
                for _, child in ipairs({ self.lootLogFrame.scrollframe:GetChildren() }) do
                    if child.background and child.background.SetTexture then
                        child.background:SetTexture(nil)
                        child.background:Hide()
                    end
                end
            end
        end

        self:RefreshLockedButtons()

        self.lootLogFrame:RegisterEvents({
            ["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, sttable, button, ...)
                clearAllFocus()
                local entry, idx = GetEntryFromUI(rowFrame, cellFrame, data, cols, row, realrow, column, sttable)

                if not entry then
                    return
                end

                -- 2/6/8/9번째 컬럼(마이크/상태/확정/무득)은 자체 처리하므로 테이블 클릭에서는 무시
                if column == 2 or column == 6 or column == 8 or column == 9 then
                    return
                end

                if button == "RightButton" then
                    if GUI._uiLocked then
                        return
                    end
                    StaticPopupDialogs["IBERISRAIDAUCTION_DELETE_ITEM"].OnAccept = function()
                        StaticPopup_Hide("IBERISRAIDAUCTION_DELETE_ITEM")
                        Database:RemoveEntry(idx)
                    end
                    StaticPopup_Show("IBERISRAIDAUCTION_DELETE_ITEM")
                else
                    ChatEdit_InsertLink(entry["detail"]["item"])
                end
            end,
        })
    end


    -- report btn (전체출력) — 테마 적용, 우측 정렬 (4개 버튼 한 묶음)
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(65)
        b:SetHeight(25)
        b:SetPoint("BOTTOMLEFT", 408, 133)
        b:SetText("전체출력")
        b:RegisterForClicks("LeftButtonUp")

        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(b)
        else
            b:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            b:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1, 1, 1)
        end

        b:SetScript("OnClick", function(self)
            -- 전체출력 버튼은 항상 모든 정보를 표시 (checkf = false)
            -- 데이터베이스에서 최신 아이템 목록을 직접 가져옴
            local currentItems = GUI:GetItemsForTextOutput()

            -- DEBIT 아이템의 beneficiary 정보를 UI에서 가져와서 동기화
            if GUI.lootLogFrame then
                for _, entry in ipairs(GUI.lootLogFrame.data) do
                    if entry.cols and entry.cols[5] and entry.cols[5].value and entry.realItemIdx then
                        local dbItem = currentItems[entry.realItemIdx]
                        if dbItem and dbItem.type == "DEBIT" then
                            dbItem.beneficiary = entry.cols[5].value
                        end
                    end
                end
            end

            if not IsInRaid() then
                iraShowLocalReportInExportBox(GenReport(currentItems, GUI:GetSplitNumber(), "LOCAL", false))
                return
            end
            GenReport(currentItems, GUI:GetSplitNumber(), "RAID", false)
        end)

        -- 전체출력 버튼 참조를 위해 저장
        self.reportButton = b
    end

    -- summary btn (요약출력) — 테마 적용
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(65)
        b:SetHeight(25)
        b:SetPoint("LEFT", self.reportButton, "RIGHT", 5, 0)
        b:SetText("요약출력")
        b:RegisterForClicks("LeftButtonUp")

        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(b)
        else
            b:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            b:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalText = b:GetFontString()
        if normalText then
            normalText:SetTextColor(1, 1, 1, 1)
        end

        b:SetScript("OnClick", function(self)
            -- 왼쪽 클릭: 기본 공격대 채널로 요약 보고서 생성 (득자 제외)
            -- 데이터베이스에서 최신 아이템 목록을 직접 가져옴
            local currentItems = GUI:GetItemsForTextOutput()

            -- DEBIT 아이템의 beneficiary 정보를 UI에서 가져와서 동기화
            if GUI.lootLogFrame then
                for _, entry in ipairs(GUI.lootLogFrame.data) do
                    if entry.cols and entry.cols[5] and entry.cols[5].value and entry.realItemIdx then
                        local dbItem = currentItems[entry.realItemIdx]
                        if dbItem and dbItem.type == "DEBIT" then
                            dbItem.beneficiary = entry.cols[5].value
                        end
                    end
                end
            end

            if not IsInRaid() then
                iraShowLocalReportInExportBox(GenReport(currentItems, GUI:GetSplitNumber(), "LOCAL", true))
                return
            end
            GenReport(currentItems, GUI:GetSplitNumber(), "RAID", true)
        end)

        -- 전체출력 버튼 참조를 위해 저장
        self.summaryButton = b
    end

    -- export btn (텍스트로 도출 버튼)
    do
 	local lootLogFrame = self.lootLogFrame
        local exportEditbox = self.exportEditbox
        local countEdit = self.countEdit
	local ischeck = self.ischeck

        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(80)
        b:SetHeight(25)
        b:SetPoint("LEFT", GUI.clearLogButton, "RIGHT", 5, 0)
        b:SetText("거래기록 확인")

        if ADDONSELF.theme and ADDONSELF.theme.ApplyButton then
            ADDONSELF.theme:ApplyButton(b)
        else
            b:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            b:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            b:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1, 1, 1)
        end

        b:SetScript("OnClick", function()
            GUI:UpdateSummary()

            if exportEditbox:GetParent():IsShown() then
                lootLogFrame:Show()
                countEdit:Show()
                exportEditbox:GetParent():Hide()
                b:SetText(L["Export as text"])
            else
                countEdit:Hide()
                lootLogFrame:Hide()
                exportEditbox:GetParent():Show()
                b:SetText(L["Close text export"])
            end
            local splitNumber = GUI:GetSplitNumber()

            -- UpdateAllDistributeLabel과 동일한 로직 사용
            local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
            local checkAllDistribute = true
            if checkbox then
                local rawValue = checkbox:GetChecked()
                checkAllDistribute = (rawValue == true) or (rawValue == 1)
            end
            exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), splitNumber, nil, checkAllDistribute))
        end)

        self.exportButton = b
    end

    self:RefreshLockedButtons()

    -- 최소화 아이콘 생성
    local icon = CreateFrame("Button", "IberisRaidAuctionMinimizeIcon", UIParent, "BackdropTemplate")
    icon:SetWidth(30)
    icon:SetHeight(30)
    icon:Hide()

    -- 아이콘 스타일 (보더 없음)
    icon:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "",
        tile = false,
        tileSize = 0,
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    icon:SetBackdropColor(0.3, 0.3, 0.4, 0.95)

    -- 아이콘 텍스트 (RL)
    local iconText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    iconText:SetTextColor(1, 1, 1)
    iconText:SetText("IRA")
    iconText:SetPoint("CENTER", 0, 0)

    -- 드래그 가능 설정
    icon:SetMovable(true)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", icon.StartMoving)
    icon:SetScript("OnDragStop", icon.StopMovingOrSizing)

    -- 호버 효과
    icon:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.4, 0.5, 0.95)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("IberisRaidAuction (클릭하여 열기)")
        GameTooltip:Show()
    end)

    icon:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.4, 0.95)
        GameTooltip:Hide()
    end)

    -- 클릭 효과
    icon:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.3, 1.0)
    end)

    icon:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(0.4, 0.4, 0.5, 0.95)
    end)

    -- 위치 저장 함수
    local function SaveIconPosition()
        local point, relativeTo, relativePoint, xOfs, yOfs = icon:GetPoint()
        if point and relativePoint then
            local relativeToName = relativeTo and relativeTo:GetName() or "UIParent"
            local positionData = {
                point = point,
                relativeTo = relativeToName,
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs
            }
            -- 직접 전역 변수에 저장
            if not IberisRaidAuctionGlobalConfig then
                IberisRaidAuctionGlobalConfig = {}
            end
            IberisRaidAuctionGlobalConfig.minimizeIconPosition = positionData

            -- 강제 저장 호출
            Database:ForceSaveGlobalConfig()
            -- 디버그: 저장된 위치 출력
            -- Print(string.format("Icon position saved: %s %s %s %.1f %.1f",
            --     point, relativeToName, relativePoint, xOfs, yOfs))
        else
            -- Print("Failed to get icon position for saving")
        end
    end

    -- 위치 불러오기 함수
    local function LoadIconPosition()
        -- 직접 전역 변수 접근
        local pos = IberisRaidAuctionGlobalConfig and IberisRaidAuctionGlobalConfig.minimizeIconPosition

        if pos and pos.point and pos.relativePoint then
            -- 위치 정보 적용
            local relativeFrame = _G[pos.relativeTo] or UIParent
            if relativeFrame then
                icon:ClearAllPoints()
                icon:SetPoint(pos.point, relativeFrame, pos.relativePoint, pos.xOfs or 0, pos.yOfs or 0)
                -- Print("Icon position applied successfully")
                return true  -- 위치를 성공적으로 불러옴
            else
                -- Print(string.format("Failed to find relative frame: %s", pos.relativeTo))
            end
        else
            -- Print("No saved icon position found")
        end
        return false  -- 저장된 위치가 없음
    end

    -- 아이콘 클릭 시 메인 창 열기
    icon:SetScript("OnClick", function()
        icon:Hide()
        f:Show()
    end)

    -- 드래그 중지 시 위치 저장
    icon:HookScript("OnDragStop", function()
        SaveIconPosition()
    end)

    -- 위치 불러오기
    if not LoadIconPosition() then
        -- 저장된 위치가 없으면 기본 위치 설정
        icon:SetPoint("CENTER", 0, 0)
    end

    GUI.minimizeIcon = icon

    -- 매크로 버튼 1 (카운트다운)
    do
        local macroBtn = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
        macroBtn:SetWidth(30)
        macroBtn:SetHeight(30)
        macroBtn:SetPoint("LEFT", icon, "RIGHT", 2, 0)

        -- 버튼 스타일 (보더 없음)
        macroBtn:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "",
            tile = false,
            tileSize = 0,
            edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        macroBtn:SetBackdropColor(0.2, 0.2, 0.3, 0.95)

        -- 버튼 텍스트
        local btnText = macroBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetTextColor(1, 1, 1)
        btnText:SetText("5")
        btnText:SetPoint("CENTER", 0, 0)

        -- 호버 효과
        macroBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.4, 0.95)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("카운트다운 매크로 (5~1)")
            GameTooltip:Show()
        end)

        macroBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.3, 0.95)
            GameTooltip:Hide()
        end)

        -- 클릭 효과
        macroBtn:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.15, 1.0)
        end)

        macroBtn:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.4, 0.95)
        end)

        -- 카운트다운 전역 변수
        GUI.countdownActive = false
        GUI.countdownTimer = nil
        GUI.currentCount = 5

        -- 매크로 실행
        macroBtn:SetScript("OnClick", function()
            if not GUI.countdownActive then
                GUI.countdownActive = true
                GUI.currentCount = 5

                -- 데이터베이스에서 메시지 가져오기
                local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                    count = "--- %d",
                    closed = "--- 입찰 마감 ---",
                    resume = "--- 신규 입찰 ! 재개합니다 ---"
                })

                -- 시작 메시지 전송
                SendChatMessage(string.format(messages.count, GUI.currentCount), "RAID_WARNING")

                local function countStep()
                    if GUI.countdownActive and GUI.currentCount > 1 then
                        GUI.currentCount = GUI.currentCount - 1
                        SendChatMessage(string.format(messages.count, GUI.currentCount), "RAID_WARNING")
                        GUI.countdownTimer = C_Timer.After(1.0, countStep)
                    else
                        if GUI.countdownActive then
                            SendChatMessage(messages.closed, "RAID_WARNING")
                        end
                        GUI.countdownActive = false
                        GUI.countdownTimer = nil
                    end
                end

                GUI.countdownTimer = C_Timer.After(1.0, countStep)
            end
        end)

        -- 메인 창이 표시될 때는 숨기고, 최소화 아이콘이 표시될 때는 보이기
        macroBtn:Hide()
        icon:HookScript("OnShow", function()
            macroBtn:Show()
        end)
        icon:HookScript("OnHide", function()
            macroBtn:Hide()
        end)
    end

    -- 매크로 버튼 2 (END 버튼)
    do
        local macroBtn2 = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
        macroBtn2:SetWidth(30)
        macroBtn2:SetHeight(30)
        macroBtn2:SetPoint("LEFT", icon, "RIGHT", 34, 0)

        -- 버튼 스타일 (보더 없음)
        macroBtn2:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "",
            tile = false,
            tileSize = 0,
            edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        macroBtn2:SetBackdropColor(0.6, 0.2, 0.2, 0.95)

        -- 버튼 텍스트
        local btnText2 = macroBtn2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText2:SetTextColor(1, 1, 1)
        btnText2:SetText("S")
        btnText2:SetPoint("CENTER", 0, 0)

        -- 호버 효과
        macroBtn2:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.8, 0.3, 0.3, 0.95)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("카운트다운 중단 및 STOP 메시지")
            GameTooltip:Show()
        end)

        macroBtn2:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.6, 0.2, 0.2, 0.95)
            GameTooltip:Hide()
        end)

        -- 클릭 효과
        macroBtn2:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.4, 0.1, 0.1, 1.0)
        end)

        macroBtn2:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.8, 0.3, 0.3, 0.95)
        end)

        -- 매크로 실행 (중단 및 END 메시지)
        macroBtn2:SetScript("OnClick", function()
            if GUI.countdownActive then
                GUI.countdownActive = false
                if GUI.countdownTimer then
                    GUI.countdownTimer = nil
                end

                -- 데이터베이스에서 재개 메시지 가져오기
                local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                    count = "--- %d",
                    closed = "--- 입찰 마감 ---",
                    resume = "--- 신규 입찰 ! 재개합니다 ---"
                })

                SendChatMessage(messages.resume, "RAID_WARNING")
            end
        end)

        -- 메인 창이 표시될 때는 숨기고, 최소화 아이콘이 표시될 때는 보이기
        macroBtn2:Hide()
        icon:HookScript("OnShow", function()
            macroBtn2:Show()
        end)
        icon:HookScript("OnHide", function()
            macroBtn2:Hide()
        end)

        -- MinimapButton.RemoveAll 에러 방지 (nil 체크 추가)
        if MinimapButton and MinimapButton.RemoveAll then
            MinimapButton.RemoveAll()
        end

        MinimapButton = {
            ["worldMapButton"] = worldMapButton,
            ["minimapButton"] = icon,
            ["macroBtn"] = macroBtn,
            ["macroBtn2"] = macroBtn2,
        }
    end

    -- 애드온 버전 라벨은 메인 타이틀 우측에 합쳐서 표시 (별도 라벨 제거)

    if ADDONSELF.sync then
        ADDONSELF.sync:UpdateHostStatus()
        self:RefreshRaidSyncUI()
    end
end

-- CLI에서 GUI 버튼 업데이트를 위해 호출하는 함수
function GUI:UpdateAutoLootDropdown(value)
    Database:SetConfig("autoaddloot", AUTOADDLOOT_TYPE_RAID)
end

function GUI:UpdateRoundingDropdown()
    GUI.roundingLevel = 0
    if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
        local splitNumber = GUI:GetSplitNumber()
        local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
        local checkAllDistribute = true
        if checkbox then
            local rawValue = checkbox:GetChecked()
            checkAllDistribute = (rawValue == true) or (rawValue == 1)
        end
        GUI.exportEditbox:SetText(GenExport(GUI:GetItemsForTextOutput(), splitNumber, nil, checkAllDistribute))
    end
end

function UpdateAllDistributeLabel()
    if not GUI.allDistributeLabel then
        return
    end

    local totalMembers = tonumber(GUI.countEdit:GetText()) or 10

    local checkAllDistribute = GUI._checkAllDistributeState
    if checkAllDistribute == nil then checkAllDistribute = true end

    if checkAllDistribute then
        GUI.allDistributeLabel:SetText("전체분배 (" .. totalMembers .. ")")
    else
        local beneficiaryCount = GUI:GetBeneficiaryCount()
        local actualMembers = math.max(1, totalMembers - beneficiaryCount)
        GUI.allDistributeLabel:SetText("무득분배 (" .. actualMembers .. ")")
    end

    if GUI._updateDistBtnStyle then
        GUI._updateDistBtnStyle()
    end
    if GUI._updateSplitInfoLabel then
        GUI._updateSplitInfoLabel()
    end
end

ADDONSELF.RefreshLootGuiAfterSync = function()
    if GUI.UpdateLootTableFromDatabase then GUI:UpdateLootTableFromDatabase() end
    if GUI.UpdateSummary then GUI:UpdateSummary() end
    if GUI.UpdateNoBidCount then GUI:UpdateNoBidCount() end
    UpdateAllDistributeLabel()
    if GUI.UpdateLedgerSyncMatchIndicator then
        GUI:UpdateLedgerSyncMatchIndicator()
    end
end

function GUI:UpdateLedgerSyncMatchIndicator()
    local ind = self.ledgerSyncMatchIndicator
    if not ind then return end
    local s = ADDONSELF.sync
    if not s or not s.enabled or not IsInRaid() then
        ind:Hide()
        return
    end
    ind:Show()
    local fs = ind:GetFontString()
    if not fs then return end
    fs:SetText("\226\151\143")
    if s.IsLedgerSyncMatchOK and s:IsLedgerSyncMatchOK() then
        fs:SetTextColor(0.15, 0.95, 0.25)
    else
        fs:SetTextColor(0.95, 0.2, 0.2)
    end
end

function GUI:GetCheckTradeButton()
    return 1
end


RegEvent("VARIABLES_LOADED", function()
    GUI:UpdateLootTableFromDatabase()
    UpdateAllDistributeLabel()
    if GUI.UpdateLedgerSyncMatchIndicator then
        GUI:UpdateLedgerSyncMatchIndicator()
    end
end)

RegEvent("GROUP_ROSTER_UPDATE", function()
    if not GUI.countEdit then return end
    local savedCount = Database:GetConfigOrDefault("splitcount", nil)
    if savedCount then return end
    local raidSize = 0
    if IsInRaid() then
        for i = 1, MAX_RAID_MEMBERS do
            if GetRaidRosterInfo(i) then raidSize = raidSize + 1 end
        end
    end
    local newDefault = 10
    if raidSize > 25 then newDefault = 40
    elseif raidSize > 10 then newDefault = 25 end
    GUI.countEdit:SetText(newDefault)
    Database:SetConfig("splitcount", newDefault)
    GUI:UpdateSummary()
    UpdateAllDistributeLabel()
end)

RegEvent("ADDON_LOADED", function()
    -- CLI 초기화 후 GUI 초기화를 위해 약간 지연
    C_Timer.After(0.1, function()
        local ok, err = xpcall(function()
            GUI:Init()
            Database:RegisterChangeCallback(function()
                if GUI.recipeNoBeneficiaryButton and GUI.recipeNoBeneficiaryButton:GetChecked() then
                    GUI.applyRecipeNoBeneficiary(true)
                else
                    GUI:UpdateLootTableFromDatabase()
                end
            end)

            if GUI.mainframe and GUI.mainframe:IsShown() then
                GUI:UpdateLootTableFromDatabase()
            end
            if GUI.UpdateLedgerSyncMatchIndicator then
                GUI:UpdateLedgerSyncMatchIndicator()
            end
        end, function(caughtErr)
            return tostring(caughtErr or "unknown")
        end)
        if not ok then
            ADDONSELF.print("|cFFFF4444[초기화 오류]|r " .. tostring(err))
        end
    end)


    -- raid frame handler

    do
        if _G.RaidFrame then
            local b = CreateFrame("Button", nil, _G.RaidFrame, "UIPanelButtonTemplate")
            b:SetWidth(100)
            b:SetHeight(20)
            b:SetPoint("TOPRIGHT", -25, 0)
            b:SetText(L["IberisRaidAuction"])
            b:SetScript("OnClick", function()
                if GUI.mainframe:IsShown() then
                    GUI.mainframe:Hide()
                else
                    GUI.mainframe:Show()
                end
            end)
        end

        local hooked = false

        hooksecurefunc("RaidFrame_LoadUI", function()
            if hooked then
                return
            end

            local enter = function(l, idx)
                local tooltip = GUI.commtooltip
                if not tooltip then return end
                tooltip:SetOwner(l, "ANCHOR_TOP")

                local c = 0
                local members = {}

                for i = 1, MAX_RAID_MEMBERS do
                    local name, _, subgroup, _, _, classFilename = GetRaidRosterInfo(i)
                    if name and subgroup == idx then
                        local _, _, _, colorCode = GetClassColor(classFilename);
                        members[name] = {
                            text = WrapTextInColorCode(name, colorCode),
                            cost = 0,
                        }
                        c = c + 1
                    end
                end

                local special = false
                local teamtotal = 0
                -- 툴팁용 calcavg 호출 - 체크박스 상태 반영
                local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                local checkAllDistribute = checkbox and (checkbox:GetChecked() == true or checkbox:GetChecked() == 1) or true
                local _, avg = calcavg(Database:GetCurrentLedger()["items"], GUI:GetSplitNumber(), function(entry, cost)
                    local b = GetEntryDisplayBeneficiary(entry)

                    if members[b] then
                        special = true
                        members[b].cost = members[b].cost + cost
                        teamtotal = teamtotal + cost
                    end
                end, nil, checkAllDistribute)

                teamtotal = teamtotal + c * avg

                if c > 0 then
                    tooltip:SetText(L["Member credit for subgroup"])
                    tooltip:AddLine(L["Subgroup total"] .. " : " .. GetMoneyStringComma(teamtotal))
                    tooltip:AddLine(L["Per Member"] .. " : " .. GetMoneyStringComma(avg))

                    if special then
                        tooltip:AddLine(L["Special Members"])
                        for _, member in pairs(members) do
                            if member.cost > 0 then
                                tooltip:AddLine(member.text .. " : " .. GetMoneyStringComma(avg + member.cost) )
                            end
                        end

                    end

                    tooltip:Show()
                end
            end

            local leave = function()
                local tooltip = GUI.commtooltip
                if not tooltip then return end
                tooltip:Hide()
                tooltip:SetOwner(UIParent, "ANCHOR_NONE")
            end

            for i = 1, NUM_RAID_GROUPS do
                local l = _G["RaidGroup" .. i .."Label"]
                if l then
                    l:SetScript("OnEnter", function() enter(l, i) end)
                    l:SetScript("OnLeave", leave)
                end
            end

            hooked = true
        end)
    end
end)

StaticPopupDialogs["IBERISRAIDAUCTION_CLEARMSG"] = {
    text = L["Remove all records?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    multiple = 0,
    OnAccept = function()
        Database:NewLedger()
    end,
}

StaticPopupDialogs["IBERISRAIDAUCTION_DELETE_ITEM"] = {
    text = L["Remove this record?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    multiple = 0,
}

