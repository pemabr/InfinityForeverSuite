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

function InfinityUtils:Warn(message, source)
	self:Warning(message, source)
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

-- Hide all child frames and fontstring/texture regions of a container
function InfinityUtils:ClearContainer(container)
	if not container then
		return
	end
	for _, child in ipairs({container:GetChildren()}) do
		if child and child.Hide then
			child:Hide()
		end
	end
	for _, region in ipairs({container:GetRegions()}) do
		if region and region.Hide then
			region:Hide()
		end
	end
end

-- Cross-client boss unit check (Forever 1.60.1 lacks UnitIsRaidBoss)
function InfinityUtils:IsRaidBoss(unit)
	if _G.issecretvalue and issecretvalue(unit) then return nil end
	if type(unit) ~= "string" then
		return false
	end
	if _G.UnitIsRaidBoss then
		local boss = _G.UnitIsRaidBoss(unit)
		if _G.issecretvalue and issecretvalue(boss) then return nil end
		return boss
	end
	local exists = UnitExists(unit)
	if _G.issecretvalue and issecretvalue(exists) then return nil end
	if not exists then
		return false
	end
	if unit:match("^boss%d+$") then
		return true
	end
	local classification = UnitClassification(unit)
	if _G.issecretvalue and issecretvalue(classification) then return nil end
	return classification == "worldboss"
end

-- Cross-client container helpers (Forever 1.60.1 uses C_Container)
function InfinityUtils:GetBagSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	end
	if _G.GetContainerNumSlots then
		return _G.GetContainerNumSlots(bag) or 0
	end
	return 0
end

function InfinityUtils:GetBagItemID(bag, slot)
	if C_Container and C_Container.GetContainerItemID then
		return C_Container.GetContainerItemID(bag, slot)
	end
	if _G.GetContainerItemID then
		return _G.GetContainerItemID(bag, slot)
	end
	return nil
end

function InfinityUtils:GetBagItemLink(bag, slot)
	if C_Container and C_Container.GetContainerItemLink then
		return C_Container.GetContainerItemLink(bag, slot)
	end
	if _G.GetContainerItemLink then
		return _G.GetContainerItemLink(bag, slot)
	end
	return nil
end

function InfinityUtils:GetBagItemInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then
			return info.iconFileID, info.stackCount
		end
		return nil, nil
	end
	if _G.GetContainerItemInfo then
		local texture, count = _G.GetContainerItemInfo(bag, slot)
		return texture, count
	end
	return nil, nil
end

-- Cross-client item helpers (Forever 1.60.1 uses C_Item)
function InfinityUtils:GetItemInfo(item)
	if C_Item and C_Item.GetItemInfo then
		return C_Item.GetItemInfo(item)
	end
	if _G.GetItemInfo then
		return _G.GetItemInfo(item)
	end
	return nil
end

function InfinityUtils:GetItemStats(itemLink)
	if C_Item and C_Item.GetItemStats then
		return C_Item.GetItemStats(itemLink)
	end
	if _G.GetItemStats then
		return _G.GetItemStats(itemLink)
	end
	return nil
end

function InfinityUtils:GetItemCount(item, includeBank, includeUses, includeReagentBank)
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(item, includeBank, includeUses, includeReagentBank) or 0
	end
	if _G.GetItemCount then
		return _G.GetItemCount(item, includeBank, includeUses, includeReagentBank) or 0
	end
	return 0
end

function InfinityUtils:GetItemIDFromLink(itemLink)
	if _G.GetItemInfoFromHyperlink then
		return _G.GetItemInfoFromHyperlink(itemLink)
	end
	if type(itemLink) == "string" then
		return tonumber(itemLink:match("item:(%d+)"))
	end
	return nil
end

function InfinityUtils:CanUseCombatLogEvent()
	-- Midnight / Forever 1.60.1 blocks or restricts legacy COMBAT_LOG_EVENT_UNFILTERED
	if _G.issecretvalue or _G.C_DamageMeter or _G.C_EncounterTimeline then
		return false
	end
	if C_EventUtils and C_EventUtils.IsEventValid then
		return C_EventUtils.IsEventValid("COMBAT_LOG_EVENT_UNFILTERED")
	end
	return true
end

function InfinityUtils:GetSpellNameByID(spellID)
	if not spellID then return nil end
	if C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(spellID)
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		return info and info.name
	end
	if _G.GetSpellInfo then
		return (_G.GetSpellInfo(spellID))
	end
	return nil
end

function InfinityUtils:IsValidWaypoint(mapID, x, y)
	if _G.issecretvalue and (issecretvalue(mapID) or issecretvalue(x) or issecretvalue(y)) then return false end
	return type(mapID) == "number" and mapID == mapID and mapID > 0 and mapID < math.huge
		and mapID == math.floor(mapID) and type(x) == "number" and x == x and x >= 0 and x <= 1
		and type(y) == "number" and y == y and y >= 0 and y <= 1
end

function InfinityUtils:SetUserWaypoint(mapID, x, y, source)
	if not self:IsValidWaypoint(mapID, x, y) then
		self:Warning("Invalid or protected waypoint coordinates.", source)
		return false
	end
	if _G.InCombatLockdown and InCombatLockdown() then
		self:Warning("Cannot set a waypoint during combat.", source)
		return false
	end
	local map = _G.C_Map
	if not map or not map.CanSetUserWaypointOnMap or not map.SetUserWaypoint
		or not _G.UiMapPoint or not UiMapPoint.CreateFromCoordinates then
		self:Warning("Waypoints are unavailable on this client.", source)
		return false
	end
	local allowed = map.CanSetUserWaypointOnMap(mapID)
	if (_G.issecretvalue and issecretvalue(allowed)) or not allowed then
		self:Warning("Waypoints are unavailable on this map.", source)
		return false
	end
	local point = UiMapPoint.CreateFromCoordinates(mapID, x, y)
	if (_G.issecretvalue and issecretvalue(point)) or not point then
		self:Warning("Could not create the waypoint.", source)
		return false
	end
	local result = map.SetUserWaypoint(point)
	if (_G.issecretvalue and issecretvalue(result)) or result == false then
		self:Warning("Could not set the waypoint.", source)
		return false
	end
	if _G.C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	end
	return true
end

function InfinityUtils:GetPlayerCoords()
	if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
		local mapID = C_Map.GetBestMapForUnit("player")
		if mapID then
			local pos = C_Map.GetPlayerMapPosition(mapID, "player")
			if pos and pos.GetXY then
				local x, y = pos:GetXY()
				if x and y then
					return x * 100, y * 100, mapID
				end
			end
		end
	end
	if _G.GetPlayerMapPosition then
		local x, y = _G.GetPlayerMapPosition("player")
		if x and y then
			return x * 100, y * 100, 0
		end
	end
	return 0, 0, 0
end

return InfinityUtils
