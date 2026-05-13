-- IRATest.lua
-- 테스트모드 버튼 + 카라잔 TBC 25개 가상 데이터 — RaidBook 패턴 차용
-- (Apache 2.0, originally adapted from RaidBook RBGui.lua testModeButton)
local _, ADDONSELF = ...

local Test = {}
ADDONSELF.test = Test

local Database = ADDONSELF.db
local L        = ADDONSELF.L

-- 카라잔(TBC 2.0/2.1) 실제 드랍 기준 25개
-- 도안 4 (전용 득자 2명) + 보스/잡템 Epic 17 (일반 득자 3명) + 마력추출 인계 2 + 결과물 2
local TEST_ITEMS = {
    -- 도안 4종
    { id = 23809, name = "Schematic: Stabilized Eternium Scope", cost = 8000, isRecipe = true },
    { id = 22559, name = "Formula: Enchant Weapon - Mongoose",   cost = 8000, isRecipe = true },
    { id = 21903, name = "Pattern: Soulcloth Shoulders",         cost = 8000, isRecipe = true },
    { id = 21904, name = "Pattern: Soulcloth Vest",              cost = 8000, isRecipe = true },
    -- 보스/잡템 Epic 17종
    { id = 28509, name = "Worgen Claw Necklace",                 cost = 15000 },
    { id = 28570, name = "Shadow-Cloak of Dalaran",              cost = 26000 },
    { id = 28528, name = "Moroes' Lucky Pocket Watch",           cost = 30000 },
    { id = 28524, name = "Emerald Ripper",                       cost = 28000 },
    { id = 28572, name = "Blade of the Unrequited",              cost = 25000 },
    { id = 28573, name = "Despair",                              cost = 24000 },
    { id = 28633, name = "Staff of Infinite Mysteries",          cost = 65000 },
    { id = 28653, name = "Shadowvine Cloak of Infusion",         cost = 31000 },
    { id = 28785, name = "The Lightning Capacitor",              cost = 54000 },
    { id = 28674, name = "Saberclaw Talisman",                   cost = 18000 },
    { id = 28734, name = "Jewel of Infinite Possibilities",      cost = 42000 },
    { id = 28762, name = "Adornment of Stolen Souls",            cost = 20000 },
    { id = 28770, name = "Nathrezim Mindblade",                  cost = 32000 },
    { id = 28771, name = "Light's Justice",                      cost = 75000 },
    { id = 28602, name = "Robe of the Elder Scribes",            cost = 42000 },
    { id = 28603, name = "Talisman of Nightbane",                cost = 36000 },
    { id = 28604, name = "Nightstaff of the Everliving",         cost = 26000 },
    -- 마력추출 인계 2 (수령자: *마력추출*)
    { id = 28601, name = "Chestguard of the Conniver",           cost = 0, isDisenchantHandoff = true },
    { id = 28600, name = "Stonebough Jerkin",                    cost = 0, isDisenchantHandoff = true },
    -- 마력추출 결과물 2줄 (수령자 명시)
    { id = 22450, name = "Void Crystal", cost = 0, count = 2, isDisenchantResult = true, beneficiary = "마부테스트A" },
    { id = 22450, name = "Void Crystal", cost = 0, count = 1, isDisenchantResult = true, beneficiary = "마부테스트B" },
}

local RECIPE_NAMES = { "도안전용A", "도안전용B" }
local NORMAL_NAMES = { "전사테스트", "법사테스트", "힐러테스트" }

function Test:HasTestData()
    local ledger = Database and Database:GetCurrentLedger()
    if not ledger or not ledger.items then return false end
    for _, item in ipairs(ledger.items) do
        if item.detail and item.detail.isTestMode then return true end
    end
    return false
end

function Test:Clear()
    local ledger = Database and Database:GetCurrentLedger()
    if not ledger or not ledger.items then return end
    for i = #ledger.items, 1, -1 do
        local it = ledger.items[i]
        if it.detail and it.detail.isTestMode then
            table.remove(ledger.items, i)
        end
    end
    if Database.OnLedgerItemsChange then Database:OnLedgerItemsChange() end
    print("|cFF9966FF[거래기록]|r 테스트 데이터 제거")
end

function Test:Generate()
    if not Database then return end

    for i, t in ipairs(TEST_ITEMS) do
        local _, itemLink = GetItemInfo(t.id)
        if not itemLink then
            itemLink = "|cffffffff|Hitem:" .. t.id .. "::::::::60:::::|h[" .. t.name .. "]|h|r"
        end

        local pool = t.isRecipe and RECIPE_NAMES or NORMAL_NAMES
        local beneficiary = pool[((i - 1) % #pool) + 1]
        if t.isDisenchantResult then
            beneficiary = tostring(t.beneficiary or "마부테스트")
        elseif t.isDisenchantHandoff then
            beneficiary = "*마력추출*"
        end

        local detail = {
            item             = itemLink,
            type             = "ITEM",
            count            = t.count or 1,
            reliableItemID   = t.id,
            displayname      = t.name,
            isTestMode       = true,
        }
        Database:AddEntry("CREDIT", detail, beneficiary, t.cost)
        -- 도안/마부식은 통상 무득(noBeneficiary) 처리
        if t.isRecipe then
            local ledger = Database:GetCurrentLedger()
            if Database.SetItemNoBeneficiary then
                Database:SetItemNoBeneficiary(#ledger.items, true)
            else
                ledger.items[#ledger.items].noBeneficiary = true
            end
        end
    end

    if Database.OnLedgerItemsChange then Database:OnLedgerItemsChange() end
    print("|cFF9966FF[테스트모드]|r 카라잔 테마 샘플 25개가 추가되었습니다.")
end

-- ====== 메인 창에 테스트모드 버튼 추가 (RaidBook 패턴) ======
local function buildButton()
    local GUI = ADDONSELF.gui
    if not GUI or not GUI.mainframe then return false end
    if GUI.testModeButton then return true end

    local f = GUI.mainframe
    local b = CreateFrame("Button", nil, f, "BackdropTemplate")
    b:SetWidth(80); b:SetHeight(22)
    -- TOPRIGHT 기준 X(-5)+최소화(-29~-53) 안쪽 위치, 가려지지 않게
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -60, -7)
    b:SetFrameStrata("HIGH")
    b:SetText("테스트모드")
    b:SetNormalFontObject("GameFontNormal")
    b:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    b:SetBackdropColor(0.2, 0.1, 0.3, 0.9)
    b:SetBackdropBorderColor(0.6, 0.3, 0.8, 1.0)
    local fs = b:GetFontString()
    if fs then fs:SetTextColor(0.9, 0.7, 1) end

    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.15, 0.45, 0.95)
        self:SetBackdropBorderColor(0.8, 0.5, 1.0, 1.0)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("테스트 아이템 25개 추가")
        GameTooltip:AddLine("카라잔(TBC 2.0/2.1) 도안 4, 보스 에픽 17, 마력추출 인계 2, 결과물 2.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.1, 0.3, 0.9)
        self:SetBackdropBorderColor(0.6, 0.3, 0.8, 1.0)
        GameTooltip:Hide()
    end)
    b:SetScript("OnMouseDown", function(self) self:SetBackdropColor(0.12, 0.06, 0.2, 1.0) end)
    b:SetScript("OnMouseUp",   function(self) self:SetBackdropColor(0.3, 0.15, 0.45, 0.95) end)
    b:SetScript("OnClick", function()
        local ok, err = xpcall(function() Test:Generate() end, function(e) return tostring(e or "?") end)
        if not ok then
            print("|cFFFF4444[테스트모드 오류]|r " .. tostring(err))
        end
    end)
    GUI.testModeButton = b
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if buildButton() then return end
    -- mainframe이 lazy 생성될 수 있어 1초 후 재시도
    C_Timer.After(1, function()
        if buildButton() then return end
        C_Timer.After(2, buildButton)
    end)
end)
