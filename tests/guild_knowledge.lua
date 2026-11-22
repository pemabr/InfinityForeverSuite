local current, now, timers, packets, warnings, results = nil, 100, {}, {}, {}, {}
local clients, secret = {}, {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function CreateFrame()
	return setmetatable({ events = {}, scripts = {} }, { __index = widget })
end
issecretvalue = function(value) return value == secret end
time = function() return 100000 + math.floor(now) end
GetTime = function() return now end
IsInGuild = function() return current.guild ~= nil end
GetGuildInfo = function() return current.guild, "Member", 1, "HomeRealm" end
GetNormalizedRealmName = function() return "HomeRealm" end
UnitName = function(unit) if unit == "player" then return current.name end end
local names = { "Alice", "Bob", "Cara" }
GetNumGuildMembers = function() return #names end
GetGuildRosterInfo = function(index)
	local client = clients[names[index]]
	if client and client.guild == current.guild then
		return client.name .. "-HomeRealm", nil, nil, nil, nil, nil, nil, nil, client.online
	end
end
C_Timer = { After = function(delay, callback)
	timers[#timers + 1] = { when = now + delay, callback = callback, client = current }
end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityKnow1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel, target)
		assert(prefix == "InfinityKnow1" and #message <= 240 and (channel == "GUILD" or channel == "WHISPER"))
		local result = table.remove(results, 1)
		if result == nil or result == 0 then
			packets[#packets + 1] = { prefix = prefix, message = message, channel = channel,
				target = target, sender = current.name .. "-HomeRealm", guild = current.guild }
		end
		return result
	end,
}
InfinityUtils = {
	Info = function() end,
	Warning = function(_, text) warnings[#warnings + 1] = current.name .. ": " .. text end,
}
InfinityCore = { GetDatabase = function() return current.db end }
local function Use(client)
	current = client
	InfinityDataCollectorCore, InfinityGuildKnowledge = client.core, client.knowledge
end
for _, name in ipairs(names) do clients[name] = { name = name, guild = "Guild", online = true, db = {} } end
for _, name in ipairs(names) do
	local client = clients[name]
	Use(client)
	dofile("InfinityDataCollector\\Core\\DataCollectorCore.lua")
	client.core = InfinityDataCollectorCore
	client.core:Initialize()
	client.knowledge = dofile("InfinityDataCollector\\Modules\\GuildKnowledge.lua")
	Use(client)
	client.knowledge:Initialize()
end
local alice, bob, cara = clients.Alice, clients.Bob, clients.Cara
local function Pump()
	while #packets > 0 do
		local packet = table.remove(packets, 1)
		for _, client in pairs(clients) do
			if client.online and client.guild == packet.guild
				and (packet.channel == "GUILD" or packet.target:lower() == (client.name .. "-HomeRealm"):lower()) then
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
	timer.callback()
	Pump()
end
local function DrainQueues()
	local steps = 0
	Pump()
	while #alice.knowledge.queue > 0 or #bob.knowledge.queue > 0 or #cara.knowledge.queue > 0 do
		steps = steps + 1
		assert(steps < 3000, "queue did not drain")
		NextTimer()
	end
end
Use(alice)
assert(alice.knowledge:SetEnabled(true))
Use(bob)
assert(bob.knowledge:SetEnabled(true))
DrainQueues()
timers = {}
alice.knowledge.scheduled, bob.knowledge.scheduled = {}, {}
alice.knowledge.sending, bob.knowledge.sending = false, false
Use(alice)
alice.knowledge:ObserveQuest(100, "Herbs", 0)
Pump()
assert(bob.core.gatheredData.quests[100].name == "Herbs" and not cara.core.gatheredData.quests[100])
Use(alice)
alice.knowledge:ObserveQuest(100, "Herbs", 10)
DrainQueues()
assert(bob.core.gatheredData.quests[100].level == 10)
Use(alice)
assert(alice.knowledge:State().count == 1)
Use(bob)
bob.knowledge:ObserveDrop(444, "Wolf", 456, "Cloth", nil)
DrainQueues()
assert(alice.core.gatheredData.drops["444_456"].itemName == "Cloth")
Use(bob)
bob.knowledge:ObserveDrop(444, "Wolf", 456, "Cloth", 2)
DrainQueues()
assert(alice.core.gatheredData.drops["444_456"].rarity == 2)
while alice.knowledge.sending do NextTimer() end
Use(alice)
results = { 5 }
local failedWarningCount = #warnings
alice.knowledge:ObserveQuest(108, "Retry later", 5)
assert(alice.knowledge.backoff and alice.knowledge:State().records["Q:108"])
alice.knowledge:ObserveQuest(109, "Also retained", 5)
assert(#warnings == failedWarningCount + 1 and not bob.core.gatheredData.quests[108])
while alice.knowledge.backoff do NextTimer() end
Use(bob)
bob.core:RecordQuestData(101, "Existing", 20, nil, nil, nil, nil, nil, nil)
Use(alice)
alice.knowledge:ObserveQuest(101, "Other", 30)
DrainQueues()
assert(bob.core.gatheredData.quests[101].name == "Existing" and bob.core.gatheredData.quests[101].level == 20)
Use(bob)
bob.knowledge:OnMessage("InfinityKnow1", "LQ~102~1~Injected", "GUILD", "Stranger-HomeRealm")
bob.knowledge:OnMessage("InfinityKnow1", "LQ~102~1~Injected", "PARTY", "Alice-HomeRealm")
assert(not bob.core.gatheredData.quests[102])
Use(alice)
local warningCount = #warnings
alice.knowledge:ObserveQuest(103, secret, 1)
alice.knowledge:ObserveQuest(104, "Protected", secret)
assert(#warnings == warningCount + 1 and not alice.core.gatheredData.quests[103])
while alice.knowledge.sending do NextTimer() end
Use(alice)
results = { 3, 8, 0 }
alice.knowledge:ObserveQuest(105, "Throttled", 7)
assert(alice.knowledge.queue[1].retries == 1)
while #alice.knowledge.queue > 0 do NextTimer() end
assert(bob.core.gatheredData.quests[105] and not alice.knowledge.backoff)
bob.online = false
alice.knowledge.events.scripts.OnEvent(alice.knowledge.events, "GUILD_ROSTER_UPDATE")
for id = 1000, 1104 do
	assert(alice.knowledge:Add({ kind = "Q", id = id, level = 5, name = "Offline discovery " .. id }, false))
end
Use(alice)
alice.knowledge:ObserveQuest(999, "Missed live", 5)
DrainQueues()
assert(not bob.core.gatheredData.quests[999])
bob.online = true
Use(bob)
bob.knowledge.events.scripts.OnEvent(bob.knowledge.events, "GUILD_ROSTER_UPDATE")
bob.knowledge:SyncNext()
assert(bob.knowledge.pull and bob.knowledge.pull.peer.key == "alice-homerealm")
Pump()
local steps = 0
while bob.knowledge.pull do
	steps = steps + 1
	assert(steps < 3000, "catch-up did not finish")
	NextTimer()
end
assert(bob.core.gatheredData.quests[999] and bob.core.gatheredData.quests[1104])
Use(bob)
local bobState = bob.knowledge:State()
Use(alice)
assert(bobState.cursors["alice-homerealm"].revision == alice.knowledge:State().revision)
local cursor = bobState.cursors["alice-homerealm"].revision
Use(bob)
bob.knowledge:SyncNext()
local pull = bob.knowledge.pull
assert(pull and pull.peer.key == "alice-homerealm")
local epoch = bobState.cursors["alice-homerealm"].epoch
bob.knowledge:OnMessage("InfinityKnow1", "B~" .. pull.token .. "~" .. epoch .. "~" .. cursor .. "~" .. (cursor + 1) .. "~1~0",
	"WHISPER", "Alice-HomeRealm")
bob.knowledge:OnMessage("InfinityKnow1", "E~" .. pull.token, "WHISPER", "Alice-HomeRealm")
assert(not bob.knowledge.pull and bobState.cursors["alice-homerealm"].revision == cursor)
Use(alice)
alice.knowledge:SetEnabled(false)
Use(bob)
bob.knowledge:SetEnabled(false)
timers, packets = {}, {}
Use(alice)
assert(alice.knowledge:SetEnabled(true))
Use(bob)
assert(bob.knowledge:SetEnabled(true))
DrainQueues()
while alice.knowledge.sending do NextTimer() end
Use(alice)
results = { 5 }
alice.knowledge:ObserveQuest(8000, "Automatic retry", 9)
assert(alice.knowledge.backoff and not bob.core.gatheredData.quests[8000])
steps = 0
while not bob.core.gatheredData.quests[8000] do
	steps = steps + 1
	assert(steps < 3000, "automatic retry did not recover")
	NextTimer()
end
assert(not alice.knowledge.backoff)
while alice.knowledge.sending do NextTimer() end
Use(alice)
alice.knowledge.sending = true
for index = 1, 400 do alice.knowledge.queue[index] = {} end
warningCount = #warnings
alice.knowledge:ObserveQuest(8001, "Queue full", 9)
alice.knowledge:ObserveQuest(8002, "Queue still full", 9)
assert(#warnings == warningCount + 1 and alice.knowledge:State().records["Q:8002"])
alice.knowledge.queue, alice.knowledge.sending = {}, false
Use(cara)
InfinityDataCollectorHooks = { questCache = { [555] = { name = "Current quest", level = 12 } } }
assert(cara.knowledge:SetEnabled(true))
InfinityDataCollectorHooks = nil
DrainQueues()
assert(bob.core.gatheredData.quests[555] and alice.core.gatheredData.quests[555])
Use(alice)
local guildState = alice.knowledge:State()
local epochBefore = guildState.epoch
alice.knowledge.scheduled, alice.knowledge.queue = nil, {}
alice.knowledge.sendGeneration = (alice.knowledge.sendGeneration or 0) + 1
alice.knowledge = dofile("InfinityDataCollector\\Modules\\GuildKnowledge.lua")
Use(alice)
alice.knowledge:Initialize()
assert(alice.knowledge:State().epoch == epochBefore and alice.knowledge:State().count == guildState.count)
alice.guild = "DifferentGuild"
alice.knowledge:ObserveQuest(5000, "Wrong guild", 1)
assert(not alice.db.guildKnowledge.enabled and not alice.db.guildKnowledge.guilds["differentguild-homerealm"])
assert(warnings[#warnings]:find("Guild changed", 1, true))
Use(bob)
bob.knowledge.validatedState = nil
bobState.count = bobState.count + 1
warningCount = #warnings
assert(not bob.knowledge:State() and not bob.db.guildKnowledge.enabled)
assert(#warnings == warningCount + 1 and warnings[#warnings]:find("disabled", 1, true))
assert(not bob.knowledge:State() and #warnings == warningCount + 1)
print("guild_knowledge: all tests passed")
