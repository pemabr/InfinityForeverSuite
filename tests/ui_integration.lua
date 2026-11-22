local frames, notices = {}, {}
local combat = true
local methods = {}
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:SetText(text) self.text = text end
function methods:SetPoint(...) self.point = { ... } end
function methods:Show() self.shown = true end
function methods:Hide()
	self.shown = false
	if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
local meta = { __index = function(_, key)
	if key == "targetName" or key == "targetMethod" or key == "featureName" or key == "featureLabel" then return nil end
	return methods[key] or function() end
end }
function CreateFrame(_, name, parent)
	local frame = setmetatable({ name = name, parent = parent, scripts = {}, events = {}, shown = true }, meta)
	if name then assert(not _G[name]); _G[name] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
Minimap = CreateFrame("Frame")
function Minimap:GetWidth() return 140 end
function Minimap:GetCenter() return 100, 100 end
function Minimap:GetEffectiveScale() return 1 end
function UIParent:GetCenter() return 500, 300 end
function UIParent:GetRight() return 1000 end
function UIParent:GetEffectiveScale() return 1 end
GetCursorPosition = function() return 200, 100 end
WorldMapFrame = CreateFrame("Frame")
CommunitiesFrame = CreateFrame("Frame")
ProfessionsFrame = CreateFrame("Frame")
CharacterFrame = CreateFrame("Frame")
WorldMapFrame.scripts.OnShow = "unchanged"
InCombatLockdown = function() return combat end
local profile = {}
local savedSettings = {}
InfinityStorageManager = {
	GetProfile = function(_, key, default) if profile[key] == nil then return default end return profile[key] end,
	SetProfile = function(_, key, value) profile[key] = value end,
	GetSetting = function(_, category, key, default)
		return savedSettings[category .. key] == nil and default or savedSettings[category .. key]
	end,
	SetSetting = function(_, category, key, value) savedSettings[category .. key] = value end,
}
InfinityMessaging = { Publish = function() end, Subscribe = function() end }
InfinityUtils = {
	Warning = function(_, message) notices[#notices + 1] = message end,
	Error = function(_, message) notices[#notices + 1] = message end,
	Info = function() end,
}
InfinityUIFramework = {
	CreateFrame = function(_, name, parent) return CreateFrame("Frame", name, parent) end,
	CreateLabel = function(_, parent, text)
		local label = CreateFrame("FontString", nil, parent)
		label:SetText(text)
		return label
	end,
	CreateButton = function(_, parent, text, _, _, callback)
		local button = CreateFrame("Button", nil, parent)
		button:SetText(text)
		button:SetScript("OnClick", callback)
		return button
	end,
}
GameTooltip = {
	SetOwner = function(self, owner) self.owner = owner end,
	SetText = function(self, text) self.text = text end,
	AddLine = function(self, text) self.description = text end,
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end,
}
local loaded = { InfinityQuestie = true, InfinityGuide = true, InfinityGuild = true,
	InfinityInventory = true, InfinityDataCollector = true, InfinityDetails = true, InfinityDKP = true }
C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] end }
local opened = {}
InfinityQuestieUI = { Toggle = function() opened.quest = true end, ShowSearch = function() opened.search = true end,
	ShowSelectedWaypoint = function() opened.selected = true end,
	ShowSelectedLocations = function() opened.locations = true end }
InfinityGuideUI = { Toggle = function() opened.guide = true end, ShowGuides = function() opened.guides = true end }
InfinityGuildUI = { Toggle = function() opened.guild = true end }
InfinityInventoryUI = { Toggle = function() opened.inventory = true end, ShowRecipe = function() opened.recipe = true end }
InfinityInventoryUI.OpenCurrentBank = function() opened.bank = true end
InfinityDataCollectorUI = { Toggle = function() opened.collector = true end }
InfinityGuildRecipes = { Toggle = function() end, OpenForProfession = function() opened.crafters = true end }
InfinityDetailsUI = { Toggle = function() opened.details = true end }
InfinityDKPUI = { Toggle = function() opened.dkp = true end, ShowGuildBankLog = function() opened.bankLog = true end }
InfinityAuctionPrices = { Toggle = function() opened.prices = true end }
InfinityShoppingLists = { Toggle = function() opened.shopping = true end }
dofile("InfinityCore\\UI\\MainFrame.lua")
InfinityMainFrame.Toggle = function() opened.suite = true end
dofile("InfinityCore\\UI\\UIIntegration.lua")
local ui = InfinityUIIntegration
ui:Initialize()
assert(not ui.minimapButton and ui.navigationPending)
combat = false
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "PLAYER_REGEN_ENABLED")
assert(ui.minimapButton and ui.hostButtons[WorldMapFrame] and ui.hostButtons[CommunitiesFrame])
assert(ui.hostButtons[ProfessionsFrame] and ui.hostButtons[CharacterFrame])
assert(WorldMapFrame.scripts.OnShow == "unchanged")
local count = #frames
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "ADDON_LOADED", "Blizzard_Professions")
assert(#frames == count)
CalendarFrame = CreateFrame("Frame")
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "ADDON_LOADED", "Blizzard_Calendar")
assert(ui.hostButtons[CalendarFrame])
BankFrame = CreateFrame("Frame")
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "BANKFRAME_OPENED")
assert(ui.hostButtons[BankFrame])
GuildBankFrame, AuctionHouseFrame = CreateFrame("Frame"), CreateFrame("Frame")
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "GUILDBANKFRAME_OPENED")
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "AUCTION_HOUSE_SHOW")
assert(ui.hostButtons[GuildBankFrame] and ui.hostButtons[AuctionHouseFrame])
combat = true
TradeSkillFrame = CreateFrame("Frame")
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "ADDON_LOADED", "Blizzard_TradeSkillUI")
assert(not ui.hostButtons[TradeSkillFrame] and ui.navigationPending)
combat = false
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "PLAYER_REGEN_ENABLED")
assert(ui.hostButtons[TradeSkillFrame])
ui.minimapButton.scripts.OnDragStart()
ui.minimapButton.scripts.OnUpdate()
ui.minimapButton.scripts.OnDragStop()
assert(profile["minimap.angle"] == 0 and not ui.minimapButton.scripts.OnUpdate)

ui.minimapButton.scripts.OnEnter()
assert(GameTooltip.shown and GameTooltip.text == "Infinity Suite")
ui.minimapButton.scripts.OnLeave()
assert(not GameTooltip.shown)
ui.minimapButton.scripts.OnClick(ui.minimapButton, "LeftButton")
assert(ui.menu:IsShown() and ui.menu.buttons[1].text == "Suite Settings")
local details
for _, button in ipairs(ui.menu.buttons) do
	if button:IsShown() and button.text == "Combat Details" then details = button end
end
assert(details)
details.scripts.OnClick(details)
assert(opened.details and not ui.menu:IsShown())
ui.minimapButton.scripts.OnClick(ui.minimapButton, "RightButton")
assert(opened.suite)

local map = ui.hostButtons[WorldMapFrame]
function map:GetCenter() return 900, 400 end
function map:GetEffectiveScale() return 1 end
function map:GetWidth() return 75 end
map.scripts.OnClick()
assert(ui.menu:IsShown() and ui.menu.buttons[1].text == "Quest Waypoint")
assert(ui.menu.point[4] == 119.5)
function map:GetCenter() return 100, 400 end
ui:PositionMenu(ui.menu, map)
assert(ui.menu.point[4] == -119.5)
function map:GetCenter() return nil, nil end
ui:PositionMenu(ui.menu, map)
assert(ui.menu.point[4] == 0 and ui.menu.point[5] == 0)
ui.menu.buttons[1].scripts.OnClick(ui.menu.buttons[1])
assert(opened.selected)
map.scripts.OnClick()
assert(ui.menu.buttons[2].text == "Quest Locations")
ui.menu.buttons[2].scripts.OnClick(ui.menu.buttons[2])
assert(opened.locations)
map.scripts.OnClick()
assert(ui.menu.buttons[3].text == "Search Quests")
ui.menu.buttons[3].scripts.OnClick(ui.menu.buttons[3])
assert(opened.search)
local skills = ui.hostButtons[ProfessionsFrame]
skills.scripts.OnClick()
assert(ui.menu.buttons[1].text == "Recipe Reagents")
ui.menu.buttons[1].scripts.OnClick(ui.menu.buttons[1])
assert(opened.recipe)
skills.scripts.OnClick()
assert(ui.menu.buttons[2].text == "Guild Crafters")
ui.menu.buttons[2].scripts.OnClick(ui.menu.buttons[2])
assert(opened.crafters)
local bank = ui.hostButtons[BankFrame]
bank.scripts.OnClick()
assert(ui.menu.buttons[1].text == "My Bank")
ui.menu.buttons[1].scripts.OnClick(ui.menu.buttons[1])
assert(opened.bank)
ui.hostButtons[GuildBankFrame].scripts.OnClick()
assert(ui.menu.buttons[1].text == "Guild Bank Log")
ui.menu.buttons[1].scripts.OnClick(ui.menu.buttons[1])
assert(opened.bankLog)
ui.hostButtons[AuctionHouseFrame].scripts.OnClick()
assert(ui.menu.buttons[1].text == "Auction Prices")
ui.menu.buttons[1].scripts.OnClick(ui.menu.buttons[1])
assert(opened.prices)
local guild = ui.hostButtons[CommunitiesFrame]
guild.scripts.OnClick()
local guildAction
for _, button in ipairs(ui.menu.buttons) do
	if button:IsShown() and button.text == "Guild" then guildAction = button end
end
assert(guildAction)
loaded.InfinityGuild = false
guildAction.scripts.OnClick(guildAction)
assert(not opened.guild and notices[#notices]:find("unavailable", 1, true))
profile["minimap.enabled"] = false
ui:UpdateMinimapVisibility()
assert(not ui.minimapButton:IsShown())
profile["minimap.enabled"] = true
ui:UpdateMinimapVisibility()
assert(ui.minimapButton:IsShown())
dofile("InfinityCore\\UI\\SettingsPanel.lua")
InfinitySettingsPanel:Initialize()
combat = true
assert(InfinitySettingsPanel:SetSetting("General", "Show Minimap Button", false))
assert(ui.minimapButton:IsShown() and ui.visibilityPending)
combat = false
ui.navigationEvents.scripts.OnEvent(ui.navigationEvents, "PLAYER_REGEN_ENABLED")
assert(not ui.minimapButton:IsShown())
InfinitySettingsPanel.settings.General["Show Minimap Button"].value = true
InfinitySettingsPanel:ApplySettings()
assert(ui.minimapButton:IsShown() and profile["minimap.enabled"])
print("ui_integration: all tests passed")
