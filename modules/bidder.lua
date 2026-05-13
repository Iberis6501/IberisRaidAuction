-- IberisRaidAuction: 낙찰자 목록 (Phase 1 — 단순 데이터 모델)
-- 채팅 입찰 자동 파싱은 Phase 2-3에서 추가.
local IA = IberisRaidAuction
local M = {}
IA.modules.Bidder = M

function M:Add(name)
    if not name or name == "" then return end
    IberisRaidAuctionDB.bidders[name] = (IberisRaidAuctionDB.bidders[name] or 0) + 1
end

function M:Remove(name)
    if not name then return end
    IberisRaidAuctionDB.bidders[name] = nil
end

function M:Clear()
    wipe(IberisRaidAuctionDB.bidders)
end

function M:GetAll()
    local list = {}
    for name, count in pairs(IberisRaidAuctionDB.bidders) do
        list[#list + 1] = { name = name, count = count }
    end
    return list
end
