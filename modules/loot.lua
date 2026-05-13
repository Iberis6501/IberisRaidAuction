-- IberisRaidAuction: CHAT_MSG_LOOT 파싱 — 시간순 전리품 기록
-- Blizzard GlobalStrings: LOOT_ITEM(_SELF)(_PUSHED)(_MULTIPLE) 패턴 활용.
local IA = IberisRaidAuction
local M = {}
IA.modules.Loot = M

local patterns = {}

local function toPattern(fmt)
    -- "%s" → "(.+)", "%d" → "(%d+)", literal "%%" → "%"
    local p = fmt:gsub("([%(%)%.%+%-%[%]%?%^%$])", "%%%1")
    p = p:gsub("%%%%", "\1")
    p = p:gsub("%%s", "(.+)")
    p = p:gsub("%%d", "(%%d+)")
    p = p:gsub("\1", "%%")
    return "^" .. p .. "$"
end

local function buildPatterns()
    local defs = {
        { LOOT_ITEM_SELF,                 false, false },
        { LOOT_ITEM_SELF_MULTIPLE,        false, true  },
        { LOOT_ITEM_PUSHED_SELF,          false, false },
        { LOOT_ITEM_PUSHED_SELF_MULTIPLE, false, true  },
        { LOOT_ITEM,                      true,  false },
        { LOOT_ITEM_MULTIPLE,             true,  true  },
        { LOOT_ITEM_PUSHED,               true,  false },
        { LOOT_ITEM_PUSHED_MULTIPLE,      true,  true  },
    }
    wipe(patterns)
    for _, d in ipairs(defs) do
        if d[1] then
            patterns[#patterns + 1] = { pat = toPattern(d[1]), hasPlayer = d[2], hasCount = d[3] }
        end
    end
end

local function parseLoot(msg)
    for _, def in ipairs(patterns) do
        local m1, m2, m3 = msg:match(def.pat)
        if m1 then
            if def.hasPlayer then
                return m1, m2, def.hasCount and tonumber(m3) or 1
            else
                return UnitName("player"), m1, def.hasCount and tonumber(m2) or 1
            end
        end
    end
end

local function getQuality(link)
    if not link or not GetItemInfo then return 0 end
    local _, _, quality = GetItemInfo(link)
    return quality or 0
end

function M:OnLoaded()
    buildPatterns()
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_LOOT")
    f:SetScript("OnEvent", function(_, _, msg)
        local player, link, count = parseLoot(msg)
        if not link then return end
        local q = getQuality(link)
        local minQ = (IberisRaidAuctionDB.settings and IberisRaidAuctionDB.settings.minQuality) or 0
        if q < minQ then return end
        IberisRaidAuctionDB.ledger[#IberisRaidAuctionDB.ledger + 1] = {
            time    = time(),
            player  = player,
            link    = link,
            count   = count or 1,
            quality = q,
            gold    = nil,    -- Phase 2 거래 매칭에서 채움
        }
        if IA.ui.Ledger and IA.ui.Ledger.Refresh then
            IA.ui.Ledger:Refresh()
        end
    end)
end
