-- IRACountdown.lua
-- RaidBook RBGui.lua "메인 창 카운트다운 버튼들" 블록을 그대로 차용.
-- (Apache 2.0, adapted from RaidBook RBGui.lua 1710-1939)
-- 차이점: 위치/텍스트/색상만 IberisRaidAuction UX 에 맞게 변경. timer/송출/이벤트 로직은 동일.
local _, ADDONSELF = ...

local Countdown = {}
ADDONSELF.countdown = Countdown

local Database = ADDONSELF.db

local function GUI() return ADDONSELF.gui end

local function makeBtn(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(80, 50)
    local Theme = ADDONSELF.theme
    if Theme and Theme.Backdrop then
        b:SetBackdrop(Theme:Backdrop({ edgeSize = 1 }))
    else
        b:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER")
    b.txt = t
    return b
end

function Countdown:Build()
    local f = ADDONSELF.gui and ADDONSELF.gui.mainframe
    if not f or Countdown.autoBtn then return end

    GUI().autoCountEnabled = true

    -- ====== RaidBook 원본 로직 ======
    local function stopAndResume()
        if GUI().countdownActive then
            GUI().countdownActive = false
            if GUI().countdownTimer then
                GUI().countdownTimer = nil
            end
            local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                count = "--- %d",
                closed = "--- 입찰 마감 ---",
                resume = "--- 신규 입찰 ! 재개합니다 ---"
            })
            SendChatMessage(messages.resume, "RAID_WARNING")
        end
    end

    local numberPattern = "%d+"
    local koreanNumbers = { "일", "이", "삼", "사", "오", "육", "칠", "팔", "구", "십",
        "백", "천", "만", "억", "원" }

    local function msgContainsNumber(msg)
        if msg:match(numberPattern) then return true end
        for _, kn in ipairs(koreanNumbers) do
            if msg:find(kn, 1, true) then return true end
        end
        return false
    end

    local function isCountdownMessage(msg)
        local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
            count = "--- %d",
            closed = "--- 입찰 마감 ---",
            resume = "--- 신규 입찰 ! 재개합니다 ---"
        })
        local countEsc = messages.count:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%d", "%%d+")
        if msg:match("^" .. countEsc .. "$") then return true end
        if msg == messages.closed then return true end
        if msg == messages.resume then return true end
        return false
    end

    local autoCountFrame = CreateFrame("Frame")
    autoCountFrame:SetScript("OnEvent", function(_, _, msg, sender)
        if not GUI().autoCountEnabled then return end
        if not GUI().countdownActive then return end
        if isCountdownMessage(msg) then return end
        if msgContainsNumber(msg) then
            stopAndResume()
        end
    end)

    -- ====== UI: 거래기록 확인 줄(TOPRIGHT -13, -524, h=28 → 끝 -552) 밑 24px ======
    local autoBtn  = makeBtn(f)
    local countBtn = makeBtn(f)
    local stopBtn  = makeBtn(f)

    stopBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -13, -608)
    countBtn:SetPoint("RIGHT", stopBtn, "LEFT", -5, 0)
    autoBtn:SetPoint("RIGHT", countBtn, "LEFT", -5, 0)

    Countdown.autoBtn  = autoBtn
    Countdown.countBtn = countBtn
    Countdown.stopBtn  = stopBtn

    -- ====== 자동 버튼 (활성: 보라 / 비활성: 회색) ======
    local function updateAutoBtnStyle()
        if GUI().autoCountEnabled then
            autoBtn:SetBackdropColor(0.20, 0.10, 0.30, 0.95)
            autoBtn:SetBackdropBorderColor(0.60, 0.30, 0.80, 1)
            autoBtn.txt:SetTextColor(0.85, 0.55, 1.0)
            autoBtn.txt:SetText("자동")
            autoCountFrame:RegisterEvent("CHAT_MSG_RAID")
            autoCountFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
            autoCountFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
        else
            autoBtn:SetBackdropColor(0.12, 0.12, 0.15, 0.95)
            autoBtn:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
            autoBtn.txt:SetTextColor(0.5, 0.5, 0.5)
            autoBtn.txt:SetText("수동")
            autoCountFrame:UnregisterAllEvents()
        end
    end
    autoBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("자동 카운트다운 정지")
        GameTooltip:AddLine("활성화 시, 카운트다운 중 누군가 채팅에", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("숫자(100, 백 등)를 포함한 메시지를 보내면", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("자동으로 정지 후 재개 메시지를 전송합니다.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    autoBtn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    autoBtn:SetScript("OnClick", function()
        GUI().autoCountEnabled = not GUI().autoCountEnabled
        updateAutoBtnStyle()
    end)
    updateAutoBtnStyle()

    -- ====== 카운트시작 버튼 (녹색) — RaidBook 원본 OnClick 로직 그대로 ======
    countBtn:SetBackdropColor(0.05, 0.25, 0.05, 0.95)
    countBtn:SetBackdropBorderColor(0.15, 0.50, 0.15, 1)
    countBtn.txt:SetTextColor(0.2, 0.9, 0.2)
    countBtn.txt:SetText("카운트시작")
    countBtn:SetScript("OnEnter", function(self)
        countBtn:SetBackdropColor(0.10, 0.40, 0.10, 0.95)
        countBtn:SetBackdropBorderColor(0.20, 0.80, 0.20, 1)
        countBtn.txt:SetTextColor(0.3, 1.0, 0.3)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("카운트다운 시작 (5>1)")
        GameTooltip:Show()
    end)
    countBtn:SetScript("OnLeave", function(self)
        countBtn:SetBackdropColor(0.05, 0.25, 0.05, 0.95)
        countBtn:SetBackdropBorderColor(0.15, 0.50, 0.15, 1)
        countBtn.txt:SetTextColor(0.2, 0.9, 0.2)
        GameTooltip:Hide()
    end)
    countBtn:SetScript("OnMouseDown", function(self)
        countBtn:SetBackdropColor(0.02, 0.15, 0.02, 1.0)
        countBtn.txt:SetTextColor(0.1, 0.6, 0.1)
    end)
    countBtn:SetScript("OnMouseUp", function(self)
        countBtn:SetBackdropColor(0.10, 0.40, 0.10, 0.95)
        countBtn.txt:SetTextColor(0.3, 1.0, 0.3)
    end)

    -- 중지 버튼 색상 토글 헬퍼 (active: 빨강 / inactive: 회색)
    local function styleStop()
        if GUI().countdownActive then
            stopBtn:SetBackdropColor(0.35, 0.05, 0.05, 0.95)
            stopBtn:SetBackdropBorderColor(0.60, 0.15, 0.15, 1)
            stopBtn.txt:SetTextColor(0.9, 0.2, 0.2)
        else
            stopBtn:SetBackdropColor(0.12, 0.12, 0.15, 0.95)
            stopBtn:SetBackdropBorderColor(0.30, 0.30, 0.35, 1)
            stopBtn.txt:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    countBtn:SetScript("OnClick", function()
        if not GUI().countdownActive then
            GUI().countdownActive = true
            GUI().currentCount = 5

            local messages = Database:GetGlobalConfigOrDefault("countdownmessages", {
                count = "--- %d",
                closed = "--- 입찰 마감 ---",
                resume = "--- 신규 입찰 ! 재개합니다 ---"
            })

            SendChatMessage(string.format(messages.count, GUI().currentCount), "RAID_WARNING")
            styleStop()

            local function countStep()
                if GUI().countdownActive and GUI().currentCount > 1 then
                    GUI().currentCount = GUI().currentCount - 1
                    SendChatMessage(string.format(messages.count, GUI().currentCount), "RAID_WARNING")
                    GUI().countdownTimer = C_Timer.After(1.0, countStep)
                else
                    if GUI().countdownActive then
                        SendChatMessage(messages.closed, "RAID_WARNING")
                    end
                    GUI().countdownActive = false
                    GUI().countdownTimer = nil
                    styleStop()
                end
            end

            GUI().countdownTimer = C_Timer.After(1.0, countStep)
        end
    end)

    -- ====== 카운트 중지 버튼 — RaidBook 원본 OnClick 로직 그대로 ======
    stopBtn.txt:SetText("카운트 중지")
    styleStop()
    stopBtn:SetScript("OnEnter", function(self)
        if GUI().countdownActive then
            stopBtn:SetBackdropColor(0.50, 0.10, 0.10, 0.95)
            stopBtn:SetBackdropBorderColor(1.0, 0.25, 0.25, 1)
            stopBtn.txt:SetTextColor(1.0, 0.3, 0.3)
        else
            stopBtn:SetBackdropColor(0.20, 0.20, 0.22, 0.95)
            stopBtn:SetBackdropBorderColor(0.45, 0.45, 0.50, 1)
            stopBtn.txt:SetTextColor(0.75, 0.75, 0.75)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("카운트다운 중지 및 재개")
        GameTooltip:Show()
    end)
    stopBtn:SetScript("OnLeave", function(self)
        styleStop()
        GameTooltip:Hide()
    end)
    stopBtn:SetScript("OnMouseDown", function(self)
        if GUI().countdownActive then
            stopBtn:SetBackdropColor(0.20, 0.02, 0.02, 1.0)
            stopBtn.txt:SetTextColor(0.6, 0.1, 0.1)
        else
            stopBtn:SetBackdropColor(0.06, 0.06, 0.08, 1.0)
            stopBtn.txt:SetTextColor(0.35, 0.35, 0.35)
        end
    end)
    stopBtn:SetScript("OnMouseUp", function(self)
        if GUI().countdownActive then
            stopBtn:SetBackdropColor(0.50, 0.10, 0.10, 0.95)
            stopBtn.txt:SetTextColor(1.0, 0.3, 0.3)
        else
            stopBtn:SetBackdropColor(0.20, 0.20, 0.22, 0.95)
            stopBtn.txt:SetTextColor(0.75, 0.75, 0.75)
        end
    end)
    stopBtn:SetScript("OnClick", function()
        stopAndResume()
        styleStop()
    end)
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
