local _, ADDONSELF = ...

local L = ADDONSELF.L
local GUI = ADDONSELF.gui
local Database = ADDONSELF.db
local Print = ADDONSELF.print
local deformat = ADDONSELF.deformat
local RegEvent = ADDONSELF.regevent

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

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)

    if GUI.mainframe:IsShown() and IsControlKeyDown() and button == "LeftButton" then
        local bag = self:GetParent():GetID()
        local slot = self:GetID()
        local itemLink = C_Container.GetContainerItemLink(bag, slot)

        if itemLink then
            Print(L["Item added"] .. " " .. itemLink)
            Database:AddLoot(itemLink, 1, "", 0, true)
            -- GUI 업데이트는 AddLoot -> AddEntry -> OnLedgerItemsChange 콜백을 통해 자동으로 처리됨
        end
    end
end)

 
local ls_targetName = ""
local ll_targetMoney = 0
local playerItem = ""
local targetItem = ""


local AUTOADDLOOT_TYPE_ALL = 0
-- local AUTOADDLOOT_TYPE_PARTY = 1
local AUTOADDLOOT_TYPE_RAID = 1
local AUTOADDLOOT_TYPE_DISABLE = 2

-- AutoAddLoot is now accessed through ADDONSELF.cli.AutoAddLoot for GUI synchronization
local AutoAddLoot = AUTOADDLOOT_TYPE_RAID

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
    -- if code reaches this point, we should have a valid looter and a valid itemLink
    -- print(itemLink)
    for _ = 1, itemCount do
        Database:AddLoot(itemLink, 1, playerName, 0);
    end
end)

RegEvent("ADDON_LOADED", function()
    AutoAddLoot = Database:GetConfigOrDefault("autoaddloot", AUTOADDLOOT_TYPE_RAID)
    ADDONSELF.cli.AutoAddLoot = AutoAddLoot

    local ldb = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)

    if not ldb or not icon then
        -- LibDataBroker 또는 LibDBIcon이 없으면 미니맵 아이콘 생성 건너뛰기
        return
    end

    -- 미니맵 아이콘 데이터베이스 설정
    local minimapDB = Database:GetConfig("minimapicons")
    if not minimapDB then
        minimapDB = {
            hide = false  -- 기본값은 표시
        }
        Database:SetConfig("minimapicons", minimapDB)
    end

    -- 사용자 설정에 따라 표시/숨김 설정 (true일 때 숨김)
    minimapDB.hide = not Database:GetConfigOrDefault("minimapicon", true)

    -- 누적 수익 — tooltip 과 동일한 calcavg 결과 사용 (단위 환산 일치)
    local function formatRevenueText()
        local ledger = Database and Database:GetCurrentLedger()
        if not ledger or not ledger.items or not ADDONSELF.calcavg then
            return GetMoneyString and GetMoneyString(0) or "0"
        end
        local profit = ADDONSELF.calcavg(ledger.items, 1, nil, nil, true)
        if GetMoneyString then return GetMoneyString(profit or 0) end
        return tostring(profit or 0)
    end

    -- LibDataBroker 데이터 객체 생성
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
                if ADDONSELF.options and ADDONSELF.options.Toggle then
                    ADDONSELF.options:Toggle()
                else
                    print("|cff91d7f2[IberisRaidAuction]|r 설정창 모듈 로드 실패")
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
                        manualRevenue = manualRevenue + item.cost * 10000
                    end
                end
                local autoRevenue  = (revenue or 0) - manualRevenue
                local distribution = profit or 0
                local fmt = ADDONSELF.GetMoneyStringL or GetMoneyString
                tooltip:AddDoubleLine("아이템",   fmt(autoRevenue,   true), 1,1,1, 1,1,1)
                tooltip:AddDoubleLine("총수익",   "+" .. fmt(manualRevenue, true), 1,1,1, 0.6,1,0.6)
                tooltip:AddDoubleLine("총지출",   "-" .. fmt(expense or 0,  true), 1,1,1, 1,0.7,0.7)
                tooltip:AddDoubleLine("총분배금", fmt(distribution,  true), 1,1,1, 1,0.82,0)
                tooltip:AddDoubleLine("인당",    fmt(avg or 0,      true), 1,1,1, 0.6,0.85,1)
            end
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffff00좌클릭|r 경매창", 1, 1, 1)
            tooltip:AddLine("|cffffff00우클릭|r 설정창", 1, 1, 1)
        end,
    })

    -- LibDBIcon에 등록
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
end)



----------------------------------------------------------------

-- 골드만 선택
local function truncGold(str)
  local ll_len = string.len(str)
  local ll_end = ll_len - 4
  local ll_gold = tonumber(string.sub(str, 1, ll_end))
  if ll_gold == nil then
    return 0
  else
    return ll_gold
  end
end

-- 골드확인
local function TS_UpdateMoney()
  ll_targetMoney = truncGold(GetTargetTradeMoney())
end

-- 거래물품의 정보 처리
function TS_UpdateItemInfo(id, unit, item)
  local funcInfo = getglobal("GetTrade"..unit.."ItemInfo")
  local funcLink = getglobal("GetTrade"..unit.."ItemLink")

  local name, texture, numItems, quality, isUsable, enchantment

  name, texture, numItems, quality, enchantment = funcInfo(id)

  if(not name) then
--   item = nil
    return
  end

   playerItem = funcLink(id)

end


RegEvent("UI_INFO_MESSAGE", function(messageType, message)

	local errorName, soundKitID, voiceID = GetGameMessageInfo(messageType);

	if ( errorName=="ERR_TRADE_COMPLETE") then

	    -- 여기서 애돈에 기록	
	    if (playerItem~=nil) and (GUI:GetCheckTradeButton()) and (ll_targetMoney~=0)	then    
	        Database:AddLoot(playerItem, 1, ls_targetName, ll_targetMoney, 1);
		SendChatMessage("경매 알림 : " .. ls_targetName .. "님이 " .. playerItem .. "을 " .. ll_targetMoney .. "골에 구매하였습니다.", "RAID")
	    end

	    playerItem=nil;
	    ls_targetName="";
	    ll_targetMoney=0;
	elseif ( errorName=="ERR_TRADE_CANCELLED") then

    	    playerItem=nil;
	    ls_targetName="";
	    ll_targetMoney=0;
	end
end)
RegEvent("TRADE_SHOW", function()
    ls_targetName = GetUnitName("NPC") 
end)
RegEvent("TRADE_ACCEPT_UPDATE", function()
    playerItem=nil
    local cant
    for cant = 6, 1, -1 do
        TS_UpdateItemInfo(cant, "Player", playerItem)
    end
    if(playerItem~=nil) then
        TS_UpdateMoney()
    end
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

    if not cmd then
        GUI:Show()

        Print(L["Control + 아이템 클릭은 수익으로 추가"])
        Print(L["Right click to remove record"])
        ShowCurrentAutoLootType()
        Print("[".. L["/ira"] .. " toggle] " .. L["toggle Auto recording on/off"])
        Print("[".. L["/ira"] .. " rounding] Change rounding unit (none → silver → gold)")
        Print("[".. L["/ira"] .. " countdown] Configure countdown messages")
        Print("[".. L["/ira"] .. " autoclear] Auto clear on dungeon enter (on/off)")
        Print("[".. L["/ira"] .. " scale] Adjust UI scale (0.7-1.5)")
    elseif cmd == "new" then
        db:NewLedger()
    elseif cmd == "test" then
        if ADDONSELF.test and ADDONSELF.test.Generate then
            ADDONSELF.test:Generate()
        else
            Print("test module unavailable")
        end
    elseif cmd == "clear" then

    elseif cmd == "countdown" and not what then
        -- /ira countdown만 입력했을 때 카운트다운 도움말 표시
        local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
            count = "--- %d",
            closed = "--- BIDDING CLOSED",
            resume = "--- NEW BID. RESUMING"
        })

        Print("=== Countdown Messages Configuration ===")
        Print(string.format("Count: %s", messages.count))
        Print(string.format("Closed: %s", messages.closed))
        Print(string.format("Resume: %s", messages.resume))
        Print("Usage:")
        Print("/ira countdown count <message> - Set countdown message (use %d for number)")
        Print("/ira countdown closed <message> - Set bidding closed message")
        Print("/ira countdown resume <message> - Set resume message")
        Print("/ira countdown reset - Reset to default values")

    elseif cmd == "toggle" then
        AutoAddLoot = (AutoAddLoot + 1) % 3
        Database:SetConfig("autoaddloot", AutoAddLoot)
        ShowCurrentAutoLootType()

        -- GUI 드롭다운 업데이트 (GUI는 DB에서 직접 읽음)
        local GUI = ADDONSELF and ADDONSELF.gui or nil
        if GUI and GUI.UpdateAutoLootDropdown then
            GUI:UpdateAutoLootDropdown()
        end
    elseif cmd == "rounding" then
        local currentRounding = Database:GetConfigOrDefault("roundinglevel", 2)
        local newRounding = (currentRounding + 1) % 3
        Database:SetConfig("roundinglevel", newRounding)

        -- 현재 절삭 상태 표시
        if newRounding == 0 then
            Print("Rounding unit: Set to gold")
        elseif newRounding == 1 then
            Print("Rounding unit: Set to silver")
        else
            Print("Rounding unit: Set to none")
        end

        -- GUI 드롭다운 업데이트
        local GUI = ADDONSELF and ADDONSELF.gui or nil
        if GUI and GUI.UpdateRoundingDropdown then
            GUI:UpdateRoundingDropdown()
        end
    elseif cmd == "countdown" then
        if what == "reset" then
            -- 기본값으로 초기화
            Database:SetGlobalConfig("countdownmessages", {
                count = "--- %d",
                closed = "--- BIDDING CLOSED",
                resume = "--- NEW BID. RESUMING"
            })
            Print("Countdown messages have been reset to default values.")

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
                    closed = "--- BIDDING CLOSED",
                    resume = "--- NEW BID. RESUMING"
                })

                messages[what] = message
                Database:SetGlobalConfig("countdownmessages", messages)

                if what == "count" then
                    Print(string.format("Countdown message set to: '%s'", message))
                elseif what == "closed" then
                    Print(string.format("Bidding closed message set to: '%s'", message))
                elseif what == "resume" then
                    Print(string.format("Resume message set to: '%s'", message))
                end

            else
                Print("Error: Please enter a message.")
                Print(string.format("Usage: /ira countdown %s <message>", what))
            end
        else
            Print("Error: Unknown subcommand.")
            Print("Type '/ira countdown' to see usage.")
        end
    elseif cmd == "autoclear" then
        -- 자동 초기화 설정
        if not what or what == "" then
            -- 현재 설정 표시
            local enabled = Database:GetGlobalConfigOrDefault("autoClearOnDungeonEnter", true)
            Print("Auto clear on dungeon enter: " .. (enabled and "ON" or "OFF"))
            Print("Usage: /ira autoclear <on|off>")
        else
            local enabled = what:lower() == "on" or what:lower() == "true" or what:lower() == "1"
            Database:SetGlobalConfig("autoClearOnDungeonEnter", enabled)
            Print("Auto clear on dungeon enter: " .. (enabled and "ENABLED" or "DISABLED"))
        end
    elseif cmd == "scale" then
        -- UI 스케일 조절
        if not what or what == "" then
            -- 현재 스케일 표시
            local currentScale = Database:GetGlobalConfigOrDefault("uiScale", 1.0)
            Print("UI Scale: " .. math.floor(currentScale * 100) .. "%")
            Print("Usage: /ira scale <0.7-1.5>")
        else
            local scale = tonumber(what)
            if scale and scale >= 0.7 and scale <= 1.5 then
                Database:SetGlobalConfig("uiScale", scale)
                if GUI and GUI.mainframe then
                    GUI.mainframe:SetScale(scale)
                    Print("UI Scale set to " .. math.floor(scale * 100) .. "%")
                end
            else
                Print("Invalid scale value. Please use a number between 0.7 and 1.5")
            end
        end
    else
        local _, itemLink = GetItemInfo(strtrim(msg))
        if itemLink then
            Database:AddLoot(itemLink, 1, "", 0, true)
            Print(L["Item added"] .. " " .. itemLink)
        end
    end

end
SLASH_IBERISRAIDAUCTION1 = "/ira"
SLASH_IBERISRAIDAUCTION2 = "/iberisraidauction"
SlashCmdList["IBERISRAIDAUCTION"] = HandleCommand

-- 스케일 조절 명령어는 HandleCommand에 이미 포함됨
