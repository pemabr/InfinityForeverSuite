local current, now, timers, packets, warnings = nil, 100, {}, {}, {}
local clients, secret = {}, {}
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
		events = {},
		RegisterEvent = function(self, event) self.events[event] = true end,
		SetScript = function(self, _, callback) self.callback = callback end,
		SetSize = function() end,
		SetPoint = function() end,
		SetAutoFocus = function() end,
		SetMaxLetters = function() end,
		SetText = function(self, text) self.text = text end,
		GetText = function(self) return self.text end,
		ClearFocus = function() end,
	}
end
C_Timer = { After = function(delay, callback)
	timers[#timers + 1] = { when = now + delay, callback = callback, client = current }
end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityBag1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel, target)
		assert(prefix == "InfinityBag1" and #message <= 240)
		packets[#packets + 1] = { prefix = prefix, message = message, channel = channel,
			target = target, sender = current.name .. "-Realm", guild = current.guild }
		return 0
	end,
}
InfinityMessaging = {
	Subscribe = function(_, event, callback) assert(event == "bags_scanned"); current.scanCallback = callback end,
}
InfinityUtils = { Warning = function(_, text) warnings[#warnings + 1] = text end }
local function Use(client)
	current = client
	InfinityDataCollectorCore = client.core
	InfinityGuildBagReports = client.reports
	InfinityBagTracker = client.tracker
end
for _, name in ipairs({ "Alice", "Bob", "Cara" }) do
	local client = { name = name, guild = "Guild", online = true, core = { db = {} }, items = {} }
	client.tracker = {
		ScanBags = function(self)
			if current.fail then self.freeSlots = nil; return false end
			self.bagContents, self.freeSlots = current.items, 2
			if current.scanCallback then current.scanCallback() end
			return true
		end,
	}
	clients[name] = client
	Use(client)
	dofile("InfinityDataCollector\\Modules\\GuildKnowledge.lua")
	client.reports = dofile("InfinityDataCollector\\Modules\\GuildBagReports.lua")
	Use(client)
	client.reports:Initialize()
end
local alice, bob, cara = clients.Alice, clients.Bob, clients.Cara
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
	while #alice.reports.queue > 0 or #bob.reports.queue > 0 or #cara.reports.queue > 0 do
		steps = steps + 1
		assert(steps < 3000, "queue did not drain")
		NextTimer()
	end
end

alice.items = { [0] = { { itemId = 123, quantity = 2 }, { itemId = 123, quantity = 3 } } }
Use(bob)
assert(bob.reports:SetEnabled(true))
Use(alice)
assert(alice.reports:SetEnabled(true))
Drain()
Use(bob)
local found = bob.reports:Search(123)
assert(#found == 1 and found[1].owner == "Alice-Realm" and found[1].count == 5)
local inventories = bob.reports:GetInventories()
assert(inventories["alice-realm"].items[1].itemId == 123 and inventories["alice-realm"].items[1].quantity == 5)
assert(not cara.reports.db.enabled and cara.reports:Search(123) == nil)

Use(alice)
local state = alice.reports:State()
local unchanged = state.revision
assert(alice.tracker:ScanBags())
while alice.reports.scanPending do NextTimer() end
assert(state.revision == unchanged)
local previous = state.records["I:alice-realm:123"]
alice.items = { [0] = {} }
assert(alice.tracker:ScanBags())
while alice.reports.scanPending do NextTimer() end
Use(alice)
local zero = state.records["I:alice-realm:123"]
assert(zero.count == 0 and zero.observed > previous.observed)
Drain()
Use(bob)
assert(#bob.reports:Search(123) == 0)
assert(not bob.reports:GetInventories()["alice-realm"])

Use(alice)
alice.items = { [0] = { { itemId = 123, quantity = 8 } } }
assert(alice.tracker:ScanBags() and alice.reports:PublishScan())
Drain()
Use(bob)
assert(bob.reports:Search(123)[1].count == 8)
Use(alice)
alice.fail = true
assert(not alice.tracker:ScanBags() and not alice.reports:PublishScan())
assert(alice.reports:State().records["I:alice-realm:123"].count == 8)
alice.fail = false
alice.items = { [0] = { { itemId = secret, quantity = 1 } } }
assert(alice.tracker:ScanBags() and not alice.reports:PublishScan())
assert(alice.reports:State().records["I:alice-realm:123"].count == 8)

timers = {}
alice.reports.scheduled, bob.reports.scheduled = {}, {}
alice.reports.scanPending, bob.reports.scanPending = nil, nil
alice.reports.sending, bob.reports.sending = false, false
bob.online = false
alice.reports.events.callback(nil, "GUILD_ROSTER_UPDATE")
alice.items = { [0] = { { itemId = 456, quantity = 4 } } }
assert(alice.tracker:ScanBags() and alice.reports:PublishScan())
Drain()
bob.online = true
now = now + 6
Use(bob)
bob.reports.events.callback(nil, "GUILD_ROSTER_UPDATE")
assert(bob.reports:SyncNext())
Pump()
local steps = 0
while bob.reports.pull do
	steps = steps + 1
	assert(steps < 3000, "bag catch-up did not finish")
	NextTimer()
end
Use(bob)
assert(#bob.reports:Search(123) == 0 and bob.reports:Search(456)[1].count == 4)

InfinityUIFramework = {
	CreateListWindow = function()
		return {
			shown = false, status = { SetText = function(self, text) self.text = text end },
			IsShown = function(self) return self.shown end,
			Show = function(self) self.shown = true end,
			Hide = function(self) self.shown = false end,
			SetItems = function(self, rows) self.rows = rows end,
		}
	end,
	CreateButton = function() return { SetPoint = function() end } end,
}
bob.reports:Toggle()
assert(not bob.reports:OpenItem(-1) and bob.reports:OpenItem(456))
assert(bob.reports.window:IsShown() and bob.reports.window.rows[1].text:find("Alice%-Realm: 4"))
assert(bob.reports.window.status.text:find("outdated", 1, true))
alice.guild = "OtherGuild"
bob.reports.events.callback(nil, "GUILD_ROSTER_UPDATE")
assert(#bob.reports:Search(456) == 0)
assert(not bob.reports:GetInventories()["alice-realm"])
alice.guild = "Guild"
bob.reports.events.callback(nil, "GUILD_ROSTER_UPDATE")
assert(#bob.reports:Search(456) == 1)
assert(not bob.reports:SetEnabled(false))
local missing, problem = bob.reports:Search(456)
assert(not missing and problem:find("Enable", 1, true))
assert(not bob.reports:GetInventories())
assert(bob.reports:SetEnabled(true))
bob.guild = "OtherGuild"
assert(not bob.reports:Search(456) and not bob.reports.db.enabled)
Use(cara)
cara.tracker = nil
Use(cara)
assert(not cara.reports:SetEnabled(true) and not cara.reports.db.enabled)

Use(alice)
local savedRevision = alice.reports:State().revision
alice.items = { [0] = {} }
assert(alice.tracker:ScanBags())
alice.reports = dofile("InfinityDataCollector\\Modules\\GuildBagReports.lua")
Use(alice)
alice.reports:Initialize()
assert(alice.reports.db.enabled and alice.reports.scanPending)
while alice.reports.scanPending do NextTimer() end
Use(alice)
assert(alice.reports:State().revision > savedRevision
	and alice.reports:State().records["I:alice-realm:456"].count == 0)
print("guild_bag_reports: all tests passed")
