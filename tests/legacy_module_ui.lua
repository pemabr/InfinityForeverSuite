local frames, commands, warnings = {}, {}, {}
local secret, now, guildCount = {}, 1000, 2
local guildName, protectedMember = "Guild", false
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return rawget(self, "text") or "" end
function widget:SetPoint(...) self.point = { ... } end
function widget:SetSize(width, height) self.width, self.height = width, height end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
function widget:SetShown(shown) self.shown = shown end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name, parent)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local frame = setmetatable({ events = {}, scripts = {}, parent = parent, shown = true }, meta)
	if name then _G[name] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
issecretvalue = function(value) return value == secret end
GetTime = function() return now end
GetRealZoneText = function() return "Test raid" end
GetNumGroupMembers = function() return 0 end
GetRealmName = function() return "Realm" end
IsInGuild = function() return true end
GetGuildInfo = function() return guildName end
GetNumGuildMembers = function() return guildCount end
GetGuildRosterInfo = function(index)
	if index == 1 then return "Alice-Realm", "Master", 0, 60, "Mage", "City", "", "", true, 0, "MAGE" end
	if protectedMember then return secret end
	return "Bob-Other", "Member", 1, 50, "Priest", "Forest", "", "", false, 0, "PRIEST"
end
GetInventorySlotInfo = function(slot)
	if slot == "HeadSlot" then return 1 end
	if slot == "Finger0Slot" then return 2 end
	if slot == "Finger1Slot" then return 3 end
	if slot == "Trinket0Slot" then return 4 end
	if slot == "Trinket1Slot" then return 5 end
end
GetInventoryItemLink = function(_, slot) if slot and slot <= 5 then return "item:1000" end end
C_UnitAuras = { GetBuffDataByIndex = function(_, index)
	if index == 1 then return { name = "Fortitude", spellId = 123, duration = 30, expirationTime = now + 30 } end
end }
InfinityUtils = {
	Info = function() end,
	Warning = function(_, message) warnings[#warnings + 1] = message end,
	GetTimeStamp = function() return now end,
	GetBagSlots = function(_, bag) return bag == 0 and 1 or 0 end,
	GetBagItemID = function() return 100 end,
	GetBagItemInfo = function() return nil, 2 end,
	GetItemIDFromLink = function() return 1000 end,
	GetItemInfo = function(_, id)
		if id == 100 then return "Potion", nil, 1, 1, 1, "Consumable", "Potion" end
		return "Hat", nil, 1, 50
	end,
	DeepCopy = function(_, value) return value end,
}
InfinityCore = {}
InfinityDataManager = { RegisterSource = function() end }
InfinityMessaging = { Publish = function() end, Subscribe = function() end }
InfinityCharacterManager = {
	GetCurrentCharacter = function() return { name = "Alice" } end,
	LinkCharacterToMain = function() error("Guild scans must not alter character links") end,
}
InfinityCommandRegistry = {
	RegisterCommand = function(_, name, callback) commands[name] = callback end,
	RegisterKeybind = function() end,
}
dofile("InfinityCore\\UI\\UIFramework.lua")
local function Load(name)
	local first = #frames + 1
	for line in io.lines(name .. "\\" .. name .. ".toc") do
		if line:match("%.lua%s*$") and not line:match("^%s*#") then dofile(name .. "\\" .. line:match("^%s*(.-)%s*$")) end
	end
	for index = first, #frames do
		local frame = frames[index]
		if frame.events.ADDON_LOADED then frame.scripts.OnEvent(frame, "ADDON_LOADED", name); return end
	end
	error("Missing addon loader: " .. name)
end
local function Button(parent, text)
	for _, frame in ipairs(frames) do
		if frame.parent == parent and frame.text == text then return frame end
	end
	error("Missing button: " .. text)
end

Load("InfinityConsumables")
InfinityConsumablesUI:Toggle()
local consumables = InfinityConsumablesUI.frame
assert(consumables:IsShown() and consumables.rows[1].data.text == "Potion x2")
Button(consumables, "Buffs").scripts.OnClick()
assert(consumables.rows[1].data.text == "Fortitude")
local scan = InfinityConsumables.ScanInventory
InfinityConsumables.ScanInventory = function() error("scan failure") end
Button(consumables, "Scan bags").scripts.OnClick()
assert(not consumables.rows[1]:IsShown() and warnings[#warnings]:find("scan failure", 1, true))
InfinityConsumables.ScanInventory = scan

Load("InfinityGearMgr")
InfinityGearMgrUI:Toggle()
local gear = InfinityGearMgrUI.frame
assert(gear.rows[1].data.text:find("Hat", 1, true))
assert(#gear.rows == 5)
Button(gear, "Low slots").scripts.OnClick()
assert(gear.rows[1].data.text == "No readable equipment.")
Button(gear, "Equipment").scripts.OnClick()
assert(gear.rows[1].data.link == "item:1000")
Button(gear, "Export").scripts.OnClick()
assert(InfinityGearMgrUI.exportFrame:IsShown())
assert(InfinityGearMgrUI.exportText.text:find("Character: Alice", 1, true))
assert(InfinityGearMgrUI.exportText.text:find("Finger1Slot: item:1000", 1, true))

Load("InfinityRosterMgr")
local roster = InfinityRosterManager
assert(roster:GetGuildInfo().totalMembers == 2 and roster:GetMemberInfo("Bob-Other").name == "Bob-Other")
InfinityRosterMgrUI:Toggle()
local rosterWindow = InfinityRosterMgrUI.frame
assert(rosterWindow.rows[1].data.text:find("Alice", 1, true))
InfinityRosterMgrUI.filter:SetText("PRIEST")
Button(rosterWindow, "Search").scripts.OnClick()
assert(rosterWindow.rows[1].data.text:find("Bob", 1, true) and not rosterWindow.rows[2]:IsShown())
Button(rosterWindow, "Online only").scripts.OnClick()
assert(rosterWindow.rows[1].data.text == "No matching roster entries.")
local old = roster.members
protectedMember = true
Button(rosterWindow, "Rescan").scripts.OnClick()
assert(roster.members == old and roster.scanError and not rosterWindow.rows[1]:IsShown())
protectedMember = false
Button(rosterWindow, "Rescan").scripts.OnClick()
assert(not roster.scanError and roster:GetGuildInfo().totalMembers == 2)
guildCount = 0
assert(not roster:ScanGuild() and roster:GetGuildInfo().totalMembers == 2)
guildCount = 2
assert(roster:ScanGuild())

local lootAddonHistory = {}
InfinityLootHistory = lootAddonHistory
Load("InfinityLootHistory")
local history = InfinityLootHistoryTracker
assert(InfinityLootHistory == lootAddonHistory and commands.lootlog)
assert(history:RecordLoot(10, "Sword", 1, "Dragon", { "Bob" }))
InfinityLootHistoryUI:Toggle()
local lootWindow = InfinityLootHistoryUI.frame
assert(lootWindow.rows[1].data.text == "Sword | Dragon")
InfinityLootHistoryUI.clearButton.scripts.OnClick()
assert(#history.lootLog == 1)
assert(history:RecordLoot(11, "Shield", 1, "Dragon", { "Bob" }))
InfinityLootHistoryUI.clearButton.scripts.OnClick()
assert(#history.lootLog == 2)
InfinityLootHistoryUI.clearButton.scripts.OnClick()
assert(#history.lootLog == 0 and not next(history.playerStats))
dofile("InfinityLoot\\Modules\\LootHistory.lua")
assert(InfinityLootHistory ~= history and InfinityLootHistoryTracker == history)
assert(history:RecordLoot(12, "Gem", 1, "Dragon", {}))
InfinityLootHistoryUI:Refresh()
assert(lootWindow.rows[1].data.text == "Gem | Dragon")
Button(lootWindow, "Record").scripts.OnClick()
InfinityLootHistoryUI.recordID:SetText("13")
InfinityLootHistoryUI.recordName:SetText("Manual item")
InfinityLootHistoryUI.recordSource:SetText("Boss")
InfinityLootHistoryUI.recordRecipient:SetText("Alice")
local recordWindow = InfinityLootHistoryUI.recordFrame
recordWindow.rows[1].scripts.OnClick(recordWindow.rows[1])
assert(#history.lootLog == 2 and history.playerStats.Alice.lootCount == 1)
assert(lootWindow.rows[1].data.text == "Manual item | Boss")
InfinityLootHistoryUI.recordID:SetText(secret)
recordWindow.rows[1].scripts.OnClick(recordWindow.rows[1])
assert(#history.lootLog == 2 and warnings[#warnings]:find("protected", 1, true))

dofile("InfinityAttendance\\Modules\\Tracker.lua")
dofile("InfinityAttendance\\Modules\\Statistics.lua")
dofile("InfinityAttendance\\UI\\Main.lua")
InfinityAttendanceUI:Toggle()
local attendance = InfinityAttendanceUI.frame
Button(attendance, "Start").scripts.OnClick()
assert(#InfinityAttendanceTracker.raids == 1 and not InfinityAttendanceTracker.raids[1].end_time)
Button(attendance, "Start").scripts.OnClick()
assert(#InfinityAttendanceTracker.raids == 1 and warnings[#warnings]:find("already running", 1, true))
Button(attendance, "Auto: on").scripts.OnClick()
assert(not InfinityAttendanceTracker.auto_tracking)
Button(attendance, "End").scripts.OnClick()
assert(InfinityAttendanceTracker.raids[1].end_time == now)
Button(attendance, "End").scripts.OnClick()
assert(warnings[#warnings]:find("No attendance", 1, true))
GetNumGroupMembers = function() return 2 end
GetRaidRosterInfo = function(index)
	if index == 1 then return "Alice", 0, 1, 60, "Mage", "MAGE", "City", true end
	return secret
end
Button(attendance, "Start").scripts.OnClick()
local current = InfinityAttendanceTracker:GetCurrentRaid()
assert(not next(current.members) and warnings[#warnings]:find("incomplete or protected", 1, true))
GetRaidRosterInfo = function(index)
	if index == 1 then return "Alice", 0, 1, 60, "Mage", "MAGE", "City", true end
	return "Bob", 0, 1, 50, "Priest", "PRIEST", "City", false
end
assert(InfinityAttendanceTracker:ScanRaid(current))
assert(current.members.Alice.class == "Mage" and current.members.Alice.is_online)
assert(current.members.Bob.level == 50 and not current.members.Bob.is_online)
dofile("InfinityGatherPath\\Core\\NodeDatabase.lua")
dofile("InfinityGatherPath\\Modules\\Routes.lua")
dofile("InfinityGatherPath\\Modules\\Optimization.lua")
dofile("InfinityGatherPath\\UI\\Main.lua")
InfinityRoutes.routes.test = { name = "Test route", zone = "Test zone", nodes = { {} } }
InfinityGatherPathUI:Toggle()
assert(InfinityGatherPathUI.routes_text.text:find("Test route", 1, true))
InfinityUtils.IsValidWaypoint = function(_, map, x, y)
	return type(map) == "number" and type(x) == "number" and type(y) == "number"
		and x >= 0 and x <= 1 and y >= 0 and y <= 1
end
C_Map = {
	GetBestMapForUnit = function() return 12 end,
	GetPlayerMapPosition = function() return { x = 0.3, y = 0.7 } end,
}
Button(InfinityGatherPathUI.frame, "Record herb").scripts.OnClick()
assert(InfinityNodeDB:GetNodeCount() == 1)
Button(InfinityGatherPathUI.frame, "Optimize zone").scripts.OnClick()
assert(InfinityGatherPathUI.routeFrame.rows[1].data.text:find("30.0, 70.0", 1, true))
C_Map.GetPlayerMapPosition = function() return secret end
Button(InfinityGatherPathUI.frame, "Record herb").scripts.OnClick()
assert(InfinityNodeDB:GetNodeCount() == 1 and warnings[#warnings]:find("protected", 1, true))
InfinityCore.RegisterCommand = function(_, command, _, callback) commands[command] = callback end
dofile("InfinityGatherPath\\Init.lua")
local gatherLoader = frames[#frames]
gatherLoader.scripts.OnEvent(gatherLoader, "ADDON_LOADED", "InfinityGatherPath")
assert(commands["/gatherpath record"] and commands["/gatherpath optimize"])
C_Map.GetPlayerMapPosition = function() return { x = 0.4, y = 0.7 } end
commands["/gatherpath record"]()
assert(InfinityNodeDB:GetNodeCount() == 2)
commands["/gatherpath optimize"]()
assert(InfinityGatherPathUI.routeFrame.rows[2].data.text:find("40.0, 70.0", 1, true))
InfinityGatherPathUI:Toggle()
assert(not InfinityGatherPathUI.frame:IsShown())

date = os.date
dofile("InfinityPerformanceAnalytics\\Modules\\Meter.lua")
dofile("InfinityPerformanceAnalytics\\UI\\Main.lua")
InfinityPerformanceAnalyticsUI:Toggle()
local analytics = InfinityPerformanceAnalyticsUI
Button(analytics:CreateMainWindow(), "Start").scripts.OnClick()
local meter = InfinityPerformanceAnalyticsMeter
assert(meter.currentSession)
meter:RecordHealing("Alice", "Bob", "Spell", 100)
meter:RecordDamage("Alice", "Bob", "Spell", 200, 1)
assert(#meter.players.Alice.healingEvents == 1 and #meter.players.Alice.damageEvents == 1)
now = now + 10
Button(analytics:CreateMainWindow(), "Refresh").scripts.OnClick()
assert(meter.players.Alice.dps == 20 and meter.players.Alice.hps == 10)
Button(analytics:CreateMainWindow(), "End").scripts.OnClick()
assert(not meter.currentSession and meter.combatLog[1].players.Alice.totalDamage == 200)
assert(meter:GetPlayerStats("Alice").dps == 20)
Button(analytics:CreateMainWindow(), "Clear").scripts.OnClick()
assert(#meter.combatLog == 1)
Button(analytics:CreateMainWindow(), "Clear").scripts.OnClick()
assert(#meter.combatLog == 0)
InfinityUtils.CanUseCombatLogEvent = function() return false end
UnitAffectingCombat = function() return true end
local protectedSample = false
C_DamageMeter = { GetCombatSessionFromType = function(session, metric)
	assert(session == 1)
	return { combatSources = { { name = "Alice", totalAmount = protectedSample and secret or (metric == 0 and 200 or 100) } } }
end }
dofile("InfinityPerformanceAnalytics\\Init.lua")
local analyticsLoader = frames[#frames]
analyticsLoader.scripts.OnEvent(analyticsLoader, "ADDON_LOADED", "InfinityPerformanceAnalytics")
local combatEvents
for _, frame in ipairs(frames) do
	if frame.events.ENCOUNTER_START and frame.events.PLAYER_REGEN_DISABLED then combatEvents = frame end
end
assert(combatEvents)
combatEvents.scripts.OnEvent(combatEvents, "PLAYER_REGEN_DISABLED")
combatEvents.scripts.OnUpdate(combatEvents, 1)
assert(meter.currentSession.totalDamage == 200 and meter.currentSession.totalHealing == 100)
assert(meter.sampleStatus == "Public native sample")
protectedSample = true
local warningCount = #warnings
combatEvents.scripts.OnUpdate(combatEvents, 1)
combatEvents.scripts.OnUpdate(combatEvents, 1)
assert(#warnings == warningCount + 1 and meter.currentSession.totalDamage == 200)
assert(meter.sampleStatus:find("incomplete", 1, true))
analyticsLoader.scripts.OnEvent(analyticsLoader, "INFINITY_DATA_LOADED")
assert(combatEvents == frames[#frames])

InfinityStorageManager = {
	GetFeatureSetting = function() return {} end,
	SetFeatureSetting = function() end,
}
InfinityDataManager.UpdateSourceData = function() end
dofile("InfinityGuild\\Modules\\Events.lua")
dofile("InfinityGuild\\UI\\MainUI.lua")
InfinityGuildEvents:Initialize()
InfinityGuildUI:ShowEventManager()
local manager, fields = InfinityGuildUI.eventManager, InfinityGuildUI.eventFields
assert(fields.player.point[2] + fields.player.width < fields.detail.point[2])
fields.name:SetText("Raid night")
fields.kind:SetText("RAID")
fields.detail:SetText("Normal")
manager.rows[2].scripts.OnClick(manager.rows[2])
assert(not next(InfinityGuildEvents.raids))
manager.rows[2].scripts.OnClick(manager.rows[2])
local raid = InfinityGuildEvents:GetRaid(InfinityGuildUI.selectedGuildRaid)
assert(raid and raid.status == "planned")
manager.rows[2].scripts.OnClick(manager.rows[2])
manager.rows[2].scripts.OnClick(manager.rows[2])
assert(InfinityGuildUI.selectedGuildRaid ~= raid.id)
local secondRaidId = InfinityGuildUI.selectedGuildRaid
manager.rows[8].scripts.OnClick(manager.rows[8])
assert(InfinityGuildUI.selectedGuildRaid == raid.id)
manager.rows[9].scripts.OnClick(manager.rows[9])
assert(InfinityGuildUI.selectedGuildRaid == secondRaidId)
local originalShowTab = InfinityGuildUI.ShowTab
local refreshedTab
InfinityGuildWindow = { currentTab = "raiding" }
InfinityGuildUI.ShowTab = function(_, _, tab) refreshedTab = tab end
manager.rows[3].scripts.OnClick(manager.rows[3])
manager.rows[3].scripts.OnClick(manager.rows[3])
local activeRaid = InfinityGuildEvents:GetRaid(InfinityGuildUI.selectedGuildRaid)
assert(activeRaid.status == "active" and refreshedTab == "raiding")
InfinityGuildWindow = nil
InfinityGuildUI.ShowTab = originalShowTab
fields.player:SetText("Bob")
fields.kind:SetText("Healer")
manager.rows[5].scripts.OnClick(manager.rows[5])
activeRaid.participants.Alice = { role = "Tank", active = true }
manager.rows[5].scripts.OnClick(manager.rows[5])
assert(not activeRaid.participants.Bob)
manager.rows[5].scripts.OnClick(manager.rows[5])
assert(activeRaid.participants.Bob.role == "Healer")
fields.name:SetText("Dragon")
manager.rows[6].scripts.OnClick(manager.rows[6])
manager.rows[6].scripts.OnClick(manager.rows[6])
assert(activeRaid.bosses[1].boss == "Dragon")
fields.name:SetText("Sword")
fields.detail:SetText("Dragon")
fields.value:SetText("10")
manager.rows[7].scripts.OnClick(manager.rows[7])
manager.rows[7].scripts.OnClick(manager.rows[7])
assert(activeRaid.lootDistributed[1].winner == "Bob" and activeRaid.lootDistributed[1].dkpSpent == 10)
local visibleLoot = false
for _, row in ipairs(manager.rows) do
	if row:IsShown() and row.data.text:find("Loot: Sword | Bob | Dragon | 10 DKP", 1, true) then visibleLoot = true end
end
assert(visibleLoot)
manager.rows[4].scripts.OnClick(manager.rows[4])
manager.rows[4].scripts.OnClick(manager.rows[4])
assert(activeRaid.status == "completed")
fields.name:SetText("Meeting")
fields.kind:SetText("social")
fields.value:SetText("60")
manager.rows[1].scripts.OnClick(manager.rows[1])
manager.rows[1].scripts.OnClick(manager.rows[1])
assert(InfinityGuildEvents:GetUpcomingEvents(1)[1].name == "Meeting")
manager.rows[1].scripts.OnClick(manager.rows[1])
manager.rows[1].scripts.OnClick(manager.rows[1])
assert(#InfinityGuildEvents:GetUpcomingEvents(1) == 2)
fields.name:SetText(secret)
manager.rows[1].scripts.OnClick(manager.rows[1])
assert(warnings[#warnings]:find("protected", 1, true))
local members = { Alice = { name = "Alice", dkpBalance = 5 } }
InfinityGuildRoster = {
	GetMember = function(_, name) return members[name] end,
	SaveRoster = function() end,
}
dofile("InfinityGuild\\Modules\\DKP.lua")
InfinityGuildDKP:Initialize()
InfinityGuildUI:ShowLocalDKP()
local dkpWindow = InfinityGuildUI.localDKPWindow
InfinityGuildUI.localDKPPlayer:SetText("Alice")
InfinityGuildUI.localDKPAmount:SetText("3")
dkpWindow.rows[1].scripts.OnClick(dkpWindow.rows[1])
assert(members.Alice.dkpBalance == 5)
members.Alice.dkpBalance = 6
dkpWindow.rows[1].scripts.OnClick(dkpWindow.rows[1])
assert(members.Alice.dkpBalance == 6)
dkpWindow.rows[1].scripts.OnClick(dkpWindow.rows[1])
assert(members.Alice.dkpBalance == 9)
dkpWindow.rows[2].scripts.OnClick(dkpWindow.rows[2])
dkpWindow.rows[2].scripts.OnClick(dkpWindow.rows[2])
assert(members.Alice.dkpBalance == 6)
InfinityGuildUI.localDKPAmount:SetText(secret)
dkpWindow.rows[1].scripts.OnClick(dkpWindow.rows[1])
assert(warnings[#warnings]:find("Protected", 1, true))
for i = 1, 205 do
	InfinityGuildDKP.syncHistory[#InfinityGuildDKP.syncHistory + 1] = { member = "Page" .. i, amount = i, reason = "test" }
end
InfinityGuildUI:RefreshLocalDKP()
dkpWindow.rows[6].scripts.OnClick(dkpWindow.rows[6])
assert(InfinityGuildUI.localDKPOffset == 200 and dkpWindow.rows[7].data.text:find("Page5", 1, true))
dkpWindow.rows[5].scripts.OnClick(dkpWindow.rows[5])
assert(InfinityGuildUI.localDKPOffset == 0 and dkpWindow.rows[7].data.text:find("Page205", 1, true))
print("legacy_module_ui: all tests passed")
