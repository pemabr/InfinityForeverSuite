local frames, timers, messages, warnings, results = {}, {}, {}, {}, {}
local player, realm, guild, inguild = "Master", "HomeRealm", "Guild", true
local db = {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame()
	local frame = setmetatable({ events = {}, scripts = {} }, meta)
	frames[#frames + 1] = frame
	return frame
end
time = function() return 100000 end
local secret = {}
issecretvalue = function(value) return value == secret end
GetGuildInfo = function() return guild, "Member", 0, "Home Realm" end
GetNormalizedRealmName = function() return realm end
IsInGuild = function() return inguild end
UnitName = function() return player end
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityDC1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel)
		assert(prefix == "InfinityDC1" and channel == "GUILD" and #message <= 240)
		local result = table.remove(results, 1)
		if result == nil or result == 0 then messages[#messages + 1] = message end
		return result
	end,
}
InfinityUtils = {
	Warning = function(_, message) warnings[#warnings + 1] = message end,
}
InfinityCore = { GetDatabase = function() return db end }
dofile("InfinityDataCollector\\Core\\DataCollectorCore.lua")
dofile("InfinityDataCollector\\Modules\\Network.lua")
local core, network = InfinityDataCollectorCore, InfinityDataCollectorNetwork
core:Initialize()
network:Initialize()
assert(network.available and not network.shareEnabled and not network:Send())
assert(network:SetSharingEnabled(true) and db.network.enabled)
core:RecordQuestData(123, "Herbs", 10, "Giver", nil, nil, "Meadow", "Private objective", {})
core:RecordDropData(444, "Wolf", 456, "Item", nil, nil)
results = { 0, 3, 0, 0, 0 }
assert(network:Send())
assert(not network:Send())
while #timers > 0 do table.remove(timers, 1).callback() end
assert(#messages == 4 and messages[1]:find("^B~") and messages[4]:find("^E~"))
for _, message in ipairs(messages) do assert(not message:find("Private objective", 1, true)) end
local snapshot = messages
player, realm, db, timers, messages = "Member", "OtherRealm", {}, {}, {}
core:Initialize()
dofile("InfinityDataCollector\\Modules\\Network.lua")
network = InfinityDataCollectorNetwork
network:Initialize()
assert(network:SetSharingEnabled(true))
core:RecordQuestData(123, "Existing", 20, nil, nil, nil, nil, nil, nil)
local function receive(message, sender, channel)
	network.frame.scripts.OnEvent(network.frame, "CHAT_MSG_ADDON", "InfinityDC1", message,
		channel or "GUILD", sender or "Master-HomeRealm")
end
receive(snapshot[1], "Member-OtherRealm")
receive(snapshot[1], nil, "PARTY")
assert(not network.incoming and not network.pending)
for _, message in ipairs(snapshot) do receive(message) end
assert(network.pending and network.pending.count == 2 and not db.gatheredData.drops["444_456"])
guild = "Other Guild"
assert(not network:Apply() and network.pending)
guild = "Guild"
assert(network:Apply())
assert(db.gatheredData.quests[123].name == "Existing")
assert(db.gatheredData.drops["444_456"].itemName == "Item")
assert(db.gatheredData.drops["444_456"].rarity == nil)
for _, message in ipairs(snapshot) do receive(message) end
assert(network:Discard() and not network.pending)
receive(snapshot[1])
receive(snapshot[4])
assert(not network.pending and not network.incoming)
receive("B~100-8~1")
receive("Q~100-8~1~9999999999~1~Bad")
receive("E~100-8")
assert(not network.pending and not network.incoming)
receive(snapshot[1])
assert(network.incoming)
assert(network:Discard() and not network.incoming)
receive(snapshot[1])
assert(network.incoming)
timers[#timers].callback()
assert(not network.incoming and warnings[#warnings]:find("timed out", 1, true))
core.gatheredData.quests[123].name = "Bad~name"
assert(not network:Send())
core.gatheredData.quests[123].name = secret
assert(not network:Send())
core.gatheredData.quests[123].name = "Existing"
inguild = false
assert(not network:Send())
inguild = true
results = { 5 }
assert(not network:Send() and not network.outgoing)
assert(network:SetSharingEnabled(false) == false and not db.network.enabled)
print("datacollector_guild_sync: all tests passed")
