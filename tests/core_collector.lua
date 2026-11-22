local frames, published = {}, {}
local secret = {}
issecretvalue = function(value) return value == secret end
InfinityUtils = {
	Info = function() end,
	CanUseCombatLogEvent = function() return false end,
	GetItemInfo = function() return "Item", nil, 2 end,
}
InfinityMessaging = { Publish = function(_, ...) published[#published + 1] = { ... } end }
C_Timer = { NewTicker = function() end }
GetZoneText = function() return "Zone" end
GetServerTime = function() return 100 end
GetNumLootItems = function() return 2 end
GetLootSlotLink = function(slot) if slot == 1 then return "|Hitem:456:0|h[Item]|h" end return secret end
C_QuestLog = {
	GetTitleForQuestID = function(id) if id == 10 then return "Quest" end end,
	GetLogIndexForQuestID = function(id) if id == 10 then return 1 end end,
	GetInfo = function() return { title = "Quest", level = 30 } end,
}
function CreateFrame()
	local frame = { events = {}, scripts = {} }
	function frame:RegisterEvent(event) self.events[event] = true end
	function frame:SetScript(name, callback) self.scripts[name] = callback end
	frames[#frames + 1] = frame
	return frame
end
dofile("InfinityCore\\Modules\\DataCollector.lua")
local collector = InfinityCoreDataCollector
collector:Initialize()
local events = frames[1]
assert(events.events.QUEST_ACCEPTED and events.events.QUEST_TURNED_IN)
assert(not events.events.QUEST_TURN_IN and not events.events.QUEST_COMPLETE)
events.scripts.OnEvent(events, "QUEST_ACCEPTED", 10)
assert(#collector.queues.questData == 1)
local quest = collector.queues.questData[1]
assert(quest.id == 10 and quest.name == "Quest" and quest.level == 30 and quest.startLocation == nil)
events.scripts.OnEvent(events, "QUEST_ACCEPTED", 11)
events.scripts.OnEvent(events, "QUEST_ACCEPTED", secret)
assert(#collector.queues.questData == 1)
events.scripts.OnEvent(events, "QUEST_TURNED_IN", 10)
assert(published[1][1] == "quest_completed" and published[1][2] == 10)
events.scripts.OnEvent(events, "QUEST_TURNED_IN", secret)
assert(#published == 1)
events.scripts.OnEvent(events, "LOOT_OPENED")
assert(#collector.queues.dropData == 1 and collector.queues.dropData[1].itemId == 456)
C_QuestLog.GetTitleForQuestID = function() return secret end
events.scripts.OnEvent(events, "QUEST_ACCEPTED", 10)
assert(#collector.queues.questData == 2 and collector.queues.questData[2].name == "Quest")
print("core_collector: all tests passed")
