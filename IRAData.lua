local _, ADDONSELF = ...

local strbyte = string.byte

local RegEvent = ADDONSELF.regevent

-- 성능 개선: GetItemInfo 캐시 (개선된 버전)
local itemInfoCache = {}
local maxCacheSize = 1000

-- 거래 자동 입력: TRADE_SUCCESS + UI_INFO 등으로 동일 스냅샷이 연속 적용될 때 장부 이중 삽입 방지
local lastTradeForcedLootKey
local lastTradeForcedLootTime = 0
local TRADE_FORCED_LOOT_DEDUP_SEC = 6

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
    -- 레거시 RaidLedgerDatabase에서 마이그레이션
    if RaidLedgerDatabase and next(RaidLedgerDatabase) then
        for k, v in pairs(RaidLedgerDatabase) do
            if IberisRaidAuctionDatabase[k] == nil then
                IberisRaidAuctionDatabase[k] = v
            end
        end
    end
    -- 레거시 RaidLedgerGlobalConfig에서 마이그레이션
    if not IberisRaidAuctionGlobalConfig then
        IberisRaidAuctionGlobalConfig = {}
    end
    if RaidLedgerGlobalConfig and next(RaidLedgerGlobalConfig) then
        for k, v in pairs(RaidLedgerGlobalConfig) do
            if IberisRaidAuctionGlobalConfig[k] == nil then
                IberisRaidAuctionGlobalConfig[k] = v
            end
        end
    end
end)

local db = {
    ledgerItemsChangedCallback = {},
    testRowsPurgedThisSession = false,
}

local COPPER_PER_GOLD = 10000
local MONEY_AUDIT_ANOMALY_THRESHOLD_GOLD = 100

local TYPE_CREDIT, TYPE_DEBIT, DETAIL_TYPE_ITEM, DETAIL_TYPE_CUSTOM
local SALE_STATE_OPEN, SALE_STATE_PRICED, SALE_STATE_CONFIRMED
local COST_TYPE_GOLD, COST_TYPE_PROFIT_PERCENT, COST_TYPE_MUL_AVG
local isLedgerSaleStateConfirmed
local normalizeLedgerSaleStateForItem
local normalizeLedgerConfirmedForEntry
local normalizeLedgerParticipantFields
local getLedgerDisplayBeneficiary
local getLedgerWinnerName
local getLedgerLooterName

isLedgerSaleStateConfirmed = function(state)
    return state == "confirmed"
end

normalizeLedgerSaleStateForItem = function(item)
    if not item or item.type ~= "CREDIT" or not item.detail or item.detail.type ~= "ITEM" then
        return nil
    end
    local st = tostring(item.saleState or "")
    if st == "open" or st == "priced" or st == "confirmed" then
        return st
    end
    if item.confirmed then
        return "confirmed"
    end
    if item.noBeneficiary then
        return "confirmed"
    end
    if (tonumber(item.cost) or 0) > 0 then
        return "priced"
    end
    return "open"
end

normalizeLedgerConfirmedForEntry = function(item)
    if not item then
        return false
    end
    if item.type == "CREDIT" and item.detail and item.detail.type == "ITEM" then
        return isLedgerSaleStateConfirmed(normalizeLedgerSaleStateForItem(item))
    end
    return item.confirmed and true or false
end

getLedgerLooterName = function(item)
    if type(item) ~= "table" then
        return ""
    end
    if item.looter ~= nil and item.looter ~= "" then
        return tostring(item.looter)
    end
    if item.beneficiary ~= nil and item.beneficiary ~= "" then
        return tostring(item.beneficiary)
    end
    if item.winner ~= nil and item.winner ~= "" then
        return tostring(item.winner)
    end
    return ""
end

getLedgerWinnerName = function(item)
    if type(item) ~= "table" then
        return ""
    end
    if item.winner ~= nil and item.winner ~= "" then
        return tostring(item.winner)
    end
    if item.type == "CREDIT" and item.detail and item.detail.type == "ITEM" then
        local legacy = tostring(item.beneficiary or "")
        if legacy == "" then
            return ""
        end
        local st = normalizeLedgerSaleStateForItem(item)
        if st == "open" and not item.confirmed and not item.noBeneficiary and (tonumber(item.cost) or 0) <= 0 then
            return ""
        end
        return legacy
    end
    if item.beneficiary ~= nil and item.beneficiary ~= "" then
        return tostring(item.beneficiary)
    end
    return ""
end

getLedgerDisplayBeneficiary = function(item)
    if type(item) ~= "table" then
        return ""
    end
    if item.type == "CREDIT" and item.detail and item.detail.type == "ITEM" then
        local winner = getLedgerWinnerName(item)
        if winner ~= "" then
            return winner
        end
        return getLedgerLooterName(item)
    end
    if item.beneficiary ~= nil and item.beneficiary ~= "" then
        return tostring(item.beneficiary)
    end
    local winner = getLedgerWinnerName(item)
    if winner ~= "" then
        return winner
    end
    return getLedgerLooterName(item)
end

normalizeLedgerParticipantFields = function(item)
    if type(item) ~= "table" then
        return
    end
    local looter = getLedgerLooterName(item)
    local winner = getLedgerWinnerName(item)
    if item.type == "CREDIT" and item.detail and item.detail.type == "ITEM" then
        item.looter = looter
        item.winner = winner
        item.beneficiary = getLedgerDisplayBeneficiary(item)
        return
    end
    local bene = item.beneficiary
    if bene == nil then
        bene = winner ~= "" and winner or looter
    end
    item.looter = looter
    item.winner = winner ~= "" and winner or tostring(bene or "")
    item.beneficiary = tostring(bene or "")
end

-- 공격대 첫 입던 자동 초기화 팝업
-- 정책:
--   1) 공격대(`raid`) 인스턴스 + IsInRaid() 둘 다 만족할 때만 동작 (파티/솔로 인던 무시)
--   2) 같은 공격대 인스턴스에 머무는 동안에는 절대 재질문하지 않음
--      (사망 부활, 무덤→재입장, 다중 영역 raid 의 영역 전환 등 모두 동일 instanceMapID)
--   3) 공대를 떠났다가(IsInRaid()=false) 다른 공대에 다시 들어가면 새 입던으로 간주해 다시 질문
--   4) /reload 후에도 같은 입던에서는 안 묻도록 SavedVariables 에 영속 저장

local function iraGetCurrentInstanceMapID()
    if type(GetInstanceInfo) ~= "function" then return nil end
    local ok, _, _, _, _, _, _, _, instanceMapID = pcall(GetInstanceInfo)
    if ok then return tonumber(instanceMapID) end
    return nil
end

local function iraShouldPromptAutoClearOnRaidEntry()
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance or instanceType ~= "raid" then return false end
    if not IsInRaid() then return false end

    local autoClearEnabled = db:GetGlobalConfigOrDefault("autoClearOnDungeonEnter", true)
    if not autoClearEnabled then return false end

    local ledger = db:GetCurrentLedger()
    if not (ledger and ledger["items"] and #ledger["items"] > 0) then return false end

    return true
end

local function iraMaybePromptAutoClearOnRaidEntry()
    local instanceMapID = iraGetCurrentInstanceMapID()
    if not instanceMapID then return end

    -- 공격대(raid) 인스턴스가 아닌 곳(파티/필드/도시 등)에선 아무 것도 안 함.
    -- 단, 공격대를 떠난 직후(현재 raid 가 아니고 IsInRaid()=false) 마크를 비워서
    -- 다음 공대 입던 시 새로 묻도록 한다 → GROUP_ROSTER_UPDATE 핸들러에서 처리.
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance or instanceType ~= "raid" or not IsInRaid() then return end

    -- 같은 공격대 인스턴스에 다시 들어온 경우(사망 후 부활 등) → 묻지 않음
    local lastID = tonumber(db:GetConfigOrDefault("autoClearLastPromptedInstanceID", 0)) or 0
    if lastID == instanceMapID then return end

    -- 이번 입던을 "이미 처리한 입던"으로 표시 (옵션 OFF/장부 비어있음 등으로 팝업 안 띄우는 경우도 동일)
    db:SetConfig("autoClearLastPromptedInstanceID", instanceMapID)

    if not iraShouldPromptAutoClearOnRaidEntry() then return end

    StaticPopupDialogs["IBERISRAIDAUCTION_AUTO_CLEAR"] = {
        text = string.format("%s|n|n공격대에 진입했습니다. 이전 데이터를 모두 삭제하시겠습니까?", GetRealZoneText() or ""),
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

RegEvent("ZONE_CHANGED_NEW_AREA", function()
    iraMaybePromptAutoClearOnRaidEntry()
end)

-- PLAYER_ENTERING_WORLD: 로그인/리로드/포탈 등으로 월드 진입 시 1회 점검
-- (저장된 instanceMapID 와 비교하므로 같은 입던이면 자동으로 스킵됨)
RegEvent("PLAYER_ENTERING_WORLD", function()
    iraMaybePromptAutoClearOnRaidEntry()
end)

-- 공격대를 떠나면(혹은 해체) 마크를 비워, 다음에 들어가는 공대에서 다시 묻도록 함.
RegEvent("GROUP_ROSTER_UPDATE", function()
    if not IsInRaid() then
        db:SetConfig("autoClearLastPromptedInstanceID", 0)
    end
end)

function db:RegisterChangeCallback(cb)
    table.insert( self.ledgerItemsChangedCallback, cb )
end

function db:OnLedgerItemsChange()
    local ledgers = IberisRaidAuctionDatabase and IberisRaidAuctionDatabase["ledgers"]
    local cur = IberisRaidAuctionDatabase and IberisRaidAuctionDatabase["current"]
    local ledger = ledgers and cur and ledgers[cur]
    if type(ledger) == "table" then
        ledger._iraPrepared = nil
    end
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

--- @param internalInit boolean|nil true when creating first empty ledger from GetCurrentLedger (no permission check)
--- @return boolean success false if blocked (non-leader clear in synced raid)
function db:NewLedger(internalInit)
    local s = ADDONSELF.sync
    if not internalInit and IsInRaid() and s and s.enabled and not UnitIsGroupLeader("player") and not s.suppressBroadcast then
        return false
    end

    if not IberisRaidAuctionDatabase["ledgers"] then
        IberisRaidAuctionDatabase["ledgers"] = {}
    end

    local ledgers = IberisRaidAuctionDatabase["ledgers"]
    local startMoneyCopper = (type(GetMoney) == "function" and tonumber(GetMoney())) or 0
    table.insert( ledgers, {
        ["time"] = time(),
        ["items"] = {},
        ["_syncRev"] = 0,
        ["_nextSeq"] = 0,
        ["_startMoneyCopper"] = startMoneyCopper,
        ["_raidLootMoneyCopper"] = 0,
        ["_merchantMoneyDeltaCopper"] = 0,
    } )

    while(#ledgers > MAX_LEDGER_COUNT) do
        table.remove(ledgers, 1)
    end

    self:SetCurrentLedger(#ledgers)
    self:OnLedgerItemsChange()

    local leader = UnitIsGroupLeader("player")
    if s and s.enabled and IsInRaid() and not s.suppressBroadcast and leader then
        s:BroadcastClearLedger()
    end
    if s and not s.suppressBroadcast and ADDONSELF.raidWarningNotice and leader and IsInRaid() then
        ADDONSELF.raidWarningNotice((UnitName("player") or "?") .. "님이 장부를 초기화했습니다.")
    end
    return true
end

function db:GetCurrentLedger()
    if not IberisRaidAuctionDatabase["ledgers"] then
        self:NewLedger(true)
    end

    local ledgers = IberisRaidAuctionDatabase["ledgers"]
    local cur = IberisRaidAuctionDatabase["current"]
    local ledger = ledgers[cur]
    if ledger and type(ledger) == "table" then
        if ledger["items"] == nil then
            ledger["items"] = {}
        end
        if ledger["_nextSeq"] == nil then
            ledger["_nextSeq"] = 0
        end
        if ledger["_startMoneyCopper"] == nil then
            ledger["_startMoneyCopper"] = (type(GetMoney) == "function" and tonumber(GetMoney())) or 0
        end
        if ledger["_raidLootMoneyCopper"] == nil then
            ledger["_raidLootMoneyCopper"] = 0
        end
        if ledger["_merchantMoneyDeltaCopper"] == nil then
            ledger["_merchantMoneyDeltaCopper"] = 0
        end
        if ledger._iraPrepared and self.testRowsPurgedThisSession then
            return ledger
        end
        if not self.testRowsPurgedThisSession then
            local cleaned = nil
            for i = 1, #ledger["items"] do
                local it = ledger["items"][i]
                local isTestRow = type(it) == "table" and (it.isTestMode == true or (it.detail and it.detail.isTestMode == true))
                if isTestRow then
                    if not cleaned then
                        cleaned = {}
                        for j = 1, i - 1 do
                            cleaned[#cleaned + 1] = ledger["items"][j]
                        end
                    end
                elseif cleaned then
                    cleaned[#cleaned + 1] = it
                end
            end
            if cleaned then
                ledger["items"] = cleaned
            end
            self.testRowsPurgedThisSession = true
        end
        local anySeq = false
        -- 리로드 시 테스트 행을 먼저 걷어내므로, 다음 순번은 저장된 _nextSeq 가 아니라
        -- 실제로 남아 있는 행들의 seq 최댓값 기준으로 다시 잡아야 한다.
        local maxSeq = 0
        for i = 1, #ledger["items"] do
            local it = ledger["items"][i]
            local seq = it and tonumber(it.seq) or nil
            if seq and seq > 0 then
                anySeq = true
                if seq > maxSeq then
                    maxSeq = seq
                end
            end
        end
        if not anySeq and #ledger["items"] > 0 then
            maxSeq = 0
            for i = 1, #ledger["items"] do
                local it = ledger["items"][i]
                if type(it) == "table" then
                    maxSeq = maxSeq + 1
                    it.seq = maxSeq
                end
            end
        else
            for i = 1, #ledger["items"] do
                local it = ledger["items"][i]
                if type(it) == "table" and (not tonumber(it.seq) or tonumber(it.seq) <= 0) then
                    maxSeq = maxSeq + 1
                    it.seq = maxSeq
                end
            end
        end
        for i = 1, #ledger["items"] do
            local it = ledger["items"][i]
            if type(it) == "table" then
                -- UI 렌더링 중 붙는 임시 필드는 SavedVariables에 남으면 다음 로드에서
                -- 실제 장부 row처럼 오염된다. 장부 접근 시점에 정리해 둔다.
                it.stackIndices = nil
                it.stackCount = nil
                it.isStacked = nil
                it.costcache = nil
                it.realItemIdx = nil
                if it.cols ~= nil then
                    it.cols = nil
                end
                if type(it.detail) ~= "table" then
                    it.detail = {}
                end
                normalizeLedgerParticipantFields(it)
                it.saleState = normalizeLedgerSaleStateForItem(it)
                it.confirmed = normalizeLedgerConfirmedForEntry(it)
                normalizeLedgerParticipantFields(it)
            end
        end
        ledger["_nextSeq"] = maxSeq
        ledger._iraPrepared = true
        return ledger
    end
    -- 손상/레거시 SV: current 가 범위 밖이거나 희소 테이블인 경우 복구
    local bestIdx, bestL = nil, nil
    for i, lg in pairs(ledgers) do
        if type(i) == "number" and type(lg) == "table" then
            if bestIdx == nil or i > bestIdx then
                bestIdx, bestL = i, lg
            end
        end
    end
    if bestL then
        self:SetCurrentLedger(bestIdx)
        if bestL["items"] == nil then
            bestL["items"] = {}
        end
        return self:GetCurrentLedger()
    end
    self:NewLedger(true)
    return ledgers[IberisRaidAuctionDatabase["current"]]
end

local function shortNameLower(name)
    local s = tostring(name or "")
    s = s:match("^([^%-]+)") or s
    return string.lower(s)
end

function db:AddRaidLootMoneyCopper(copper)
    local add = math.floor(tonumber(copper) or 0)
    if add <= 0 then
        return
    end
    local ledger = self:GetCurrentLedger()
    ledger._raidLootMoneyCopper = math.max(0, math.floor(tonumber(ledger._raidLootMoneyCopper) or 0) + add)
end

function db:AddMerchantMoneyDeltaCopper(copper)
    local delta = math.floor(tonumber(copper) or 0)
    if delta == 0 then
        return
    end
    local ledger = self:GetCurrentLedger()
    ledger._merchantMoneyDeltaCopper = math.floor(tonumber(ledger._merchantMoneyDeltaCopper) or 0) + delta
end

function db:GetMoneyAuditState(itemsOverride, splitCount, checkAllDistribute)
    local ledger = self:GetCurrentLedger()
    if not ledger then
        return nil
    end

    local startMoneyCopper = math.floor(tonumber(ledger._startMoneyCopper) or 0)
    -- Keep these fields for compatibility / UI display, but exclude them from
    -- anomaly math to reduce false positives from loot money parsing and vendor deltas.
    local raidLootMoneyCopper = 0
    local merchantMoneyDeltaCopper = 0
    local currentMoneyCopper = (type(GetMoney) == "function" and tonumber(GetMoney())) or 0
    currentMoneyCopper = math.floor(currentMoneyCopper or 0)

    local receivedAuctionCopper = 0
    local meShort = shortNameLower(UnitName("player") or "")
    local auditItems = itemsOverride or ledger.items or {}
    local winners = {}
    for _, item in ipairs(auditItems) do
        if item and item.type == TYPE_CREDIT then
            local costGold = math.floor(tonumber(item.cost) or 0)
            if costGold > 0 then
                local winnerShort = ""
                local includeAsCash = true
                if item.detail and item.detail.type == DETAIL_TYPE_ITEM then
                    winnerShort = shortNameLower(getLedgerWinnerName(item))
                    if winnerShort ~= "" and winnerShort == meShort then
                        includeAsCash = false
                    end
                end
                if item.noBeneficiary ~= true and winnerShort ~= "" then
                    winners[winnerShort] = true
                end
                if includeAsCash then
                    receivedAuctionCopper = receivedAuctionCopper + (costGold * COPPER_PER_GOLD)
                end
            end
        end
    end

    splitCount = math.floor(tonumber(splitCount) or 0)
    if checkAllDistribute == nil then
        checkAllDistribute = true
    else
        checkAllDistribute = checkAllDistribute and true or false
    end

    local _, avgGold, _, expenseGold = ADDONSELF.calcavg(auditItems, splitCount, nil, nil, checkAllDistribute)
    local explicitExpenseCopper = math.max(0, math.floor(tonumber(expenseGold) or 0) * COPPER_PER_GOLD)

    local preDistributionExpectedMoneyCopper = startMoneyCopper + receivedAuctionCopper - explicitExpenseCopper
    local postDistributionExpectedMoneyCopper = preDistributionExpectedMoneyCopper
    local distributionEligibleCount = 0
    local myEligibleForDistribution = false
    local myDistributionShareCopper = 0

    if splitCount > 0 then
        local beneficiaryCount = 0
        for _ in pairs(winners) do
            beneficiaryCount = beneficiaryCount + 1
        end
        if checkAllDistribute then
            distributionEligibleCount = splitCount
            myEligibleForDistribution = true
        else
            distributionEligibleCount = math.max(splitCount - beneficiaryCount, 1)
            myEligibleForDistribution = not winners[meShort]
        end

        myDistributionShareCopper = math.max(0, math.floor(tonumber(avgGold) or 0) * COPPER_PER_GOLD)
        local payoutsToOthersCopper = math.max(0, distributionEligibleCount - (myEligibleForDistribution and 1 or 0)) * myDistributionShareCopper
        postDistributionExpectedMoneyCopper = preDistributionExpectedMoneyCopper - payoutsToOthersCopper
    end

    local preDiffCopper = currentMoneyCopper - preDistributionExpectedMoneyCopper
    local postDiffCopper = currentMoneyCopper - postDistributionExpectedMoneyCopper
    local usePostDistribution = distributionEligibleCount > 0 and math.abs(postDiffCopper) < math.abs(preDiffCopper)
    local expectedMoneyCopper = usePostDistribution and postDistributionExpectedMoneyCopper or preDistributionExpectedMoneyCopper
    local diffCopper = usePostDistribution and postDiffCopper or preDiffCopper
    local absDiffCopper = math.abs(diffCopper)
    local anomalyThresholdCopper = MONEY_AUDIT_ANOMALY_THRESHOLD_GOLD * COPPER_PER_GOLD

    return {
        startMoneyCopper = startMoneyCopper,
        raidLootMoneyCopper = raidLootMoneyCopper,
        merchantMoneyDeltaCopper = merchantMoneyDeltaCopper,
        receivedAuctionCopper = receivedAuctionCopper,
        explicitExpenseCopper = explicitExpenseCopper,
        preDistributionExpectedMoneyCopper = preDistributionExpectedMoneyCopper,
        postDistributionExpectedMoneyCopper = postDistributionExpectedMoneyCopper,
        expectedMoneyCopper = expectedMoneyCopper,
        currentMoneyCopper = currentMoneyCopper,
        diffCopper = diffCopper,
        anomaly = absDiffCopper >= anomalyThresholdCopper,
        anomalyThresholdCopper = anomalyThresholdCopper,
        distributionEligibleCount = distributionEligibleCount,
        myEligibleForDistribution = myEligibleForDistribution and true or false,
        myDistributionShareCopper = myDistributionShareCopper,
        usePostDistribution = usePostDistribution and true or false,
    }
end

local LEDGER_HASH_SEP_F = "\030"
local LEDGER_HASH_SEP_R = "\029"

function db:BuildLedgerHashString(items)
    if not items then return "" end
    local buf = {}
    for _, it in ipairs(items) do
        local d = it.detail or {}
        buf[#buf + 1] = (it.type or "")
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = tostring(tonumber(d.reliableItemID) or 0)
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = d.item or ""
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = d.displayname or ""
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = d.type or ""
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = tostring(tonumber(d.count) or 1)
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = it.beneficiary or ""
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = it.looter or ""
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = it.winner or ""
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = tostring(tonumber(it.cost) or 0)
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = (it.noBeneficiary and "1" or "0")
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = tostring(tonumber(it.seq) or 0)
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = normalizeLedgerSaleStateForItem(it) or ""
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = (normalizeLedgerConfirmedForEntry(it) and "1" or "0")
        buf[#buf + 1] = LEDGER_HASH_SEP_F
        buf[#buf + 1] = (it.isTestMode and "1" or "0")
        buf[#buf + 1] = LEDGER_HASH_SEP_R
    end
    return table.concat(buf)
end

function db:ComputeLedgerHashHex(items)
    local s = self:BuildLedgerHashString(items)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + strbyte(s, i)) % 4294967296
    end
    return string.format("%08x", h)
end

function db:GetLedgerSyncRevision()
    local ledger = self:GetCurrentLedger()
    if not ledger then return 0 end
    return tonumber(ledger._syncRev) or 0
end

--- 네트워크 스냅샷으로 장부 줄만 통째 교체 (호출 전후 sync.suppressBroadcast 로 억제)
function db:ReplaceLedgerItemsFromSync(newItems, syncRev)
    local ledger = self:GetCurrentLedger()
    if not ledger then return end
    ledger["items"] = newItems
    ledger._syncRev = tonumber(syncRev) or 0
    ledger._nextSeq = 0
    self:GetCurrentLedger()
    self:OnLedgerItemsChange()
end

function db:GetItemSaleState(itemIdx)
    local ledger = self:GetCurrentLedger()
    local item = ledger and ledger.items and ledger.items[itemIdx]
    return normalizeLedgerSaleStateForItem(item)
end

function db:IsLedgerItemConfirmed(itemOrIdx)
    return self:IsLedgerEntryConfirmed(itemOrIdx)
end

function db:IsLedgerEntryConfirmed(itemOrIdx)
    local item = itemOrIdx
    if type(itemOrIdx) == "number" then
        local ledger = self:GetCurrentLedger()
        item = ledger and ledger.items and ledger.items[itemOrIdx]
    end
    return normalizeLedgerConfirmedForEntry(item) and true or false
end

function db:GetLedgerEntryLooter(itemOrIdx)
    local item = itemOrIdx
    if type(itemOrIdx) == "number" then
        local ledger = self:GetCurrentLedger()
        item = ledger and ledger.items and ledger.items[itemOrIdx]
    end
    return getLedgerLooterName(item)
end

function db:GetLedgerEntryWinner(itemOrIdx)
    local item = itemOrIdx
    if type(itemOrIdx) == "number" then
        local ledger = self:GetCurrentLedger()
        item = ledger and ledger.items and ledger.items[itemOrIdx]
    end
    return getLedgerWinnerName(item)
end

function db:GetLedgerDisplayBeneficiary(itemOrIdx)
    local item = itemOrIdx
    if type(itemOrIdx) == "number" then
        local ledger = self:GetCurrentLedger()
        item = ledger and ledger.items and ledger.items[itemOrIdx]
    end
    return getLedgerDisplayBeneficiary(item)
end

function db:SetLedgerEntryLooter(itemIdx, looter, suppressChange)
    local ledger = self:GetCurrentLedger()
    local item = ledger and ledger.items and ledger.items[itemIdx]
    if not item then
        return false
    end
    local want = tostring(looter or "")
    if tostring(item.looter or "") == want then
        return false
    end
    item.looter = want
    normalizeLedgerParticipantFields(item)
    if not suppressChange then
        self:OnLedgerItemsChange()
    end
    return true
end

function db:SetLedgerEntryWinner(itemIdx, winner, suppressChange)
    local ledger = self:GetCurrentLedger()
    local item = ledger and ledger.items and ledger.items[itemIdx]
    if not item then
        return false
    end
    local want = tostring(winner or "")
    if tostring(item.winner or "") == want then
        return false
    end
    item.winner = want
    normalizeLedgerParticipantFields(item)
    if not suppressChange then
        self:OnLedgerItemsChange()
    end
    return true
end

function db:SetLedgerEntryConfirmed(itemIdx, confirmed, suppressChange)
    local ledger = self:GetCurrentLedger()
    if not ledger or not ledger.items or not ledger.items[itemIdx] then
        return false
    end
    local item = ledger.items[itemIdx]
    local want = confirmed and true or false
    local changed = false
    if item.type == TYPE_CREDIT and item.detail and item.detail.type == DETAIL_TYPE_ITEM then
        local newState
        if want then
            newState = SALE_STATE_CONFIRMED
        else
            newState = ((tonumber(item.cost) or 0) > 0) and SALE_STATE_PRICED or SALE_STATE_OPEN
        end
        if item.saleState ~= newState then
            item.saleState = newState
            changed = true
        end
    end
    if (item.confirmed and true or false) ~= want then
        item.confirmed = want
        changed = true
    end
    if changed and not suppressChange then
        self:OnLedgerItemsChange()
    end
    return changed
end

function db:SetItemSaleState(itemIdx, newState)
    local ledger = self:GetCurrentLedger()
    if not ledger or not ledger.items or not ledger.items[itemIdx] then
        return false
    end
    local item = ledger.items[itemIdx]
    if item.type ~= TYPE_CREDIT or not item.detail or item.detail.type ~= DETAIL_TYPE_ITEM then
        return false
    end
    local want = newState
    if want ~= SALE_STATE_OPEN and want ~= SALE_STATE_PRICED and want ~= SALE_STATE_CONFIRMED then
        want = normalizeLedgerSaleStateForItem(item)
    end
    local changed = false
    if item.saleState ~= want then
        item.saleState = want
        changed = true
    end
    local wantConfirmed = (want == SALE_STATE_CONFIRMED)
    if (item.confirmed and true or false) ~= wantConfirmed then
        item.confirmed = wantConfirmed
        changed = true
    end
    if not changed then
        return false
    end
    self:OnLedgerItemsChange()
    return true
end

-- TODO should global const
TYPE_CREDIT = "CREDIT"
TYPE_DEBIT  = "DEBIT"
DETAIL_TYPE_ITEM = "ITEM"
DETAIL_TYPE_CUSTOM = "CUSTOM"
SALE_STATE_OPEN = "open"
SALE_STATE_PRICED = "priced"
SALE_STATE_CONFIRMED = "confirmed"

COST_TYPE_GOLD = "GOLD"
COST_TYPE_PROFIT_PERCENT = "PROFIT_PERCENT"
COST_TYPE_MUL_AVG = "MUL_AVG"

isLedgerSaleStateConfirmed = function(state)
    return state == SALE_STATE_CONFIRMED
end

normalizeLedgerSaleStateForItem = function(item)
    if not item or item.type ~= TYPE_CREDIT or not item.detail or item.detail.type ~= DETAIL_TYPE_ITEM then
        return nil
    end
    local st = tostring(item.saleState or "")
    if st == SALE_STATE_OPEN or st == SALE_STATE_PRICED or st == SALE_STATE_CONFIRMED then
        return st
    end
    if item.confirmed then
        return SALE_STATE_CONFIRMED
    end
    if item.noBeneficiary then
        return SALE_STATE_CONFIRMED
    end
    if (tonumber(item.cost) or 0) > 0 then
        return SALE_STATE_PRICED
    end
    return SALE_STATE_OPEN
end

normalizeLedgerConfirmedForEntry = function(item)
    if not item then
        return false
    end
    if item.type == TYPE_CREDIT and item.detail and item.detail.type == DETAIL_TYPE_ITEM then
        return isLedgerSaleStateConfirmed(normalizeLedgerSaleStateForItem(item))
    end
    return item.confirmed and true or false
end

local function ledgerRowItemReliableId(it)
    if not it or it.type ~= TYPE_CREDIT or not it.detail or it.detail.type ~= DETAIL_TYPE_ITEM then
        return nil
    end
    local rid = tonumber(it.detail.reliableItemID)
    if rid then
        return rid
    end
    local link = it.detail.item
    if type(link) == "string" then
        return tonumber(link:match("item:(%d+)"))
    end
    return nil
end

-- 거래 낙찰 반영 전: 같은 itemID·낙찰 0원인 장부 줄(경매 담당 획득 등) 한 줄 제거
local function findFirstZeroCostCreditIndexForItemId(ledger, targetRid)
    targetRid = tonumber(targetRid)
    if not targetRid or not ledger or not ledger.items then
        return nil
    end
    for i = 1, #ledger.items do
        local it = ledger.items[i]
        if ledgerRowItemReliableId(it) == targetRid then
            local c = tonumber(it.cost) or 0
            if c == 0 then
                return i
            end
        end
    end
    return nil
end

local function beneficiaryShortMatches(benStored, sellerShort)
    if not benStored or benStored == "" or not sellerShort or sellerShort == "" then
        return false
    end
    local b = (tostring(benStored):match("^([^%-]+)") or tostring(benStored)):lower()
    local s = (tostring(sellerShort):match("^([^%-]+)") or tostring(sellerShort)):lower()
    return b == s
end

-- 공대장·경매담당 → 마부사(골드0) 거래 시 득자 표기. *…* 는 닉네임에 쓸 수 없어 플레이어와 겹치지 않음.
local IRA_BENE_DISENCHANT_HANDOFF = "*마력추출*"

local function DisenchantHandoffBeneficiaryLabel()
    return IRA_BENE_DISENCHANT_HANDOFF
end

--- 내가 아이템을 넣고 상대가 골드(또는 0)를 주는 거래 완료 시 장부 반영.
--- snap: item(링크), name(수신자 짧은 이름), money(골드 정수), count(스택 수), seller(보내는 사람=나, 짧은 이름)
--- deHandoff: 공대장·경매담당이 골드0으로 넘김 → 득자를 *마력추출* 로 두고 무득(noBeneficiary) 자동.
--- 골드 0: CHAT로 쌓인 '나=득자' 낙찰0 줄 count개의 득자만 수신자(또는 *마력추출* 표기)로 바꿈.
--- 골드>0: 매칭된 줄 중 장부 인덱스가 가장 작은 줄(먼저 기록된 루팅)에 수신자·낙찰가·수량을 반영하고, 나머지 0원 줄만 제거(맨 뒤 AddLoot 없음 → 순서 유지).
--- seller 가 비면: 상대→나 아이템+내 골드 구매(기존 GDKP) 경로로 AddLoot 만 수행.
--- @return boolean ok, string|nil tradeToastCode IRACmd 토스트용 결과 코드
function db:ApplyPlayerToTargetTradeSnap(snap)
    if not snap or not snap.item or snap.item == "" then
        return false
    end
    local buyer = snap.name or ""
    if buyer == "" then
        return false
    end
    local seller = snap.seller or ""
    local money = math.floor(tonumber(snap.money) or 0)
    local wantCount = math.max(1, tonumber(snap.count) or 1)

    if seller == "" then
        if money <= 0 then
            return false
        end
        if self:AddLoot(snap.item, 1, buyer, money, true, nil, SALE_STATE_CONFIRMED) then
            return true, "trade_purchase"
        end
        return false
    end

    local itemIDFromLink = type(snap.item) == "string" and snap.item:match("item:(%d+)")
    if not itemIDFromLink then
        return false
    end
    local rid = tonumber(itemIDFromLink)
    local ledger = self:GetCurrentLedger()
    if not ledger or not ledger.items then
        return false
    end

    local function tradeCandidatePriority(it)
        if not it or it.type ~= TYPE_CREDIT or ledgerRowItemReliableId(it) ~= rid then
            return nil
        end
        if isLedgerSaleStateConfirmed(normalizeLedgerSaleStateForItem(it)) then
            return nil
        end
        local bene = tostring(getLedgerDisplayBeneficiary(it) or "")
        local costNow = tonumber(it.cost) or 0
        local beneMatchesBuyer = beneficiaryShortMatches(bene, buyer)
        local beneMatchesSeller = beneficiaryShortMatches(bene, seller)
        local beneUnknown = (bene == "" or bene == "?")
        if money > 0 and costNow ~= 0 and costNow ~= money then
            return nil
        end
        if beneMatchesBuyer and money > 0 then
            return 4
        end
        if beneMatchesSeller then
            return 3
        end
        if beneUnknown then
            return 2
        end
        if money > 0 and costNow == money then
            return 1
        end
        return nil
    end

    local candidateRows = {}
    for i = 1, #ledger.items do
        local prio = tradeCandidatePriority(ledger.items[i])
        if prio then
            candidateRows[#candidateRows + 1] = { idx = i, prio = prio }
        end
    end
    table.sort(candidateRows, function(a, b)
        if a.prio ~= b.prio then
            return a.prio > b.prio
        end
        return a.idx < b.idx
    end)
    local indices = {}
    for i = 1, math.min(wantCount, #candidateRows) do
        indices[#indices + 1] = candidateRows[i].idx
    end

    if #indices == 0 then
        if money > 0 then
            if self:AddLoot(snap.item, wantCount, buyer, money, true, nil, SALE_STATE_CONFIRMED) then
                return true, "trade_sale_add"
            end
            return false
        end
        if snap.deHandoff then
            if self:AddLoot(snap.item, wantCount, DisenchantHandoffBeneficiaryLabel(), 0, true, nil, SALE_STATE_CONFIRMED) then
                return true, "trade_de_add"
            end
            return false
        end
        return false
    end

    if money == 0 then
        local newBene = buyer
        if snap.deHandoff then
            newBene = DisenchantHandoffBeneficiaryLabel()
        end
        for j = 1, #indices do
            local idx = indices[j]
            local row = ledger.items[idx]
            if row then
                row.winner = newBene
                normalizeLedgerParticipantFields(row)
                row.saleState = SALE_STATE_CONFIRMED
                if snap.deHandoff then
                    row.noBeneficiary = true
                end
                if ADDONSELF.sync then
                    local rrid = ledgerRowItemReliableId(row)
                    local iLink = row.detail and row.detail.item or ""
                    ADDONSELF.sync:BroadcastWinner(idx, rrid, newBene, iLink)
                    ADDONSELF.sync:BroadcastSaleState(idx, rrid, row.saleState, iLink)
                    if snap.deHandoff then
                        ADDONSELF.sync:BroadcastNoBeneficiary(idx, rrid, true, iLink)
                    end
                end
            end
        end
        self:OnLedgerItemsChange()
        if snap.deHandoff then
            return true, "trade_de_retarget"
        end
        return true, "trade_beneficiary_retarget"
    end

    -- 골드 > 0: 맨 앞(가장 작은 장부 인덱스 = 먼저 루팅된 줄)에 낙찰을 반영하고, 나머지 0원 매칭 줄만 제거.
    -- (기존: 전부 Remove 후 AddLoot로 맨 뒤에 넣어 목록 순서가 바뀜)
    table.sort(indices, function(a, b)
        return a < b
    end)
    local keepIdx = indices[1]
    local keptRow = ledger.items[keepIdx]
    if not keptRow then
        return false
    end

    local totalCount = 0
    for _, idx in ipairs(indices) do
        local row = ledger.items[idx]
        if row then
            totalCount = totalCount + (tonumber(row.detail and row.detail.count) or 1)
        end
    end
    if totalCount < 1 then
        totalCount = #indices
    end

    keptRow.winner = buyer
    keptRow.cost = money
    keptRow.saleState = SALE_STATE_CONFIRMED
    if not keptRow.detail then
        keptRow.detail = {
            type = DETAIL_TYPE_ITEM,
            item = (type(snap.item) == "string" and snap.item ~= "") and snap.item or "",
            reliableItemID = rid,
            count = math.max(1, totalCount),
        }
    else
        keptRow.detail.count = totalCount
        if type(snap.item) == "string" and snap.item ~= "" then
            keptRow.detail.item = snap.item
        end
        if keptRow.detail.type ~= DETAIL_TYPE_ITEM then
            keptRow.detail.type = DETAIL_TYPE_ITEM
        end
        if not keptRow.detail.reliableItemID then
            keptRow.detail.reliableItemID = rid
        end
    end

    if ADDONSELF.sync then
        local rrid = ledgerRowItemReliableId(keptRow) or rid
        local iLink = (keptRow.detail and keptRow.detail.item) or ""
        normalizeLedgerParticipantFields(keptRow)
        ADDONSELF.sync:BroadcastWinner(keepIdx, rrid, buyer, iLink)
        ADDONSELF.sync:BroadcastCost(keepIdx, rrid, money, iLink, keptRow.detail.count)
        ADDONSELF.sync:BroadcastSaleState(keepIdx, rrid, keptRow.saleState, iLink)
    end

    for k = #indices, 1, -1 do
        local idx = indices[k]
        if idx ~= keepIdx then
            self:RemoveEntry(idx)
        end
    end

    self:OnLedgerItemsChange()
    return true, "trade_sale_merge"
end

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

local function creditAutoNoBeneficiary(itemType, detail, beneficiary, cost)
    if itemType ~= TYPE_CREDIT then
        return false
    end
    if detail and detail.isDisenchantResult == true then
        return true
    end
    if (tonumber(cost) or 0) ~= 0 then
        return false
    end
    return ADDONSELF.IsDisenchantHandoffBeneficiary(beneficiary or "")
end

function db:AddEntry(type, detail, beneficiary, cost, saleState, suppressChange)
    local ledger = self:GetCurrentLedger()
    local nextSeq = (tonumber(ledger._nextSeq) or 0) + 1
    ledger._nextSeq = nextSeq

    local finalBeneficiary = beneficiary
    if type == TYPE_DEBIT and not beneficiary then
        finalBeneficiary = ""
    end

    local nb = creditAutoNoBeneficiary(type, detail, finalBeneficiary, cost)

    local row = {
        type = type,
        detail = detail or {},
        beneficiary = finalBeneficiary or "",
        cost = cost or 0,
        noBeneficiary = nb,
        seq = nextSeq,
        isTestMode = detail and detail.isTestMode == true or false,
    }
    row.saleState = saleState or normalizeLedgerSaleStateForItem(row)
    row.confirmed = normalizeLedgerConfirmedForEntry(row)
    if row.type == TYPE_CREDIT and row.detail and row.detail.type == DETAIL_TYPE_ITEM then
        local inferredWinner = ""
        if row.detail and row.detail.winner ~= nil then
            inferredWinner = tostring(row.detail.winner or "")
        elseif row.detail and row.detail.looter ~= nil then
            if row.saleState == SALE_STATE_OPEN and (tonumber(row.cost) or 0) <= 0 and not row.confirmed and not row.noBeneficiary then
                inferredWinner = ""
            else
                inferredWinner = tostring(finalBeneficiary or "")
            end
        elseif row.saleState == SALE_STATE_OPEN and (tonumber(row.cost) or 0) <= 0 and not row.confirmed and not row.noBeneficiary then
            inferredWinner = ""
        else
            inferredWinner = tostring(finalBeneficiary or "")
        end
        row.looter = tostring((row.detail and row.detail.looter) or finalBeneficiary or "")
        row.winner = inferredWinner
    else
        row.looter = tostring((row.detail and row.detail.looter) or finalBeneficiary or "")
        row.winner = tostring((row.detail and row.detail.winner) or finalBeneficiary or "")
    end
    normalizeLedgerParticipantFields(row)
    table.insert(ledger["items"], row)

    if ADDONSELF.sync then
        ADDONSELF.sync:BroadcastAdd(type, detail, finalBeneficiary or "", cost or 0, nb, nextSeq, row.saleState, row.confirmed, row.looter, row.winner, row.isTestMode)
    end

    if not suppressChange then
        self:OnLedgerItemsChange()
    end
end

function db:RemoveEntry(idx)
    local ledger = self:GetCurrentLedger()
    local item = ledger["items"][idx]
    local rid = item and item.detail and item.detail.reliableItemID
    local iLink = item and item.detail and item.detail.item
    table.remove(ledger["items"], idx)

    if ADDONSELF.sync then
        ADDONSELF.sync:BroadcastRemove(idx, rid, iLink)
    end

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

-- WoW ItemClass: Recipe = 9 (도안·제작법·도면 등)
local IRA_ITEM_CLASS_RECIPE = (type(_G.LE_ITEM_CLASS_RECIPE) == "number" and _G.LE_ITEM_CLASS_RECIPE) or 9
local IRA_QUALITY_UNCOMMON = 2 -- 고급(녹색)
local IRA_QUALITY_RARE = 3     -- 희귀(파랑)

--- 자동 수집: 도안류는 녹색 이상, 장비·재료 등은 희귀 이상으로 구분
local function iraItemLooksRecipeLikeForAutoLoot(itemRef, itemTypeStr, itemSubTypeStr)
    -- 빠른 경로: GetItemInfoInstant 의 6번째 반환값 itemClassID 로 정확히 판정한다.
    -- pcall 은 (success, itemID, itemType, itemSubType, itemEquipLoc, icon, itemClassID, itemSubClassID) 를 돌려주므로 언더스코어 5개로 itemClassID 자리를 맞춰야 한다.
    if type(itemRef) == "string" and itemRef ~= "" and type(GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, classID = pcall(GetItemInfoInstant, itemRef)
        if ok and tonumber(classID) == IRA_ITEM_CLASS_RECIPE then
            return true
        end
    end
    -- 폴백: 지역화 문자열 매칭 (캐시 미반영·Instant 실패 시 보조)
    if itemTypeStr and itemTypeStr ~= "" then
        local s = itemTypeStr
        local l = strlower(s)
        if l:find("recipe", 1, true) or l:find("formula", 1, true) or l:find("pattern", 1, true) or l:find("schematic", 1, true) or l:find("manual", 1, true) then
            return true
        end
        if s:find("제작") or s:find("레시피") or s:find("도안") or s:find("도면") or s:find("공식") or s:find("기술서") or s:find("비법서") then
            return true
        end
        if s:find("요리법") or s:find("주문식") or s:find("약제") then
            return true
        end
    end
    if itemSubTypeStr and itemSubTypeStr ~= "" then
        local l = strlower(itemSubTypeStr)
        if l:find("recipe", 1, true) or l:find("book", 1, true) then
            return true
        end
    end
    return false
end

--- 자동 수집·수동 추가 공통: 희귀+ 또는 녹색 도안류만 허용 (하급 0 제외)
local function iraNonForcePickupQualityAllows(itemLink, itemRarity, itemType, itemSubType)
    local q = tonumber(itemRarity)
    if q == 0 then
        return false
    end
    if q ~= nil then
        local ref = itemLink
        local recipeLike = iraItemLooksRecipeLikeForAutoLoot(ref, itemType, itemSubType)
        if recipeLike then
            if q < IRA_QUALITY_UNCOMMON then
                return false
            end
        else
            if q < IRA_QUALITY_RARE then
                return false
            end
        end
    end
    return true
end

--- +아이템·Ctrl+클릭 등 UI에서 `AddLoot(..., force)` 전에 동일 규칙으로 선검사
function ADDONSELF.ItemPassesLedgerPickupQualityRules(item)
    if type(item) ~= "string" or item == "" then
        return false
    end
    if not item:match("item:(%d+)") and not item:find("|Hitem:") then
        return false
    end
    local _, itemLink, itemRarity, _, _, itemType, itemSubType = GetItemInfo(item)
    if not itemLink and type(item) == "string" and item:find("|Hitem:%d+") then
        itemLink = item
        if not itemRarity or itemRarity < 0 then
            itemRarity = 0
        end
    end
    if not itemLink then
        return false
    end
    return iraNonForcePickupQualityAllows(itemLink, itemRarity, itemType, itemSubType)
end

--- 장부 목록 `고급+` 필터·UI와 자동 수집 도안 판별 공통 (링크만 넘기면 GetItemInfo로 type 보강)
function ADDONSELF.ItemLooksRecipeLikeForAutoLoot(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return false
    end
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    return iraItemLooksRecipeLikeForAutoLoot(itemLink, itemType, itemSubType)
end

-- 성공 시 true, 미반영(필터/링크 오류 등) 시 false — 호출부에서 공대 알림 등과 일치시키기 위해 사용
function db:AddLoot(item, count, beneficiary, cost, force, skipZeroPrecreditStrip, saleStateOverride)
    -- 링크에서 직접 itemID 추출을 우선적으로 시도
    local itemIDFromLink = nil
    if type(item) == "string" then
        itemIDFromLink = item:match("item:(%d+)")
    end

    -- GetItemInfo는 이름만 얻고 ID는 링크에서 직접 추출 (WoW Classic 버그 회피)
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType = GetItemInfo(item)

    -- 링크에서 ID 추출 실패 시
    if not itemIDFromLink then
        return false
    end

    -- itemID는 링크에서 추출한 값을 사용
    local itemID = tonumber(itemIDFromLink)

    -- 링크에서 추출한 ID를 reliableItemID로 사용
    local reliableItemID = itemID

    -- 거래 직후 등 캐시가 비어 GetItemInfo가 nil이어도, 하이퍼링크 문자열이면 그대로 사용
    if not itemLink and type(item) == "string" and item:find("|Hitem:%d+") then
        itemLink = item
        if not itemRarity or itemRarity < 0 then
            itemRarity = 0
        end
    end

    if not itemLink then
        return false
    end

    -- 품질(장부 목록 고급+ 필터는 희귀+녹색도안 / 희귀+·영웅+ 는 최소 품질) — 아래는 자동 수집
    -- 자동 수집(force 아님): 도안류→고급(2) 이상, 그 외→희귀(3) 이상. 하급(0) 제외.
    -- force 거래 등은 품질 무시(하급도 기록 가능)
    if force ~= true then
        if not iraNonForcePickupQualityAllows(itemLink, itemRarity, itemType, itemSubType) then
            return false
        end
    end

    -- 거래 완료 force 입력: 같은 itemID·구매자·낙찰가로 수 초 내 재호출이면 한 줄만 유지
    if force == true then
        local c = math.floor(tonumber(cost) or 0)
        if c > 0 then
            local ben = tostring(beneficiary or "")
            local short = ben:match("^([^%-]+)") or ben
            short = string.lower(short)
            local dedupKey = tostring(reliableItemID) .. "\0" .. short .. "\0" .. tostring(c)
            local now = GetTime()
            if dedupKey == lastTradeForcedLootKey and (now - lastTradeForcedLootTime) < TRADE_FORCED_LOOT_DEDUP_SEC then
                return true
            end
            lastTradeForcedLootKey = dedupKey
            lastTradeForcedLootTime = now
            -- ApplyPlayerToTargetTradeSnap 에서 판매자·수량 맞춰 이미 지웠으면 생략
            if not skipZeroPrecreditStrip then
                local ledger = self:GetCurrentLedger()
                local rmIdx = findFirstZeroCostCreditIndexForItemId(ledger, reliableItemID)
                if rmIdx then
                    self:RemoveEntry(rmIdx)
                end
            end
        end
    end

    -- 모든 필터링 통과: 아이템 추가
    self:AddEntry(TYPE_CREDIT, {
        item = itemLink,
        type = DETAIL_TYPE_ITEM,
        count = count or 1,
        reliableItemID = reliableItemID,  -- 안정적인 아이템 ID 저장
    }, beneficiary, cost, saleStateOverride)
    return true
end

function db:SetItemNoBeneficiary(itemIdx, noBeneficiary, suppressChange)
    local ledger = self:GetCurrentLedger()
    if ledger["items"] and ledger["items"][itemIdx] then
        local row = ledger["items"][itemIdx]
        local want = noBeneficiary and true or false
        if (row.noBeneficiary and true or false) == want then
            return
        end
        row.noBeneficiary = want
        normalizeLedgerParticipantFields(row)
        -- 실제 데이터베이스에도 저장 (전역 변수 보호 강화)
        if type(IberisRaidAuctionDatabase) == "table" then
            local currentLedgerIdx = IberisRaidAuctionDatabase["current"]
            if currentLedgerIdx and type(IberisRaidAuctionDatabase["ledgers"]) == "table" and
               type(IberisRaidAuctionDatabase["ledgers"][currentLedgerIdx]) == "table" and
               type(IberisRaidAuctionDatabase["ledgers"][currentLedgerIdx]["items"]) == "table" and
               type(IberisRaidAuctionDatabase["ledgers"][currentLedgerIdx]["items"][itemIdx]) == "table" then
                IberisRaidAuctionDatabase["ledgers"][currentLedgerIdx]["items"][itemIdx].noBeneficiary = want
            end
        end
        if not suppressChange then
            self:OnLedgerItemsChange()
        end
    end
end

-- SavedVariables·동기화 등으로 true / 1 / "1" 등이 섞일 수 있음
local function RawNoBeneficiaryIsSet(v)
    if v == true or v == 1 then
        return true
    end
    if v == "1" then
        return true
    end
    if type(v) == "string" and tonumber(v) == 1 then
        return true
    end
    return false
end

function db:IsNoBeneficiarySetOnRow(item)
    if not item then
        return false
    end
    return RawNoBeneficiaryIsSet(item.noBeneficiary)
end

function db:GetItemNoBeneficiary(itemIdx)
    local ledger = self:GetCurrentLedger()
    if ledger["items"] and ledger["items"][itemIdx] then
        return RawNoBeneficiaryIsSet(ledger["items"][itemIdx].noBeneficiary)
    end
    return false
end

--- 마력추출 관련 기록(0골 인계, 결과물)에 무득 플래그가 없으면 채움 (구버전 저장·동기화 호환).
function db:ApplyDisenchantHandoffNoBeneficiaryFlagsIfNeeded()
    local ledger = self:GetCurrentLedger()
    if not ledger or not ledger.items then
        return
    end
    local changed = false
    for _, it in ipairs(ledger.items) do
        local shouldBeNoBeneficiary = false
        if it.type == TYPE_CREDIT then
            if it.detail and it.detail.isDisenchantResult == true then
                shouldBeNoBeneficiary = true
            elseif (tonumber(it.cost) or 0) == 0 and ADDONSELF.IsDisenchantHandoffBeneficiary(it.beneficiary or "") then
                shouldBeNoBeneficiary = true
            end
        end
        if shouldBeNoBeneficiary and not self:IsNoBeneficiarySetOnRow(it) then
            it.noBeneficiary = true
            normalizeLedgerParticipantFields(it)
            changed = true
        end
    end
    if changed then
        self:OnLedgerItemsChange()
    end
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

ADDONSELF.GetLedgerLooterName = function(item)
    return getLedgerLooterName(item)
end

ADDONSELF.GetLedgerWinnerName = function(item)
    return getLedgerWinnerName(item)
end

ADDONSELF.GetLedgerDisplayBeneficiary = function(item)
    return getLedgerDisplayBeneficiary(item)
end

ADDONSELF.db = db
