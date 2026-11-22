local frames, commands, hooks, messages, warnings = {}, {}, {}, {}, {}
local currentName, currentRealm, currentLevel = "Alice", "Realm", 70
local characters, lootDB, dkpDB = {}, {}, {}
local settings = { General = { ["Enable Tooltips"] = false } }

InfinityUtils = {
	Info = function() end,
	Debug = function() end,
	Warning = function(_, text) warnings[#warnings + 1] = text end,
	Error = function(_, message) error(message) end,
	GetTimeStamp = function() return 1000 end,
	GetItemInfo = function() error("unconfigured prices must not be estimated") end,
}
InfinityStorageManager = {
	GetGlobal = function() return characters end,
	SetGlobal = function(_, _, value) characters = value end,
	GetFeatureSettings = function() return lootDB end,
	GetSetting = function(_, category, key, default)
		if settings[category] and settings[category][key] ~= nil then return settings[category][key] end
		return default
	end,
	SetSetting = function(_, category, key, value)
		settings[category] = settings[category] or {}
		settings[category][key] = value
	end,
}
InfinityDataManager = { UpdateSourceData = function() end }
InfinityMessaging = { Publish = function() end }
InfinityCore = { GetDatabase = function() return dkpDB end }
INFINITY_FEATURES = { LOOT = "loot" }
INFINITY_EVENTS = { FEATURE_ENABLED = "enabled" }
UnitName = function() return currentName end
GetRealmName = function() return currentRealm end
UnitLevel = function() return currentLevel end
UnitClass = function() return "Mage", "MAGE" end
UnitRace = function() return "Human" end
GetTime = function() return 10 end
time = function() return 100000 end
IsTestingLua = true
SlashCmdList = {}
InfinityCommandRegistry = {
	RegisterCommand = function(_, name, callback) commands[name] = callback end,
	RegisterKeybind = function() end,
}
CreateFrame = function(_, _, parent)
	local frame = { events = {}, scripts = {} }
	function frame:RegisterEvent(event) self.events[event] = true end
	function frame:UnregisterEvent(event) self.events[event] = nil end
	function frame:SetScript(event, callback) self.scripts[event] = callback end
	function frame:SetPoint() end
	function frame:SetSize(width, height) self.width, self.height = width, height end
	function frame:SetText(text) self.text = text end
	function frame:SetFont() end
	function frame:SetScrollChild(child) self.scrollChild = child end
	function frame:UpdateScrollChildRect() end
	frame.parent = parent
	frames[#frames + 1] = frame
	return frame
end
Enum = { TooltipDataType = { Item = 0 } }
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, callback)
		assert(kind == 0)
		hooks[#hooks + 1] = callback
	end,
}
local originalPrint = print
print = function(message) messages[#messages + 1] = tostring(message) end

dofile("InfinityCore\\Core\\CharacterManager.lua")
InfinityCharacterManager:Initialize()
assert(characters["Alice-Realm"].isMain)
currentName, currentLevel = "Bob", 80
InfinityCharacterManager:Initialize()
assert(not characters["Bob-Realm"].isMain and characters["Bob-Realm"].linkedTo == "Alice")
currentName, currentRealm = "Alice", "Other"
InfinityCharacterManager:Initialize()
assert(not characters["Alice-Other"].isMain)
assert(InfinityCharacterManager:MarkAsMain("Bob-Realm"))
assert(characters["Bob-Realm"].isMain and not characters["Alice-Realm"].isMain)
currentName, currentRealm = "Bob", "Realm"
InfinityCharacterManager:Initialize()
assert(InfinityCharacterManager:GetCurrentCharacter().isMain)

for i = 1, 15 do
	local name = string.format("Extra%02d", i)
	characters[name .. "-Realm"] = { name = name, realm = "Realm", level = 60, class = "MAGE" }
end
INFINITY_COLORS = { PRIMARY = "", RESET = "", SECONDARY = "", WARNING = "", SUCCESS = "", INFO = "" }
local characterButtons = {}
InfinityUIFramework = {
	CreateLabel = function(_, parent, text)
		local label = CreateFrame("FontString", nil, parent)
		label:SetText(text)
		return label
	end,
	CreateButton = function(_, parent, text, _, _, callback)
		local button = CreateFrame("Button", nil, parent)
		button:SetText(text)
		button:SetScript("OnClick", callback)
		characterButtons[#characterButtons + 1] = button
		return button
	end,
}
dofile("InfinityCore\\UI\\MainFrame.lua")
local characterFrame = { contentFrame = CreateFrame("Frame") }
InfinityMainFrame:ShowCharactersTab(characterFrame)
assert(#characterButtons == 17)
local scroll
for _, frame in ipairs(frames) do
	if frame.parent == characterFrame.contentFrame and frame.scrollChild then scroll = frame end
end
assert(scroll and scroll.scrollChild.height == 18 * 22)
InfinityMainFrame.ShowTab = function() end
characterButtons[#characterButtons].scripts.OnClick()
assert(characters["Extra15-Realm"].isMain and not characters["Bob-Realm"].isMain)

dofile("InfinityCore\\UI\\SettingsPanel.lua")
InfinitySettingsPanel:Initialize()
assert(InfinitySettingsPanel:GetSetting("General", "Enable Tooltips") == false)

dofile("InfinityLoot\\Modules\\AdvancedEconomy.lua")
dofile("InfinityLoot\\Modules\\TooltipPrices.lua")
dofile("InfinityLoot\\Init.lua")
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityLoot")
assert(InfinityLootAdvancedEconomy.initialized and commands.loot and #hooks == 1)

dofile("InfinityDKP\\Modules\\TooltipPriceInfo.lua")
InfinityDKPTooltipPriceInfo:Initialize()
assert(#hooks == 2)

local tooltip = { lines = {} }
function tooltip:IsForbidden() return false end
function tooltip:AddLine(line) self.lines[#self.lines + 1] = line end
function tooltip:AddDoubleLine(line) self.lines[#self.lines + 1] = line end
function tooltip:GetItem() return "Item", "|Hitem:123:0|h[Item]|h" end
local function display(data)
	tooltip.lines = {}
	for _, hook in ipairs(hooks) do hook(tooltip, data) end
	return table.concat(tooltip.lines, "\n")
end

assert(display({ id = 123 }) == "")
commands.loot({ "price", "123", "70" })
assert(lootDB.itemPrices[123].basePrice == 70)
assert(display({ id = 123 }) == "")
InfinitySettingsPanel:SetSetting("General", "Enable Tooltips", true)
assert(display({ id = 123 }):find("Local configured price: 70 GP", 1, true))
commands.loot({ "price", "123", "0" })
assert(display({}):find("Local configured price: 0 GP", 1, true))
commands.loot({ "price", "123", "-1" })
assert(lootDB.itemPrices[123].basePrice == 0 and messages[#messages]:find("Usage:", 1, true))
commands.loot({ "price", "123", "100" })
InfinityLootAdvancedEconomy:RecordItemAward(123)
InfinityLootAdvancedEconomy:Initialize()
assert(InfinityLootAdvancedEconomy.itemPrices[123].basePrice == 100)
assert(InfinityLootAdvancedEconomy.itemValues[123].awardCount == 1)
assert(InfinityLootAdvancedEconomy:GetItemValue(123, nil, "Warrior", "Epic") == 150)
assert(InfinityLootAdvancedEconomy:GetItemValue(123, nil, "Warrior", "Epic", "PLATE") == 120)
assert(InfinityLootAdvancedEconomy:ImportData({ itemPrices = { [456] = { basePrice = 25 } } }))
InfinityLootAdvancedEconomy:Initialize()
assert(InfinityLootAdvancedEconomy.itemPrices[456].basePrice == 25)
assert(not InfinityLootAdvancedEconomy:ImportData({ itemPrices = "invalid" }))

dkpDB.economy = { item_prices = { [123] = { gp = 45 } } }
dkpDB.loot_history = {
	{ item_id = 123, gp_cost = 20, timestamp = 99990 },
	{ item_id = 123 },
}
local text = display({ id = 123 })
assert(text:find("Local DKP Information", 1, true))
assert(text:find("Configured GP: 45", 1, true))
assert(text:find("Avg Recorded GP: 20", 1, true))
dkpDB.economy.item_prices[123].gp = 55
assert(display({ id = 123 }):find("Configured GP: 55", 1, true))
InfinityDKPHistory = { awards = {
	{ itemID = 456, points = 40, type = "dkp", time = 99990 },
	{ itemID = 456, points = 20, type = "manual", time = 99995 },
	{ itemID = 456, points = 500, type = "manual", time = 99996, refund = {} },
} }
local actual = display({ id = 456 })
assert(actual:find("Times Awarded (including refunds): 3", 1, true))
assert(actual:find("Avg Recorded DKP: 40", 1, true) and actual:find("Avg Recorded GP: 20", 1, true))
assert(actual:find("Local configured price: 25 GP", 1, true))
assert(display({ id = 999 }) == "")
issecretvalue = function(value) return value == "secret" end
tooltip.GetItem = function() return "Item", "secret" end
assert(display({ id = "secret", hyperlink = "secret" }) == "")
assert(display("secret") == "")
tooltip.GetItem = function() error("blocked") end
local warningCount = #warnings
assert(display({ hyperlink = "|Hitem:456|h[Test]|h" }):find("Avg Recorded DKP: 40", 1, true))
assert(#warnings == warningCount + 2)
display({ hyperlink = "|Hitem:456|h[Test]|h" })
assert(#warnings == warningCount + 2)
InfinityTooltipPrices.hooked = false
local processor = TooltipDataProcessor
TooltipDataProcessor = nil
InfinityTooltipPrices:Initialize()
assert(not InfinityTooltipPrices.hooked and warnings[#warnings]:find("hooks unavailable", 1, true))
TooltipDataProcessor = processor
InfinityTooltipPrices:Initialize()
assert(InfinityTooltipPrices.hooked)

print = originalPrint
print("character_tooltips: all tests passed")
