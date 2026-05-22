local _, ADDONSELF = ...

local L = ADDONSELF.L

--- TOC Version (Retail/Anniversary: C_AddOns.GetAddOnMetadata, 구 클라: GetAddOnMetadata)
local function GetIberisRaidAuctionAddonVersion()
    local n = (ADDONSELF.addonName) or "IberisRaidAuction"
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local v = C_AddOns.GetAddOnMetadata(n, "Version")
        if v and v ~= "" then
            return v
        end
    end
    if GetAddOnMetadata then
        local v = GetAddOnMetadata(n, "Version")
        if v and v ~= "" then
            return v
        end
    end
    return "1.00"
end
ADDONSELF.GetAddOnVersion = GetIberisRaidAuctionAddonVersion

-- 마력추출 인계 득자: 표시·그룹핑은 *마력추출* 로 통일 (예전 한쪽만 * 인 저장값 호환)
function ADDONSELF.NormalizeDisenchantHandoffBeneficiary(s)
    if type(s) ~= "string" or s == "" then
        return s
    end
    if s == "*마력추출" or s == "*마력추출*" then
        return "*마력추출*" -- 예전 한쪽만 * 인 저장값·표시 통일
    end
    return s
end

function ADDONSELF.FormatBeneficiaryForDisplay(s)
    return ADDONSELF.NormalizeDisenchantHandoffBeneficiary(s)
end

local function GetLedgerWinnerForCount(item)
    local getter = ADDONSELF.GetLedgerWinnerName
    local raw = getter and getter(item) or item and (item.winner or item.beneficiary) or ""
    return ADDONSELF.NormalizeDisenchantHandoffBeneficiary(raw or "")
end

local function GetLedgerDisplayBeneficiaryName(item)
    local getter = ADDONSELF.GetLedgerDisplayBeneficiary
    local raw = getter and getter(item) or item and item.beneficiary or ""
    return ADDONSELF.NormalizeDisenchantHandoffBeneficiary(raw or "")
end

function ADDONSELF.IsDisenchantHandoffBeneficiary(s)
    return ADDONSELF.NormalizeDisenchantHandoffBeneficiary(s) == "*마력추출*"
end

ADDONSELF.print = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|CFFFF0000<|r|CFFFFD100IberisRaidAuction|r|CFFFF0000>|r "..(msg or "nil"))
end

-- 레이드 경보 영역(공대장 경보와 동일한 프레임)에 표시
ADDONSELF.raidWarningNotice = function(msg)
    if not msg or msg == "" then return end
    if RaidNotice_AddMessage and RaidWarningFrame then
        local c = (ChatTypeInfo and ChatTypeInfo.RAID_WARNING) or { r = 1, g = 0.85, b = 0, a = 1 }
        RaidNotice_AddMessage(RaidWarningFrame, msg, c)
    else
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

-- 화면 상단 짧은 토스트(채팅을 잘 안 볼 때 안내용). 연속 호출 시 타이머만 갱신됨.
local iraToastFrame
local iraToastExpireSeq = 0

-- tone: "success"(녹색), "warn"(황색), "danger"·nil = 빨간 테두리(거절·오류 안내)
function ADDONSELF.showToast(msg, holdSec, tone)
    if not msg or msg == "" then
        return
    end
    holdSec = tonumber(holdSec) or 4.5
    if not iraToastFrame then
        iraToastFrame = CreateFrame("Frame", "IberisRaidAuctionToastFrame", UIParent, "BackdropTemplate")
        iraToastFrame:SetSize(440, 88)
        iraToastFrame:SetPoint("TOP", UIParent, "TOP", 0, -96)
        iraToastFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        iraToastFrame:SetFrameLevel(200)
        iraToastFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 10, right = 10, top = 10, bottom = 10 },
        })
        iraToastFrame:EnableMouse(false)
        local fs = iraToastFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", 14, -12)
        fs:SetPoint("BOTTOMRIGHT", -14, 12)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetWordWrap(true)
        fs:SetSpacing(2)
        iraToastFrame.text = fs
        iraToastFrame:Hide()
    end
    if tone == "success" then
        iraToastFrame:SetBackdropColor(0.06, 0.14, 0.09, 0.94)
        iraToastFrame:SetBackdropBorderColor(0.35, 0.92, 0.48, 1)
    elseif tone == "warn" then
        iraToastFrame:SetBackdropColor(0.12, 0.1, 0.04, 0.94)
        iraToastFrame:SetBackdropBorderColor(1, 0.78, 0.22, 1)
    else
        -- danger (또는 tone 미지정): 주황이 아닌 명확한 적색 테두리
        iraToastFrame:SetBackdropColor(0.16, 0.05, 0.05, 0.95)
        iraToastFrame:SetBackdropBorderColor(0.95, 0.18, 0.18, 1)
    end
    iraToastFrame.text:SetText(msg)
    iraToastFrame:Show()
    iraToastExpireSeq = iraToastExpireSeq + 1
    local seq = iraToastExpireSeq
    C_Timer.After(holdSec, function()
        if seq == iraToastExpireSeq and iraToastFrame then
            iraToastFrame:Hide()
        end
    end)
end

local function FormatGoldComma(n)
    local s = tostring(math.floor(n))
    while true do
        local k
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

local function GetMoneyStringL(money)
	local gold = math.floor(money)
	if gold > 0 then
		return FormatGoldComma(gold) .. "골드"
	end
	return "0골드"
end

local function SendToCurrrentChannel(msg)
    local chatType = DEFAULT_CHAT_FRAME.editBox:GetAttribute("chatType")
    local whisperTo = DEFAULT_CHAT_FRAME.editBox:GetAttribute("tellTarget")
    if chatType == "WHISPER" then
        SendChatMessage(msg, chatType, nil, whisperTo)
    elseif chatType == "CHANNEL" then
        SendChatMessage(msg, chatType, nil, DEFAULT_CHAT_FRAME.editBox:GetAttribute("channelTarget"))
    elseif chatType == "BN_WHISPER" then
        BNSendWhisper(BNet_GetBNetIDAccount(whisperTo), msg)
    else
        SendChatMessage(msg, chatType)
    end
end

local function noop() end

local CRLF = "\r\n"


ADDONSELF.CRLF = CRLF

local calcavg = function(items, n, oncredit, ondebit, checkAllDistribute)

    oncredit = oncredit or noop
    ondebit  = ondebit or noop

    local revenue = 0
    local expense = 0
    local saltN = n

    -- checkAllDistribute 파라미터가 없으면 기본값 true 사용 (호환성 유지)
    if checkAllDistribute == nil then
        checkAllDistribute = true
    end

    -- checkAllDistribute에 따라 분배 인원 계산
    if checkAllDistribute then
        saltN = n  -- 전체 분배: 입력된 인원으로
    else
        -- 득자 제외 분배: 입력된 인원 - 실제 득자 수 (CREDIT 아이템만)
        local beneficiaries = {}
        for _, item in pairs(items or {}) do
            -- CREDIT 아이템만 득자 계산에서 제외
            local winner = GetLedgerWinnerForCount(item)
            if item.type == "CREDIT" and item.noBeneficiary ~= true and winner ~= "" and item.cost and item.cost > 0 then
                beneficiaries[winner] = true
            end
        end
        local actualBeneficiaryCount = 0
        for _ in pairs(beneficiaries) do
            actualBeneficiaryCount = actualBeneficiaryCount + 1
        end
        saltN = math.max(n - actualBeneficiaryCount, 1)
    end


    local profitPercentItems = {}
    local mulAvgItems = {}

    local totalItems = 0
    local excludedItems = 0
    local includedCredits = 0

    for _, item in pairs(items or {}) do
        totalItems = totalItems + 1

        -- 수익/지출 계산에는 모든 아이템 포함 (noBeneficiary 관계없이)
        local c = item["cost"] or 0
        local t = item["type"]
        local ct = item["costtype"] or "GOLD"

        if t == "CREDIT" then
            item["costcache"] = c
            revenue = revenue + c
            includedCredits = includedCredits + 1

  
            -- oncredit 콜백은 항상 호출 (모든 아이템을 표시하기 위해)
            if oncredit then
                if c > 0 then
                  end
                oncredit(item, c)
            else
                end
        elseif t == "DEBIT" then
              if ct == "GOLD" then
                expense = expense + c
                item["costcache"] = c
                  ondebit(item, c)
            elseif ct == "PROFIT_PERCENT" then
                table.insert( profitPercentItems, item)
            elseif ct == "MUL_AVG" then
                -- MUL_AVG 아이템은 분배 인원(saltN)에 추가하지 않음
                -- 나중에 avg * cost로 계산됨
                table.insert(mulAvgItems, item)
            end
        end
    end

    
    -- before profit

    local profit = math.max(revenue - expense, 0)
    -- after profit

    do
        -- recalculate expense
        for _, item in pairs(profitPercentItems) do
            local p = item["cost"] or 0
            local c = math.floor(profit * (p / 100.0))

            expense = expense + c
            item["costcache"] = c
            ondebit(item, c)
        end
    end

    profit = math.max(revenue - expense, 0)

    local avg = 0

    if saltN > 0 then
        avg = 1.0 * profit / saltN
        avg = math.max( avg, 0)
        avg = math.floor( avg )  -- 골드 단위 절삭
    end

    do
        -- recalculate expense
        for _, item in pairs(mulAvgItems) do
            local m = item["cost"] or 0
            local c = math.floor(m * avg)
            expense = expense + c
            item["costcache"] = c
            ondebit(item, c)
        end
    end
    
    profit = math.max(revenue - expense, 0)

    return profit, avg, revenue, expense
end

ADDONSELF.calcavg = calcavg


local function GenExportLine(item, c)
    -- 가격이 0인 아이템은 제외
    if c == 0 then
        return ""
    end

    local rawB = GetLedgerDisplayBeneficiaryName(item)
    local l = (not rawB or rawB == "") and L["[Unknown]"] or ADDONSELF.FormatBeneficiaryForDisplay(rawB)
    local i = item["detail"]["item"] or ""
    local d = item["detail"]["displayname"] or ""
    local t = item["type"]
    local ct = item["costtype"]

    local n = GetItemInfo(i) or d
    n = n ~= "" and n or nil
    n = n or L["Other"]

    if t == "DEBIT" then
        n = d or L["Compensation"]
    end

    local s = "[" ..  n .. "] " .. l .. " " .. GetMoneyStringL(c)

    if ct == "PROFIT_PERCENT" then
        s = s .. " (" .. (item["cost"] or 0) .. " %" .. L["Net Profit"] .. ")"
    elseif ct == "MUL_AVG" then
        s = s .. " (" .. (item["cost"] or 0) .. " *" .. L["Per Member credit"] .. ")"
    end

    return s
end

-- IRA_UI 양식 거래기록 (자동 캡처 [아이템] / 수동 [+수익] / [무득 아이템] / [+지출] / 요약)
ADDONSELF.genexport = function(items, n, checkf, checkAllDistribute)

    if type(checkAllDistribute) == "number" then
        checkAllDistribute = true
    end

    local originalCheckAllDistribute = nil
    if checkAllDistribute ~= nil and ADDONSELF and ADDONSELF.db and ADDONSELF.db.GetConfigOrDefault and ADDONSELF.db.SetConfig then
        originalCheckAllDistribute = ADDONSELF.db:GetConfigOrDefault("checkAllDistribute", true)
        ADDONSELF.db:SetConfig("checkAllDistribute", checkAllDistribute)
    end

    -- 실제 분배 인원 계산 (calcavg와 동일한 로직)
    local splitCount = n
    if not checkAllDistribute then
        local beneficiaries = {}
        for _, item in pairs(items or {}) do
            local winner = GetLedgerWinnerForCount(item)
            if item.type == "CREDIT" and item.noBeneficiary ~= true and winner ~= "" and item.cost and item.cost > 0 then
                beneficiaries[winner] = true
            end
        end
        local actualBeneficiaryCount = 0
        for _ in pairs(beneficiaries) do
            actualBeneficiaryCount = actualBeneficiaryCount + 1
        end
        splitCount = math.max(n - actualBeneficiaryCount, 0)
    end

    local filteredItems = items
    local grp = {}
    local looternames = "득자 : "

    if checkAllDistribute == nil then
        checkAllDistribute = not checkf
    end

    local profit, avg, revenue, expense  = ADDONSELF.calcavg(filteredItems, n,
        function(item, c)
            if item.noBeneficiary ~= true then
                local l = GetLedgerDisplayBeneficiaryName(item)
                l = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(l)
                if l == "" and item.type ~= "DEBIT" then
                    l = L["[Unknown]"]
                end
                local i = item["detail"]["item"] or ""
                local d = item["detail"]["displayname"] or ""
                if not grp[l] then
                    grp[l] = {
                        ["cost"] = 0,
                        ["items"] = {},
                        ["manualItems"] = {},
                        ["autoCost"] = 0,
                        ["manualCost"] = 0,
                        ["citems"] = {},
                        ["compensation"] = 0,
                    }
                end

                grp[l]["cost"] = grp[l]["cost"] + c

                if c > 0 then
                    if item.type ~= "DEBIT" then
                        local hasItemLink = i and i ~= ""
                        if hasItemLink then
                            local itemName = (not GetItemInfoFromHyperlink(i)) and d or i
                            table.insert(grp[l]["items"], itemName .. " " .. GetMoneyStringL(c))
                            grp[l]["autoCost"] = grp[l]["autoCost"] + c
                        else
                            local itemName = d or L["Other"]
                            table.insert(grp[l]["manualItems"], itemName .. " " .. GetMoneyStringL(c))
                            grp[l]["manualCost"] = grp[l]["manualCost"] + c
                        end
                    end
                end
            end
        end,
        function(item, c)
            local l = GetLedgerDisplayBeneficiaryName(item)
            l = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(l)
            if l == "" and item.type ~= "DEBIT" then
                l = L["[Unknown]"]
            end
            local d = item["detail"]["displayname"] or ""
            local ct = item["costtype"] or "GOLD"

            if not grp[l] then
                grp[l] = {
                    ["cost"] = 0,
                    ["items"] = {},
                    ["manualItems"] = {},
                    ["autoCost"] = 0,
                    ["manualCost"] = 0,
                    ["citems"] = {},
                    ["compensation"] = 0,
                }
            end

            local s = d .. " " .. GetMoneyStringL(c)

            if ct == "PROFIT_PERCENT" then
                s = s .. " (" .. (item["cost"] or 0) .. " % " .. L["Net Profit"] .. ")"
            elseif ct == "MUL_AVG" then
                s = s .. " (" .. (item["cost"] or 0) .. " * " .. L["Per Member credit"] .. ")"
            end

            grp[l]["compensation"] = grp[l]["compensation"] + c
            table.insert(grp[l]["citems"], s)
        end,
        checkAllDistribute
    )

    local looter = {}        -- 자동 캡처 [아이템]
    local manualLooter = {}  -- 수동 [+수익]
    local compensation = {}

    for l, k in pairs(grp) do
        local classFilename
        for i = 1, MAX_RAID_MEMBERS do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            if name == l then
                classFilename = class
                break
            end
        end
        local looterName = l
        if classFilename and RAID_CLASS_COLORS[classFilename] then
            local color = RAID_CLASS_COLORS[classFilename].colorStr
            looterName = "|c" .. color .. l .. "|r"
        end

        if k["items"] and #k["items"] > 0 then
            table.insert(looter, {
                ["cost"] = k["autoCost"] or 0,
                ["items"] = k["items"],
                ["looter"] = looterName,
            })
        end
        if k["manualItems"] and #k["manualItems"] > 0 then
            table.insert(manualLooter, {
                ["cost"] = k["manualCost"] or 0,
                ["items"] = k["manualItems"],
                ["looter"] = looterName,
            })
        end
        if k["compensation"] > 0 then
            table.insert(compensation, {
                ["beneficiary"] = looterName,
                ["compensation"] = k["compensation"],
                ["citems"] = k["citems"],
            })
        end
    end

    table.sort(looter, function(a, b) return a["cost"] > b["cost"] end)
    table.sort(manualLooter, function(a, b) return a["cost"] > b["cost"] end)
    table.sort(compensation, function(a, b) return a["compensation"] > b["compensation"] end)

    if #looter > 0 then
        local c = math.min(#looter, 40)
        local c_final = 0
        while c > 0 and looter[c]["cost"] == 0 do c = c - 1 end
        for i = 1, c do
            if looter[i] and looter[i]["looter"] ~= "" then
                looternames = looternames .. looter[i]["looter"] .. ", "
                c_final = c_final + 1
            end
        end
        looternames = looternames .. " (총 " .. c_final .. "명)"
    end

    local outputText = ""

    -- [아이템] 자동 캡처
    if #looter > 0 then
        outputText = outputText .. "=========================" .. CRLF
        outputText = outputText .. "[아이템]" .. CRLF
        local count = 0
        for i, entry in ipairs(looter) do
            if entry.cost > 0 then
                count = count + 1
                local name = entry.looter
                outputText = outputText .. string.format("%d. %s [%s]" .. CRLF, count, name, GetMoneyStringL(entry.cost))
                for idx, item in ipairs(entry.items) do
                    outputText = outputText .. string.format("%d) %s %s" .. CRLF, idx, name, item)
                end
            end
        end
    end

    -- [무득 아이템]
    do
        local noBeneficiaryItems = {}
        for _, item in pairs(items or {}) do
            if item.type == "CREDIT" and item.noBeneficiary == true and item.cost and item.cost > 0 then
                local i = item["detail"]["item"] or ""
                local rawB = GetLedgerDisplayBeneficiaryName(item)
                local l = (not rawB or rawB == "") and L["[Unknown]"] or ADDONSELF.FormatBeneficiaryForDisplay(rawB)
                local actualCost = item.costcache or item.cost
                table.insert(noBeneficiaryItems, {
                    itemLink = i, beneficiary = l, cost = actualCost,
                })
            end
        end
        if #noBeneficiaryItems > 0 then
            outputText = outputText .. CRLF
            outputText = outputText .. "=========================" .. CRLF
            outputText = outputText .. "[무득 아이템]" .. CRLF
            for i, item in ipairs(noBeneficiaryItems) do
                outputText = outputText .. string.format("%d. %s [%s] %s" .. CRLF, i, item.beneficiary, item.itemLink, GetMoneyStringL(item.cost))
            end
            outputText = outputText .. CRLF
        end
    end

    -- [+수익] 수동 추가
    if #manualLooter > 0 then
        outputText = outputText .. CRLF
        outputText = outputText .. "=========================" .. CRLF
        outputText = outputText .. "[+" .. L["Credit"] .. "]" .. CRLF
        local count = 0
        for i, entry in ipairs(manualLooter) do
            if entry.cost > 0 then
                count = count + 1
                local name = entry.looter
                outputText = outputText .. string.format("%d. %s [%s]" .. CRLF, count, name, GetMoneyStringL(entry.cost))
                for idx, item in ipairs(entry.items) do
                    outputText = outputText .. string.format("%d) %s %s" .. CRLF, idx, name, item)
                end
            end
        end
        outputText = outputText .. CRLF
    end

    -- [+지출]
    if expense > 0 and #compensation > 0 then
        outputText = outputText .. CRLF
        outputText = outputText .. "=========================" .. CRLF
        outputText = outputText .. "[+" .. L["Debit"] .. "]" .. CRLF
        for i, l in ipairs(compensation) do
            local beneficiaryName = l.beneficiary or L["[Unknown]"]
            outputText = outputText .. string.format("%d. %s [%s]" .. CRLF, i, beneficiaryName, GetMoneyStringL(l.compensation))
            for idx, item in ipairs(l.citems) do
                outputText = outputText .. string.format("%d) %s %s" .. CRLF, idx, beneficiaryName, item)
            end
        end
    end

    -- 자동/수동 수익 분리
    local manualRevenue = 0
    for _, item in pairs(items or {}) do
        if item.type == "CREDIT" and item.cost and item.cost > 0
                and (item.costtype == nil or item.costtype == "GOLD")
                and not (item.detail and item.detail.item) then
            manualRevenue = manualRevenue + item.cost
        end
    end
    local autoRevenue = (revenue or 0) - manualRevenue
    local distribution = profit or 0

    local floorNum = math.floor(avg)
    local partyMoney  = floorNum * 5
    local partyMoney4 = floorNum * 4
    local partyMoney3 = floorNum * 3
    local partyMoney2 = floorNum * 2

    local s = outputText .. CRLF
    s = s .. "=========================" .. CRLF
    s = s .. "아이템 : "    .. GetMoneyStringL(autoRevenue)     .. CRLF
    s = s .. "총수익 : +"   .. GetMoneyStringL(manualRevenue)   .. CRLF
    s = s .. "총지출 : -"   .. GetMoneyStringL(expense)         .. CRLF
    s = s .. "총분배금 : "  .. GetMoneyStringL(distribution)    .. CRLF
    s = s .. looternames .. CRLF
    s = s .. "분배 인원 설정 : " .. splitCount                  .. CRLF
    s = s .. "개인당 : " .. GetMoneyStringL(floorNum)           .. CRLF
    s = s .. "파티당 : " .. GetMoneyStringL(partyMoney)         .. CRLF
    s = s .. "4명당 : "  .. GetMoneyStringL(partyMoney4)        .. CRLF
    s = s .. "3명당 : "  .. GetMoneyStringL(partyMoney3)        .. CRLF
    s = s .. "2명당 : "  .. GetMoneyStringL(partyMoney2)        .. CRLF

    if originalCheckAllDistribute ~= nil and ADDONSELF and ADDONSELF.db and ADDONSELF.db.SetConfig then
        ADDONSELF.db:SetConfig("checkAllDistribute", originalCheckAllDistribute)
    end

    return s
end

-- IRA_UI 양식 채팅 출력 (자동 [아이템] / [무득 아이템] / [+수익] / [+지출] / 정산 — genexport와 동일 포맷)
ADDONSELF.genreport = function(items, n, channel, checkf)

    if channel == "RAID" and not IsInRaid() then
        ADDONSELF.print("공격대 상태에서만 출력 가능합니다.")
        return
    end

    local filteredItems = items

    -- UI에서 DEBIT 아이템의 최신 beneficiary 정보 가져와서 items 배열 업데이트
    local GUI = ADDONSELF.gui
    if GUI and GUI.lootLogFrame then
        local uiData = GUI.lootLogFrame.data
        for idx, entry in ipairs(uiData or {}) do
            local isDebitItem = false
            if entry.type == "DEBIT" then isDebitItem = true end
            if entry.realItemIdx and filteredItems[entry.realItemIdx] and filteredItems[entry.realItemIdx].type == "DEBIT" then
                isDebitItem = true
            end
            if entry.cols and entry.cols[3] and entry.cols[3].value and type(entry.cols[3].value) == "string" and string.find(entry.cols[3].value, "보상:") then
                isDebitItem = true
            end
            if isDebitItem and entry.cols and entry.cols[4] then
                local dbItem = nil
                if entry.realItemIdx and filteredItems[entry.realItemIdx] then
                    dbItem = filteredItems[entry.realItemIdx]
                end
                if not dbItem and entry.cols[3] and entry.cols[3].value then
                    for _, item in ipairs(filteredItems) do
                        if item.type == "DEBIT" and item.detail and item.detail.displayname == entry.cols[3].value then
                            dbItem = item
                            break
                        end
                    end
                end
                local currentUIValue = entry.beneficiary or entry.cols[4].value or ""
                if dbItem then
                    dbItem.beneficiary = currentUIValue
                end
            end
        end
    end

    local lines = {}
    local grp = {}

    local checkAllDistribute = true
    local checkbox = _G.IberisRaidAuctionCheckAllDistributeButton
    if checkbox then
        local rawValue = checkbox:GetChecked()
        checkAllDistribute = (rawValue == true) or (rawValue == 1)
    end

    local oncreditCallback = function(item, c)
        if c == 0 then return end
        if item.noBeneficiary ~= true then
            local l = GetLedgerDisplayBeneficiaryName(item)
            l = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(l)
            if l == "" and item.type ~= "DEBIT" then
                l = L["[Unknown]"]
            end
            local i = item["detail"]["item"] or ""
            local d = item["detail"]["displayname"] or ""

            if not grp[l] then
                grp[l] = {
                    ["cost"] = 0,
                    ["items"] = {},
                    ["manualItems"] = {},
                    ["manualCost"] = 0,
                    ["autoCost"] = 0,
                    ["citems"] = {},
                    ["compensation"] = 0,
                }
            end
            grp[l]["cost"] = grp[l]["cost"] + c

            if item.type == "CREDIT" then
                local hasItemLink = i and i ~= ""
                if hasItemLink then
                    local itemName = (not GetItemInfoFromHyperlink(i)) and d or i
                    grp[l]["autoCost"] = grp[l]["autoCost"] + c
                    table.insert(grp[l]["items"], itemName .. " " .. GetMoneyStringL(c))
                else
                    grp[l]["manualCost"] = grp[l]["manualCost"] + c
                    table.insert(grp[l]["manualItems"], (d or L["Other"]) .. " " .. GetMoneyStringL(c))
                end
            end
        end
    end

    local profit, avg, revenue, expense = ADDONSELF.calcavg(filteredItems, n,
        oncreditCallback,
        function(item, c)
            local l = GetLedgerDisplayBeneficiaryName(item)
            l = ADDONSELF.NormalizeDisenchantHandoffBeneficiary(l)
            if l == "" and item.type ~= "DEBIT" then
                l = L["[Unknown]"]
            end
            local d = item["detail"]["displayname"] or ""
            local ct = item["costtype"] or "GOLD"

            if not grp[l] then
                grp[l] = {
                    ["cost"] = 0,
                    ["items"] = {},
                    ["manualItems"] = {},
                    ["manualCost"] = 0,
                    ["autoCost"] = 0,
                    ["citems"] = {},
                    ["compensation"] = 0,
                }
            end

            local s = d .. " " .. GetMoneyStringL(c)
            if ct == "PROFIT_PERCENT" then
                s = s .. " (" .. (item["cost"] or 0) .. " % " .. L["Net Profit"] .. ")"
            elseif ct == "MUL_AVG" then
                s = s .. " (" .. (item["cost"] or 0) .. " * " .. L["Per Member credit"] .. ")"
            end
            grp[l]["compensation"] = grp[l]["compensation"] + c
            table.insert(grp[l]["citems"], s)
        end,
        checkAllDistribute
    )

    local looter = {}        -- 자동 캡처 [아이템]
    local manualLooter = {}  -- 수동 [+수익]
    local compensation = {}

    for l, k in pairs(grp) do
        local classFilename
        local nameShort = Ambiguate(l, "short")
        for i = 1, MAX_RAID_MEMBERS do
            local raidName = GetRaidRosterInfo(i)
            if raidName and Ambiguate(raidName, "short") == nameShort then
                local guid = UnitGUID("raid"..i)
                if guid then
                    local _, _, _, _, _, class = GetPlayerInfoByGUID(guid)
                    classFilename = class
                end
                break
            end
        end
        local looterName = l
        if classFilename and RAID_CLASS_COLORS[classFilename] then
            local color = RAID_CLASS_COLORS[classFilename].colorStr
            looterName = "|c" .. color .. l .. "|r"
        end

        if k["items"] and #k["items"] > 0 then
            table.insert(looter, {
                ["cost"] = k["autoCost"] or 0,
                ["items"] = k["items"],
                ["looter"] = looterName,
            })
        end
        if k["manualItems"] and #k["manualItems"] > 0 then
            table.insert(manualLooter, {
                ["cost"] = k["manualCost"] or 0,
                ["items"] = k["manualItems"],
                ["looter"] = looterName,
            })
        end
        if k["compensation"] > 0 then
            table.insert(compensation, {
                ["beneficiary"] = looterName,
                ["compensation"] = k["compensation"],
                ["citems"] = k["citems"],
            })
        end
    end

    table.sort(looter,        function(a, b) return a["cost"] > b["cost"] end)
    table.sort(manualLooter,  function(a, b) return a["cost"] > b["cost"] end)
    table.sort(compensation,  function(a, b) return a["compensation"] > b["compensation"] end)

    -- 득자 이름 목록 (자동 캡처 받은 사람만)
    local beneficiaryNames = {}
    local seenNames = {}
    local function pushBeneficiary(entry)
        local cleanName = entry.looter
        cleanName = cleanName:gsub("|c[%x%x%x%x%x%x%x%x%x]+", "")
        cleanName = cleanName:gsub("|cff[%x%x%x%x%x%x%x]+", "")
        cleanName = cleanName:gsub("|r", "")
        cleanName = cleanName:gsub("|T[^|]*|t", "")
        cleanName = cleanName:gsub("|H[^|]*|h?([^|]*)|h?", "%1")
        cleanName = cleanName:gsub("|n", "")
        cleanName = cleanName:gsub("|x%x%x%x%x", "")
        if cleanName ~= "" and not seenNames[cleanName] then
            seenNames[cleanName] = true
            table.insert(beneficiaryNames, cleanName)
        end
    end
    for _, entry in ipairs(looter) do if entry.cost > 0 then pushBeneficiary(entry) end end

    -- 요약 모드: 엔트리들 다 숨기고 정산만 표시
    if not checkf then
        -- [아이템] 자동 캡처
        if #looter > 0 then
            table.insert(lines, "=========================")
            table.insert(lines, "[아이템]")
            local count = 0
            for i, entry in ipairs(looter) do
                if entry.cost > 0 then
                    count = count + 1
                    local name = entry.looter
                    table.insert(lines, string.format("%d. %s [%s]", count, name, GetMoneyStringL(entry.cost)))
                    for idx, item in ipairs(entry.items) do
                        table.insert(lines, string.format("%d) %s %s", idx, name, item))
                    end
                end
            end
        end
    end

    -- 무득 아이템
    local noBeneficiaryItems = {}
    for _, item in pairs(items or {}) do
        if item.type == "CREDIT" and item.noBeneficiary == true and item.cost and item.cost > 0 then
            local i = item["detail"]["item"] or ""
            local d = item["detail"]["displayname"] or ""
            local rawB = GetLedgerDisplayBeneficiaryName(item)
            local l = (not rawB or rawB == "") and L["[Unknown]"] or ADDONSELF.FormatBeneficiaryForDisplay(rawB)
            local actualCost = item.costcache or item.cost
            table.insert(noBeneficiaryItems, {
                itemLink = i, displayName = d, beneficiary = l, cost = actualCost,
            })
        end
    end

    if not checkf then
        if #noBeneficiaryItems > 0 then
            table.insert(lines, "=========================")
            table.insert(lines, "[무득 아이템]")
            for i, item in ipairs(noBeneficiaryItems) do
                table.insert(lines, string.format("%d. %s [%s] %s", i, item.beneficiary, item.itemLink, GetMoneyStringL(item.cost)))
            end
        end

        -- [+수익] 수동 추가
        if #manualLooter > 0 then
            table.insert(lines, "=========================")
            table.insert(lines, "[+" .. L["Credit"] .. "]")
            local count = 0
            for i, entry in ipairs(manualLooter) do
                if entry.cost > 0 then
                    count = count + 1
                    local name = entry.looter
                    table.insert(lines, string.format("%d. %s [%s]", count, name, GetMoneyStringL(entry.cost)))
                    for idx, item in ipairs(entry.items) do
                        table.insert(lines, string.format("%d) %s %s", idx, name, item))
                    end
                end
            end
        end

        if expense > 0 and #compensation > 0 then
            table.insert(lines, "=========================")
            table.insert(lines, "[+" .. L["Debit"] .. "]")
            local c = math.min(#compensation, 80)
            for i = 1, c do
                local l = compensation[i]
                local beneficiaryName = l["beneficiary"] or L["[Unknown]"]
                table.insert(lines, i .. ". " .. beneficiaryName .. " [" .. GetMoneyStringL(l["compensation"]) .. "]")
                for idx, item in ipairs(l["citems"]) do
                    table.insert(lines, string.format("%d) %s %s", idx, beneficiaryName, item))
                end
            end
        end
    end

    -- 자동/수동 수익 분리
    local manualRevenue = 0
    for _, item in pairs(items or {}) do
        if item.type == "CREDIT" and item.cost and item.cost > 0
                and (item.costtype == nil or item.costtype == "GOLD")
                and not (item.detail and item.detail.item) then
            manualRevenue = manualRevenue + item.cost
        end
    end
    local autoRevenue  = (revenue or 0) - manualRevenue
    local distribution = profit or 0

    local floorNum    = math.floor(avg or 0)
    local partyMoney  = floorNum * 5
    local partyMoney4 = floorNum * 4
    local partyMoney3 = floorNum * 3
    local partyMoney2 = floorNum * 2

    -- 분배 인원
    local splitCount
    if checkAllDistribute then
        splitCount = n
    else
        local beneficiaries = {}
        for _, item in pairs(items or {}) do
            local winner = GetLedgerWinnerForCount(item)
            if item.noBeneficiary ~= true and item.type == "CREDIT" and winner ~= "" and item.cost and item.cost > 0 then
                beneficiaries[winner] = true
            end
        end
        local actualBeneficiaryCount = 0
        for _ in pairs(beneficiaries) do
            actualBeneficiaryCount = actualBeneficiaryCount + 1
        end
        splitCount = math.max(n - actualBeneficiaryCount, 1)
    end

    -- 정산 (genexport와 동일 포맷)
    table.insert(lines, "=========================")
    table.insert(lines, "아이템 : "    .. GetMoneyStringL(autoRevenue))
    table.insert(lines, "총수익 : +"   .. GetMoneyStringL(manualRevenue))
    table.insert(lines, "총지출 : -"   .. GetMoneyStringL(expense))
    table.insert(lines, "총분배금 : "  .. GetMoneyStringL(distribution))
    if not checkf and #beneficiaryNames > 0 then
        table.insert(lines, "득자 : " .. table.concat(beneficiaryNames, ", ") .. ",  (총 " .. #beneficiaryNames .. "명)")
    end
    table.insert(lines, "분배 인원 설정 : " .. splitCount)
    table.insert(lines, "개인당 : " .. GetMoneyStringL(floorNum))
    table.insert(lines, "파티당 : " .. GetMoneyStringL(partyMoney))
    table.insert(lines, "4명당 : "  .. GetMoneyStringL(partyMoney4))
    table.insert(lines, "3명당 : "  .. GetMoneyStringL(partyMoney3))
    table.insert(lines, "2명당 : "  .. GetMoneyStringL(partyMoney2))

    local localText = table.concat(lines, CRLF)
    if channel == "LOCAL" then
        return localText
    end

    local SendToChat
    if channel == "PRINT" then
        SendToChat = function(msg) print(msg) end
    else
        SendToChat = function(msg)
            if IsInRaid() then
                SendChatMessage(msg, "RAID")
            else
                ADDONSELF.print(msg)
            end
        end
    end

    -- borrow from [details] — 모든 메시지를 타이머로 순차 전송
    for i = 1, #lines do
        local message = lines[i]
        C_Timer.NewTimer(i * 200 / 1000, function()
            SendToChat(message)
        end)
    end
end

