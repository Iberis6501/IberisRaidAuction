-- IberisRaidAuction: 메인 장부 창 (검색 + 품질 필터 + 시간순 목록)
-- Phase 1: 단순 N행 표시. Phase 2에서 ScrollFrame 도입 예정.
local IA = IberisRaidAuction
local U = {}
IA.ui.Ledger = U

local frame, content, rows = nil, nil, {}
local searchText, minQualityFilter = "", 0
local ROW_HEIGHT = 22
local MAX_VISIBLE_ROWS = 18

local function savePos()
    if not frame then return end
    local p, _, _, x, y = frame:GetPoint(1)
    IberisRaidAuctionDB.settings.ledgerPos = { point = p, x = x, y = y }
end

local function restorePos()
    local pos = IberisRaidAuctionDB.settings.ledgerPos
    frame:ClearAllPoints()
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function buildRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(540, ROW_HEIGHT)
    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.time:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.time:SetWidth(60); row.time:SetJustifyH("LEFT")
    row.item = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.item:SetPoint("LEFT", row.time, "RIGHT", 6, 0)
    row.item:SetWidth(280); row.item:SetJustifyH("LEFT")
    row.player = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.player:SetPoint("LEFT", row.item, "RIGHT", 6, 0)
    row.player:SetWidth(110); row.player:SetJustifyH("LEFT")
    row.gold = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.gold:SetPoint("LEFT", row.player, "RIGHT", 6, 0)
    row.gold:SetWidth(70); row.gold:SetJustifyH("RIGHT")
    return row
end

local function getFiltered()
    local out, q = {}, minQualityFilter
    local search = (searchText or ""):lower()
    local L = IberisRaidAuctionDB.ledger
    for i = #L, 1, -1 do                       -- 최신순
        local e = L[i]
        if (e.quality or 0) >= q then
            local match = (search == "")
                or (e.link and e.link:lower():find(search, 1, true))
                or (e.player and e.player:lower():find(search, 1, true))
            if match then out[#out + 1] = e end
        end
    end
    return out
end

local function refresh()
    if not content then return end
    local data = getFiltered()
    for i = 1, MAX_VISIBLE_ROWS do
        local row, entry = rows[i], data[i]
        if entry then
            row.time:SetText(date("%H:%M:%S", entry.time))
            row.item:SetText(entry.link or "?")
            row.player:SetText(entry.player or "?")
            row.gold:SetText(entry.gold and (entry.gold .. "g") or "-")
            row:Show()
        else
            row:Hide()
        end
    end
end
U.Refresh = function() refresh() end

local function qText(v)
    local L = IA.L or {}
    local map = {
        [0] = L["Q_ALL"]       or "All",
        [1] = L["Q_COMMON"]    or "Common+",
        [2] = L["Q_UNCOMMON"]  or "Uncommon+",
        [3] = L["Q_RARE"]      or "Rare+",
        [4] = L["Q_EPIC"]      or "Epic+",
        [5] = L["Q_LEGENDARY"] or "Legendary+",
    }
    return map[v] or map[0]
end

function U:OnLoaded()
    frame = CreateFrame("Frame", "IberisRaidAuctionLedger", UIParent, "BackdropTemplate")
    frame:SetSize(560, 480)
    frame:SetMovable(true); frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePos() end)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -16)
    frame.title:SetText((IA.L and IA.L["LEDGER_TITLE"]) or "IberisRaidAuction Ledger")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(180, 22)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -52)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self) searchText = self:GetText() or ""; refresh() end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", -2, 2)
    searchLabel:SetText((IA.L and IA.L["SEARCH"]) or "Search")

    local qLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qLabel:SetPoint("LEFT", searchBox, "RIGHT", 24, 8)
    qLabel:SetText((IA.L and IA.L["QUALITY"]) or "Quality")

    local qBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    qBtn:SetSize(110, 22)
    qBtn:SetPoint("TOPLEFT", qLabel, "BOTTOMLEFT", 0, -2)
    qBtn:SetScript("OnClick", function(self)
        minQualityFilter = (minQualityFilter + 1) % 6
        IberisRaidAuctionDB.settings.minQuality = minQualityFilter
        self:SetText(qText(minQualityFilter))
        refresh()
    end)

    -- 컬럼 헤더
    local header = CreateFrame("Frame", nil, frame)
    header:SetSize(540, 18)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -110)
    local function head(text, x, w)
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", header, "LEFT", x, 0)
        fs:SetWidth(w); fs:SetJustifyH("LEFT")
        fs:SetText(text)
    end
    local Lo = IA.L or {}
    head(Lo["COL_TIME"]   or "Time",    4, 60)
    head(Lo["COL_ITEM"]   or "Item",   70, 280)
    head(Lo["COL_PLAYER"] or "Player",356, 110)
    head(Lo["COL_GOLD"]   or "Gold",  472, 70)

    -- 본문
    content = CreateFrame("Frame", nil, frame)
    content:SetSize(540, ROW_HEIGHT * MAX_VISIBLE_ROWS)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)

    for i = 1, MAX_VISIBLE_ROWS do
        local row = buildRow(content)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:Hide()
        rows[i] = row
    end

    minQualityFilter = (IberisRaidAuctionDB.settings and IberisRaidAuctionDB.settings.minQuality) or 0
    qBtn:SetText(qText(minQualityFilter))
    restorePos()
end

function U:OnLogin()
    refresh()
    if IberisRaidAuctionDB.settings and IberisRaidAuctionDB.settings.ledgerShown and frame then
        frame:Show()
    end
end

function U:Show()
    if frame then frame:Show(); IberisRaidAuctionDB.settings.ledgerShown = true; refresh() end
end
function U:Hide()
    if frame then frame:Hide(); IberisRaidAuctionDB.settings.ledgerShown = false end
end
function U:Toggle()
    if not frame then return end
    if frame:IsShown() then U:Hide() else U:Show() end
end
