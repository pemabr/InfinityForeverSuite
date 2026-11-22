InfinityGatherUI = {}

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function ValidCoordinate(value)
	return type(value) == "number" and value == value and value >= 0 and value <= 1
end

function InfinityGatherUI:GetPlayerPosition()
	local map = _G.C_Map
	if not map or not map.GetBestMapForUnit or not map.GetPlayerMapPosition then return nil end
	local mapID = Public(map.GetBestMapForUnit("player"))
	if type(mapID) ~= "number" or mapID <= 0 or mapID >= math.huge or mapID ~= math.floor(mapID) then return nil end
	local position = Public(map.GetPlayerMapPosition(mapID, "player"))
	if type(position) ~= "table" and type(position) ~= "userdata" then return nil end
	local x, y = Public(position.x), Public(position.y)
	if (x == nil or y == nil) and type(position.GetXY) == "function" then
		x, y = position:GetXY()
		x, y = Public(x), Public(y)
	end
	if not ValidCoordinate(x) or not ValidCoordinate(y) or (x == 0 and y == 0) then return nil end
	return { mapID = mapID, x = x, y = y }
end

function InfinityGatherUI:GetPublicNode(node, mapID)
	node = Public(node)
	if type(node) ~= "table" then return nil end
	local id, kind, x, y = Public(node.mapID), Public(node.kind), Public(node.x), Public(node.y)
	if type(id) ~= "number" or id ~= mapID or (kind ~= "Herb" and kind ~= "Ore")
		or not ValidCoordinate(x) or not ValidCoordinate(y) or (x == 0 and y == 0) then return nil end
	local name = Public(node.name)
	return { mapID = id, kind = kind, x = x, y = y, name = type(name) == "string" and name or nil }
end

local function SpellName(spellID)
	if _G.C_Spell and _G.C_Spell.GetSpellName then
		return Public(_G.C_Spell.GetSpellName(spellID))
	elseif _G.GetSpellInfo then
		return Public(_G.GetSpellInfo(spellID))
	end
end

local function GatherKind(spellID)
	spellID = Public(spellID)
	if type(spellID) ~= "number" then return nil end
	if spellID == 2366 then return "Herb" end
	if spellID == 2575 then return "Ore" end
	local name = SpellName(spellID)
	if type(name) ~= "string" or name == "" then return nil end
	local herb, mining = SpellName(2366), SpellName(2575)
	if type(herb) == "string" and herb ~= "" and name == herb then return "Herb" end
	if type(mining) == "string" and mining ~= "" and name == mining then return "Ore" end
end

function InfinityGatherUI:Initialize()
	local nodes = InfinityStorageManager:GetFeatureSetting("InfinityGather", "manualNodes", {})
	if type(nodes) ~= "table" then
		InfinityUtils:Error("Saved gathering positions are invalid.", "Gather")
		self.nodes = nil
		return
	end
	self.nodes = nodes
	if _G.InfinityGatherMap then _G.InfinityGatherMap:Initialize() end
	if not self.eventFrame then
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("UNIT_SPELLCAST_SENT")
		frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
		frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		frame:SetScript("OnEvent", function(_, event, ...)
			self:OnSpellEvent(event, ...)
		end)
		self.eventFrame = frame
	end
end

function InfinityGatherUI:OnSpellEvent(event, unit, ...)
	if Public(unit) ~= "player" then return end
	if event == "UNIT_SPELLCAST_SENT" then
		local target, castGUID, spellID = ...
		target, castGUID = Public(target), Public(castGUID)
		local kind = GatherKind(spellID)
		self.pendingCast = nil
		if kind and type(castGUID) == "string" and castGUID ~= "" then
			self.pendingCast = {
				guid = castGUID,
				kind = kind,
				name = type(target) == "string" and target ~= "" and target or nil,
			}
		elseif kind and not self.warnedCastGUID then
			self.warnedCastGUID = true
			InfinityUtils:Warning("Automatic gathering unavailable: cast identifier is protected or missing.", "Gather")
		end
		return
	end
	local castGUID = Public(...)
	if self.pendingCast and type(castGUID) ~= "string" then
		self.pendingCast = nil
		if not self.warnedCastGUID then
			self.warnedCastGUID = true
			InfinityUtils:Warning("Automatic gathering unavailable: cast identifier is protected or missing.", "Gather")
		end
		return
	end
	if not self.pendingCast or type(castGUID) ~= "string" or castGUID ~= self.pendingCast.guid then return end
	local cast = self.pendingCast
	self.pendingCast = nil
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		self:Record(cast.kind, cast.name, true)
	end
end

function InfinityGatherUI:Record(kind, gatheredName, automatic)
	if not self.nodes then
		InfinityUtils:Error("Gathering positions are unavailable.", "Gather")
		return
	end
	local position = self:GetPlayerPosition()
	if not position then
		InfinityUtils:Warning("Player map position is unavailable.", "Gather")
		return
	end
	local map, mapID, x, y = _G.C_Map, position.mapID, position.x, position.y
	local info = map.GetMapInfo and Public(map.GetMapInfo(mapID))
	local mapName = type(info) == "table" and Public(info.name)
	if automatic then
		for _, node in ipairs(self.nodes) do
			if node.source == "auto" and node.mapID == mapID and node.kind == kind
				and node.name == gatheredName and type(node.x) == "number" and type(node.y) == "number"
				and (node.x - x) ^ 2 + (node.y - y) ^ 2 <= 0.001 ^ 2 then
				node.count = (node.count or 1) + 1
				node.lastSeen = time()
				InfinityStorageManager:SetFeatureSetting("InfinityGather", "manualNodes", self.nodes)
				if _G.InfinityGuildGatherKnowledge then
					InfinityGuildGatherKnowledge:ObserveNode(kind, node.mapID, node.x, node.y)
				end
				self:Refresh()
				return
			end
		end
	end
	self.nodes[#self.nodes + 1] = {
		kind = kind,
		mapID = mapID,
		mapName = type(mapName) == "string" and mapName or ("Map " .. mapID),
		x = x,
		y = y,
		source = automatic and "auto" or "manual",
		name = gatheredName,
		lastSeen = automatic and time() or nil,
	}
	if self.routeFrame and self.routeFrame:IsShown() then
		self.routeFrame.status:SetText("New positions omitted; reopen Waypoints to rebuild.")
	end
	InfinityStorageManager:SetFeatureSetting("InfinityGather", "manualNodes", self.nodes)
	if _G.InfinityGuildGatherKnowledge then
		InfinityGuildGatherKnowledge:ObserveNode(kind, mapID, x, y)
	end
	self:Refresh()
end

function InfinityGatherUI:ShowOnMap(node, openMap)
	if _G.InCombatLockdown and _G.InCombatLockdown() then
		InfinityUtils:Warning("Cannot set a gathering waypoint during combat.", "Gather")
		return
	end
	local map = _G.C_Map
	if not map or not map.CanSetUserWaypointOnMap or not map.SetUserWaypoint
		or not _G.UiMapPoint or not _G.UiMapPoint.CreateFromCoordinates
		or not Public(map.CanSetUserWaypointOnMap(node.mapID)) then
		InfinityUtils:Warning("Waypoints are unavailable on this map.", "Gather")
		return
	end
	local point = _G.UiMapPoint.CreateFromCoordinates(node.mapID, node.x, node.y)
	local result = map.SetUserWaypoint(point)
	if (_G.issecretvalue and _G.issecretvalue(result)) or result == false then
		InfinityUtils:Warning("Could not set the gathering waypoint.", "Gather")
		return
	end
	if _G.C_SuperTrack and _G.C_SuperTrack.SetSuperTrackedUserWaypoint then
		_G.C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	end
	if openMap ~= false and _G.OpenWorldMap then _G.OpenWorldMap(node.mapID) end
end

function InfinityGatherUI:RemoveLast()
	if not self.nodes or #self.nodes == 0 then
		InfinityUtils:Warning("No saved gathering positions to remove.", "Gather")
		return
	end
	table.remove(self.nodes)
	self.routeOrder, self.routeMapID = nil, nil
	if self.routeFrame then self.routeFrame:Hide() end
	InfinityStorageManager:SetFeatureSetting("InfinityGather", "manualNodes", self.nodes)
	self:Refresh()
end

function InfinityGatherUI:ShowRoute()
	local position = self:GetPlayerPosition()
	if not position then
		InfinityUtils:Warning("Player map position is unavailable.", "Gather")
		return false
	end
	if not self.nodes then
		InfinityUtils:Warning("Gathering positions are unavailable.", "Gather")
		return false
	end
	local pending, truncated = {}, false
	for index = #self.nodes, 1, -1 do
		local node = self.nodes[index]
		local point = self:GetPublicNode(node, position.mapID)
		if point then
			if #pending >= 200 then truncated = true; break end
			pending[#pending + 1] = { node = node, point = point }
		end
	end
	if _G.InfinityGuildGatherKnowledge and not truncated then
		local shared, more = InfinityGuildGatherKnowledge:GetNodes(position.mapID, 200 - #pending, self.nodes)
		for _, point in ipairs(shared) do
			pending[#pending + 1] = { node = point, point = point }
		end
		truncated = more
	end
	if _G.InfinityGatherMateSource and not truncated then
		local external, more = InfinityGatherMateSource:GetNodes(position.mapID, 200 - #pending)
		for _, point in ipairs(external) do
			pending[#pending + 1] = { node = point, point = point }
		end
		truncated = more
	end
	local route, x, y = {}, position.x, position.y
	while #pending > 0 do
		local best, distance = 1, math.huge
		for index, entry in ipairs(pending) do
			local dx, dy = entry.point.x - x, entry.point.y - y
			local candidate = dx * dx + dy * dy
			if candidate < distance then best, distance = index, candidate end
		end
		local entry = table.remove(pending, best)
		route[#route + 1] = entry
		x, y = entry.point.x, entry.point.y
	end
	self.routeOrder, self.routeMapID = {}, position.mapID
	if not self.routeFrame then
		self.routeFrame = InfinityUIFramework:CreateListWindow(
			"InfinityGatherRouteWindow", "Gathering Waypoints", 600, 500)
	end
	local items = {}
	for index, entry in ipairs(route) do
		local point = entry.point
		self.routeOrder[entry.node.sourceKey or entry.node] = index
		items[#items + 1] = {
			text = string.format("%d. %s%s%s - %.1f, %.1f", index, point.kind,
				point.name and (" (" .. point.name .. ")") or "",
				point.source == "guild" and " [guild]" or "", point.x * 100, point.y * 100),
			onClick = function() self:ShowOnMap(point) end,
		}
	end
	if #items == 0 then items[1] = { text = "No saved positions on the current map." } end
	self.routeFrame.status:SetText(truncated and "Up to 200 positions; saved positions first. Approximate order."
		or "Approximate coordinate order, not an actual travel route.")
	self.routeFrame:SetItems(items)
	self.routeFrame:Show()
	if _G.InfinityGatherMap then _G.InfinityGatherMap:Refresh() end
	return true
end

function InfinityGatherUI:Refresh()
	if _G.InfinityGatherMap then _G.InfinityGatherMap:Refresh() end
	if not self.frame then return end
	local items = {}
	if self.nodes then
		for i = #self.nodes, 1, -1 do
			local node = self.nodes[i]
			local suffix = node.source == "auto" and (" [auto" .. (node.count and " x" .. node.count or "") .. "]") or ""
			local name = node.name and (" (" .. node.name .. ")") or ""
			items[#items + 1] = {
				text = string.format("%s%s  |  %s  |  %.1f, %.1f%s",
					node.kind, name, node.mapName, node.x * 100, node.y * 100, suffix),
				onClick = function() self:ShowOnMap(node) end,
			}
		end
		local position = self:GetPlayerPosition()
		if position and _G.InfinityGuildGatherKnowledge then
			local shared, more = InfinityGuildGatherKnowledge:GetNodes(position.mapID, 200, self.nodes)
			for _, node in ipairs(shared) do
				items[#items + 1] = {
					text = string.format("%s  |  Map %d  |  %.1f, %.1f [guild]",
						node.kind, node.mapID, node.x * 100, node.y * 100),
					onClick = function() self:ShowOnMap(node) end,
				}
			end
			if more then items[#items + 1] = { text = "More guild positions available on this map." } end
		end
		if #items == 0 then items[1] = { text = "No saved positions." } end
		local status = "Approx. player positions; click a row to replace your waypoint."
		if _G.InfinityGatherMap and _G.InfinityGatherMap.pool then
			status = "Approx. positions; map shows up to 500, saved first. Click for waypoint."
		elseif _G.InfinityGatherMap and not _G.ForeverCore then
			status = "Approx. positions; map markers require ForeverCore."
		elseif _G.InfinityGatherMap then
			status = "Approx. positions; map markers load with the world map."
		end
		if _G.InfinityGatherMateSource and InfinityGatherMateSource.choice == "on" then
			status = status .. " GatherMate2 live enabled."
		end
		self.frame.status:SetText(status)
	else
		self.frame.status:SetText("Saved positions unavailable; see error log.")
	end
	self.frame:SetItems(items)
end

function InfinityGatherUI:Toggle()
	if not self.frame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityGatherWindow", "Gathering Positions", 600, 500)
		local herb = InfinityUIFramework:CreateButton(frame, "Save herb", 100, 22, function() self:Record("Herb") end)
		herb:SetPoint("TOPLEFT", 15, -37)
		local ore = InfinityUIFramework:CreateButton(frame, "Save ore", 100, 22, function() self:Record("Ore") end)
		ore:SetPoint("LEFT", herb, "RIGHT", 6, 0)
		local remove = InfinityUIFramework:CreateButton(frame, "Remove local", 100, 22, function() self:RemoveLast() end)
		remove:SetPoint("LEFT", ore, "RIGHT", 6, 0)
		local route = InfinityUIFramework:CreateButton(frame, "Waypoints", 100, 22, function() self:ShowRoute() end)
		route:SetPoint("LEFT", remove, "RIGHT", 6, 0)
		local source = InfinityUIFramework:CreateButton(frame, "GatherMate2", 100, 22, function()
			local bridge = _G.InfinityGatherMateSource
			if bridge then bridge:SetEnabled(bridge.choice ~= "on") end
		end)
		source:SetPoint("LEFT", route, "RIGHT", 6, 0)
		self.frame = frame
	end
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Refresh()
		self.frame:Show()
	end
end
