local frames = {}
local errors = {}
local labels = {}
local inCombat = false
local bindings = {}
local addonStates = { InfinityLoot = true, InfinityGuild = true, InfinityGear = false }
local ignoreAddonChanges = false
local rosterReady = false
local rosterCount = 12
local rosterRequests = 0

local widgetMethods = {}
function widgetMethods:SetScript(event, callback) self.scripts[event] = callback end
function widgetMethods:RegisterEvent(event) self.events[event] = true end
function widgetMethods:UnregisterEvent(event) self.events[event] = nil end
function widgetMethods:GetName() return self.name end
function widgetMethods:GetChildren() return unpack(self.children) end
function widgetMethods:GetRegions() return unpack(self.regions) end
function widgetMethods:CreateFontString()
	local label = CreateFrame("FontString", nil, self)
	table.insert(self.regions, label)
	return label
end
function widgetMethods:SetText(text) self.text = text; table.insert(labels, text) end
function widgetMethods:Show() self.shown = true end
function widgetMethods:Hide() self.shown = false end
function widgetMethods:IsShown() return self.shown ~= false end
function widgetMethods:IsVisible() return self:IsShown() end
function widgetMethods:Disable() self.disabled = true end
local widgetMeta = { __index = function(_, key)
	if key == "rosterView" or key == "selected" then return nil end
	return widgetMethods[key] or function() end
end }

function CreateFrame(_, name, parent)
	local frame = setmetatable({ name = name, events = {}, scripts = {}, children = {}, regions = {}, shown = true }, widgetMeta)
	if parent and parent.children then table.insert(parent.children, frame) end
	if name then _G[name] = frame end
	table.insert(frames, frame)
	return frame
end
UIParent = CreateFrame("Frame")
SlashCmdList = {}
time = function() return 1000 end
date = os.date
UnitGUID = function() return "Player-1" end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
InCombatLockdown = function() return inCombat end
ClearOverrideBindings = function() bindings = {} end
SetOverrideBindingClick = function(_, _, key, button) bindings[key] = button end
GetCVarBool = function() return false end
C_AddOns = {
	DoesAddOnExist = function(name) return addonStates[name] ~= nil end,
	GetAddOnEnableState = function(name, character)
		assert(character == nil or character == "Player-1")
		if addonStates[name] == nil then return nil end
		return addonStates[name] and 2 or 0
	end,
	EnableAddOn = function(name, character)
		assert(character == "Player-1")
		if not ignoreAddonChanges then addonStates[name] = true end
	end,
	DisableAddOn = function(name, character)
		assert(character == "Player-1")
		if not ignoreAddonChanges then addonStates[name] = false end
	end,
}

dofile("InfinityCore\\Core\\Constants.lua")
dofile("InfinityCore\\Core\\Utilities.lua")
local protectedBossValue = {}
issecretvalue = function(value) return value == protectedBossValue end
UnitExists = function() return protectedBossValue end
assert(InfinityUtils:IsRaidBoss("boss1") == nil)
UnitExists = function() return true end
UnitClassification = function() return protectedBossValue end
assert(InfinityUtils:IsRaidBoss("target") == nil)
UnitIsRaidBoss = function() return protectedBossValue end
assert(InfinityUtils:IsRaidBoss("boss1") == nil)
UnitIsRaidBoss = nil
InfinityUtils.Error = function(_, message) table.insert(errors, message) end
InfinityUtils.Warning = function(_, message) table.insert(errors, message) end
dofile("InfinityCore\\Core\\Storage.lua")
dofile("InfinityCore\\Core\\Messaging.lua")
dofile("InfinityCore\\Core\\DataManager.lua")
dofile("InfinityCore\\Core\\CommandRegistry.lua")
dofile("InfinityCore\\UI\\AddonManager.lua")
InfinityCoreDB = { global = { enabledFeatures = { InfinityGear = true } } }
InfinityStorageManager:Initialize(InfinityCoreDB)

local function dispatchSlash(alias, message)
	for id, callback in pairs(SlashCmdList) do
		local index = 1
		while _G["SLASH_" .. id .. index] do
			if _G["SLASH_" .. id .. index] == alias then
				callback(message)
				return true
			end
			index = index + 1
		end
	end
	return false
end

local lastArgs
assert(InfinityCommandRegistry:RegisterCommand("infinity", function(args, message)
	lastArgs = { args, message }
end, { "inf", "suite" }))
assert(dispatchSlash("/infinity", "one two") and lastArgs[1][2] == "two")
assert(dispatchSlash("/inf", "abc") and lastArgs[2] == "abc")
assert(dispatchSlash("/suite", ""))
assert(InfinityCommandRegistry:RegisterCommand("infinity", function() end, { "new" }))
assert(not dispatchSlash("/inf", "") and not InfinityCommandRegistry:GetCommand("inf"))
assert(dispatchSlash("/new", ""))
assert(not InfinityCommandRegistry:RegisterCommand("broken", nil))
InfinityCommandRegistry:RegisterCommand("fail", function() error("command failure") end)
dispatchSlash("/fail", "")
assert(errors[#errors]:find("command failure", 1, true))

dofile("InfinityCore\\Init.lua")
local coreLoader = frames[#frames]
coreLoader.scripts.OnEvent(coreLoader, "ADDON_LOADED", "InfinityCore")
local database = InfinityCore:GetDatabase("TestFeature")
database.saved = { value = 42 }
assert(InfinityCore:GetDatabase("TestFeature") == database)
assert(InfinityCoreDB.global.settings.TestFeature.saved.value == 42)
InfinityStorageManager:Initialize(InfinityCoreDB)
assert(InfinityCore:GetDatabase("TestFeature").saved.value == 42)
local slashMessage
assert(InfinityCore:RegisterSlashCommand("caltest", function(message) slashMessage = message end))
assert(dispatchSlash("/caltest", "create event"))
assert(slashMessage == "create event")

inCombat = true
InfinityCommandRegistry:RegisterKeybind("TEST", "Test", function() end, "CTRL-T")
assert(bindings["CTRL-T"] == nil)
local owner = InfinityKeybindOwner
assert(owner.events.PLAYER_REGEN_ENABLED)
inCombat = false
owner.scripts.OnEvent(owner, "PLAYER_REGEN_ENABLED")
assert(bindings["CTRL-T"] == "InfinityKeybindBtn_TEST")
assert(not owner.events.PLAYER_REGEN_ENABLED)

InfinityAddonManager:RegisterAddon("InfinityLoot", "1", {})
assert(InfinityAddonManager:IsAddonEnabled("InfinityLoot"))
assert(not InfinityStorageManager:IsFeatureEnabled("InfinityGear"))
assert(InfinityStorageManager:SetFeatureEnabled("InfinityGear", true))
assert(InfinityStorageManager:IsFeatureEnabled("InfinityGear"))
assert(InfinityAddonManager:SetAddonEnabled("InfinityLoot", false))
assert(not InfinityAddonManager:IsAddonEnabled("InfinityLoot"))
assert(InfinityAddonManager:IsAddonEnabled("Missing") == nil)
assert(not InfinityAddonManager:SetAddonEnabled("Missing", true))
ignoreAddonChanges = true
assert(not InfinityAddonManager:SetAddonEnabled("InfinityGear", false))
assert(InfinityAddonManager:IsAddonEnabled("InfinityGear"))
ignoreAddonChanges = false

InfinityDataManager:RegisterSource("example", { first = 1, second = 2 })
local statistics = InfinityDataManager:GetStatistics()
assert(statistics.enabledSources == 1 and statistics.totalDataPoints == 2)

IsInGuild = function() return true end
GetGuildInfo = function() return "Test Guild" end
GetNumGuildMembers = function() return rosterReady and rosterCount or 0 end
GetGuildRosterInfo = function(index)
	if index == 1 then return "Alice-Realm", "Master", 0, 60, nil, nil, nil, nil, true, nil, "MAGE" end
	if index == 2 then return "Bob-Realm", "Member", 1, 50, nil, nil, nil, nil, false, nil, "WARRIOR" end
	return "Member" .. index .. "-Realm", "Member", 1, 40, nil, nil, nil, nil, false, nil, "MAGE"
end
C_GuildInfo = { GuildRoster = function() rosterRequests = rosterRequests + 1 end }
InfinityUIFramework = {
	CreateLabel = function(_, parent, text)
		local label = parent:CreateFontString()
		label:SetText(text)
		return label
	end,
	CreateButton = function(_, parent, text, _, _, callback)
		local button = CreateFrame("Button", nil, parent)
		button:SetText(text)
		button:SetScript("OnClick", callback)
		return button
	end,
	CreateScrollFrame = function(_, parent)
		local scroll = CreateFrame("ScrollFrame", nil, parent)
		scroll.content = CreateFrame("Frame", nil, scroll)
		return scroll
	end,
}

addonStates.InfinityDetails = false
local installed = { "InfinityCore", "InfinityGuild", "InfinityDetails", "Unrelated" }
C_AddOns.GetNumAddOns = function() return #installed end
C_AddOns.GetAddOnInfo = function(index) return installed[index] end
dofile("InfinityCore\\UI\\MainFrame.lua")
local opened = false
InfinityGuildUI = { Toggle = function() opened = true end }
labels = {}
local beforeFeatureFrames = #frames
InfinityMainFrame:ShowFeaturesTab({ contentFrame = CreateFrame("Frame") })
local detailsFound, coreFound = false, false
for _, text in ipairs(labels) do
	if text:find("InfinityDetails: ", 1, true) then detailsFound = true end
	if text:find("InfinityCore: ", 1, true) then coreFound = true end
end
assert(detailsFound and not coreFound)
local openButtons = {}
for index = beforeFeatureFrames + 1, #frames do
	if frames[index].text == "Open" then openButtons[#openButtons + 1] = frames[index] end
end
assert(#openButtons == 2 and rawget(openButtons[1], "disabled") and not rawget(openButtons[2], "disabled"))
openButtons[2].scripts.OnClick()
assert(opened)
InfinityGuildUI = nil

for line in io.lines("InfinityGuild\\InfinityGuild.toc") do
	if line:match("%.lua%s*$") then
		dofile("InfinityGuild\\" .. line:match("^%s*(.-)%s*$"))
	end
end
local guildLoader = frames[#frames]
assert(guildLoader.events.ADDON_LOADED)
guildLoader.scripts.OnEvent(guildLoader, "ADDON_LOADED", "InfinityGuild")
assert(not guildLoader.events.ADDON_LOADED)
assert(InfinityGuildRoster and InfinityGuildDKP and InfinityGuildEvents)
assert(InfinityDataManager:GetSourceData("InfinityGuild"))
local rosterFrame = InfinityGuildRoster.eventFrame
rosterFrame.scripts.OnEvent(rosterFrame, "PLAYER_LOGIN")
assert(rosterRequests == 1)

local window = CreateFrame("Frame", "InfinityGuildWindow")
window.contentArea = CreateFrame("Frame", nil, window)
window.currentTab = "roster"
rosterReady = true
labels = {}
rosterFrame.scripts.OnEvent(rosterFrame, "GUILD_ROSTER_UPDATE")
assert(InfinityGuildRoster:GetGuildStats("Test Guild").memberCount == 12)
assert(InfinityGuildRoster:GetMember("Alice").rankIndex == 0)
assert(InfinityStorageManager:GetFeatureSetting("InfinityGuild", "roster").members.Bob)
assert(InfinityGuildDKP:AwardDKP("Alice", 10).reason == "Manual Award")
assert(InfinityGuildDKP:SpendDKP("Alice", 3).reason == "Loot Purchased")
assert(InfinityGuildRoster:GetMember("Alice").dkpBalance == 7)
assert(InfinityStorageManager:GetFeatureSetting("InfinityGuild", "roster").members.Alice.dkpBalance == 7)
assert(not InfinityGuildDKP:SpendDKP("Alice", -1))
assert(not InfinityGuildDKP:SpendDKP("Alice", 100))
assert(not InfinityGuildDKP:AwardDKP("Alice", protectedBossValue))
assert(InfinityGuildDKP:AwardDKP("Bob", 1))
assert(InfinityGuildDKP:GetDKPHistory("Alice", 2)[2].amount == 10)
local pending = #InfinityGuildDKP.pendingSync
assert(not InfinityGuildDKP:SyncDKPWithGuild() and #InfinityGuildDKP.pendingSync == pending)
assert(InfinityGuildDKP:ResetMemberDKP("Alice", 0).newBalance == 0)
local errorCount = #errors
assert(dispatchSlash("/infguildroster", ""))
assert(#errors == errorCount)
assert(not dispatchSlash("/g", ""))
local foundAlice, foundBob, foundLast = false, false, false
for _, text in ipairs(labels) do
	if text:find("Alice", 1, true) then foundAlice = true end
	if text:find("Bob", 1, true) then foundBob = true end
	if text:find("Member12", 1, true) then foundLast = true end
end
assert(foundAlice and foundBob and foundLast)
rosterCount = 1
rosterFrame.scripts.OnEvent(rosterFrame, "GUILD_ROSTER_UPDATE")
assert(#InfinityGuildRoster:GetGuildMembers("Test Guild") == 1)

for _, addon in ipairs({ "InfinityRaid", "InfinityGear", "InfinityGuide", "InfinityQoL" }) do
	dofile(addon .. "\\Init.lua")
	local loader = frames[#frames]
	loader.scripts.OnEvent(loader, "ADDON_LOADED", addon)
end
assert(InfinityCommandRegistry:GetCommand("infraid"))
assert(InfinityCommandRegistry:GetCommand("infgear"))
assert(InfinityCommandRegistry:GetCommand("infguide"))
assert(not dispatchSlash("/r", ""))
assert(not dispatchSlash("/e", ""))
assert(not dispatchSlash("/q", ""))
print("core_runtime: all tests passed")
