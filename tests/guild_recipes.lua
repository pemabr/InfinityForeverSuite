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
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityRec1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel, target)
		assert(prefix == "InfinityRec1" and #message <= 240)
		packets[#packets + 1] = { prefix = prefix, message = message, channel = channel,
			target = target, sender = current.name .. "-Realm", guild = current.guild }
		return 0
	end,
}
C_TradeSkillUI = {
	IsTradeSkillLinked = function() return current.linked end,
	IsTradeSkillGuild = function() return current.guildWindow end,
	GetBaseProfessionInfo = function() return current.profession and { professionID = current.profession } end,
	GetAllRecipeIDs = function() return current.ids or {} end,
	GetRecipeInfo = function(id) return current.recipes and current.recipes[id] end,
}
InfinityUtils = { Warning = function(_, text) warnings[#warnings + 1] = text end }
local function Use(client)
	current = client
	InfinityDataCollectorCore = client.core
	InfinityGuildRecipes = client.recipesModule
end
for _, name in ipairs({ "Alice", "Bob", "Cara" }) do
	local client = { name = name, guild = "Guild", online = true, core = { db = {} } }
	clients[name] = client
	Use(client)
	dofile("InfinityDataCollector\\Modules\\GuildKnowledge.lua")
	client.recipesModule = dofile("InfinityDataCollector\\Modules\\GuildRecipes.lua")
	Use(client)
	client.recipesModule:Initialize()
end
local alice, bob, cara = clients.Alice, clients.Bob, clients.Cara
local function Pump()
	while #packets > 0 do
		local packet = table.remove(packets, 1)
		for _, client in pairs(clients) do
			if client.online and client.guild == packet.guild
				and (packet.channel == "GUILD" or packet.target:lower() == (client.name .. "-Realm"):lower()) then
				Use(client)
				client.recipesModule:OnMessage(packet.prefix, packet.message, packet.channel, packet.sender)
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
	while #alice.recipesModule.queue > 0 or #bob.recipesModule.queue > 0 or #cara.recipesModule.queue > 0 do
		steps = steps + 1
		assert(steps < 3000, "queue did not drain")
		NextTimer()
	end
end

alice.profession, alice.ids = 171, { 10, 11, 12 }
alice.recipes = {
	[10] = { learned = true, name = "Healing Potion" },
	[11] = { learned = false, name = "Unknown Potion" },
	[12] = { learned = secret, name = "Protected Potion" },
}
Use(bob)
assert(bob.recipesModule:SetEnabled(true))
Use(alice)
assert(alice.recipesModule:SetEnabled(true))
Drain()
Use(bob)
local reports = bob.recipesModule:Search("healing")
assert(#reports == 1 and reports[1].owner == "Alice-Realm" and reports[1].id == 10)
assert(#bob.recipesModule:Search("11") == 0 and not cara.recipesModule.db.enabled)
Use(alice)
assert(alice.recipesModule:State().count == 1)
alice.linked = true
alice.recipes[11].learned = true
assert(not alice.recipesModule:ScanOpen(false) and alice.recipesModule:State().count == 1)
alice.linked = secret
assert(not alice.recipesModule:ScanOpen(false) and alice.recipesModule:State().count == 1)
alice.linked, alice.guildWindow = false, true
assert(not alice.recipesModule:ScanOpen(false) and alice.recipesModule:State().count == 1)
alice.guildWindow = false

timers = {}
alice.recipesModule.scheduled, bob.recipesModule.scheduled = {}, {}
alice.recipesModule.sending, bob.recipesModule.sending = false, false
bob.online = false
alice.recipesModule.events.callback(nil, "GUILD_ROSTER_UPDATE")
alice.recipesModule.professionEvents.callback(nil, "TRADE_SKILL_LIST_UPDATE")
NextTimer()
Drain()
assert(alice.recipesModule:State().count == 2)
bob.online = true
Use(bob)
bob.recipesModule.events.callback(nil, "GUILD_ROSTER_UPDATE")
assert(bob.recipesModule:SyncNext())
Pump()
local steps = 0
while bob.recipesModule.pull do
	steps = steps + 1
	assert(steps < 3000, "recipe catch-up did not finish")
	NextTimer()
end
Use(bob)
assert(#bob.recipesModule:Search("11") == 1)
local state = bob.recipesModule:State()
Use(alice)
local before = alice.recipesModule:State().revision
assert(alice.recipesModule:ScanOpen(false) and alice.recipesModule:State().revision == before)
timers = {}
alice.recipesModule.sending = false
now = now + 3601
alice.recipes[10].name = "Strong Healing Potion"
assert(alice.recipesModule:ScanOpen(false))
Drain()
Use(bob)
reports = bob.recipesModule:Search("strong")
assert(#reports == 1 and reports[1].id == 10)
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
	GetSelectedProfessionRecipeID = function() return 10 end,
}
bob.recipesModule:Toggle()
assert(bob.recipesModule.window:IsShown())
bob.recipesModule.input:SetText("strong")
bob.recipesModule:Refresh()
assert(#bob.recipesModule.window.rows == 1
	and bob.recipesModule.window.rows[1].text:find("Alice-Realm", 1, true)
	and bob.recipesModule.window.status.text:find("outdated", 1, true))
bob.recipesModule.window:Hide()
bob.recipesModule:OpenForProfession()
assert(bob.recipesModule.window:IsShown() and bob.recipesModule.input:GetText() == "10")
assert(#bob.recipesModule.window.rows == 1 and bob.recipesModule.window.rows[1].text:find("Alice-Realm", 1, true))
local search = bob.recipesModule.Search
local many = {}
for index = 1, 201 do many[index] = reports[1] end
bob.recipesModule.Search = function() return many end
bob.recipesModule:Refresh()
assert(#bob.recipesModule.window.rows == 200 and bob.recipesModule.window.status.text:find("201", 1, true))
bob.recipesModule.Search = search
alice.guild = "OtherGuild"
bob.recipesModule.events.callback(nil, "GUILD_ROSTER_UPDATE")
assert(#bob.recipesModule:Search("10") == 0)
alice.guild = "Guild"
bob.recipesModule.events.callback(nil, "GUILD_ROSTER_UPDATE")
assert(#bob.recipesModule:Search("10") == 1)
bob.recipesModule:SetEnabled(false)
local missing, problem = bob.recipesModule:Search("10")
assert(not missing and problem:find("Enable", 1, true) and state.count == 2)
assert(bob.recipesModule:SetEnabled(true))
assert(#bob.recipesModule:Search("10") == 1)
bob.guild = "OtherGuild"
missing = bob.recipesModule:Search("10")
assert(not missing and not bob.recipesModule.db.enabled)
print("guild_recipes: all tests passed")
