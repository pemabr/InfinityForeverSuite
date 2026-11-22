local frames, warnings = {}, {}
local features, commands = {}, {}
local combat = false
local secret = {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:UnregisterEvent(event) self.events[event] = nil end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return self.text or "" end
function widget:SetTexture(texture) self.texture = texture end
function widget:SetPosition(x, y) self.x, self.y = x, y end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
function widget:GetName() return self.name end
local meta = { __index = function(_, key) return widget[key] or function() end end }

function CreateFrame(_, name, parent)
	local result = setmetatable({ name = name, parent = parent, shown = true, events = {}, scripts = {} }, meta)
	if name then _G[name] = result end
	frames[#frames + 1] = result
	return result
end
UIParent = CreateFrame("Frame")
InfinityUtils = {
	Info = function() end,
	Warn = function(_, message) warnings[#warnings + 1] = message end,
	Warning = function(_, message) warnings[#warnings + 1] = message end,
	Error = function(_, message) error(message) end,
	GetTimeStamp = function() return "timestamp" end,
}
InfinityStorageManager = {
	GetFeatureSetting = function(_, feature, key, default)
		return features[feature] and features[feature][key] or default
	end,
	SetFeatureSetting = function(_, feature, key, value)
		features[feature] = features[feature] or {}
		features[feature][key] = value
	end,
}
InfinityDataManager = { RegisterSource = function() end, UpdateSourceData = function() return true end }
InfinityMessaging = { Publish = function() end }
InfinityCommandRegistry = {
	RegisterCommand = function(_, entry) commands[entry.name] = entry.func end,
	RegisterKeybind = function() end,
}
InfinityCore = {}
InCombatLockdown = function() return combat end
issecretvalue = function(value) return value == secret end

dofile("InfinityCore\\UI\\UIFramework.lua")
local function loadAddon(name)
	if name == "InfinityGather" then dofile(name .. "\\Modules\\GatherMate2IntegrationEngine.lua") end
	dofile(name .. "\\UI\\MainUI.lua")
	if name == "InfinityGather" then dofile(name .. "\\UI\\MapPins.lua") end
	if name == "InfinityGuide" then dofile(name .. "\\Modules\\Guides.lua") end
	dofile(name .. "\\Init.lua")
	local loader = frames[#frames]
	loader.scripts.OnEvent(loader, "ADDON_LOADED", name)
	assert(not loader.events.ADDON_LOADED)
end

local equipped, usedSet = "item:100", nil
GetInventoryItemLink = function(_, slot) if slot == 1 then return equipped end end
C_EquipmentSet = {
	GetEquipmentSetIDs = function() return { 5 } end,
	GetEquipmentSetInfo = function(id) assert(id == 5); return "Healing" end,
	UseEquipmentSet = function(id) usedSet = id end,
}
loadAddon("InfinityGear")
commands.infgear()
assert(InfinityGearUI.frame:IsShown())
assert(InfinityGearUI.frame.rows[1].data.link == "item:100")
assert(InfinityGearUI.frame.rows[20].data.text == "Equip set: Healing")
InfinityGearUI.frame.rows[20].scripts.OnClick(InfinityGearUI.frame.rows[20])
assert(usedSet == 5)
combat, usedSet = true, nil
InfinityGearUI.frame.rows[20].scripts.OnClick(InfinityGearUI.frame.rows[20])
assert(usedSet == nil and #warnings > 0)
combat = false
equipped = "item:101"
InfinityGearUI.eventFrame.scripts.OnEvent(InfinityGearUI.eventFrame, "PLAYER_EQUIPMENT_CHANGED")
assert(InfinityGearUI.frame.rows[1].data.link == "item:101")
equipped = secret
InfinityGearUI.eventFrame.scripts.OnEvent(InfinityGearUI.eventFrame, "PLAYER_EQUIPMENT_CHANGED")
assert(InfinityGearUI.frame.rows[1].data.text:find("unavailable", 1, true))
equipped = "item:101"
C_EquipmentSet.GetEquipmentSetIDs = function() return { secret, 5 } end
InfinityGearUI:Refresh()
assert(InfinityGearUI.frame.rows[20].data.text == "Equip set: Healing")
assert(InfinityGearUI.frame.status.text:find("Some sets are unavailable", 1, true))
C_EquipmentSet.GetEquipmentSetIDs = function() return { 5 } end

local watch = { [101] = 0 }
local objective = "Collect 2/5"
C_QuestLog = {
	GetNumQuestLogEntries = function() return 3 end,
	GetInfo = function(i)
		if i == 1 then return { isHeader = true, title = "Zone" } end
		if i == 2 then return { questID = 101, title = "Collect" } end
		return { isHeader = false, questID = 102, title = secret }
	end,
	GetQuestObjectives = function(id) assert(id == 101); return { { text = objective } } end,
	GetQuestWatchType = function(id) return watch[id] end,
	AddQuestWatch = function(id) watch[id] = 0; return true end,
	RemoveQuestWatch = function(id) watch[id] = nil end,
}
loadAddon("InfinityGuide")
assert(type(InfinityGuideUI.ShowGuides) == "function")
commands.infguide("guides")
assert(InfinityGuideUI.guideFrame:IsShown())
commands.infguide()
local questWindow = InfinityGuideUI.frame
assert(questWindow.rows[1].data.text == "[Tracked] Collect")
assert(questWindow.rows[2].data.text:find("2/5", 1, true))
questWindow.rows[1].scripts.OnClick(questWindow.rows[1])
assert(watch[101] == nil and questWindow.rows[1].data.text == "Collect")
questWindow.rows[1].scripts.OnClick(questWindow.rows[1])
assert(watch[101] == 0)
local firstRow = questWindow.rows[1]
objective = "Collect 5/5"
InfinityGuideUI.eventFrame.scripts.OnEvent(InfinityGuideUI.eventFrame, "QUEST_LOG_UPDATE")
assert(questWindow.rows[1] == firstRow and questWindow.rows[2].data.text:find("5/5", 1, true))
commands.infguide("create Forest route")
assert(InfinityGuideGuides.activeGuide == "guide_1" and InfinityGuideUI.guideFrame:IsShown())
commands.infguide("step Speak to the scout")
local customGuide = InfinityGuideGuides.guides.guide_1
assert(customGuide.steps[1].description == "Speak to the scout")
assert(InfinityGuideUI.guideFrame.rows[3].data.text:find("[ ] 1.", 1, true))
InfinityGuideUI.guideFrame.rows[3].scripts.OnClick(InfinityGuideUI.guideFrame.rows[3])
assert(customGuide.steps[1].done and features.InfinityGuide.guides.guides.guide_1.steps[1].done)
InfinityGuideUI.guideFrame.rows[3].scripts.OnClick(InfinityGuideUI.guideFrame.rows[3])
assert(not customGuide.steps[1].done)
commands.infguide("create Second route")
assert(InfinityGuideGuides.activeGuide == "guide_2")
commands.infguide("select guide_1")
assert(InfinityGuideGuides.activeGuide == "guide_1")
commands.infguide("quest 101 Turn in the collection quest")
assert(customGuide.steps[2].questID == 101 and not customGuide.steps[2].done)
InfinityGuideUI.eventFrame.scripts.OnEvent(InfinityGuideUI.eventFrame, "QUEST_TURNED_IN", secret)
assert(not customGuide.steps[2].done)
InfinityGuideUI.eventFrame.scripts.OnEvent(InfinityGuideUI.eventFrame, "QUEST_TURNED_IN", 101)
assert(customGuide.steps[2].done)
commands.infguide("unstep 2")
commands.infguide("step Find the cave")
commands.infguide("unstep 1")
assert(#customGuide.steps == 1 and customGuide.steps[1].number == 1
	and customGuide.steps[1].description == "Find the cave")
commands.infguide("step " .. string.rep("a", 61))
assert(#customGuide.steps == 1 and warnings[#warnings]:find("Invalid guide step", 1, true))
assert(InfinityGuideGuides:Initialize() and InfinityGuideGuides.activeGuide == "guide_1")
commands.infguide("guides")
assert(InfinityGuideUI.guideFrame.rows[1].data.text:find("Forest route", 1, true))
InfinityGuideUI.guideFrame.rows[1].scripts.OnClick(InfinityGuideUI.guideFrame.rows[1])
assert(InfinityGuideUI.guideFrame.rows[3].data.text:find("Find the cave", 1, true))
commands.infguide("delete guide_1")
assert(InfinityGuideGuides.guides.guide_1 == nil and InfinityGuideGuides.activeGuide == nil)
commands.infguide("create New route")
assert(InfinityGuideGuides.activeGuide == "guide_3")
InfinityGuideUI:ShowGuideActions()
local guideActions = InfinityGuideUI.actionsFrame
local function ClickGuideAction(prefix)
	for _, row in ipairs(guideActions.rows) do
		if row:IsShown() and row.data.text:find(prefix, 1, true) == 1 then
			row.scripts.OnClick(row)
			return
		end
	end
	error("Missing guide action: " .. prefix)
end
InfinityGuideUI.actionText:SetText("GUI guide")
ClickGuideAction("Create guide")
local guiID = InfinityGuideGuides.activeGuide
assert(guiID == "guide_4" and InfinityGuideGuides.guides[guiID].name == "GUI guide")
InfinityGuideUI.actionText:SetText("GUI quest step")
InfinityGuideUI.actionNumber:SetText("102")
ClickGuideAction("Add step")
assert(InfinityGuideGuides.guides[guiID].steps[1].questID == 102)
InfinityGuideUI.actionNumber:SetText("bad")
ClickGuideAction("Add step")
assert(#InfinityGuideGuides.guides[guiID].steps == 1 and warnings[#warnings]:find("valid quest ID", 1, true))
InfinityGuideUI.actionNumber:SetText("1")
ClickGuideAction("Remove step")
assert(#InfinityGuideGuides.guides[guiID].steps == 1)
ClickGuideAction("Remove step")
assert(#InfinityGuideGuides.guides[guiID].steps == 0)
ClickGuideAction("Delete selected guide")
assert(InfinityGuideGuides.guides[guiID])
ClickGuideAction("Delete selected guide")
assert(not InfinityGuideGuides.guides[guiID])
local guildActions = {}
InfinityGuideGuildPresets = {
	Request = function() guildActions.requested = true end,
	GetPublished = function() return guildActions.unpublished and {} or { "G:guide_3" } end,
	Unpublish = function(_, id) guildActions.unpublished = id; return true end,
	Accept = function() guildActions.accepted = true end,
}
InfinityGuideUI:RefreshGuideActions()
ClickGuideAction("Request guild")
assert(guildActions.requested)
InfinityGuideGuildPresets.pending = { name = "Received", sender = "Member" }
ClickGuideAction("Save and republish")
assert(not guildActions.accepted and warnings[#warnings]:find("Pending preset changed", 1, true))
assert(guideActions.rows[1].data.text:find("Received", 1, true))
ClickGuideAction("Save and republish")
assert(guildActions.accepted)
ClickGuideAction("Manage published")
local published = InfinityGuideUI.publishedFrame
published.rows[1].scripts.OnClick(published.rows[1])
assert(not guildActions.unpublished)
published.rows[1].scripts.OnClick(published.rows[1])
assert(guildActions.unpublished == "G:guide_3" and published.rows[1].data.text == "No published presets.")
InfinityGuideGuildPresets = nil

local cvars = { autoLootDefault = "0", autoSelfCast = "1", rotateMinimap = "0" }
C_CVar = {
	GetCVar = function(name) return cvars[name] end,
	SetCVar = function(name, value) cvars[name] = value end,
}
loadAddon("InfinityQoL")
commands.qol()
assert(InfinityQoLUI.frame.rows[3].data.text:find("unavailable", 1, true))
assert(InfinityQoLUI.frame.rows[3].data.onClick == nil)
InfinityQoLUI.frame.rows[1].scripts.OnClick(InfinityQoLUI.frame.rows[1])
assert(cvars.autoLootDefault == "1")
assert(InfinityQoLUI.frame.rows[1].data.text:find("On", 1, true))

local hasPosition, positionX, positionY = true, 0.123, 0.456
local waypoint, openedMap, superTracked
time = function() return 1000 end
C_Spell = { GetSpellName = function(id)
	if id == 2366 or id == 1001 then return "Herb Gathering" end
	if id == 2575 or id == 1002 then return "Mining" end
	return "Other spell"
end }
C_Map = {
	GetBestMapForUnit = function() return 9 end,
	GetPlayerMapPosition = function()
		if hasPosition then return { x = positionX, y = positionY } end
	end,
	GetMapInfo = function() return { name = "Test Zone" } end,
	CanSetUserWaypointOnMap = function(id) return id == 9 end,
	SetUserWaypoint = function(point) waypoint = point; return true end,
}
UiMapPoint = { CreateFromCoordinates = function(id, x, y) return { mapID = id, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(value) superTracked = value end }
OpenWorldMap = function(id) openedMap = id end
local popupShown
StaticPopupDialogs = {}
StaticPopup_Show = function(name) popupShown = name; return {} end
loadAddon("InfinityGather")
commands.gather()
InfinityGatherUI:Record("Herb")
InfinityGatherUI:Record("Ore")
assert(#features.InfinityGather.manualNodes == 2)
assert(InfinityGatherUI.frame.rows[1].data.text:find("Ore  |  Test Zone  |  12.3, 45.6", 1, true))
assert(InfinityGatherUI.frame.status.text:find("ForeverCore", 1, true))
local mapID, canvasShown, listener = 9, nil, nil
WorldMapFrame = {
	IsShown = function() return true end,
	GetMapID = function() return mapID end,
	AddDataProvider = function() error("must not modify the Blizzard map") end,
	AcquirePin = function() error("must not acquire Blizzard map pins") end,
}
local pool = { pins = {} }
local canvas = {
	PinMixin = {},
	Pool = function(map, mixin)
		assert(map == WorldMapFrame)
		function pool:ReleaseAll() self.pins = {} end
		function pool:Acquire(node)
			local pin = CreateFrame("Frame")
			for key, value in pairs(mixin) do pin[key] = value end
			pin:OnLoad()
			pin:OnAcquired(node)
			self.pins[#self.pins + 1] = pin
			return pin
		end
		return pool
	end,
	Watch = function(map, callback) assert(map == WorldMapFrame); listener = callback end,
	SetShown = function(map, shown) assert(map == WorldMapFrame); canvasShown = shown end,
}
ForeverCore = { Register = function(name) assert(name == "InfinityGather"); return { MapCanvas = canvas } end }
combat = true
InfinityGatherMap.events.scripts.OnEvent(InfinityGatherMap.events, "ADDON_LOADED", "ForeverCore")
assert(not InfinityGatherMap.pool)
combat = false
InfinityGatherMap.events.scripts.OnEvent(InfinityGatherMap.events, "PLAYER_REGEN_ENABLED")
assert(canvasShown and #pool.pins == 2 and pool.pins[1].node.kind == "Ore")
mapID = 10
listener(nil, "map")
assert(#pool.pins == 0)
mapID = 9
listener(nil, "map")
assert(#pool.pins == 2)
local tooltip = {}
GameTooltip = {
	SetOwner = function(_, owner) tooltip.owner = owner end,
	GetOwner = function() return tooltip.owner end,
	SetText = function(_, text) tooltip.text = text end,
	AddLine = function() end,
	Show = function() tooltip.shown = true end,
	Hide = function() tooltip.shown = false end,
}
pool.pins[1]:OnMouseEnter()
assert(tooltip.shown and tooltip.text == "Ore")
pool.pins[1]:OnMouseLeave()
assert(not tooltip.shown)
waypoint, openedMap = nil, nil
pool.pins[1]:OnMouseClickAction("LeftButton")
assert(waypoint and waypoint.mapID == 9 and openedMap == nil)
combat = true
InfinityGatherMap.events.scripts.OnEvent(InfinityGatherMap.events, "PLAYER_REGEN_DISABLED")
assert(canvasShown == false)
waypoint = nil
pool.pins[1]:OnMouseClickAction("LeftButton")
assert(not waypoint)
combat = false
InfinityGatherMap.events.scripts.OnEvent(InfinityGatherMap.events, "PLAYER_REGEN_ENABLED")
assert(canvasShown == true and #pool.pins == 2)
local savedNodes = InfinityGatherUI.nodes
InfinityGatherUI.nodes = {}
for i = 1, 502 do
	InfinityGatherUI.nodes[i] = { mapID = 9, kind = "Herb", x = i / 1000, y = 0.5 }
end
InfinityGatherUI.nodes[503] = { mapID = 9, kind = "Ore", x = secret, y = 0.5 }
InfinityGatherMap:Refresh()
assert(#pool.pins == 500 and InfinityGatherMap.truncated)
assert(pool.pins[1].node.x == 0.502 and pool.pins[500].node.x == 0.003)
assert(InfinityGatherUI:ShowRoute())
assert(#InfinityGatherUI.routeFrame.rows == 200)
assert(InfinityGatherUI.routeFrame.status.text:find("Up to 200", 1, true))
assert(pool.pins[1].node.order ~= nil and pool.pins[201].node.order == nil)
InfinityGatherUI.nodes = savedNodes
InfinityGatherMap:Refresh()
local routeNodes = {
	{ mapID = 9, kind = "Herb", name = "Far herb", x = 0.9, y = 0.9 },
	{ mapID = 9, kind = "Ore", name = "Near ore", x = 0.2, y = 0.2 },
	{ mapID = 10, kind = "Ore", x = 0.11, y = 0.11 },
	{ mapID = 9, kind = "Herb", x = secret, y = 0.1 },
}
InfinityGatherUI.nodes, positionX, positionY = routeNodes, 0.1, 0.1
assert(InfinityGatherUI:ShowRoute())
assert(InfinityGatherUI.routeFrame.rows[1].data.text:find("Near ore", 1, true))
assert(InfinityGatherUI.routeFrame.rows[2].data.text:find("Far herb", 1, true))
assert(not InfinityGatherUI.routeFrame.rows[3]:IsShown())
assert(pool.pins[1].node.order == 1 and pool.pins[2].node.order == 2)
waypoint = nil
InfinityGatherUI.routeFrame.rows[1].scripts.OnClick(InfinityGatherUI.routeFrame.rows[1])
assert(waypoint and waypoint.mapID == 9 and waypoint.x == 0.2)
positionX = secret
local routeWarnings = #warnings
assert(not InfinityGatherUI:ShowRoute() and #warnings == routeWarnings + 1)
InfinityGatherUI.nodes, positionX, positionY = savedNodes, 0.123, 0.456
InfinityGatherMap:Refresh()
local previousSetWaypoint = C_Map.SetUserWaypoint
C_Map.SetUserWaypoint = function() return secret end
local deniedWarnings = #warnings
InfinityGatherUI:ShowOnMap(savedNodes[1], false)
assert(#warnings == deniedWarnings + 1)
C_Map.SetUserWaypoint = previousSetWaypoint
InfinityGatherUI:Initialize()
assert(#InfinityGatherUI.nodes == 2)
local gatherEvents = InfinityGatherUI.eventFrame
local function spell(event, ...) gatherEvents.scripts.OnEvent(gatherEvents, event, ...) end
spell("UNIT_SPELLCAST_SENT", "player", "Copper Vein", "failed", 1002)
spell("UNIT_SPELLCAST_FAILED", "player", "failed", 1002)
spell("UNIT_SPELLCAST_SUCCEEDED", "player", "failed", 1002)
spell("UNIT_SPELLCAST_SENT", "party1", "Copper Vein", "other", 1002)
spell("UNIT_SPELLCAST_SUCCEEDED", "party1", "other", 1002)
spell("UNIT_SPELLCAST_SENT", "player", "Other", "unknown", 9999)
spell("UNIT_SPELLCAST_SUCCEEDED", "player", "unknown", 9999)
assert(#InfinityGatherUI.nodes == 2)
spell("UNIT_SPELLCAST_SENT", "player", "Copper Vein", "cast1", 1002)
spell("UNIT_SPELLCAST_SUCCEEDED", "player", "wrong", 1002)
assert(#InfinityGatherUI.nodes == 2)
spell("UNIT_SPELLCAST_SUCCEEDED", "player", "cast1", 1002)
assert(#InfinityGatherUI.nodes == 3 and InfinityGatherUI.nodes[3].source == "auto")
assert(InfinityGatherUI.nodes[3].name == "Copper Vein")
local repeatedObservation
InfinityGuildGatherKnowledge = {
	ObserveNode = function(_, kind, id, x, y) repeatedObservation = { kind = kind, id = id, x = x, y = y } end,
	GetNodes = function() return {}, false end,
}
positionX = 0.1235
spell("UNIT_SPELLCAST_SENT", "player", "Copper Vein", "cast2", 1002)
spell("UNIT_SPELLCAST_SUCCEEDED", "player", "cast2", 1002)
assert(#InfinityGatherUI.nodes == 3 and InfinityGatherUI.nodes[3].count == 2)
assert(repeatedObservation and repeatedObservation.x == 0.123 and repeatedObservation.y == 0.456)
InfinityGuildGatherKnowledge = nil
spell("UNIT_SPELLCAST_SENT", "player", secret, "cast3", 1001)
spell("UNIT_SPELLCAST_SUCCEEDED", "player", "cast3", 1001)
assert(#InfinityGatherUI.nodes == 4 and InfinityGatherUI.nodes[4].source == "auto")
assert(InfinityGatherUI.nodes[4].name == nil)
assert(InfinityGatherUI.frame.rows[1].data.text:find("[auto]", 1, true))
InfinityGatherUI.frame.rows[1].scripts.OnClick(InfinityGatherUI.frame.rows[1])
assert(waypoint.mapID == 9 and waypoint.x == 0.1235 and waypoint.y == 0.456)
assert(openedMap == 9 and superTracked)
combat, waypoint = true, nil
local mapWarnings = #warnings
InfinityGatherUI.frame.rows[1].scripts.OnClick(InfinityGatherUI.frame.rows[1])
assert(waypoint == nil and #warnings == mapWarnings + 1)
combat = false
InfinityGatherUI:Initialize()
assert(#InfinityGatherUI.nodes == 4 and InfinityGatherUI.nodes[3].count == 2)
hasPosition = false
local previousWarnings = #warnings
InfinityGatherUI:Record("Herb")
assert(#warnings == previousWarnings + 1 and #InfinityGatherUI.nodes == 4)
hasPosition = true
assert(InfinityGatherUI:ShowRoute())
InfinityGatherUI:Record("Ore")
assert(InfinityGatherUI.routeFrame.status.text:find("rebuild", 1, true))
InfinityGatherUI:RemoveLast()
InfinityGatherUI:RemoveLast()
assert(#features.InfinityGather.manualNodes == 3 and not InfinityGatherUI.routeFrame:IsShown())

local source = InfinityGatherMateSource
source.frame.scripts.OnEvent(source.frame, "PLAYER_LOGIN")
assert(not popupShown and source.choice == "ask")
GatherMate2 = {
	GetNodesForZone = function(_, zone, category)
		assert(zone == 9)
		if category == "Herb Gathering" then return pairs({ [2000300000] = 123 }) end
		assert(category == "Mining")
		return pairs({ [4000500000] = 456 })
	end,
	DecodeLoc = function(_, coord)
		return math.floor(coord / 1000000) / 10000, math.floor(coord % 1000000 / 100) / 10000
	end,
	GetNameForNode = function(_, category, id)
		if category == "Herb Gathering" and id == 123 then return "Peacebloom" end
		if category == "Mining" and id == 456 then return "Copper Vein" end
	end,
}
combat = true
source.frame.scripts.OnEvent(source.frame, "ADDON_LOADED", "GatherMate2")
assert(not popupShown and #pool.pins == 3)
combat = false
source.frame.scripts.OnEvent(source.frame, "PLAYER_REGEN_ENABLED")
assert(popupShown == "INFINITY_GATHER_GATHERMATE" and #pool.pins == 3)
StaticPopupDialogs.INFINITY_GATHER_GATHERMATE.OnAccept()
assert(features.InfinityGather.gatherMateSource == "on" and #pool.pins == 5)
assert(#features.InfinityGather.manualNodes == 3)
assert(pool.pins[4].node.name == "Peacebloom" and pool.pins[4].node.x == 0.2)
assert(pool.pins[5].node.name == "Copper Vein" and pool.pins[5].node.y == 0.5)
assert(InfinityGatherUI:ShowRoute() and InfinityGatherUI.routeFrame.rows[5]:IsShown()
	and not InfinityGatherUI.routeFrame.rows[6]:IsShown())
assert(pool.pins[4].node.order and pool.pins[5].node.order)
waypoint = nil
pool.pins[4]:OnMouseClickAction("LeftButton")
assert(waypoint and waypoint.x == 0.2 and waypoint.y == 0.3)
commands.gather({ "source", "off" })
assert(features.InfinityGather.gatherMateSource == "off" and #pool.pins == 3)
assert(not InfinityGatherUI.routeFrame:IsShown() and #features.InfinityGather.manualNodes == 3)
StaticPopupDialogs.INFINITY_GATHER_GATHERMATE.OnCancel()
assert(source.choice == "off")
commands.gather({ "source", "on" })
local limited, more = source:GetNodes(9, 1)
assert(#limited == 1 and more)
local previousIterator = GatherMate2.GetNodesForZone
local many = {}
for i = 1, 600 do many[1000000000 + i * 100] = 123 end
GatherMate2.GetNodesForZone = function(_, _, category)
	return pairs(category == "Herb Gathering" and many or {})
end
InfinityGatherMap:Refresh()
assert(#pool.pins == 500 and InfinityGatherMap.truncated)
assert(InfinityGatherUI:ShowRoute())
assert(InfinityGatherUI.routeFrame.status.text:find("Up to 200", 1, true))
assert(InfinityGatherUI.routeFrame.rows[200]:IsShown()
	and (not InfinityGatherUI.routeFrame.rows[201] or not InfinityGatherUI.routeFrame.rows[201]:IsShown()))
assert(#features.InfinityGather.manualNodes == 3)
GatherMate2.GetNodesForZone = previousIterator
GatherMate2.GetNodesForZone = function() error("provider failed") end
local warningCount = #warnings
local failed = source:GetNodes(9, 10)
assert(#failed == 0 and #warnings == warningCount + 1 and warnings[#warnings]:find("provider failed", 1, true))
source:GetNodes(9, 10)
assert(#warnings == warningCount + 1)
GatherMate2.GetNodesForZone = previousIterator
local recovered = source:GetNodes(9, 10)
assert(#recovered == 2)
GatherMate2.GetNodesForZone = function(_, _, category)
	if category == "Herb Gathering" then return pairs({ [secret] = 1, [2000300000] = secret }) end
	return pairs({})
end
warningCount = #warnings
local skipped = source:GetNodes(9, 10)
assert(#skipped == 0 and #warnings == warningCount + 1)
GatherMate2.GetNodesForZone = previousIterator
local sourceButton
for _, frame in ipairs(frames) do
	if frame.parent == InfinityGatherUI.frame and frame.text == "GatherMate2" then sourceButton = frame end
end
assert(sourceButton)
sourceButton.scripts.OnClick(sourceButton)
assert(source.choice == "off" and #pool.pins == 3)
sourceButton.scripts.OnClick(sourceButton)
assert(source.choice == "on" and #pool.pins == 5)
dofile("InfinityGather\\Modules\\GatherMate2IntegrationEngine.lua")
source = InfinityGatherMateSource
source:Initialize()
assert(source.choice == "on" and source:Available())
InfinityGatherMap:Refresh()
assert(#pool.pins == 5)
local provider = GatherMate2
GatherMate2 = nil
warningCount = #warnings
source:GetNodes(9, 10)
source:GetNodes(9, 10)
assert(#warnings == warningCount + 1 and warnings[#warnings]:find("unavailable", 1, true))
GatherMate2 = provider
source:Detect()
assert(#pool.pins == 5)
commands.gather({ "source", "off" })
GatherMate2 = nil
warningCount = #warnings
sourceButton.scripts.OnClick(sourceButton)
assert(source.choice == "on" and #warnings == warningCount + 1
	and warnings[#warnings]:find("unavailable", 1, true))
sourceButton.scripts.OnClick(sourceButton)

local observed
InfinityGuildGatherKnowledge = {
	ObserveNode = function(_, kind, id, x, y) observed = { kind = kind, id = id, x = x, y = y } end,
	GetNodes = function(_, id, limit)
		if id == 9 and limit > 0 then
			return { { mapID = 9, kind = "Herb", x = 0.8, y = 0.7, source = "guild", sourceKey = "N:9:Herb:8000:7000" } }, false
		end
		return {}, false
	end,
}
InfinityGatherUI:Record("Herb")
assert(observed and observed.kind == "Herb" and observed.id == 9)
assert(#pool.pins == 5 and pool.pins[5].node.source == "guild")
pool.pins[5]:OnMouseEnter()
assert(tooltip.text == "Herb [Guild]")
assert(InfinityGatherUI:ShowRoute() and InfinityGatherUI.routeFrame.rows[5]:IsShown())
assert(InfinityGatherUI.frame.rows[5].data.text:find("[guild]", 1, true))
InfinityGatherUI:RemoveLast()
InfinityGuildGatherKnowledge = nil
InfinityGatherMap:Refresh()

local isRaid = true
IsInRaid = function() return isRaid end
GetNumGroupMembers = function() return isRaid and 2 or 1 end
GetRaidRosterInfo = function(i)
	if i == 1 then return "Alice", 2, 1, 60, "Mage", "MAGE", "Zone", true end
	return "Bob", 0, 2, 55, "Priest", "PRIEST", "Zone", false
end
UnitName = function() return "Alice" end
UnitGroupRolesAssigned = function() return "HEALER" end
loadAddon("InfinityRaid")
InfinityRaidUI.eventFrame.scripts.OnEvent(InfinityRaidUI.eventFrame, "ENCOUNTER_START", 1, "Boss", 1, 2)
commands.infraid()
assert(InfinityRaidUI.frame.rows[1].data.text == "Boss: In progress")
assert(InfinityRaidUI.frame.rows[3].data.text:find("Alice", 1, true))
assert(InfinityRaidUI.frame.rows[4].data.text:find("Offline", 1, true))
InfinityRaidUI.eventFrame.scripts.OnEvent(InfinityRaidUI.eventFrame, "ENCOUNTER_END", 1, "Boss", 1, 2, 1)
assert(InfinityRaidUI.frame.rows[1].data.text == "Boss: Defeated")
isRaid = false
InfinityRaidUI.eventFrame.scripts.OnEvent(InfinityRaidUI.eventFrame, "GROUP_ROSTER_UPDATE")
assert(InfinityRaidUI.frame.rows[3].data.text == "Alice | HEALER")
print("feature_windows: all tests passed")
