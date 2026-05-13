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

-- ScrollBar (UIPanelScrollFrameTemplate / FauxScrollFrame 의 자식 슬라이더)
function Theme:ApplyScrollBar(bar)
    if not bar then return end
    -- 위/아래 버튼 텍스처 제거 후 대체
    local up   = _G[bar:GetName() and (bar:GetName() .. "ScrollUpButton")]
    local down = _G[bar:GetName() and (bar:GetName() .. "ScrollDownButton")]
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

    -- 위/아래 버튼은 숨김 (미니멀)
    if up then up:Hide(); up:SetWidth(0.001) end
    if down then down:Hide(); down:SetWidth(0.001) end
end
