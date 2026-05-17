-- IRATheme.lua
-- B-1: LibSharedMedia 기반 테마. ElvUI 설치 시 ElvUI 미디어, 미설치면 클린 fallback.
local _, ADDONSELF = ...

local Theme = {}
ADDONSELF.theme = Theme

local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"

-- ============================================================
-- 미디어 lazy fetch (ElvUI 로드 후 LSM 등록 보장하기 위함)
-- ============================================================
local function fetchLSM(kind, preferred, fallback)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local v = LSM:Fetch(kind, preferred, true) -- noDefault=true: 등록 안 됐으면 nil
        if v and v ~= "" then return v end
    end
    return fallback
end

function Theme:GetBackground()
    if self._bg ~= nil then return self._bg end
    self._bg = fetchLSM("background", "ElvUI Norm", WHITE8X8)
    return self._bg
end

function Theme:GetBorder()
    if self._border ~= nil then return self._border end
    -- ElvUI 보더 우선, 없으면 1px 평면 (WHITE8X8을 edgeSize 1로)
    self._border = fetchLSM("border", "ElvUI Norm", WHITE8X8)
    return self._border
end

function Theme:GetStatusBar()
    if self._sb ~= nil then return self._sb end
    self._sb = fetchLSM("statusbar", "ElvUI Norm", WHITE8X8)
    return self._sb
end

function Theme:GetFont()
    if self._font ~= nil then return self._font end
    -- 한글 환경: 한글 글리프 있는 폰트 필요. ElvUI 한글 우선, 없으면 게임 기본
    self._font = fetchLSM("font", "Expressway", nil) -- ElvUI 기본 폰트 중 하나
    if not self._font then
        self._font = STANDARD_TEXT_FONT or "Fonts\\2002.TTF"
    end
    return self._font
end

-- ============================================================
-- 색상 팔레트 (ElvUI 디폴트 톤 흉내)
-- ============================================================
Theme.colors = {
    bg          = { 0.10, 0.10, 0.10, 0.85 }, -- 어두운 평면 백그라운드
    bgLight     = { 0.15, 0.15, 0.18, 0.90 }, -- 살짝 밝은 (버튼)
    bgHover     = { 0.22, 0.22, 0.28, 0.95 }, -- 호버
    bgPressed   = { 0.05, 0.05, 0.07, 1.00 }, -- 눌림
    border      = { 0.00, 0.00, 0.00, 1.00 }, -- 검정 1px
    borderLight = { 0.30, 0.30, 0.35, 1.00 }, -- 회색 (호버)
    text        = { 1.00, 1.00, 1.00, 1.00 }, -- 흰색
    textDim     = { 0.65, 0.65, 0.65, 1.00 }, -- 회색
    accent      = { 0.10, 0.50, 0.85, 1.00 }, -- 하늘색 강조
}

-- ============================================================
-- 백드롭 빌더
-- ============================================================
function Theme:Backdrop(opts)
    opts = opts or {}
    return {
        bgFile   = self:GetBackground(),
        edgeFile = self:GetBorder(),
        tile     = false,
        tileSize = 0,
        edgeSize = opts.edgeSize or 1,
        insets   = opts.insets or { left = 1, right = 1, top = 1, bottom = 1 },
    }
end

-- ============================================================
-- 위젯 적용 헬퍼 (필수: BackdropTemplate으로 만들어진 프레임)
-- ============================================================
function Theme:ApplyFrame(frame, opts)
    if not frame or not frame.SetBackdrop then return end
    opts = opts or {}
    frame:SetBackdrop(self:Backdrop({ edgeSize = opts.edgeSize or 1 }))
    local bg = opts.bgColor or self.colors.bg
    local bd = opts.borderColor or self.colors.border
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
end

function Theme:ApplyButton(btn, opts)
    if not btn or not btn.SetBackdrop then return end
    opts = opts or {}
    btn:SetBackdrop(self:Backdrop({ edgeSize = 1 }))
    local bg     = opts.bgColor     or self.colors.bgLight
    local bd     = opts.borderColor or self.colors.border
    local bgH    = opts.bgHover     or self.colors.bgHover
    local bdH    = opts.borderHover or self.colors.borderLight
    local bgP    = opts.bgPressed   or self.colors.bgPressed
    btn:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    btn:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])

    btn:HookScript("OnEnter", function(self)
        self:SetBackdropColor(bgH[1], bgH[2], bgH[3], bgH[4])
        self:SetBackdropBorderColor(bdH[1], bdH[2], bdH[3], bdH[4])
    end)
    btn:HookScript("OnLeave", function(self)
        self:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        self:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
    end)
    btn:HookScript("OnMouseDown", function(self)
        self:SetBackdropColor(bgP[1], bgP[2], bgP[3], bgP[4])
    end)
    btn:HookScript("OnMouseUp", function(self)
        self:SetBackdropColor(bgH[1], bgH[2], bgH[3], bgH[4])
    end)
end

-- InputBoxTemplate으로 만들어진 EditBox는 좌/우/중간 텍스처가 박혀있음.
-- 그것들을 비우고 백드롭으로 평면 처리.
function Theme:ApplyEditBox(edit)
    if not edit then return end
    -- InputBoxTemplate 텍스처 제거
    local left  = _G[edit:GetName() and (edit:GetName() .. "Left")]  or edit.Left
    local mid   = _G[edit:GetName() and (edit:GetName() .. "Middle")] or edit.Middle
    local right = _G[edit:GetName() and (edit:GetName() .. "Right")] or edit.Right
    -- 자식 region 순회로 안전하게 텍스처 제거
    for i = 1, edit:GetNumRegions() do
        local r = select(i, edit:GetRegions())
        if r and r:GetObjectType() == "Texture" then
            r:SetTexture(nil)
            r:Hide()
        end
    end

    -- 백드롭 입히려면 BackdropTemplate 필요. EditBox는 기본 그게 없을 수 있음.
    -- Mixin 시도 (10.x+) 또는 wrapper 프레임으로 감싸는 대신, BackdropTemplateMixin 적용
    if BackdropTemplateMixin and not edit.SetBackdrop then
        Mixin(edit, BackdropTemplateMixin)
        edit:HookScript("OnSizeChanged", edit.OnBackdropSizeChanged)
    end

    if edit.SetBackdrop then
        edit:SetBackdrop(self:Backdrop({ edgeSize = 1 }))
        local bg = self.colors.bg
        local bd = self.colors.border
        edit:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        edit:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])

        local accent = self.colors.accent
        edit:HookScript("OnEditFocusGained", function(self)
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], accent[4])
        end)
        edit:HookScript("OnEditFocusLost", function(self)
            self:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
        end)
    end

    edit:SetTextInsets(4, 4, 0, 0)
end

-- AutoCompleteEditBoxTemplate 호환 외형 적용.
-- EditBox의 자체 region(텍스처)으로 외형 처리 → 형제 Frame 안 쓰고, HookScript 안 걸어도
-- EditBox가 Hide되면 텍스처도 자동으로 같이 사라짐 (region 시각성은 부모 프레임에 종속).
-- AutoComplete 스크립트 흐름(OnTextChanged/OnEditFocusGained/OnEditFocusLost)에 일절 손대지 않음.
function Theme:ApplyAutoCompleteEditBox(edit)
    if not edit then return end
    if edit._iuiACThemed then return end
    edit._iuiACThemed = true

    -- InputBoxTemplate 텍스처 제거 (시각만 평면화)
    for i = 1, edit:GetNumRegions() do
        local r = select(i, edit:GetRegions())
        if r and r:GetObjectType() == "Texture" then
            r:SetTexture(nil)
            r:Hide()
        end
    end

    -- 배경: BACKGROUND 레이어 → 텍스트보다 아래 그려짐. EditBox region 이라 hide 자동 추적.
    -- LEFT 는 cellFrame(parent) 에 clamp → textBox가 -X offset으로 옆 셀 침범해도 외형은 셀 안에만.
    local parent = edit:GetParent()
    local bg = edit:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("LEFT", parent, "LEFT", 0, 0)
    bg:SetPoint("RIGHT", edit, "RIGHT", 0, 0)
    bg:SetPoint("TOP", edit, "TOP", 0, 0)
    bg:SetPoint("BOTTOM", edit, "BOTTOM", 0, 0)
    bg:SetColorTexture(0.02, 0.02, 0.03, 0.98)
    edit._iuiBg = bg

    -- 보더 4면: 1px 텍스처 (배경과 동일 clamp 규칙)
    local bdc = self.colors.border
    local function newBord()
        local t = edit:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(bdc[1], bdc[2], bdc[3], bdc[4])
        return t
    end
    local top, btm, lft, rgt = newBord(), newBord(), newBord(), newBord()
    top:SetPoint("LEFT", parent, "LEFT", 0, 0)
    top:SetPoint("RIGHT", edit, "RIGHT", 0, 0)
    top:SetPoint("TOP", edit, "TOP", 0, 0)
    top:SetHeight(1)
    btm:SetPoint("LEFT", parent, "LEFT", 0, 0)
    btm:SetPoint("RIGHT", edit, "RIGHT", 0, 0)
    btm:SetPoint("BOTTOM", edit, "BOTTOM", 0, 0)
    btm:SetHeight(1)
    lft:SetPoint("LEFT", parent, "LEFT", 0, 0)
    lft:SetPoint("TOP", edit, "TOP", 0, 0)
    lft:SetPoint("BOTTOM", edit, "BOTTOM", 0, 0)
    lft:SetWidth(1)
    rgt:SetPoint("TOP", edit, "TOP", 0, 0)
    rgt:SetPoint("BOTTOM", edit, "BOTTOM", 0, 0)
    rgt:SetPoint("RIGHT", edit, "RIGHT", 0, 0)
    rgt:SetWidth(1)
    edit._iuiBorders = { top, btm, lft, rgt }

    edit:SetTextInsets(4, 4, 0, 0)
end

-- ScrollBar 양 끝 ▲▼ 버튼: ElvUI 풍 평면 + 화살표 글리프
local function styleArrowBtn(btn, dir)
    if not btn or btn._iuiArrow then return end
    btn:Show()
    btn:SetSize(10, 12)
    -- 기본 4 텍스처(Normal/Pushed/Disabled/Highlight)를 평면 컬러로 교체
    local function paint(tex, r, g, b, a)
        if not tex then return end
        tex:SetTexture(WHITE8X8)
        tex:SetAllPoints(btn)
        tex:SetVertexColor(r, g, b, a)
    end
    paint(btn:GetNormalTexture(),     0.10, 0.10, 0.12, 0.90)
    paint(btn:GetPushedTexture(),     0.05, 0.05, 0.07, 1.00)
    paint(btn:GetDisabledTexture(),   0.10, 0.10, 0.12, 0.50)
    paint(btn:GetHighlightTexture(),  0.20, 0.20, 0.25, 0.60)
    -- 화살표 글리프 ▲ / ▼
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(dir == "up" and "\226\150\178" or "\226\150\188") -- ▲ / ▼
    fs:SetTextColor(0.7, 0.7, 0.75)
    btn._iuiArrow = fs
end

-- ScrollBar (UIPanelScrollFrameTemplate / FauxScrollFrame 의 자식 슬라이더)
function Theme:ApplyScrollBar(bar)
    if not bar then return end
    local thumb = bar.GetThumbTexture and bar:GetThumbTexture() or nil

    bar:SetWidth(10)

    -- 트랙 백그라운드
    if not bar._track then
        local track = bar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints(bar)
        track:SetTexture(WHITE8X8)
        track:SetVertexColor(0.05, 0.05, 0.05, 0.7)
        bar._track = track
    end

    -- 썸 (드래그 손잡이)
    if thumb then
        thumb:SetTexture(WHITE8X8)
        thumb:SetVertexColor(0.4, 0.4, 0.45, 0.95)
        thumb:SetSize(8, 18)
    end

    -- ▲▼ 버튼 (ElvUI 풍): retail attribute 우선, 글로벌 네이밍 fallback, 마지막으로 children 순회
    local up   = bar.ScrollUpButton   or _G[(bar:GetName() or "") .. "ScrollUpButton"]
    local down = bar.ScrollDownButton or _G[(bar:GetName() or "") .. "ScrollDownButton"]
    if not up or not down then
        for _, child in ipairs({ bar:GetChildren() }) do
            if child.GetObjectType and child:GetObjectType() == "Button" then
                local n = child:GetName() or ""
                if not up   and n:find("Up")   then up   = child end
                if not down and n:find("Down") then down = child end
            end
        end
    end
    styleArrowBtn(up,   "up")
    styleArrowBtn(down, "down")
end
