-- PluribusCore Utilities
-- General utility functions used throughout the suite

PluribusUtils = {}

-- Logging function
function PluribusUtils:Log(level, message, source)
	if not level or level < PLURIBUS_CURRENT_LOG_LEVEL then
		return
	end
	
	source = source or "PluribusCore"
	local timestamp = date("%H:%M:%S")
	local levelName = ""
	
	if level == PLURIBUS_LOG_LEVEL.DEBUG then
		levelName = "DEBUG"
	elseif level == PLURIBUS_LOG_LEVEL.INFO then
		levelName = "INFO"
	elseif level == PLURIBUS_LOG_LEVEL.WARNING then
		levelName = "WARN"
	elseif level == PLURIBUS_LOG_LEVEL.ERROR then
		levelName = "ERROR"
	end
	
	print(string.format("|cff00ccff[%s]|r |cff9999ff%s|r |cffcccccc%s|r: %s", PLURIBUS_SUITE_NAME, timestamp, levelName, message))
end

-- Debug wrapper
function PluribusUtils:Debug(message, source)
	self:Log(PLURIBUS_LOG_LEVEL.DEBUG, message, source)
end

-- Info wrapper
function PluribusUtils:Info(message, source)
	self:Log(PLURIBUS_LOG_LEVEL.INFO, message, source)
end

-- Warning wrapper
function PluribusUtils:Warning(message, source)
	self:Log(PLURIBUS_LOG_LEVEL.WARNING, message, source)
end

-- Error wrapper
function PluribusUtils:Error(message, source)
	self:Log(PLURIBUS_LOG_LEVEL.ERROR, message, source)
end

-- Table operations
function PluribusUtils:DeepCopy(obj)
	if type(obj) ~= "table" then return obj end
	
	local result = {}
	for k, v in pairs(obj) do
		result[k] = self:DeepCopy(v)
	end
	return result
end

function PluribusUtils:TableMerge(base, override)
	local result = self:DeepCopy(base)
	for k, v in pairs(override) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = self:TableMerge(result[k], v)
		else
			result[k] = v
		end
	end
	return result
end

-- String operations
function PluribusUtils:Trim(str)
	return str:match("^%s*(.-)%s*$")
end

function PluribusUtils:Split(str, delimiter)
	local result = {}
	for part in str:gmatch("([^" .. delimiter .. "]+)") do
		table.insert(result, part)
	end
	return result
end

-- Validation
function PluribusUtils:IsValid(value)
	return value ~= nil and value ~= ""
end

function PluribusUtils:IsValidTable(tbl)
	return type(tbl) == "table" and #tbl > 0
end

-- Time operations
function PluribusUtils:GetTimeStamp()
	return time()
end

function PluribusUtils:FormatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	
	if hours > 0 then
		return string.format("%dh %dm %ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	else
		return string.format("%ds", secs)
	end
end

-- Number formatting
function PluribusUtils:FormatNumber(num)
	if not num then return "0" end
	
	local formatted = tostring(num)
	local k = tonumber(num) or num
	
	if k >= 1000000 then
		return string.format("%.1fM", k / 1000000)
	elseif k >= 1000 then
		return string.format("%.1fK", k / 1000)
	else
		return formatted
	end
end

-- Gold formatting
function PluribusUtils:FormatGold(copper)
	if not copper or copper == 0 then return "0g" end
	
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	local copper_remainder = copper % 100
	
	local result = ""
	if gold > 0 then
		result = gold .. "g"
	end
	if silver > 0 then
		result = result .. (result ~= "" and " " or "") .. silver .. "s"
	end
	if copper_remainder > 0 then
		result = result .. (result ~= "" and " " or "") .. copper_remainder .. "c"
	end
	
	return result ~= "" and result or "0c"
end

-- Color utilities
function PluribusUtils:GetQualityColor(quality)
	local colors = {
		[0] = "|cff9d9d9d",	-- Poor (grey)
		[1] = "|cffffffff",	-- Common (white)
		[2] = "|cff1eff00",	-- Uncommon (green)
		[3] = "|cff0070dd",	-- Rare (blue)
		[4] = "|cffa335ee",	-- Epic (purple)
		[5] = "|cffff8000",	-- Legendary (orange)
		[6] = "|cffe6cc80",	-- Artifact (tan)
	}
	return colors[quality] or "|cffffffff"
end

function PluribusUtils:GetQualityRGB(quality)
	local rgb = {
		[0] = { 0.62, 0.62, 0.62 },
		[1] = { 0.86, 0.90, 0.95 },
		[2] = { 0.12, 1.00, 0.00 },
		[3] = { 0.00, 0.44, 0.87 },
		[4] = { 0.64, 0.21, 0.93 },
		[5] = { 1.00, 0.50, 0.00 },
		[6] = { 0.90, 0.80, 0.50 },
	}
	local c = rgb[quality] or rgb[1]
	return c[1], c[2], c[3]
end

-- ============================================================================
-- Warcraft Forever 1.60.1 / Modern WoW API Compatibility Wrappers (Taint-Free)
-- ============================================================================

function PluribusUtils:GetItemInfo(item)
	if not item then return nil end
	if C_Item and C_Item.GetItemInfo then
		return C_Item.GetItemInfo(item)
	elseif GetItemInfo then
		return GetItemInfo(item)
	end
	return nil
end

function PluribusUtils:GetItemIcon(item)
	if not item then return "Interface\\Icons\\INV_Misc_QuestionMark" end
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, item)
		if ok and icon then return icon end
	end
	if GetItemIcon then
		local ok, icon = pcall(GetItemIcon, item)
		if ok and icon then return icon end
	end
	local _, _, _, _, _, _, _, _, _, tex = self:GetItemInfo(item)
	return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function PluribusUtils:SetTooltipItem(tooltip, itemID, itemLink)
	if not tooltip then return false end
	if itemLink and tooltip.SetHyperlink then
		local ok = pcall(tooltip.SetHyperlink, tooltip, itemLink)
		if ok then return true end
	end
	local id = tonumber(itemID)
	if id and id > 0 then
		if tooltip.SetItemByID then
			local ok = pcall(tooltip.SetItemByID, tooltip, id)
			if ok then return true end
		end
		if tooltip.SetHyperlink then
			local ok = pcall(tooltip.SetHyperlink, tooltip, "item:" .. tostring(id))
			if ok then return true end
		end
	end
	return false
end

function PluribusUtils:GetItemCount(item, includeBank, includeUses, includeReagentBank)
	if not item then return 0 end
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(item, includeBank, includeUses, includeReagentBank) or 0
	elseif GetItemCount then
		return GetItemCount(item, includeBank, includeUses, includeReagentBank) or 0
	end
	return 0
end

function PluribusUtils:GetItemStats(itemLink)
	if not itemLink then return {} end
	if C_Item and C_Item.GetItemStats then
		return C_Item.GetItemStats(itemLink) or {}
	elseif GetItemStats then
		return GetItemStats(itemLink) or {}
	end
	return {}
end

function PluribusUtils:GetItemIDFromHyperlink(link)
	if not link then return nil end
	if type(link) == "number" then return link end
	if GetItemInfoFromHyperlink then
		local ok, id = pcall(GetItemInfoFromHyperlink, link)
		if ok and tonumber(id) then
			return tonumber(id)
		end
	end
	if type(link) == "string" then
		local id = link:match("item:(%d+)")
		if id then return tonumber(id) end
		if tonumber(link) then return tonumber(link) end
	end
	return nil
end

function PluribusUtils:GetUnitAura(unit, index, filter)
	if not unit or not index then return nil end
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
		if aura then
			return aura.name, aura.icon, aura.applications, aura.dispelName, aura.duration, aura.expirationTime, aura.sourceUnit, aura.isStealable, aura.nameplateShowPersonal, aura.spellId, aura.canApplyAura, aura.isBossAura, aura.isFromPlayerOrPlayerPet, aura.nameplateShowAll
		end
		return nil
	elseif UnitAura then
		return UnitAura(unit, index, filter)
	elseif filter == "HARMFUL" and UnitDebuff then
		return UnitDebuff(unit, index)
	elseif UnitBuff then
		return UnitBuff(unit, index)
	end
	return nil
end

function PluribusUtils:GetSpellCooldown(spell)
	if not spell then return 0, 0, 1 end
	if C_Spell and C_Spell.GetSpellCooldown then
		local cd = C_Spell.GetSpellCooldown(spell)
		if cd then
			return cd.startTime or 0, cd.duration or 0, cd.isEnabled and 1 or 0
		end
		return 0, 0, 1
	elseif GetSpellCooldown then
		return GetSpellCooldown(spell)
	end
	return 0, 0, 1
end

function PluribusUtils:IsSecret(val)
	return issecretvalue ~= nil and issecretvalue(val) or false
end

function PluribusUtils:GetQuestLogCount()
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
		local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)
		if ok and type(count) == "number" then return count end
	elseif GetNumQuestLogEntries then
		local ok, count = pcall(GetNumQuestLogEntries)
		if ok and type(count) == "number" then return count end
	end
	return 0
end

function PluribusUtils:GetQuestLogEntry(index)
	if C_QuestLog and C_QuestLog.GetInfo then
		local ok, info = pcall(C_QuestLog.GetInfo, index)
		if ok and type(info) == "table" then
			return info.title, info.level or 0, info.isHeader, info.questID, info.isComplete
		end
		return nil
	elseif GetQuestLogTitle then
		local ok, title, level, _, isHeader, _, isComplete, _, questID = pcall(GetQuestLogTitle, index)
		if ok then
			return title, level or 0, isHeader, questID, isComplete
		end
	end
	return nil
end

function PluribusUtils:GetQuestTitleByID(questID)
	if not questID then return nil end
	if C_QuestLog and C_QuestLog.GetTitleForQuestID then
		local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
		if ok and title and title ~= "" then return title end
	end
	local count = self:GetQuestLogCount()
	for i = 1, count do
		local title, _, isHeader, qid = self:GetQuestLogEntry(i)
		if not isHeader and qid == questID and title then
			return title
		end
	end
	return nil
end

function PluribusUtils:GetQuestObjectives(questID)
	if not questID then return {} end
	if C_QuestLog and C_QuestLog.GetQuestObjectives then
		local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
		if ok and type(objs) == "table" then
			return objs
		end
	end
	return {}
end

function PluribusUtils:GetUnitMapPosition(unit)
	unit = unit or "player"
	if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
		local okMap, mapID = pcall(C_Map.GetBestMapForUnit, unit)
		if okMap and mapID then
			local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
			if okPos and pos and pos.GetXY then
				local x, y = pos:GetXY()
				if x and y then
					return x, y, mapID
				end
			end
		end
	end
	if GetPlayerMapPosition then
		local ok, x, y = pcall(GetPlayerMapPosition, unit)
		if ok and x and y then
			return x, y, nil
		end
	end
	return 0, 0, nil
end

return PluribusUtils
