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
        "아이템 " .. fmt(autoRevenue, true)
        .. " + 수익 " .. fmt(manualRevenue, true)
        .. " - 지출 " .. fmt(expense or 0, true)
        .. " = 분배금 " .. fmt(distribution, true)
        .. CRLF
        .. "개인당 " .. fmt(floorNum, true)
        .. " 파티당 " .. fmt(partyMoney, true)
        .. " 4명당 " .. fmt(party4, true)
        .. " 3명당 " .. fmt(party3, true)
        .. " 2명당 " .. fmt(party2, true)
    )

    -- 분배 인원 라벨도 같이 갱신 (득자 카운트 변동)
    if self.splitLabel then
        self.splitLabel:SetText(L["Split into (Current %d)"]:format(GetRosterNumber(), beneficiaryCount))
    end

    checkTrade = self.checkTbutton:GetChecked()
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
                    -- entry.beneficiary와 cols[2].value 모두 확인하여 최신 값 수집
                    local uiBeneficiary = entry.beneficiary or (entry.cols and entry.cols[2] and entry.cols[2].value) or ""
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

            local key = tostring(safeItemID) .. "_" .. beneficiary .. "_" .. normalizedCost

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

            -- DEBIT 항목은 항상 표시
            if item.type == "DEBIT" then
                shouldShow = true
                -- UI에서 수집된 최신 beneficiary 값을 우선 적용
                -- 빈 문자열인 경우 그대로 사용 (L["[Unknown]"]으로 변환하지 않음)
                local uiBeneficiary = currentDebitBeneficiaries[i] or item.beneficiary or ""
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
                        { ["value"] = uiBeneficiary },  -- UI에서 수집된 최신 DEBIT 득자 정보 표시
                        { ["value"] = "" },
                        { ["value"] = "" },
                        { ["value"] = "" },
                        { ["value"] = item.noBeneficiary or false }
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
                { ["value"] = firstItemIdx },  -- 첫 번째 아이템 인덱스
                { ["value"] = uiBeneficiary },
                { ["value"] = "" },
                { ["value"] = "" },
                { ["value"] = "" },
                { ["value"] = firstItem.noBeneficiary or false }
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
                            entry.cols[2].value = beneficiary
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
    f:SetHeight(705)
    ADDONSELF.theme:ApplyFrame(f)
    f:SetPoint("CENTER", 0, 0)
    f:SetToplevel(true)
    f:EnableMouse(true)

    -- 추가 배경: 아래쪽으로 50px 더 확장 (resize handle 영역)
    local extraBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    extraBg:SetWidth(650)
    extraBg:SetHeight(50)
    extraBg:SetPoint("TOP", f, "BOTTOM", 0, 0)
    ADDONSELF.theme:ApplyFrame(extraBg)
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

        local rh = CreateFrame("Button", nil, extraBg)
        rh:SetSize(16, 16)
        rh:SetPoint("BOTTOMRIGHT", extraBg, "BOTTOMRIGHT", -2, 2)
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

    -- 우측 상단 최소화 버튼
    do
        local minimizeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        minimizeBtn:SetWidth(24)
        minimizeBtn:SetHeight(24)
        minimizeBtn:SetPoint("TOPRIGHT", f, -29, -5) -- X 버튼 왼쪽에 위치

        -- 원형 버튼 스타일
        minimizeBtn:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        minimizeBtn:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
        minimizeBtn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)

        -- 텍스트 스타일
        local text = minimizeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetTextColor(1, 1, 1)
        text:SetText("-")
        text:SetPoint("CENTER", 0, 0)

        -- 호버 효과
        minimizeBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.2, 0.8, 0.2, 0.95)
            self:SetBackdropBorderColor(0.4, 1.0, 0.4, 1.0)
        end)

        minimizeBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            self:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end)

        -- 클릭 효과
        minimizeBtn:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.1, 0.6, 0.1, 1.0)
            self:SetBackdropBorderColor(0.2, 0.8, 0.2, 1.0)
        end)

        minimizeBtn:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.2, 0.8, 0.2, 0.95)
            self:SetBackdropBorderColor(0.4, 1.0, 0.4, 1.0)
        end)

        -- 최소화 기능
        minimizeBtn:SetScript("OnClick", function()
            f:Hide()
            if GUI.minimizeIcon then
                GUI.minimizeIcon:Show()
            end
        end)
    end

    -- 우측 상단 X 닫기 버튼
    do
        local closeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        closeBtn:SetWidth(24)
        closeBtn:SetHeight(24)
        closeBtn:SetPoint("TOPRIGHT", f, -5, -5)

        -- 원형 버튼 스타일
        closeBtn:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        closeBtn:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
        closeBtn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)

        -- 텍스트 스타일
        local text = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetTextColor(1, 1, 1)
        text:SetText("X")
        text:SetPoint("CENTER", 0, 0)

        -- 호버 효과
        closeBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.8, 0.2, 0.2, 0.95)
            self:SetBackdropBorderColor(1.0, 0.4, 0.4, 1.0)
        end)

        closeBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.15, 0.15, 0.2, 0.9)
            self:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
        end)

        -- 클릭 효과
        closeBtn:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.6, 0.1, 0.1, 1.0)
            self:SetBackdropBorderColor(0.8, 0.2, 0.2, 1.0)
        end)

        closeBtn:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.8, 0.2, 0.2, 0.95)
            self:SetBackdropBorderColor(1.0, 0.4, 0.4, 1.0)
        end)

        -- 닫기 기능
        closeBtn:SetScript("OnClick", function() f:Hide() end)
    end

    -- 메인 창 카운트다운 버튼들
    do
        -- 카운트다운 버튼
        local countdownBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        countdownBtn:SetWidth(80)
        countdownBtn:SetHeight(25)
        countdownBtn:SetPoint("TOPRIGHT", f, -300, -480)

        -- 버튼 스타일
        countdownBtn:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        countdownBtn:SetBackdropColor(0.2, 0.2, 0.3, 0.95)
        countdownBtn:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)

        -- 버튼 텍스트
        local btnText = countdownBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetTextColor(1, 1, 1)
        btnText:SetText("Count")
        btnText:SetPoint("CENTER", 0, 0)

        -- 호버 효과
        countdownBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.4, 0.95)
            self:SetBackdropBorderColor(0.6, 0.6, 0.7, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Start Countdown (5>1)")
            GameTooltip:Show()
        end)

        countdownBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.3, 0.95)
            self:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)
            GameTooltip:Hide()
        end)

        -- 클릭 효과
        countdownBtn:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.15, 1.0)
        end)

        countdownBtn:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.4, 0.95)
        end)

        -- 카운트다운 기능
        countdownBtn:SetScript("OnClick", function()
            if not GUI.countdownActive then
                GUI.countdownActive = true
                GUI.currentCount = 5

                -- 데이터베이스에서 메시지 가져오기
                local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                    count = "--- %d",
                    closed = "--- BIDDING CLOSED",
                    resume = "--- NEW BID. RESUMING"
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

        countdownBtn:Hide()  -- IRACountdown.lua 의 새 버튼 그룹 사용 — 기존 버튼 폐기
    end

    do
        -- 중지 버튼
        local stopBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        stopBtn:SetWidth(80)
        stopBtn:SetHeight(25)
        stopBtn:SetPoint("TOPRIGHT", f, -218, -480)

        -- 버튼 스타일
        stopBtn:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        stopBtn:SetBackdropColor(0.6, 0.2, 0.2, 0.95)
        stopBtn:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)

        -- 버튼 텍스트
        local btnText = stopBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetTextColor(1, 1, 1)
        btnText:SetText("Stop")
        btnText:SetPoint("CENTER", 0, 0)

        -- 호버 효과
        stopBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.8, 0.3, 0.3, 0.95)
            self:SetBackdropBorderColor(1.0, 0.4, 0.4, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Stop Countdown & Resume")
            GameTooltip:Show()
        end)

        stopBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.6, 0.2, 0.2, 0.95)
            self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)
            GameTooltip:Hide()
        end)

        -- 클릭 효과
        stopBtn:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.4, 0.1, 0.1, 1.0)
        end)

        stopBtn:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.8, 0.3, 0.3, 0.95)
        end)

        -- 중지 기능
        stopBtn:SetScript("OnClick", function()
            if GUI.countdownActive then
                GUI.countdownActive = false
                if GUI.countdownTimer then
                    GUI.countdownTimer = nil
                end

                -- 데이터베이스에서 재개 메시지 가져오기
                local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                    count = "--- %d",
                    closed = "--- BIDDING CLOSED",
                    resume = "--- NEW BID. RESUMING"
                })

                SendChatMessage(messages.resume, "RAID_WARNING")
            end
        end)

        stopBtn:Hide()  -- IRACountdown.lua 의 새 버튼 그룹 사용 — 기존 버튼 폐기
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

    -- split member and editbox
    do
        local t = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        t:SetWidth(80)
        t:SetHeight(25)
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 230, -566)
        t:SetAutoFocus(false)
        t:SetMaxLetters(4)
        ADDONSELF.theme:ApplyEditBox(t)
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

    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -572)
        self.splitLabel = t
        -- 초기 텍스트 (득자 0)
        t:SetText(L["Split into (Current %d)"]:format(GetRosterNumber(), 0))
        -- roster 변경 시 UpdateSummary가 splitLabel도 갱신
        RegEvent("GROUP_ROSTER_UPDATE", function() GUI:UpdateSummary() end)
        RegEvent("CHAT_MSG_SYSTEM",     function() GUI:UpdateSummary() end)
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

    -- Auto loot recording dropdown — 메인창에서 폐기 (옵션창에서만 설정)
    if false then
    do
        local container = CreateFrame("Frame", nil, f)
        container:SetWidth(120)
        container:SetHeight(28)
        container:SetPoint("BOTTOMLEFT", f, 280, 10) -- #2

        -- 메인 버튼
        local button = CreateFrame("Button", nil, container, "BackdropTemplate")
        button:SetAllPoints(container)
        button:SetText("공격대일때만 ▼")

        -- GUI에서 버튼 참조 저장 (CLI 업데이트용)
        GUI.autoLootButton = button

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
        dropdown:SetWidth(140)
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
            {text = "항상 자동 기록", value = 0},
            {text = "공격대일때만", value = 1},
            {text = "자동 기록 끔", value = 2}
        }

        -- 메뉴 아이템 생성
        for i, item in ipairs(menuItems) do
            local itemButton = CreateFrame("Button", nil, dropdown, "BackdropTemplate")
            itemButton:SetWidth(136)
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
                button:SetText(item.text .. " ▼")
                dropdown:Hide()
                -- Save to database
                Database:SetConfig("autoaddloot", item.value)

                -- Database is the single source of truth
                -- No need to update CLI variable as it will read from DB when needed
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

        -- 초기값 설정 - 데이터베이스에서 직접 읽기
        local currentValue = Database:GetConfigOrDefault("autoaddloot", AUTOADDLOOT_TYPE_DISABLE)
        if currentValue == 0 then
            button:SetText("항상 자동 기록 ▼")
        elseif currentValue == 1 then
            button:SetText("공격대일때만 ▼")
        elseif currentValue == 2 then
            button:SetText("자동 기록 끔 ▼")
        end
    end
    end -- end of if false (자동 기록 dropdown 폐기)

    -- Gold/Silver rounding dropdown — 폐기 (항상 골드 단위 floor)
    if false then
    do
        local container = CreateFrame("Frame", nil, f)
        container:SetWidth(100)
        container:SetHeight(28)
        container:SetPoint("BOTTOMLEFT", f, 410, 10) -- #3

        -- 메인 버튼
        local button = CreateFrame("Button", nil, container, "BackdropTemplate")
        button:SetAllPoints(container)
        button:SetText("절삭 없음 ▼")

        -- GUI에서 버튼 참조 저장 (CLI 업데이트용)
        GUI.roundingButton = button

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
        dropdown:SetWidth(100)
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
            {text = "절삭 없음", value = 2},
            {text = "실버 단위", value = 1},
            {text = "골드 단위", value = 0}
        }

        local selectedValue = 2

        -- 메뉴 아이템 생성
        for i, item in ipairs(menuItems) do
            local itemButton = CreateFrame("Button", nil, dropdown, "BackdropTemplate")
            itemButton:SetWidth(96)
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
                Database:SetConfig("roundinglevel", item.value)
                GUI.roundingLevel = item.value

                -- UI 요약 정보 실시간 업데이트 (총수익, 개인당 골드, 파티당 골드)
                GUI:UpdateSummary()

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

        -- 초기값 설정 - 데이터베이스에서 직접 읽기
        local currentValue = Database:GetConfigOrDefault("roundinglevel", 2)
        GUI.roundingLevel = currentValue

        if currentValue == 0 then
            button:SetText("골드 단위 ▼")
        elseif currentValue == 1 then
            button:SetText("실버 단위 ▼")
        elseif currentValue == 2 then
            button:SetText("절삭 없음 ▼")
        end
    end
    end -- end of if false (rounding dropdown 폐기)


    --
    do
        local t = CreateFrame("CheckButton", nil, f, "BackdropTemplate")
        t:SetWidth(20)
        t:SetHeight(20)
        t:SetPoint("BOTTOMLEFT", f, 200, 71)
        t:SetChecked(true)

        -- 체크박스 기본 스타일 (배경 및 테두리 없음)
        -- WoW 기본 체크박스 텍스처만 사용
        t:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        t:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        t:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        t:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

        -- 클릭 효과
        t:SetScript("OnClick", function()
            checkTrade = t:GetChecked()
        end)
        self.checkTbutton = t

        t:Hide()  -- UI 폐기 — 항상 자동 기록 디폴트
    end
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        t:SetPoint("BOTTOMLEFT", f, 230, 76)
	t:SetText("거래시 자동으로 기록")
        t:Hide()  -- 라벨도 폐기
    end

    -- 모두 분배 체크박스
    do
        local t = CreateFrame("CheckButton", nil, f, "BackdropTemplate")
        t:SetWidth(20)
        t:SetHeight(20)
        t:SetPoint("BOTTOMLEFT", f, 340, 71)
        -- 데이터베이스에서 체크 상태 불러오기
        local savedState = Database:GetConfigOrDefault("checkAllDistribute", true)
        t:SetChecked(savedState)

        -- 체크박스 기본 스타일 (배경 및 테두리 없음)
        -- WoW 기본 체크박스 텍스처만 사용
        t:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        t:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        t:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        t:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

        -- 클릭 효과
        t:SetScript("OnClick", function()
            -- 체크 상태를 데이터베이스에 저장
            local currentState = t:GetChecked()
            Database:SetConfig("checkAllDistribute", currentState)

              
            -- "모두 분배" 라벨 업데이트
            UpdateAllDistributeLabel()

            -- 요약 정보 업데이트 (총수익, 개인당 골드, 파티당 골드 실시간 적용)
            GUI:UpdateSummary()

            -- 텍스트 도출 모드가 열려있으면 텍스트 내용도 업데이트
            if GUI.exportEditbox and GUI.exportEditbox:GetParent():IsShown() then
                local splitNumber = GUI:GetSplitNumber()
                -- UpdateAllDistributeLabel과 동일한 체크박스 상태 읽기
                local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton
                local checkAllDistribute = true
                if checkbox then
                    local rawValue = checkbox:GetChecked()
                    checkAllDistribute = (rawValue == true) or (rawValue == 1)
                end
                  GUI.exportEditbox:SetText(GenExport(Database:GetCurrentLedger()["items"], splitNumber, nil, checkAllDistribute))
            end
        end)
        GUI.checkAllDistributeButton = t  -- 전역 GUI 객체에 저장
        _G.IberisRaidAuctionCheckAllDistributeButton = t  -- 전역 변수에도 저장

        -- UI 폐기 — 항상 "모두 분배" 디폴트 (체크 상태도 강제 true)
        t:SetChecked(true)
        Database:SetConfig("checkAllDistribute", true)
        t:Hide()
    end
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        t:SetPoint("BOTTOMLEFT", f, 370, 76)
        t:SetText(L["Distribute All"])
        GUI.allDistributeLabel = t -- 라벨을 전역 GUI 객체에 저장하여 동적 업데이트 가능
        t:Hide()  -- 라벨도 폐기

        -- 초기 라벨 업데이트 (체크박스 상태에 따라)
        C_Timer.After(0.1, function()
            UpdateAllDistributeLabel()
        end)
    end
    --

    -- sum 총수익 총지출 최종수입 개인당 골드 파티당 골드 (분배인원 row 바로 밑, 한 줄)
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -605)
        t:SetJustifyH("LEFT")

        self.summaryLabel = t
    end

    -- export editbox
    do
        local t = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        t:SetPoint("TOPLEFT", f, 25, -30)
        t:SetWidth(580)
        t:SetHeight(360)

        -- 스크롤바 테마 (UIPanelScrollFrameTemplate의 자식 슬라이더)
        if t.ScrollBar then
            ADDONSELF.theme:ApplyScrollBar(t.ScrollBar)
        end

        local edit = CreateFrame("EditBox", nil, t)
        edit:SetWidth(580)
        edit:SetHeight(320)
        edit:SetPoint("TOPLEFT", t, 10, 0)
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

    -- clear btn (전체 지우기 버튼)
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(100)
        b:SetHeight(28)
        -- 우측 배열, 거래기록확인 좌측 5px 옆 (width 100, 거래기록확인 좌측 끝 -133 기준)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -138, -524)
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

    -- credit (+수익 버튼)
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(60)
        b:SetHeight(28)
        -- 아이템 리스트 (TOPLEFT 13, -50, 15행×30=450) 밑 + 반칸(14px) 간격
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -524)
        b:SetText("+" .. L["Credit"])

        -- 현대적인 버튼 스타일 적용
        b:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        -- +수익: 진한 하늘색 테두리 + 폰트
        b:SetBackdropColor(0.05, 0.15, 0.25, 0.9)
        b:SetBackdropBorderColor(0.1, 0.5, 0.85, 1.0)

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(0.4, 0.75, 1.0)
        end

        b:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.08, 0.22, 0.35, 0.95)
            self:SetBackdropBorderColor(0.2, 0.65, 1.0, 1.0)
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.05, 0.15, 0.25, 0.9)
            self:SetBackdropBorderColor(0.1, 0.5, 0.85, 1.0)
        end)
        b:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.03, 0.10, 0.18, 1.0)
            self:SetBackdropBorderColor(0.05, 0.35, 0.6, 1.0)
        end)
        b:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.08, 0.22, 0.35, 0.95)
            self:SetBackdropBorderColor(0.2, 0.65, 1.0, 1.0)
        end)

        b:SetScript("OnClick", function()
            Database:AddCredit("")
            FauxScrollFrame_SetOffset(self.lootLogFrame.scrollframe, 0) -- move to top
        end)
    end

    -- debit (+지출 버튼)
    do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetWidth(60)
        b:SetHeight(28)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 78, -524)
        b:SetText("+" .. L["Debit"])

        b:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        -- +지출: 주황색 테두리 + 폰트
        b:SetBackdropColor(0.30, 0.18, 0.08, 0.9)
        b:SetBackdropBorderColor(1.0, 0.55, 0.1, 1.0)

        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        local normalFontString = b:GetFontString()
        if normalFontString then
            normalFontString:SetTextColor(1.0, 0.7, 0.2)
        end

        b:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.40, 0.25, 0.10, 0.95)
            self:SetBackdropBorderColor(1.0, 0.7, 0.25, 1.0)
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.30, 0.18, 0.08, 0.9)
            self:SetBackdropBorderColor(1.0, 0.55, 0.1, 1.0)
        end)
        b:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(0.20, 0.12, 0.05, 1.0)
            self:SetBackdropBorderColor(0.6, 0.35, 0.05, 1.0)
        end)
        b:SetScript("OnMouseUp", function(self)
            self:SetBackdropColor(0.40, 0.25, 0.10, 0.95)
            self:SetBackdropBorderColor(1.0, 0.7, 0.25, 1.0)
        end)

        b:SetScript("OnClick", function()
            Database:AddDebit(L["Compensation"], "", 0)
            FauxScrollFrame_SetOffset(self.lootLogFrame.scrollframe, 0) -- move to top
        end)
    end

    -- dropbox filter (아이템 등급) - 커스텀 드롭다운 (아이템 품질 필터링 드롭다운)
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
        dropdown:SetWidth(120)
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

        -- 메뉴 아이템 생성
        for i, item in ipairs(menuItems) do
            local itemButton = CreateFrame("Button", nil, dropdown, "BackdropTemplate")
            itemButton:SetWidth(116)
            itemButton:SetHeight(22)
            itemButton:SetPoint("TOP", dropdown, "TOP", 0, -(i-1)*24)
            itemButton:SetText(coloredFilterText(item.value, item.text))

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
        if not GUI.customDropdowns then GUI.customDropdowns = {} end
        table.insert(GUI.customDropdowns, dropdown)

        -- 다른 곳 클릭 시 닫기
        container:SetScript("OnHide", function()
            dropdown:Hide()
        end)

        -- 초기값 설정 (RaidBook: 2=고급+ / 3=희귀+ / 4=영웅+, 기본 3)
        local savedFilterLevel = Database:GetConfigOrDefault("filterlevel", 3)
        if savedFilterLevel < 2 or savedFilterLevel > 4 then savedFilterLevel = 3 end
        local labelMap = { [2] = "고급", [3] = "희귀", [4] = "영웅" }
        local label = labelMap[savedFilterLevel] or "희귀"
        button:SetText(coloredFilterText(savedFilterLevel, label) .. " \226\150\188")
        if false then
            button:SetText("legacy")
        end
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
                                if rowData.cols and rowData.cols[2] then
                                    rowData.cols[2].value = n
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

            -- DEBIT 아이템의 경우 entry.beneficiary가 cols[2].value에서 설정되도록 보장
            if entry.type == "DEBIT" then
                if not entry.beneficiary then
                    entry.beneficiary = entry.cols[2].value or ""
                end
                -- 빈 문자열인 경우 L["[Unknown]"]으로 설정하지 않고 그대로 유지
                if entry.beneficiary == L["[Unknown]"] then
                    entry.beneficiary = ""
                    if entry.cols[2] then
                        entry.cols[2].value = ""
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
                        -- DEBIT 아이템의 경우 cols[2].value도 동기화 (ScrollingTable 데이터 일관성)
                        if entry.cols and entry.cols[2] then
                            entry.cols[2].value = t
                        end

                        -- ScrollingTable UI 데이터 강제 업데이트
                        if self.lootLogFrame and self.lootLogFrame.data and idx then
                            -- UI 테이블에서 해당 행 찾아서 업데이트
                            for _, rowData in ipairs(self.lootLogFrame.data) do
                                if rowData.realItemIdx == idx then
                                    rowData.beneficiary = t
                                    if rowData.cols and rowData.cols[2] then
                                        rowData.cols[2].value = t
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
                ["width"] = 50,
                ["DoCellUpdate"] = iconUpdate,
            },
            {
                ["name"] = L["Entry"],
                ["width"] = 250,
                ["DoCellUpdate"] = entryUpdate,
            },
            {
                ["name"] = L["Beneficiary"],
                ["width"] = 150,
                ["DoCellUpdate"] = beneficiaryUpdate,
            },
            {
                ["name"] = L["Value"],
                ["width"] = 100,
                ["align"] = "RIGHT",
                ["DoCellUpdate"] = valueUpdate,
            },
            {
                ["name"] = L["No Beneficiary"],
                ["width"] = 40,
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
        self.lootLogFrame.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -50)

        -- lib-st 외곽 프레임 + 스크롤바 테마
        if self.lootLogFrame.frame then
            ADDONSELF.theme:ApplyFrame(self.lootLogFrame.frame)
        end
        if self.lootLogFrame.scrollframe and self.lootLogFrame.scrollframe.ScrollBar then
            ADDONSELF.theme:ApplyScrollBar(self.lootLogFrame.scrollframe.ScrollBar)
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
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -308, -524)
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

            -- DEBIT 아이템의 beneficiary 정보를 UI에서 가져와서 동기화
            if GUI.lootTable then
                for _, entry in ipairs(GUI.lootTable.data) do
                    if entry.cols and entry.cols[2] and entry.cols[2].value and entry.realItemIdx then
                        local dbItem = currentItems[entry.realItemIdx]
                        if dbItem and dbItem.type == "DEBIT" then
                            -- UI의 최신 beneficiary 값을 데이터베이스 아이템에 복사
                            dbItem.beneficiary = entry.cols[2].value
                        end
                    end
                end
            end

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

            -- DEBIT 아이템의 beneficiary 정보를 UI에서 가져와서 동기화
            if GUI.lootTable then
                for _, entry in ipairs(GUI.lootTable.data) do
                    if entry.cols and entry.cols[2] and entry.cols[2].value and entry.realItemIdx then
                        local dbItem = currentItems[entry.realItemIdx]
                        if dbItem and dbItem.type == "DEBIT" then
                            -- UI의 최신 beneficiary 값을 데이터베이스 아이템에 복사
                            dbItem.beneficiary = entry.cols[2].value
                        end
                    end
                end
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
        b:SetWidth(120)
        b:SetHeight(28)
        -- 아이템 리스트 우측 끝(-13)에 정렬, +수익/+지출 과 동일 줄 (-524, 반칸 간격)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -13, -524)
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
                    closed = "--- BIDDING CLOSED",
                    resume = "--- NEW BID. RESUMING"
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
                    closed = "--- BIDDING CLOSED",
                    resume = "--- NEW BID. RESUMING"
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

    -- 블랙리스트/화이트리스트 입력 UI — 폐기
    if false then
    do
        -- 블랙리스트 레이블
        local blacklistLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        blacklistLabel:SetPoint("BOTTOMLEFT", f, 20, -17)
        blacklistLabel:SetText("Black List")

        -- 블랙리스트 입력창
        local blacklistEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        blacklistEdit:SetWidth(235)
        blacklistEdit:SetHeight(25)
        blacklistEdit:SetPoint("BOTTOMLEFT", f, 20, -42)
        blacklistEdit:SetAutoFocus(false)
        blacklistEdit:SetMultiLine(false)
        blacklistEdit:SetMaxLetters(999999)
        blacklistEdit:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            SaveItemListToBlacklist(self:GetText())
        end)
        blacklistEdit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            -- 사용자가 필요한 경우에만 ESC로 초기화
            -- 현재는 ESC를 눌러도 입력창은 유지됨
        end)

        -- 블랙리스트 저장 버튼
        local blacklistSaveBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        blacklistSaveBtn:SetWidth(60)
        blacklistSaveBtn:SetHeight(22)
        blacklistSaveBtn:SetPoint("LEFT", blacklistEdit, "RIGHT", 5, 0)
        blacklistSaveBtn:SetText("저장")

        -- 버튼 스타일
        blacklistSaveBtn:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        blacklistSaveBtn:SetBackdropColor(0.6, 0.2, 0.2, 0.9)  -- 붉은색
        blacklistSaveBtn:SetBackdropBorderColor(0.8, 0.4, 0.4, 1.0)  -- 붉은색 테두리

        -- 버튼 텍스트 설정
        blacklistSaveBtn:SetNormalFontObject("GameFontNormalSmall")
        local blacklistFontString = blacklistSaveBtn:GetFontString()
        if blacklistFontString then
            blacklistFontString:SetTextColor(1, 1, 1)
        end

        blacklistSaveBtn:SetScript("OnClick", function()
            SaveItemListToBlacklist(blacklistEdit:GetText())
        end)

        -- 화이트리스트 레이블
        local whitelistLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        whitelistLabel:SetPoint("BOTTOMLEFT", f, 330, -17)
        whitelistLabel:SetText("White List")

        -- 화이트리스트 입력창
        local whitelistEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        whitelistEdit:SetWidth(235)
        whitelistEdit:SetHeight(25)
        whitelistEdit:SetPoint("BOTTOMLEFT", f, 330, -42)
        whitelistEdit:SetAutoFocus(false)
        whitelistEdit:SetMultiLine(false)
        whitelistEdit:SetMaxLetters(999999)
        whitelistEdit:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            SaveItemListToWhitelist(self:GetText())
        end)
        whitelistEdit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            -- 사용자가 필요한 경우에만 ESC로 초기화
            -- 현재는 ESC를 눌러도 입력창은 유지됨
        end)

        -- 화이트리스트 저장 버튼
        local whitelistSaveBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        whitelistSaveBtn:SetWidth(60)
        whitelistSaveBtn:SetHeight(22)
        whitelistSaveBtn:SetPoint("LEFT", whitelistEdit, "RIGHT", 5, 0)
        whitelistSaveBtn:SetText("저장")

        -- 버튼 스타일
        whitelistSaveBtn:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        whitelistSaveBtn:SetBackdropColor(0.2, 0.2, 0.6, 0.9)  -- 푸른색
        whitelistSaveBtn:SetBackdropBorderColor(0.4, 0.4, 0.8, 1.0)  -- 푸른색 테두리

        -- 버튼 텍스트 설정
        whitelistSaveBtn:SetNormalFontObject("GameFontNormalSmall")
        local whitelistFontString = whitelistSaveBtn:GetFontString()
        if whitelistFontString then
            whitelistFontString:SetTextColor(1, 1, 1)
        end

        whitelistSaveBtn:SetScript("OnClick", function()
            SaveItemListToWhitelist(whitelistEdit:GetText())
        end)

        -- GUI 객체에 저장
        GUI.blacklistEdit = blacklistEdit
        GUI.blacklistSaveBtn = blacklistSaveBtn
        GUI.whitelistEdit = whitelistEdit
        GUI.whitelistSaveBtn = whitelistSaveBtn

        -- 현재 리스트 값 로드 및 표시
        local function LoadCurrentLists()
            -- 블랙리스트 현재 상태 표시
            local blacklist = Database:GetConfigOrDefault("itemBlacklist", {})
            if next(blacklist) then
                local blacklistItems = {}
                for item in pairs(blacklist) do
                    table.insert(blacklistItems, item)
                end
                blacklistEdit:SetText(table.concat(blacklistItems, ", "))
            end

            -- 화이트리스트 현재 상태 표시
            local whitelist = Database:GetConfigOrDefault("itemWhitelist", {})
            if next(whitelist) then
                local whitelistItems = {}
                for item in pairs(whitelist) do
                    table.insert(whitelistItems, item)
                end
                whitelistEdit:SetText(table.concat(whitelistItems, ", "))
            end
        end

        -- 로드 후 현재 리스트 표시
        LoadCurrentLists()
    end
    end -- end of if false (블랙/화이트리스트 폐기)

  
end

-- CLI에서 GUI 드롭다운 업데이트를 위해 호출하는 함수
function GUI:UpdateAutoLootDropdown(value)
    -- value 파라미터는 무시하고 데이터베이스에서 직접 읽음
    local dbValue = Database:GetConfigOrDefault("autoaddloot", AUTOADDLOOT_TYPE_DISABLE)
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

function UpdateAllDistributeLabel()
    if not GUI.allDistributeLabel then
        return
    end

    local totalMembers = tonumber(GUI.countEdit:GetText()) or 40

    -- 여러 방법으로 checkAllDistributeButton 찾기
    local checkAllDistribute = true
    local checkbox = GUI.checkAllDistributeButton or _G.IberisRaidAuctionCheckAllDistributeButton

    if checkbox then
        local rawValue = checkbox:GetChecked()
        checkAllDistribute = (rawValue == true) or (rawValue == 1)
    end

    if checkAllDistribute then
        -- 모두 분배: 득자 포함
        GUI.allDistributeLabel:SetText(L["Distribute All"] .. "(" .. totalMembers .. ")")
    else
        -- 모두 분배 해제: 득자 수 계산
        local beneficiaryCount = GUI:GetBeneficiaryCount()
        local actualMembers = math.max(1, totalMembers - beneficiaryCount)
        GUI.allDistributeLabel:SetText(L["Distribute All"] .. "(" .. actualMembers .. ")")
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

-- 블랙리스트/화이트리스트 입력 UI 추가 (Init 함수 안으로 이동해야 함)
-- 아이템 리스트 파싱 함수
local function ParseItemList(text)
    local items = {}

    -- 콤마로 먼저 분리
    for itemPart in string.gmatch(text, "([^,]+)") do
        -- 앞뒤 공백 제거 (내부 공백은 유지)
        local cleanItem = strtrim(itemPart)
        if cleanItem ~= "" then
            table.insert(items, cleanItem)
        end
    end

    return items
end

-- 아이템 유효성 검증 함수
local function ValidateItem(itemInput)
    if not itemInput or itemInput == "" then
        return false, "빈 입력값"
    end

    local trimmed = strtrim(itemInput)

    -- 아이템 이름 확인 (한글 아이템명 지원 강화)
    local name, link = GetItemInfo(trimmed)
    if name then
        return true, name  -- 항상 아이템 이름으로 저장
    end

    -- 게임에서 찾을 수 없는 아이템도 최소 길이 확인 후 이름으로 저장
    -- 실제 검증은 드랍 시 필터링에서 처리
    if string.len(trimmed) >= 2 then
        return true, trimmed  -- 이름으로 그냥 저장 (실제 검증은 드랍 시)
    else
        return false, "너무 짧은 아이템명: " .. trimmed
    end
end

-- 블랙리스트 저장 함수
function SaveItemListToBlacklist(text)
    local items = ParseItemList(text)
    if #items == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("저장할 아이템이 없습니다.", 1, 0, 0)
        return
    end

    -- 기존 데이터를 비우고 새로 시작
    local newBlacklist = {}
    local addedCount = 0
    local errorItems = {}

    for _, item in ipairs(items) do
        local isValid, normalizedItem = ValidateItem(item)
        if isValid then
            if not newBlacklist[normalizedItem] then
                newBlacklist[normalizedItem] = true
                addedCount = addedCount + 1
            end
        else
            table.insert(errorItems, item)
        end
    end

    Database:SetConfig("itemBlacklist", newBlacklist)

    -- 결과 피드백
    if addedCount > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(addedCount .. "개 아이템을 블랙리스트에 설정했습니다.", 0, 1, 0)
    end

    if #errorItems > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("오류 아이템: " .. table.concat(errorItems, ", "), 1, 0, 0)
    end
end

-- 화이트리스트 저장 함수
function SaveItemListToWhitelist(text)
    local items = ParseItemList(text)
    if #items == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("저장할 아이템이 없습니다.", 1, 0, 0)
        return
    end

    -- 기존 데이터를 비우고 새로 시작
    local newWhitelist = {}
    local addedCount = 0
    local errorItems = {}

    for _, item in ipairs(items) do
        local isValid, normalizedItem = ValidateItem(item)
        if isValid then
            if not newWhitelist[normalizedItem] then
                newWhitelist[normalizedItem] = true
                addedCount = addedCount + 1
            end
        else
            table.insert(errorItems, item)
        end
    end

    Database:SetConfig("itemWhitelist", newWhitelist)

    -- 결과 피드백
    if addedCount > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(addedCount .. "개 아이템을 화이트리스트에 설정했습니다.", 0, 1, 0)
    end

    if #errorItems > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("오류 아이템: " .. table.concat(errorItems, ", "), 1, 0, 0)
    end
end

