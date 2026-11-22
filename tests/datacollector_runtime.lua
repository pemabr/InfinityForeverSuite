local frames, db, commands, warnings = {}, {}, {}, {}
local secret, name, secondSource = {}, "Herbs", nil
local guildName, guildCount = nil, 1
local widget = {}
function widget:RegisterEvent(event)
	assert(event ~= "UNIT_DIED" and event ~= "NPC_CHAT")
	self.events[event] = true
end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return self.text end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:SetShown(value) self.shown = value end
function widget:IsShown() return self.shown end
function widget:SetChecked(value) self.checked = not not value end
function widget:GetChecked() return self.checked end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, frameName, parent)
	if frameName then assert(not _G[frameName], "duplicate frame: " .. frameName) end
	local frame = setmetatable({ events = {}, scripts = {}, parent = parent, shown = true }, meta)
	if frameName then _G[frameName] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
time = function() return 100 end
issecretvalue = function(value) return value == secret end
GetGuildInfo = function() return guildName end
GetNumGuildMembers = function() return guildCount end
GetGuildRosterInfo = function() return secret end
GetQuestID = function() return 123 end
GetTitleText = function() return "Herbs" end
GetQuestText = function() return "Find herbs" end
GetRealZoneText = function() return "Meadow" end
UnitName = function(unit) if unit == "npc" then return "Quest giver" else return "Wolf" end end
UnitGUID = function() return "Creature-0-1-2-3-444-00001234" end
C_QuestLog = {
	GetNumQuestLogEntries = function() return 3 end,
	GetInfo = function(index)
		if index == 1 then return { isHeader = true } end
		if index == 2 then return { questID = 123, title = name, level = 10 } end
		return { questID = secret, title = "Protected" }
	end,
}
GetNumLootItems = function() return 1 end
GetLootSlotLink = function() return "|Hitem:456:0|h[Item]|h" end
GetLootSlotInfo = function() return 1, "Item", 1, 999, 2 end
GetLootSourceInfo = function() return "Creature-0-1-2-3-444-00001234", 1, secondSource end
InfinityCore = {
	GetDatabase = function(_, name) assert(name == "InfinityDataCollector"); return db end,
	RegisterAddon = function() end,
	RegisterCommand = function(_, command, _, callback) commands[command] = callback end,
}
InfinityMessaging = { Subscribe = function() end, Publish = function() end }
local registered, suiteCategory = {}, {}
InfinitySettingsPanel = { blizzardCategory = suiteCategory, blizzardPanel = {} }
Settings = {
	RegisterCanvasLayoutCategory = function(panel, name)
		registered.category = { panel = panel, name = name }
		return registered.category
	end,
	RegisterAddOnCategory = function(category) registered.addon = category end,
	RegisterCanvasLayoutSubcategory = function(parent, panel, name)
		registered.parent = parent
		registered.subcategory = { panel = panel, name = name }
		return registered.subcategory
	end,
}
dofile("InfinityCore\\Core\\Utilities.lua")
InfinityUtils.Info = function() end
InfinityUtils.Debug = function() end
InfinityUtils.Warning = function(_, message) warnings[#warnings + 1] = message end
for line in io.lines("InfinityDataCollector\\InfinityDataCollector.toc") do
	if line:match("%.lua%s*$") and not line:match("^%s*#") then
		dofile("InfinityDataCollector\\" .. line:match("^%s*(.-)%s*$"))
	end
end
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityDataCollector")
assert(registered.parent == suiteCategory and registered.subcategory == InfinityDataCollectorUI.blizzardCategory)
assert(InfinityDataCollectorUI:RegisterBlizzardSettings() == registered.subcategory)
local core, hooks = InfinityDataCollectorCore, InfinityDataCollectorHooks
assert(db.gatheredData.quests[123].name == "Herbs")
assert(db.gatheredData.quests[123].giver_location == nil)
assert(hooks.eventFrame.events.QUEST_LOG_UPDATE and hooks.eventFrame.events.LOOT_OPENED)
local guildFrame
for _, frame in ipairs(frames) do if frame.events.GUILD_ROSTER_UPDATE then guildFrame = frame end end
guildName = secret
guildFrame.scripts.OnEvent(guildFrame, "GUILD_ROSTER_UPDATE")
guildName, guildCount = "Guild", secret
guildFrame.scripts.OnEvent(guildFrame, "GUILD_ROSTER_UPDATE")
guildCount = 1
guildFrame.scripts.OnEvent(guildFrame, "GUILD_ROSTER_UPDATE")
assert(next(InfinityDataCollectorPrivacy.guildMembers) == nil)
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "QUEST_LOG_UPDATE")
assert(db.gatheredData.quests[123].instances == 1)
local positions, observedOffer = InfinityGuildQuestPositions
InfinityGuildQuestPositions = { ObserveOffer = function(_, id, giver) observedOffer = { id, giver } end }
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "QUEST_DETAIL")
InfinityGuildQuestPositions = positions
assert(observedOffer[1] == 123 and observedOffer[2] == "Quest giver")
local quest = db.gatheredData.quests[123]
assert(quest.giver == "Quest giver" and quest.zone == "Meadow" and quest.objective == "Find herbs")
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "LOOT_OPENED")
local drop = db.gatheredData.drops["444_456"]
assert(drop and drop.mobName == "Wolf" and drop.itemName == "Item" and drop.rarity == 2 and drop.dropRate == nil)
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "LOOT_OPENED")
assert(drop.sightings == 1)
secondSource = "Creature-0-1-2-3-555-00001234"
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "LOOT_OPENED")
secondSource = secret
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "LOOT_OPENED")
assert(drop.sightings == 1)
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "LOOT_CLOSED")
secondSource = nil
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "LOOT_OPENED")
assert(drop.sightings == 2)
name = secret
hooks.eventFrame.scripts.OnEvent(hooks.eventFrame, "QUEST_LOG_UPDATE")
assert(quest.name == "Herbs")
core:SetGatheringEnabled(false)
assert(db.gatheringEnabled == false)
core:Initialize()
assert(not core:IsGatheringEnabled() and core.gatheredData.quests[123] == quest)
assert(not InfinityDataCollectorNetwork:SetSharingEnabled(true))
assert(not InfinityDataCollectorNetwork:Send())
assert(#warnings >= 2 and not InfinityDataCollectorNetwork.shareEnabled)
commands["/datacollector guild"]("enable")
assert(not InfinityDataCollectorNetwork.shareEnabled)
commands["/datacollector guild"]("live on")
assert(not InfinityGuildKnowledge.available and not db.guildKnowledge.enabled)
commands["/datacollector guild"]("live sync")
assert(warnings[#warnings]:find("disabled, busy", 1, true))
commands["/datacollector guild"]("nodes on")
assert(not InfinityGuildGatherKnowledge.available and not db.guildGatherKnowledge.enabled)
commands["/datacollector guild"]("nodes sync")
assert(warnings[#warnings]:find("disabled, busy", 1, true))
commands["/datacollector guild"]("recipes on")
assert(not InfinityGuildRecipes.available and not db.guildRecipes.enabled)
commands["/datacollector guild"]("offers on")
assert(not InfinityGuildQuestPositions.available and not db.guildQuestPositions.enabled)
commands["/datacollector guild"]("bosses on")
assert(not InfinityGuildBossReports.available and not db.guildBossReports.enabled)
commands["/datacollector guild"]("bags on")
assert(not InfinityGuildBagReports.available and not db.guildBagReports.enabled)
commands["/datacollector"]()
assert(InfinityDataCollectorUI.mainFrame:IsShown())
InfinityDataCollectorUI:ShowTab("settings")
assert(InfinityDataCollectorUI.tabs.settings.liveToggle and InfinityDataCollectorUI.tabs.settings.nodesToggle
	and InfinityDataCollectorUI.tabs.settings.recipesToggle and InfinityDataCollectorUI.tabs.settings.offersToggle
	and InfinityDataCollectorUI.tabs.settings.bossesToggle and InfinityDataCollectorUI.tabs.settings.bagsToggle)
local ui, game = InfinityDataCollectorUI, InfinityDataCollectorUI.blizzardControls
assert(ui:GetAutoSyncEnabled())
ui.tabs.stats.autoSync.scripts.OnClick()
assert(not ui:GetAutoSyncEnabled() and ui.tabs.stats.autoSync.text == "Auto-sync: Off")
ui.tabs.stats.autoSync.scripts.OnClick()
assert(ui:GetAutoSyncEnabled())
local integrations, syncCalls = InfinityDataCollectorDBIntegration, 0
local originalSync = integrations.SyncAll
integrations.SyncAll = function() syncCalls = syncCalls + 1; return {} end
ui.tabs.stats.externalSync.scripts.OnClick()
assert(syncCalls == 1)
integrations.SyncAll = originalSync
ui:ShowTab("network")
local networkButtons = ui.tabs.network.buttons
local originalSend = InfinityDataCollectorNetwork.Send
InfinityDataCollectorNetwork.Send = function() syncCalls = syncCalls + 1; return true end
networkButtons.send.scripts.OnClick()
assert(syncCalls == 2)
InfinityDataCollectorNetwork.Send = originalSend
local syncModules = {
	live = InfinityGuildKnowledge, nodes = InfinityGuildGatherKnowledge, recipes = InfinityGuildRecipes,
	offers = InfinityGuildQuestPositions, bosses = InfinityGuildBossReports, bags = InfinityGuildBagReports,
}
for key, module in pairs(syncModules) do
	local original = module.SyncNext
	module.SyncNext = function() syncCalls = syncCalls + 1; return true end
	networkButtons[key].scripts.OnClick()
	module.SyncNext = original
end
assert(syncCalls == 8)
networkButtons.apply.scripts.OnClick()
assert(warnings[#warnings]:find("No collector snapshot", 1, true))
networkButtons.settings.scripts.OnClick()
assert(ui.currentTab == "settings")
ui.blizzardPanel.scripts.OnShow()
assert(not game.gatheringToggle:GetChecked())
game.gatheringToggle:SetChecked(true)
game.gatheringToggle.scripts.OnClick(game.gatheringToggle)
assert(core:IsGatheringEnabled() and ui.tabs.settings.gatheringToggle:GetChecked())
ui.tabs.settings.gatheringToggle:SetChecked(false)
ui.tabs.settings.gatheringToggle.scripts.OnClick(ui.tabs.settings.gatheringToggle)
assert(not core:IsGatheringEnabled() and not game.gatheringToggle:GetChecked())
game.liveToggle:SetChecked(true)
game.liveToggle.scripts.OnClick(game.liveToggle)
assert(not game.liveToggle:GetChecked() and not ui.tabs.settings.liveToggle:GetChecked())
game.sharingToggle:SetChecked(true)
game.sharingToggle.scripts.OnClick(game.sharingToggle)
assert(not game.sharingToggle:GetChecked() and not ui.tabs.settings.sharingToggle:GetChecked())
for _, item in ipairs({
	{ "liveToggle", InfinityGuildKnowledge },
	{ "nodesToggle", InfinityGuildGatherKnowledge },
	{ "recipesToggle", InfinityGuildRecipes },
	{ "offersToggle", InfinityGuildQuestPositions },
	{ "bossesToggle", InfinityGuildBossReports },
	{ "bagsToggle", InfinityGuildBagReports },
}) do
	local key, module = item[1], item[2]
	local original = module.SetEnabled
	module.SetEnabled = function(self, value) self.db.enabled = value; return value end
	game[key]:SetChecked(true)
	game[key].scripts.OnClick(game[key])
	assert(module.db.enabled and ui.tabs.settings[key]:GetChecked())
	ui.tabs.settings[key]:SetChecked(false)
	ui.tabs.settings[key].scripts.OnClick(ui.tabs.settings[key])
	assert(not module.db.enabled and not game[key]:GetChecked())
	module.SetEnabled = original
end
db.guildKnowledge.enabled = true
ui.blizzardPanel.scripts.OnShow()
assert(game.liveToggle:GetChecked())
db.guildKnowledge.enabled = false
ui.blizzardPanel.scripts.OnShow()
assert(not game.liveToggle:GetChecked())
ui.tabs.settings.refreshFunc()
InfinityDataCollectorUI:ShowTab("network")
assert(InfinityDataCollectorUI.tabs.network.text.text:find("Live quest/drop knowledge: Unavailable", 1, true))
InfinityDataCollectorUI:ShowTab("knowledge")
local knowledge = InfinityDataCollectorUI.tabs.knowledge
knowledge.input:SetText("123")
knowledge.questButton.scripts.OnClick()
assert(knowledge.text.text:find("Herbs", 1, true) and knowledge.text.text:find("10", 1, true))
knowledge.input:SetText("444")
knowledge.dropsButton.scripts.OnClick()
assert(knowledge.text.text:find("456: Item (quality 2)", 1, true))
for id = 500, 510 do core:RecordDropData(444, "Wolf", id, "Drop " .. id, nil, nil) end
knowledge.dropsButton.scripts.OnClick()
assert(knowledge.text.text:find("page 1/2", 1, true))
knowledge.nextButton.scripts.OnClick()
assert(knowledge.text.text:find("page 2/2", 1, true) and knowledge.text.text:find("510: Drop 510", 1, true))
knowledge.previousButton.scripts.OnClick()
assert(knowledge.text.text:find("page 1/2", 1, true))
knowledge.input:SetText("invalid")
knowledge.questButton.scripts.OnClick()
assert(knowledge.text.text:find("valid", 1, true))
commands["/datacollector"]()
assert(not InfinityDataCollectorUI.mainFrame:IsShown())
ui.blizzardCategory, ui.blizzardControls = nil, nil
Settings.RegisterCanvasLayoutSubcategory = nil
assert(ui:RegisterBlizzardSettings() == registered.category and registered.addon == registered.category)
ui.blizzardCategory, ui.blizzardControls = nil, nil
Settings = nil
InfinitySettingsPanel.blizzardCategory = InfinitySettingsPanel.blizzardPanel
InterfaceOptions_AddCategory = function(panel) registered.legacy = panel end
assert(ui:RegisterBlizzardSettings() == registered.legacy and registered.legacy.parent == "Infinity Suite")
ui.blizzardCategory, ui.blizzardControls = nil, nil
InterfaceOptions_AddCategory = nil
assert(ui:RegisterBlizzardSettings() == nil and warnings[#warnings]:find("/datacollector settings", 1, true))
print("datacollector_runtime: all tests passed")
