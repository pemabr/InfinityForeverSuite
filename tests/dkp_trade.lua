local frames, queue, warnings = {}, {}, {}
local current, now, sendResult, masterRank = nil, 100, nil, 0
local secret = {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame()
	local frame = setmetatable({ events = {}, scripts = {} }, meta)
	frames[#frames + 1] = frame
	return frame
end
issecretvalue = function(value) return value == secret end
GetTime = function() return now end
time = function() return 100000 + now end
date = os.date
IsInGuild = function() return true end
GetGuildInfo = function() return "Guild", "Rank", current.name == "Master" and masterRank or 1, "Home Realm" end
GetNormalizedRealmName = function() return current.realm end
UnitName = function() return current.name end
local roster = { "Master-HomeRealm", "Alice-HomeRealm", "Bob-OtherRealm", "Mallory-HomeRealm" }
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(i) return roster[i], "Rank", i == 1 and masterRank or 1 end
InfinityCore = { GetDatabase = function() return current.db end }
InfinityUtils = {
	Warning = function(_, message) warnings[#warnings + 1] = message end,
	Info = function() end,
}
InfinityDKPUI = { Update = function() end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityDKPT1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel)
		assert(prefix == "InfinityDKPT1" and channel == "GUILD")
		if sendResult ~= nil then local result = sendResult; sendResult = nil; return result end
		queue[#queue + 1] = { prefix = prefix, message = message, sender = current.name .. "-" .. current.realm }
		return 0
	end,
}

local clients = {}
local function Use(client)
	current = client
	InfinityDKPEngine, InfinityDKPPoints = client.engine, client.points
	InfinityDKPGuildSync, InfinityDKPPlayerTrading = client.sync, client.trade
end
for _, config in ipairs({ {"Master", "HomeRealm"}, {"Alice", "HomeRealm"}, {"Bob", "OtherRealm"}, {"Mallory", "HomeRealm"} }) do
	local client = { name = config[1], realm = config[2], db = {} }
	current = client
	client.engine = dofile("InfinityDKP\\Core\\DKPEngine.lua")
	client.engine:Initialize()
	client.points = dofile("InfinityDKP\\Modules\\Points.lua")
	client.points:Initialize(client.db)
	client.sync = dofile("InfinityDKP\\Modules\\GuildSync.lua")
	client.trade = dofile("InfinityDKP\\Modules\\PlayerTrading.lua")
	client.trade:Initialize(client.db)
	clients[client.name] = client
end
local master, alice, bob, mallory = clients.Master, clients.Alice, clients.Bob, clients.Mallory
local function Pump(skip)
	while #queue > 0 do
		local packet = table.remove(queue, 1)
		for _, client in pairs(clients) do
			if not skip or not skip(client, packet) then
				Use(client)
				client.trade:OnMessage(packet.prefix, packet.message, "GUILD", packet.sender)
			end
		end
	end
end
local function At(client, method, ...)
	Use(client)
	return client.trade[method](client.trade, ...)
end
Use(master)
assert(master.engine:AddPlayer("Alice"))
assert(master.engine:AddPlayer("Bob-OtherRealm"))
assert(master.engine:SetSystemType("dkp"))
assert(master.engine:AdjustDKP("Alice", 100, "initial"))

assert(not At(alice, "Offer", "Alice", 10))
assert(not At(alice, "Offer", "Bob-OtherRealm", 0))
assert(not At(alice, "Offer", "Bob-OtherRealm", 1.5))
assert(not At(alice, "Offer", "Bob-OtherRealm", secret))
assert(not At(alice, "Offer", "Missing", 10))
sendResult = 3
assert(not At(alice, "Offer", "Bob-OtherRealm", 10) and #queue == 0)
local ok, token = At(alice, "Offer", "Bob-OtherRealm", 30)
assert(ok and token)
Pump()
assert(not At(mallory, "Accept", "Alice-HomeRealm", token))
assert(not At(alice, "Finalize", "Alice", token))
Use(master)
master.trade:OnMessage("InfinityDKPT1", "A~" .. token .. "~alice-homerealm~30", "GUILD", "Mallory-HomeRealm")
master.trade:OnMessage("InfinityDKPT1", "A~" .. token .. "~alice-homerealm~1", "GUILD", "Bob-OtherRealm")
assert(master.trade:Find("Alice", token).status == "pending")
assert(not master.trade:Finalize("Alice", token))
assert(At(bob, "Accept", "Alice-HomeRealm", token))
Pump()
Use(bob)
bob.trade:OnMessage("InfinityDKPT1", "F~" .. token .. "~alice-homerealm~30", "GUILD", "Mallory-HomeRealm")
assert(bob.trade:Find("Alice-HomeRealm", token).status == "accepted")
Use(master)
assert(master.trade:Find("Alice", token).status == "accepted")
masterRank = 1
assert(not master.trade:Finalize("Alice", token))
masterRank = 0
assert(master.engine:SetSystemType("epgp"))
assert(not master.trade:Finalize("Alice", token))
assert(master.engine:SetSystemType("dkp"))
master.sync.outgoing = {}
assert(not master.trade:Finalize("Alice", token))
master.sync.outgoing = nil
assert(master.engine:AddPlayer("Alice-HomeRealm"))
assert(not master.trade:Finalize("Alice", token))
assert(master.engine:RemovePlayer("Alice-HomeRealm"))
bob.sync.pending = { stale = false }
mallory.sync.pending = { stale = false }
assert(master.trade:Finalize("Alice", token))
assert(master.db.players.Alice.dkp == 70 and master.db.players["Bob-OtherRealm"].dkp == 30)
assert(#master.db.pointTransactions == 2 and master.db.pointTransactions[1].amount == -30
	and master.db.pointTransactions[2].amount == 30)
local saved
for _, trade in pairs(master.db.dkpTrades) do saved = trade end
assert(saved and saved.amount == 30 and saved.approvedBy == "master-homerealm")
assert(not master.trade:Finalize("Alice", token))
Pump()
assert(At(bob, "Find", "Alice-HomeRealm", token).status == "completed")
assert(bob.sync.pending.stale and mallory.sync.pending.stale)
bob.sync.pending = {}
Use(bob)
bob.trade:OnMessage("InfinityDKPT1", "F~" .. token .. "~alice-homerealm~30", "GUILD", "Master-HomeRealm")
assert(not bob.sync.pending.stale)
bob.sync.pending, mallory.sync.pending = nil, nil
Use(master)
master.trade.offers = {}
master.trade:OnMessage("InfinityDKPT1", "O~" .. token .. "~bob-otherrealm~30", "GUILD", "Alice-HomeRealm")
assert(not master.trade:Find("Alice", token))

local _, second = At(alice, "Offer", "Bob-OtherRealm", 80)
Pump()
assert(At(bob, "Accept", "Alice-HomeRealm", second))
Pump()
assert(not At(master, "Finalize", "Alice", second))
assert(master.db.players.Alice.dkp == 70 and master.db.players["Bob-OtherRealm"].dkp == 30)
assert(At(alice, "Cancel", "Alice", second))
Pump()
assert(not At(master, "Finalize", "Alice", second))

local _, third = At(alice, "Offer", "Bob-OtherRealm", 10)
Pump(function(client, packet) return client == master and packet.message:match("^O~") end)
assert(At(bob, "Accept", "Alice-HomeRealm", third))
Pump()
assert(not At(master, "Find", "Alice", third))
assert(At(alice, "Resend", third))
Pump()
assert(At(bob, "Accept", "Alice-HomeRealm", third))
Pump()
assert(At(master, "Finalize", "Alice", third))
Pump()
assert(master.db.players.Alice.dkp == 60 and master.db.players["Bob-OtherRealm"].dkp == 40)

local _, expired = At(alice, "Offer", "Bob-OtherRealm", 5)
Pump()
now = now + 300
assert(not At(bob, "Accept", "Alice-HomeRealm", expired))
assert(not At(master, "Finalize", "Alice", expired))
Use(master)
assert(not master.engine:TransferDKP("Alice", "Bob-OtherRealm", secret))
assert(not master.engine:TransferDKP("Alice", "Bob-OtherRealm", 100))
master.db.players["Bob-OtherRealm"].dkp = 1000000000
assert(not master.engine:TransferDKP("Alice", "Bob-OtherRealm", 1))
assert(master.db.players.Alice.dkp == 60)
master.db.players["Bob-OtherRealm"].dkp = 40
local _, fourth = At(alice, "Offer", "Bob-OtherRealm", 5)
Pump()
assert(At(bob, "Accept", "Alice-HomeRealm", fourth))
Pump()
sendResult = 3
assert(At(master, "Finalize", "Alice", fourth))
assert(master.db.players.Alice.dkp == 55 and master.db.players["Bob-OtherRealm"].dkp == 45)
assert(warnings[#warnings]:find("notification failed", 1, true))
assert(not At(master, "Finalize", "Alice", fourth))
print("dkp_trade: all tests passed")
