-- World Map Objective Markers
-- Displays quest objectives and waypoints on the world map

local WorldMapMarkers = {
	markers = {},
	maxMarkers = 50,
	updateInterval = 1,
	lastUpdate = 0,
	enabled = true,
}

_G.InfinityWorldMapMarkers = WorldMapMarkers

-- Initialize world map markers
function WorldMapMarkers:Initialize()
	InfinityUtils:Info("World map markers initialized", "Navigation")
	
	-- Register for map events
	self:RegisterMapEvents()
end

-- Register for map update events
function WorldMapMarkers:RegisterMapEvents()
	local frame = CreateFrame("Frame")
	
	pcall(frame.RegisterEvent, frame, "WORLD_MAP_UPDATE")
	pcall(frame.RegisterEvent, frame, "QUEST_LOG_UPDATE")
	pcall(frame.RegisterEvent, frame, "ZONE_CHANGED_NEW_AREA")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		WorldMapMarkers:OnMapEvent(event, ...)
	end)
end

-- Handle map events
function WorldMapMarkers:OnMapEvent(event, ...)
	if event == "WORLD_MAP_UPDATE" then
		self:RefreshMarkers()
	elseif event == "QUEST_LOG_UPDATE" then
		self:UpdateQuestMarkers()
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		self:OnZoneChanged()
	end
end

-- Refresh all markers
function WorldMapMarkers:RefreshMarkers()
	-- Clear old markers
	for _, marker in ipairs(self.markers) do
		if marker.frame then
			marker.frame:Hide()
		end
	end
	
	self.markers = {}
	
	-- Add quest objective markers
	self:AddQuestMarkers()
	
	-- Add waypoint markers
	self:AddWaypointMarkers()
end

-- Add quest objective markers (100% standalone via C_QuestLog + optional QuestieDB enrichment)
function WorldMapMarkers:AddQuestMarkers()
	if not InfinityUtils or not InfinityUtils.GetQuestLogCount then return end
	local count = InfinityUtils:GetQuestLogCount()
	for i = 1, count do
		local questName, level, isHeader, questId = InfinityUtils:GetQuestLogEntry(i)
		
		if not isHeader and questId then
			local added = false
			-- Optional QuestieDB coordinates if installed
			if _G.QuestieDB and _G.QuestieDB.GetQuestData then
				local ok, questData = pcall(function() return _G.QuestieDB:GetQuestData(questId) end)
				if ok and questData and questData.objectives then
					for _, objective in ipairs(questData.objectives) do
						if objective.x and objective.y then
							self:AddMarker({
								type = "quest",
								questId = questId,
								questName = questName,
								objectiveText = objective.text,
								x = objective.x,
								y = objective.y,
								zone = objective.zone,
								icon = "objective",
							})
							added = true
						end
					end
				end
			end
			-- Standalone fallback: use InfinityDataCollector recorded coordinates if present
			if not added and _G.InfinityDataCollectorCore and _G.InfinityDataCollectorCore.GetQuestData then
				local ok, localQuest = pcall(function() return _G.InfinityDataCollectorCore:GetQuestData(questId) end)
				if ok and localQuest and localQuest.x and localQuest.y and (localQuest.x > 0 or localQuest.y > 0) then
					self:AddMarker({
						type = "quest",
						questId = questId,
						questName = questName,
						objectiveText = localQuest.objectives or "Quest Objective",
						x = localQuest.x,
						y = localQuest.y,
						zone = localQuest.zone,
						icon = "objective",
					})
				end
			end
		end
	end
end

-- Add waypoint markers
function WorldMapMarkers:AddWaypointMarkers()
	-- Get waypoints from TomTom if available
	if _G.TomTom then
		local waypoints = _G.TomTom.db.profile.waypoints
		if waypoints then
			for mapId, zoneWaypoints in pairs(waypoints) do
				if type(zoneWaypoints) == "table" then
					for _, waypoint in ipairs(zoneWaypoints) do
						self:AddMarker({
							type = "waypoint",
							x = waypoint.x,
							y = waypoint.y,
							zone = mapId,
							title = waypoint.title,
							icon = "waypoint",
						})
					end
				end
			end
		end
	end
end

-- Add a single marker
function WorldMapMarkers:AddMarker(markerData)
	if #self.markers >= self.maxMarkers then
		return
	end
	
	-- Create marker frame
	local marker = CreateFrame("Button", nil, WorldMapFrame)
	marker:SetSize(16, 16)
	
	-- Marker texture based on type
	local icon = "Interface/Icons/Misc_QuestionMark"
	if markerData.icon == "waypoint" then
		icon = "Interface/Minimap/ObjectIcons"
	elseif markerData.icon == "objective" then
		icon = "Interface/Icons/Misc_Landmark"
	end
	
	local texture = marker:CreateTexture(nil, "OVERLAY")
	texture:SetTexture(icon)
	texture:SetAllPoints(marker)
	marker.texture = texture
	
	-- Click to set waypoint
	marker:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			WorldMapMarkers:SetWaypoint(markerData)
		end
	end)
	
	-- Hover tooltip
	marker:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if markerData.questName then
			GameTooltip:AddLine(markerData.questName, 1, 1, 0)
			GameTooltip:AddLine(markerData.objectiveText or "Quest Objective", 0.5, 0.5, 1)
		elseif markerData.title then
			GameTooltip:AddLine(markerData.title, 1, 1, 0)
		else
			GameTooltip:AddLine("Objective Marker", 1, 1, 0)
		end
		GameTooltip:AddLine("Click to waypoint", 0, 1, 0)
		GameTooltip:Show()
	end)
	
	marker:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	
	-- Calculate map position
	if markerData.x and markerData.y then
		local mapWidth = WorldMapFrame:GetWidth()
		local mapHeight = WorldMapFrame:GetHeight()
		
		local posX = mapWidth * markerData.x
		local posY = mapHeight * (1 - markerData.y)
		
		marker:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", posX, posY)
		marker:Show()
	else
		marker:Hide()
	end
	
	markerData.frame = marker
	table.insert(self.markers, markerData)
end

-- Set waypoint on click
function WorldMapMarkers:SetWaypoint(markerData)
	if markerData.type == "quest" then
		-- Set quest objective waypoint
		if _G.TomTom then
			local x = markerData.x * 100
			local y = markerData.y * 100
			_G.TomTom:AddWaypoint(markerData.zone, x, y, markerData.objectiveText)
		end
	elseif markerData.type == "waypoint" then
		-- Set waypoint waypoint
		if _G.TomTom then
			local x = markerData.x * 100
			local y = markerData.y * 100
			_G.TomTom:AddWaypoint(markerData.zone, x, y, markerData.title)
		end
	end
	
	-- Close map
	WorldMapFrame:Hide()
end

-- Update quest markers on quest log change
function WorldMapMarkers:UpdateQuestMarkers()
	self:RefreshMarkers()
end

-- Zone change handler
function WorldMapMarkers:OnZoneChanged()
	self:RefreshMarkers()
end

-- Set marker visibility
function WorldMapMarkers:SetEnabled(enabled)
	self.enabled = enabled
	for _, marker in ipairs(self.markers) do
		if marker.frame then
			if enabled then
				marker.frame:Show()
			else
				marker.frame:Hide()
			end
		end
	end
end

-- Get marker count
function WorldMapMarkers:GetMarkerCount()
	return #self.markers
end

-- Clear all markers
function WorldMapMarkers:ClearAll()
	for _, marker in ipairs(self.markers) do
		if marker.frame then
			marker.frame:Hide()
		end
	end
	self.markers = {}
end

return WorldMapMarkers
