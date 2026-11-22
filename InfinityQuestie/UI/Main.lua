local InfinityQuestieUI = {}
_G.InfinityQuestieUI = InfinityQuestieUI

local function MapName(mapID)
	local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
	if _G.issecretvalue and _G.issecretvalue(info) then info = nil end
	local name = type(info) == "table" and info.name
	if _G.issecretvalue and _G.issecretvalue(name) then name = nil end
	return type(name) == "string" and name or ("Map " .. mapID)
end

function InfinityQuestieUI:Initialize()
	if self.frame then return end
	self.frame = InfinityUIFramework:CreateListWindow("InfinityQuestieMainFrame", "Quest Log", 600, 500)
	self.routeButton = InfinityUIFramework:CreateButton(self.frame, "Waypoints", 100, 22,
		function() self:ShowRoute() end)
	self.routeButton:SetPoint("TOPRIGHT", -40, -34)
	self.compassButton = InfinityUIFramework:CreateButton(self.frame, "Compass", 100, 22,
		function() InfinityQuestCompass:Toggle() end)
	self.compassButton:SetPoint("TOPRIGHT", -145, -34)
	local search = InfinityUIFramework:CreateButton(self.frame, "Search", 100, 22,
		function() self:ShowSearch() end)
	search:SetPoint("TOPRIGHT", -250, -34)
end

function InfinityQuestieUI:ShowSearch()
	if not self.searchFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityQuestieSearchFrame", "Search Quests", 650, 500)
		local label = InfinityUIFramework:CreateLabel(frame, "Name or ID")
		label:SetPoint("TOPLEFT", 20, -43)
		local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		input:SetSize(250, 20)
		input:SetPoint("TOPLEFT", 100, -38)
		input:SetAutoFocus(false)
		input:SetMaxLetters(100)
		local search = InfinityUIFramework:CreateButton(frame, "Search", 100, 22, function()
			local query = input:GetText()
			if _G.issecretvalue and _G.issecretvalue(query) then
				InfinityUtils:Warning("Protected search text cannot be used.", "Questie")
				return
			end
			if type(query) ~= "string" then InfinityUtils:Warning("Search text unavailable.", "Questie"); return end
			query = query:match("^%s*(.-)%s*$")
			if type(self.SearchQuests) ~= "function" then InfinityUtils:Warning("Quest search unavailable.", "Questie"); return end
			local results = self.SearchQuests(query)
			if not results then return end
			local rows = {}
			for index = 1, math.min(#results, 200) do
				local quest = results[index]
				rows[#rows + 1] = {
					text = quest.name .. " (" .. quest.id .. ") - click for locations",
					onClick = function() self:ShowLocations(quest.id) end,
				}
			end
			if #rows == 0 then rows[1] = { text = "No matching quests." } end
			frame:SetItems(rows)
			frame.status:SetText(#results .. " matches." .. (#results > 200 and " Showing first 200." or "")
				.. (InfinityQuestieDBSync.syncInProgress
					and " QuestieDB indexing is still in progress." or " Click a quest for possible locations."))
		end)
		search:SetPoint("LEFT", input, "RIGHT", 12, 0)
		frame.status:SetText("Search QuestieDB, collector data and the visible quest log.")
		frame:SetItems({ { text = "Enter a name or ID to search." } })
		self.searchFrame, self.searchInput = frame, input
	end
	self.searchFrame:Show()
end

function InfinityQuestieUI:Toggle()
	self:Initialize()
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Update()
		self.frame:Show()
	end
end

function InfinityQuestieUI:Show()
	self:Initialize()
	self:Update()
	self.frame:Show()
end

local function SelectedQuestID()
	local api = _G.C_QuestLog
	if not api or type(api.GetSelectedQuest) ~= "function" then
		InfinityUtils:Warning("Selected quest API unavailable.", "Questie")
		return nil
	end
	local ok, id = pcall(api.GetSelectedQuest)
	if not ok then
		if _G.issecretvalue and issecretvalue(id) then id = nil end
		InfinityUtils:Warning("Selected quest unavailable: " .. tostring(id or "protected error"), "Questie")
		return nil
	end
	if (_G.issecretvalue and issecretvalue(id)) or type(id) ~= "number" or id ~= id
		or id <= 0 or id > 1000000000 or id ~= math.floor(id) then
		InfinityUtils:Warning("Select a quest in the quest log first.", "Questie")
		return nil
	end
	return id
end

function InfinityQuestieUI:ShowSelectedWaypoint()
	local id = SelectedQuestID()
	if not id then return false end
	return InfinityQuestRouter:ShowWaypoint(id)
end

function InfinityQuestieUI:ShowSelectedLocations()
	local id = SelectedQuestID()
	if not id then return false end
	return self:ShowLocations(id)
end

function InfinityQuestieUI:Update()
	if not self.frame then return end
	local items, status, quests = InfinityUIFramework:CreateQuestLogItems(
		function() self:Update() end, "Questie",
		function(questID) InfinityQuestRouter:ShowWaypoint(questID) end)
	if InfinityQuestTracker then InfinityQuestTracker:SyncQuestLog(quests) end
	self.frame.status:SetText(status)
	self.frame:SetItems(items)
end

function InfinityQuestieUI:ShowLocations(questID, background)
	local locations, err, truncated = InfinityQuestLocations:Lookup(questID)
	local shared, more = {}, false
	if _G.InfinityGuildQuestPositions then
		shared, more = InfinityGuildQuestPositions:GetLocations(questID, 200 - (locations and #locations or 0))
	end
	if not locations and #shared == 0 then
		if background and self.locationsFrame then
			self.locationsFrame.status:SetText(err)
			self.locationsFrame:SetItems({ { text = "No quest locations available." } })
		else
			InfinityUtils:Warning(err, "Questie")
		end
		return false
	end
	local sourceUnavailable = not locations
	locations = locations or {}
	for _, location in ipairs(shared) do locations[#locations + 1] = location end
	truncated = truncated or more
	if not self.locationsFrame then
		self.locationsFrame = InfinityUIFramework:CreateListWindow(
			"InfinityQuestieLocationsFrame", "Possible Quest Locations", 650, 500)
	end
	local items = {}
	for _, location in ipairs(locations) do
		local phase = location.phase and (" [phase " .. location.phase .. "]") or ""
		items[#items + 1] = {
			text = string.format("%s: %s - %s (%.1f, %.1f)%s", location.role, location.name,
				MapName(location.mapID), location.x * 100, location.y * 100, phase),
			onClick = function() InfinityQuestRouter:SetWaypoint(location) end,
		}
	end
	if #items == 0 then items[1] = { text = "No outdoor QuestieDB locations found." } end
	local status = truncated and "List truncated; locations may already be complete."
		or "Possible locations; objectives may already be complete. Click to set waypoint."
	if #shared > 0 then status = status .. " Guild offers are approximate." end
	if sourceUnavailable then status = "QuestieDB unavailable. " .. status end
	self.locationsFrame.status:SetText(status)
	self.locationsFrame:SetItems(items)
	self.locationsQuestID = questID
	self.locationsFrame:Show()
	return true
end

function InfinityQuestieUI:ShowRoute(background)
	local quests, _, collapsed = InfinityUIFramework:GetQuestLogSnapshot()
	if not quests then
		if self.routeFrame then
			self.routeFrame.status:SetText("Quest log API unavailable.")
			self.routeFrame:SetItems({ { text = "Quest log API unavailable." } })
		end
		if not background then InfinityUtils:Warning("Quest log API unavailable.", "Questie") end
		return false
	end
	if not self.routeFrame then
		self.routeFrame = InfinityUIFramework:CreateListWindow(
			"InfinityQuestieRouteFrame", "Quest Waypoints", 650, 500)
	end
	local route, hasPosition = InfinityQuestRouter:BuildRoute(quests)
	local items = {}
	for _, entry in ipairs(route) do
		local point, quest = entry.point, entry.quest
		local text = quest.title .. " - no native waypoint; click for possible locations"
		if point then
			text = string.format("%s - %s (%.1f, %.1f)", quest.title, MapName(point.mapID),
				point.x * 100, point.y * 100)
		end
		items[#items + 1] = {
			text = text,
			onClick = function()
				if point then InfinityQuestRouter:SetWaypoint(point)
				else self:ShowLocations(quest.id) end
			end,
		}
	end
	if #items == 0 then items[1] = { text = "No visible quests in the quest log." } end
	local status = hasPosition and "Approximate map-coordinate order; other maps unsorted."
		or "Player position unavailable; waypoints unsorted."
	if collapsed then status = status .. " Collapsed quests hidden." end
	self.routeFrame.status:SetText(status)
	self.routeFrame:SetItems(items)
	self.routeFrame:Show()
	return true
end

return InfinityQuestieUI
