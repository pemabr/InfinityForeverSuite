-- Waypoint Persistence Module
-- Saves and loads waypoints from SavedVariables

local WaypointPersistence = {
	savedWaypoints = {}, -- Loaded from SavedVariables
	
	config = {
		maxWaypoints = 100,
		autoSave = true,
		saveInterval = 30, -- seconds
		lastSaveTime = 0,
	},
}

_G.PluribusWaypointPersistence = WaypointPersistence

-- Initialize waypoint persistence
function WaypointPersistence:Initialize()
	PluribusUtils:Info("Waypoint persistence initialized", "Navigation")
	
	-- Load saved waypoints
	self:LoadWaypoints()
	
	-- Enable periodic saving
	C_Timer.NewTicker(self.config.saveInterval, function()
		if WaypointPersistence.config.autoSave then
			WaypointPersistence:SaveWaypoints()
		end
	end)
	
	-- Subscribe to waypoint events
	PluribusMessaging:Subscribe("waypoint_added", function(waypoint)
		WaypointPersistence:OnWaypointAdded(waypoint)
	end)
	
	PluribusMessaging:Subscribe("waypoint_removed", function(waypointId)
		WaypointPersistence:OnWaypointRemoved(waypointId)
	end)
end

-- Load waypoints from SavedVariables
function WaypointPersistence:LoadWaypoints()
	PluribusStorageManager:LoadData("waypoints", function(data)
		if data then
			self.savedWaypoints = data
			PluribusUtils:Info("Loaded " .. PluribusUtils:TableSize(self.savedWaypoints) .. " waypoints", "Navigation")
			PluribusMessaging:Publish("waypoints_loaded")
		end
	end)
end

-- Save waypoints to SavedVariables
function WaypointPersistence:SaveWaypoints()
	-- Collect current waypoints
	local waypoints = {}
	
	for waypointId, waypoint in pairs(self.savedWaypoints) do
		if waypoint then
			table.insert(waypoints, waypoint)
		end
	end
	
	-- Check size limit
	if #waypoints > self.config.maxWaypoints then
		PluribusUtils:Warning("Too many waypoints (" .. #waypoints .. "), keeping most recent", "Navigation")
		-- Sort by creation time and keep newest
		table.sort(waypoints, function(a, b)
			return a.createdAt > b.createdAt
		end)
		for i = self.config.maxWaypoints + 1, #waypoints do
			waypoints[i] = nil
		end
	end
	
	-- Save to storage
	PluribusStorageManager:SaveData("waypoints", waypoints)
	self.config.lastSaveTime = GetTime()
end

-- Called when waypoint is added
function WaypointPersistence:OnWaypointAdded(waypoint)
	waypoint.createdAt = GetServerTime()
	waypoint.id = waypoint.id or GetUniqueId()
	
	self.savedWaypoints[waypoint.id] = waypoint
	
	PluribusMessaging:Publish("waypoint_persisted", waypoint)
end

-- Called when waypoint is removed
function WaypointPersistence:OnWaypointRemoved(waypointId)
	self.savedWaypoints[waypointId] = nil
	PluribusMessaging:Publish("waypoint_removed_persisted", waypointId)
end

-- Get all saved waypoints
function WaypointPersistence:GetWaypoints()
	local waypoints = {}
	
	for _, waypoint in pairs(self.savedWaypoints) do
		if waypoint then
			table.insert(waypoints, waypoint)
		end
	end
	
	return waypoints
end

-- Get waypoints by zone
function WaypointPersistence:GetWaypointsByZone(zone)
	local waypoints = {}
	
	for _, waypoint in pairs(self.savedWaypoints) do
		if waypoint and waypoint.zone == zone then
			table.insert(waypoints, waypoint)
		end
	end
	
	return waypoints
end

-- Get waypoint by ID
function WaypointPersistence:GetWaypoint(waypointId)
	return self.savedWaypoints[waypointId]
end

-- Clear all waypoints
function WaypointPersistence:ClearAll()
	self.savedWaypoints = {}
	self:SaveWaypoints()
	PluribusUtils:Info("All waypoints cleared", "Navigation")
end

-- Export waypoints
function WaypointPersistence:ExportWaypoints()
	return self:GetWaypoints()
end

-- Import waypoints
function WaypointPersistence:ImportWaypoints(waypointsData)
	for _, waypoint in ipairs(waypointsData) do
		waypoint.id = waypoint.id or GetUniqueId()
		self.savedWaypoints[waypoint.id] = waypoint
	end
	
	self:SaveWaypoints()
	PluribusUtils:Info("Imported " .. #waypointsData .. " waypoints", "Navigation")
end

-- Display waypoint status
function WaypointPersistence:DisplayStatus()
	local totalWaypoints = PluribusUtils:TableSize(self.savedWaypoints)
	
	print("|cffffd700=== WAYPOINT PERSISTENCE ===|r")
	print("Total Waypoints: " .. totalWaypoints .. " / " .. self.config.maxWaypoints)
	print("Auto-Save: " .. (self.config.autoSave and "YES" or "NO"))
	
	-- Group by zone
	local byZone = {}
	for _, waypoint in pairs(self.savedWaypoints) do
		if waypoint then
			local zone = waypoint.zone or "Unknown"
			byZone[zone] = (byZone[zone] or 0) + 1
		end
	end
	
	print("\n|cffccccccWaypoints by Zone:|r")
	for zone, count in pairs(byZone) do
		print("  " .. zone .. ": " .. count)
	end
end

return WaypointPersistence
