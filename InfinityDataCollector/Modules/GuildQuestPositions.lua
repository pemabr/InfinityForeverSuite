local Knowledge = _G.InfinityGuildKnowledge
local Positions = {
	prefix = "InfinityQPos1",
	storageKey = "guildQuestPositions",
	sequence = 0,
	queue = {},
	maxRecords = 10000,
}
for key, value in pairs(Knowledge) do
	if type(value) == "function" then Positions[key] = value end
end
_G.InfinityGuildQuestPositions = Positions

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum, zero)
	value = Public(value)
	return type(value) == "number" and value == value and value >= (zero and 0 or 1)
		and value <= maximum and value == math.floor(value)
end

local function Field(value)
	value = Public(value)
	return type(value) == "string" and #value <= 75 and value:match("%S")
		and not value:find("[%z\1-\31~|]")
end

local function Quantize(value)
	value = Public(value)
	if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return nil end
	return math.floor(value * 10000 + 0.5)
end

function Positions:Valid(record)
	record = Public(record)
	if type(record) ~= "table" then return false end
	local x, y = Public(record.x), Public(record.y)
	return Public(record.kind) == "P" and Integer(record.id, 1000000000)
		and Integer(record.mapID, 1000000000) and Integer(x, 10000, true)
		and Integer(y, 10000, true) and (x ~= 0 or y ~= 0) and Field(record.giver)
end

function Positions:Key(record)
	return table.concat({ "P", record.id, record.mapID, record.x, record.y }, ":")
end

function Positions:Payload(prefix, record)
	return table.concat({ prefix, record.id, record.mapID, record.x, record.y, record.giver }, "~")
end

function Positions:Parse(kind, body)
	if kind ~= "P" then return nil end
	local id, mapID, x, y, giver = body:match("^(%d+)~(%d+)~(%d+)~(%d+)~([^~]+)$")
	local record = { kind = kind, id = tonumber(id), mapID = tonumber(mapID),
		x = tonumber(x), y = tonumber(y), giver = giver }
	if self:Valid(record) then return record end
end

function Positions:Copy(record, revision)
	return { kind = "P", id = record.id, mapID = record.mapID, x = record.x, y = record.y,
		giver = record.giver, revision = revision }
end

function Positions:PublishCurrent()
end

function Positions:Apply(record)
	local ui = _G.InfinityQuestieUI
	if type(ui) ~= "table" or not ui.locationsFrame or not ui.locationsFrame:IsShown()
		or not ui.locationsQuestID or (record and record.id ~= ui.locationsQuestID) then return end
	if self.refreshPending then return end
	self.refreshPending = true
	C_Timer.After(0.5, function()
		self.refreshPending = false
		local current = _G.InfinityQuestieUI
		if type(current) == "table" and current.locationsFrame and current.locationsFrame:IsShown()
			and current.locationsQuestID then current:ShowLocations(current.locationsQuestID, true) end
	end)
end

function Positions:SetEnabled(enabled)
	local old = self.db and self.db.enabled
	local result = Knowledge.SetEnabled(self, enabled)
	if old ~= (self.db and self.db.enabled) and self.available then self:Apply() end
	return result
end

function Positions:ObserveOffer(id, giver)
	if not self.available or not self.db.enabled then return end
	local guid = _G.UnitGUID and Public(UnitGUID("npc"))
	if type(guid) ~= "string" or not (guid:match("^Creature%-") or guid:match("^GameObject%-")
		or guid:match("^Vehicle%-")) then return end
	local map = _G.C_Map
	local mapID = map and map.GetBestMapForUnit and Public(map.GetBestMapForUnit("player"))
	local position = Integer(mapID, 1000000000) and map.GetPlayerMapPosition
		and Public(map.GetPlayerMapPosition(mapID, "player"))
	local x, y
	if type(position) == "table" or type(position) == "userdata" then
		x, y = Public(position.x), Public(position.y)
		if (x == nil or y == nil) and type(position.GetXY) == "function" then
			x, y = position:GetXY()
			x, y = Public(x), Public(y)
		end
	end
	giver = Public(giver)
	local record = { kind = "P", id = id, mapID = mapID, x = Quantize(x), y = Quantize(y),
		giver = Field(giver) and giver or "Quest giver" }
	if not self:Valid(record) then
		if not self.warnedPosition then
			self.warnedPosition = true
			InfinityUtils:Warning("A quest-giver position was unavailable or protected.", "Knowledge")
		end
		return
	end
	if self:Add(record, true) then self:Apply(record) end
end

function Positions:GetLocations(id, limit)
	id, limit = Public(id), Public(limit)
	if not Integer(id, 1000000000) or not Integer(limit, self.maxRecords, true) then return {}, false end
	local state = self:State()
	if not state then return {}, false end
	local points = {}
	for _, record in pairs(state.records) do
		if self:Valid(record) and record.id == id then
			points[#points + 1] = { mapID = record.mapID, x = record.x / 10000, y = record.y / 10000,
				name = record.giver, role = "Quest offer (guild)" }
		end
	end
	table.sort(points, function(a, b)
		if a.mapID ~= b.mapID then return a.mapID < b.mapID end
		if a.x ~= b.x then return a.x < b.x end
		if a.y ~= b.y then return a.y < b.y end
		return a.name < b.name
	end)
	local more = #points > limit
	while #points > limit do points[#points] = nil end
	return points, more
end

return Positions
