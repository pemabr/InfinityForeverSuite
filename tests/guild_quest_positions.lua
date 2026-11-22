local current, now, timers, packets, warnings = nil, 100, {}, {}, {}
local clients, secret = {}, {}
issecretvalue = function(value) return value == secret end
time = function() return 100000 + math.floor(now) end
GetTime = function() return now end
IsInGuild = function() return current.guild ~= nil end
GetGuildInfo = function() return current.guild, "Member", 1, "Realm" end
GetNormalizedRealmName = function() return "Realm" end
UnitName = function() return current.name end
UnitGUID = function(unit) if unit == "npc" then return current.guid end end
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
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityQPos1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel, target)
		assert(prefix == "InfinityQPos1" and #message <= 240)
		packets[#packets + 1] = { prefix = prefix, message = message, channel = channel,
			target = target, sender = current.name .. "-Realm", guild = current.guild }
		return 0
	end,
}
C_Map = {
	GetBestMapForUnit = function() return current.mapID end,
	GetPlayerMapPosition = function() return current.position end,
}
InfinityUtils = { Warning = function(_, text) warnings[#warnings + 1] = text end }
local function Use(client)
	current = client
	InfinityDataCollectorCore = client.core
	InfinityGuildQuestPositions = client.positions
end
for _, name in ipairs({ "Alice", "Bob" }) do
	local client = { name = name, guild = "Guild", online = true, core = { db = {} },
		guid = "Creature-0-1-2-3-444-00001234", mapID = 9, position = { x = 0.12501, y = 0.45601 } }
	clients[name] = client
	Use(client)
	dofile("InfinityDataCollector\\Modules\\GuildKnowledge.lua")
	client.positions = dofile("InfinityDataCollector\\Modules\\GuildQuestPositions.lua")
	Use(client)
	client.positions:Initialize()
end
local alice, bob = clients.Alice, clients.Bob
local function Pump()
	while #packets > 0 do
		local packet = table.remove(packets, 1)
		for _, client in pairs(clients) do
			if client.online and client.guild == packet.guild
				and (packet.channel == "GUILD" or packet.target:lower() == (client.name .. "-Realm"):lower()) then
				Use(client)
				client.positions:OnMessage(packet.prefix, packet.message, packet.channel, packet.sender)
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
	while #alice.positions.queue > 0 or #bob.positions.queue > 0 do
		steps = steps + 1
		assert(steps < 3000, "queue did not drain")
		NextTimer()
	end
end

Use(alice)
assert(alice.positions:SetEnabled(true))
alice.positions:ObserveOffer(101, "Scout")
Drain()
Use(bob)
assert(#bob.positions:GetLocations(101, 200) == 0)
assert(bob.positions:SetEnabled(true))
Drain()
Use(bob)
assert(bob.positions:SyncNext())
Pump()
local steps = 0
while bob.positions.pull do
	steps = steps + 1
	assert(steps < 3000, "offer catch-up did not finish")
	NextTimer()
end
Use(bob)
local points = bob.positions:GetLocations(101, 200)
assert(#points == 1 and points[1].name == "Scout" and points[1].x == 0.125)
assert(points[1].role == "Quest offer (guild)")
bob.positions:OnMessage("InfinityQPos1", "LP~102~9~100~100~Injected", "GUILD", "Stranger-Realm")
assert(#bob.positions:GetLocations(102, 200) == 0)
Use(alice)
local state = alice.positions:State()
alice.guid = "Player-1-2"
alice.positions:ObserveOffer(102, "Player")
assert(state.count == 1)
alice.guid = "Creature-0-1-2-3-444-00001234"
alice.position.x = secret
local count = #warnings
alice.positions:ObserveOffer(102, "Scout")
alice.positions:ObserveOffer(103, "Scout")
assert(#warnings == count + 1 and state.count == 1)
alice.position.x = 0.2
alice.positions:ObserveOffer(102, "Scout")
Drain()
Use(bob)
assert(#bob.positions:GetLocations(102, 200) == 1)
local stored = bob.positions:State()
local refreshed = false
InfinityQuestieUI = {
	locationsQuestID = 102,
	locationsFrame = { IsShown = function() return true end },
	ShowLocations = function(_, id, background)
		if current == bob then refreshed = id == 102 and background end
	end,
}
bob.positions:SetEnabled(false)
assert(#bob.positions:GetLocations(102, 200) == 0 and stored.count == 2)
steps = 0
while not refreshed do
	steps = steps + 1
	assert(steps < 1000, "quest window did not refresh")
	NextTimer()
end
InfinityQuestieUI = nil
Use(bob)
assert(bob.positions:SetEnabled(true))
bob.guild = "OtherGuild"
assert(#bob.positions:GetLocations(102, 200) == 0 and not bob.positions.db.enabled)
print("guild_quest_positions: all tests passed")
