-- IRAOptions.lua
-- Blizzard 인터페이스 옵션 패널 (메뉴 → 설정 → 애드온 → IberisRaidAuction)
-- + 미니맵 우클릭으로도 같은 패널 오픈 (ADDONSELF.options:Toggle)
local _, ADDONSELF = ...

local Options = {}
ADDONSELF.options = Options

local Database = ADDONSELF.db

local panel
local categoryID

local function build()
    panel = CreateFrame("Frame", "IberisRaidAuctionOptionsPanel", UIParent)
    panel.name = "IberisRaidAuction"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff91d7f2IberisRaidAuction|r")

    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(560); sub:SetJustifyH("LEFT")
    sub:SetText("공격대 GDKP 골드 분배 장부 — 빠른 설정")

    local y = -54

    -- 체크박스 헬퍼: scope = "char" | "global"
    local function makeCheck(text, key, default, scope, onClickExtra)
        local c = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        c:SetPoint("TOPLEFT", 16, y)
        c.Text:SetText(text)
        local getter = (scope == "global") and "GetGlobalConfigOrDefault" or "GetConfigOrDefault"
        local setter = (scope == "global") and "SetGlobalConfig"          or "SetConfig"
        c:SetScript("OnShow", function(self)
            self:SetChecked(Database[getter](Database, key, default))
        end)
        c:SetScript("OnClick", function(self)
            local on = self:GetChecked() and true or false
            Database[setter](Database, key, on)
            if onClickExtra then onClickExtra(on) end
        end)
        y = y - 28
        return c
    end

    makeCheck("미니맵 아이콘 표시", "minimapicon", true, "char", function(on)
        local icon = LibStub and LibStub("LibDBIcon-1.0", true)
        local minimapDB = Database:GetConfig("minimapicons")
        if icon and minimapDB then
            minimapDB.hide = not on
            if on then icon:Show("IberisRaidAuction") else icon:Hide("IberisRaidAuction") end
        end
    end)

    makeCheck("던전 입장 시 자동 정리", "autoClearOnDungeonEnter", true, "global")

    -- autoaddloot 드롭다운
    y = y - 12
    local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", 16, y)
    lbl:SetText("자동 전리품 기록")
    y = y - 22

    local MODES = {
        [0] = "항상 (어느 그룹이든)",
        [1] = "공대일 때만",
        [2] = "꺼짐",
    }

    local dd = CreateFrame("Frame", "IberisRaidAuctionOptAutoLootDD", panel, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", 0, y)
    UIDropDownMenu_SetWidth(dd, 220)
    UIDropDownMenu_Initialize(dd, function(self, level)
        for v = 0, 2 do
            local info = UIDropDownMenu_CreateInfo()
            info.text = MODES[v]
            info.func = function()
                Database:SetConfig("autoaddloot", v)
                if ADDONSELF.cli then ADDONSELF.cli.AutoAddLoot = v end
                UIDropDownMenu_SetText(dd, MODES[v])
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dd:SetScript("OnShow", function()
        local cur = Database:GetConfigOrDefault("autoaddloot", 1)
        UIDropDownMenu_SetText(dd, MODES[cur] or MODES[2])
    end)

    -- 안내
    y = y - 60
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, y)
    hint:SetWidth(560); hint:SetJustifyH("LEFT")
    hint:SetText("|cff909090세부 설정은 메인 창 하단 컨트롤 또는 슬래시 명령(|cffffd200/ira help|cff909090)을 사용하세요.|r")
end

local function register()
    if categoryID then return end -- 이미 등록됨
    if not panel then build() end

    if Settings and Settings.RegisterAddOnCategory and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(cat)
        categoryID = cat:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        categoryID = panel.name -- 옛 API 식별자
    end
end

function Options:Show()
    register()
    if Settings and Settings.OpenToCategory and type(categoryID) == "number" then
        Settings.OpenToCategory(categoryID)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel) -- 옛 클라 더블콜 워크어라운드
    end
end

function Options:Hide()
    -- Blizzard Settings는 별도 닫기 API가 없음 — 사용자가 X로 닫음. 호환 stub.
end

function Options:Toggle()
    -- 토글보다는 매번 Show (Settings 패널은 매번 새로 열어도 무해)
    Options:Show()
end

-- ADDON_LOADED 시점에 카테고리 등록 (Settings 인터페이스 인식 위해 미리)
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "IberisRaidAuction" then register() end
end)
