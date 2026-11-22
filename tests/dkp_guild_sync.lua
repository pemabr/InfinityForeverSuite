local frames, timers, messages, warnings = {}, {}, {}, {}
local player, masterRank, guild, realm, now = "Master", 0, "My Guild", "HomeRealm", 100
local sendResults = {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame()
	local frame = setmetatable({ events = {}, scripts = {} }, meta)
	frames[#frames + 1] = frame
	return frame
end
local db = {}
InfinityCore = { GetDatabase = function() return db end }
InfinityUtils = { Warning = function(_, message) warnings[#warnings + 1] = message end }
InfinityDKPUI = { Update = function() end }
IsInGuild = function() return true end
GetGuildInfo = function()
	return guild, "Rank", player == "Master" and masterRank or 1, "Home Realm"
end
GetNormalizedRealmName = function() return realm end
UnitName = function() return player end
GetNumGuildMembers = function() return 2 end
GetGuildRosterInfo = function(index)
	if index == 1 then return "Master-HomeRealm", "Master", masterRank end
	return "Member-OtherRealm", "Member", 1
end
GetTime = function() return now end
time = function() return 100000 + now end
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityDKP1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel)
		assert(prefix == "InfinityDKP1" and channel == "GUILD")
		local result = table.remove(sendResults, 1)
		if result == nil or result == 0 then messages[#messages + 1] = message end
		return result
	end,
}

dofile("InfinityDKP\\Core\\DKPEngine.lua")
dofile("InfinityDKP\\Modules\\GuildSync.lua")
InfinityDKPEngine:Initialize()
InfinityDKPGuildSync:Initialize()
assert(InfinityDKPGuildSync.available and frames[#frames].events.CHAT_MSG_ADDON)
assert(InfinityDKPEngine:AddPlayer("Master", "MAGE"))
assert(InfinityDKPEngine:AddPlayer("Member-HomeRealm", "WARRIOR"))
assert(InfinityDKPEngine:AwardEP("Master", 100))
assert(InfinityDKPEngine:AwardGP("Master", 20))
assert(InfinityDKPEngine:SetSystemType("dkp"))
assert(InfinityDKPEngine:AdjustDKP("Master", -5, "test"))
db.players.Master.notes = "private note"
assert(InfinityDKPEngine:AddPlayer("Master-HomeRealm"))
assert(not InfinityDKPGuildSync:Send() and #messages == 0)
assert(InfinityDKPEngine:RemovePlayer("Master-HomeRealm"))
sendResults = { 0, 3, 0, 0, 0 }
assert(InfinityDKPGuildSync:Send())
assert(not InfinityDKPGuildSync:Send())
while #timers > 0 do table.remove(timers, 1).callback() end
assert(#messages == 4 and messages[1]:find("^B~") and messages[4]:find("^E~"))

player, realm = "Member", "OtherRealm"
db = {}
InfinityDKPEngine:Initialize()
assert(InfinityDKPEngine:AddPlayer("Local", "DRUID"))
assert(InfinityDKPEngine:AddPlayer("Master-HomeRealm", "MAGE"))
db.players["Master-HomeRealm"].notes = "private member note"
local original = db.players
local function receive(message, sender, channel)
	InfinityDKPGuildSync:OnMessage("InfinityDKP1", message, channel or "GUILD", sender or "Master-HomeRealm")
end
receive(messages[1], "Member-HomeRealm")
receive(messages[1], "Master-OtherRealm")
receive(messages[1], nil, "PARTY")
assert(not InfinityDKPGuildSync.incoming and not InfinityDKPGuildSync.pending)
receive(messages[1])
receive(messages[3])
assert(not InfinityDKPGuildSync.incoming and #warnings > 0)
receive(messages[1])
receive(messages[2])
receive(messages[4])
assert(not InfinityDKPGuildSync.pending and not InfinityDKPGuildSync.incoming)
receive(messages[1])
local token = messages[1]:match("^B~([^~]+)")
receive("P~" .. token .. "~1~Master~MAGE~nan~0~0~1")
assert(not InfinityDKPGuildSync.incoming and not InfinityDKPGuildSync.pending)

for _, message in ipairs(messages) do receive(message) end
assert(InfinityDKPGuildSync.pending and db.players == original and db.players.Local)
InfinityDKPGuildSync:MarkSnapshotsStale()
assert(not InfinityDKPGuildSync:Apply() and db.players == original)
assert(InfinityDKPGuildSync:Discard())
for _, message in ipairs(messages) do receive(message) end
masterRank = 1
assert(not InfinityDKPGuildSync:Apply() and db.players == original and not InfinityDKPGuildSync.pending)
masterRank = 0
for _, message in ipairs(messages) do receive(message) end
guild = "Other Guild"
assert(not InfinityDKPGuildSync:Apply() and db.players == original)
guild = "My Guild"
for _, message in ipairs(messages) do receive(message) end
assert(InfinityDKPGuildSync:Apply())
assert(db.players["Master-homerealm"].ep == 100 and db.players["Master-homerealm"].gp == 20)
assert(db.system_type == "dkp" and db.players["Master-homerealm"].dkp == -5)
assert(db.players["Master-homerealm"].notes == "private member note" and not db.players.Local)
assert(db.syncBackup.players == original)
assert(InfinityDKPGuildSync:Undo())
assert(db.players == original and db.players.Local and not db.syncBackup)
assert(not InfinityDKPGuildSync:Undo())
assert(not InfinityDKPGuildSync:Send())

for _, message in ipairs(messages) do receive(message) end
assert(InfinityDKPGuildSync:Discard() and db.players == original)
assert(not InfinityDKPGuildSync.pending)
realm = "HomeRealm"
for _, message in ipairs(messages) do receive(message) end
assert(InfinityDKPGuildSync.pending.players.Master)
assert(InfinityDKPGuildSync:Discard())
realm = "OtherRealm"
receive(messages[1])
assert(InfinityDKPGuildSync.incoming)
timers[#timers].callback()
assert(not InfinityDKPGuildSync.incoming and warnings[#warnings]:find("timed out", 1, true))
player, realm = "Master", "HomeRealm"
local secret = {}
issecretvalue = function(value) return value == secret end
sendResults = { secret }
assert(InfinityDKPGuildSync:Send())
assert(not InfinityDKPGuildSync.outgoing and warnings[#warnings]:find("protected result", 1, true))
print("dkp_guild_sync: all tests passed")
