local current, now, timers, packets, warnings = nil, 100, {}, {}, {}
local clients, secret = {}, {}
issecretvalue = function(value) return value == secret end
time = function() return 100000 + math.floor(now) end
GetTime = function() return now end
IsInGuild = function() return current.guild ~= nil end
GetGuildInfo = function() return current.guild, "Member", 1, "Realm" end
GetNormalizedRealmName = function() return "Realm" end
UnitName = function() return current.name end
GetNumGuildMembers = function() return 2 end
GetGuildRosterInfo = function(index)
	local member = clients[({ "Alice", "Bob" })[index]]
	if member.guild == current.guild then
		return member.name .. "-Realm", nil, nil, nil, nil, nil, nil, nil, member.online
	end
end
function CreateFrame()
	return {
		RegisterEvent = function() end,
		SetScript = function(self, _, callback) self.callback = callback end,
	}
end
C_Timer = { After = function(delay, callback)
	timers[#timers + 1] = { when = now + delay, callback = callback, client = current }
end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityBoss1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel, target)
		assert(prefix == "InfinityBoss1" and #message <= 240)
		packets[#packets + 1] = { prefix = prefix, message = message, channel = channel,
			target = target, sender = current.name .. "-Realm", guild = current.guild }
		return 0
	end,
}
InfinityUtils = { Warning = function(_, text) warnings[#warnings + 1] = text end }
local function Use(client)
	current = client
	InfinityDataCollectorCore = client.core
	InfinityGuildBossReports = client.reports
end
for _, name in ipairs({ "Alice", "Bob" }) do
	local client = { name = name, guild = "Guild", online = true, core = { db = {} } }
	clients[name] = client
	Use(client)
	dofile("InfinityDataCollector\\Modules\\GuildKnowledge.lua")
	client.reports = dofile("InfinityDataCollector\\Modules\\GuildBossReports.lua")
	Use(client)
	client.reports:Initialize()
end
local alice, bob = clients.Alice, clients.Bob
local function Pump()
	while #packets > 0 do
		local packet = table.remove(packets, 1)
		for _, client in pairs(clients) do
			if client.online and client.guild == packet.guild
				and (packet.channel == "GUILD" or packet.target:lower() == (client.name .. "-Realm"):lower()) then
				Use(client)
				client.reports:OnMessage(packet.prefix, packet.message, packet.channel, packet.sender)
			end
		end
	end
end
local function NextTimer()
	table.sort(timers, function(a, b) return a.when < b.when end)
	local timer = table.remove(timers, 1)
	assert(timer, "missing timer")
	now = timer.when
	Use(timer.client)
	if timer.client.online then timer.callback() end
	Pump()
end
local function Drain()
	local steps = 0
	Pump()
	while #alice.reports.queue > 0 or #bob.reports.queue > 0 do
		steps = steps + 1
		assert(steps < 3000, "queue did not drain")
		NextTimer()
	end
end

Use(alice)
assert(alice.reports:SetEnabled(true))
alice.reports:ObserveKill(42, "Dragon", 90000)
Drain()
Use(bob)
assert(not bob.reports:GetReport(42))
assert(bob.reports:SetEnabled(true))
Drain()
Use(bob)
assert(bob.reports:SyncNext())
Pump()
local steps = 0
while bob.reports.pull do
	steps = steps + 1
	assert(steps < 3000, "boss catch-up did not finish")
	NextTimer()
end
Use(bob)
assert(bob.reports:GetReport(42).killed == 90000)
bob.reports:ObserveKill(42, "Dragon", 80000)
assert(bob.reports:GetReport(42).killed == 90000)
Use(alice)
alice.reports:ObserveKill(42, "Dragon", 95000)
Drain()
Use(bob)
assert(bob.reports:GetReport(42).killed == 95000)
bob.reports:OnMessage("InfinityBoss1", "LB~42~99999~Injected", "GUILD", "Stranger-Realm")
assert(bob.reports:GetReport(42).killed == 95000)
Use(alice)
local warningCount = #warnings
alice.reports:ObserveKill(43, "Dragon", secret)
assert(#warnings == warningCount + 1 and not alice.reports:GetReport(43))
Use(bob)
local state = bob.reports:State()
bob.reports:SetEnabled(false)
assert(not bob.reports:GetReport(42) and state.count == 1)
assert(bob.reports:SetEnabled(true))
bob.guild = "OtherGuild"
assert(not bob.reports:GetReport(42) and not bob.reports.db.enabled)
print("guild_boss_reports: all tests passed")
