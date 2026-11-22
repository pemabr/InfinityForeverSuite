-- InfinityGatherPath Main UI
-- Modern Flat Node Recorder, TSP Route Optimizer, and Zone Route Browser for WoW Forever

local InfinityGatherPathUI = {}
_G.InfinityGatherPathUI = InfinityGatherPathUI

local function getPlayerCoords()
	if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
		local mapID = C_Map.GetBestMapForUnit("player")
		if mapID then
			local pos = C_Map.GetPlayerMapPosition(mapID, "player")
			if pos then return pos.x * 100, pos.y * 100 end
		end
	end
	if GetPlayerMapPosition then
		local x, y = GetPlayerMapPosition("player")
		if x and y then return x * 100, y * 100 end
	end
	return 50, 50
end

function InfinityGatherPathUI:Initialize()
	if self.initialized and self.frame then return end

	local frame = InfinityUIFramework:CreateFrame(
		"InfinityGatherPathMainFrame",
		UIParent,
		580,
		450,
		"Infinity GatherPath",
		"Node Database & Route Optimizer"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 180, -40)

	-- Action buttons
	local recHerbBtn = InfinityUIFramework:CreateButton(frame, "+ Record Herb", 112, 26, function()
		local zone = (GetRealZoneText and GetRealZoneText()) or "Eastern Plaguelands"
		local x, y = getPlayerCoords()
		if _G.InfinityNodeDB and _G.InfinityNodeDB.RecordNode then
			_G.InfinityNodeDB:RecordNode("herb", x, y, zone, 300)
		end
		InfinityUIFramework:ShowNotification(string.format("Recorded Herb node in %s (%.1f, %.1f)", zone, x, y), 2.2)
		InfinityGatherPathUI:Update()
	end, true)
	recHerbBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)

	local recOreBtn = InfinityUIFramework:CreateButton(frame, "+ Record Ore", 106, 26, function()
		local zone = (GetRealZoneText and GetRealZoneText()) or "Eastern Plaguelands"
		local x, y = getPlayerCoords()
		if _G.InfinityNodeDB and _G.InfinityNodeDB.RecordNode then
			_G.InfinityNodeDB:RecordNode("ore", x, y, zone, 300)
		end
		InfinityUIFramework:ShowNotification(string.format("Recorded Ore node in %s (%.1f, %.1f)", zone, x, y), 2.2)
		InfinityGatherPathUI:Update()
	end)
	recOreBtn:SetPoint("LEFT", recHerbBtn, "RIGHT", 8, 0)

	local optBtn = InfinityUIFramework:CreateButton(frame, "Optimize Current Zone", 156, 26, function()
		local zone = (GetRealZoneText and GetRealZoneText()) or "Eastern Plaguelands"
		local nodes = (_G.InfinityNodeDB and _G.InfinityNodeDB.GetNodesByZone) and _G.InfinityNodeDB:GetNodesByZone(zone) or {}
		if #nodes > 0 and _G.InfinityOptimization and _G.InfinityOptimization.OptimizeRoute then
			local opt = _G.InfinityOptimization:OptimizeRoute(nodes)
			local dist = _G.InfinityOptimization:CalculateTotalDistance(opt)
			if _G.InfinityRoutes and _G.InfinityRoutes.CreateRoute then
				pcall(function() _G.InfinityRoutes:CreateRoute(zone .. " Optimal Loop", zone, opt) end)
			end
			InfinityUIFramework:ShowNotification(string.format("Optimized %s: %d nodes (%.0f yd)", zone, #opt, dist or 0), 3)
			InfinityGatherPathUI:Update()
		else
			InfinityUIFramework:ShowNotification("Record nodes in " .. zone .. " first to optimize a route.", 2.5)
		end
	end)
	optBtn:SetPoint("LEFT", recOreBtn, "RIGHT", 8, 0)

	-- Metric tiles
	frame.mNodes = InfinityUIFramework:CreateMetricTile(frame, 180, 56, "Recorded Nodes", 0, "|cff4ade80")
	frame.mNodes:SetPoint("TOPLEFT", recHerbBtn, "BOTTOMLEFT", 0, -10)
	frame.mRoutes = InfinityUIFramework:CreateMetricTile(frame, 180, 56, "Saved Routes", 0, "|cff38bdf8")
	frame.mRoutes:SetPoint("LEFT", frame.mNodes, "RIGHT", 8, 0)
	frame.mZone = InfinityUIFramework:CreateMetricTile(frame, 180, 56, "Active Zone", "Azeroth", "|cfffbbf24")
	frame.mZone:SetPoint("LEFT", frame.mRoutes, "RIGHT", 8, 0)

	local listCard = InfinityUIFramework:CreateCard(frame, 556, 286, "Saved Farming Routes")
	listCard:SetPoint("TOPLEFT", frame.mNodes, "BOTTOMLEFT", 0, -10)

	local scroll = InfinityUIFramework:CreateScrollFrame(listCard, "InfinityGatherPathScroll", 542, 246)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 6, -32)
	self.content = scroll.content

	frame:Hide()
	self.frame = frame
	self.initialized = true
end

function InfinityGatherPathUI:Toggle()
	if not self.initialized then self:Initialize() end
	self.frame:SetShown(not self.frame:IsShown())
	if self.frame:IsShown() then self:Update() end
end

function InfinityGatherPathUI:Show()
	if not self.initialized then self:Initialize() end
	self.frame:Show()
	self:Update()
end

function InfinityGatherPathUI:Update()
	if not self.initialized or not self.frame or not self.frame:IsShown() then return end
	InfinityUIFramework:ClearContainer(self.content)

	local nodeCount = (_G.InfinityNodeDB and _G.InfinityNodeDB.GetNodeCount) and _G.InfinityNodeDB:GetNodeCount() or 0
	local routes = (_G.InfinityRoutes and _G.InfinityRoutes.GetRoutes) and _G.InfinityRoutes:GetRoutes() or {}
	local routeCount = 0
	for _ in pairs(routes) do routeCount = routeCount + 1 end

	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	self.frame.mNodes:SetValue(nodeCount, "|cff4ade80")
	self.frame.mRoutes:SetValue(routeCount, "|cff38bdf8")
	self.frame.mZone:SetValue(zone, "|cfffbbf24")

	if routeCount == 0 then
		local empty = InfinityUIFramework:CreateLabel(self.content, "|cff94a3b8No farming routes saved yet. Click '+ Record Herb' or '+ Record Ore' while gathering, then 'Optimize Current Zone'.|r")
		empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, -10)
		empty:SetWidth(510)
		empty:SetWordWrap(true)
		self.content:SetHeight(230)
		return
	end

	local y = -2
	local idx = 0
	for _, route in pairs(routes) do
		idx = idx + 1
		local row = InfinityUIFramework:CreateListRow(self.content, 514, 30, idx)
		row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
		local l = InfinityUIFramework:CreateLabel(row, "|cff4ade80" .. tostring(route.name or "Route") .. "|r")
		l:SetPoint("LEFT", row, "LEFT", 8, 0)
		local r = InfinityUIFramework:CreateLabel(row, string.format("%d nodes  |  |cff94a3b8%s|r", route.nodes and #route.nodes or 0, tostring(route.zone or "")))
		r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		y = y - 32
	end
	self.content:SetHeight(math.max(230, -y + 10))
end

return InfinityGatherPathUI
