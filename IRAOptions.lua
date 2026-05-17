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

    -- ===== 자동 캡처 블랙리스트 (RaidLedgerBR 패턴, 입력/목록 분리) =====
    y = y - 50

    local blHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blHeader:SetPoint("TOPLEFT", 16, y)
    blHeader:SetText("자동 캡처 차단 목록")
    y = y - 6

    local blHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blHint:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", 0, -2)
    blHint:SetWidth(560); blHint:SetJustifyH("LEFT")
    blHint:SetText("|cff909090아이템 이름 부분일치로 차단. 기본값: 폭풍우 요새 켈타스 P4 무기/쐐기 8종.|r")
    y = y - 24

    -- (1) 새 항목 추가 입력
    local addLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLbl:SetPoint("TOPLEFT", 22, y)
    addLbl:SetText("새 항목 추가:")
    y = y - 22

    local addEdit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    addEdit:SetPoint("TOPLEFT", 28, y)
    addEdit:SetSize(380, 24)
    addEdit:SetAutoFocus(false)
    addEdit:SetMaxLetters(120)
    addEdit:SetScript("OnEscapePressed", addEdit.ClearFocus)

    local addBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addBtn:SetPoint("LEFT", addEdit, "RIGHT", 8, 0)
    addBtn:SetSize(60, 22)
    addBtn:SetText("추가")
    y = y - 36

    -- (2) 등록 항목 리스트 (스크롤 가능)
    local listLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listLbl:SetPoint("TOPLEFT", 22, y)
    listLbl:SetText("등록된 아이템:")
    y = y - 20

    local listBg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", 28, y)
    listBg:SetSize(450, 180)
    listBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, tile = false,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listBg:SetBackdropColor(0, 0, 0, 0.45)
    listBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    y = y - 188

    -- 행 풀
    local rows = {}
    local ROW_H = 22

    local function ensureRow(i)
        local row = rows[i]
        if row then return row end
        row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(400, ROW_H)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * (ROW_H + 1))

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetTextColor(1, 1, 1)

        row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.del:SetSize(22, 20)
        row.del:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.del:SetText("X")

        rows[i] = row
        return row
    end

    local function rebuildList()
        local list = Database:GetItemBlacklist()
        local items = {}
        for entry in pairs(list) do table.insert(items, entry) end
        table.sort(items)

        local count = #items
        scrollChild:SetHeight(math.max(1, count * (ROW_H + 1)))

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
                    rebuildList()
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
        rebuildList()
    end)
    addEdit:SetScript("OnEnterPressed", function(self)
        addBtn:Click()
        self:ClearFocus()
    end)

    -- (3) 기본값 복원 버튼
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 28, y)
    resetBtn:SetSize(110, 22)
    resetBtn:SetText("기본값 복원")
    resetBtn:SetScript("OnClick", function()
        IberisRaidAuctionGlobalConfig = IberisRaidAuctionGlobalConfig or {}
        IberisRaidAuctionGlobalConfig.itemBlacklist = nil
        Database:GetItemBlacklist()  -- 다시 호출하면 기본값 재주입됨
        rebuildList()
    end)
    y = y - 32

    panel:HookScript("OnShow", rebuildList)

    -- 안내
    y = y - 16
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
