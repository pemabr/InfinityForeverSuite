local Knowledge = _G.InfinityGuildKnowledge
local Gather = {
	prefix = "InfinityNode1",
	storageKey = "guildGatherKnowledge",
	sequence = 0,
	queue = {},
	maxRecords = 10000,
}
for key, value in pairs(Knowledge) do
	if type(value) == "function" then Gather[key] = value end
end
_G.InfinityGuildGatherKnowledge = Gather

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum, zero)
	value = Public(value)
	return type(value) == "number" and value == value and value >= (zero and 0 or 1)
		and value <= maximum and value == math.floor(value)
end

local function Quantize(value)
	value = Public(value)
	if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return nil end
	return math.floor(value * 10000 + 0.5)
end

function Gather:Valid(record)
	record = Public(record)
	if type(record) ~= "table" then return false end
	local kind, resource = Public(record.kind), Public(record.resource)
	local x, y = Public(record.x), Public(record.y)
	return kind == "N" and (resource == "Herb" or resource == "Ore")
		and Integer(record.mapID, 1000000000) and Integer(x, 10000, true)
		and Integer(y, 10000, true) and (x ~= 0 or y ~= 0)
end

function Gather:Key(record)
	return table.concat({ "N", record.mapID, record.resource, record.x, record.y }, ":")
end

function Gather:Payload(prefix, record)
	return table.concat({ prefix, record.mapID, record.resource, record.x, record.y }, "~")
end

function Gather:Parse(kind, body)
	if kind ~= "N" then return nil end
	local mapID, resource, x, y = body:match("^(%d+)~(%a+)~(%d+)~(%d+)$")
	local record = { kind = kind, mapID = tonumber(mapID), resource = resource, x = tonumber(x), y = tonumber(y) }
	if self:Valid(record) then return record end
end

function Gather:Copy(record, revision)
	return { kind = "N", mapID = record.mapID, resource = record.resource,
		x = record.x, y = record.y, revision = revision }
end

function Gather:Apply()
	if self.refreshPending then return end
	self.refreshPending = true
	C_Timer.After(0.5, function()
		self.refreshPending = false
		local ui = _G.InfinityGatherUI
		if type(ui) == "table" then
			if ui.routeFrame and ui.routeFrame:IsShown() then
				ui.routeFrame.status:SetText("Guild positions changed; reopen Waypoints to rebuild.")
			end
			if type(ui.Refresh) == "function" then ui:Refresh() end
		end
	end)
end

function Gather:ObserveNode(kind, mapID, x, y)
	if not self.available or not self.db.enabled then return end
	self:Add({ kind = "N", resource = kind, mapID = mapID, x = Quantize(x), y = Quantize(y) }, true)
end

function Gather:PublishCurrent()
	local ui = _G.InfinityGatherUI
	if type(ui) ~= "table" or type(ui.nodes) ~= "table" then return end
	for _, raw in ipairs(ui.nodes) do
		local node = Public(raw)
		if type(node) == "table" then
			local source = Public(node.source)
			if source == "manual" or source == "auto" then
				self:ObserveNode(node.kind, node.mapID, node.x, node.y)
			end
		end
	end
end

function Gather:SetEnabled(enabled)
	local ui = _G.InfinityGatherUI
	if enabled and (type(ui) ~= "table" or type(ui.nodes) ~= "table") then
		InfinityUtils:Warning("Load Infinity Gather before enabling guild gathering positions.", "Knowledge")
		return false
	end
	local wasEnabled = self.db and self.db.enabled
	local result = Knowledge.SetEnabled(self, enabled)
	if type(ui) == "table" and wasEnabled ~= (self.db and self.db.enabled) then
		ui.routeOrder, ui.routeMapID = nil, nil
		if ui.routeFrame then ui.routeFrame:Hide() end
		if type(ui.Refresh) == "function" then ui:Refresh() end
	end
	return result
end

function Gather:GetNodes(mapID, limit, saved)
	mapID, limit = Public(mapID), Public(limit)
	if not Integer(mapID, 1000000000) or not Integer(limit, self.maxRecords, true) then return {}, false end
	local state = self:State()
	if not state then return {}, false end
	local existing = {}
	if type(saved) == "table" then
		for _, raw in ipairs(saved) do
			local node = Public(raw)
			if type(node) == "table" and Public(node.mapID) == mapID then
				local record = { kind = "N", mapID = mapID, resource = Public(node.kind),
					x = Quantize(node.x), y = Quantize(node.y) }
				if self:Valid(record) then existing[self:Key(record)] = true end
			end
		end
	end
	local nodes = {}
	for key, record in pairs(state.records) do
		if self:Valid(record) and record.mapID == mapID and not existing[key] then
			nodes[#nodes + 1] = { mapID = mapID, kind = record.resource,
				x = record.x / 10000, y = record.y / 10000, source = "guild", sourceKey = key }
		end
	end
	table.sort(nodes, function(a, b) return a.sourceKey < b.sourceKey end)
	local more = #nodes > limit
	while #nodes > limit do nodes[#nodes] = nil end
	return nodes, more
end

return Gather
