local frames, commands, logs, warnings = {}, {}, {}, {}
local secret = {}
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:UnregisterEvent(event) self.events[event] = nil end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return self.text end
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
issecretvalue = function(value) return value == secret end
UnitGUID = function() return "Player-1" end
UnitName = function() return "Alice" end
GetRealmName = function() return "Realm" end
time = function() return 100000 end
InfinityCore, InfinityDataManager = {}, {}
local featureSettings = {}
InfinityStorageManager = {
	GetFeatureSetting = function(_, feature, key, default)
		return featureSettings[feature] and featureSettings[feature][key] or default
	end,
	SetFeatureSetting = function(_, feature, key, value)
		featureSettings[feature] = featureSettings[feature] or {}
		featureSettings[feature][key] = value
	end,
}
InfinityMessaging = { Publish = function() end }
InfinityCommandRegistry = { RegisterCommand = function(_, name, callback) commands[name] = callback end }
INFINITY_EVENTS = { FEATURE_ENABLED = "enabled" }
dofile("InfinityCore\\Core\\Utilities.lua")
InfinityUtils.Info = function(_, message) logs[#logs + 1] = message end
InfinityUtils.Warning = function(_, message) warnings[#warnings + 1] = message end
InfinityUtils.Error = function(_, message) error(message) end
dofile("InfinityCore\\UI\\UIFramework.lua")

NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4, 5
local slots = { [0] = 3, [1] = 1, [5] = 1 }
local bags = {
	[0] = {
		[1] = { id = 100, count = 2, price = 25 },
		[3] = { id = 200, count = 1 },
	},
	[5] = { [1] = { id = 100, count = 3, price = 25 } },
}
local protected = false
local prices = { [100] = 25 }
C_Container = {
	GetContainerNumSlots = function(bag) return slots[bag] or 0 end,
	GetContainerItemID = function(bag, slot)
		if protected and bag == 0 and slot == 1 then return secret end
		local item = bags[bag] and bags[bag][slot]
		return item and item.id
	end,
	GetContainerItemInfo = function(bag, slot)
		local item = bags[bag] and bags[bag][slot]
		return item and { iconFileID = 1, stackCount = item.count }
	end,
	GetContainerItemLink = function(bag, slot)
		local item = bags[bag] and bags[bag][slot]
		return item and ("|Hitem:" .. item.id .. "|h[Item " .. item.id .. "]|h")
	end,
}
C_Item = { GetItemInfo = function(id) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, prices[id] end }
local bagsOpened = 0
ToggleAllBags = function() bagsOpened = bagsOpened + 1 end
GameTooltip = { SetOwner = function() end, SetHyperlink = function(self, link) self.link = link end, Show = function() end, Hide = function() end }

dofile("InfinityInventory\\Modules\\BagTracker.lua")
dofile("InfinityInventory\\Modules\\ItemTracking.lua")
dofile("InfinityInventory\\Modules\\CraftingIntegration.lua")
dofile("InfinityInventory\\Modules\\VendorPricing.lua")
dofile("InfinityInventory\\Modules\\AuctionPrices.lua")
dofile("InfinityInventory\\Modules\\ShoppingLists.lua")
dofile("InfinityInventory\\UI\\InventoryUI.lua")
dofile("InfinityInventory\\Init.lua")
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityInventory")
local tracker, ui = InfinityBagTracker, InfinityInventoryUI
assert(tracker.eventFrame.events.BAG_UPDATE_DELAYED)
assert(tracker:GetItemCount(100) == 5 and tracker:GetItemCount(200) == 1)
assert(tracker:GetFreeSlots() == 2)
slots[0] = 0
assert(not tracker:ScanBags() and tracker:GetItemCount(100) == nil)
assert(warnings[#warnings]:find("Backpack slots", 1, true))
slots[0] = 3
assert(tracker:ScanBags() and tracker:GetItemCount(100) == 5)
commands.inv({})
assert(ui.mainFrame:IsShown() and #ui.mainFrame.cells == 5)
assert(ui.mainFrame.status.text:find("1s 25c", 1, true))
assert(ui.mainFrame.status.text:find("1 prices unknown", 1, true))
InfinityCraftingIntegration:RegisterRecipe(1, 1, "Example", { [100] = 4 })
assert(InfinityCraftingIntegration:CanCraftRecipe(1, 1))
local firstCell = ui.mainFrame.cells[1]
firstCell.scripts.OnEnter(firstCell)
assert(GameTooltip.link:find("item:100", 1, true))
prices[200] = 30
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "GET_ITEM_INFO_RECEIVED")
assert(ui.mainFrame.status.text:find("1s 55c", 1, true))
assert(not ui.mainFrame.status.text:find("unknown", 1, true))
bags[0][1] = nil
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "BAG_UPDATE_DELAYED")
assert(tracker:GetItemCount(100) == 3 and tracker:GetFreeSlots() == 3)
assert(ui.mainFrame.cells[1] == firstCell and not ui.mainFrame.cells[1].data.item)
commands.inv({"free"})
assert(logs[#logs]:find("3", 1, true))
commands.inv({"item", "100"})
assert(logs[#logs]:find("3", 1, true))
commands.inv({"value"})
assert(logs[#logs]:find("1s 5c", 1, true))
commands.inv({ "crafters" })
assert(warnings[#warnings]:find("InfinityDataCollector", 1, true))
local craftersOpened = false
InfinityGuildRecipes = { Toggle = function() craftersOpened = true end }
commands.inv({ "crafters" })
assert(craftersOpened)
InfinityGuildRecipes = nil
commands.inv({ "stock" })
assert(warnings[#warnings]:find("InfinityDataCollector", 1, true))
local stockOpened = false
local stockID
InfinityGuildBagReports = { Toggle = function() stockOpened = true end,
	OpenItem = function(_, id) stockID = id end }
local stockButton
for _, frame in ipairs(frames) do if frame.parent == ui.mainFrame and frame.text == "Guild Stock" then stockButton = frame end end
assert(stockButton)
stockButton.scripts.OnClick()
assert(stockOpened)
stockOpened = false
commands.inv({ "stock" })
assert(stockOpened)
commands.inv({ "stock", "100" })
assert(stockID == 100)
InfinityGuildBagReports = nil
assert(featureSettings.InfinityInventory.inventories["Player-1"].bags.contents[5][1].quantity == 3)
local picked, used
C_Container.PickupContainerItem = function(bag, slot) picked = { bag, slot } end
C_Container.UseContainerItem = function(bag, slot) used = { bag, slot } end
ui.mainFrame.cells[1].scripts.OnClick(ui.mainFrame.cells[1], "LeftButton")
assert(picked[1] == 0 and picked[2] == 1)
ui.mainFrame.cells[3].scripts.OnClick(ui.mainFrame.cells[3], "LeftButton")
assert(picked[1] == 0 and picked[2] == 3)
ui.mainFrame.cells[3].scripts.OnClick(ui.mainFrame.cells[3], "RightButton")
assert(used[1] == 0 and used[2] == 3)
IsShiftKeyDown = function() return true end
local shiftedPick = picked
ui.mainFrame.cells[3].scripts.OnClick(ui.mainFrame.cells[3], "LeftButton")
assert(picked == shiftedPick and warnings[#warnings]:find("split stacks", 1, true))
IsShiftKeyDown = nil
C_Container.UseContainerItem = nil
local beforeMissingAction = picked
ui.mainFrame.cells[3].scripts.OnClick(ui.mainFrame.cells[3], "RightButton")
assert(picked == beforeMissingAction and warnings[#warnings]:find("action unavailable", 1, true))
C_Container.UseContainerItem = function(bag, slot) used = { bag, slot } end
local oldPick = picked
bags[0][3] = { id = 300, count = 1 }
ui.mainFrame.cells[3].scripts.OnClick(ui.mainFrame.cells[3], "LeftButton")
assert(picked == oldPick and warnings[#warnings]:find("slot changed", 1, true))
bags[0][3] = { id = 200, count = 1 }
tracker:ScanBags()
ui:Refresh()
ui.mainFrame.search:SetText("100")
ui.mainFrame.search.scripts.OnTextChanged()
assert(ui.mainFrame.cells[1].data.item.itemId == 100 and not ui.mainFrame.cells[2]:IsShown())
local itemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
	if id == 100 then return "Magic Potion" end
	return itemInfo(id)
end
ui.mainFrame.search:SetText("magic")
ui.mainFrame.search.scripts.OnTextChanged()
assert(ui.mainFrame.cells[1].data.item.itemId == 100 and not ui.mainFrame.cells[2]:IsShown())
C_Item.GetItemInfo = itemInfo
ui.mainFrame.search:SetText("")
ui.mainFrame.search.scripts.OnTextChanged()

Enum = { BankType = { Character = 1 } }
C_Bank = { FetchPurchasedBankTabIDs = function() return { 101 } end }
slots[101], bags[101] = 2, { [1] = { id = 400, count = 5 } }
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "BANKFRAME_OPENED")
assert(tracker.bankOpen and tracker.bankContents[101][1].itemId == 400)
assert(featureSettings.InfinityInventory.inventories["Player-1"].bank.contents[101][1].quantity == 5)
featureSettings.InfinityInventory.inventories["Player-2"] = {
	name = "Alt-Realm", bags = { observed = 99999, sizes = { [0] = 1 },
		contents = { [0] = { [1] = { itemId = 500, quantity = 2 } } } },
}
ui:ShowSources()
local sharingButton, sharingOpened, sharingTab
for _, frame in ipairs(frames) do
	if frame.parent == ui.sourceWindow and frame.text == "Guild sharing" then sharingButton = frame end
end
assert(sharingButton)
sharingButton.scripts.OnClick()
assert(warnings[#warnings]:find("require Infinity Data Collector", 1, true))
InfinityDataCollectorUI = { Show = function() sharingOpened = true end,
	ShowTab = function(_, tab) sharingTab = tab end }
sharingButton.scripts.OnClick()
assert(sharingOpened and sharingTab == "settings")
InfinityDataCollectorUI = nil
ui.sourceSearch:SetText("alt")
ui.sourceSearch.scripts.OnTextChanged()
assert(ui.sourceWindow.rows[1].data.text:find("Alt%-Realm") and not ui.sourceWindow.rows[2]:IsShown())
ui.sourceWindow.rows[1].scripts.OnClick(ui.sourceWindow.rows[1])
local altWindow = ui.inventoryWindows["bags:Player-2"]
assert(altWindow:IsShown() and altWindow.cells[1].data.item.itemId == 500)
altWindow.cells[1].scripts.OnClick(altWindow.cells[1], "LeftButton")
assert(picked == oldPick and altWindow.status.text:find("read%-only"))
ui.sourceSearch:SetText("alice")
ui.sourceSearch.scripts.OnTextChanged()
ui.sourceWindow.rows[1].scripts.OnClick(ui.sourceWindow.rows[1])
local bankWindow = ui.inventoryWindows["bank:Player-1"]
assert(bankWindow:IsShown() and bankWindow.cells[1].data.item.itemId == 400)
bankWindow:Hide()
assert(ui:OpenCurrentBank() and bankWindow:IsShown())
bankWindow.cells[1].scripts.OnClick(bankWindow.cells[1], "LeftButton")
assert(picked[1] == 101 and picked[2] == 1)
local savedBank = featureSettings.InfinityInventory.inventories["Player-1"].bank
slots[101] = 0
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "PLAYERBANKSLOTS_CHANGED")
assert(featureSettings.InfinityInventory.inventories["Player-1"].bank == savedBank)
assert(bankWindow.status.text:find("not yet available", 1, true))
slots[101] = 2
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "BANKFRAME_CLOSED")
assert(not tracker.bankOpen and bankWindow.status.text:find("read%-only"))
local bankPick = picked
bankWindow.cells[1].scripts.OnClick(bankWindow.cells[1], "LeftButton")
assert(picked == bankPick)
bags[101][1] = nil
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "BANKFRAME_OPENED")
assert(tracker.bankError:find("appears empty", 1, true))
assert(featureSettings.InfinityInventory.inventories["Player-1"].bank == savedBank)
local savedContents = savedBank.contents
savedBank.contents = secret
assert(not tracker:ScanBank() and tracker.bankError:find("Saved bank contents unavailable", 1, true))
savedBank.contents = savedContents
local refreshBank
for _, frame in ipairs(frames) do
	if frame.parent == bankWindow and frame.text == "Refresh bank" then refreshBank = frame end
end
assert(refreshBank)
refreshBank.scripts.OnClick()
assert(not tracker.bankError and not featureSettings.InfinityInventory.inventories["Player-1"].bank.contents[101][1])
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "BANKFRAME_CLOSED")
InfinityGuildBagReports = { GetInventories = function()
	return { ["bob-realm"] = { name = "Bob-Realm", items = { { itemId = 600, quantity = 9 } } } }
end }
ui:RefreshSources()
ui.sourceSearch:SetText("bob")
ui.sourceSearch.scripts.OnTextChanged()
ui.sourceWindow.rows[1].scripts.OnClick(ui.sourceWindow.rows[1])
local guildWindow = ui.inventoryWindows["guild:bob-realm"]
assert(guildWindow.cells[1].data.item.itemId == 600 and guildWindow.status.text:find("incomplete", 1, true))
guildWindow:Hide()
assert(ui:OpenGuildMember("Bob") and guildWindow:IsShown())
assert(ui:OpenGuildMember("BOB-Realm"))
assert(not ui:OpenGuildMember("Bob-Other") and warnings[#warnings]:find("No shared", 1, true))
assert(not ui:OpenGuildMember(secret) and warnings[#warnings]:find("name unavailable", 1, true))
guildWindow.cells[1].scripts.OnClick(guildWindow.cells[1], "LeftButton")
assert(picked == bankPick)
InfinityGuildBagReports = nil
commands.inv({"item", "invalid"})
assert(warnings[#warnings]:find("Usage", 1, true))
local pricesUI = InfinityAuctionPrices
commands.inv({ "price", "100" })
assert(warnings[#warnings]:find("Open the auction house", 1, true))
assert(pricesUI.window:IsShown() and not pricesUI.pending)
local sent, loaded, ready, cached, full = {}, {}, false, false, false
local commodityResults, itemResults = {}, {}
C_Item.RequestLoadItemDataByID = function(id) loaded[#loaded + 1] = id end
C_AuctionHouse = {
	MakeItemKey = function(id) return { itemID = id, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 } end,
	GetItemKeyInfo = function() if cached then return { itemName = "Item" } end end,
	IsThrottledMessageSystemReady = function() return ready end,
	SendSearchQuery = function(key, sorts, split) sent[#sent + 1] = key; assert(#sorts == 0 and split) end,
	HasSearchResults = function() return true end,
	HasFullCommoditySearchResults = function() return full end,
	HasFullItemSearchResults = function() return full end,
	GetNumCommoditySearchResults = function() return #commodityResults end,
	GetCommoditySearchResultInfo = function(_, index) return commodityResults[index] end,
	GetNumItemSearchResults = function() return #itemResults end,
	GetItemSearchResultInfo = function(_, index) return itemResults[index] end,
}
local auctionEvent = function(event, ...)
	pricesUI.events.scripts.OnEvent(pricesUI.events, event, ...)
end
auctionEvent("AUCTION_HOUSE_SHOW")
commands.inv({ "price", "100" })
assert(#sent == 0 and warnings[#warnings]:find("throttled", 1, true))
ready = true
commands.inv({ "price", "100" })
assert(#sent == 0 and loaded[1] == 100 and warnings[#warnings]:find("not loaded", 1, true))
cached = true
commands.inv({ "price", "100" })
assert(#sent == 1 and pricesUI.pending and sent[1].itemID == 100)
commands.inv({ "price", "200" })
assert(#sent == 1 and warnings[#warnings]:find("pending", 1, true))
assert(pricesUI.input.text == "100")
commodityResults = {
	{ quantity = 10, unitPrice = 120 },
	{ quantity = 3, unitPrice = 90 },
	{ quantity = secret, unitPrice = 10 },
}
auctionEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 200)
assert(pricesUI.pending and pricesUI.status:find("Searching", 1, true))
auctionEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 100)
assert(pricesUI.pending and pricesUI.status:find("Partial", 1, true))
assert(pricesUI.status:find("1 unavailable", 1, true))
assert(pricesUI.window.rows[1].data.text:find("3 available | 90c each", 1, true))
full = true
auctionEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 100)
assert(not pricesUI.pending and pricesUI.status:find("Complete", 1, true))
full = false
assert(pricesUI:Search(200))
local wrongKey = { itemID = 200, itemLevel = 1, itemSuffix = 0, battlePetSpeciesID = 0 }
auctionEvent("ITEM_SEARCH_RESULTS_UPDATED", wrongKey)
assert(pricesUI.pending and pricesUI.status:find("Searching", 1, true))
itemResults = {
	{ quantity = 3, buyoutAmount = 100, itemLink = "|Hitem:200|h[Test]|h" },
	{ quantity = 2, buyoutAmount = 40 },
	{ quantity = 1, bidAmount = 10 },
}
full = true
auctionEvent("ITEM_SEARCH_RESULTS_UPDATED", sent[#sent])
assert(not pricesUI.pending and pricesUI.window.rows[1].data.text:find("20c each", 1, true))
assert(pricesUI.window.rows[2].data.text:find("~33c each", 1, true))
assert(pricesUI.window.rows[2].data.link and pricesUI.window.rows[3].data.text:find("no buyout", 1, true))
assert(pricesUI:Search(100))
auctionEvent("AUCTION_HOUSE_CLOSED")
assert(not pricesUI.pending and pricesUI.status:find("no longer current", 1, true))
auctionEvent("AUCTION_HOUSE_SHOW")
assert(pricesUI:Search(100))
pricesUI.events.scripts.OnUpdate(pricesUI.events, 15)
assert(not pricesUI.pending and pricesUI.status:find("timed out", 1, true))
assert(pricesUI:Search(100))
full, commodityResults = true, {}
auctionEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 100)
assert(not pricesUI.pending and pricesUI.window.rows[1].data.text:find("No results", 1, true))
assert(pricesUI:Search(100))
C_AuctionHouse.GetNumCommoditySearchResults = nil
auctionEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 100)
assert(not pricesUI.pending and warnings[#warnings]:find("API unavailable", 1, true))
C_AuctionHouse.SendSearchQuery = function() return false end
assert(not pricesUI:Search(100) and not pricesUI.pending and warnings[#warnings]:find("rejected", 1, true))
C_AuctionHouse.SendSearchQuery = function() error("send failed") end
assert(not pricesUI:Search(100) and not pricesUI.pending and warnings[#warnings]:find("send failed", 1, true))
auctionEvent("AUCTION_HOUSE_CLOSED")
commands.inv({ "list" })
local shopping = InfinityShoppingLists
assert(shopping.window:IsShown() and shopping.window.rows[1].data.text:find("No shopping lists", 1, true))
shopping.nameInput:SetText("Raid supplies")
local shoppingButtons = {}
for _, frame in ipairs(frames) do
	if frame.parent == shopping.window and frame.scripts.OnClick and frame.text then shoppingButtons[frame.text] = frame end
end
shoppingButtons.New.scripts.OnClick()
assert(shopping.active == "shopping_1" and featureSettings.InfinityInventory.shoppingLists.lists.shopping_1)
shopping.itemInput:SetText("100")
shopping.quantityInput:SetText("20")
shoppingButtons.Set.scripts.OnClick()
assert(shopping.lists.shopping_1.steps[1].itemID == 100 and shopping.lists.shopping_1.steps[1].description == "20")
shopping.quantityInput:SetText("30")
shoppingButtons.Set.scripts.OnClick()
assert(#shopping.lists.shopping_1.steps == 1 and shopping.lists.shopping_1.steps[1].description == "30")
shoppingButtons.Lists.scripts.OnClick()
shopping.window.rows[1].scripts.OnClick(shopping.window.rows[1])
assert(shopping.active == "shopping_1" and shopping.window.rows[1].data.text:find("Quantity: 30", 1, true))
shoppingButtons.Share.scripts.OnClick()
assert(warnings[#warnings]:find("requires InfinityGuide", 1, true))
shoppingButtons.Remove.scripts.OnClick()
assert(#shopping.lists.shopping_1.steps == 0)
commands.inv({ "list", "set", "200", "5" })
commands.inv({ "list", "use", "none" })
assert(not shopping.active and featureSettings.InfinityInventory.shoppingLists.active == nil)
commands.inv({ "list", "use", "shopping_1" })
assert(shopping.active == "shopping_1" and shopping.lists.shopping_1.steps[1].itemID == 200)
commands.inv({ "list", "set", "200", "0" })
assert(shopping.lists.shopping_1.steps[1].description == "5")
shoppingButtons.Delete.scripts.OnClick()
assert(shopping.lists.shopping_1 and shopping.window.status.text:find("again to confirm", 1, true))
shoppingButtons.Delete.scripts.OnClick()
assert(not shopping.active and not shopping.lists.shopping_1)
Enum = { CraftingReagentType = { Basic = 0, Optional = 1 } }
local schematic = { reagentSlotSchematics = {
	{ reagentType = 0, quantityRequired = 2, reagents = { { itemID = 100 } } },
	{ reagentType = 0, quantityRequired = 1, reagents = { { itemID = 100 } } },
	{ reagentType = 0, quantityRequired = 2, reagents = { { itemID = 200 } } },
	{ reagentType = 1, quantityRequired = 1, reagents = { { itemID = 300 } } },
} }
C_TradeSkillUI = { GetRecipeSchematic = function(id, recraft) assert(id == 42 and not recraft); return schematic end }
local recipeButton
for _, frame in ipairs(frames) do if frame.parent == ui.mainFrame and frame.text == "Reagents" then recipeButton = frame end end
assert(recipeButton)
recipeButton.scripts.OnClick()
ui.recipeID:SetText("42")
ui.recipeQuantity:SetText("2")
ui.recipeSearch.scripts.OnClick()
assert(ui.recipeWindow.rows[1].data.text:find("Item 100: 3 / 6 | missing 3", 1, true))
ui.recipeWindow.rows[1].scripts.OnEnter(ui.recipeWindow.rows[1])
assert(GameTooltip.link == "item:100")
ProfessionsFrame = { IsShown = function() return true end,
	CraftingPage = { SchematicForm = { GetRecipeInfo = function() return { recipeID = 42 } end } } }
ui:ShowRecipe()
assert(ui.recipeID:GetText() == "42" and ui.recipeQuantity:GetText() == "1")
assert(ui.recipeWindow.rows[1].data.text:find("Item 100: 3 / 3 | missing 0", 1, true))
ProfessionsFrame.CraftingPage.SchematicForm.GetRecipeInfo = function() return { recipeID = secret } end
ui:ShowRecipe()
assert(warnings[#warnings]:find("protected", 1, true))
ProfessionsFrame = nil
ui.recipeQuantity:SetText("bad")
ui.recipeSearch.scripts.OnClick()
assert(warnings[#warnings]:find("recipe ID and quantity", 1, true) and not ui.recipeWindow.rows[1]:IsShown())
local output, originalPrint = {}, print
print = function(message) output[#output + 1] = message end
commands.inv({"recipe", "42", "2"})
assert(output[1]:find("bank", 1, true))
assert(output[2]:find("Item 100: 3 / 6, missing 3", 1, true))
assert(output[3]:find("Item 200: 1 / 4, missing 3", 1, true))
commands.inv({"recipe", "42", "invalid"})
assert(output[#output]:find("Usage", 1, true))
schematic.reagentSlotSchematics[1].reagents[2] = { itemID = 101 }
commands.inv({"recipe", "42"})
assert(warnings[#warnings]:find("choices", 1, true))
schematic.reagentSlotSchematics[1].reagents[2] = nil
schematic.reagentSlotSchematics[1].quantityRequired = secret
commands.inv({"recipe", "42"})
assert(warnings[#warnings]:find("unavailable", 1, true))
schematic.reagentSlotSchematics[1].quantityRequired = 2
commands.inv({"recipe", "42", "0"})
assert(warnings[#warnings]:find("positive integers", 1, true))
local getSchematic = C_TradeSkillUI.GetRecipeSchematic
C_TradeSkillUI.GetRecipeSchematic = function() return nil end
commands.inv({"recipe", "42"})
assert(warnings[#warnings]:find("open its profession", 1, true))
C_TradeSkillUI.GetRecipeSchematic = getSchematic
C_TradeSkillUI = nil
commands.inv({"recipe", "42"})
assert(warnings[#warnings]:find("API unavailable", 1, true))
print = originalPrint
local button
for _, frame in ipairs(frames) do
	if frame.text == "Game Bags" then button = frame end
end
assert(button)
button.scripts.OnClick(button)
assert(bagsOpened == 1)

protected = true
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "BAG_UPDATE_DELAYED")
assert(tracker:GetFreeSlots() == nil and tracker:GetItemCount(100) == nil)
assert(InfinityVendorPricing:CalculateVendorValue() == nil)
assert(InfinityCraftingIntegration:CanCraftRecipe(1, 1) == nil)
assert(ui.mainFrame.status.text:find("protected", 1, true))
assert(not ui.mainFrame.cells[1]:IsShown())
protected = false
tracker.eventFrame.scripts.OnEvent(tracker.eventFrame, "BAG_UPDATE_DELAYED")
assert(tracker:GetFreeSlots() == 3 and ui.mainFrame.cells[1]:IsShown())
C_Container.GetContainerItemID = nil
assert(not tracker:ScanBags() and tracker.scanError == "Bag API unavailable.")
local unavailableMessage
originalPrint = print
print = function(message) unavailableMessage = message end
commands.inv({"free"})
assert(unavailableMessage:find("Bag API unavailable", 1, true))
print = originalPrint
C_Container = nil
GetContainerNumSlots = function(bag) return slots[bag] or 0 end
GetContainerItemID = function(bag, slot) local item = bags[bag] and bags[bag][slot]; return item and item.id end
GetContainerItemInfo = function(bag, slot)
	local item = bags[bag] and bags[bag][slot]
	if item then return 1, item.count end
end
assert(tracker:ScanBags() and tracker:GetItemCount(100) == 3 and tracker:GetFreeSlots() == 3)
local savedInventories = featureSettings.InfinityInventory.inventories
UnitGUID = function() return "Player-3" end
UnitName = function() return "Third" end
RegionalUniqueNamesEnabled = function() return true end
UnitNameUnmodified = function() return "Third", "Surname" end
local reloadedTracker = dofile("InfinityInventory\\Modules\\BagTracker.lua")
reloadedTracker:Initialize()
assert(reloadedTracker.snapshots == savedInventories and savedInventories["Player-2"].bags.contents[0][1].itemId == 500)
assert(savedInventories["Player-3"].bags.contents[5][1].itemId == 100)
assert(savedInventories["Player-3"].name == "Third Surname-Realm")
print("inventory_runtime: all tests passed")
