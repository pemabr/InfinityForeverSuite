-- InfinityCore Utilities
-- General utility functions used throughout the suite

InfinityUtils = {}

-- Logging function
function InfinityUtils:Log(level, message, source)
	if not level or level < INFINITY_CURRENT_LOG_LEVEL then
		return
	end
	
	source = source or "InfinityCore"
	local timestamp = date("%H:%M:%S")
	local levelName = ""
	
	if level == INFINITY_LOG_LEVEL.DEBUG then
		levelName = "DEBUG"
	elseif level == INFINITY_LOG_LEVEL.INFO then
		levelName = "INFO"
	elseif level == INFINITY_LOG_LEVEL.WARNING then
		levelName = "WARN"
	elseif level == INFINITY_LOG_LEVEL.ERROR then
		levelName = "ERROR"
	end
	
	print(string.format("|cff00ccff[%s]|r |cff9999ff%s|r |cffcccccc%s|r: %s", INFINITY_SUITE_NAME, timestamp, levelName, message))
end

-- Debug wrapper
function InfinityUtils:Debug(message, source)
	self:Log(INFINITY_LOG_LEVEL.DEBUG, message, source)
end

-- Info wrapper
function InfinityUtils:Info(message, source)
	self:Log(INFINITY_LOG_LEVEL.INFO, message, source)
end

-- Warning wrapper
function InfinityUtils:Warning(message, source)
	self:Log(INFINITY_LOG_LEVEL.WARNING, message, source)
end

-- Error wrapper
function InfinityUtils:Error(message, source)
	self:Log(INFINITY_LOG_LEVEL.ERROR, message, source)
end

-- Table operations
function InfinityUtils:DeepCopy(obj)
	if type(obj) ~= "table" then return obj end
	
	local result = {}
	for k, v in pairs(obj) do
		result[k] = self:DeepCopy(v)
	end
	return result
end

function InfinityUtils:TableMerge(base, override)
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
function InfinityUtils:Trim(str)
	return str:match("^%s*(.-)%s*$")
end

function InfinityUtils:Split(str, delimiter)
	local result = {}
	for part in str:gmatch("([^" .. delimiter .. "]+)") do
		table.insert(result, part)
	end
	return result
end

-- Validation
function InfinityUtils:IsValid(value)
	return value ~= nil and value ~= ""
end

function InfinityUtils:IsValidTable(tbl)
	return type(tbl) == "table" and #tbl > 0
end

-- Time operations
function InfinityUtils:GetTimeStamp()
	return time()
end

function InfinityUtils:FormatTime(seconds)
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
function InfinityUtils:FormatNumber(num)
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
function InfinityUtils:FormatGold(copper)
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
function InfinityUtils:GetQualityColor(quality)
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

-- ============================================================================
-- Warcraft Forever 1.60.1 / Modern WoW API Compatibility Wrappers (Taint-Free)
-- ============================================================================

function InfinityUtils:GetItemInfo(item)
	if not item then return nil end
	if C_Item and C_Item.GetItemInfo then
		return C_Item.GetItemInfo(item)
	elseif GetItemInfo then
		return GetItemInfo(item)
	end
	return nil
end

function InfinityUtils:GetItemCount(item, includeBank, includeUses, includeReagentBank)
	if not item then return 0 end
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(item, includeBank, includeUses, includeReagentBank) or 0
	elseif GetItemCount then
		return GetItemCount(item, includeBank, includeUses, includeReagentBank) or 0
	end
	return 0
end

function InfinityUtils:GetItemStats(itemLink)
	if not itemLink then return {} end
	if C_Item and C_Item.GetItemStats then
		return C_Item.GetItemStats(itemLink) or {}
	elseif GetItemStats then
		return GetItemStats(itemLink) or {}
	end
	return {}
end

function InfinityUtils:GetItemIDFromHyperlink(link)
	if not link then return nil end
	if GetItemInfoFromHyperlink then
		return GetItemInfoFromHyperlink(link)
	end
	if type(link) == "number" then return link end
	if type(link) == "string" then
		return tonumber(link:match("item:(%d+)"))
	end
	return nil
end

function InfinityUtils:GetUnitAura(unit, index, filter)
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

function InfinityUtils:GetSpellCooldown(spell)
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

function InfinityUtils:IsSecret(val)
	return issecretvalue ~= nil and issecretvalue(val) or false
end

function InfinityUtils:GetQuestLogCount()
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
		local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)
		if ok and type(count) == "number" then return count end
	elseif GetNumQuestLogEntries then
		local ok, count = pcall(GetNumQuestLogEntries)
		if ok and type(count) == "number" then return count end
	end
	return 0
end

function InfinityUtils:GetQuestLogEntry(index)
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

function InfinityUtils:GetQuestTitleByID(questID)
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

function InfinityUtils:GetQuestObjectives(questID)
	if not questID then return {} end
	if C_QuestLog and C_QuestLog.GetQuestObjectives then
		local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
		if ok and type(objs) == "table" then
			return objs
		end
	end
	return {}
end

function InfinityUtils:GetUnitMapPosition(unit)
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

return InfinityUtils
