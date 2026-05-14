local _, ADDONSELF = ...


local RegEvent = ADDONSELF.regevent

-- 성능 개선: GetItemInfo 캐시 (개선된 버전)
local itemInfoCache = {}
local maxCacheSize = 1000

-- 캐시된 GetItemInfo 함수
local function GetItemInfoCached(item)
    -- 캐시 키로 아이템 링크 사용 (더 안전)
    local cacheKey = type(item) == "string" and item or tostring(item)

    if not itemInfoCache[cacheKey] then
        local name, link, quality, level, reqLevel, class, subclass, maxStack, equipSlot, icon, sellPrice, itemID = GetItemInfo(item)

        -- 캐시에 저장
        itemInfoCache[cacheKey] = {
            name = name,
            link = link,
            quality = quality,
            level = level,
            itemID = itemID,
            timestamp = time(),
        }

        -- 캐시 크기 제한 (LRU 방식)
        local cacheCount = 0
        for _ in pairs(itemInfoCache) do
            cacheCount = cacheCount + 1
        end

        if cacheCount > maxCacheSize then
            -- 가장 오래된 항목 제거
            local oldestKey, oldestTime = nil, math.huge
            for k, v in pairs(itemInfoCache) do
                if v.timestamp < oldestTime then
                    oldestKey, oldestTime = k, v.timestamp
                end
            end
            if oldestKey then
                itemInfoCache[oldestKey] = nil
            end
        end
    end

    local cached = itemInfoCache[cacheKey]
    if cached then
        return cached.name, cached.link, cached.quality, cached.level, nil, nil, nil, nil, nil, nil, cached.itemID, nil
    else
        return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    end
end

RegEvent("ADDON_LOADED", function()
    if not IberisRaidAuctionDatabase then
        IberisRaidAuctionDatabase = {}
    end
end)

local db = {
    ledgerItemsChangedCallback = {}
}

-- 던전 진입 감지 및 자동 초기화 팝업
local lastZoneName = ""
local isInDungeon = false

RegEvent("ZONE_CHANGED_NEW_AREA", function()
    local zoneName = GetRealZoneText()

    -- 던전/인스턴스인지 확인
    local isInInstance, instanceType = IsInInstance()

    if zoneName and zoneName ~= lastZoneName then
        -- 던전/인스턴스에 진입하고 이전에 던전이 아니었을 경우
        if isInInstance and (instanceType == "party" or instanceType == "raid") and not isInDungeon then
            isInDungeon = true

            -- 설정 확인: 자동 초기화 기능이 활성화되어 있는지
            local autoClearEnabled = db:GetGlobalConfigOrDefault("autoClearOnDungeonEnter", true)

            if autoClearEnabled then
                -- 데이터가 있는지 확인
                local ledger = db:GetCurrentLedger()
                if ledger and ledger["items"] and #ledger["items"] > 0 then
                    -- 자동으로 전체 지우기 팝업 표시
                StaticPopupDialogs["IBERISRAIDAUCTION_AUTO_CLEAR"] = {
                    text = string.format("%s|n|n던전에 진입했습니다. 이전 데이터를 모두 삭제하시겠습니까?", zoneName),
                    button1 = "전체 삭제",
                    button2 = "유지",
                    OnAccept = function()
                        db:NewLedger()
                        ADDONSELF.print("이전 데이터가 삭제되었습니다.")
                    end,
                    OnCancel = function()
                        ADDONSELF.print("이전 데이터를 유지합니다.")
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = false,
                    preferredIndex = 3,
                }
                StaticPopup_Show("IBERISRAIDAUCTION_AUTO_CLEAR")
                end
            end

        -- 던전에서 나왔을 경우
        elseif not isInInstance and isInDungeon then
            isInDungeon = false
        end

        lastZoneName = zoneName
    end
end)

function db:RegisterChangeCallback(cb)
    table.insert( self.ledgerItemsChangedCallback, cb )
end

function db:OnLedgerItemsChange()
    local callbackIndex = 0
    for _, cb in pairs(self.ledgerItemsChangedCallback) do
        callbackIndex = callbackIndex + 1
        cb()
    end
end

function db:GetConfig()
    if not IberisRaidAuctionDatabase["config"] then
        IberisRaidAuctionDatabase["config"] = {}
    end

    return IberisRaidAuctionDatabase["config"]
end

function db:SetConfig(key, v)
    local config = self:GetConfig()
    config[key] = v
end

function db:GetConfigOrDefault(key, def)
    local config = self:GetConfig()

    if config[key] == nil then  -- nil일 때만 기본값 설정 (false도 유효한 값)
        config[key] = def
    end

    return config[key]
end

local MAX_LEDGER_COUNT = 1

function db:SetCurrentLedger(idx)
    IberisRaidAuctionDatabase["current"] = idx
end

function db:NewLedger()
    if not IberisRaidAuctionDatabase["ledgers"] then
        IberisRaidAuctionDatabase["ledgers"] = {}
    end

    local ledgers = IberisRaidAuctionDatabase["ledgers"]
    table.insert( ledgers, {
        ["time"] = time(),
        ["items"] = {},
        -- 레이드 시작시 내 골드 (UpdateSummary 하단 라벨용). GetMoney() 단위는 copper.
        ["_startMoneyCopper"] = GetMoney() or 0,
    } )

    while(#ledgers > MAX_LEDGER_COUNT) do
        table.remove(ledgers, 1)
    end

    self:SetCurrentLedger(#ledgers)
    self:OnLedgerItemsChange()
end

function db:GetCurrentLedger()
    if not IberisRaidAuctionDatabase["ledgers"] then
        self:NewLedger()
    end

    local cur = IberisRaidAuctionDatabase["current"]
    local ledger = IberisRaidAuctionDatabase["ledgers"][cur]

    
    return ledger
end

-- TODO should global const
local TYPE_CREDIT = "CREDIT"
local TYPE_DEBIT  = "DEBIT"
local DETAIL_TYPE_ITEM = "ITEM"
local DETAIL_TYPE_CUSTOM = "CUSTOM"

local COST_TYPE_GOLD = "GOLD"
local COST_TYPE_PROFIT_PERCENT = "PROFIT_PERCENT"
local COST_TYPE_MUL_AVG = "MUL_AVG"

-- function db:GetCurrentEarning()
--     local ledger = self:GetCurrentLedger()

--     local revenue = 0
--     local expense = 0

--     for _, item in pairs(ledger["items"]) do
--         if item["type"] == TYPE_CREDIT then
--             revenue = revenue + (item["cost"] or 0)
--         elseif item["type"] == TYPE_DEBIT then
--             expense = expense + (item["cost"] or 0)
--         end
--     end

--     return revenue * 10000, expense * 10000
-- end

function db:AddEntry(type, detail, beneficiary, cost)
    local ledger = self:GetCurrentLedger()

    -- DEBIT 타입인 경우 beneficiary가 없으면 빈 문자열로 설정 (L["[Unknown]"] 사용 방지)
    local finalBeneficiary = beneficiary
    if type == TYPE_DEBIT and not beneficiary then
        finalBeneficiary = ""
    end

    table.insert(ledger["items"], {
        -- id = #ledger["items"] + 1,
        type = type,
        detail = detail or {},
        beneficiary = finalBeneficiary or "",
        cost = cost or 0,
        noBeneficiary = false,  -- 기본값: 득자 있음
    })

    self:OnLedgerItemsChange()
end

function db:RemoveEntry(idx)
    local ledger = self:GetCurrentLedger()
    table.remove(ledger["items"], idx)

    self:OnLedgerItemsChange()
end

function db:AddCredit(reason, beneficiary, cost)
    self:AddEntry(TYPE_CREDIT, {
        ["displayname"] = reason
    }, beneficiary, cost)
end

function db:AddDebit(reason, beneficiary, cost)
    -- DEBIT 아이템 생성 시 빈 문자열로 초기화하여 '[알수없음]' 표시 방지
    self:AddEntry(TYPE_DEBIT, {
        ["displayname"] = reason
    }, beneficiary or "", cost)
end

function db:AddLoot(item, count, beneficiary, cost, force)
    -- 링크에서 직접 itemID 추출을 우선적으로 시도
    local itemIDFromLink = nil
    if type(item) == "string" then
        itemIDFromLink = item:match("item:(%d+)")
    end

    -- GetItemInfo는 이름만 얻고 ID는 링크에서 직접 추출 (WoW Classic 버그 회피)
    local itemName, itemLink, itemRarity, itemLevel, _, _, _, _, _, _, _ = GetItemInfo(item)

    -- 링크에서 ID 추출 실패 시
    if not itemIDFromLink then
        return
    end

    -- itemID는 링크에서 추출한 값을 사용
    local itemID = tonumber(itemIDFromLink)

    -- 링크에서 추출한 ID를 reliableItemID로 사용
    local reliableItemID = itemID

    -- 링크가 없고 GetItemInfo도 실패한 경우
    if not itemLink then
        return
    end

    -- 등급 필터링 (force=true 면 skip — 거래 자동기록 / Ctrl+클릭 수동추가)
    if not force then
        local filter = self:GetConfigOrDefault("filterlevel", LE_ITEM_QUALITY_UNCOMMON)
        if itemRarity < filter then
            return  -- 등급 필터에 의해 제외됨
        end
    end

    -- 모든 필터링 통과: 아이템 추가
    self:AddEntry(TYPE_CREDIT, {
        item = itemLink,
        type = DETAIL_TYPE_ITEM,
        count = count or 1,
        reliableItemID = reliableItemID,  -- 안정적인 아이템 ID 저장
    }, beneficiary, cost)
end

function db:SetItemNoBeneficiary(itemIdx, noBeneficiary)
    local ledger = self:GetCurrentLedger()
    if ledger["items"] and ledger["items"][itemIdx] then
        ledger["items"][itemIdx].noBeneficiary = noBeneficiary
        -- 실제 데이터베이스에도 저장 (전역 변수 보호 강화)
        if type(IberisRaidAuctionDatabase) == "table" then
            local currentLedgerIdx = IberisRaidAuctionDatabase["current"]
            if currentLedgerIdx and type(IberisRaidAuctionDatabase["ledgers"]) == "table" and
               type(IberisRaidAuctionDatabase["ledgers"][currentLedgerIdx]) == "table" and
               type(IberisRaidAuctionDatabase["ledgers"][currentLedgerIdx]["items"]) == "table" and
               type(IberisRaidAuctionDatabase["ledgers"][currentLedgerIdx]["items"][itemIdx]) == "table" then
                IberisRaidAuctionDatabase["ledgers"][currentLedgerIdx]["items"][itemIdx].noBeneficiary = noBeneficiary
            end
        end
    end
end

function db:GetItemNoBeneficiary(itemIdx)
    local ledger = self:GetCurrentLedger()
    if ledger["items"] and ledger["items"][itemIdx] then
        return ledger["items"][itemIdx].noBeneficiary or false
    end
    return false
end

-- 전역 설정 관리 함수 (계정별 저장)
function db:GetGlobalConfig()
    if not IberisRaidAuctionGlobalConfig then
        IberisRaidAuctionGlobalConfig = {}
    end
    return IberisRaidAuctionGlobalConfig
end

function db:GetGlobalConfigOrDefault(key, def)
    local config = self:GetGlobalConfig()
    if config[key] == nil then
        config[key] = def
    end
    return config[key]
end

function db:SetGlobalConfig(key, value)
    local config = self:GetGlobalConfig()
    config[key] = value
end

-- 전역 설정 강제 저장 함수
function db:ForceSaveGlobalConfig()
    -- 데이터를 강제로 저장하기 위해 더미 값 설정/해제
    local temp = IberisRaidAuctionGlobalConfig._temp or 0
    IberisRaidAuctionGlobalConfig._temp = (temp + 1) % 1000
end

ADDONSELF.db = db
