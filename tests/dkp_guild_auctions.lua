local frames, queue, timers, warnings = {}, {}, {}, {}
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
IsInGuild = function() return true end
GetGuildInfo = function() return current.guild, "Rank", current.name == "Master" and masterRank or 1, "HomeRealm" end
GetNormalizedRealmName = function() return current.realm end
UnitName = function() return current.name end
local roster = { "Master-HomeRealm", "Alice-HomeRealm", "Bob-OtherRealm", "Mallory-HomeRealm" }
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(i) return roster[i], "Rank", i == 1 and masterRank or 1 end
InfinityUtils = {
	Warning = function(_, message) warnings[#warnings + 1] = current.name .. ": " .. message end,
	Info = function() end,
}
InfinityDKPUI = { Update = function() end }
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { when = now + delay, callback = callback, client = current } end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityDKPA1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel)
		assert(prefix == "InfinityDKPA1" and channel == "GUILD" and #message <= 240)
		if sendResult ~= nil then local result = sendResult; sendResult = nil; return result end
		queue[#queue + 1] = { prefix = prefix, message = message, sender = current.name .. "-" .. current.realm }
		return 0
	end,
}
local clients = {}
local function Use(client)
	current = client
	InfinityDKPGuildSync, InfinityDKPGuildAuctions = client.sync, client.auctions
end
for _, config in ipairs({ {"Master", "HomeRealm"}, {"Alice", "HomeRealm"}, {"Bob", "OtherRealm"}, {"Mallory", "HomeRealm"} }) do
	local client = { name = config[1], realm = config[2], guild = "Guild" }
	current = client
	client.sync = dofile("InfinityDKP\\Modules\\GuildSync.lua")
	client.auctions = dofile("InfinityDKP\\Modules\\GuildAuctions.lua")
	Use(client)
	client.auctions:Initialize()
	clients[client.name] = client
end
local master, alice, bob, mallory = clients.Master, clients.Alice, clients.Bob, clients.Mallory
local function At(client, method, ...)
	Use(client)
	return client.auctions[method](client.auctions, ...)
end
local function Pump(skip)
	while #queue > 0 do
		local packet = table.remove(queue, 1)
		for _, client in pairs(clients) do
			if not skip or not skip(client, packet) then
				Use(client)
				client.auctions:OnMessage(packet.prefix, packet.message, "GUILD", packet.sender)
			end
		end
	end
end
local item = "|cffaabbcc|Hitem:123:0:0:0|h[Example item]|h|r"
assert(not At(alice, "Create", item, 10, 30))
assert(not At(master, "Create", "not a link", 10, 30))
assert(not At(master, "Create", item, secret, 30))
sendResult = 3
assert(not At(master, "Create", item, 10, 30) and master.auctions.auction == nil)
assert(At(master, "Create", item, 10, 30))
Pump(function(client) return client == bob end)
local token = master.auctions.auction.token
assert(alice.auctions.auction.token == token and bob.auctions.auction == nil)
assert(At(bob, "Request"))
Pump()
assert(bob.auctions.auction.token == token)
assert(not At(alice, "Bid", 0))
assert(At(alice, "Bid", 9))
Pump()
assert(master.auctions.auction.highBid == nil and warnings[#warnings]:find("rejected", 1, true))
assert(At(alice, "Bid", 10))
Pump()
assert(master.auctions.auction.highBid == 10 and bob.auctions.auction.highestBidder == "alice-homerealm")
assert(At(bob, "Bid", 11))
Pump()
assert(alice.auctions.auction.highBid == 11 and master.auctions.auction.highestBidder == "bob-otherrealm")
Use(alice)
alice.auctions:OnMessage("InfinityDKPA1", "U~" .. token .. "~99~999~mallory-homerealm~10", "GUILD", "Mallory-HomeRealm")
alice.auctions:OnMessage("InfinityDKPA1", "C~" .. token .. "~mallory-homerealm~999", "GUILD", "Mallory-HomeRealm")
assert(alice.auctions.auction.highBid == 11 and alice.auctions.auction.status == "active")
Use(master)
master.auctions:OnMessage("InfinityDKPA1", "B~" .. token .. "~1000", "GUILD", "Stranger-HomeRealm")
assert(master.auctions.auction.highBid == 11)
assert(not At(alice, "Close"))
masterRank = 1
assert(not At(master, "Close"))
masterRank = 0
now = 130
assert(not At(alice, "Bid", 12))
Use(master)
sendResult = 3
timers[1].callback()
assert(master.auctions.auction.status == "active")
assert(At(master, "Close"))
Pump(function(client, packet) return client == mallory and packet.message:sub(1, 2) == "C~" end)
assert(master.auctions.auction.status == "closed" and alice.auctions.auction.status == "closed")
assert(alice.auctions.auction.highestBidder == "bob-otherrealm")
assert(mallory.auctions.auction.status == "active")
assert(At(mallory, "Request"))
Pump()
assert(mallory.auctions.auction.status == "unavailable")
assert(At(master, "Create", item, 5, 20))
Pump()
assert(mallory.auctions.auction.token ~= token and mallory.auctions.auction.status == "active")
assert(At(master, "Close", true))
Pump()
assert(bob.auctions.auction.status == "cancelled")
assert(At(master, "Create", item, 5, 20))
Pump()
local previous = alice.auctions.auction.token
Use(master)
master.auctions = dofile("InfinityDKP\\Modules\\GuildAuctions.lua")
Use(master)
master.auctions:Initialize()
now = 131
assert(At(master, "Create", item, 6, 20))
Pump()
assert(alice.auctions.auction.token ~= previous and alice.auctions.auction.startingBid == 6)
print("Guild auction tests passed")
