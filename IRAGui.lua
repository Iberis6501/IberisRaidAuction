-- 수정된 IberisRaidAuction/gui.lua
local _, ADDONSELF = ...

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
end

function GUI:Hide()
    self.mainframe:Hide()
end

function GUI:Summary()
    -- calcavg 함수 내부에서 noBeneficiary 필터링하도록 원본 데이터 전달
    local ledger = Database:GetCurrentLedger()

    -- 현재 체크박스 상태 읽기
    local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
    local checkAllDistribute = true
    if checkbox then
        local rawValue = checkbox:GetChecked()
        checkAllDistribute = (rawValue == true) or (rawValue == 1)
    end

    -- checkAllDistribute가 true이면 전체 분배, false이면 득자 제외
    return ADDONSELF.calcavg(ledger["items"], GUI:GetSplitNumber(), nil, nil, checkAllDistribute)
end

local CRLF = ADDONSELF.CRLF

function GUI:UpdateSummary()
    if not self.summaryLabel then return end
    local profit, avg, revenue, expense = self:Summary()

    -- 수동(+수익)만 직접 합산
    local ledger = Database:GetCurrentLedger()
    local manualRevenue = 0
    local beneficiaries = {}
    for _, item in pairs(ledger.items or {}) do
        if item.type == "CREDIT" and item.cost and item.cost > 0
                and (item.costtype == nil or item.costtype == "GOLD") then
            if not (item.detail and item.detail.item) then
                manualRevenue = manualRevenue + item.cost * 10000
            end
            -- 득자 = 자동 캡처 전리품 받은 사람만 (수동 +수익 받은 기부자는 제외)
            if item.beneficiary and item.beneficiary ~= "" and item.noBeneficiary ~= true
                    and item.detail and item.detail.item then
                beneficiaries[item.beneficiary] = true
            end
        end
    end
    local beneficiaryCount = 0
    for _ in pairs(beneficiaries) do beneficiaryCount = beneficiaryCount + 1 end

    local autoRevenue  = (revenue or 0) - manualRevenue
    local distribution = profit or 0
    local fmt = ADDONSELF.GetMoneyStringL or GetMoneyString

    -- 분배는 항상 골드 단위 floor (사용자 손해 방지)
    local floorNum   = math.floor((avg or 0) / 10000) * 10000
    local partyMoney = floorNum * 5
    local party4     = floorNum * 4
    local party3     = floorNum * 3
    local party2     = floorNum * 2

    local splitCount = self:GetSplitNumber() or 0

    self.summaryLabel:SetText(
        "|cffffffff아이템 " .. fmt(autoRevenue, true) .. "|r"
        .. " |cff60c0ff+ 수익 " .. fmt(manualRevenue, true) .. "|r"
        .. " |cffff9933- 지출 " .. fmt(expense or 0, true) .. "|r"
        .. " |cffffd700= 분배금 " .. fmt(distribution, true) .. "|r"
        .. CRLF
        .. "|cff60e060개인당 " .. fmt(floorNum, true) .. "|r"
        .. " |cffa080ff파티당 " .. fmt(partyMoney, true) .. "|r"
        .. " |cff80b0d04명당 " .. fmt(party4, true) .. "|r"
        .. " |cff80c0a03명당 " .. fmt(party3, true) .. "|r"
        .. " |cffc0a0802명당 " .. fmt(party2, true) .. "|r"
    )

    -- 분배 인원 라벨도 같이 갱신 (득자 카운트 변동)
    if self.splitLabel then
        self.splitLabel:SetText(L["Split into (Current %d)"]:format(GetRosterNumber(), beneficiaryCount))
    end

    -- 최다지출자 / 내 경매지출 / 레이드 시작시 내 골드 (정산 라인 밑) — RaidBook 패턴
    if self.bottomStatsLabel then
        local playerName = UnitName("player") or ""
        local spendByPlayer = {}
        for _, item in pairs(ledger["items"] or {}) do
            if item.type == "CREDIT" and item.beneficiary and item.beneficiary ~= ""
                    and item.cost and item.cost > 0 and item.noBeneficiary ~= true then
                spendByPlayer[item.beneficiary] = (spendByPlayer[item.beneficiary] or 0) + item.cost
        end
        end
        local topSpender, topAmount = nil, 0
        for name, amount in pairs(spendByPlayer) do
            if amount > topAmount then
                topSpender, topAmount = name, amount
            end
        end
        local myAmount = spendByPlayer[playerName] or 0
        local bn = BreakUpLargeNumbers or function(n) return tostring(n) end

        local parts = {}
        if topSpender then
            table.insert(parts, string.format("|cffd8d8d8최다지출자: %s (%s골드)|r", topSpender, bn(topAmount)))
        end
        if myAmount > 0 then
            table.insert(parts, string.format("|cffb8d4ff내 경매지출: %s골드|r", bn(myAmount)))
        end
        local startCopper = ledger._startMoneyCopper
        if startCopper then
            local startGold = math.floor(startCopper / 10000)
            table.insert(parts, string.format("|cffc8c8a0레이드 시작시 내 골드: %s골드|r", bn(startGold)))
        end
        self.bottomStatsLabel:SetText(table.concat(parts, "    "))
    end
end

function GUI:GetSplitNumber()
    return tonumber(self.countEdit:GetText()) or 0
end

function GUI:GetBeneficiaryCount()
    local ledger = Database:GetCurrentLedger()
    local beneficiaries = {}

    for _, item in pairs(ledger["items"]) do
        -- 골드 0원인 아이템과 noBeneficiary 아이템은 득자 계산에서 제외 (calcavg 함수와 동일한 로직)
        if item.beneficiary and item.beneficiary ~= "" and item.type == "CREDIT" and item.cost and item.cost > 0 and item.noBeneficiary ~= true then
            beneficiaries[item.beneficiary] = true
        end
    end

    local count = 0
    for _ in pairs(beneficiaries) do
        count = count + 1
    end

    return count
end


function GUI:UpdateLootTableFromDatabase()
    if not self.lootLogFrame then
        return  -- 아직 초기화되지 않았으면 무시
    end

    local data = {}
    local ledger = Database:GetCurrentLedger()

    -- 현재 UI의 DEBIT 아이템 득자 정보 보존
    local currentDebitBeneficiaries = {}

    -- 현재 UI 테이블에서 DEBIT 득자 정보 수집 (실시간 동기화용)
    if self.lootLogFrame and self.lootLogFrame.data then
        for _, entry in ipairs(self.lootLogFrame.data) do
            if entry.realItemIdx then
                local ledgerItem = ledger["items"][entry.realItemIdx]
                if ledgerItem and ledgerItem.type == "DEBIT" then
                    -- entry.beneficiary와 cols[4].value 모두 확인하여 최신 값 수집
                    local uiBeneficiary = entry.beneficiary or (entry.cols and entry.cols[4] and entry.cols[4].value) or ""
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
        if item and (item.type == "CREDIT" or item.type == "DEBIT") and item.detail and item.detail.type == "ITEM" then
            -- GetItemInfo는 이름만 얻고 ID는 저장된 reliableItemID 사용 (GetItemInfo 버그 회피)
            local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemIcon, _, itemSellPrice = GetItemInfo(item.detail.item)

            -- GetItemInfo 실패 시 안전한 기본값 설정
            itemName = itemName or "Unknown Item"
            local itemRarity = itemQuality or 0
            local beneficiary = item.beneficiary or ""
            local cost = item.cost or 0
            -- 금액 정규화
            local normalizedCost = string.format("%.2f", tonumber(cost) or 0)

            -- 저장된 reliableItemID를 항상 우선적으로 사용
            local safeItemID = item.detail.reliableItemID

            if not safeItemID then
                -- 임시 해시 생성 (이상적으로는 여기 도달하면 안됨)
                safeItemID = string.len(item.detail.item or "") .. "_" .. string.byte(item.detail.item or "", 1) .. "_" .. string.byte(item.detail.item or "", -1)
            end

            -- 동일 아이템이 여러 개 드랍됐을 때 각각을 개별 항목으로 표시.
            -- 키에 ledger 인덱스를 포함시켜 항상 그룹당 1개가 되도록 함 (GDKP 분배 워크플로).
            local key = tostring(safeItemID) .. "_" .. beneficiary .. "_" .. normalizedCost .. "_" .. i

            if not itemGroups[key] then
                itemGroups[key] = {
                    count = 0,
                    itemIndices = {},
                    itemData = item
                }
            end

            itemGroups[key].count = itemGroups[key].count + 1
            table.insert(itemGroups[key].itemIndices, i)
        end
    end

    -- DEBIT 항목 및 그룹화되지 않은 CREDIT 항목 추가
    for i = #ledger["items"], 1, -1 do
        local item = ledger["items"][i]
        if item then
            local shouldShow = false
            local uiBeneficiary = ""

            -- DEBIT 항목은 항상 표시
            if item.type == "DEBIT" then
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
                uiBeneficiary = item.beneficiary or ""
            end

            if shouldShow then
                table.insert(data, {
                    ["cols"] = {
                        { ["value"] = i },                    -- 1: 안 보임 idx
                        { ["value"] = "" },                   -- 2: 스피커
                        { ["value"] = i },                    -- 3: 순번 (보이는 idx)
                        { ["value"] = uiBeneficiary },        -- 4: DEBIT 득자 임시 저장소 (기존 cols[4])
                        { ["value"] = "" },                   -- 5: Entry
                        { ["value"] = "" },                   -- 6: Beneficiary
                        { ["value"] = "" },                   -- 7: Value
                        { ["value"] = item.noBeneficiary or false }  -- 8: NoBeneficiary
                    },
                    ["realItemIdx"] = i,
                    ["realItemData"] = item,
                    ["isStacked"] = false,
                    ["beneficiary"] = uiBeneficiary  -- entry.beneficiary 필드에 UI 값 초기화
                })
            end
        end
    end

    -- 그룹화된 아이템 추가 (최신순)
    local sortedGroups = {}
    for key, group in pairs(itemGroups) do
        table.insert(sortedGroups, {key = key, group = group})
    end
    -- 그룹을 최신 인덱스 순으로 정렬
    table.sort(sortedGroups, function(a, b)
        return (a.group.itemIndices[1] or 0) > (b.group.itemIndices[1] or 0)
    end)

    for _, sortedData in ipairs(sortedGroups) do
        local group = sortedData.group
        -- 그룹의 첫 번째 아이템으로 표시 (원본 데이터는 수정하지 않음)
        local firstItem = group.itemData
        local firstItemIdx = group.itemIndices[1]

        -- UI에서 수집된 최신 beneficiary 값을 우선 적용
        local uiBeneficiary = currentDebitBeneficiaries[firstItemIdx] or firstItem.beneficiary or ""
        -- [알수없음]을 빈 문자열로 변환하여 DEBIT 초기값 문제 해결
        if uiBeneficiary == L["[Unknown]"] then
            uiBeneficiary = ""
        end

                table.insert(data, {
            ["cols"] = {
                { ["value"] = firstItemIdx },         -- 1: 안 보임 idx
                { ["value"] = "" },                   -- 2: 스피커
                { ["value"] = firstItemIdx },         -- 3: 순번
                { ["value"] = uiBeneficiary },        -- 4: DEBIT 득자 임시 저장소 (기존 cols[4])
                { ["value"] = "" },                   -- 5: Entry
                { ["value"] = "" },                   -- 6: Beneficiary
                { ["value"] = "" },                   -- 7: Value
                { ["value"] = firstItem.noBeneficiary or false }  -- 8: NoBeneficiary
            },
            ["realItemIdx"] = firstItemIdx,
            ["realItemData"] = firstItem,  -- 원본 데이터 참조 (수정 안 함)
            ["isStacked"] = true,
            ["stackCount"] = group.count,  -- 표시 데이터에만 저장
            ["stackIndices"] = group.itemIndices,  -- 표시 데이터에만 저장
            ["beneficiary"] = uiBeneficiary  -- entry.beneficiary 필드에 UI 값 초기화
        })
    end

    
    -- ScrollingTable에 데이터 설정
    self.lootLogFrame:SetData(data)

    -- UI 업데이트 후 보존한 DEBIT 득자 정보를 데이터베이스에 복원
    C_Timer.After(0.1, function()
        for idx, beneficiary in pairs(currentDebitBeneficiaries) do
            if ledger.items[idx] and ledger.items[idx].type == "DEBIT" then
                ledger.items[idx].beneficiary = beneficiary

                -- UI에도 다시 적용
                if self.lootLogFrame and self.lootLogFrame.data then
                    for _, entry in ipairs(self.lootLogFrame.data) do
                        if entry.realItemIdx == idx then
                            entry.cols[4].value = beneficiary
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
    local copper = 0
    if not IsInGroup() then
        if digitsCounter == 3 then
            -- gold + silber + copper
            copper = (digits[1]*10000)+(digits[2]*100)+(digits[3])
        elseif digitsCounter == 2 then
            -- silber + copper
            copper = (digits[1]*100)+(digits[2])
        else
           -- copper
            copper = digits[1]
        end
    else 
        if digitsCounter == 4 then
            -- gold + silber + copper
            copper = (digits[1]*10000)+(digits[2]*100)+(digits[3])
        elseif digitsCounter == 3 then

            -- silber + copper
            copper = (digits[1]*100)+(digits[2])
        else
           -- copper
            copper = digits[1]
        end
    end

    return copper
end



local function GetEntryFromUI(rowFrame, cellFrame, data, cols, row, realrow, column, table)
    local rowdata = table:GetRow(realrow)
    if not rowdata then
        return nil
    end

    local celldata = table:GetCell(rowdata, column)
    local idx = rowdata["cols"][1].value

    local ledger = Database:GetCurrentLedger()
    local entry = ledger["items"][idx]

    -- 그룹화된 데이터 정보 추가
    if rowdata.isStacked then
        entry.stackCount = rowdata.stackCount
        entry.stackIndices = rowdata.stackIndices
        entry.isStacked = rowdata.isStacked
    end

    return entry, idx
end

-- ===== 경매 시작 알림 (RaidBook RBGui.lua 차용) =====
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

local function AnnounceAuction(itemLink)
    if not itemLink or itemLink == "" then return end
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

local function CreateCellUpdate(cb)
    return function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, table, ...)
        if not fShow then
            return
        end

        local entry, idx = GetEntryFromUI(rowFrame, cellFrame, data, cols, row, realrow, column, table)

        if entry then
            cb(cellFrame, entry, idx)
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

function GUI:Init()
    checkf = 0;
    checkTrade = 1;

    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetWidth(650)
    -- 메인프레임 height = bottomStatsLabel 라인 끝(-742) + 28px 갭 = 770
    f:SetHeight(770)
    ADDONSELF.theme:ApplyFrame(f)
    f:SetPoint("CENTER", 0, 0)
    f:SetToplevel(true)
    f:EnableMouse(true)

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

    self.mainframe = f

    -- 좌측 상단 사인
    do
        local sig = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sig:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
        sig:SetText("|cff91d7f2IberisRaidAuction|r  |cff909090made by 서약선|r")
    end

    -- 우하단 그립 드래그 = 전체 scale 변경 (균일 비율, 자식 위젯 레이아웃 영향 없음)
    do
        local savedScale = Database:GetGlobalConfigOrDefault("uiScale", 1.0)
        f:SetScale(savedScale)

        local MIN_SCALE, MAX_SCALE = 0.6, 2.0
        local SENSITIVITY = 200 -- 마우스 200px 이동당 scale 1.0 변화

        local rh = CreateFrame("Button", nil, f)
        rh:SetSize(16, 16)
        rh:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
        rh:SetFrameStrata("HIGH")
        rh:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        rh:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        rh:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

        local startScale, startX
        rh:SetScript("OnMouseDown", function()
            startScale = f:GetScale()
            startX     = select(1, GetCursorPosition())
            rh:SetScript("OnUpdate", function()
                local mx = select(1, GetCursorPosition())
                local delta = (mx - startX) / SENSITIVITY
                local newScale = math.max(MIN_SCALE, math.min(MAX_SCALE, startScale + delta))
                f:SetScale(newScale)
            end)
        end)
        rh:SetScript("OnMouseUp", function()
            rh:SetScript("OnUpdate", nil)
            Database:SetGlobalConfig("uiScale", f:GetScale())
        end)
        rh:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("창 크기 조절")
            GameTooltip:AddLine(string.format("드래그: 좌우로 움직여 크기 변경 (%d%% ~ %d%%)", MIN_SCALE * 100, MAX_SCALE * 100), 1, 1, 1)
            GameTooltip:AddLine(string.format("현재: %d%%", f:GetScale() * 100), 0.7, 0.85, 1)
            GameTooltip:Show()
        end)
        rh:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- 우측 상단 최소화 버튼 (테마: 호버 녹색 강조)
    do
        local minimizeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        minimizeBtn:SetWidth(24)
        minimizeBtn:SetHeight(24)
        minimizeBtn:SetPoint("TOPRIGHT", f, -29, -5) -- X 버튼 왼쪽

        ADDONSELF.theme:ApplyButton(minimizeBtn, {
            bgHover     = { 0.20, 0.80, 0.20, 0.95 },
            borderHover = { 0.40, 1.00, 0.40, 1.00 },
            bgPressed   = { 0.10, 0.60, 0.10, 1.00 },
        })

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
        closeBtn:SetHeight(24)
        closeBtn:SetPoint("TOPRIGHT", f, -5, -5)

        ADDONSELF.theme:ApplyButton(closeBtn, {
            bgHover     = { 0.80, 0.20, 0.20, 0.95 },
            borderHover = { 1.00, 0.40, 0.40, 1.00 },
            bgPressed   = { 0.60, 0.10, 0.10, 1.00 },
        })

        local text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetTextColor(1, 1, 1)
        text:SetText("X")
        text:SetPoint("CENTER", 0, 0)

        closeBtn:SetScript("OnClick", function() f:Hide() end)
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
        local t = self:GetText()
        local b = strbyte(char)

        -- allow number or dot only if no dot in str
        if (48 <= b and b <= 57) then
            return
        end
        
        if char == "." and string.find(t, ".", 1, true) == #t then
            return
        end

        self:SetText(string.sub(t, 0, #t - 1))
    end    

    -- 분배 인원 라벨 먼저 (countEdit 위치 기준점)
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -626)
        self.splitLabel = t
        -- 초기 텍스트 (득자 0)
        t:SetText(L["Split into (Current %d)"]:format(GetRosterNumber(), 0))
        -- roster 변경 시 UpdateSummary가 splitLabel도 갱신
        RegEvent("GROUP_ROSTER_UPDATE", function() GUI:UpdateSummary() end)
        RegEvent("CHAT_MSG_SYSTEM",     function() GUI:UpdateSummary() end)
    end

    -- split editbox (라벨 우측에 바짝 붙임)
    do
        local t = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        t:SetWidth(50)
        t:SetHeight(20)
        t:SetPoint("LEFT", self.splitLabel, "RIGHT", 8, -1)
        t:SetAutoFocus(false)
        t:SetMaxLetters(4)
        ADDONSELF.theme:ApplyEditBox(t)
        -- 메인 BG와 명확히 구분되게 더 진한 배경
        if t.SetBackdropColor then
            t:SetBackdropColor(0.02, 0.02, 0.03, 0.98)
        end
        -- t:SetNumeric(true)
        t:SetScript("OnTextChanged", function()
            -- 사용자가 입력한 분배 인원 값을 데이터베이스에 저장
            local currentValue = tonumber(t:GetText()) or 40
            Database:SetConfig("splitcount", currentValue)

            self:UpdateSummary()
            UpdateAllDistributeLabel() -- 분배 인원 변경 시 라벨도 업데이트

            -- 텍스트 도출 모드가 열려있으면 텍스트 내용도 업데이트
            if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                local checkAllDistribute = true
                if checkbox then
                    local rawValue = checkbox:GetChecked()
                    checkAllDistribute = (rawValue == true) or (rawValue == 1)
                end
                  GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], currentValue, nil, checkAllDistribute))
            end
        end)
        t:SetScript("OnEnterPressed", clearAllFocus)
        t:SetScript("OnChar", mustnumber)

        -- 데이터베이스에 저장된 분배 인원 값 로드 (기본값 40)
        local savedSplitCount = Database:GetConfigOrDefault("splitcount", 40)
        t:SetText(savedSplitCount)
        self.countEdit = t
    end
    --





    --

    -- 올분/무득분 토글 버튼 — 외형: 분홍 테두리 / 기능: RaidBook 패턴
    do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetWidth(110)
        btn:SetHeight(22)
        btn:SetPoint("LEFT", self.countEdit, "RIGHT", 8, 0)
        btn:SetFrameStrata("HIGH")          -- 자동 박스에 안 가려지도록 위로
        btn:SetFrameLevel(50)
        btn:SetBackdrop(ADDONSELF.theme:Backdrop({ edgeSize = 1 }))

        -- 자동/시작/중지 버튼과 완전 동일한 폰트 패턴 (SetFont 호출 X)
        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btnText:SetPoint("CENTER")
        btnText:SetText("올분 (40)")        -- 초기 풀 라벨

        local savedState = Database:GetConfigOrDefault("checkAllDistribute", true)
        GUI._checkAllDistributeState = savedState

        local function updateDistBtnStyle()
            -- 분홍 테두리 강조 (활성=밝은 분홍 / 비활성=어두운 분홍). 배경/텍스트는 둘 다 흰색 + 검정 BG 로 가시성 확보.
            if GUI._checkAllDistributeState then
                btn:SetBackdropColor(0, 0, 0, 0.65)
                btn:SetBackdropBorderColor(1.00, 0.40, 0.72, 1.0)
                btnText:SetTextColor(1.00, 1.00, 1.00)
            else
                btn:SetBackdropColor(0, 0, 0, 0.65)
                btn:SetBackdropBorderColor(0.50, 0.28, 0.40, 1.0)
                btnText:SetTextColor(0.75, 0.65, 0.70)
            end
        end

        updateDistBtnStyle()

        btn.GetChecked = function()
            return GUI._checkAllDistributeState
        end

        btn:SetScript("OnClick", function()
            GUI._checkAllDistributeState = not GUI._checkAllDistributeState
            Database:SetConfig("checkAllDistribute", GUI._checkAllDistributeState)
            updateDistBtnStyle()

            -- RaidBook 패턴 호출 (정상 흐름)
            UpdateAllDistributeLabel()
            -- 위 호출이 silent 실패 시를 대비한 직접 fallback
            local n = tonumber(GUI.countEdit:GetText()) or 40
            if GUI._checkAllDistributeState then
                btnText:SetText("올분 (" .. n .. ")")
            else
                local b = GUI:GetBeneficiaryCount() or 0
                btnText:SetText("무득분 (" .. math.max(1, n - b) .. ")")
            end

            GUI:UpdateSummary()

            if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                local splitNumber = GUI:GetSplitNumber()
                GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, GUI._checkAllDistributeState))
            end
        end)

        GUI.checkAllDistributeButton = btn
        _G.IberisRaidAuctionCheckAllDistributeButton = btn
        GUI.allDistributeLabel = btnText
        GUI._updateDistBtnStyle = updateDistBtnStyle

        C_Timer.After(0.1, function()
            UpdateAllDistributeLabel()
        end)
    end
    --

    -- sum 정산 라인 (2줄: "아이템 ... 분배금" / "개인당 ... 2명당") — 자동/시작/중지 라인 아래
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -679)
        t:SetJustifyH("LEFT")
        t:SetSpacing(7)  -- 2줄 사이 7px 간격
        self.summaryLabel = t
    end

    -- 최다지출자 / 내 경매지출 / 레이드 시작시 내 골드 (한 줄, 정산 라인 밑)
    do
        local row = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -728)
        row:SetJustifyH("LEFT")
        row:SetSpacing(0)
        row:SetText("")
        self.bottomStatsLabel = row
    end

    -- export editbox: lootLogFrame.frame 과 동일 위치/크기/배경/스크롤바
    do
        -- lootLogFrame.frame: TOPLEFT 13, -50, w=611(컬럼합 591+20), h=460(15 row × 30 + 10)
        local t = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -68)
        t:SetWidth(611)
        t:SetHeight(460)

        -- ScrollFrame 에 BackdropTemplate mixin 후 ApplyFrame 으로 동일 배경
        if BackdropTemplateMixin and not t.SetBackdrop then
            Mixin(t, BackdropTemplateMixin)
        end
        if t.SetBackdrop then
            ADDONSELF.theme:ApplyFrame(t)
        end

        -- 스크롤바: 박스 안쪽 우측으로 강제 배치 (lootLogFrame 과 동일 시각) + 테마 적용
        if t.ScrollBar then
            t.ScrollBar:ClearAllPoints()
            t.ScrollBar:SetPoint("TOPRIGHT",    t, "TOPRIGHT",    -8, -16)
            t.ScrollBar:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -8,  16)
            ADDONSELF.theme:ApplyScrollBar(t.ScrollBar)
        end

        local edit = CreateFrame("EditBox", nil, t)
        edit:SetWidth(580)
        edit:SetHeight(440)
        edit:SetPoint("TOPLEFT", t, "TOPLEFT", 6, -4)
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

        t:Hide()
    end


    -- clear btn (전체 지우기 버튼)
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(100)
        b:SetHeight(28)
        -- 우측 배열, 거래기록확인 좌측 5px 옆 (width 100, 거래기록확인 좌측 끝 -133 기준)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -138, -542)
        b:SetText("기록지우기")

        ADDONSELF.theme:ApplyButton(b)
        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1, 1, 1)
        end

        b:SetScript("OnClick", function()
            StaticPopup_Show("IBERISRAIDAUCTION_CLEARMSG")
            -- 전체 지우기 시에도 사용자가 입력한 분배 인원은 유지
            -- GUI.countEdit:SetText(40)
        end)
    end

    -- credit (+수익 버튼) — 테마 + 의도적 하늘색 강조
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(60)
        b:SetHeight(28)
        -- 아이템 리스트 밑 + 반칸(14px) 간격
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -542)
        b:SetText("+" .. L["Credit"])

        ADDONSELF.theme:ApplyButton(b, {
            bgColor     = { 0.05, 0.15, 0.25, 0.90 },
            borderColor = { 0.10, 0.50, 0.85, 1.00 },
            bgHover     = { 0.08, 0.22, 0.35, 0.95 },
            borderHover = { 0.20, 0.65, 1.00, 1.00 },
            bgPressed   = { 0.03, 0.10, 0.18, 1.00 },
        })
        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(0.4, 0.75, 1.0)
        end

        b:SetScript("OnClick", function()
            Database:AddCredit("")
            FauxScrollFrame_SetOffset(self.lootLogFrame.scrollframe, 0)
        end)
    end

    -- debit (+지출 버튼) — 테마 + 의도적 주황 강조
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(60)
        b:SetHeight(28)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 78, -542)
        b:SetText("+" .. L["Debit"])

        ADDONSELF.theme:ApplyButton(b, {
            bgColor     = { 0.30, 0.18, 0.08, 0.90 },
            borderColor = { 1.00, 0.55, 0.10, 1.00 },
            bgHover     = { 0.40, 0.25, 0.10, 0.95 },
            borderHover = { 1.00, 0.70, 0.25, 1.00 },
            bgPressed   = { 0.20, 0.12, 0.05, 1.00 },
        })
        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1.0, 0.7, 0.2)
        end

        b:SetScript("OnClick", function()
            Database:AddDebit(L["Compensation"], "", 0)
            FauxScrollFrame_SetOffset(self.lootLogFrame.scrollframe, 0)
        end)
    end

    -- dropbox filter (아이템 등급) — 커스텀 드롭다운 (테마 적용)
    do
        local container = CreateFrame("Frame", nil, f)
        container:SetWidth(100)
        container:SetHeight(22)
        -- 테스트모드 버튼(TOPRIGHT -60, -7, width 80) 의 좌측 5px 옆
        container:SetPoint("TOPRIGHT", f, "TOPRIGHT", -145, -7)

        -- 메인 버튼
        local button = CreateFrame("Button", nil, container, "BackdropTemplate")
        button:SetAllPoints(container)
        button:SetText("에픽이상 ▼")

        ADDONSELF.theme:ApplyButton(button)
        button:SetNormalFontObject("GameFontNormal")
        do
            local fs = button:GetFontString()
            if fs then fs:SetTextColor(1, 1, 1) end
        end

        -- 드롭다운 메뉴 프레임
        local dropdown = CreateFrame("Frame", nil, container, "BackdropTemplate")
        dropdown:SetWidth(120)
        dropdown:SetPoint("TOP", container, "BOTTOM", 0, -2)
        dropdown:SetFrameStrata("DIALOG")
        dropdown:Hide()
        ADDONSELF.theme:ApplyFrame(dropdown)

        -- 메뉴 아이템들 (RaidBook 패턴: 고급+ / 희귀+ / 영웅+)
        local qualityColors = {
            [2] = "ff1eff00",  -- 고급
            [3] = "ff0070dd",  -- 희귀
            [4] = "ffa335ee",  -- 영웅
        }
        local menuItems = {
            {text = "고급", value = 2},
            {text = "희귀", value = 3},
            {text = "영웅", value = 4},
        }
        local function coloredFilterText(val, label)
            local c = qualityColors[val]
            return c and ("|c" .. c .. label .. "|r") or label
        end

        for i, item in ipairs(menuItems) do
            local itemButton = CreateFrame("Button", nil, dropdown, "BackdropTemplate")
            itemButton:SetWidth(116)
            itemButton:SetHeight(22)
            itemButton:SetPoint("TOP", dropdown, "TOP", 0, -(i-1)*24)
            itemButton:SetText(coloredFilterText(item.value, item.text))

            -- 메뉴 아이템: 테두리 투명 (메뉴 내부에서 호버만 시각 구분)
            ADDONSELF.theme:ApplyButton(itemButton, {
                borderColor = { 0, 0, 0, 0 },
                borderHover = { 0, 0, 0, 0 },
            })
            itemButton:SetNormalFontObject("GameFontNormalSmall")
            do
                local fs = itemButton:GetFontString()
                if fs then fs:SetTextColor(1, 1, 1) end
            end

            itemButton:SetScript("OnClick", function()
                button:SetText(coloredFilterText(item.value, item.text) .. " \226\150\188")
                dropdown:Hide()
                Database:SetConfig("filterlevel", item.value)
            end)
        end

        dropdown:SetHeight(#menuItems * 24 + 4)

        -- 메인 버튼 클릭 시 메뉴 토글
        button:SetScript("OnClick", function()
            if dropdown:IsShown() then
                dropdown:Hide()
            else
                dropdown:Show()
                if GUI.customDropdowns then
                    for _, dd in pairs(GUI.customDropdowns) do
                        if dd ~= dropdown then
                            dd:Hide()
                        end
                    end
                end
            end
        end)

        if not GUI.customDropdowns then GUI.customDropdowns = {} end
        table.insert(GUI.customDropdowns, dropdown)

        container:SetScript("OnHide", function()
            dropdown:Hide()
        end)

        -- 초기값 설정 (RaidBook: 2=고급+ / 3=희귀+ / 4=영웅+, 기본 3)
        local savedFilterLevel = Database:GetConfigOrDefault("filterlevel", 3)
        if savedFilterLevel < 2 or savedFilterLevel > 4 then savedFilterLevel = 3 end
        local labelMap = { [2] = "고급", [3] = "희귀", [4] = "영웅" }
        local label = labelMap[savedFilterLevel] or "희귀"
        button:SetText(coloredFilterText(savedFilterLevel, label) .. " \226\150\188")
    end

    do
        self.itemtooltip = CreateFrame("GameTooltip", "IberisRaidAuctionTooltipItem" .. random(10000), UIParent, "GameTooltipTemplate")
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

            txt = strtrim(txt or "")
            txt = strtrim(txt, "[]")
            local name = GetItemInfo(text)

            if name then
                tinsert(data, {
                    ["name"] = CONVERT,
                    ["priority"] = LE_AUTOCOMPLETE_PRIORITY_IN_GROUP,
                })
            end

            return data
        end

        -- RaidBook autoCompleteRaidRoster 원본 그대로 (RBGui.lua:3541)
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

        -- 스피커 컬럼: 아이템마다 공대 경보 송출 버튼 (RaidBook micColumnUpdate 그대로)
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
            btn:SetEnabled(enabled)
            btn:SetAlpha(enabled and 1 or 0.25)
            if enabled then
                btn:SetScript("OnClick", function() AnnounceAuction(itemLink) end)
            else
                btn:SetScript("OnClick", nil)
            end
        end)

        local iconUpdate = CreateCellUpdate(function(cellFrame, entry)
            local tooltip = self.itemtooltip
            if not (cellFrame.cellItemTexture) then
                cellFrame.cellItemTexture = cellFrame:CreateTexture()
                cellFrame.cellItemTexture:SetTexCoord(0, 1, 0, 1)
                cellFrame.cellItemTexture:Show()
                cellFrame.cellItemTexture:SetPoint("CENTER", cellFrame.cellItemTexture:GetParent(), "CENTER")
                cellFrame.cellItemTexture:SetWidth(30)
                cellFrame.cellItemTexture:SetHeight(30)
            end

            -- 아이템 개수 표시 텍스트
            if not cellFrame.stackCount then
                cellFrame.stackCount = cellFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                cellFrame.stackCount:SetPoint("BOTTOMRIGHT", cellFrame, "BOTTOMRIGHT", -2, 2)
                cellFrame.stackCount:SetTextColor(1, 1, 1)
                cellFrame.stackCount:Hide()
            end

            cellFrame:SetScript("OnEnter", nil)

            if entry["type"] == "DEBIT" then
                cellFrame.cellItemTexture:SetTexture(135768) -- minus
                cellFrame.stackCount:Hide()
            else
                cellFrame.cellItemTexture:SetTexture(135769) -- plus
            end

            local detail = entry["detail"]
            if detail["type"] == "ITEM" then
                local itemTexture =  GetItemIcon(detail["item"])
                local _, itemLink = GetItemInfo(detail["item"])

                if itemTexture then
                    cellFrame.cellItemTexture:SetTexture(itemTexture)
                end

                -- 아이템 그룹 개수 표시
                if entry.stackCount and entry.stackCount > 1 then
                    cellFrame.stackCount:SetText(tostring(entry.stackCount))
                    cellFrame.stackCount:Show()
                else
                    cellFrame.stackCount:Hide()
                end

                if itemLink then
                    cellFrame:SetScript("OnEnter", function()
                        tooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")

                        -- 그룹화된 아이템이면 개수 정보 추가
                        if entry.stackCount and entry.stackCount > 1 then
                            local itemName = GetItemInfo(itemLink)
                            local cost = entry.cost or 0
                            tooltip:SetText(string.format("%s x%d", itemName or itemLink, entry.stackCount))
                            tooltip:AddLine(string.format("Cost: %s each", GetMoneyString(cost)))
                            tooltip:AddLine(string.format("Total: %s", GetMoneyString(cost * entry.stackCount)))
                            tooltip:AddLine("Left click to view individual items")
                        else
                            tooltip:SetHyperlink(itemLink)
                        end
                        tooltip:Show()
                    end)

                    cellFrame:SetScript("OnLeave", function()
                        tooltip:Hide()
                        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                    end)

                end
            else
                cellFrame.stackCount:Hide()
            end
        end)

        local entryUpdate = CreateCellUpdate(function(cellFrame, entry, idx)

            if not (cellFrame.textBox) then
                cellFrame.textBox = CreateFrame("EditBox", nil, cellFrame, "InputBoxTemplate,AutoCompleteEditBoxTemplate")
                cellFrame.textBox:SetPoint("CENTER", cellFrame, "CENTER", -20, 0)
                cellFrame.textBox:SetWidth(120)
                cellFrame.textBox:SetHeight(30)
                cellFrame.textBox:SetAutoFocus(false)
                cellFrame.textBox:SetScript("OnEscapePressed", cellFrame.textBox.ClearFocus)
                popOnFocus(cellFrame.textBox)
                -- 셀 EditBox는 RaidBook 기본 InputBoxTemplate 외형 유지 (theme 미적용)
            end

            cellFrame.textBox:Hide()

            local detail = entry["detail"]
            if detail["type"] == "ITEM" then
                local _, itemLink = GetItemInfo(detail["item"])
                if itemLink then
                    cellFrame.text:SetText(itemLink)
                    return
                end
            end

            if entry["type"] == "DEBIT" then
                cellFrame.text:SetText(L["Debit"])
                AutoCompleteEditBox_SetAutoCompleteSource(cellFrame.textBox, autoCompleteDebit)
            else
                cellFrame.text:SetText(L["Credit"])
                AutoCompleteEditBox_SetAutoCompleteSource(cellFrame.textBox, autoCompleteCredit)
            end

            -- DEBIT 아이템도 CREDIT 아이템과 동일하게 popOnFocus 호출
            popOnFocus(cellFrame.textBox)

            -- 디바운스 타이머를 저장할 변수
            local editTimer = nil
            local isUpdating = false  -- 재귀 호출 방지 플래그

            -- DEBIT 아이템도 CREDIT과 동일한 디바운스 방식으로 저장
            cellFrame.textBox.customTextChangedCallback = function(t)
                -- 업데이트 중이면 무시 (재귀 호출 방지)
                if isUpdating then return end

                -- 데이터 검증: 빈 문자열이나 nil 방지
                if t == nil then t = "" end

                -- 기존 타이머 취소
                if editTimer then
                    editTimer:Cancel()
                end

                -- DEBIT 아이템의 경우 displayname과 beneficiary 함께 업데이트
                entry["detail"]["displayname"] = t
                if entry["type"] == "DEBIT" then
                    entry["beneficiary"] = t
                end

                -- 득자가 변경된 경우에만 타이머 설정
                if entry.beneficiary ~= t then
                    -- 0.8초 후에 업데이트 실행 (사용자가 입력을 마칠 때까지 기다림)
                    editTimer = C_Timer.NewTimer(0.8, function()
                        isUpdating = true  -- 업데이트 시작 표시

                        -- DEBIT 아이템의 경우 데이터베이스에 직접 저장 (UI 갱신 없이)
                        if entry.type == "DEBIT" and idx then
                            local ledger = Database:GetCurrentLedger()
                            if ledger and ledger.items[idx] then
                                ledger.items[idx].beneficiary = t
                                -- OnLedgerItemsChange() 호출하지 않음 (UI 덮어쓰기 방지)
                            end
                        end

                        -- 업데이트: 요약 정보, 라벨, 텍스트 도출 업데이트
                        UpdateAllDistributeLabel() -- 득자 수 업데이트
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
                            GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, checkAllDistribute))
                        end

                        -- UI 업데이트는 다음 프레임에 지연시켜 무한 루프 방지
                        C_Timer.After(0, function()
                            GUI:UpdateLootTableFromDatabase()
                        end)

                        isUpdating = false  -- 업데이트 완료 표시
                    end)
                end
            end

            cellFrame.textBox:Show()
            cellFrame.textBox:SetText(detail["displayname"] or "")
        end)

        local beneficiaryUpdate = CreateCellUpdate(function(cellFrame, entry, idx)

            if not (cellFrame.textBox) then
                -- RaidBook RBGui.lua:4008-4015 와 동일한 셀 EditBox 셋업
                cellFrame.textBox = CreateFrame("EditBox", nil, cellFrame, "InputBoxTemplate,AutoCompleteEditBoxTemplate")
                cellFrame.textBox:SetPoint("CENTER", cellFrame, "CENTER", -20, 0)
                cellFrame.textBox:SetWidth(120)
                cellFrame.textBox:SetHeight(30)
                cellFrame.textBox:SetAutoFocus(false)
                cellFrame.textBox:SetScript("OnEscapePressed", cellFrame.textBox.ClearFocus)
                AutoCompleteEditBox_SetAutoCompleteSource(cellFrame.textBox, autoCompleteRaidRoster)
                popOnFocus(cellFrame.textBox)
            end

            cellFrame.textBox.customAutoCompleteFunction = function(editBox, newText, info)
                local n = newText ~= "" and newText or info.name

                if n ~= "" and n ~= (entry.beneficiary or "") then
                    -- 자동완성으로 데이터 직접 업데이트 (SetText 호출하지 않음)
                    entry["beneficiary"] = n

                    -- DEBIT 아이템의 경우 데이터베이스에 즉시 저장
                    if entry.type == "DEBIT" and idx then
                        local ledger = Database:GetCurrentLedger()
                        if ledger and ledger.items[idx] then
                            ledger.items[idx].beneficiary = n
                            -- OnLedgerItemsChange() 호출하지 않고 직접 SavedVariables 저장
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
                        end
                    end

                    -- ScrollingTable UI 데이터 강제 업데이트 (autoComplete)
                    if GUI.lootLogFrame and GUI.lootLogFrame.data and idx then
                        -- UI 테이블에서 해당 행 찾아서 업데이트
                        for _, rowData in ipairs(GUI.lootLogFrame.data) do
                            if rowData.realItemIdx == idx then
                                rowData.beneficiary = n
                                if rowData.cols and rowData.cols[4] then
                                    rowData.cols[4].value = n
                                end
                                break
                            end
                        end
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
                        GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, checkAllDistribute))
                    end

                    -- UI 업데이트는 다음 프레임에 지연시켜 무한 루프 방지
                    C_Timer.After(0, function()
                        GUI:UpdateLootTableFromDatabase()
                    end)
                end

                return true
            end

            -- DEBIT 아이템의 경우 entry.beneficiary가 cols[4].value에서 설정되도록 보장
            if entry.type == "DEBIT" then
                if not entry.beneficiary then
                    entry.beneficiary = entry.cols[4].value or ""
                end
                -- 빈 문자열인 경우 L["[Unknown]"]으로 설정하지 않고 그대로 유지
                if entry.beneficiary == L["[Unknown]"] then
                    entry.beneficiary = ""
                    if entry.cols[4] then
                        entry.cols[4].value = ""
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

                -- 기존 타이머 취소
                if editTimer then
                    editTimer:Cancel()
                end

                -- 득자가 변경된 경우에만 타이머 설정

                if entry.beneficiary ~= t then
                    -- 0.8초 후에 업데이트 실행 (사용자가 입력을 마칠 때까지 기다림)
                    editTimer = C_Timer.NewTimer(0.8, function()
                        isUpdating = true  -- 업데이트 시작 표시

                        local _, itemName = "Unknown"
                        if entry.detail and entry.detail.item then
                            _, itemName = GetItemInfo(entry.detail.item)
                            itemName = itemName or "Unknown"
                        end

                        entry["beneficiary"] = t
                        -- DEBIT 아이템의 경우 cols[4].value도 동기화 (ScrollingTable 데이터 일관성)
                        if entry.cols and entry.cols[4] then
                            entry.cols[4].value = t
                        end

                        -- ScrollingTable UI 데이터 강제 업데이트
                        if self.lootLogFrame and self.lootLogFrame.data and idx then
                            -- UI 테이블에서 해당 행 찾아서 업데이트
                            for _, rowData in ipairs(self.lootLogFrame.data) do
                                if rowData.realItemIdx == idx then
                                    rowData.beneficiary = t
                                    if rowData.cols and rowData.cols[4] then
                                        rowData.cols[4].value = t
                                    end
                                    break
                                end
                            end
                        end

                        -- DEBIT 아이템의 경우 데이터베이스에 즉시 저장 (UI 업데이트 방지)
                        if entry.type == "DEBIT" and idx then
                            local ledger = Database:GetCurrentLedger()
                            if ledger and ledger.items[idx] then
                                ledger.items[idx].beneficiary = t
                                -- OnLedgerItemsChange() 호출하지 않고 직접 SavedVariables 저장
                                -- 이렇게 하면 UI 업데이트를 방지하면서 영구 저장 가능
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
                            end
                        end

                        -- 업데이트: 요약 정보, 라벨, 텍스트 도출 업데이트
                        UpdateAllDistributeLabel() -- 득자 수 업데이트
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
                            GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, checkAllDistribute))
                        end

                        -- DEBIT 아이템이 아닌 경우에만 UI 전체 업데이트 (DEBIT 아이템은 득자 정보 유지를 위해 건너뜀)
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
            local newText = entry.beneficiary or ""
            if currentText ~= newText then
                cellFrame.textBox:SetText(newText)
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


        local valueUpdate = CreateCellUpdate(function(cellFrame, entry, idx)
            local tooltip = self.commtooltip
            if not (cellFrame.textBox) then
                cellFrame.textBox = CreateFrame("EditBox", nil, cellFrame, "InputBoxTemplate")
                cellFrame.textBox:SetPoint("CENTER", cellFrame, "CENTER")
                cellFrame.textBox:SetWidth(70)
                cellFrame.textBox:SetHeight(30)
                -- cellFrame.textBox:SetNumeric(true)
                cellFrame.textBox:SetAutoFocus(false)
                cellFrame.textBox:SetMaxLetters(10)
                cellFrame.textBox:SetScript("OnChar", mustnumber)
                cellFrame.textBox:SetScript("OnEnterPressed", clearAllFocus)
                ADDONSELF.theme:ApplyEditBox(cellFrame.textBox)
                if cellFrame.textBox.SetBackdropColor then
                    cellFrame.textBox:SetBackdropColor(0.02, 0.02, 0.03, 0.98)
                end
                cellFrame.textBox:SetScript("OnTabPressed", clearAllFocus)
            end
            cellFrame.textBox:SetText(tostring(entry["cost"] or 0))

            local type = entry["costtype"] or "GOLD"

            if type == "PROFIT_PERCENT" then
                cellFrame.text:SetText("%")
            elseif type == "MUL_AVG" then
                cellFrame.text:SetText("*")
            else
                -- GOLD by default
                cellFrame.text:SetText(GOLD_AMOUNT_TEXTURE_STRING:format(""))
            end

            cellFrame:SetScript("OnClick", nil)
            cellFrame:SetScript("OnEnter", nil)

            if entry["type"] == "DEBIT" then
                cellFrame:SetScript("OnClick", function()
                    valueTypeMenuCtx.entry = entry
                    for _, m in pairs(valueTypeMenu) do
                        m.checked = m.costtype == type
                    end
                
                    EasyMenu(valueTypeMenu, menuFrame, "cursor", 0 , 0, "MENU");
                end)

            end

            if entry["costcache"] then
                cellFrame:SetScript("OnEnter", function()
                    tooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
                    tooltip:SetText(GetMoneyString(entry["costcache"]))
                    tooltip:Show()
                end)

                cellFrame:SetScript("OnLeave", function()
                    tooltip:Hide()
                    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
                end)
            end

            cellFrame.textBox:SetScript("OnTextChanged", function(self, userInput)
                local t = cellFrame.textBox:GetText()
                local v = tonumber(t) or 0

                if entry["cost"] == v then
                    return
                end

                if v < 0.0001 then
                    v = 0
                end

                
                -- 실제 데이터베이스에도 저장해야 함
                if idx then
                    local ledger = Database:GetCurrentLedger()
                    if ledger and ledger.items[idx] then
                        -- DEBIT 아이템의 경우 현재 UI 상태의 beneficiary 값을 저장 (UI 업데이트 방지)
                        if entry.type == "DEBIT" then
                            ledger.items[idx].beneficiary = entry.beneficiary
                            ledger.items[idx].cost = v
                            -- OnLedgerItemsChange() 호출하지 않고 직접 SavedVariables 저장
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
                            ADDONSELF.db:OnLedgerItemsChange()
                        end
                    end
                end

                entry["cost"] = v

                -- CREDIT와 DEBIT 아이템 모두 동일한 디바운스 방식으로 처리
                if editTimer then
                    editTimer:Cancel()
                end

                editTimer = C_Timer.NewTimer(0.8, function()
                    if isUpdating then return end
                    isUpdating = true

                    -- DEBIT 아이템이 아닌 경우에만 UI 전체 업데이트 (DEBIT 아이템은 득자 정보 유지를 위해 건너뜀)
                    if entry.type ~= "DEBIT" then
                        -- UI 업데이트는 다음 프레임에 지연시켜 무한 루프 방지
                        C_Timer.After(0, function()
                            GUI:UpdateLootTableFromDatabase()
                        end)
                    end

                    isUpdating = false
                end)

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
                    GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, checkAllDistribute))
                end
            end)

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
                ["name"] = "",
                ["width"] = 50,
                ["DoCellUpdate"] = iconUpdate,
            },
            {
                ["name"] = L["Entry"],
                ["width"] = 220,
                ["DoCellUpdate"] = entryUpdate,
            },
            {
                ["name"] = L["Beneficiary"],
                ["width"] = 120,
                ["DoCellUpdate"] = beneficiaryUpdate,
            },
            {
                ["name"] = L["Value"],
                ["width"] = 111,
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
                    
                    -- 데이터베이스에서 최신 noBeneficiary 값 가져오기
                    local itemData = nil
                    local itemIdx = entry and entry.realItemIdx or (value and type(value) == "number" and value)
                    local checkboxValue = false

                    if itemIdx then
                        checkboxValue = Database:GetItemNoBeneficiary(itemIdx)
                    end

                    
                    checkbox:SetChecked(checkboxValue)
                    
                    checkbox:SetScript("OnClick", function()
                        if itemIdx then
                            cur = Database:GetItemNoBeneficiary(itemIdx)
                            Database:SetItemNoBeneficiary(itemIdx, not cur)

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
                                GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, checkAllDistribute))
                            end
                        end
                    end)

                    checkbox:Show()
                end),
            }
        }, 15, 30, nil, f)

        self.lootLogFrame.head:SetHeight(15)
        -- 거래기록 확인 버튼(TOPRIGHT -13)과 우측 정렬: TOPLEFT + TOPRIGHT 두 anchor 로 width 강제
        self.lootLogFrame.frame:ClearAllPoints()
        self.lootLogFrame.frame:SetPoint("TOPLEFT",  f, "TOPLEFT",  13, -68)
        self.lootLogFrame.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -13, -68)

        -- 거래기록 ScrollFrame 을 lootLogFrame.frame 과 정확히 동일 사각형으로 강제 (lib-st 의 실제 width 사용)
        if self.exportEditbox and self.exportEditbox:GetParent() then
            local parent = self.exportEditbox:GetParent()
            parent:ClearAllPoints()
            parent:SetAllPoints(self.lootLogFrame.frame)
        end

        -- 헤더 ↔ 첫 row 간격: head BOTTOM 을 frame TOP 위로 10px 띄움
        self.lootLogFrame.head:ClearAllPoints()
        self.lootLogFrame.head:SetPoint("BOTTOMLEFT",  self.lootLogFrame.frame, "TOPLEFT",   4, 10)
        self.lootLogFrame.head:SetPoint("BOTTOMRIGHT", self.lootLogFrame.frame, "TOPRIGHT", -4, 10)

        -- lib-st 외곽 프레임 + 스크롤바 테마
        if self.lootLogFrame.frame then
            ADDONSELF.theme:ApplyFrame(self.lootLogFrame.frame)
        end
        if self.lootLogFrame.scrollframe and self.lootLogFrame.scrollframe.ScrollBar then
            ADDONSELF.theme:ApplyScrollBar(self.lootLogFrame.scrollframe.ScrollBar)
        end

        -- lib-st 자체 scrolltrough/scrolltroughborder 숨김 (이중 트랙 제거 — ApplyScrollBar 한 ScrollBar 만 남김)
        if self.lootLogFrame.scrollframe then
            local sf = self.lootLogFrame.scrollframe
            for _, child in ipairs({ sf:GetChildren() }) do
                if child ~= sf.ScrollBar then
                    child:Hide()
                end
            end
        end

        -- row 배경 (ElvUI 풍 어두운 평면 + 청색 호버). alpha 키워 행 구분 강화.
        if self.lootLogFrame.SetDefaultHighlightBlank then
            self.lootLogFrame:SetDefaultHighlightBlank(0.06, 0.06, 0.08, 0.95)
        end
        if self.lootLogFrame.SetDefaultHighlight then
            self.lootLogFrame:SetDefaultHighlight(0.10, 0.50, 0.85, 0.55)
        end
        -- lib-st 는 OnEnter/OnLeave 에서만 SetHighLightColor 호출 → 평소 highlight 가 default alpha 0 으로 row 배경 안 보임.
        -- setup 직후 모든 row 에 GetDefaultHighlightBlank 강제 적용해서 어두운 톤 보이게.
        if self.lootLogFrame.rows and self.lootLogFrame.SetHighLightColor and self.lootLogFrame.GetDefaultHighlightBlank then
            local blank = self.lootLogFrame:GetDefaultHighlightBlank()
            for i = 1, self.lootLogFrame.displayRows do
                local row = self.lootLogFrame.rows[i]
                if row then
                    self.lootLogFrame:SetHighLightColor(row, blank)
                end
            end
        end
        if self.lootLogFrame.Refresh then
            self.lootLogFrame:Refresh()
        end

        self.lootLogFrame:RegisterEvents({
            ["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, sttable, button, ...)
                clearAllFocus()
                local entry, idx = GetEntryFromUI(rowFrame, cellFrame, data, cols, row, realrow, column, sttable)

                if not entry then
                    return
                end

                -- 6번째 컬럼(무득)은 체크박스가 자체적으로 처리하므로 테이블 클릭에서는 무시
                if column == 6 then
                    return
                end

                if button == "RightButton" then

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


    -- report btn (방송 버튼)
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(60)  -- 절반으로 크기 축소
        b:SetHeight(28)
        -- 우측 배열, 같은 줄 -524 (요약출력 좌측 5px 옆, 아이템 리스트 우측 끝 -13 기준)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -308, -542)
        b:SetText("전체출력")  -- 텍스트 변경
        -- b:SetText(L["Report"] .. " :" .. RAID)
        b:RegisterForClicks("LeftButtonUp")

        ADDONSELF.theme:ApplyButton(b)
        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1, 1, 1)
        end

        b:SetScript("OnClick", function(self)
            -- 전체출력 버튼은 항상 모든 정보를 표시 (checkf = false)
            -- 데이터베이스에서 최신 아이템 목록을 직접 가져옴
            local currentItems = Database:GetCurrentLedger()["items"]

            GenReport(currentItems, GUI:GetSplitNumber(), "RAID", false)
        end)

        -- 전체출력 버튼 참조를 위해 저장
        self.reportButton = b
    end

    -- summary btn (요약 버튼)
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(60)  -- 전체출력 버튼과 동일한 크기
        b:SetHeight(28)
        b:SetPoint("LEFT", self.reportButton, "RIGHT", 5, 0)
        b:SetText("요약출력")
        b:RegisterForClicks("LeftButtonUp")

        ADDONSELF.theme:ApplyButton(b)
        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalText = b:GetFontString()
        if normalText then
            normalText:SetTextColor(1, 1, 1, 1)
        end

        -- 텍스트 색상 호버 효과 (노란색)
        b:HookScript("OnEnter", function(self)
            local t = self:GetFontString()
            if t then t:SetTextColor(1, 1, 0, 1) end
        end)
        b:HookScript("OnLeave", function(self)
            local t = self:GetFontString()
            if t then t:SetTextColor(1, 1, 1, 1) end
        end)

        b:SetScript("OnClick", function(self)
            -- 왼쪽 클릭: 기본 공격대 채널로 요약 보고서 생성 (득자 제외)
            -- 데이터베이스에서 최신 아이템 목록을 직접 가져옴
            local currentItems = Database:GetCurrentLedger()["items"]

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
        b:SetWidth(120)
        b:SetHeight(28)
        -- 아이템 리스트 우측 끝(-13)에 정렬, +수익/+지출 과 동일 줄 (-524, 반칸 간격)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -13, -542)
        b:SetText(L["Export as text"])

        ADDONSELF.theme:ApplyButton(b)
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
            exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, checkAllDistribute))
        end)

    end

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
    iconText:SetText("RL")
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
        GameTooltip:SetText("Raid Ledger (클릭하여 열기)")
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


  
end

-- CLI에서 GUI 드롭다운 업데이트를 위해 호출하는 함수
function GUI:UpdateAutoLootDropdown(value)
    -- value 파라미터는 무시하고 데이터베이스에서 직접 읽음
    local dbValue = Database:GetConfigOrDefault("autoaddloot", AUTOADDLOOT_TYPE_RAID)
    value = dbValue
    -- 버튼 텍스트 업데이트
    local button = nil
    -- 커스텀 드롭다운 버튼 찾기
    if self.autoLootButton then
        button = self.autoLootButton
    end

    if button then
        if value == 0 then
            button:SetText("항상 자동 기록 ▼")
        elseif value == 1 then
            button:SetText("공격대일때만 ▼")
        elseif value == 2 then
            button:SetText("자동 기록 끔 ▼")
        end
    end
end

-- CLI에서 GUI 절삭 드롭다운 업데이트를 위해 호출하는 함수
function GUI:UpdateRoundingDropdown(value)
    -- value 파라미터는 무시하고 데이터베이스에서 직접 읽음
    local dbValue = Database:GetConfigOrDefault("roundinglevel", 2)
    value = dbValue
    -- 버튼 텍스트 업데이트
    local button = nil
    -- 커스텀 드롭다운 버튼 찾기
    if self.roundingButton then
        button = self.roundingButton
    end

    if button then
        if value == 0 then
            button:SetText("골드 단위 ▼")
        elseif value == 1 then
            button:SetText("실버 단위 ▼")
        elseif value == 2 then
            button:SetText("절삭 없음 ▼")
        end
    end
    GUI.roundingLevel = value

    -- 텍스트 모드가 열려있으면 내용 업데이트
    if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
        local splitNumber = GUI:GetSplitNumber()
        local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
        local checkAllDistribute = true
        if checkbox then
            local rawValue = checkbox:GetChecked()
            checkAllDistribute = (rawValue == true) or (rawValue == 1)
        end
        GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, checkAllDistribute))
    end
end

-- RaidBook RBGui.lua 5470-5494 그대로 차용 (라벨 "올분/무득분")
function UpdateAllDistributeLabel()
    if not GUI.allDistributeLabel then
        return
    end

    local totalMembers = tonumber(GUI.countEdit:GetText()) or 40

    local checkAllDistribute = GUI._checkAllDistributeState
    if checkAllDistribute == nil then checkAllDistribute = true end

    if checkAllDistribute then
        GUI.allDistributeLabel:SetText("올분 (" .. totalMembers .. ")")
    else
        local beneficiaryCount = GUI:GetBeneficiaryCount()
        local actualMembers = math.max(1, totalMembers - beneficiaryCount)
        GUI.allDistributeLabel:SetText("무득분 (" .. actualMembers .. ")")
    end

    if GUI._updateDistBtnStyle then
        GUI._updateDistBtnStyle()
    end
end

function GUI:GetCheckTradeButton()
    return checkTrade
end


RegEvent("VARIABLES_LOADED", function()
    GUI:UpdateLootTableFromDatabase()
    UpdateAllDistributeLabel() -- 초기 로딩 시 라벨 업데이트
end)

RegEvent("ADDON_LOADED", function()
    -- CLI 초기화 후 GUI 초기화를 위해 약간 지연
    C_Timer.After(0.1, function()
        GUI:Init()
        Database:RegisterChangeCallback(function()
            GUI:UpdateLootTableFromDatabase()
        end)

        GUI:UpdateLootTableFromDatabase()
    end)


    -- raid frame handler

    do
        if _G.RaidFrame then
            local b = CreateFrame("Button", nil, _G.RaidFrame, "UIPanelButtonTemplate")
            b:SetWidth(100)
            b:SetHeight(20)
            b:SetPoint("TOPRIGHT", -25, 0)
            b:SetText(L["Raid Ledger"])
            b:SetScript("OnClick", function()
                if GUI.mainframe:IsShown() then
                    GUI.mainframe:Hide()
                else
                    GUI.mainframe:Show()
                end
            end)
        end

        local hooked = false

        -- 본섭 Midnight(12.0.x)에서 RaidFrame_LoadUI 글로벌 제거됨 → 가드.
        if _G.RaidFrame_LoadUI then
        hooksecurefunc("RaidFrame_LoadUI", function()
            if hooked then
                return
            end

            local tooltip = GUI.commtooltip

            local enter = function(l, idx)
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
                    local b = entry["beneficiary"]

                    if members[b] then
                        special = true
                        members[b].cost = members[b].cost + cost
                        teamtotal = teamtotal + cost
                    end
                end, nil, checkAllDistribute)

                teamtotal = teamtotal + c * avg

                if c > 0 then
                    tooltip:SetText(L["Member credit for subgroup"])
                    tooltip:AddLine(L["Subgroup total"] .. ": " .. GetMoneyString(teamtotal))
                    tooltip:AddLine(L["Per Member"] .. ": " .. GetMoneyString(avg))

                    if special then
                        tooltip:AddLine(L["Special Members"])
                        for _, member in pairs(members) do
                            if member.cost > 0 then
                                tooltip:AddLine(member.text .. ": " .. GetMoneyString(avg + member.cost) )
                            end
                        end

                    end

                    tooltip:Show()
                end
            end

            local leave = function()
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
        end -- if _G.RaidFrame_LoadUI
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


