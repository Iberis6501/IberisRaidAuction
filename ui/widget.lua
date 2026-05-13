-- IberisRaidAuction: 이동 가능한 미니 위젯 (누적 수익 표시 / 클릭으로 장부 토글)
local IA = IberisRaidAuction
local U = {}
IA.ui.Widget = U

local frame

local function savePos()
    if not frame then return end
    local p, _, _, x, y = frame:GetPoint(1)
    IberisRaidAuctionDB.settings.widgetPos = { point = p, x = x, y = y }
end

local function restorePos()
    local pos = IberisRaidAuctionDB.settings.widgetPos
    frame:ClearAllPoints()
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
end

function U:OnLoaded()
    frame = CreateFrame("Button", "IberisRaidAuctionWidget", UIParent, "BackdropTemplate")
    frame:SetSize(120, 32)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePos() end)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.7)
    end

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.label:SetText("|cff91d7f2IA|r " .. ((IA.L and IA.L["WIDGET_DEFAULT"]) or "0g"))

    frame:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            if IA.ui.Ledger then IA.ui.Ledger:Toggle() end
        end
    end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("IberisRaidAuction")
        GameTooltip:AddLine("좌클릭: 장부 열기/닫기", 1, 1, 1)
        GameTooltip:AddLine("드래그: 위치 이동", 1, 1, 1)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    restorePos()
    if IberisRaidAuctionDB.settings.widgetHidden then frame:Hide() end
end

function U:Toggle()
    if not frame then return end
    if frame:IsShown() then
        frame:Hide(); IberisRaidAuctionDB.settings.widgetHidden = true
    else
        frame:Show(); IberisRaidAuctionDB.settings.widgetHidden = false
    end
end

function U:UpdateEarnings(g)
    if not frame or not frame.label then return end
    frame.label:SetText(string.format("|cff91d7f2IA|r %d골드", g or 0))
end
