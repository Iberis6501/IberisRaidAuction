local _, ADDONSELF = ...

-- Sync 기능 제거됨 (단독 사용 전제: 공대장 또는 공대장이 지정한 경매사만 사용).
-- 다른 모듈의 ADDONSELF.sync:Method() / ADDONSELF.sync.field 접근이 nil 에러 없이
-- 안전하게 no-op 되도록 메타테이블 기반 더미 객체 제공.

local NOOP = function() end
local TRUE_FN = function() return true end
local FALSE_FN = function() return false end

local syncMeta = {
    -- 정의되지 않은 메서드 접근은 자동으로 no-op 함수 반환.
    -- Broadcast*, SetEnabled, SendHello, UpdateHostStatus 등 모두 흡수.
    __index = function(_, k) return NOOP end,
}

local sync = setmetatable({
    enabled = false,
    assignedDistributor = nil,
    IsLedgerSyncMatchOK = TRUE_FN,
    IsSoloSynctest = FALSE_FN,
    IsAddonUserKnown = FALSE_FN,
    GetVersionMismatchSummary = function()
        return { localVersion = (ADDONSELF.GetAddOnVersion and ADDONSELF.GetAddOnVersion()) or "1.00",
                 outdated = {}, newer = {}, unknown = {} }
    end,
}, syncMeta)

ADDONSELF.sync = sync
ADDONSELF.Sync = sync
