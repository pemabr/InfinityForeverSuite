local current, now, timers, packets, warnings = nil, 100, {}, {}, {}
local clients = {}
local secret = {}
issecretvalue = function(value) return value == secret end
time = function() return 100000 + math.floor(now) end
GetTime = function() return now end
IsInGuild = function() return current.guild ~= nil end
GetGuildInfo = function() return current.guild, "Member", 1, "Realm" end
GetNormalizedRealmName = function() return "Realm" end
UnitName = function() return current.name end
GetNumGuildMembers = function() return 3 end
GetGuildRosterInfo = function(index)
	local member = clients[({ "Alice", "Bob", "Cara" })[index]]
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
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityNode1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel, target)
		assert(prefix == "InfinityNode1" and #message <= 240)
		packets[#packets + 1] = { prefix = prefix, message = message, channel = channel,
			target = target, sender = current.name .. "-Realm", guild = current.guild }
		return 0
	end,
}
InfinityUtils = {
	Warning = function(_, text) warnings[#warnings + 1] = text end,
}
local function Use(client)
	current = client
	InfinityDataCollectorCore = client.core
	InfinityGatherUI = client.ui
	InfinityGuildGatherKnowledge = client.knowledge
end
for _, name in ipairs({ "Alice", "Bob", "Cara" }) do
	local client = { name = name, guild = "Guild", online = true, core = { db = {} },
		ui = { nodes = {}, Refresh = function(self) self.refreshed = (self.refreshed or 0) + 1 end } }
	clients[name] = client
	Use(client)
	dofile("InfinityDataCollector\\Modules\\GuildKnowledge.lua")
	client.knowledge = dofile("InfinityDataCollector\\Modules\\GuildGatherKnowledge.lua")
	Use(client)
	client.knowledge:Initialize()
end
local alice, bob, cara = clients.Alice, clients.Bob, clients.Cara
local function Pump()
	while #packets > 0 do
		local packet = table.remove(packets, 1)
		for _, client in pairs(clients) do
			if client.online and client.guild == packet.guild
				and (packet.channel == "GUILD" or packet.target:lower() == (client.name .. "-Realm"):lower()) then
				Use(client)
				client.knowledge:OnMessage(packet.prefix, packet.message, packet.channel, packet.sender)
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
	while #alice.knowledge.queue > 0 or #bob.knowledge.queue > 0 or #cara.knowledge.queue > 0 do
		steps = steps + 1
		assert(steps < 3000, "queue did not drain")
		NextTimer()
	end
end

alice.ui.nodes = {
	{ source = "manual", kind = "Herb", mapID = 9, x = 0.12501, y = 0.45601 },
	{ source = "auto", kind = "Ore", mapID = 9, x = 0.6, y = 0.7 },
	{ source = "external", kind = "Herb", mapID = 9, x = 0.8, y = 0.8 },
}
Use(alice)
assert(alice.knowledge:SetEnabled(true))
Use(bob)
assert(bob.knowledge:SetEnabled(true))
Drain()
Use(bob)
local nodes, more = bob.knowledge:GetNodes(9, 10, bob.ui.nodes)
assert(#nodes == 2 and not more and nodes[1].source == "guild")
assert(#cara.ui.nodes == 0 and not cara.knowledge.db.enabled)
Use(alice)
assert(alice.knowledge:State().count == 2)
assert(#alice.knowledge:GetNodes(9, 10, alice.ui.nodes) == 0)
local only, truncated = bob.knowledge:GetNodes(9, 1, {})
assert(#only == 1 and truncated)
Use(bob)
bob.knowledge:OnMessage("InfinityNode1", "LN~9~Herb~100~100", "GUILD", "Stranger-Realm")
assert(bob.knowledge:State().count == 2)
bob.knowledge:OnMessage("InfinityNode1", "LQ~123~1~Injected", "GUILD", "Alice-Realm")
assert(bob.knowledge:State().count == 2)
local warningCount = #warnings
Use(alice)
alice.knowledge:ObserveNode("Herb", 9, secret, 0.3)
assert(#warnings == warningCount + 1)

timers = {}
alice.knowledge.scheduled, bob.knowledge.scheduled = {}, {}
alice.knowledge.sending, bob.knowledge.sending = false, false
bob.online = false
Use(alice)
alice.knowledge.events.callback(nil, "GUILD_ROSTER_UPDATE")
for index = 1, 105 do alice.knowledge:ObserveNode("Herb", 10, index / 1000, 0.5) end
Drain()
bob.online = true
Use(bob)
bob.knowledge.events.callback(nil, "GUILD_ROSTER_UPDATE")
assert(bob.knowledge:SyncNext())
Pump()
local steps = 0
while bob.knowledge.pull do
	steps = steps + 1
	assert(steps < 3000, "catch-up did not finish")
	NextTimer()
end
Use(bob)
nodes, more = bob.knowledge:GetNodes(10, 200, {})
assert(#nodes == 105 and not more)
local state = bob.knowledge:State()
assert(state.count == 107 and bob.ui.refreshed)
bob.knowledge:SetEnabled(false)
assert(#bob.knowledge:GetNodes(10, 200, {}) == 0 and state.count == 107)
assert(bob.knowledge:SetEnabled(true))
assert(#bob.knowledge:GetNodes(10, 200, {}) == 105)
bob.guild = "OtherGuild"
assert(#bob.knowledge:GetNodes(10, 200, {}) == 0 and not bob.knowledge.db.enabled)
print("guild_gather_knowledge: all tests passed")
