local frames, commands, timers, messages, warnings, subscriptions = {}, {}, {}, {}, {}, {}
local questVisible, collapsed, objective = true, false, "Gather 2/5"
local watch = { [101] = 0 }
local combat = false
local secret = {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return rawget(self, "text") or "" end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name, parent)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local frame = setmetatable({ events = {}, scripts = {}, parent = parent, shown = true }, meta)
	if name then _G[name] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
SlashCmdList = {}
InfinityUtils = {
	Info = function() end,
	Warning = function(_, message) warnings[#warnings + 1] = message end,
}
InfinityMessaging = {
	Subscribe = function(_, event, callback) subscriptions[event] = callback end,
	Publish = function() end,
}
InfinityCore = {
	RegisterAddon = function() end,
	RegisterCommand = function(_, command, _, callback) commands[command] = callback end,
}
GetTime = function() return 100 end
InCombatLockdown = function() return combat end
issecretvalue = function(value) return value == secret end
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
C_QuestLog = {
	GetNumQuestLogEntries = function() return questVisible and 3 or 1 end,
	GetInfo = function(index)
		if index == 1 then return { isHeader = true, isCollapsed = collapsed, title = "Zone" } end
		if index == 2 then return { questID = 101, title = "A herb quest" } end
		return { questID = 102, title = secret }
	end,
	GetQuestObjectives = function(id)
		assert(id == 101)
		return { { text = objective }, { text = secret } }
	end,
	GetQuestWatchType = function(id) return watch[id] end,
	AddQuestWatch = function(id) watch[id] = 0; return true end,
	RemoveQuestWatch = function(id) watch[id] = nil; return true end,
}
local originalPrint = print
print = function(message) messages[#messages + 1] = tostring(message) end

dofile("InfinityCore\\Core\\Utilities.lua")
InfinityUtils.Info = function() end
InfinityUtils.Warning = function(_, message) warnings[#warnings + 1] = message end
dofile("InfinityCore\\UI\\UIFramework.lua")
for line in io.lines("InfinityQuestie\\InfinityQuestie.toc") do
	if line:match("%.lua%s*$") and not line:match("^%s*#") then
		dofile("InfinityQuestie\\" .. line:match("^%s*(.-)%s*$"))
	end
end
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityQuestie")
assert(InfinityQuestTracker:GetActiveQuests()[101].name == "A herb quest")
assert(commands["/questcompass"])
assert(not InfinityQuestieDBSync.questieAvailable and not InfinityQuestieDBSync.syncInProgress)
commands["/questie"]()
assert(InfinityQuestieUI.frame:IsShown())
assert(InfinityQuestieUI.frame.rows[1].data.text == "[Tracked] A herb quest")
assert(InfinityQuestieUI.frame.rows[2].data.text == "    Gather 2/5")
InfinityQuestieUI.compassButton.scripts.OnClick(InfinityQuestieUI.compassButton)
assert(InfinityQuestCompass.frame:IsShown() and InfinityQuestCompass.frame.display.text:find("No target", 1, true))
InfinityQuestieUI.compassButton.scripts.OnClick(InfinityQuestieUI.compassButton)
InfinityQuestieUI.frame.rows[1].scripts.OnClick(InfinityQuestieUI.frame.rows[1])
assert(watch[101] == nil and InfinityQuestieUI.frame.rows[1].data.text == "A herb quest")
combat = true
InfinityQuestieUI.frame.rows[1].scripts.OnClick(InfinityQuestieUI.frame.rows[1])
assert(watch[101] == nil and #warnings == 1)
combat = false
collapsed = true
InfinityQuestieUI:Update()
assert(InfinityQuestieUI.frame.status.text:find("Collapsed", 1, true))
collapsed = false
objective = "Gather 5/5"
local events
for _, frame in ipairs(frames) do
	if frame.events.QUEST_LOG_UPDATE and frame.events.QUEST_TURNED_IN then events = frame end
end
assert(events)
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
assert(InfinityQuestieUI.frame.rows[2].data.text == "    Gather 5/5")
assert(InfinityQuestTracker:GetActiveQuests()[101].objectives[1] == "Gather 5/5")
commands["/questie search"]("herb")
assert(messages[#messages]:find("A herb quest", 1, true))
InfinityDataCollectorCore = { gatheredData = { quests = {
	[101] = { name = "Older herb quest" },
	[103] = { name = "Guild herb discovery", level = 15 },
	[104] = { name = secret },
} } }
local warningCount = #warnings
local messageCount = #messages
commands["/questie search"]("herb")
assert(messages[messageCount + 1]:find("2", 1, true))
assert(messages[messageCount + 2]:find("A herb quest", 1, true))
assert(messages[messageCount + 3]:find("Guild herb discovery", 1, true))
assert(#warnings == warningCount + 1 and warnings[#warnings]:find("unavailable", 1, true))
commands["/questie search"]("103")
assert(messages[#messages]:find("Guild herb discovery", 1, true))
InfinityQuestieUI:ShowSearch()
local search = InfinityQuestieUI.searchFrame
local searchButton
for _, frame in ipairs(frames) do
	if frame.parent == search and frame.text == "Search" then searchButton = frame end
end
assert(searchButton)
InfinityQuestieUI.searchInput:SetText("herb")
searchButton.scripts.OnClick(searchButton)
assert(search.rows[1].data.text:find("A herb quest", 1, true))
assert(search.rows[2].data.text:find("Guild herb discovery", 1, true))
InfinityQuestieUI.searchInput:SetText(secret)
searchButton.scripts.OnClick(searchButton)
assert(warnings[#warnings]:find("Protected search", 1, true))
InfinityDataCollectorCore = nil
InfinityQuestieUI.routeButton.scripts.OnClick(InfinityQuestieUI.routeButton)
assert(InfinityQuestieUI.routeFrame:IsShown())
assert(InfinityQuestieUI.routeFrame.rows[1].data.text:find("no native waypoint", 1, true))
assert(InfinityQuestRouter:GetWaypoint(101) == nil)

local shift, waypoint, superTracked, mapAllowed, nextX = false, nil, false, true, 0.3
IsShiftKeyDown = function() return shift end
C_QuestLog.GetNextWaypoint = function(id)
	assert(id == 101)
	return 12, nextX, 0.7
end
C_Map = {
	CanSetUserWaypointOnMap = function(id) assert(id == 12); return mapAllowed end,
	SetUserWaypoint = function(point) waypoint = point; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { mapID = map, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(value) superTracked = value end }
C_QuestLog.GetSelectedQuest = function() return 101 end
assert(InfinityQuestieUI:ShowSelectedWaypoint() and waypoint and waypoint.mapID == 12)
C_QuestLog.GetSelectedQuest = function() return secret end
assert(not InfinityQuestieUI:ShowSelectedWaypoint() and warnings[#warnings]:find("Select a quest", 1, true))
assert(not InfinityQuestieUI:ShowSelectedLocations() and warnings[#warnings]:find("Select a quest", 1, true))
waypoint = nil
shift = true
InfinityQuestieUI.frame.rows[1].scripts.OnClick(InfinityQuestieUI.frame.rows[1])
assert(waypoint.mapID == 12 and waypoint.x == 0.3 and waypoint.y == 0.7 and superTracked)
assert(watch[101] == nil)
shift = false
waypoint = nil
commands["/questie waypoint"]("101")
assert(waypoint and waypoint.mapID == 12)
commands["/questie waypoint"]("invalid")
assert(messages[#messages]:find("Usage:", 1, true))
waypoint = nil
nextX = secret
assert(not InfinityQuestRouter:ShowWaypoint(101) and not waypoint)
assert(InfinityQuestRouter:GetWaypoint(secret) == nil)
nextX = 0.3
mapAllowed = false
assert(not InfinityQuestRouter:ShowWaypoint(101) and not waypoint)
mapAllowed, combat = true, true
assert(not InfinityQuestRouter:ShowWaypoint(101) and not waypoint)
combat = false

local originalCount, originalInfo, originalObjectives, originalWaypoint =
	C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo, C_QuestLog.GetQuestObjectives, C_QuestLog.GetNextWaypoint
local routePoints = { [101] = { 12, 0.8, 0.8 }, [102] = { 12, 0.2, 0.2 }, [103] = { 13, 0.3, 0.2 } }
C_QuestLog.GetNumQuestLogEntries = function() return 5 end
C_QuestLog.GetInfo = function(index)
	if index == 1 then return { isHeader = true, isCollapsed = false } end
	local id = index + 99
	return { questID = id, title = "Quest " .. id }
end
C_QuestLog.GetQuestObjectives = function() return {} end
C_QuestLog.GetNextWaypoint = function(id)
	local point = routePoints[id]
	if point then return unpack(point) end
end
C_Map.GetBestMapForUnit = function() return 12 end
C_Map.GetPlayerMapPosition = function() return { x = 0.1, y = 0.1 } end
commands["/questie route"]()
local routeFrame = InfinityQuestieUI.routeFrame
assert(routeFrame.rows[1].data.text:find("Quest 102", 1, true))
assert(routeFrame.rows[2].data.text:find("Quest 101", 1, true))
assert(routeFrame.rows[3].data.text:find("Quest 103", 1, true))
assert(routeFrame.rows[4].data.text:find("Quest 104", 1, true))
waypoint = nil
routeFrame.rows[1].scripts.OnClick(routeFrame.rows[1])
assert(waypoint and waypoint.mapID == 12 and waypoint.x == 0.2)
C_Map.GetPlayerMapPosition = function() return { x = secret, y = 0.1 } end
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
assert(routeFrame.status.text:find("unsorted", 1, true))
assert(routeFrame.rows[1].data.text:find("Quest 101", 1, true))
C_QuestLog.GetNumQuestLogEntries = function() return secret end
local routeWarnings = #warnings
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
assert(routeFrame.status.text:find("unavailable", 1, true) and #warnings == routeWarnings)
commands["/questie route"]()
assert(#warnings == routeWarnings + 1)
C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo = originalCount, originalInfo
C_QuestLog.GetQuestObjectives, C_QuestLog.GetNextWaypoint = originalObjectives, originalWaypoint
C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition = nil, nil
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")

local ids = {}
for i = 1, 202 do ids[i] = i * 1000 end
LibQuestieDB = {
	RequireContract = function(version) assert(version == 1); return true end,
	Quest = {
		GetAllIds = function() return ids end,
		name = function(id) return id == 202000 and "Rare 100% quest" or ("Stored " .. id) end,
		questLevel = function() return 10 end,
	},
}
loader.scripts.OnEvent(loader, "ADDON_LOADED", "QuestieDB")
assert(InfinityQuestieDBSync.syncInProgress and InfinityQuestieDBSync.questsLoaded == 100)
while #timers > 0 do table.remove(timers, 1)() end
assert(InfinityQuestieDBSync.completed and InfinityQuestieDBSync.questsLoaded == 202)
assert(InfinityQuestDB:GetQuest(202000).name == "Rare 100% quest")
InfinityQuestieUI.searchInput:SetText("Stored")
searchButton.scripts.OnClick(searchButton)
assert(#InfinityQuestieUI.searchFrame.rows == 200)
assert(InfinityQuestieUI.searchFrame.status.text:find("Showing first 200", 1, true))
commands["/questie search"]("%")
assert(messages[#messages]:find("Rare 100% quest", 1, true))
LibQuestieDB = {
	RequireContract = function() return true end,
	Quest = {
		GetAllIds = function() return { 1 } end,
		name = function() error("database failed") end,
		questLevel = function() return 1 end,
	},
}
local oldWarnings = #warnings
loader.scripts.OnEvent(loader, "ADDON_LOADED", "QuestieDB")
assert(#warnings == oldWarnings + 1 and not InfinityQuestieDBSync.syncInProgress)
assert(warnings[#warnings]:find("database failed", 1, true))
local flavor = "Forever"
C_AddOns = { GetAddOnMetadata = function() return flavor end }
local spawns = {
	[10] = { [12] = { { 20, 40 }, { 25, 45, 2 }, { -1, -1 }, { secret, 10 } },
		[209] = { { 30, 30 } }, [2257] = { { 30, 30 } } },
	[11] = { [12] = { { 30, 40 } } },
	[12] = { [12] = { { 50, 60 } } },
	[50] = { [12] = { { 70, 80 } } },
}
local zone = {
	private = {
		areaIdToUiMapId = "return {\n [12] = 1429, -- Elwynn\n [209] = 310,\n [2257] = 1429,\n}",
		areaIdToUiMapIdOverride = "return {\n [2257] = 0,\n}",
		dungeons = { [209] = { nil, { 210 } } },
	},
	instanceIdToAreaId = { [1] = 209 },
}
LibQuestieDB = {
	RequireContract = function(version) assert(version == 2); return true end,
	Support = { Get = function(name) assert(name == "ZoneDB"); return zone end },
	Quest = {
		objectives = function(id)
			assert(id == 101)
			return { { { 10 } }, { { 20 } }, { { 30 } }, nil, { { { 11 }, 10 } }, { { 1, "", 31 } } }
		end,
		finishedBy = function() return { { 50 }, {} } end,
	},
	Npc = { name = function(id) return "NPC " .. id end, spawns = function(id) return spawns[id] end },
	Object = { name = function(id) return "Object " .. id end,
		spawns = function(id) return id == 20 and { [12] = { { 10, 20 } } } or nil end },
	Item = {
		npcDrops = function(id) return id == 30 and { 10, 11 } or id == 32 and { 12 } or {} end,
		objectDrops = function(id) return id == 30 and { 20 } or {} end,
		itemDrops = function(id) return id == 31 and { 32 } or {} end,
	},
}
local locations, err, truncated = InfinityQuestLocations:Lookup(101)
assert(not err and not truncated and #locations == 6)
assert(locations[1].name == "NPC 10" and locations[1].mapID == 1429)
assert(locations[2].phase == 2 and locations[#locations].role == "Turn-in")
InfinityQuestLocations.maxResults = 2
local limited, _, wasTruncated = InfinityQuestLocations:Lookup(101)
assert(wasTruncated and #limited == 2 and limited[2].role == "Turn-in")
InfinityQuestLocations.maxResults = 200
assert(InfinityQuestLocations:Lookup(secret) == nil)
C_Map.GetMapInfo = function() return { name = "Elwynn" } end
C_Map.CanSetUserWaypointOnMap = function(id) return id == 1429 end
waypoint, nextX = nil, secret
assert(InfinityQuestRouter:ShowWaypoint(101))
assert(InfinityQuestieUI.locationsFrame:IsShown() and #InfinityQuestieUI.locationsFrame.rows == 6)
InfinityQuestieUI.locationsFrame.rows[2].scripts.OnClick(InfinityQuestieUI.locationsFrame.rows[2])
assert(waypoint.mapID == 1429 and waypoint.x == 0.25 and waypoint.y == 0.45)
InfinityGuildQuestPositions = { GetLocations = function(_, id, limit)
	assert(id == 101 and limit == 194)
	return { { mapID = 1429, x = 0.3, y = 0.4, role = "Quest offer (guild)", name = "Scout" } }, false
end }
assert(InfinityQuestieUI:ShowLocations(101) and InfinityQuestieUI.locationsFrame.rows[7]:IsShown())
assert(InfinityQuestieUI.locationsFrame.rows[7].data.text:find("Quest offer (guild)", 1, true))
C_QuestLog.GetSelectedQuest = function() return 101 end
assert(InfinityQuestieUI:ShowSelectedLocations() and InfinityQuestieUI.locationsQuestID == 101)
InfinityGuildQuestPositions = nil
commands["/questie locations"]("invalid")
assert(messages[#messages]:find("Usage:", 1, true))
InfinityQuestLocations.source = nil
flavor = "Classic"
local unsupported, reason = InfinityQuestLocations:Lookup(101)
assert(not unsupported and reason:find("Forever", 1, true))
flavor = "Forever"
zone.private.areaIdToUiMapId = "return { [12] = os.execute('bad') }"
unsupported, reason = InfinityQuestLocations:Lookup(101)
assert(not unsupported and reason:find("mapping", 1, true))
zone.private.areaIdToUiMapId = "return {\n [12] = 1429,\n}"
LibQuestieDB.Quest.objectives = function() error("lookup failure") end
unsupported, reason = InfinityQuestLocations:Lookup(101)
assert(not unsupported and reason:find("lookup failure", 1, true))
LibQuestieDB = nil
local guildLocations = true
InfinityGuildQuestPositions = { GetLocations = function(_, id, limit)
	assert(id == 101 and limit == 200)
	if guildLocations then
		return { { mapID = 1429, x = 0.3, y = 0.4, role = "Quest offer (guild)", name = "Scout" } }, false
	end
	return {}, false
end }
waypoint = nil
assert(InfinityQuestieUI:ShowLocations(101))
assert(InfinityQuestieUI.locationsFrame.rows[1].data.text:find("Scout", 1, true))
assert(InfinityQuestieUI.locationsFrame.status.text:find("QuestieDB unavailable", 1, true))
InfinityQuestieUI.locationsFrame.rows[1].scripts.OnClick(InfinityQuestieUI.locationsFrame.rows[1])
assert(waypoint and waypoint.mapID == 1429 and waypoint.x == 0.3)
guildLocations = false
local previousWarnings = #warnings
assert(not InfinityQuestieUI:ShowLocations(101, true))
assert(#warnings == previousWarnings and InfinityQuestieUI.locationsFrame.rows[1].data.text:find("No quest locations", 1, true))
InfinityGuildQuestPositions = nil
local before = #frames
subscriptions.INFINITY_DATA_LOADED()
assert(#frames == before)

questVisible = false
events.scripts.OnEvent(events, "QUEST_TURNED_IN", 101)
assert(InfinityQuestTracker:GetCompletedQuests()[101].name == "A herb quest")
assert(InfinityQuestTracker:GetCompletedQuests()[101].duration == nil)
assert(not InfinityQuestTracker:GetActiveQuests()[101])
assert(InfinityQuestieUI.frame.rows[1].data.text == "No visible quests in the quest log.")

print = originalPrint
print("questie_runtime: all tests passed")
