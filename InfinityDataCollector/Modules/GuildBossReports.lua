local Knowledge = _G.InfinityGuildKnowledge
local Reports = {
	prefix = "InfinityBoss1",
	storageKey = "guildBossReports",
	sequence = 0,
	queue = {},
	maxRecords = 10000,
}
for key, value in pairs(Knowledge) do
	if type(value) == "function" then Reports[key] = value end
end
_G.InfinityGuildBossReports = Reports

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum)
	value = Public(value)
	return type(value) == "number" and value == value and value > 0
		and value <= maximum and value == math.floor(value)
end

local function Field(value)
	value = Public(value)
	return type(value) == "string" and #value <= 100 and value:match("%S")
		and not value:find("[%z\1-\31~|]")
end

function Reports:Valid(record)
	record = Public(record)
	return type(record) == "table" and Public(record.kind) == "B"
		and Integer(record.id, 1000000000) and Integer(record.killed, 100000000000)
		and Field(record.name)
end

function Reports:Key(record) return "B:" .. record.id end
function Reports:Payload(prefix, record)
	return table.concat({ prefix, record.id, record.killed, record.name }, "~")
end

function Reports:Parse(kind, body)
	if kind ~= "B" then return nil end
	local id, killed, name = body:match("^(%d+)~(%d+)~([^~]+)$")
	local record = { kind = kind, id = tonumber(id), killed = tonumber(killed), name = name }
	if self:Valid(record) then return record end
end

function Reports:Copy(record, revision)
	return { kind = "B", id = record.id, killed = record.killed, name = record.name, revision = revision }
end

function Reports:Merge(previous, record)
	if record.killed > previous.killed then return record end
end

function Reports:PublishCurrent()
end

function Reports:Apply()
	local ui = _G.InfinityWorldBossUI
	if type(ui) ~= "table" or not ui.frame or not ui.frame:IsShown() or self.refreshPending then return end
	self.refreshPending = true
	C_Timer.After(0.5, function()
		self.refreshPending = false
		local current = _G.InfinityWorldBossUI
		if type(current) == "table" and current.frame and current.frame:IsShown() then current:Refresh() end
	end)
end

function Reports:SetEnabled(enabled)
	local wasEnabled = self.db and self.db.enabled
	local result = Knowledge.SetEnabled(self, enabled)
	if wasEnabled ~= (self.db and self.db.enabled) then self:Apply() end
	return result
end

function Reports:ObserveKill(id, name, timestamp)
	if not self.available or not self.db.enabled then return end
	if self:Add({ kind = "B", id = id, name = name, killed = timestamp }, true) then self:Apply() end
end

function Reports:GetReport(id)
	if not Integer(id, 1000000000) then return nil end
	local state = self:State()
	if not state then return nil end
	local record = Public(state.records["B:" .. id])
	if self:Valid(record) then return { id = id, name = record.name, killed = record.killed } end
end

return Reports
