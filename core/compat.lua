-- IberisRaidAuction: 클라이언트 호환 shim
-- Anniversary 1.15.4+ 에서 컨테이너 API + GetAddOnMetadata 가 C_Container/C_AddOns 로 이전됨.
-- 양방향 alias로 mainline/classic/anniversary 차이 흡수. 가장 먼저 로드되어야 함.

C_Container = C_Container or {}
C_AddOns = C_AddOns or {}

local containerGlobals = {
    "GetContainerNumSlots", "GetContainerItemInfo", "GetContainerItemID",
    "GetContainerItemLink", "GetContainerNumFreeSlots", "GetContainerItemDurability",
    "GetContainerItemQuestInfo", "GetContainerItemCooldown", "PickupContainerItem",
    "UseContainerItem", "SplitContainerItem", "SocketContainerItem",
    "ContainerIDToInventoryID",
}
for _, fn in ipairs(containerGlobals) do
    if _G[fn] and not C_Container[fn] then
        C_Container[fn] = _G[fn]
    elseif C_Container[fn] and not _G[fn] then
        _G[fn] = C_Container[fn]
    end
end

if _G.GetAddOnMetadata and not C_AddOns.GetAddOnMetadata then
    C_AddOns.GetAddOnMetadata = _G.GetAddOnMetadata
elseif C_AddOns.GetAddOnMetadata and not _G.GetAddOnMetadata then
    _G.GetAddOnMetadata = C_AddOns.GetAddOnMetadata
end
