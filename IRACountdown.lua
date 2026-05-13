-- IRACountdown.lua
-- RaidBook 패턴의 카운트다운 버튼 그룹 (자동 / ▶ / ●) — 메인창 좌하단
local _, ADDONSELF = ...

local Countdown = {}
ADDONSELF.countdown = Countdown

local Database = ADDONSELF.db

-- ====== state ======
local function GUI() return ADDONSELF.gui end
GUI().autoCountEnabled = true
GUI().countdownActive  = false
GUI().countdownTimer   = nil

-- ====== 메시지 템플릿 ======
local DEFAULTS = {
    count  = "--- %d",
    closed = "--- 입찰 마감 ---",
    resume = "--- 신규 입찰 ! 재개합니다 ---",
}
local function getMessages()
    local m = Database and Database.GetGlobalConfigOrDefault
        and Database:GetGlobalConfigOrDefault("countdownmessages", DEFAULTS) or DEFAULTS
    return {
        count  = m.count  or DEFAULTS.count,
        closed = m.closed or DEFAULTS.closed,
        resume = m.resume or DEFAULTS.resume,
    }
end

-- ====== 채널 결정 + 송출 ======
local function send(msg)
    if not msg or msg == "" then return end
    if IsInRaid() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        SendChatMessage(msg, "RAID_WARNING")
    elseif IsInGroup() then
        SendChatMessage(msg, "RAID")
    else
        SendChatMessage(msg, "SAY")
    end
end

-- ====== 카운트다운 동작 ======
local function stopAndResume()
    GUI().countdownActive = false
    if GUI().countdownTimer then GUI().countdownTimer:Cancel(); GUI().countdownTimer = nil end
    send(getMessages().resume)
end

local function startCountdown()
    if GUI().countdownActive then return end
    GUI().countdownActive = true
    GUI().currentCount    = 5
    local m = getMessages()
    send(string.format(m.count, GUI().currentCount))
    GUI().countdownTimer = C_Timer.NewTicker(1, function()
        GUI().currentCount = GUI().currentCount - 1
        if GUI().currentCount > 0 then
            send(string.format(m.count, GUI().currentCount))
        else
            send(m.closed)
            GUI().countdownActive = false
            if GUI().countdownTimer then GUI().countdownTimer:Cancel(); GUI().countdownTimer = nil end
        end
    end)
end

-- ====== 자동 모니터링 (한국 숫자 + 아라비아 숫자) ======
local autoFrame = CreateFrame("Frame")
local KOREAN_NUM = { "일","이","삼","사","오","육","칠","팔","구","십","백","천","만","억","원" }
local function hasNumber(msg)
    if not msg then return false end
    if msg:find("%d") then return true end
    for _, n in ipairs(KOREAN_NUM) do
        if msg:find(n) then return true end
    end
    return false
end

local function isOwnCountdownMsg(msg)
    local m = getMessages()
    if msg == m.closed or msg == m.resume then return true end
    -- "--- N" 같은 자체 카운트
    if msg:match("^%-%-%- %d+$") then return true end
    return false
end

autoFrame:SetScript("OnEvent", function(_, _, msg)
    if not GUI().countdownActive or not GUI().autoCountEnabled then return end
    if isOwnCountdownMsg(msg) then return end
    if hasNumber(msg) then stopAndResume() end
end)

local function updateAutoEvents()
    if GUI().autoCountEnabled then
        autoFrame:RegisterEvent("CHAT_MSG_RAID")
        autoFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
        autoFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
    else
        autoFrame:UnregisterAllEvents()
    end
end

-- ====== UI 빌드 ======
local function makeBtn(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(80, 50)
    b:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
    })
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER")
    b.txt = t
    return b
end

function Countdown:Build()
    local f = ADDONSELF.gui and ADDONSELF.gui.mainframe
    if not f or Countdown.autoBtn then return end

    -- 자동 토글 (정산라벨 -605, 2줄(28) 아래 + 14px 갭, 좌측 정렬)
    local autoBtn = makeBtn(f)
    autoBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -647)
    local function styleAuto()
        if GUI().autoCountEnabled then
            autoBtn:SetBackdropColor(0.05, 0.35, 0.05, 0.95)
            autoBtn:SetBackdropBorderColor(0.15, 0.7, 0.15, 1)
            autoBtn.txt:SetTextColor(0.1, 0.85, 0.1)
            autoBtn.txt:SetText("자동")
        else
            autoBtn:SetBackdropColor(0.12, 0.12, 0.15, 0.95)
            autoBtn:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
            autoBtn.txt:SetTextColor(0.5, 0.5, 0.5)
            autoBtn.txt:SetText("수동")
        end
    end
    styleAuto()
    autoBtn:SetScript("OnClick", function()
        GUI().autoCountEnabled = not GUI().autoCountEnabled
        updateAutoEvents()
        styleAuto()
    end)
    autoBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("자동 카운트다운 정지")
        GameTooltip:AddLine("활성화 시, 카운트다운 중 누군가 채팅에", 1,1,1, true)
        GameTooltip:AddLine("숫자(100, 백 등)를 포함한 메시지를 보내면", 1,1,1, true)
        GameTooltip:AddLine("자동으로 정지 후 재개 메시지를 전송합니다.", 1,1,1, true)
        GameTooltip:Show()
    end)
    autoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ▶ 카운트다운 시작
    local countBtn = makeBtn(f)
    countBtn:SetPoint("LEFT", autoBtn, "RIGHT", 5, 0)
    countBtn:SetBackdropColor(0.05, 0.25, 0.05, 0.95)
    countBtn:SetBackdropBorderColor(0.15, 0.5, 0.15, 1)
    countBtn.txt:SetTextColor(0.2, 0.9, 0.2)
    countBtn.txt:SetText("\226\150\182") -- ▶
    countBtn:SetScript("OnEnter", function(self)
        countBtn:SetBackdropColor(0.1, 0.4, 0.1, 0.95)
        countBtn:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
        countBtn.txt:SetTextColor(0.3, 1, 0.3)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("카운트다운 시작 (5>1)")
        GameTooltip:Show()
    end)
    countBtn:SetScript("OnLeave", function()
        countBtn:SetBackdropColor(0.05, 0.25, 0.05, 0.95)
        countBtn:SetBackdropBorderColor(0.15, 0.5, 0.15, 1)
        countBtn.txt:SetTextColor(0.2, 0.9, 0.2)
        GameTooltip:Hide()
    end)
    countBtn:SetScript("OnClick", startCountdown)

    -- ● 정지/재개
    local stopBtn = makeBtn(f)
    stopBtn:SetPoint("LEFT", countBtn, "RIGHT", 5, 0)
    stopBtn:SetBackdropColor(0.35, 0.05, 0.05, 0.95)
    stopBtn:SetBackdropBorderColor(0.6, 0.15, 0.15, 1)
    stopBtn.txt:SetTextColor(0.9, 0.2, 0.2)
    stopBtn.txt:SetText("\226\151\143") -- ●
    stopBtn:SetScript("OnEnter", function(self)
        stopBtn:SetBackdropColor(0.5, 0.1, 0.1, 0.95)
        stopBtn:SetBackdropBorderColor(1, 0.25, 0.25, 1)
        stopBtn.txt:SetTextColor(1, 0.3, 0.3)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("카운트다운 중지 및 재개")
        GameTooltip:Show()
    end)
    stopBtn:SetScript("OnLeave", function()
        stopBtn:SetBackdropColor(0.35, 0.05, 0.05, 0.95)
        stopBtn:SetBackdropBorderColor(0.6, 0.15, 0.15, 1)
        stopBtn.txt:SetTextColor(0.9, 0.2, 0.2)
        GameTooltip:Hide()
    end)
    stopBtn:SetScript("OnClick", stopAndResume)

    Countdown.autoBtn  = autoBtn
    Countdown.countBtn = countBtn
    Countdown.stopBtn  = stopBtn

    updateAutoEvents()
end

-- 메인 frame 준비된 후 빌드
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    local function try()
        local ok = pcall(function() Countdown:Build() end)
        return ok and Countdown.autoBtn ~= nil
    end
    if try() then return end
    C_Timer.After(1, function()
        if try() then return end
        C_Timer.After(2, try)
    end)
end)
