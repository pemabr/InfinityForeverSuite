local Core = {}
_G.InfinityWorldBossCore = Core
_G.InfinityWorldBoss = Core

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function PositiveInteger(value, maximum)
	value = Public(value)
	return type(value) == "number" and value == value and value > 0
		and value <= (maximum or 1000000000) and value == math.floor(value)
end

local function ValidName(name)
	name = Public(name)
	return type(name) == "string" and name:match("%S") and #name <= 100 and not name:find("[%c]")
end

function Core:Initialize()
	local db = InfinityCore:GetDatabase("InfinityWorldBoss")
	if type(db) ~= "table" then error("World boss database unavailable") end
	if db.bosses == nil then db.bosses = {} end
	if type(db.bosses) ~= "table" then error("Invalid world boss database") end
	for id, boss in pairs(db.bosses) do
		if not PositiveInteger(id) or type(boss) ~= "table" or not ValidName(boss.name)
			or not PositiveInteger(boss.interval)
			or (boss.lastKilled ~= nil and not PositiveInteger(boss.lastKilled, 1000000000000))
			or (boss.notified ~= nil and type(boss.notified) ~= "boolean") then
			error("Invalid saved world boss data")
		end
	end
	self.bosses = db.bosses
end

function Core:RegisterBoss(id, name, interval)
	id, name, interval = Public(id), Public(name), Public(interval)
	if not PositiveInteger(id) or not ValidName(name) or not PositiveInteger(interval) then
		return false, "Invalid encounter ID, name or interval."
	end
	if self.bosses[id] then return false, "Encounter ID is already registered." end
	self.bosses[id] = { name = name, interval = interval }
	return true
end

function Core:RecordBossKill(id, timestamp)
	id, timestamp = Public(id), Public(timestamp)
	local boss = PositiveInteger(id) and self.bosses[id]
	if not boss then return false, "Encounter ID is not registered." end
	if not PositiveInteger(timestamp, 1000000000000) then return false, "Kill time unavailable." end
	boss.lastKilled, boss.notified = timestamp, false
	return true
end

function Core:SetInterval(id, interval)
	id, interval = Public(id), Public(interval)
	if not PositiveInteger(id) or not self.bosses[id] then return false, "Encounter ID is not registered." end
	if not PositiveInteger(interval) then return false, "Interval must be a positive number of seconds." end
	self.bosses[id].interval, self.bosses[id].notified = interval, false
	return true
end

function Core:ClearKill(id)
	id = Public(id)
	if not PositiveInteger(id) or not self.bosses[id] then return false end
	self.bosses[id].lastKilled, self.bosses[id].notified = nil, nil
	return true
end

function Core:RemoveBoss(id)
	id = Public(id)
	if not PositiveInteger(id) or not self.bosses[id] then return false end
	self.bosses[id] = nil
	return true
end

function Core:GetAllBosses()
	local result = {}
	for id, boss in pairs(self.bosses) do
		result[#result + 1] = { id = id, boss = boss }
	end
	table.sort(result, function(a, b) return a.boss.name:lower() < b.boss.name:lower() end)
	return result
end

function Core:Describe(boss, now)
	if not boss.lastKilled then return "No kill recorded; status unknown." end
	local remaining = boss.lastKilled + boss.interval - now
	if remaining <= 0 then return "Estimate elapsed; actual status unknown." end
	local hours, minutes = math.floor(remaining / 3600), math.floor((remaining % 3600) / 60)
	return string.format("Estimated: %dh %02dm remaining; actual status unknown.", hours, minutes)
end

return Core
