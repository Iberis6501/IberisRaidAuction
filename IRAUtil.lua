local _, ADDONSELF = ...

local L = ADDONSELF.L

ADDONSELF.print = function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|CFFFF0000<|r|CFFFFD100경매 장부|r|CFFFF0000>|r"..(msg or "nil"))
end

local function GetMoneyStringL(money, separateThousands)
	local goldString, silverString, copperString;
	local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD));
	local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER);
	local copper = mod(money, COPPER_PER_SILVER);

    if (separateThousands) then
        goldString = FormatLargeNumber(gold)..GOLD_AMOUNT_SYMBOL;
    else
        goldString = gold..GOLD_AMOUNT_SYMBOL;
    end
    silverString = silver..SILVER_AMOUNT_SYMBOL;
    copperString = copper..COPPER_AMOUNT_SYMBOL;

	local moneyString = "";
	local separator = "";
	if ( gold > 0 ) then
		moneyString = goldString;
		separator = " ";
	end
	if ( silver > 0 ) then
		moneyString = moneyString..separator..silverString;
		separator = " ";
	end
	if ( copper > 0 or moneyString == "" ) then
		moneyString = moneyString..separator..copperString;
	end
	
--	moneyString = money/10000.0;

	return moneyString;
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
            if item.type == "CREDIT" and item.noBeneficiary ~= true and item.beneficiary and item.beneficiary ~= "" and item.cost and item.cost > 0 then
                beneficiaries[item.beneficiary] = true
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
            c = math.floor( c * 10000 )
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
                c = math.floor( c * 10000 )
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
        avg = math.floor( avg )

        -- 절삭 단위 적용
        local roundingLevel = (ADDONSELF and ADDONSELF.gui and ADDONSELF.gui.roundingLevel) or 2

        if roundingLevel == 0 then
            avg = math.floor(avg/10000)*10000  -- 골드 단위 절삭
        elseif roundingLevel == 1 then
            avg = math.floor(avg/100)*100      -- 실버 단위 절삭
        -- else: 절삭 없음 (기존 avg 값 유지)
        end
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

    local l = item["beneficiary"] or L["[Unknown]"]
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

ADDONSELF.genexport = function(items, n, checkf, checkAllDistribute)

    -- checkAllDistribute 파라미터 타입 확인 및 정규화
    -- 숫자가 전달되면 true로 처리 (GUI에서 splitNumber를 전달하는 경우)
    if type(checkAllDistribute) == "number" then
        checkAllDistribute = true
    end

    -- 외부에서 전달받은 checkAllDistribute 값으로 임시 설정
    local originalCheckAllDistribute = nil
    if checkAllDistribute ~= nil and ADDONSELF and ADDONSELF.db and ADDONSELF.db.GetConfigOrDefault and ADDONSELF.db.SetConfig then
        originalCheckAllDistribute = ADDONSELF.db:GetConfigOrDefault("checkAllDistribute", true)
        ADDONSELF.db:SetConfig("checkAllDistribute", checkAllDistribute)
    end

    -- 실제 분배 인원 계산 (calcavg와 동일한 로직)
    local splitCount = n
    if not checkAllDistribute then
        -- 실제 득자 수 계산 (CREDIT 아이템만)
        local beneficiaries = {}
        for _, item in pairs(items or {}) do
            -- CREDIT 아이템만 득자 계산에서 제외
            if item.type == "CREDIT" and item.noBeneficiary ~= true and item.beneficiary and item.beneficiary ~= "" and item.cost and item.cost > 0 then
                beneficiaries[item.beneficiary] = true
            end
        end
        local actualBeneficiaryCount = 0
        for _ in pairs(beneficiaries) do
            actualBeneficiaryCount = actualBeneficiaryCount + 1
        end
        splitCount = math.max(n - actualBeneficiaryCount, 0)
    end

    local s = "Raid Ledger BR" .. CRLF
    s = s .. CRLF

    -- 텍스트 도출에서도 roundingLevel을 적용해야 함 (genreport와 동일)
    local roundingLevel = (ADDONSELF and ADDONSELF.gui and ADDONSELF.gui.roundingLevel) or 2

    -----------------------------------

    -- NOTE: noBeneficiary 필터링을 제거하고 원본 items 사용
    -- 수익 계산에는 모든 CREDIT 아이템이 포함되어야 함
    -- noBeneficiary는 분산 계산(divisor)에만 영향을 줌
    local filteredItems = items

    local lines = {}
    local grp = {}
    local looternames = L["득자 : "]
    local lootercount = 0
    local s = ""  -- s 변수 초기화

    -- 전달받은 checkAllDistribute 파라미터 사용 (GUI와 동일하게)
  -- checkAllDistribute 파라미터가 nil이면 checkf 기반으로 결정
  if checkAllDistribute == nil then
        checkAllDistribute = not checkf  -- checkf가 true이면 득자 제외 모드
  end
    local profit, avg, revenue, expense  = ADDONSELF.calcavg(filteredItems, n,
        function(item, c)
            -- 아이템 목록은 나중에 구성 - 여기서는 grp만 채움
            if item.noBeneficiary ~= true then
                -- DEBIT 아이템의 경우 빈 문자열을 그대로 사용
                local l = item["beneficiary"] or ""
                if l == "" and item.type ~= "DEBIT" then
                    l = L["[Unknown]"]
                end
                local i = item["detail"]["item"] or ""
                local d = item["detail"]["displayname"] or ""
                if not grp[l] then
                    grp[l] = {
                        ["cost"] = 0,
                        ["items"] = {},
                        ["citems"] = {},
                        ["compensation"] = 0,
                    }
                end

                grp[l]["cost"] = grp[l]["cost"] + c

                -- 아이템 정보 저장
                if c > 0 then  -- 0골드 아이템은 제외
                    -- DEBIT 아이템은 items 배열에 추가하지 않음 (수익 항목만 추가)
                    if item.type ~= "DEBIT" then
                        local itemName = ""
                        if i and i ~= "" then
                            if not GetItemInfoFromHyperlink(i) then
                                itemName = d
                            else
                                itemName = i
                            end
                        else
                            itemName = d or L["Other"]
                        end

                        table.insert(grp[l]["items"], itemName .. " " .. GetMoneyStringL(c))
                    end
                end

                    end
        end,
        function(item, c)
            -- ondebit callback
            -- DEBIT 아이템의 경우 빈 문자열을 그대로 사용하고, 다른 경우에만 L["[Unknown]"] 사용
            local l = item["beneficiary"] or ""
            if l == "" and item.type ~= "DEBIT" then
                l = L["[Unknown]"]
            end
            local d = item["detail"]["displayname"] or ""
            local ct = item["costtype"] or "GOLD"

  
            if not grp[l] then
                grp[l] = {
                    ["cost"] = 0,
                    ["items"] = {},
                    ["citems"] = {},
                    ["compensation"] = 0,
                }
            end

            -- local s = string.format(L["Debit"] .. ": [%s] -> [%s] %s", d, l, GetMoneyStringL(c))
            local s = d .. " " .. GetMoneyStringL(c)

            if ct == "PROFIT_PERCENT" then
                s = s .. " (" .. (item["cost"] or 0) .. " % " .. L["Net Profit"] .. ")"
            elseif ct == "MUL_AVG" then
                s = s .. " (" .. (item["cost"] or 0) .. " * " .. L["Per Member credit"] .. ")"
            end

            grp[l]["compensation"] = grp[l]["compensation"] + c
            table.insert( grp[l]["citems"], s)  -- DEBIT 아이템 추가
          end,
        checkAllDistribute
    )

    local looter = {}
    local compensation = {}

    for l, k in pairs(grp) do
        -- 수익 항목이 있는 경우만 looter 배열에 추가 (DEBIT 항목만 있는 경우 제외)
        if k["items"] and #k["items"] > 0 then
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

            table.insert(looter, {
                ["cost"] = k["cost"],
                ["items"] = k["items"],
                ["looter"] = looterName,
            })
        end
    end

    table.sort(looter, function(a, b)
        return a["cost"] > b["cost"]
    end)

    -- compensation 배열 채우기 (지출 항목용)
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

        if k["compensation"] > 0 then
            table.insert(compensation, {
                ["beneficiary"] = looterName,
                ["compensation"] = k["compensation"],
                ["citems"] = k["citems"]
            })
        end
    end

    table.sort(compensation, function(a, b)
        return a["compensation"] > b["compensation"]
    end)

      if #looter > 0 then
        local c = math.min(#looter, 40)
        local c_final = 0

    
        while c > 0 and looter[c]["cost"] == 0 do
            c = c - 1
        end

        for i = 1, c do
            if looter[i] and looter[i]["looter"] ~= "" then
                -- 텍스트 모드에서도 색상 유지 (사용자 요청)
                local displayName = looter[i]["looter"]
                    looternames = looternames .. displayName .. ", "
                c_final = c_final + 1
            end
        end
        looternames = looternames .. " (총 " .. c_final .. "명)"
          else
            end

    -- 전체출력과 동일한 형식으로 수익/지출/득자 목록 구성
    local lines = {}
    local outputText = ""

    -- 수익 목록 (득자 정보)
    if not checkf then
        outputText = outputText .. "+++ " .. L["Credit"] .. " +++" .. CRLF
        local count = 0

        for i, entry in ipairs(looter) do
            if entry.cost > 0 then
                count = count + 1
                local name = entry.looter
                outputText = outputText .. string.format("%d. %s [%s]" .. CRLF, count, name, GetMoneyStringL(entry.cost))

                for idx, item in ipairs(entry.items) do
                    outputText = outputText .. string.format("... %d. %s %s" .. CRLF, idx, name, item)
                end

                -- 클래스 색상이 적용된 이름에서 순수 이름 추출
                local cleanName = entry.looter
                -- WoW의 모든 이스케이프 시퀀스 제거
                cleanName = cleanName:gsub("|c[%x%x%x%x%x%x%x%x%x]+", "")  -- |c로 시작하는 모든 색상 코드
                cleanName = cleanName:gsub("|cff[%x%x%x%x%x%x%x]+", "")  -- |cff로 시작하는 모든 색상 코드
                cleanName = cleanName:gsub("|r", "")  -- 색상 리셋
                cleanName = cleanName:gsub("|T[^|]*|t", "")  -- 텍스처 아이콘
                cleanName = cleanName:gsub("|H[^|]*|h?([^|]*)|h?", "%1")  -- 하이퍼링크
                cleanName = cleanName:gsub("|n", "")  -- 개행 문자
                cleanName = cleanName:gsub("|x%x%x%x%x", "")  -- 다른 이스케이프 문자
            end
        end

        -- 무득 아이템 추가 출력 (수익 목록에 포함되지만 득자 계산에서 제외)
        local noBeneficiaryItems = {}
        for _, item in pairs(items or {}) do
            if item.type == "CREDIT" and item.noBeneficiary == true and item.cost and item.cost > 0 then
                local i = item["detail"]["item"] or ""
                local l = item["beneficiary"] or L["[Unknown]"]
                local actualCost = item.costcache or (item.cost * 10000)

                table.insert(noBeneficiaryItems, {
                    itemLink = i,
                    beneficiary = l,
                    cost = actualCost
                })
            end
        end

        if #noBeneficiaryItems > 0 then
            outputText = outputText .. CRLF
            outputText = outputText .. "+++ 무득 아이템 +++" .. CRLF
            for i, item in ipairs(noBeneficiaryItems) do
                outputText = outputText .. string.format("%d. %s [%s] %s" .. CRLF, i, item.beneficiary, item.itemLink, GetMoneyStringL(item.cost))
            end
            outputText = outputText .. CRLF
        end
    end

    -- 지출 목록 출력
    if expense > 0 and #compensation > 0 then
        outputText = outputText .. CRLF
        outputText = outputText .. "+++ " .. L["Debit"] .. " +++" .. CRLF

        for i, l in ipairs(compensation) do
            local beneficiaryName = l.beneficiary or L["[Unknown]"]
            outputText = outputText .. string.format("%d. %s [%s]" .. CRLF, i, beneficiaryName, GetMoneyStringL(l.compensation))

            for idx, item in ipairs(l.citems) do
                outputText = outputText .. string.format("... %d. %s %s" .. CRLF, idx, beneficiaryName, item)
            end
        end
        outputText = outputText .. CRLF
    end

    ------------------------------------
    -- 텍스트 도출에서도 roundingLevel을 적용해야 함 (genreport와 동일)
    local roundingLevel = (ADDONSELF and ADDONSELF.gui and ADDONSELF.gui.roundingLevel) or 2

    local floorNum = 0
    if roundingLevel == 0 then
        floorNum = math.floor(avg/10000)*10000  -- 골드 단위 절삭
    elseif roundingLevel == 1 then
        floorNum = math.floor(avg/100)*100      -- 실버 단위 절삭
    else
        floorNum = avg                          -- 절삭 없음
    end

    
    local partyMoney = floorNum*5
    local partyMoney4 = floorNum*4
    local partyMoney3 = floorNum*3
    local bossMoney = profit - floorNum*splitCount

    revenue = GetMoneyStringL(revenue)
    expense = GetMoneyStringL(expense)
    profit = GetMoneyStringL(profit)
    floorNum = GetMoneyStringL(floorNum)
    partyMoney = GetMoneyStringL(partyMoney)
    partyMoney4 = GetMoneyStringL(partyMoney4)
    partyMoney3 = GetMoneyStringL(partyMoney3)
    bossMoney = GetMoneyStringL(bossMoney)

    -- 수익/지출 정보와 득자 목록 합치기
    s = outputText .. CRLF
    s = s .. L["총수익"] .. ":" .. revenue .. CRLF
    s = s .. L["총지출"] .. ":" .. expense .. CRLF
    s = s .. L["최종 수입"] .. ":" .. profit .. CRLF
    s = s .. CRLF

    s = s .. looternames .. CRLF

    s = s .. L["분배 인원 설정"] .. ":" .. splitCount .. CRLF
    s = s .. L["개인당 골드"] .. ": " .. floorNum .. CRLF
    s = s .. L["파티당 골드"] .. ": " .. partyMoney .. "/5 " .. partyMoney4 .. "/4 " .. partyMoney3 .. "/3" .. CRLF
    s = s .. "남는 금액:" .. bossMoney .. CRLF

    -- 원래 checkAllDistribute 값 복원
    if originalCheckAllDistribute ~= nil and ADDONSELF and ADDONSELF.db and ADDONSELF.db.SetConfig then
        ADDONSELF.db:SetConfig("checkAllDistribute", originalCheckAllDistribute)
    end

    return s
end

ADDONSELF.genreport = function(items, n, channel, checkf)

    -- 파티나 공격대 상태 확인
    if channel == "RAID" and not IsInRaid() and not IsInGroup() then
        ADDONSELF.print("공격대 또는 파티 상태에서만 출력 가능합니다.")
        return
    end

    -- NOTE: noBeneficiary 필터링을 제거하고 원본 items 사용
    -- 수익 계산에는 모든 CREDIT 아이템이 포함되어야 함
    -- noBeneficiary는 분산 계산(divisor)에만 영향을 줌
    local filteredItems = items

    -- UI에서 DEBIT 아이템의 최신 beneficiary 정보 가져와서 items 배열 업데이트
    local GUI = ADDONSELF.gui
    if GUI and GUI.lootLogFrame then
        -- ScrollingTable에서 현재 데이터 가져오기
        local uiData = GUI.lootLogFrame.data

        for idx, entry in ipairs(uiData or {}) do
        
            if entry.cols then
                            end

            -- 여러 방법으로 DEBIT 아이템 식별 시도
            local isDebitItem = false

            -- 방법 1: entry.type 필드 확인
            if entry.type == "DEBIT" then
                isDebitItem = true
            end

            -- 방법 2: realItemIdx로 필터링된Items 확인
            if entry.realItemIdx and filteredItems[entry.realItemIdx] and filteredItems[entry.realItemIdx].type == "DEBIT" then
                isDebitItem = true
            end

            -- 방법 3: 첫 번째 열에 "보상:" 포함 확인
            if entry.cols and entry.cols[1] and entry.cols[1].value and type(entry.cols[1].value) == "string" and string.find(entry.cols[1].value, "보상:") then
                isDebitItem = true
            end

            if isDebitItem and entry.cols and entry.cols[2] then
                -- 데이터베이스 아이템 찾기
                local dbItem = nil

                -- 방법 1: realItemIdx 사용
                if entry.realItemIdx and filteredItems[entry.realItemIdx] then
                    dbItem = filteredItems[entry.realItemIdx]
                end

                -- 방법 2: displayname으로 찾기
                if not dbItem and entry.cols[1] and entry.cols[1].value then
                    for _, item in ipairs(filteredItems) do
                        if item.type == "DEBIT" and item.detail and item.detail.displayname == entry.cols[1].value then
                            dbItem = item
                            break
                        end
                    end
                end

                -- ScrollingTable에서 entry.beneficiary 직접 읽기 (데이터 동기화 후)
                local currentUIValue = entry.beneficiary or entry.cols[2].value or ""

                -- 빈 문자열이면 L["[Unknown]"]으로 변환하지 않고 그대로 사용
                if currentUIValue == "" then
                    currentUIValue = ""
                end

                
                if dbItem then
                    local oldBeneficiary = dbItem.beneficiary
                    dbItem.beneficiary = currentUIValue
                                    else
                                    end
            end
        end
    else
            end

    local lines = {}
    local grp = {}

    
    -- UI의 체크박스 상태를 읽어서 분배 방식 결정
    local checkAllDistribute = true  -- 기본값: 모두 분배
    local checkbox = _G.IberisRaidAuctionCheckAllDistributeButton
    if checkbox then
        local rawValue = checkbox:GetChecked()
        checkAllDistribute = (rawValue == true) or (rawValue == 1)
    end

    
    -- oncredit callback 함수 정의
    local oncreditCallback = function(item, c)
        -- oncredit callback
                if c == 0 then
                        return
        end  -- 골드 0인 아이템은 무시

        -- 무득 아이템은 득자 그룹에 추가하지 않음 (득자 계산에서 제외)
        -- nil인 경우도 false로 처리 (기존 데이터 호환)
                if item.noBeneficiary ~= true then
            -- DEBIT 아이템은 여기 오지 않지만, 일관성을 위해 동일한 로직 적용
            local l = item["beneficiary"] or ""
            if l == "" and item.type ~= "DEBIT" then
                l = L["[Unknown]"]
            end
            local i = item["detail"]["item"] or ""
            local d = item["detail"]["displayname"] or ""

            
            if not grp[l] then
                grp[l] = {
                    ["cost"] = 0,
                    ["items"] = {},
                    ["citems"] = {},
                    ["compensation"] = 0,
                }
            end

            grp[l]["cost"] = grp[l]["cost"] + c

            if not GetItemInfoFromHyperlink(i) then
                i = d
            end
            -- CREDIT 아이템만 items 배열에 추가 (수익 항목만)
            if item.type == "CREDIT" then
                table.insert( grp[l]["items"], i .. " " .. GetMoneyStringL(c))
            end
        end
    end

    local profit, avg, revenue, expense  = ADDONSELF.calcavg(filteredItems, n,
        oncreditCallback,
        function(item, c)
            -- ondebit callback
                        -- DEBIT 아이템의 경우 빈 문자열을 그대로 사용하고, 다른 경우에만 L["[Unknown]"] 사용
            local l = item["beneficiary"] or ""
            if l == "" and item.type ~= "DEBIT" then
                l = L["[Unknown]"]
            end
            local d = item["detail"]["displayname"] or ""
            local ct = item["costtype"] or "GOLD"


            
            if not grp[l] then
                grp[l] = {
                    ["cost"] = 0,
                    ["items"] = {},
                    ["citems"] = {},
                    ["compensation"] = 0,
                }
            end

            -- local s = string.format(L["Debit"] .. ": [%s] -> [%s] %s", d, l, GetMoneyStringL(c))
            local s = d .. " " .. GetMoneyStringL(c)

            if ct == "PROFIT_PERCENT" then
                s = s .. " (" .. (item["cost"] or 0) .. " % " .. L["Net Profit"] .. ")"
            elseif ct == "MUL_AVG" then
                s = s .. " (" .. (item["cost"] or 0) .. " * " .. L["Per Member credit"] .. ")"
            end

            grp[l]["compensation"] = grp[l]["compensation"] + c
            table.insert( grp[l]["citems"], s)  -- DEBIT 아이템 추가
                    end,
        checkAllDistribute
    )


    local looter = {}
    local compensation = {}

for l, k in pairs(grp) do
    -- 클래스 정보와 색상 처리는 한 번만 수행
    local classFilename
    local name = Ambiguate(l, "short")  -- 서버명 제거

    for i = 1, MAX_RAID_MEMBERS do
        local raidName = GetRaidRosterInfo(i)
        if raidName and Ambiguate(raidName, "short") == name then
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

    -- 수익 항목이 있는 경우만 looter 배열에 추가 (DEBIT 항목만 있는 경우 제외)
    if k["items"] and #k["items"] > 0 then
        table.insert(looter, {
            ["cost"] = k["cost"],
            ["items"] = k["items"],
            ["looter"] = looterName,
        })
    end

    -- compensation 배열 채우기 (지출 항목용)
    if k["compensation"] > 0 then
                table.insert(compensation, {
            ["beneficiary"] = looterName,
            ["compensation"] = k["compensation"],
            ["citems"] = k["citems"]
        })
    end
end

    table.sort( looter, function(a, b)
        return a["cost"] > b["cost"]
    end)

    table.sort( compensation, function(a, b)
        return a["compensation"] > b["compensation"]
    end)

    -- 득자 이름 목록 초기화 (전체출력용)
    local beneficiaryNames = {}

    -- 요약 모드가 아닐 경우에만 득자 목록 출력
    if not checkf then
                table.insert(lines, "+++ " .. L["Credit"] .. " +++")
        local count = 0

        for i, entry in ipairs(looter) do
            if entry.cost > 0 then
                count = count + 1
                local name = entry.looter
                table.insert(lines, string.format("%d. %s [%s]", count, name, GetMoneyStringL(entry.cost)))

                for idx, item in ipairs(entry.items) do
                    table.insert(lines, string.format("... %d. %s %s", idx, name, item))
                end

                -- 클래스 색상이 적용된 이름에서 순수 이름 추출
                local cleanName = entry.looter
                -- WoW의 모든 이스케이프 시퀀스 제거
                cleanName = cleanName:gsub("|c[%x%x%x%x%x%x%x%x%x]+", "")  -- |c로 시작하는 모든 색상 코드
                cleanName = cleanName:gsub("|cff[%x%x%x%x%x%x%x]+", "")  -- |cff로 시작하는 모든 색상 코드
                cleanName = cleanName:gsub("|r", "")  -- 색상 리셋
                cleanName = cleanName:gsub("|T[^|]*|t", "")  -- 텍스처 아이콘
                cleanName = cleanName:gsub("|H[^|]*|h?([^|]*)|h?", "%1")  -- 하이퍼링크
                cleanName = cleanName:gsub("|n", "")  -- 개행 문자
                cleanName = cleanName:gsub("|x%x%x%x%x", "")  -- 다른 이스케이프 문자
                table.insert(beneficiaryNames, cleanName)
            end
        end
    end

    -- 무득 아이템 추가 출력 (수익 목록에 포함되지만 득자 계산에서 제외)
    local noBeneficiaryItems = {}
    for _, item in pairs(items or {}) do
        if item.type == "CREDIT" and item.noBeneficiary == true and item.cost and item.cost > 0 then
            local i = item["detail"]["item"] or ""
            local d = item["detail"]["displayname"] or ""
            local l = item["beneficiary"] or L["[Unknown]"]

            -- calcavg에서 계산된 실제 코스트 사용
            local actualCost = item.costcache or (item.cost * 10000)

            table.insert(noBeneficiaryItems, {
                itemLink = i,  -- 원본 아이템 링크 보관
                displayName = d,
                beneficiary = l,
                cost = actualCost  -- calcavg에서 계산된 실제 코스트
            })
        end
    end

    -- 무득 아이템이 있으면 별도로 출력 (원래 형식처럼 링크 포함)
    if #noBeneficiaryItems > 0 then
        table.insert(lines, "+++ 무득 아이템 +++")
        for i, item in ipairs(noBeneficiaryItems) do
            -- 득자이름 [아이템링크] 금액 형식으로 출력
            table.insert(lines, string.format("%d. %s [%s] %s", i, item.beneficiary, item.itemLink, GetMoneyStringL(item.cost)))
        end
    end

    -- 간단한 득자 목록 추가 (5명씩 그룹화) - 요약 모드가 아닐 때만
    if not checkf and #beneficiaryNames > 0 then
        local header = "득자: "
        local footer = " (총 " .. #beneficiaryNames .. "명)"
        local namesPerLine = 5

        -- 5명씩 그룹으로 나누어 출력
        for i = 1, #beneficiaryNames, namesPerLine do
            local lineNames = {}
            local endIndex = math.min(i + namesPerLine - 1, #beneficiaryNames)

            -- 현재 그룹의 이름들 수집
            for j = i, endIndex do
                table.insert(lineNames, beneficiaryNames[j])
            end

            local namesString = table.concat(lineNames, ", ")

            -- 마지막 그룹인 경우 footer 추가
            if endIndex == #beneficiaryNames then
                local line = header .. namesString .. footer
                table.insert(lines, line)
            else
                local line = header .. namesString
                table.insert(lines, line)
            end
        end
    end


    if expense > 0 then
        table.insert(lines, "+++ " .. L["Debit"] .. " +++")
        local citemShort = ""
        local c = math.min( #compensation, 80)

        -- local waterMoney = 0  -- 물의 정기 기능 사용 안 함

        cutF = 0
        for i = 1, c do
            local l = compensation[i]
            local beneficiaryName = l["beneficiary"] or L["[Unknown]"]
                           table.insert(lines, i .. ". " .. L["Debit"] .. " " .. beneficiaryName .. " [" .. GetMoneyStringL(l["compensation"]) .. "]")
            for _, item in pairs(l["citems"]) do
                -- table.insert(lines, beneficiaryName .. " " .. item)  -- 중복 출력 방지를 위해 주석 처리
                -- 물의 정기 기능 사용 안 함 - 모든 아이템을 일반 처리로 변경
	            citemShort = citemShort .. item .. ", "
                cutF = cutF + 1
	       -- if string.find(item, "물의 정기") ~= nil then
                -- waterMoney = waterMoney + tonumber(GetMoneyStringL(l["compensation"]))
	       -- else
	            -- citemShort = citemShort .. item .. ", "
                -- cutF = cutF + 1
	       -- end

	    if math.fmod(cutF, 4) == 0 then
	        table.insert(lines, citemShort)
	        citemShort = ""
   	    end
            end
        end
        table.insert(lines, citemShort)
        -- if waterMoney ~= 0 then
	    --     table.insert(lines, "물의 정기 " .. waterMoney)
        -- end
    end

    revenue = GetMoneyStringL(revenue)
    expense = GetMoneyStringL(expense)
    profit = GetMoneyStringL(profit)

--    local floorNum = math.floor(avg/10000)*10000
    local floorNum = 0
    local roundingLevel = (ADDONSELF and ADDONSELF.gui and ADDONSELF.gui.roundingLevel) or 2

    if roundingLevel == 0 then
        floorNum = math.floor(avg/10000)*10000  -- 골드 단위 절삭
    elseif roundingLevel == 1 then
        floorNum = math.floor(avg/100)*100      -- 실버 단위 절삭
    else
        floorNum = avg                          -- 절삭 없음
    end

    local partyMoney = floorNum*5
    local partyMoney4 = floorNum*4
    local partyMoney3 = floorNum*3
    floorNum = GetMoneyStringL(floorNum)
    partyMoney = GetMoneyStringL(partyMoney)
    partyMoney4 = GetMoneyStringL(partyMoney4)
    partyMoney3 = GetMoneyStringL(partyMoney3)

    local myStatus = -1
    if IsInRaid() then    
        local pName = UnitName("player")
        for i = 1, MAX_RAID_MEMBERS do
            local name, rank = GetRaidRosterInfo(i)
            if name == pName then
    	     myStatus = rank
	     break
            end
        end
    end

    -- 간단한 득자 목록 생성
    local beneficiaryList = {}

    for i, item in ipairs(filteredItems) do
        -- CREDIT 아이템이고 비용이 0보다 커야 함 (filteredItems는 이미 noBeneficiary 필터링됨)
        if item["type"] == "CREDIT" and item["cost"] and item["cost"] > 0 then
            local name = item["beneficiary"] or L["[Unknown]"]
            local shortName = Ambiguate(name, "short")

            -- 클래스 색상 정보 가져오기
            local classFilename
            for i = 1, MAX_RAID_MEMBERS do
                local raidName = GetRaidRosterInfo(i)
                if raidName and Ambiguate(raidName, "short") == shortName then
                    local guid = UnitGUID("raid"..i)
                    if guid then
                        local _, _, _, _, _, class = GetPlayerInfoByGUID(guid)
                        classFilename = class
                    end
                    break
                end
            end

            local displayName = name
            if classFilename and RAID_CLASS_COLORS[classFilename] then
                local color = RAID_CLASS_COLORS[classFilename].colorStr
                displayName = "|c" .. color .. name .. "|r"
            end

            table.insert(beneficiaryList, {
                name = displayName,
                cost = item["cost"]
            })
        end
    end

    -- 비용 기준 정렬 및 중복 제거
    local seenNames = {}
    local uniqueBeneficiaries = {}
    for _, beneficiary in ipairs(beneficiaryList) do
        if not seenNames[beneficiary.name] and beneficiary.cost > 0 then
            table.insert(uniqueBeneficiaries, beneficiary)
            seenNames[beneficiary.name] = true
        end
    end

    table.sort(uniqueBeneficiaries, function(a, b)
        return a.cost > b.cost
    end)

  
    -- calcavg에서 이미 계산된 분배 인원 사용
    local splitCount
    if checkAllDistribute then
        splitCount = n
    else
        -- 실제 득자 수 계산
        local beneficiaries = {}
        for _, item in pairs(items or {}) do
            if item.noBeneficiary ~= true and item.type == "CREDIT" and item.beneficiary and item.beneficiary ~= "" and item.cost and item.cost > 0 then
                beneficiaries[item.beneficiary] = true
            end
        end
        local actualBeneficiaryCount = 0
        for _ in pairs(beneficiaries) do
            actualBeneficiaryCount = actualBeneficiaryCount + 1
        end
        splitCount = math.max(n - actualBeneficiaryCount, 1)
    end

    -- 요약 정보 추가
    if checkf then
        -- 요약 모드: 득자 정보 제외한 간단한 요약
        table.insert(lines, "=== 장부 요약 ===")
        table.insert(lines, L["Revenue"] .. ": " .. revenue .. " - " .. expense .. " = " .. profit)
        table.insert(lines, L["Split into"]  .. ": " .. splitCount)
        table.insert(lines, L["Per Member credit"] .. ": " .. floorNum )
        table.insert(lines, L["Per Party credit"] .. ": " .. partyMoney .. "/5 " .. partyMoney4 .. "/4 " .. partyMoney3 .. "/3")
    else
        -- 전체 모드: 기존 방식
        table.insert(lines, L["Revenue"] .. ": " .. revenue .. " - " .. expense .. " = " .. profit)
        table.insert(lines, L["Split into"]  .. ": " .. splitCount)
        table.insert(lines, L["Per Member credit"] .. ": " .. floorNum )
        table.insert(lines, L["Per Party credit"] .. ": " .. partyMoney .. "/5 " .. partyMoney4 .. "/4 " .. partyMoney3 .. "/3")
    end

    local SendToChat = function(msg)
        if not IsInRaid() then
            if IsInGroup() then
                SendChatMessage(msg, "PARTY")
            else
                SendChatMessage(msg, "SAY")
            end
        else
            SendChatMessage(msg, "RAID")
        end
    end

    -- borrow from [details]
    -- 모든 메시지를 타이머로 순차 전송
    for i = 1, #lines do
        local message = lines[i]
        local timer = C_Timer.NewTimer(i * 200 / 1000, function()
            SendToChat(message)
        end)
    end

    -- if myStatus > 0 then    
    --     SendChatMessage(L["Per Member credit"] .. ": " .. floorNum, "RAID_WARNING")
    --     SendChatMessage(L["Per Party credit"] .. ": " .. partyMoney, "RAID_WARNING")
    -- end

end
