local GatherMap = { limit = 500 }
_G.InfinityGatherMap = GatherMap

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

function GatherMap:Setup()
	if self.pool then return true end
	if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
	local core, map = _G.ForeverCore, _G.WorldMapFrame
	if type(core) ~= "table" or type(core.Register) ~= "function" or not map then return false end
	local context = core.Register("InfinityGather")
	local canvas = type(context) == "table" and context.MapCanvas
	if type(canvas) ~= "table" or type(canvas.PinMixin) ~= "table"
		or type(canvas.Pool) ~= "function" or type(canvas.Watch) ~= "function"
		or type(canvas.SetShown) ~= "function" then
		if not self.warned then
			self.warned = true
			InfinityUtils:Warning("ForeverCore does not provide the required map canvas API.", "Gather")
		end
		return false
	end
	local mixin = {}
	for key, value in pairs(canvas.PinMixin) do mixin[key] = value end
	mixin.takesMouse, mixin.clicks = true, true
	function mixin:OnLoad()
		self:SetSize(16, 16)
		self.icon = self:CreateTexture(nil, "ARTWORK")
		self.icon:SetAllPoints()
		self.order = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		self.order:SetAllPoints()
	end
	function mixin:OnAcquired(node)
		self.node = node
		self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
		self:SetScalingLimits(1, 1, 1)
		self.icon:SetTexture(node.kind == "Herb" and "Interface\\Icons\\INV_Misc_Herb_07"
			or "Interface\\Icons\\INV_Ore_Copper_01")
		self.order:SetText(node.order and tostring(node.order) or "")
		self:SetPosition(node.x, node.y)
	end
	function mixin:OnReleased()
		self.node = nil
	end
	function mixin:OnMouseEnter()
		if not self.node or not _G.GameTooltip then return end
		local node = self.node
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText((node.name or node.kind) .. (node.source == "guild" and " [Guild]" or ""))
		GameTooltip:AddLine(string.format("Approximate position: %.1f, %.1f", node.x * 100, node.y * 100))
		GameTooltip:AddLine("Click to set a waypoint.")
		GameTooltip:Show()
	end
	function mixin:OnMouseLeave()
		if _G.GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end
	function mixin:OnMouseClickAction(button)
		if button == "LeftButton" and self.node then InfinityGatherUI:ShowOnMap(self.node, false) end
	end
	self.canvas, self.map = canvas, map
	self.pool = canvas.Pool(map, mixin)
	canvas.Watch(map, function(_, what)
		if what == "show" or what == "map" then self:Refresh() end
	end)
	self:Refresh()
	return true
end

function GatherMap:Initialize()
	if self.events then return end
	local events = CreateFrame("Frame")
	events:RegisterEvent("ADDON_LOADED")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event)
		if event == "ADDON_LOADED" then
			self:Setup()
		elseif event == "PLAYER_REGEN_ENABLED" then
			self:Setup()
			self:Refresh()
		else
			self:Refresh()
		end
	end)
	self.events = events
	self:Setup()
end

function GatherMap:Refresh()
	if not self.pool then return end
	if _G.InCombatLockdown and _G.InCombatLockdown() then
		self.canvas.SetShown(self.map, false)
		return
	end
	self.canvas.SetShown(self.map, true)
	if not self.map:IsShown() then return end
	self.pool:ReleaseAll()
	local mapID = Public(self.map:GetMapID())
	if type(mapID) ~= "number" or mapID <= 0 or mapID >= math.huge then return end
	local nodes = InfinityGatherUI.nodes
	if type(nodes) ~= "table" then return end
	local count = 0
	for index = #nodes, 1, -1 do
		local original = Public(nodes[index])
		local node = InfinityGatherUI:GetPublicNode(original, mapID)
		if node then
			count = count + 1
			if count > self.limit then break end
			if InfinityGatherUI.routeMapID == mapID and InfinityGatherUI.routeOrder then
				node.order = InfinityGatherUI.routeOrder[original]
			end
			self.pool:Acquire(node)
		end
	end
	self.truncated = count > self.limit
	if not self.truncated and _G.InfinityGuildGatherKnowledge then
		local shared, more = InfinityGuildGatherKnowledge:GetNodes(mapID, self.limit - count, nodes)
		for _, node in ipairs(shared) do
			if InfinityGatherUI.routeMapID == mapID and InfinityGatherUI.routeOrder then
				node.order = InfinityGatherUI.routeOrder[node.sourceKey]
			end
			self.pool:Acquire(node)
			count = count + 1
		end
		self.truncated = more
	end
	if not self.truncated and _G.InfinityGatherMateSource then
		local external, more = InfinityGatherMateSource:GetNodes(mapID, self.limit - count)
		for _, node in ipairs(external) do
			if InfinityGatherUI.routeMapID == mapID and InfinityGatherUI.routeOrder then
				node.order = InfinityGatherUI.routeOrder[node.sourceKey]
			end
			self.pool:Acquire(node)
		end
		self.truncated = more
	end
end

return GatherMap
