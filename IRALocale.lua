local ADDONNAME, ADDONSELF = ...
ADDONSELF.addonName = ADDONNAME

local L = setmetatable({}, {
    __index = function(table, key)
        if key then
            table[key] = tostring(key)
        end
        return tostring(key)
    end,
})


ADDONSELF.L = L

--
-- Localization strings for IberisRaidAuction
--
local locale = GetLocale()

if locale == 'enUS' then
L["#Try to convert to item link"] = true
L["/iberisraidauction"] = true
L["[Unknown]"] = true
L["Auto record quality"] = true
L["Auto recording loot: In Raid Only"] = true
L["Auto recording loot: Off"] = true
L["Auto recording loot: On"] = true
L["Always auto record"] = "Always auto record"
L["Raid only auto record"] = "Raid only auto record"
L["Disable auto record"] = "Disable auto record"
L["Beneficiary"] = true
L["Clear"] = true
L["Close"] = true
L["Close text export"] = true
L["Compensation"] = true
L["Compensation added"] = true
-- L["Compensation: Aqual Quintessence"] = true
L["Compensation: DPS"] = true
L["Compensation: Healer"] = true
L["Compensation: Other"] = true
-- L["Compensation: Repait Bot"] = true
L["Compensation: Tank"] = true
L["Confirmed"] = true
L["Status"] = true
L["convert failed, text can be either item id or item name"] = true
L["Credit"] = true
L["Debit"] = true
L["Entry"] = true
L["etc."] = true
L["Expense"] = true
L["Export as text"] = true
L["Feedback"] = true
L["Gain per member"] = true
L["Gain per party"] = true
L["Item added"] = true
L["Last used"] = true
L["Member credit for subgroup"] = true
L["Net Profit"] = true
L["No Beneficiary"] = true
L["Other"] = true
L["Per Member"] = true
L["Per Member credit"] = true
L["Per Party credit"] = true
L["IberisRaidAuction"] = true
L["Raid sync sending"] = true
L["Remove all records?"] = true
L["Remove this record?"] = true
L["Only the raid leader can clear the ledger."] = true
L["Report"] = true
L["Revenue"] = true
L["Right click to remove record"] = true
L["Shift + item/name to add to record"] = true
L["Special Members"] = true
L["Split into"] = true
L["Split into (Current %d)"] = true
L["Subgroup total"] = true
L["TITLE"] = "IberisRaidAuction"
L["TOC_NOTES"] = "A ledger for GDKP/gold run raid."
L["toggle Auto recording on/off"] = true
L["Top [%d] contributors"] = true
L["Value"] = true
L["Toast ledger credit added"] = "A new revenue line was added at the top of the ledger."
L["Toast ledger debit added"] = "A new expense line was added at the top of the ledger."
L["Toast manual item added note"] = "Added to the ledger:"
L["Toast manual item no edit raid"] = "You cannot edit the ledger in this raid (no permission)."
L["Toast manual item add failed"] = "Could not add (invalid link, etc.). Waiting mode stays on."
L["Toast trade ledger purchase"] = "Trade (purchase) recorded in the ledger."
L["Toast trade ledger gold and beneficiary"] = "%d g — beneficiary: %s"
L["Toast trade ledger sale"] = "Trade (sale) recorded in the ledger."
L["Toast trade ledger buyer gold"] = "%s — %d g"
L["Toast trade ledger de add"] = "Disenchant handoff recorded (no bid)."
L["Toast trade ledger de retarget"] = "Beneficiary updated for disenchant handoff (no bid)."
L["Toast trade ledger beneficiary retarget"] = "0g trade: beneficiary updated."
L["Toast trade ledger new beneficiary"] = "Beneficiary: %s"

elseif locale == 'deDE' then
--[[Translation missing --]]
--[[ L["#Try to convert to item link"] = "#Try to convert to item link"--]] 
--[[Translation missing --]]
--[[ L["/iberisraidauction"] = "/iberisraidauction"--]] 
--[[Translation missing --]]
--[[ L["[Unknown]"] = "[Unknown]"--]] 
--[[Translation missing --]]
--[[ L["Auto record quality"] = "Auto record quality"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: In Raid Only"] = "Auto recording loot: In Raid Only"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: Off"] = "Auto recording loot: Off"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: On"] = "Auto recording loot: On"--]] 
--[[Translation missing --]]
--[[ L["Beneficiary"] = "Beneficiary"--]] 
--[[Translation missing --]]
--[[ L["Clear"] = "Clear"--]] 
--[[Translation missing --]]
--[[ L["Close"] = "Close"--]] 
--[[Translation missing --]]
--[[ L["Close text export"] = "Close text export"--]] 
--[[Translation missing --]]
--[[ L["Compensation"] = "Compensation"--]] 
--[[Translation missing --]]
--[[ L["Compensation added"] = "Compensation added"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Aqual Quintessence"] = "Compensation: Aqual Quintessence"--]] 
--[[Translation missing --]]
--[[ L["Compensation: DPS"] = "Compensation: DPS"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Healer"] = "Compensation: Healer"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Other"] = "Compensation: Other"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Repait Bot"] = "Compensation: Repait Bot"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Tank"] = "Compensation: Tank"--]] 
--[[Translation missing --]]
--[[ L["convert failed, text can be either item id or item name"] = "convert failed, text can be either item id or item name"--]] 
--[[Translation missing --]]
--[[ L["Credit"] = "Credit"--]] 
--[[Translation missing --]]
--[[ L["Debit"] = "Debit"--]] 
--[[Translation missing --]]
--[[ L["Entry"] = "Entry"--]] 
--[[Translation missing --]]
--[[ L["etc."] = "etc."--]] 
--[[Translation missing --]]
--[[ L["Expense"] = "Expense"--]] 
--[[Translation missing --]]
--[[ L["Export as text"] = "Export as text"--]] 
--[[Translation missing --]]
--[[ L["Feedback"] = "Feedback"--]] 
--[[Translation missing --]]
--[[ L["Gain per member"] = "Gain per member"--]] 
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
--[[Translation missing --]]
--[[ L["Item added"] = "Item added"--]] 
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
--[[Translation missing --]]
--[[ L["Net Profit"] = "Net Profit"--]] 
--[[Translation missing --]]
--[[ L["Other"] = "Other"--]] 
--[[Translation missing --]]
--[[ L["Per Member"] = "Per Member"--]] 
--[[Translation missing --]]
--[[ L["Per Member credit"] = "Per Member credit"--]] 
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
--[[Translation missing --]]
--[[ L["IberisRaidAuction"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["Remove all records?"] = "Remove all records?"--]] 
--[[Translation missing --]]
--[[ L["Remove this record?"] = "Remove this record?"--]] 
--[[Translation missing --]]
--[[ L["Report"] = "Report"--]] 
--[[Translation missing --]]
--[[ L["Revenue"] = "Revenue"--]] 
--[[Translation missing --]]
--[[ L["Right click to remove record"] = "Right click to remove record"--]] 
--[[Translation missing --]]
--[[ L["Shift + item/name to add to record"] = "Shift + item/name to add to record"--]] 
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
--[[Translation missing --]]
--[[ L["Split into"] = "Split into"--]] 
--[[Translation missing --]]
--[[ L["Split into (Current %d)"] = "Split into (Current %d)"--]] 
--[[Translation missing --]]
--[[ L["Subgroup total"] = "Subgroup total"--]] 
--[[Translation missing --]]
--[[ L["TITLE"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
--[[Translation missing --]]
--[[ L["toggle Auto recording on/off"] = "toggle Auto recording on/off"--]] 
--[[Translation missing --]]
--[[ L["Top [%d] contributors"] = "Top [%d] contributors"--]] 
--[[Translation missing --]]
--[[ L["Value"] = "Value"--]] 

elseif locale == 'esES' then
--[[Translation missing --]]
--[[ L["#Try to convert to item link"] = "#Try to convert to item link"--]] 
--[[Translation missing --]]
--[[ L["/iberisraidauction"] = "/iberisraidauction"--]] 
--[[Translation missing --]]
--[[ L["[Unknown]"] = "[Unknown]"--]] 
--[[Translation missing --]]
--[[ L["Auto record quality"] = "Auto record quality"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: In Raid Only"] = "Auto recording loot: In Raid Only"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: Off"] = "Auto recording loot: Off"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: On"] = "Auto recording loot: On"--]] 
--[[Translation missing --]]
--[[ L["Beneficiary"] = "Beneficiary"--]] 
--[[Translation missing --]]
--[[ L["Clear"] = "Clear"--]] 
--[[Translation missing --]]
--[[ L["Close"] = "Close"--]] 
--[[Translation missing --]]
--[[ L["Close text export"] = "Close text export"--]] 
--[[Translation missing --]]
--[[ L["Compensation"] = "Compensation"--]] 
--[[Translation missing --]]
--[[ L["Compensation added"] = "Compensation added"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Aqual Quintessence"] = "Compensation: Aqual Quintessence"--]] 
--[[Translation missing --]]
--[[ L["Compensation: DPS"] = "Compensation: DPS"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Healer"] = "Compensation: Healer"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Other"] = "Compensation: Other"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Repait Bot"] = "Compensation: Repait Bot"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Tank"] = "Compensation: Tank"--]] 
--[[Translation missing --]]
--[[ L["convert failed, text can be either item id or item name"] = "convert failed, text can be either item id or item name"--]] 
--[[Translation missing --]]
--[[ L["Credit"] = "Credit"--]] 
--[[Translation missing --]]
--[[ L["Debit"] = "Debit"--]] 
--[[Translation missing --]]
--[[ L["Entry"] = "Entry"--]] 
--[[Translation missing --]]
--[[ L["etc."] = "etc."--]] 
--[[Translation missing --]]
--[[ L["Expense"] = "Expense"--]] 
--[[Translation missing --]]
--[[ L["Export as text"] = "Export as text"--]] 
--[[Translation missing --]]
--[[ L["Feedback"] = "Feedback"--]] 
--[[Translation missing --]]
--[[ L["Gain per member"] = "Gain per member"--]] 
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
--[[Translation missing --]]
--[[ L["Item added"] = "Item added"--]] 
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
--[[Translation missing --]]
--[[ L["Net Profit"] = "Net Profit"--]] 
--[[Translation missing --]]
--[[ L["Other"] = "Other"--]] 
--[[Translation missing --]]
--[[ L["Per Member"] = "Per Member"--]] 
--[[Translation missing --]]
--[[ L["Per Member credit"] = "Per Member credit"--]] 
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
--[[Translation missing --]]
--[[ L["IberisRaidAuction"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["Remove all records?"] = "Remove all records?"--]] 
--[[Translation missing --]]
--[[ L["Remove this record?"] = "Remove this record?"--]] 
--[[Translation missing --]]
--[[ L["Report"] = "Report"--]] 
--[[Translation missing --]]
--[[ L["Revenue"] = "Revenue"--]] 
--[[Translation missing --]]
--[[ L["Right click to remove record"] = "Right click to remove record"--]] 
--[[Translation missing --]]
--[[ L["Shift + item/name to add to record"] = "Shift + item/name to add to record"--]] 
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
--[[Translation missing --]]
--[[ L["Split into"] = "Split into"--]] 
--[[Translation missing --]]
--[[ L["Split into (Current %d)"] = "Split into (Current %d)"--]] 
--[[Translation missing --]]
--[[ L["Subgroup total"] = "Subgroup total"--]] 
--[[Translation missing --]]
--[[ L["TITLE"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
--[[Translation missing --]]
--[[ L["toggle Auto recording on/off"] = "toggle Auto recording on/off"--]] 
--[[Translation missing --]]
--[[ L["Top [%d] contributors"] = "Top [%d] contributors"--]] 
--[[Translation missing --]]
--[[ L["Value"] = "Value"--]] 

elseif locale == 'esMX' then
--[[Translation missing --]]
--[[ L["#Try to convert to item link"] = "#Try to convert to item link"--]] 
--[[Translation missing --]]
--[[ L["/iberisraidauction"] = "/iberisraidauction"--]] 
--[[Translation missing --]]
--[[ L["[Unknown]"] = "[Unknown]"--]] 
--[[Translation missing --]]
--[[ L["Auto record quality"] = "Auto record quality"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: In Raid Only"] = "Auto recording loot: In Raid Only"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: Off"] = "Auto recording loot: Off"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: On"] = "Auto recording loot: On"--]] 
--[[Translation missing --]]
--[[ L["Beneficiary"] = "Beneficiary"--]] 
--[[Translation missing --]]
--[[ L["Clear"] = "Clear"--]] 
--[[Translation missing --]]
--[[ L["Close"] = "Close"--]] 
--[[Translation missing --]]
--[[ L["Close text export"] = "Close text export"--]] 
--[[Translation missing --]]
--[[ L["Compensation"] = "Compensation"--]] 
--[[Translation missing --]]
--[[ L["Compensation added"] = "Compensation added"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Aqual Quintessence"] = "Compensation: Aqual Quintessence"--]] 
--[[Translation missing --]]
--[[ L["Compensation: DPS"] = "Compensation: DPS"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Healer"] = "Compensation: Healer"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Other"] = "Compensation: Other"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Repait Bot"] = "Compensation: Repait Bot"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Tank"] = "Compensation: Tank"--]] 
--[[Translation missing --]]
--[[ L["convert failed, text can be either item id or item name"] = "convert failed, text can be either item id or item name"--]] 
--[[Translation missing --]]
--[[ L["Credit"] = "Credit"--]] 
--[[Translation missing --]]
--[[ L["Debit"] = "Debit"--]] 
--[[Translation missing --]]
--[[ L["Entry"] = "Entry"--]] 
--[[Translation missing --]]
--[[ L["etc."] = "etc."--]] 
--[[Translation missing --]]
--[[ L["Expense"] = "Expense"--]] 
--[[Translation missing --]]
--[[ L["Export as text"] = "Export as text"--]] 
--[[Translation missing --]]
--[[ L["Feedback"] = "Feedback"--]] 
--[[Translation missing --]]
--[[ L["Gain per member"] = "Gain per member"--]] 
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
--[[Translation missing --]]
--[[ L["Item added"] = "Item added"--]] 
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
--[[Translation missing --]]
--[[ L["Net Profit"] = "Net Profit"--]] 
--[[Translation missing --]]
--[[ L["Other"] = "Other"--]] 
--[[Translation missing --]]
--[[ L["Per Member"] = "Per Member"--]] 
--[[Translation missing --]]
--[[ L["Per Member credit"] = "Per Member credit"--]] 
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
--[[Translation missing --]]
--[[ L["IberisRaidAuction"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["Remove all records?"] = "Remove all records?"--]] 
--[[Translation missing --]]
--[[ L["Remove this record?"] = "Remove this record?"--]] 
--[[Translation missing --]]
--[[ L["Report"] = "Report"--]] 
--[[Translation missing --]]
--[[ L["Revenue"] = "Revenue"--]] 
--[[Translation missing --]]
--[[ L["Right click to remove record"] = "Right click to remove record"--]] 
--[[Translation missing --]]
--[[ L["Shift + item/name to add to record"] = "Shift + item/name to add to record"--]] 
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
--[[Translation missing --]]
--[[ L["Split into"] = "Split into"--]] 
--[[Translation missing --]]
--[[ L["Split into (Current %d)"] = "Split into (Current %d)"--]] 
--[[Translation missing --]]
--[[ L["Subgroup total"] = "Subgroup total"--]] 
--[[Translation missing --]]
--[[ L["TITLE"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
--[[Translation missing --]]
--[[ L["toggle Auto recording on/off"] = "toggle Auto recording on/off"--]] 
--[[Translation missing --]]
--[[ L["Top [%d] contributors"] = "Top [%d] contributors"--]] 
--[[Translation missing --]]
--[[ L["Value"] = "Value"--]] 

elseif locale == 'frFR' then
--[[Translation missing --]]
--[[ L["#Try to convert to item link"] = "#Try to convert to item link"--]] 
--[[Translation missing --]]
--[[ L["/iberisraidauction"] = "/iberisraidauction"--]] 
--[[Translation missing --]]
--[[ L["[Unknown]"] = "[Unknown]"--]] 
--[[Translation missing --]]
--[[ L["Auto record quality"] = "Auto record quality"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: In Raid Only"] = "Auto recording loot: In Raid Only"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: Off"] = "Auto recording loot: Off"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: On"] = "Auto recording loot: On"--]] 
--[[Translation missing --]]
--[[ L["Beneficiary"] = "Beneficiary"--]] 
--[[Translation missing --]]
--[[ L["Clear"] = "Clear"--]] 
--[[Translation missing --]]
--[[ L["Close"] = "Close"--]] 
--[[Translation missing --]]
--[[ L["Close text export"] = "Close text export"--]] 
--[[Translation missing --]]
--[[ L["Compensation"] = "Compensation"--]] 
--[[Translation missing --]]
--[[ L["Compensation added"] = "Compensation added"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Aqual Quintessence"] = "Compensation: Aqual Quintessence"--]] 
--[[Translation missing --]]
--[[ L["Compensation: DPS"] = "Compensation: DPS"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Healer"] = "Compensation: Healer"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Other"] = "Compensation: Other"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Repait Bot"] = "Compensation: Repait Bot"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Tank"] = "Compensation: Tank"--]] 
--[[Translation missing --]]
--[[ L["convert failed, text can be either item id or item name"] = "convert failed, text can be either item id or item name"--]] 
--[[Translation missing --]]
--[[ L["Credit"] = "Credit"--]] 
--[[Translation missing --]]
--[[ L["Debit"] = "Debit"--]] 
--[[Translation missing --]]
--[[ L["Entry"] = "Entry"--]] 
--[[Translation missing --]]
--[[ L["etc."] = "etc."--]] 
--[[Translation missing --]]
--[[ L["Expense"] = "Expense"--]] 
--[[Translation missing --]]
--[[ L["Export as text"] = "Export as text"--]] 
--[[Translation missing --]]
--[[ L["Feedback"] = "Feedback"--]] 
--[[Translation missing --]]
--[[ L["Gain per member"] = "Gain per member"--]] 
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
--[[Translation missing --]]
--[[ L["Item added"] = "Item added"--]] 
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
--[[Translation missing --]]
--[[ L["Net Profit"] = "Net Profit"--]] 
--[[Translation missing --]]
--[[ L["Other"] = "Other"--]] 
--[[Translation missing --]]
--[[ L["Per Member"] = "Per Member"--]] 
--[[Translation missing --]]
--[[ L["Per Member credit"] = "Per Member credit"--]] 
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
--[[Translation missing --]]
--[[ L["IberisRaidAuction"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["Remove all records?"] = "Remove all records?"--]] 
--[[Translation missing --]]
--[[ L["Remove this record?"] = "Remove this record?"--]] 
--[[Translation missing --]]
--[[ L["Report"] = "Report"--]] 
--[[Translation missing --]]
--[[ L["Revenue"] = "Revenue"--]] 
--[[Translation missing --]]
--[[ L["Right click to remove record"] = "Right click to remove record"--]] 
--[[Translation missing --]]
--[[ L["Shift + item/name to add to record"] = "Shift + item/name to add to record"--]] 
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
--[[Translation missing --]]
--[[ L["Split into"] = "Split into"--]] 
--[[Translation missing --]]
--[[ L["Split into (Current %d)"] = "Split into (Current %d)"--]] 
--[[Translation missing --]]
--[[ L["Subgroup total"] = "Subgroup total"--]] 
--[[Translation missing --]]
--[[ L["TITLE"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
--[[Translation missing --]]
--[[ L["toggle Auto recording on/off"] = "toggle Auto recording on/off"--]] 
--[[Translation missing --]]
--[[ L["Top [%d] contributors"] = "Top [%d] contributors"--]] 
--[[Translation missing --]]
--[[ L["Value"] = "Value"--]] 

elseif locale == 'itIT' then
--[[Translation missing --]]
--[[ L["#Try to convert to item link"] = "#Try to convert to item link"--]] 
--[[Translation missing --]]
--[[ L["/iberisraidauction"] = "/iberisraidauction"--]] 
--[[Translation missing --]]
--[[ L["[Unknown]"] = "[Unknown]"--]] 
--[[Translation missing --]]
--[[ L["Auto record quality"] = "Auto record quality"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: In Raid Only"] = "Auto recording loot: In Raid Only"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: Off"] = "Auto recording loot: Off"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: On"] = "Auto recording loot: On"--]] 
--[[Translation missing --]]
--[[ L["Beneficiary"] = "Beneficiary"--]] 
--[[Translation missing --]]
--[[ L["Clear"] = "Clear"--]] 
--[[Translation missing --]]
--[[ L["Close"] = "Close"--]] 
--[[Translation missing --]]
--[[ L["Close text export"] = "Close text export"--]] 
--[[Translation missing --]]
--[[ L["Compensation"] = "Compensation"--]] 
--[[Translation missing --]]
--[[ L["Compensation added"] = "Compensation added"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Aqual Quintessence"] = "Compensation: Aqual Quintessence"--]] 
--[[Translation missing --]]
--[[ L["Compensation: DPS"] = "Compensation: DPS"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Healer"] = "Compensation: Healer"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Other"] = "Compensation: Other"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Repait Bot"] = "Compensation: Repait Bot"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Tank"] = "Compensation: Tank"--]] 
--[[Translation missing --]]
--[[ L["convert failed, text can be either item id or item name"] = "convert failed, text can be either item id or item name"--]] 
--[[Translation missing --]]
--[[ L["Credit"] = "Credit"--]] 
--[[Translation missing --]]
--[[ L["Debit"] = "Debit"--]] 
--[[Translation missing --]]
--[[ L["Entry"] = "Entry"--]] 
--[[Translation missing --]]
--[[ L["etc."] = "etc."--]] 
--[[Translation missing --]]
--[[ L["Expense"] = "Expense"--]] 
--[[Translation missing --]]
--[[ L["Export as text"] = "Export as text"--]] 
--[[Translation missing --]]
--[[ L["Feedback"] = "Feedback"--]] 
--[[Translation missing --]]
--[[ L["Gain per member"] = "Gain per member"--]] 
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
--[[Translation missing --]]
--[[ L["Item added"] = "Item added"--]] 
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
--[[Translation missing --]]
--[[ L["Net Profit"] = "Net Profit"--]] 
--[[Translation missing --]]
--[[ L["Other"] = "Other"--]] 
--[[Translation missing --]]
--[[ L["Per Member"] = "Per Member"--]] 
--[[Translation missing --]]
--[[ L["Per Member credit"] = "Per Member credit"--]] 
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
--[[Translation missing --]]
--[[ L["IberisRaidAuction"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["Remove all records?"] = "Remove all records?"--]] 
--[[Translation missing --]]
--[[ L["Remove this record?"] = "Remove this record?"--]] 
--[[Translation missing --]]
--[[ L["Report"] = "Report"--]] 
--[[Translation missing --]]
--[[ L["Revenue"] = "Revenue"--]] 
--[[Translation missing --]]
--[[ L["Right click to remove record"] = "Right click to remove record"--]] 
--[[Translation missing --]]
--[[ L["Shift + item/name to add to record"] = "Shift + item/name to add to record"--]] 
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
--[[Translation missing --]]
--[[ L["Split into"] = "Split into"--]] 
--[[Translation missing --]]
--[[ L["Split into (Current %d)"] = "Split into (Current %d)"--]] 
--[[Translation missing --]]
--[[ L["Subgroup total"] = "Subgroup total"--]] 
--[[Translation missing --]]
--[[ L["TITLE"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
--[[Translation missing --]]
--[[ L["toggle Auto recording on/off"] = "toggle Auto recording on/off"--]] 
--[[Translation missing --]]
--[[ L["Top [%d] contributors"] = "Top [%d] contributors"--]] 
--[[Translation missing --]]
--[[ L["Value"] = "Value"--]] 

elseif locale == 'koKR' then
L["#Try to convert to item link"] = "#물품등급을 자동으로 기록"
L["/iberisraidauction"] = "/iberisraidauction"
L["[Unknown]"] = "[알수없음]"
L["Auto record quality"] = "자동으로 기록될 물품등급"
--[[Translation missing --]]
L["Auto recording loot: In Raid Only"] = "공격대일 경우 자동 기록"
L["Auto recording loot: Off"] = "아이템 습득 시 자동 기록 끄기"
L["Auto recording loot: On"] = "아이템 습득 시 자동 기록 켜기"
L["Always auto record"] = "항상 자동 기록"
L["Raid only auto record"] = "공격대에서만 자동 기록"
L["Disable auto record"] = "자동 기록 비활성화"
L["Beneficiary"] = "획득자"
L["Clear"] = "전체삭제"
L["Close"] = "닫기"
L["Close text export"] = "거래기록 닫기"
L["Compensation"] = "보상"
L["Compensation added"] = "보상 추가"
-- L["Compensation: Aqual Quintessence"] = "보상: 물의 정기"
L["Compensation: DPS"] = "보상: 딜러"
L["Compensation: Healer"] = "보상: 힐러"
L["Compensation: Other"] = "보상: 기타"
-- L["Compensation: Repait Bot"] = "보상: 로봇 수리"
L["Compensation: Tank"] = "보상: 탱커"
L["Confirmed"] = "확정"
L["Status"] = "상태"
L["convert failed, text can be either item id or item name"] = "전환 실패, 명칭이 물품의 ID나 물품의 이름이 됨"
L["Credit"] = "수익"
L["Debit"] = "지출"
L["Entry"] = "아이템"
L["etc."] = "등..."
L["Expense"] = "총지출"
L["Export as text"] = "거래기록 확인"
L["Feedback"] = "피드백"
L["Gain per member"] = "개인당"
L["Gain per party"] = ""
L["Item added"] = "추가한 물품"
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
L["Net Profit"] = "총수입"
L["Other"] = "기타"
L["Per Member"] = "개인당"
L["Per Member credit"] = "개인당"
L["Per Party credit"] = ""
L["IberisRaidAuction"] = "IberisRaidAuction"
L["Raid sync sending"] = "공격대 동기화 전송"
L["Remove all records?"] = "모든 기록을 삭제하시겠습니까?"
L["Remove this record?"] = "이 기록의 삭제를 확인?"
L["Only the raid leader can clear the ledger."] = "공격대장만 장부를 전체 삭제할 수 있습니다."
L["Report"] = "방송"
L["Revenue"] = "총수익"
L["Right click to remove record"] = "오른쪽 버튼 클릭하면 기록 삭제"
L["Shift + item/name to add to record"] = "Shift + 인명/물품 기록에 자동으로 첨가"
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
L["Split into"] = "분배 인원 설정"
L["Split into (Current %d)"] = "분배 인원 설정 (현재 %d명)"
L["Distribute All"] = "모두 분배"
L["No Beneficiary"] = "무득"
--[[Translation missing --]]
--[[ L["Subgroup total"] = "Subgroup total"--]] 
L["TITLE"] = "IberisRaidAuction"
L["TOC_NOTES"] = "골드 분배 장부 애드온"
L["toggle Auto recording on/off"] = "습득시 자동기록 켜기/끄기"
L["Top [%d] contributors"] = "획득자 [%d] 명"
L["Value"] = "낙찰가"
L["Toast ledger credit added"] = "새 수익 줄을 장부 맨 위에 추가했습니다."
L["Toast ledger debit added"] = "새 지출 줄을 장부 맨 위에 추가했습니다."
L["Toast manual item added note"] = "장부에 추가했습니다."
L["Toast manual item no edit raid"] = "공격대에서 편집 권한이 없습니다."
L["Toast manual item add failed"] = "추가 실패(링크 인식 불가 등). 모드를 유지합니다."
L["Toast trade ledger purchase"] = "구매 거래로 장부에 반영했습니다."
L["Toast trade ledger gold and beneficiary"] = "%d골드 · 득자 %s"
L["Toast trade ledger sale"] = "낙찰 거래로 장부에 반영했습니다."
L["Toast trade ledger buyer gold"] = "%s님 · %d골드"
L["Toast trade ledger de add"] = "마력추출 인계로 장부에 반영했습니다(무득)."
L["Toast trade ledger de retarget"] = "마력추출 인계로 득자·무득 처리했습니다."
L["Toast trade ledger beneficiary retarget"] = "0골드 거래로 득자만 갱신했습니다."
L["Toast trade ledger new beneficiary"] = "득자: %s"

elseif locale == 'ptBR' then
--[[Translation missing --]]
--[[ L["#Try to convert to item link"] = "#Try to convert to item link"--]] 
--[[Translation missing --]]
--[[ L["/iberisraidauction"] = "/iberisraidauction"--]] 
--[[Translation missing --]]
--[[ L["[Unknown]"] = "[Unknown]"--]] 
--[[Translation missing --]]
--[[ L["Auto record quality"] = "Auto record quality"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: In Raid Only"] = "Auto recording loot: In Raid Only"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: Off"] = "Auto recording loot: Off"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: On"] = "Auto recording loot: On"--]] 
--[[Translation missing --]]
--[[ L["Beneficiary"] = "Beneficiary"--]] 
--[[Translation missing --]]
--[[ L["Clear"] = "Clear"--]] 
--[[Translation missing --]]
--[[ L["Close"] = "Close"--]] 
--[[Translation missing --]]
--[[ L["Close text export"] = "Close text export"--]] 
--[[Translation missing --]]
--[[ L["Compensation"] = "Compensation"--]] 
--[[Translation missing --]]
--[[ L["Compensation added"] = "Compensation added"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Aqual Quintessence"] = "Compensation: Aqual Quintessence"--]] 
--[[Translation missing --]]
--[[ L["Compensation: DPS"] = "Compensation: DPS"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Healer"] = "Compensation: Healer"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Other"] = "Compensation: Other"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Repait Bot"] = "Compensation: Repait Bot"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Tank"] = "Compensation: Tank"--]] 
--[[Translation missing --]]
--[[ L["convert failed, text can be either item id or item name"] = "convert failed, text can be either item id or item name"--]] 
--[[Translation missing --]]
--[[ L["Credit"] = "Credit"--]] 
--[[Translation missing --]]
--[[ L["Debit"] = "Debit"--]] 
--[[Translation missing --]]
--[[ L["Entry"] = "Entry"--]] 
--[[Translation missing --]]
--[[ L["etc."] = "etc."--]] 
--[[Translation missing --]]
--[[ L["Expense"] = "Expense"--]] 
--[[Translation missing --]]
--[[ L["Export as text"] = "Export as text"--]] 
--[[Translation missing --]]
--[[ L["Feedback"] = "Feedback"--]] 
--[[Translation missing --]]
--[[ L["Gain per member"] = "Gain per member"--]] 
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
--[[Translation missing --]]
--[[ L["Item added"] = "Item added"--]] 
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
--[[Translation missing --]]
--[[ L["Net Profit"] = "Net Profit"--]] 
--[[Translation missing --]]
--[[ L["Other"] = "Other"--]] 
--[[Translation missing --]]
--[[ L["Per Member"] = "Per Member"--]] 
--[[Translation missing --]]
--[[ L["Per Member credit"] = "Per Member credit"--]] 
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
--[[Translation missing --]]
--[[ L["IberisRaidAuction"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["Remove all records?"] = "Remove all records?"--]] 
--[[Translation missing --]]
--[[ L["Remove this record?"] = "Remove this record?"--]] 
--[[Translation missing --]]
--[[ L["Report"] = "Report"--]] 
--[[Translation missing --]]
--[[ L["Revenue"] = "Revenue"--]] 
--[[Translation missing --]]
--[[ L["Right click to remove record"] = "Right click to remove record"--]] 
--[[Translation missing --]]
--[[ L["Shift + item/name to add to record"] = "Shift + item/name to add to record"--]] 
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
--[[Translation missing --]]
--[[ L["Split into"] = "Split into"--]] 
--[[Translation missing --]]
--[[ L["Split into (Current %d)"] = "Split into (Current %d)"--]] 
--[[Translation missing --]]
--[[ L["Subgroup total"] = "Subgroup total"--]] 
--[[Translation missing --]]
--[[ L["TITLE"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
--[[Translation missing --]]
--[[ L["toggle Auto recording on/off"] = "toggle Auto recording on/off"--]] 
--[[Translation missing --]]
--[[ L["Top [%d] contributors"] = "Top [%d] contributors"--]] 
--[[Translation missing --]]
--[[ L["Value"] = "Value"--]] 

elseif locale == 'ruRU' then
L["#Try to convert to item link"] = "#Попробуйте преобразовать в ссылку элемента"
L["/iberisraidauction"] = "/iberisraidauction"
L["[Unknown]"] = "[Неизвестно]"
L["Auto record quality"] = "Автоматическое качество записи"
L["Auto recording loot: In Raid Only"] = "Автоматическая запись добычи: только в рейде"
L["Auto recording loot: Off"] = "Автоматическая запись добычи: Выкл."
L["Auto recording loot: On"] = "Автоматическая запись добычи: Вкл."
L["Beneficiary"] = "Бенефициарий"
L["Clear"] = "Очистить"
L["Close"] = "Закрыть"
L["Close text export"] = "Закрыть экспорт текста"
L["Compensation"] = "Компенсация"
L["Compensation added"] = "Компенсация добавлена"
-- L["Compensation: Aqual Quintessence"] = "Компенсация: Акваланг Квинтэссенция"
L["Compensation: DPS"] = "Компенсация: Боец"
L["Compensation: Healer"] = "Компенсация: Лекарь"
L["Compensation: Other"] = "Компенсация: Другое"
-- L["Compensation: Repait Bot"] = "Компенсации: Ремонтный бот"
L["Compensation: Tank"] = "Компенсация: Танк"
L["convert failed, text can be either item id or item name"] = "преобразование не удалось, текст может быть либо ID элемента или имя элемента"
L["Credit"] = "Кредит"
L["Debit"] = "Дебит"
L["Entry"] = "Вход"
L["etc."] = "и т.д."
L["Expense"] = "Расход"
L["Export as text"] = "Экспорт в виде текста"
L["Feedback"] = "Обратная связь"
L["Gain per member"] = "Прирост на одного участника"
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
L["Item added"] = "Пункт добавлен"
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
L["Net Profit"] = "Чистая прибыль"
L["Other"] = "Другое"
L["Per Member"] = "на одного члена"
--[[Translation missing --]]
--[[ L["Per Member credit"] = "Per Member credit"--]] 
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
L["IberisRaidAuction"] = "Рейдовая книга"
L["Remove all records?"] = "Удалить все записи?"
L["Remove this record?"] = "Удалить эту запись?"
L["Report"] = "Жалоба"
L["Revenue"] = "Доход"
L["Right click to remove record"] = "Щелкните правой кнопкой мыши, чтобы удалить запись"
L["Shift + item/name to add to record"] = "Shift + элемент/имя для добавления в запись"
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
L["Split into"] = "Разделить на"
L["Split into (Current %d)"] = "Разделить на (текущий %d)"
L["Subgroup total"] = "Всего подгрупп"
L["TITLE"] = "IberisRaidAuction"
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
L["toggle Auto recording on/off"] = "включение/выключение автоматической записи"
L["Top [%d] contributors"] = "Лучшие [%d] участники"
L["Value"] = "Значение"
L["Toast ledger credit added"] = "Новая строка дохода добавлена в начало журнала."
L["Toast ledger debit added"] = "Новая строка расхода добавлена в начало журнала."
L["Toast manual item added note"] = "Добавлено в журнал:"
L["Toast manual item no edit raid"] = "Нет прав на редактирование журнала в этом рейде."
L["Toast manual item add failed"] = "Не удалось добавить (неверная ссылка и т.д.). Режим ожидания остаётся."
L["Toast trade ledger purchase"] = "Покупка через обмен записана в журнал."
L["Toast trade ledger gold and beneficiary"] = "%d з — получатель: %s"
L["Toast trade ledger sale"] = "Продажа через обмен записана в журнал."
L["Toast trade ledger buyer gold"] = "%s — %d з"
L["Toast trade ledger de add"] = "Передача на распыление записана (без ставки)."
L["Toast trade ledger de retarget"] = "Получатель обновлён: передача на распыление (без ставки)."
L["Toast trade ledger beneficiary retarget"] = "Обмен за 0 з: обновлён получатель."
L["Toast trade ledger new beneficiary"] = "Получатель: %s"

elseif locale == 'zhCN' then
L["#Try to convert to item link"] = "#尝试转换为物品链接"
L["/iberisraidauction"] = "/gtuan"
L["[Unknown]"] = "[未知]"
L["Auto record quality"] = "自动记录物品等级"
L["Auto recording loot: In Raid Only"] = "自动拾取记录: 仅团队中"
L["Auto recording loot: Off"] = "自动拾取记录关闭"
L["Auto recording loot: On"] = "自动拾取记录开启"
L["Beneficiary"] = "获取人"
L["Clear"] = "清空"
L["Close"] = "关闭"
L["Close text export"] = "关闭文本模式"
L["Compensation"] = "补助"
L["Compensation added"] = "已经添补助"
-- L["Compensation: Aqual Quintessence"] = "补助: 水之精粹"
L["Compensation: DPS"] = "补助: 输出"
L["Compensation: Healer"] = "补助: 治疗"
L["Compensation: Other"] = "补助: 其他"
-- L["Compensation: Repait Bot"] = "补助: 修理机器人"
L["Compensation: Tank"] = "补助: 坦克"
L["convert failed, text can be either item id or item name"] = "转换失败, 名称可以是物品ID, 物品名称"
L["Credit"] = "收入"
L["Debit"] = "支出"
L["Entry"] = "条目"
L["etc."] = "等..."
L["Expense"] = "总支出"
L["Export as text"] = "导出为文本"
L["Feedback"] = "反馈"
L["Gain per member"] = "每人收入"
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
L["Item added"] = "已添加物品"
L["Last used"] = "上次使用"
L["Member credit for subgroup"] = "小队收入明细"
L["Net Profit"] = "净收入"
L["Other"] = "其他"
L["Per Member"] = "平均每人"
L["Per Member credit"] = "平均每人收入"
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
L["IberisRaidAuction"] = "金团账本"
L["Remove all records?"] = "确定清空所有记录?"
L["Remove this record?"] = "确定删除这条记录?"
L["Report"] = "广播"
L["Revenue"] = "总收入"
L["Right click to remove record"] = "右键点击记录删除"
L["Shift + item/name to add to record"] = "Shift + 人名/物品 自动添加到记录"
L["Special Members"] = "特别成员"
L["Split into"] = "分钱人数"
L["Split into (Current %d)"] = "分钱人数 (当前 %d)"
L["Subgroup total"] = "小队总和"
L["TITLE"] = "IberisRaidAuction"
L["TOC_NOTES"] = "A ledger for GDKP/gold run raid."
L["toggle Auto recording on/off"] = "开启/关闭自动拾取记录"
L["Top [%d] contributors"] = "贡献钱 [%d] 的老板"
L["Value"] = "费用"
L["Toast ledger credit added"] = "已在账本顶部添加新的收入条目。"
L["Toast ledger debit added"] = "已在账本顶部添加新的支出条目。"
L["Toast manual item added note"] = "已记入账本："
L["Toast manual item no edit raid"] = "在团队中无权限编辑账本。"
L["Toast manual item add failed"] = "添加失败（链接无效等）。仍保持等待模式。"
L["Toast trade ledger purchase"] = "已记录购买交易到账本。"
L["Toast trade ledger gold and beneficiary"] = "%d金 — 获得者：%s"
L["Toast trade ledger sale"] = "已记录拍卖交易到账本。"
L["Toast trade ledger buyer gold"] = "%s — %d金"
L["Toast trade ledger de add"] = "已记录附魔分解交接（无出价）。"
L["Toast trade ledger de retarget"] = "已更新为附魔分解交接（无出价）。"
L["Toast trade ledger beneficiary retarget"] = "0金交易：已更新获得者。"
L["Toast trade ledger new beneficiary"] = "获得者：%s"

elseif locale == 'zhTW' then
--[[Translation missing --]]
--[[ L["#Try to convert to item link"] = "#Try to convert to item link"--]] 
--[[Translation missing --]]
--[[ L["/iberisraidauction"] = "/iberisraidauction"--]] 
--[[Translation missing --]]
--[[ L["[Unknown]"] = "[Unknown]"--]] 
--[[Translation missing --]]
--[[ L["Auto record quality"] = "Auto record quality"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: In Raid Only"] = "Auto recording loot: In Raid Only"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: Off"] = "Auto recording loot: Off"--]] 
--[[Translation missing --]]
--[[ L["Auto recording loot: On"] = "Auto recording loot: On"--]] 
--[[Translation missing --]]
--[[ L["Beneficiary"] = "Beneficiary"--]] 
--[[Translation missing --]]
--[[ L["Clear"] = "Clear"--]] 
--[[Translation missing --]]
--[[ L["Close"] = "Close"--]] 
--[[Translation missing --]]
--[[ L["Close text export"] = "Close text export"--]] 
--[[Translation missing --]]
--[[ L["Compensation"] = "Compensation"--]] 
--[[Translation missing --]]
--[[ L["Compensation added"] = "Compensation added"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Aqual Quintessence"] = "Compensation: Aqual Quintessence"--]] 
--[[Translation missing --]]
--[[ L["Compensation: DPS"] = "Compensation: DPS"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Healer"] = "Compensation: Healer"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Other"] = "Compensation: Other"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Repait Bot"] = "Compensation: Repait Bot"--]] 
--[[Translation missing --]]
--[[ L["Compensation: Tank"] = "Compensation: Tank"--]] 
--[[Translation missing --]]
--[[ L["convert failed, text can be either item id or item name"] = "convert failed, text can be either item id or item name"--]] 
--[[Translation missing --]]
--[[ L["Credit"] = "Credit"--]] 
--[[Translation missing --]]
--[[ L["Debit"] = "Debit"--]] 
--[[Translation missing --]]
--[[ L["Entry"] = "Entry"--]] 
--[[Translation missing --]]
--[[ L["etc."] = "etc."--]] 
--[[Translation missing --]]
--[[ L["Expense"] = "Expense"--]] 
--[[Translation missing --]]
--[[ L["Export as text"] = "Export as text"--]] 
--[[Translation missing --]]
--[[ L["Feedback"] = "Feedback"--]] 
--[[Translation missing --]]
--[[ L["Gain per member"] = "Gain per member"--]] 
--[[Translation missing --]]
--[[ L["Gain per party"] = "Gain per party"--]] 
--[[Translation missing --]]
--[[ L["Item added"] = "Item added"--]] 
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
--[[Translation missing --]]
--[[ L["Net Profit"] = "Net Profit"--]] 
--[[Translation missing --]]
--[[ L["Other"] = "Other"--]] 
--[[Translation missing --]]
--[[ L["Per Member"] = "Per Member"--]] 
--[[Translation missing --]]
--[[ L["Per Member credit"] = "Per Member credit"--]] 
--[[Translation missing --]]
--[[ L["Per Party credit"] = "Per Party credit"--]] 
--[[Translation missing --]]
--[[ L["IberisRaidAuction"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["Remove all records?"] = "Remove all records?"--]] 
--[[Translation missing --]]
--[[ L["Remove this record?"] = "Remove this record?"--]] 
--[[Translation missing --]]
--[[ L["Report"] = "Report"--]] 
--[[Translation missing --]]
--[[ L["Revenue"] = "Revenue"--]] 
--[[Translation missing --]]
--[[ L["Right click to remove record"] = "Right click to remove record"--]] 
--[[Translation missing --]]
--[[ L["Shift + item/name to add to record"] = "Shift + item/name to add to record"--]] 
--[[Translation missing --]]
--[[ L["Special Members"] = "Special Members"--]] 
--[[Translation missing --]]
--[[ L["Split into"] = "Split into"--]] 
--[[Translation missing --]]
--[[ L["Split into (Current %d)"] = "Split into (Current %d)"--]] 
--[[Translation missing --]]
--[[ L["Subgroup total"] = "Subgroup total"--]] 
--[[Translation missing --]]
--[[ L["TITLE"] = "IberisRaidAuction"--]] 
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
--[[Translation missing --]]
--[[ L["toggle Auto recording on/off"] = "toggle Auto recording on/off"--]] 
--[[Translation missing --]]
--[[ L["Top [%d] contributors"] = "Top [%d] contributors"--]] 
--[[Translation missing --]]
--[[ L["Value"] = "Value"--]] 

end
