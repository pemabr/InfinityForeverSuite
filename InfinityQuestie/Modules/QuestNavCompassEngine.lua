local Compass = { followWaypoint = true, history = {} }
_G.InfinityQuestCompass = Compass

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function ValidPoint(mapID, x, y)
	return Finite(mapID) and mapID > 0 and mapID == math.floor(mapID)
		and Finite(x) and x >= 0 and x <= 1 and Finite(y) and y >= 0 and y <= 1
end

local function WorldPosition(point)
	if not (_G.C_Map and C_Map.GetWorldPosFromMapPos and _G.CreateVector2D) then return nil end
	local instance, position = C_Map.GetWorldPosFromMapPos(point.mapID, CreateVector2D(point.x, point.y))
	instance, position = Public(instance), Public(position)
	if not Finite(instance) or (type(position) ~= "table" and type(position) ~= "userdata") then return nil end
	local x, y = Public(position.x), Public(position.y)
	if (x == nil or y == nil) and type(position.GetXY) == "function" then
		x, y = position:GetXY()
		x, y = Public(x), Public(y)
	end
	if not Finite(x) or not Finite(y) then return nil end
	return { instance = instance, x = x, y = y }
end

function Compass:GetTarget()
	if not self.followWaypoint then return self.target end
	if not (_G.C_Map and C_Map.GetUserWaypoint) then return nil end
	local point = Public(C_Map.GetUserWaypoint())
	if type(point) ~= "table" then return nil end
	local mapID, pos = Public(point.uiMapID), Public(point.position)
	if type(pos) ~= "table" and type(pos) ~= "userdata" then return nil end
	local x, y = Public(pos.x), Public(pos.y)
	if not ValidPoint(mapID, x, y) then return nil end
	return { mapID = mapID, x = x, y = y }
end

function Compass:SetTarget(x, y, mapID)
	x, y, mapID = Public(x), Public(y), Public(mapID)
	if not Finite(x) or not Finite(y) then return false end
	if mapID == nil then
		local player = InfinityQuestRouter:GetPlayerPosition()
		mapID = player and player.mapID
	end
	if not ValidPoint(mapID, x / 100, y / 100) then return false end
	self.target = { mapID = mapID, x = x / 100, y = y / 100 }
	self.followWaypoint, self.history, self.lastTarget = false, {}, nil
	return true
end

function Compass:FollowWaypoint()
	self.followWaypoint, self.target, self.history, self.lastTarget = true, nil, {}, nil
end

function Compass:ClearTarget()
	self.followWaypoint, self.target, self.history, self.lastTarget = false, nil, {}, nil
end

function Compass:GetCompassData()
	local target = self:GetTarget()
	if not target then return nil, "No target; set coordinates or follow a user waypoint." end
	local player = InfinityQuestRouter:GetPlayerPosition()
	if not player then return nil, "Player position unavailable." end
	local origin, destination = WorldPosition(player), WorldPosition(target)
	if not origin or not destination then return nil, "World coordinates unavailable." end
	if origin.instance ~= destination.instance then return nil, "Target is on a different continent or instance." end
	local north, east = destination.x - origin.x, origin.y - destination.y
	local distance = math.sqrt(north * north + east * east)
	if not Finite(distance) then return nil, "Distance unavailable." end
	local angle, direction
	if distance < 0.1 then
		direction = "At target"
	else
		angle = (math.atan2(east, north) * 180 / math.pi + 360) % 360
		local names = { "North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest" }
		direction = names[math.floor((angle + 22.5) / 45) % 8 + 1]
	end
	return { target = target, distance = distance, angle = angle, direction = direction }
end

function Compass:Update()
	if not self.frame or not self.frame:IsShown() then return end
	local data, problem = self:GetCompassData()
	if not data then
		self.frame.display:SetText(problem)
		self.history, self.lastTarget = {}, nil
		return
	end
	local point = data.target
	local key = string.format("%d:%.6f:%.6f", point.mapID, point.x, point.y)
	if key ~= self.lastTarget then self.history, self.lastTarget = {}, key end
	self.history[#self.history + 1] = data.distance
	if #self.history > 100 then table.remove(self.history, 1) end
	self.frame.display:SetText(string.format("%s  |  %.0f yards (straight line)\nMap %d: %.1f, %.1f",
		data.direction, data.distance, point.mapID, point.x * 100, point.y * 100))
end

function Compass:Toggle()
	if not self.frame then
		local frame = InfinityUIFramework:CreateFrame("InfinityQuestCompassFrame", UIParent, 320, 100)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
		frame:SetMovable(true)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(window) window:StartMoving() end)
		frame:SetScript("OnDragStop", function(window) window:StopMovingOrSizing() end)
		local title = InfinityUIFramework:CreateLabel(frame, "Quest compass")
		title:SetPoint("TOPLEFT", 12, -10)
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -5, -5)
		close:SetScript("OnClick", function() frame:Hide() end)
		frame.display = InfinityUIFramework:CreateLabel(frame, "")
		frame.display:SetPoint("TOPLEFT", 12, -35)
		frame.display:SetWidth(290)
		frame.display:SetJustifyH("LEFT")
		local elapsed = 0
		frame:SetScript("OnUpdate", function(_, dt)
			elapsed = elapsed + dt
			if elapsed >= 1 then elapsed = 0; self:Update() end
		end)
		frame:Hide()
		self.frame = frame
	end
	if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:Update() end
end

function Compass:HandleCommand(message)
	local cmd, args = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" or cmd == "show" then
		self:Toggle()
	elseif cmd == "set" then
		local x, y, rest = args:match("^(%S+)%s+(%S+)%s*(.-)$")
		local mapID = rest ~= "" and tonumber(rest) or nil
		if not x or not y or (rest ~= "" and not mapID) or not self:SetTarget(tonumber(x), tonumber(y), mapID) then
			print("Usage: /questcompass set <x 0-100> <y 0-100> [map ID]")
		else
			print("Compass target set; the native waypoint was not changed.")
			self:Update()
		end
	elseif cmd == "waypoint" then
		self:FollowWaypoint()
		print("Compass follows the native user waypoint.")
		self:Update()
	elseif cmd == "clear" then
		self:ClearTarget()
		print("Compass target cleared; the native waypoint was not changed.")
		self:Update()
	elseif cmd == "compass" or cmd == "target" then
		local data, problem = self:GetCompassData()
		if data then
			print(string.format("%s: %.0f yards straight line, map %d (%.1f, %.1f).",
				data.direction, data.distance, data.target.mapID, data.target.x * 100, data.target.y * 100))
		else
			print(problem)
		end
	elseif cmd == "heading" then
		local count = #self.history
		if count < 2 then print("Open the compass and wait for two position samples.")
		elseif self.history[count] < self.history[count - 1] then print("Distance decreased since the previous sample.")
		elseif self.history[count] > self.history[count - 1] then print("Distance increased since the previous sample.")
		else print("Distance unchanged since the previous sample.") end
	else
		print("Usage: /questcompass [show|set <x> <y> [map ID]|waypoint|clear|compass|heading]")
	end
end

return Compass
