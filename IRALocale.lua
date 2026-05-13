local _, ADDONSELF = ...

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
-- Use https://www.curseforge.com/wow/addons/raidledger/localization to translate thanks
--
local locale = GetLocale()

if locale == 'enUs' then
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
L["Raid Ledger"] = true
L["Remove all records?"] = true
L["Remove this record?"] = true
L["Report"] = true
L["Revenue"] = true
L["Right click to remove record"] = true
L["Shift + item/name to add to record"] = true
L["Special Members"] = true
L["Split into"] = true
L["Split into (Current %d)"] = true
L["Subgroup total"] = true
L["TITLE"] = "Raid Ledger"
L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"
L["toggle Auto recording on/off"] = true
L["Top [%d] contributors"] = true
L["Value"] = true

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
--[[ L["Raid Ledger"] = "Raid Ledger"--]] 
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
--[[ L["TITLE"] = "Raid Ledger"--]] 
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
--[[ L["Raid Ledger"] = "Raid Ledger"--]] 
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
--[[ L["TITLE"] = "Raid Ledger"--]] 
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
--[[ L["Raid Ledger"] = "Raid Ledger"--]] 
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
--[[ L["TITLE"] = "Raid Ledger"--]] 
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
--[[ L["Raid Ledger"] = "Raid Ledger"--]] 
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
--[[ L["TITLE"] = "Raid Ledger"--]] 
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
--[[ L["Raid Ledger"] = "Raid Ledger"--]] 
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
--[[ L["TITLE"] = "Raid Ledger"--]] 
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
L["Beneficiary"] = "득자"
L["Clear"] = "전부지우기"
L["Close"] = "닫기"
L["Close text export"] = "텍스트 모드 닫기"
L["Compensation"] = "보상"
L["Compensation added"] = "보상 추가"
-- L["Compensation: Aqual Quintessence"] = "보상: 물의 정기"
L["Compensation: DPS"] = "보상:딜러"
L["Compensation: Healer"] = "보상: 힐러"
L["Compensation: Other"] = "보상: 기타"
-- L["Compensation: Repait Bot"] = "보상: 로봇 수리"
L["Compensation: Tank"] = "보상: 탱커"
L["convert failed, text can be either item id or item name"] = "전환 실패, 명칭이 물품의 ID나 물품의 이름이 됨"
L["Credit"] = "수익"
L["Debit"] = "지출"
L["Entry"] = "항목"
L["etc."] = "등..."
L["Expense"] = "총지출"
L["Export as text"] = "텍스트로 도출"
L["Feedback"] = "피드백"
L["Gain per member"] = "개인당 골드"
L["Gain per party"] = "파티당 골드"
L["Item added"] = "추가한 물품"
--[[Translation missing --]]
--[[ L["Last used"] = "Last used"--]] 
--[[Translation missing --]]
--[[ L["Member credit for subgroup"] = "Member credit for subgroup"--]] 
L["Net Profit"] = "최종 수입"
L["Other"] = "기타"
L["Per Member"] = "개인당 골드"
L["Per Member credit"] = "개인당 골드"
L["Per Party credit"] = "파티당 골드"
L["Raid Ledger"] = "Raid Ledger"
L["Remove all records?"] = "모든 기록의 비움을 확인?"
L["Remove this record?"] = "이 기록의 삭제를 확인?"
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
L["TITLE"] = "Raid Ledger 오즈공대 버전"
L["TOC_NOTES"] = "문제를 피드백 blessedrabies@gmail.com Kr Translator:QS"
L["toggle Auto recording on/off"] = "습득시 자동기록 켜기/끄기"
L["Top [%d] contributors"] = "득자 [%d]명"
L["Value"] = "골드"

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
--[[ L["Raid Ledger"] = "Raid Ledger"--]] 
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
--[[ L["TITLE"] = "Raid Ledger"--]] 
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
L["Raid Ledger"] = "Рейдовая книга"
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
L["TITLE"] = "Рейдовая книга"
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
L["toggle Auto recording on/off"] = "включение/выключение автоматической записи"
L["Top [%d] contributors"] = "Лучшие [%d] участники"
L["Value"] = "Значение"

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
L["Raid Ledger"] = "金团账本"
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
L["TITLE"] = "Raid Ledger 金团账本"
L["TOC_NOTES"] = "金团账本，帮你在金团中记账 反馈问题 blessedrabies@gmail.com"
L["toggle Auto recording on/off"] = "开启/关闭自动拾取记录"
L["Top [%d] contributors"] = "贡献钱 [%d] 的老板"
L["Value"] = "费用"

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
--[[ L["Raid Ledger"] = "Raid Ledger"--]] 
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
--[[ L["TITLE"] = "Raid Ledger"--]] 
--[[Translation missing --]]
--[[ L["TOC_NOTES"] = "A ledger for GDKP/gold run raid. Feedback: blessedrabies@gmail.com"--]] 
--[[Translation missing --]]
--[[ L["toggle Auto recording on/off"] = "toggle Auto recording on/off"--]] 
--[[Translation missing --]]
--[[ L["Top [%d] contributors"] = "Top [%d] contributors"--]] 
--[[Translation missing --]]
--[[ L["Value"] = "Value"--]] 

end
