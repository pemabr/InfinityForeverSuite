local current, now, queue, timers, messages, warnings, results = nil, 100, {}, {}, {}, {}, {}
local secret = {}
local roster = { "Alice-HomeRealm", "Bob-HomeRealm", "Mallory-HomeRealm" }
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame()
	return setmetatable({ events = {}, scripts = {} }, meta)
end
issecretvalue = function(value) return value == secret end
GetTime = function() return now end
time = function() return 100000 + math.floor(now) end
IsLoggedIn = function() return false end
InCombatLockdown = function() return false end
IsInGuild = function() return true end
GetGuildInfo = function() return current.guild, "Member", 1, "HomeRealm" end
GetNormalizedRealmName = function() return "HomeRealm" end
UnitName = function() return current.name end
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(index) return roster[index] end
InfinityUtils = {
	GetTimeStamp = function() return time() end,
	Warning = function(_, text) warnings[#warnings + 1] = current.name .. ": " .. text end,
}
InfinityStorageManager = {
	GetFeatureSetting = function(_, _, key, default) return current.db[key] or default end,
	SetFeatureSetting = function(_, _, key, value) current.db[key] = value end,
}
InfinityDataManager = { UpdateSourceData = function() return true end }
InfinityGuideUI = { RefreshGuides = function() end }
C_Timer = { After = function(delay, callback)
	timers[#timers + 1] = { when = now + delay, callback = callback, client = current }
end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityGdP1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel, target)
		assert(prefix == "InfinityGdP1" and (channel == "GUILD" or channel == "WHISPER") and #message <= 240)
		assert(channel ~= "WHISPER" or target)
		local result = table.remove(results, 1)
		if result == nil or result == 0 then
			queue[#queue + 1] = { prefix = prefix, message = message, sender = current.name .. "-HomeRealm", channel = channel, target = target }
		end
		return result
	end,
}
local chain = { [100] = 101, [101] = 0 }
LibQuestieDB = {
	RequireContract = function(version) assert(version == 1); return true end,
	Quest = {
		Exists = function(id) return chain[id] ~= nil end,
		nextQuestInChain = function(id) return chain[id] end,
	},
}
StaticPopup_Show = function(which, arg1, arg2, data)
	messages[#messages + 1] = { client = current.name, which = which, arg = arg1, data = data }
	return true
end
local clients = {}
local function Use(client)
	current = client
	InfinityGuideGuides, InfinityGuideSources, InfinityGuideGuildPresets = client.guides, client.sources, client.network
	InfinityEncounterAbilities, InfinityEncounterPresets = client.abilities, client.presets
	InfinityShoppingLists = client.shopping
	StaticPopupDialogs = client.dialogs
end
for _, name in ipairs({ "Alice", "Bob", "Mallory" }) do
	local client = { name = name, guild = "Guild", db = {}, dialogs = {}, abilities = { watchedSpells = {} } }
	Use(client)
	client.guides = dofile("InfinityGuide\\Modules\\Guides.lua")
	client.sources = dofile("InfinityGuide\\Modules\\Sources.lua")
	client.network = dofile("InfinityGuide\\Modules\\GuildPresets.lua")
	client.presets = dofile("InfinityEncounter\\Modules\\Presets.lua")
	Use(client)
	assert(client.guides:Initialize())
	client.sources:Initialize()
	client.network:Initialize()
	assert(client.presets:Initialize(client.db))
	clients[name] = client
end
local alice, bob, mallory = clients.Alice, clients.Bob, clients.Mallory
local function At(client, target, method, ...)
	Use(client)
	return client[target][method](client[target], ...)
end
local function Pump()
	while #queue > 0 do
		local packet = table.remove(queue, 1)
		for _, client in pairs(clients) do
			if client.online ~= false and (packet.channel == "GUILD" or packet.target:lower() == (client.name .. "-HomeRealm"):lower()) then
				Use(client)
				client.network:OnMessage(packet.prefix, packet.message, packet.channel, packet.sender)
			end
		end
	end
end
local function NextTimer()
	table.sort(timers, function(a, b) return a.when < b.when end)
	local nextTimer = table.remove(timers, 1)
	now = nextTimer.when
	Use(nextTimer.client)
	nextTimer.callback()
	Pump()
end
local function CompleteSend(client)
	client = client or alice
	Pump()
	while client.network.outgoing do NextTimer() end
end

Use(alice)
alice.sources.frame.scripts.OnEvent(alice.sources.frame, "PLAYER_LOGIN")
assert(messages[#messages].which == "INFINITY_GUIDE_QUESTIEDB")
alice.dialogs.INFINITY_GUIDE_QUESTIEDB.OnCancel()
assert(not alice.db.sourceDecisions.QuestieDB and not At(alice, "sources", "ImportChain", 100))
assert(At(alice, "sources", "SetAllowed", true))
assert(At(alice, "sources", "ImportChain", 100))
local imported = alice.guides.guides.guide_1
assert(imported and imported.type == "QuestieDB" and #imported.steps == 2)
assert(imported.steps[1].questID == 100 and imported.steps[2].questID == 101)
assert(alice.guides.activeGuide == nil)
chain[101] = 100
assert(not At(alice, "sources", "ImportChain", 100) and not alice.guides.guides.guide_2)
chain[101] = 0

local original = At(bob, "guides", "CreateGuide", "Existing")
assert(original and bob.guides.activeGuide == original.id)
local guide = At(alice, "guides", "CreateGuide", "Forest \195\164")
assert(At(alice, "guides", "AddGuideStep", guide.id, 1, "Find ~ herbs", 100))
assert(At(alice, "guides", "SetStepDone", guide.id, 1, true))
results = { 3, 0, 0, 0 }
assert(At(alice, "network", "Send", guide.id))
CompleteSend()
assert(bob.network.pending and bob.guides.activeGuide == original.id and not bob.guides.guides.guide_2)
local oldPending = bob.network.pending
Use(bob)
assert(bob.dialogs.INFINITY_GUIDE_GUILD_PRESET and messages[#messages].which == "INFINITY_GUIDE_GUILD_PRESET")
assert(bob.network:Accept())
local received = bob.guides.guides.guide_2
assert(received.name == "Forest \195\164" and received.steps[1].description == "Find ~ herbs")
assert(received.steps[1].questID == 100 and not received.steps[1].done and bob.guides.activeGuide == original.id)
assert(At(alice, "network", "Send", imported.id))
CompleteSend()
assert(bob.network.pending)
Use(bob)
bob.dialogs.INFINITY_GUIDE_GUILD_PRESET.OnAccept(nil, oldPending)
assert(bob.network.pending and not bob.guides.guides.guide_3)
local pending = bob.network.pending
bob.guild = "DifferentGuild"
assert(not bob.network:Accept() and bob.network.pending == pending)
bob.guild = "Guild"
assert(bob.network:Discard() and not bob.network.pending)
assert(At(alice, "network", "Send", nil, true))
CompleteSend()
assert(bob.network.pending and bob.network.waiting and #bob.network.waiting == 1)
assert(At(bob, "network", "Accept"))
assert(bob.guides.guides.guide_3 and bob.guides.activeGuide == original.id and bob.network.pending)
assert(At(bob, "network", "Discard") and not bob.network.pending)

Use(bob)
bob.network:OnMessage("InfinityGdP1", "B~1-1~0~54657374", "GUILD", "Stranger-HomeRealm")
assert(not bob.network.incoming or not next(bob.network.incoming))
bob.network:OnMessage("InfinityGdP1", "B~1-1~1~54657374", "GUILD", "Alice-HomeRealm")
assert(next(bob.network.incoming))
bob.network:OnMessage("InfinityGdP1", "S~1-1~2~0~626164", "GUILD", "Alice-HomeRealm")
assert(not next(bob.network.incoming))
bob.network:OnMessage("InfinityGdP1", "B~1-2~1~54657374", "GUILD", "Alice-HomeRealm")
bob.network:OnMessage("InfinityGdP1", "E~1-2", "GUILD", "Alice-HomeRealm")
assert(not bob.network.pending and not next(bob.network.incoming))
Use(alice)
guide.steps[1].description = secret
assert(not alice.network:Send(guide.id))
guide.steps[1].description = "Find ~ herbs"
guide.steps[1].images = { "unsupported" }
assert(not alice.network:Send(guide.id))
guide.steps[1].images = {}

alice.abilities.watchedSpells[42] = "Fire blast"
alice.abilities.watchedSpells[51] = "Explosion"
bob.abilities.watchedSpells[123] = "Existing"
assert(At(alice, "presets", "Create", "First boss"))
assert(At(alice, "presets", "Send", "preset_1"))
CompleteSend()
assert(bob.network.pending and bob.network.pending.kind == "E")
assert(not bob.presets.presets.preset_1 and bob.abilities.watchedSpells[123])
assert(At(bob, "network", "Accept"))
assert(bob.presets.presets.preset_1 and bob.abilities.watchedSpells[123])
assert(At(bob, "presets", "Use", "preset_1"))
assert(bob.abilities.watchedSpells[42] == "Fire blast" and bob.abilities.watchedSpells[51] == "Explosion")
assert(not bob.abilities.watchedSpells[123])
assert(At(bob, "presets", "Use", "none") and not next(bob.abilities.watchedSpells))
assert(At(bob, "presets", "Delete", "preset_1"))
assert(not At(bob, "presets", "Use", "preset_1"))
assert(At(alice, "network", "Send", nil, true))
CompleteSend()
assert(bob.network.pending and #bob.network.waiting == 2)
assert(At(bob, "network", "Discard") and At(bob, "network", "Discard"))
assert(bob.network.pending.kind == "E" and At(bob, "network", "Accept"))
assert(bob.presets.presets.preset_1 and not next(bob.abilities.watchedSpells))
alice.presets.presets.preset_2 = { name = "Invalid", steps = { { questID = 0, description = "Bad" } } }
assert(not At(alice, "network", "Send", nil, true) and not alice.network.outgoing and #queue == 0)
alice.presets.presets.preset_2 = nil
assert(not At(bob, "presets", "Save", "Bad", {
	{ questID = 42, description = "one" }, { questID = 42, description = "duplicate" },
}))

bob.online = false
local late = At(alice, "guides", "CreateGuide", "While Bob was offline")
assert(At(alice, "guides", "AddGuideStep", late.id, 1, "Late step"))
assert(At(alice, "network", "Send", late.id))
CompleteSend()
local secondLate = At(mallory, "guides", "CreateGuide", "Other publisher")
assert(At(mallory, "guides", "AddGuideStep", secondLate.id, 1, "Other step"))
assert(At(mallory, "network", "Send", secondLate.id))
CompleteSend(mallory)
assert(not bob.network.pending)

Use(alice)
alice.network = dofile("InfinityGuide\\Modules\\GuildPresets.lua")
Use(alice)
alice.network:Initialize()
assert(alice.presets:Connect())
assert(alice.db.guildPresets["guild-homerealm"].published["G:" .. late.id])
bob.online = true
Use(bob)
bob.network.frame.scripts.OnEvent(bob.network.frame, "PLAYER_ENTERING_WORLD")
while not bob.network.lastRequest or alice.network.outgoing or mallory.network.outgoing do NextTimer() end
assert(bob.network.pending and bob.network.waiting and #bob.network.waiting == 1)
local names = { [bob.network.pending.name] = true, [bob.network.waiting[1].name] = true }
assert(names["While Bob was offline"] and names["Other publisher"])
assert(At(bob, "network", "Accept") and At(bob, "network", "Discard"))
assert(not bob.network.pending)
while alice.network.outgoing or bob.network.outgoing or mallory.network.outgoing do NextTimer() end
Use(bob)
bob.network = dofile("InfinityGuide\\Modules\\GuildPresets.lua")
Use(bob)
bob.network:Initialize()
assert(bob.presets:Connect())
now = now + 61
results = { 3, 0 }
assert(At(bob, "network", "Request"))
Pump()
while #results > 0 or alice.network.outgoing or bob.network.outgoing or mallory.network.outgoing do NextTimer() end
assert(not bob.network.pending and (not bob.network.waiting or #bob.network.waiting == 0))
assert(At(alice, "network", "Unpublish", "G:" .. late.id))
assert(not alice.db.guildPresets["guild-homerealm"].published["G:" .. late.id])
assert(At(mallory, "network", "Unpublish", "all"))
assert(not next(mallory.db.guildPresets["guild-homerealm"].published))

bob.online = false
local later = At(alice, "guides", "CreateGuide", "Publisher returns later")
assert(At(alice, "guides", "AddGuideStep", later.id, 1, "New step"))
assert(At(alice, "network", "Send", later.id))
CompleteSend()
alice.online, bob.online = false, true
now = now + 61
assert(At(bob, "network", "Request"))
Pump()
while bob.network.outgoing or mallory.network.outgoing do NextTimer() end
assert(not bob.network.pending)
alice.online = true
Use(alice)
alice.network.frame.scripts.OnEvent(alice.network.frame, "PLAYER_ENTERING_WORLD")
while not alice.network.lastRequest or alice.network.outgoing or bob.network.outgoing or mallory.network.outgoing do NextTimer() end
assert(bob.network.pending and bob.network.pending.name == "Publisher returns later")
assert(At(bob, "network", "Accept"))
assert(bob.db.guildPresets["guild-homerealm"].published["G:guide_5"])
for _, client in pairs(clients) do
	Use(client)
	client.shopping = dofile("InfinityInventory\\Modules\\ShoppingLists.lua")
	assert(client.shopping:Initialize())
end
local existing = At(bob, "shopping", "Save", "Existing", {}, true)
local list = At(alice, "shopping", "Save", "Raid materials", {}, true)
assert(At(alice, "shopping", "SetItem", 765, 20))
assert(At(alice, "shopping", "SetItem", 2770, 5))
assert(At(alice, "shopping", "Share", list))
CompleteSend()
assert(bob.network.pending and bob.network.pending.kind == "S")
assert(bob.network.pending.steps[1].itemID == 765 and bob.network.pending.steps[1].description == "20")
assert(At(bob, "network", "Accept"))
assert(bob.shopping.active == existing and bob.shopping.lists.shopping_2.steps[2].itemID == 2770)
assert(bob.db.guildPresets["guild-homerealm"].published["S:shopping_2"])
assert(At(alice, "shopping", "SetItem", 765, 99))
assert(bob.shopping.lists.shopping_2.steps[1].description == "20")
assert(alice.db.guildPresets["guild-homerealm"].published["S:shopping_1"].steps[1].description == "20")
assert(At(alice, "shopping", "Share", list))
CompleteSend()
assert(bob.network.pending and bob.network.pending.steps[1].description == "99")
assert(At(bob, "network", "Discard"))
assert(At(alice, "network", "Unpublish", "S:" .. list))
assert(not alice.db.guildPresets["guild-homerealm"].published["S:" .. list])
assert(bob.shopping.lists.shopping_2.steps[1].description == "20")
print("guide_presets: all tests passed")
