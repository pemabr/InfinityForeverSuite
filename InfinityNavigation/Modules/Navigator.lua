local InfinityNavigator = {}
_G.InfinityNavigator = InfinityNavigator

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function ValidName(name)
	return type(name) == "string" and name:match("%S") and #name <= 100 and not name:find("[%c]")
end

function InfinityNavigator:Initialize()
	local db = InfinityCore:GetDatabase("InfinityNavigation")
	if type(db) ~= "table" then error("Navigation database unavailable") end
	if db.waypoints == nil then db.waypoints = {} end
	if type(db.waypoints) ~= "table" then error("Invalid saved waypoints") end
	for index, waypoint in pairs(db.waypoints) do
		if type(index) ~= "number" or index < 1 or index ~= math.floor(index)
			or type(waypoint) ~= "table" or not ValidName(waypoint.description)
			or not InfinityUtils:IsValidWaypoint(waypoint.mapID, waypoint.x, waypoint.y) then
			error("Invalid saved waypoint")
		end
	end
	self.waypoints = db.waypoints
end

function InfinityNavigator:AddWaypoint(x, y, mapID, description)
	description = Public(description)
	if not ValidName(description) or not InfinityUtils:IsValidWaypoint(mapID, x, y) then
		return false, "Invalid map ID, coordinates or name."
	end
	local waypoint = { x = x, y = y, mapID = mapID, description = description }
	self.waypoints[#self.waypoints + 1] = waypoint
	return true, waypoint
end

function InfinityNavigator:RemoveWaypoint(index)
	index = Public(index)
	if type(index) ~= "number" or index ~= index or index < 1 or index > #self.waypoints
		or index ~= math.floor(index) then return false end
	table.remove(self.waypoints, index)
	return true
end

function InfinityNavigator:ClearWaypoints()
	for i = #self.waypoints, 1, -1 do self.waypoints[i] = nil end
end

function InfinityNavigator:SetWaypoint(waypoint)
	waypoint = Public(waypoint)
	if type(waypoint) ~= "table" then
		InfinityUtils:Warning("Waypoint not found.", "Navigation")
		return false
	end
	return InfinityUtils:SetUserWaypoint(waypoint.mapID, waypoint.x, waypoint.y, "Navigation")
end

function InfinityNavigator:SetObjective(questID)
	questID = Public(questID)
	if type(questID) ~= "number" or questID ~= questID or questID <= 0
		or questID >= math.huge or questID ~= math.floor(questID) then
		InfinityUtils:Warning("Invalid quest ID.", "Navigation")
		return false
	end
	local api = _G.C_QuestLog
	if not api or not api.GetNextWaypoint then
		InfinityUtils:Warning("Quest waypoint API unavailable.", "Navigation")
		return false
	end
	local mapID, x, y = api.GetNextWaypoint(questID)
	mapID, x, y = Public(mapID), Public(x), Public(y)
	if not InfinityUtils:IsValidWaypoint(mapID, x, y) or (x == 0 and y == 0) then
		InfinityUtils:Warning("No public waypoint is available for this quest.", "Navigation")
		return false
	end
	local waypoint = { mapID = mapID, x = x, y = y, questID = questID }
	if not self:SetWaypoint(waypoint) then return false end
	self.currentObjective = waypoint
	return true
end

function InfinityNavigator:GetPlayerPosition()
	local map = _G.C_Map
	if not map or not map.GetBestMapForUnit or not map.GetPlayerMapPosition then return nil end
	local mapID = Public(map.GetBestMapForUnit("player"))
	if not InfinityUtils:IsValidWaypoint(mapID, 0, 0) then return nil end
	local position = Public(map.GetPlayerMapPosition(mapID, "player"))
	if type(position) ~= "table" and type(position) ~= "userdata" then return nil end
	local x, y = Public(position.x), Public(position.y)
	if (x == nil or y == nil) and type(position.GetXY) == "function" then
		x, y = position:GetXY()
		x, y = Public(x), Public(y)
	end
	if not InfinityUtils:IsValidWaypoint(mapID, x, y) or (x == 0 and y == 0) then return nil end
	return { mapID = mapID, x = x, y = y }
end

function InfinityNavigator:SavePlayerPosition(description)
	local point = self:GetPlayerPosition()
	if not point then return false, "Player position unavailable or protected." end
	return self:AddWaypoint(point.x, point.y, point.mapID, description)
end

function InfinityNavigator:GetNearestObjective()
	return self.currentObjective
end

return InfinityNavigator
