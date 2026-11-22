local now, timers, warnings = 100, {}, {}
time = function() return 100000 end
GetTime = function() return now end
IsInGuild = function() return true end
GetGuildInfo = function() return "Guild", nil, nil, "Realm" end
GetNormalizedRealmName = function() return "Realm" end
UnitName = function() return "Bob" end
GetNumGuildMembers = function() return 2 end
GetGuildRosterInfo = function(index)
	return (index == 1 and "Bob-Realm" or "Alice-Realm"), nil, nil, nil, nil, nil, nil, nil, true
end
function CreateFrame()
	return { RegisterEvent = function() end, SetScript = function() end }
end
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function() return 0 end,
	SendAddonMessage = function() return 0 end,
}
InfinityUtils = { Warning = function(_, text) warnings[#warnings + 1] = text end }
InfinityDataCollectorCore = { db = {}, gatheredData = { quests = {}, drops = {} } }
function InfinityDataCollectorCore:RecordQuestData(id, name, level)
	self.gatheredData.quests[id] = { name = name, level = level }
end
local knowledge = dofile("InfinityDataCollector\\Modules\\GuildKnowledge.lua")
knowledge:Initialize()
assert(knowledge:SetEnabled(true))
local state, guild = knowledge:State()
knowledge.scheduled, knowledge.sending, knowledge.queue = {}, false, {}
timers = {}
assert(knowledge:Request({ name = "Alice-Realm", key = "alice-realm" }, state, guild))
local pull, timeout = knowledge.pull, timers[1].callback
assert(timers[1].delay == 240)
now = 330
knowledge:OnMessage("InfinityKnow1", "B~" .. pull.token .. "~123-1~0~2~2~0", "WHISPER", "Alice-Realm")
now = 340
timeout()
assert(knowledge.pull == pull and timers[#timers].delay == 230)
timeout = timers[#timers].callback
now = 550
knowledge:OnMessage("InfinityKnow1", "Q~" .. pull.token .. "~1~1~101~5~First", "WHISPER", "Alice-Realm")
now = 570
timeout()
assert(knowledge.pull == pull and timers[#timers].delay == 220)
timeout = timers[#timers].callback
now = 780
knowledge:OnMessage("InfinityKnow1", "Q~" .. pull.token .. "~2~2~102~5~Second", "WHISPER", "Alice-Realm")
knowledge:OnMessage("InfinityKnow1", "E~" .. pull.token, "WHISPER", "Alice-Realm")
assert(not knowledge.pull and state.cursors["alice-realm"].revision == 2)
assert(InfinityDataCollectorCore.gatheredData.quests[101] and InfinityDataCollectorCore.gatheredData.quests[102])
now = 790
timeout()
assert(#warnings == 0)
knowledge.sending, knowledge.queue, timers = false, {}, {}
assert(knowledge:Request({ name = "Alice-Realm", key = "alice-realm" }, state, guild))
now = now + 240
timers[1].callback()
assert(not knowledge.pull and warnings[#warnings]:find("timed out", 1, true))
print("guild_knowledge_timeout: all tests passed")
