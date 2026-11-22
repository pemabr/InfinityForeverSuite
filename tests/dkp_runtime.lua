local frames, commands, db, warnings, timers = {}, {}, {}, {}, {}
local now, secret = 100, {}
local bobPresent = true
local widget = {}
function widget:RegisterEvent(event) self.events[event] = true end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return self.text or "" end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name, parent)
	if name then assert(_G[name] == nil, "duplicate named frame: " .. name) end
	local frame = setmetatable({ events = {}, scripts = {}, parent = parent, shown = true }, meta)
	if name then _G[name] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
InfinityCore = {
	GetDatabase = function(_, name) assert(name == "InfinityDKP"); return db end,
	RegisterAddon = function() end,
	RegisterCommand = function(_, command, _, callback) commands[command] = callback end,
}
InfinityMessaging = { Subscribe = function() end }
InfinityUtils = {
	Warning = function(_, message) warnings[#warnings + 1] = message end,
	Info = function() end,
}
GetTime = function() return now end
time = function() return 100000 + now end
date = os.date
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
issecretvalue = function(value) return value == secret end
UnitName = function(unit) if unit == "player" then return "Alice" elseif bobPresent then return "Bob" end end
UnitClass = function() return "Mage", "MAGE" end
GetNumGroupMembers = function() return 2 end
IsInRaid = function() return false end

dofile("InfinityDKP\\Core\\DKPEngine.lua")
dofile("InfinityDKP\\Core\\AttendanceTracker.lua")
local InfinityAttendanceTracker = InfinityDKPAttendanceTracker
dofile("InfinityAttendance\\Modules\\Tracker.lua")
assert(_G.InfinityAttendanceTracker ~= InfinityAttendanceTracker)
dofile("InfinityDKP\\Modules\\Points.lua")
dofile("InfinityDKP\\Modules\\History.lua")
dofile("InfinityDKP\\Modules\\Reports.lua")
dofile("InfinityDKP\\Modules\\GuildSync.lua")
dofile("InfinityDKP\\Modules\\GuildAuctions.lua")
dofile("InfinityDKP\\Modules\\TaxSystem.lua")
dofile("InfinityDKP\\Modules\\GuildBankDonations.lua")
dofile("InfinityDKP\\Modules\\BossKillAwards.lua")
dofile("InfinityDKP\\Modules\\UnifiedAuctions.lua")
dofile("InfinityDKP\\Modules\\PlayerTrading.lua")
dofile("InfinityDKP\\UI\\Main.lua")
dofile("InfinityDKP\\Init.lua")
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityDKP")
local events
for _, frame in ipairs(frames) do
	if frame.events.ENCOUNTER_START and frame.events.GROUP_ROSTER_UPDATE then events = frame end
end
assert(events and InfinityDKPEngine.players == db.players)
assert(InfinityDKPTaxSystem.saved == db.taxSystem and InfinityDKPGuildBankDonations.saved == db.donationSystem)
assert(InfinityBossKillAwards.localConfig == db.localBossAwards and not db.localBossAwards.enabled)
assert(InfinityDKPEngine:AddPlayer("Alice", "MAGE", 1))
assert(InfinityDKPEngine:AwardEP("Alice", 100, "test"))
assert(InfinityDKPEngine:AwardGP("Alice", 20, "item", "test"))
assert(not InfinityDKPEngine:AddPlayer("Alice"))
assert(db.players.Alice.ep == 100 and db.players.Alice.gp == 20)
assert(InfinityDKPEngine:AddPlayer("Bob"))
db.players.Alice.sk_position, db.players.Bob.sk_position = 2, 1
assert(InfinityDKPEngine:SetSystemType("sk"))
assert(InfinityDKPEngine:GetRankedPlayers()[1].name == "Bob")
assert(not InfinityDKPEngine:SetSystemType("invalid") and db.system_type == "sk")

commands["/dkp"]()
assert(InfinityDKPUI.frame:IsShown())
assert(InfinityDKPUI.player_list.text:find("Alice", 1, true))
InfinityDKPUI:Initialize()
local tabs = {}
for _, frame in ipairs(frames) do
	if frame.text and frame.scripts.OnClick then tabs[frame.text] = frame end
end
tabs.Auctions.scripts.OnClick(tabs.Auctions)
assert(InfinityDKPUI.player_list.text:find("No active auctions", 1, true))
tabs.Reports.scripts.OnClick(tabs.Reports)
assert(InfinityDKPUI.player_list.text:find("Total Players: 2", 1, true))
commands["/dkp add"]("Charlie")
local offer = InfinityDKPPlayerTrading.Offer
InfinityDKPPlayerTrading.Offer = function(_, recipient, amount)
	assert(recipient == "Bob" and amount == 3)
end
commands["/dkp trade offer"]("Bob 3")
InfinityDKPPlayerTrading.Offer = offer
local createGuildAuction, guildBid = InfinityDKPGuildAuctions.Create, InfinityDKPGuildAuctions.Bid
InfinityDKPGuildAuctions.Create = function(_, item, bid, duration)
	assert(item == "|Hitem:123|h[Example item]|h" and bid == 10 and duration == 30)
end
InfinityDKPGuildAuctions.Bid = function(_, amount) assert(amount == 11) end
commands["/dkp guildauction create"]("10 30 |Hitem:123|h[Example item]|h")
commands["/dkp guildauction bid"]("11")
InfinityDKPGuildAuctions.Create, InfinityDKPGuildAuctions.Bid = createGuildAuction, guildBid
local getGuildKey = InfinityDKPGuildSync.GetGuildKey
InfinityDKPGuildSync.GetGuildKey = function() return "guild-test" end
InfinityDKPGuildAuctions.auction = { status = "active", guild = "guild-test", itemLink = "|Hitem:123|h[Example item]|h",
	startingBid = 10, highBid = 11, highestBidder = "Bob" }
tabs.Auctions.scripts.OnClick(tabs.Auctions)
assert(InfinityDKPUI.player_list.text:find("Bob", 1, true))
InfinityDKPGuildAuctions.auction = nil
InfinityDKPGuildSync.GetGuildKey = getGuildKey
commands["/dkp ep"]("Charlie 30 attendance")
commands["/dkp gp"]("Charlie 5 item")
assert(db.players.Charlie.ep == 30 and db.players.Charlie.gp == 5)
assert(#db.pointTransactions == 2 and db.pointTransactions[1].reason == "attendance")
commands["/dkp ep"]("Charlie -10 invalid")
commands["/dkp gp"]("Charlie 0 invalid")
commands["/dkp ep"]("Missing 10")
assert(db.players.Charlie.ep == 30 and #db.pointTransactions == 2)
for i = 1, 16 do assert(InfinityDKPEngine:AddPlayer("Player" .. i)) end
tabs.Players.scripts.OnClick(tabs.Players)
assert(InfinityDKPUI.player_list.text:find("Player16", 1, true))
assert(InfinityDKPReports:GeneratePriorityList():find("Player16", 1, true))
commands["/dkp award"]("Charlie 2 Example item")
assert(db.players.Charlie.gp == 7 and db.lootAwards[1].item == "Example item")
InfinityDKPPoints:LogTransaction("Alice", "ep", 1, "other")
InfinityDKPHistory:RecordAward("Alice", "Another item", 2, "manual", 1, "test")
assert(#InfinityDKPPoints:GetHistory("Charlie", 1) == 1)
assert(#InfinityDKPHistory:GetPlayerHistory("Charlie", 1) == 1)
assert(#InfinityDKPHistory:GetItemAwards("Example item", 1) == 1)
assert(#db.lootAwards == 2 and #InfinityDKPHistory:GetRecentAwards(7) == 2)

local originalPrint, messages = print, {}
print = function(message) messages[#messages + 1] = tostring(message) end
tabs.Auctions.scripts.OnClick(tabs.Auctions)
commands["/dkp auction create"]("10 15 |Hitem:123|h[Example Sword]|h")
local auction = InfinityDKPUnifiedAuctions:GetAuctionDetails(1)
assert(auction and auction.itemName == "Example Sword" and auction.startingBid == 10)
assert(InfinityDKPUI.player_list.text:find("[1] Example Sword", 1, true))
commands["/dkp auction bid"]("1 Charlie 10")
assert(auction.highestBidder == "Charlie" and auction.currentHighBid == 10)
local warningsBeforeBids = #warnings
commands["/dkp auction bid"]("1 Bob 10")
commands["/dkp auction bid"]("1 Bob 10.5")
assert(auction.highestBidder == "Charlie" and #warnings == warningsBeforeBids + 2)
commands["/dkp auction bid"]("1 Missing 11")
assert(messages[#messages]:find("Unknown local player", 1, true))
now = 109
commands["/dkp auction bid"]("1 Bob 11")
assert(auction.highestBidder == "Bob" and auction.endTime == 119)
now = 115
table.remove(timers, 1).callback()
assert(auction.status == "active" and timers[1].delay == 4)
now = 119
table.remove(timers, 1).callback()
assert(auction.status == "closed" and auction.winner == "Bob" and auction.winningBid == 11)
assert(messages[#messages]:find("No points were changed", 1, true))
assert(db.players.Bob.gp == 0 and db.players.Charlie.gp == 7 and #db.lootAwards == 2)
assert(InfinityDKPUnifiedAuctions:GetPlayerAuctionStats("Bob").lastWin == date("%Y-%m-%d %H:%M:%S", 100100))
commands["/dkp auction create"]("1 5 Empty item")
local empty = InfinityDKPUnifiedAuctions:GetAuctionDetails(2)
now = 124
commands["/dkp auction bid"]("2 Bob 1")
assert(not empty.highestBidder and warnings[#warnings]:find("ended", 1, true))
table.remove(timers, 1).callback()
assert(empty.status == "closed" and messages[#messages]:find("without bids", 1, true))
commands["/dkp auction create"]("5 30 Another item")
commands["/dkp auction close"]("3")
local historyCount = #InfinityDKPUnifiedAuctions.auctionHistory
now = 154
table.remove(timers, 1).callback()
assert(#InfinityDKPUnifiedAuctions.auctionHistory == historyCount)
commands["/dkp auction create"]("0 10 Invalid")
assert(not InfinityDKPUnifiedAuctions:GetAuctionDetails(4))
commands["/dkp auction create"]("10 15")
assert(messages[#messages]:find("Usage:", 1, true))
commands["/dkp auction create"]("2 20 Cancelled item")
commands["/dkp auction bid"]("4 Charlie 2")
commands["/dkp auction cancel"]("4")
assert(InfinityDKPUnifiedAuctions:GetAuctionDetails(4).status == "cancelled")
assert(messages[#messages]:find("no winner", 1, true))
assert(InfinityDKPUnifiedAuctions:ExportAuctionHistory():find("Cancelled", 1, true))
assert(InfinityDKPUnifiedAuctions:GetGuildAuctionStats().totalAuctions == 3)
local cancelledCount = #InfinityDKPUnifiedAuctions.auctionHistory
now = 180
table.remove(timers, 1).callback()
assert(#InfinityDKPUnifiedAuctions.auctionHistory == cancelledCount and db.players.Charlie.gp == 7)
local savedTimer = C_Timer
C_Timer = nil
commands["/dkp auction create"]("Sword of Testing")
assert(InfinityDKPUnifiedAuctions:GetAuctionDetails(5).itemName == "Sword of Testing")
assert(messages[#messages]:find("timer unavailable", 1, true))
assert(not InfinityDKPUnifiedAuctions:PlaceBid(5, "Bob", secret))
commands["/dkp auction close"]("5")
C_Timer = savedTimer
print, now = originalPrint, 100

events.scripts.OnEvent(events, "GROUP_ROSTER_UPDATE")
assert(#InfinityAttendanceTracker.raids == 0)
events.scripts.OnEvent(events, "ENCOUNTER_START", 5, "Boss", 1, 2)
assert(#InfinityAttendanceTracker.raids == 1)
assert(InfinityAttendanceTracker.raids[1].members.Alice)
assert(InfinityAttendanceTracker.raids[1].members.Bob)
events.scripts.OnEvent(events, "GROUP_ROSTER_UPDATE")
assert(#InfinityAttendanceTracker.attendance_log == 2)
now = 120
events.scripts.OnEvent(events, "ENCOUNTER_END", 5, "Boss", 1, 2, 0)
assert(InfinityAttendanceTracker.raids[1].wipes == 1)
assert(InfinityAttendanceTracker.raids[1].boss_kills == 0)
assert(InfinityAttendanceTracker.raids[1].end_time == 100120)
assert(#InfinityDKPPoints.point_history == 5)
now = 140
events.scripts.OnEvent(events, "ENCOUNTER_END", 5, "Boss", 1, 2, 1)
assert(InfinityAttendanceTracker.raids[1].end_time == 100120)
bobPresent = false
events.scripts.OnEvent(events, "ENCOUNTER_START", 6, "Boss 2", 1, 2)
now = 160
events.scripts.OnEvent(events, "ENCOUNTER_END", 6, "Boss 2", 1, 2, 1)
assert(InfinityAttendanceTracker.raids[2].boss_kills == 1)
assert(InfinityDKPPoints.point_history[#InfinityDKPPoints.point_history].type == "encounter_complete")
assert(InfinityAttendanceTracker:GetAttendanceStats("Alice").percentage == 100)
assert(InfinityAttendanceTracker:GetAttendanceStats("Bob").percentage == 50)
assert(InfinityAttendanceTracker:GetAttendanceStats("Charlie").percentage == 0)

commands["/dkp system"]("dkp")
assert(db.system_type == "dkp")
commands["/dkp points"]("Charlie 25 raid")
commands["/dkp points"]("Bob -5 adjustment")
assert(db.players.Charlie.dkp == 25 and db.players.Bob.dkp == -5)
assert(InfinityDKPEngine:GetRankedPlayers()[1].name == "Charlie")
print = function(message) messages[#messages + 1] = tostring(message) end
commands["/dkp auction create"]("1 30 DKP item")
commands["/dkp auction bid"]("6 Charlie 1")
commands["/dkp auction close"]("6")
assert(messages[#messages]:find("/dkp spend", 1, true) and db.players.Charlie.dkp == 25)
print = originalPrint
tabs.Players.scripts.OnClick(tabs.Players)
assert(InfinityDKPUI.player_list.text:find("DKP", 1, true))
assert(InfinityDKPUI.player_list.text:find("25.00", 1, true))
local transactions, awards = #db.pointTransactions, #db.lootAwards
commands["/dkp points"]("Charlie 0")
commands["/dkp points"]("Charlie 1.5")
commands["/dkp points"]("Missing 1")
commands["/dkp points"]("Charlie 1000000000")
commands["/dkp spend"]("Charlie -10 item")
assert(db.players.Charlie.dkp == 25 and #db.pointTransactions == transactions and #db.lootAwards == awards)
assert(not InfinityDKPEngine:AdjustDKP("Charlie", secret))
db.players.Bob.dkp = secret
assert(not InfinityDKPEngine:AdjustDKP("Bob", 1))
db.players.Bob.dkp = -5
commands["/dkp spend"]("Charlie 30 |Hitem:456|h[Test Item]|h")
assert(db.players.Charlie.dkp == -5 and db.players.Charlie.gp == 7)
assert(db.pointTransactions[#db.pointTransactions].amount == -30)
assert(db.lootAwards[#db.lootAwards].type == "dkp" and db.lootAwards[#db.lootAwards].itemID == 456)
commands["/dkp system"]("zero")
assert(db.system_type == "dkp")
commands["/dkp system"]("epgp")
assert(db.system_type == "epgp" and db.players.Charlie.dkp == -5)
print = function(message) messages[#messages + 1] = tostring(message) end
commands["/dkp auction create"]("1 30 EPGP item")
commands["/dkp auction bid"]("7 Charlie 1")
commands["/dkp auction close"]("7")
assert(messages[#messages]:find("/dkp award", 1, true) and db.players.Charlie.gp == 7)
print = originalPrint
assert(InfinityDKPEngine:SetSystemType("sk"))

dofile("InfinityDKP\\Core\\DKPEngine.lua")
InfinityDKPEngine:Initialize()
assert(InfinityDKPEngine.players.Alice.ep == 100)
assert(InfinityDKPEngine.players.Charlie.dkp == -5)
assert(InfinityDKPEngine.system_type == "sk")
assert(InfinityDKPEngine:GetRankedPlayers()[1].name == "Bob")
dofile("InfinityDKP\\Core\\AttendanceTracker.lua")
InfinityAttendanceTracker = InfinityDKPAttendanceTracker
dofile("InfinityDKP\\Modules\\Points.lua")
dofile("InfinityDKP\\Modules\\History.lua")
InfinityAttendanceTracker:Initialize(db)
InfinityDKPPoints:Initialize(db)
InfinityDKPHistory:Initialize(db)
assert(InfinityAttendanceTracker:GetAttendanceStats("Bob").percentage == 50)
assert(InfinityDKPPoints.point_history[1].reason == "attendance")
assert(#InfinityDKPHistory:GetRecentAwards(7) == 3)
now = now + 8 * 86400
assert(#InfinityDKPHistory:GetRecentAwards(7) == 0)
dofile("InfinityCore\\UI\\UIFramework.lua")
InfinityUtils.Split = function(_, input)
	local result = {}
	for word in input:gmatch("%S+") do result[#result + 1] = word end
	return result
end
InfinityUtils.Error = function(_, message) error(message) end
SlashCmdList = {}
INFINITY_CORE_NAME, INFINITY_SUITE_VERSION = "InfinityCore", "test"
dofile("InfinityCore\\Core\\CommandRegistry.lua")
dofile("InfinityCore\\Init.lua")
local coreLoader = frames[#frames]
coreLoader.scripts.OnEvent(coreLoader, "ADDON_LOADED", "InfinityCore")
for command, callback in pairs(commands) do InfinityCore:RegisterCommand(command, "Test route", callback) end
local ui = InfinityDKPUI
ui:ShowActions()
local function ClickAction(prefix)
	for _, row in ipairs(ui.actionsWindow.rows) do
		if row:IsShown() and row.data.text:find(prefix, 1, true) == 1 then
			row.scripts.OnClick(row)
			return
		end
	end
	error("Missing DKP action: " .. prefix)
end
ClickAction("Open live guild bank log")
assert(ui.bankLogWindow:IsShown() and ui.bankLogWindow.rows[1].data.text:find("Open the guild bank", 1, true))
ui.bankLogMoneyButton.scripts.OnClick()
assert(warnings[#warnings]:find("Open the guild bank", 1, true))
local queried
MAX_GUILDBANK_TABS = 8
GetNumGuildBankTabs = function() return 2 end
QueryGuildBankLog = function(tab) queried = tab end
GetNumGuildBankMoneyTransactions = function() return 2 end
GetGuildBankMoneyTransaction = function(index)
	if index == 1 then return "deposit", "Alice", 12345, 0, 0, 1, 2 end
	return "withdraw", secret, 500, 0, 0, 0, 1
end
GetNumGuildBankTransactions = function(tab) assert(tab == 2); return 1 end
GetGuildBankTransaction = function(tab, index)
	assert(tab == 2 and index == 1)
	return "deposit", "Bob", "|Hitem:123|h[Test item]|h", 3, nil, nil, 0, 0, 0, 2
end
events.scripts.OnEvent(events, "GUILDBANKFRAME_OPENED")
ui.bankLogMoneyButton.scripts.OnClick()
assert(queried == 9 and ui.bankLogWindow.rows[1].data.text:find("Waiting", 1, true))
events.scripts.OnEvent(events, "GUILDBANKLOG_UPDATE")
assert(ui.bankLogWindow.rows[1].data.text:find("12345 copper", 1, true))
assert(ui.bankLogWindow.status.text:find("Unreadable: 1", 1, true))
ui.bankLogInput:SetText("3")
ui.bankLogItemButton.scripts.OnClick()
assert(queried == 9 and warnings[#warnings]:find("available guild bank tab", 1, true))
ui.bankLogInput:SetText("2")
ui.bankLogItemButton.scripts.OnClick()
assert(queried == 2)
events.scripts.OnEvent(events, "GUILDBANKLOG_UPDATE")
assert(ui.bankLogWindow.rows[1].data.link == "|Hitem:123|h[Test item]|h")
ui.bankLogInput:SetText(secret)
ui.bankLogItemButton.scripts.OnClick()
assert(warnings[#warnings]:find("Protected bank tab", 1, true))
GetNumGuildBankTransactions = function() return secret end
events.scripts.OnEvent(events, "GUILDBANKLOG_UPDATE")
assert(ui.bankLogWindow.rows[1].data.text:find("protected", 1, true))
GetNumGuildBankTransactions = function() error("bank read blocked") end
events.scripts.OnEvent(events, "GUILDBANKLOG_UPDATE")
assert(warnings[#warnings]:find("bank read blocked", 1, true))
QueryGuildBankLog = function() error("bank request blocked") end
ui.bankLogMoneyButton.scripts.OnClick()
assert(warnings[#warnings]:find("bank request blocked", 1, true))
events.scripts.OnEvent(events, "GUILDBANKFRAME_CLOSED")
assert(ui.bankLogWindow.rows[1].data.text:find("Open the guild bank", 1, true))
ClickAction("Open copyable DKP reports")
assert(ui.reportWindow:IsShown() and ui.reportText:GetText():find("Total Players", 1, true))
ui.reportButtons.loot.scripts.OnClick()
assert(ui.reportText:GetText():find("Loot Report", 1, true))
ui.reportButtons.priority.scripts.OnClick()
assert(ui.reportText:GetText():find("Priority", 1, true))
dofile("InfinityDKP\\Modules\\TaxSystem.lua")
dofile("InfinityDKP\\Modules\\GuildBankDonations.lua")
local guildRank, leader = 0, false
GetGuildInfo = function() return "Test Guild", "Rank", guildRank end
IsGuildLeader = function() return leader end
InfinityDKPTaxSystem:Initialize(db)
InfinityDKPGuildBankDonations:Initialize(db)
assert(InfinityDKPTaxSystem:IsAdminOnly() and InfinityDKPGuildBankDonations:IsAdminOnly())
assert(InfinityDKPTaxSystem:SetWhitelistMode(true) and InfinityDKPTaxSystem:WhitelistItem(123))
assert(InfinityDKPGuildBankDonations:SetWhitelistMode(true) and InfinityDKPGuildBankDonations:BlacklistItem(456))
assert(InfinityDKPTaxSystem:SetTaxRate(12) and InfinityDKPGuildBankDonations:SetGoldRewardRate(0.5))
dofile("InfinityDKP\\Modules\\TaxSystem.lua")
dofile("InfinityDKP\\Modules\\GuildBankDonations.lua")
InfinityDKPTaxSystem:Initialize(db)
InfinityDKPGuildBankDonations:Initialize(db)
assert(InfinityDKPTaxSystem.whitelistMode and InfinityDKPTaxSystem:ShouldTaxItem(123))
assert(InfinityDKPTaxSystem.config.taxRatePercentage == 12)
assert(InfinityDKPGuildBankDonations.whitelistMode and InfinityDKPGuildBankDonations.blacklistedItems["456"])
assert(InfinityDKPGuildBankDonations.config.goldRewardPerGoldDonated == 0.5)
assert(not InfinityDKPTaxSystem:SetWhitelistMode("off") and db.taxSystem.whitelistMode)
assert(not InfinityDKPGuildBankDonations:SetWhitelistMode(secret) and db.donationSystem.whitelistMode)
assert(not InfinityDKPTaxSystem:SetTaxRate(math.huge) and db.taxSystem.config.taxRatePercentage == 12)
assert(not InfinityDKPGuildBankDonations:SetGoldRewardRate(secret) and db.donationSystem.config.goldRewardPerGoldDonated == 0.5)
assert(not InfinityDKPGuildBankDonations:SetItemRarityMultiplier(1.5, 1))
assert(not InfinityDKPTaxSystem:SetEnabled("on") and db.taxSystem.config.enabled == true)
ClickAction("Open DKP tax and donation configuration")
local foundTaxFilter, foundDonationFilter = false, false
for _, row in ipairs(ui.taxConfigWindow.rows) do
	if row.data.text == "Tax Whitelist: 123" then foundTaxFilter = true end
	if row.data.text == "Donation Blacklist: 456" then foundDonationFilter = true end
end
assert(foundTaxFilter and foundDonationFilter)
local function ClickTaxConfig(prefix)
	for _, row in ipairs(ui.taxConfigWindow.rows) do
		if row:IsShown() and row.data.onClick and row.data.text:find(prefix, 1, true) == 1 then
			row.scripts.OnClick(row)
			return
		end
	end
	error("Missing tax configuration: " .. prefix)
end
ui.taxConfigValue:SetText("15")
ClickTaxConfig("Tax percentage")
assert(InfinityDKPTaxSystem.config.taxRatePercentage == 12)
InfinityDKPTaxSystem.config.taxRatePercentage = 13
ClickTaxConfig("Tax percentage")
assert(InfinityDKPTaxSystem.config.taxRatePercentage == 13)
ClickTaxConfig("Tax percentage")
assert(InfinityDKPTaxSystem.config.taxRatePercentage == 15 and db.taxSystem.config.taxRatePercentage == 15)
ui.taxConfigValue:SetText("2.5")
ui.taxConfigRarity:SetText("3")
ClickTaxConfig("Rarity multiplier")
ClickTaxConfig("Rarity multiplier")
assert(db.donationSystem.config.itemRarityMultipliers[3] == 2.5)
ui.taxConfigValue:SetText(secret)
ClickTaxConfig("Minimum taxable gold")
assert(warnings[#warnings]:find("finite numeric", 1, true))
ClickTaxConfig("Disable donation rewards")
ClickTaxConfig("Disable donation rewards")
assert(db.donationSystem.config.enabled == false)
assert(InfinityDKPTaxSystem:ClearWhitelist() and next(db.taxSystem.whitelist) == nil)
assert(InfinityDKPGuildBankDonations:ClearBlacklist() and next(db.donationSystem.blacklist) == nil)
assert(not pcall(InfinityDKPTaxSystem.Initialize, InfinityDKPTaxSystem, { taxSystem = "invalid" }))
assert(not pcall(InfinityDKPGuildBankDonations.Initialize, InfinityDKPGuildBankDonations, { donationSystem = "invalid" }))
guildRank = 1
assert(InfinityDKPTaxSystem:IsAdminOnly() and InfinityDKPGuildBankDonations:IsAdminOnly())
guildRank = 2
assert(not InfinityDKPTaxSystem:IsAdminOnly() and not InfinityDKPGuildBankDonations:IsAdminOnly())
assert(warnings[#warnings]:find("permission required", 1, true))
leader = true
assert(InfinityDKPTaxSystem:IsAdminOnly() and InfinityDKPGuildBankDonations:IsAdminOnly())
guildRank, leader = secret, secret
InfinityGuildRoster = { members = { Alice = { rank = "Officer" } } }
assert(not InfinityDKPTaxSystem:IsAdminOnly() and not InfinityDKPGuildBankDonations:IsAdminOnly())
InfinityGuildRoster = nil
GetGuildInfo = function() return nil, nil, nil end
leader = true
assert(not InfinityDKPTaxSystem:IsAdminOnly() and not InfinityDKPGuildBankDonations:IsAdminOnly())
GetGuildInfo, IsGuildLeader = nil, nil
ui.actionFields.player:SetText("GuiPlayer")
ClickAction("Add local player")
assert(db.players.GuiPlayer)
ui.actionFields.value:SetText("30")
ui.actionFields.text:SetText("GUI award")
ClickAction("Award local EP")
assert(db.players.GuiPlayer.ep == 0)
ClickAction("Award local EP")
assert(db.players.GuiPlayer.ep == 30)
ui.actionFields.value:SetText(secret)
ClickAction("Award local EP")
assert(db.players.GuiPlayer.ep == 30 and warnings[#warnings]:find("Protected input", 1, true))
local trading = InfinityDKPPlayerTrading
local oldOffers, oldPrune, oldFind = trading.offers, trading.Prune, trading.Find
local offer = { from = "Alice-Realm", recipient = "Bob-Realm", token = "123-1", amount = 5, status = "pending" }
trading.offers = { test = offer }
trading.Prune = function() end
trading.Find = function(_, from, token)
	if from == offer.from and token == offer.token then return trading.offers.test end
end
ui:RefreshActions()
ClickAction("Trade: Alice-Realm")
assert(ui.actionFields.player:GetText() == "Alice-Realm" and ui.actionFields.value:GetText() == "123-1")
trading.offers.test = nil
ClickAction("Trade: Alice-Realm")
assert(warnings[#warnings]:find("expired or changed", 1, true))
trading.offers, trading.Prune, trading.Find = oldOffers, oldPrune, oldFind
local guildSync = InfinityDKPGuildSync
guildSync.pending = { sender = "Master", count = 2, system = "dkp" }
ui:RefreshActions()
assert(ui.actionsWindow.rows[1].data.text:find("Master", 1, true))
guildSync.pending = { sender = "Master", count = 3, system = "dkp" }
ClickAction("Apply guild snapshot")
assert(warnings[#warnings]:find("Pending snapshot changed", 1, true))
guildSync.pending = nil
local history = InfinityDKPHistory
history:RecordAward("Bob", "Refund sword", nil, "dkp", 5, "Loot award")
history:RecordAward("Bob", "Refund gloves", nil, "manual", 3, "Loot award")
local sword, gloves = history.awards[#history.awards - 1], history.awards[#history.awards]
db.players.Bob.dkp, db.players.Bob.gp = 10, 10
local reentrantAttempt
InfinityDKPEngine:RegisterCallback(function(event)
	if event == "gp_refunded" then reentrantAttempt = history:RefundAward(#history.awards) end
end)
ui:ShowRefunds()
local function ClickRefund(item)
	for _, row in ipairs(ui.refundWindow.rows) do
		if row:IsShown() and row.data.onClick and row.data.text:find(item, 1, true) then row.scripts.OnClick(row); return end
	end
	error("Missing refundable award: " .. item)
end
ClickRefund("Refund gloves")
assert(db.players.Bob.gp == 10 and not gloves.refund)
ClickRefund("Refund gloves")
assert(db.players.Bob.gp == 7 and gloves.refund.amount == 3)
assert(reentrantAttempt == false)
ClickRefund("Refund sword")
db.players.Bob.dkp = 11
ClickRefund("Refund sword")
assert(db.players.Bob.dkp == 11 and not sword.refund)
ClickRefund("Refund sword")
assert(db.players.Bob.dkp == 16 and sword.refund.amount == 5)
assert(not history:RefundAward(#history.awards - 1))
assert(db.pointTransactions[#db.pointTransactions].amount == 5)
assert(InfinityDKPReports:GenerateLootReport(7):find("refunded", 1, true))
assert(history:ExportHistory(7):find("refunded", 1, true))
history:RecordAward("Bob", "Insufficient GP", nil, "manual", 20, "Loot award")
assert(not history:RefundAward(#history.awards) and db.players.Bob.gp == 7)
guildSync.outgoing = {}
history:RecordAward("Bob", "While syncing", nil, "dkp", 1, "Loot award")
assert(not history:RefundAward(#history.awards) and db.players.Bob.dkp == 16)
guildSync.outgoing = nil
local transactionsTable = db.pointTransactions
db.pointTransactions, InfinityDKPPoints.point_history = nil, nil
assert(not history:RefundAward(#history.awards) and db.players.Bob.dkp == 16)
db.pointTransactions, InfinityDKPPoints.point_history = transactionsTable, transactionsTable
local latest = history.awards[#history.awards]
ui:ShowRefunds()
ClickRefund("While syncing")
latest.points = secret
ClickRefund("While syncing")
assert(db.players.Bob.dkp == 16 and not latest.refund)
latest.points = 1
guildSync.pending = { stale = false }
assert(history:RefundAward(#history.awards))
assert(guildSync.pending.stale and db.players.Bob.dkp == 17)
guildSync.pending = nil
history:Initialize(db)
InfinityDKPPoints:Initialize(db)
assert(history.awards[#history.awards].refund.amount == 1)
assert(InfinityDKPPoints.point_history[#InfinityDKPPoints.point_history].reason == "Refund: While syncing")
SlashCmdList = {}
dofile("InfinityDKP\\Modules\\RefundSystem.lua")
dofile("InfinityDKP\\Modules\\BankDepositTracking.lua")
dofile("InfinityDKP\\Modules\\PointHistoryAudit.lua")
dofile("InfinityDKP\\Modules\\PodiumDisplay.lua")
SlashCmdList.REFUND("pending")
assert(ui.refundWindow:IsShown())
SlashCmdList.REFUND("approve old-id")
assert(warnings[#warnings]:find("unavailable", 1, true))
ClickAction("Open local point transactions")
assert(ui.pointHistoryWindow:IsShown() and ui.pointHistoryWindow.rows[1].data.text:find("Refund:", 1, true))
ui.pointHistoryFilter:SetText("GuiPlayer")
ui:RefreshPointHistory()
assert(ui.pointHistoryWindow.rows[1].data.text:find("GuiPlayer", 1, true))
assert(not ui.pointHistoryWindow.rows[2]:IsShown())
ui.pointHistoryFilter:SetText(secret)
ui:RefreshPointHistory()
assert(warnings[#warnings]:find("Protected input", 1, true))
db.pointTransactions[#db.pointTransactions + 1] = { player = secret, type = "gp", amount = 1, reason = "x", timestamp = "now" }
ui.pointHistoryFilter:SetText("")
ui:RefreshPointHistory()
assert(ui.pointHistoryWindow.status.text:find("Unreadable records: 1", 1, true))
table.remove(db.pointTransactions)
SlashCmdList.POINTHISTORY("player Bob")
assert(ui.pointHistoryFilter:GetText() == "Bob" and ui.pointHistoryWindow.rows[1].data.text:find("Bob", 1, true))
for i = 1, 205 do
	InfinityDKPPoints:LogTransaction("CapTest", "dkp", i, "record " .. i)
end
ui.pointHistoryFilter:SetText("CapTest")
ui:RefreshPointHistory()
assert(ui.pointHistoryWindow.rows[200]:IsShown() and ui.pointHistoryWindow.rows[200].data.text:find("record 6", 1, true))
assert(not ui.pointHistoryWindow.rows[201] or not ui.pointHistoryWindow.rows[201]:IsShown())
ui.pointHistoryOlder.scripts.OnClick()
assert(ui.pointHistoryWindow.rows[1].data.text:find("record 5", 1, true))
assert(ui.pointHistoryWindow.rows[5].data.text:find("record 1", 1, true))
ui.pointHistoryNewer.scripts.OnClick()
assert(ui.pointHistoryWindow.rows[1].data.text:find("record 205", 1, true))
ui.pointHistoryOlder.scripts.OnClick()
ui.pointHistoryFilter:SetText("GuiPlayer")
ui.pointHistoryOlder.scripts.OnClick()
assert(ui.pointHistoryOffset == 0 and ui.pointHistoryWindow.rows[1].data.text:find("GuiPlayer", 1, true))
for i = 1, 205 do history:RecordAward("Bob", "Page item " .. i, nil, "dkp", 1, "test") end
ui:ShowRefunds()
assert(ui.refundWindow.rows[1].data.text:find("Page item 205", 1, true))
ui.refundOlder.scripts.OnClick()
assert(ui.refundWindow.rows[1].data.text:find("Page item 5", 1, true))
ui.refundNewer.scripts.OnClick()
assert(ui.refundWindow.rows[1].data.text:find("Page item 205", 1, true))
SlashCmdList.BANKDEPOSIT("whitelist ore")
assert(warnings[#warnings]:find("unavailable", 1, true))
ui.bankLogWindow:Hide()
SlashCmdList.BANKDEPOSIT("")
assert(ui.bankLogWindow:IsShown())
SlashCmdList.POINTHISTORY("status")
assert(warnings[#warnings]:find("unavailable", 1, true))
ui:Hide()
SlashCmdList.PODIUM("show")
assert(ui.frame:IsShown() and ui.selectedTab == "Players")
SlashCmdList.PODIUM("hide")
assert(not ui.frame:IsShown())
ui:ShowActions()
ClickAction("Configure local boss kill awards")
local bossWindow, bossConfig = ui.bossAwardWindow, db.localBossAwards
ui.bossAwardAmount:SetText("7")
bossWindow.rows[6].scripts.OnClick(bossWindow.rows[6])
assert(bossConfig.amount == 10)
bossConfig.amount = 12
bossWindow.rows[6].scripts.OnClick(bossWindow.rows[6])
assert(bossConfig.amount == 12)
bossWindow.rows[6].scripts.OnClick(bossWindow.rows[6])
assert(bossConfig.amount == 7)
bossWindow.rows[2].scripts.OnClick(bossWindow.rows[2])
assert(not bossConfig.enabled)
bossWindow.rows[2].scripts.OnClick(bossWindow.rows[2])
assert(bossConfig.enabled)
commands["/dkp system"]("dkp")
InfinityDKPEngine:SetSystemType("dkp")
bobPresent = true
local aliceBefore, bobBefore = db.players.Alice.dkp, db.players.Bob.dkp
guildSync.pending = { stale = false }
db.syncBackup = { players = {}, system_type = "dkp" }
events.scripts.OnEvent(events, "ENCOUNTER_START", 80, "Award boss", 1, 2)
local bossRaid = InfinityAttendanceTracker.raids[#InfinityAttendanceTracker.raids]
events.scripts.OnEvent(events, "ENCOUNTER_END", 80, "Award boss", 1, 2, 1)
assert(db.players.Alice.dkp == aliceBefore + 7 and db.players.Bob.dkp == bobBefore + 7)
assert(bossRaid.localBossAward and bossRaid.localBossAward.recipients == 2 and guildSync.pending.stale)
assert(db.syncBackup.stale and not guildSync:Undo())
local transactionCount = #db.pointTransactions
events.scripts.OnEvent(events, "ENCOUNTER_END", 80, "Award boss", 1, 2, 1)
assert(db.players.Alice.dkp == aliceBefore + 7 and #db.pointTransactions == transactionCount)
events.scripts.OnEvent(events, "ENCOUNTER_START", 81, "Mismatched boss", 1, 2)
events.scripts.OnEvent(events, "ENCOUNTER_END", 82, "Mismatched boss", 1, 2, 1)
assert(db.players.Alice.dkp == aliceBefore + 7 and warnings[#warnings]:find("encounter ID", 1, true))
events.scripts.OnEvent(events, "ENCOUNTER_START", 83, "Wipe", 1, 2)
events.scripts.OnEvent(events, "ENCOUNTER_END", 83, "Wipe", 1, 2, 0)
assert(db.players.Alice.dkp == aliceBefore + 7)
events.scripts.OnEvent(events, "ENCOUNTER_START", 86, "Unknown result", 1, 2)
events.scripts.OnEvent(events, "ENCOUNTER_END", 86, "Unknown result", 1, 2, secret)
assert(db.players.Alice.dkp == aliceBefore + 7 and warnings[#warnings]:find("result unavailable", 1, true))
local groupCount = GetNumGroupMembers
GetNumGroupMembers = function() return secret end
events.scripts.OnEvent(events, "ENCOUNTER_START", 84, "Protected roster", 1, 2)
GetNumGroupMembers = groupCount
events.scripts.OnEvent(events, "ENCOUNTER_END", 84, "Protected roster", 1, 2, 1)
assert(db.players.Alice.dkp == aliceBefore + 7 and warnings[#warnings]:find("attendance was incomplete", 1, true))
guildSync.pending = nil
db.syncBackup = nil
local directRaid = { name = "Test", members = { Alice = { present = true }, Bob = { present = true } } }
db.players.Bob.dkp = secret
assert(not InfinityBossKillAwards:AwardLocalRaid(directRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync))
assert(db.players.Alice.dkp == aliceBefore + 7 and not directRaid.localBossAward)
db.players.Bob.dkp = bobBefore + 7
directRaid.attendanceIncomplete = true
assert(not InfinityBossKillAwards:AwardLocalRaid(directRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync))
directRaid.attendanceIncomplete = nil
guildSync.outgoing = {}
assert(not InfinityBossKillAwards:AwardLocalRaid(directRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync))
guildSync.outgoing = nil
assert(InfinityBossKillAwards:SetLocalConfig(true, "ep", 3))
assert(not InfinityBossKillAwards:AwardLocalRaid(directRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync))
InfinityDKPEngine:SetSystemType("epgp")
local aliceEP, bobEP = db.players.Alice.ep, db.players.Bob.ep
local callbackCount, callbackConsistent = 0, true
InfinityDKPEngine:RegisterCallback(function(event)
	if event == "ep_awarded" then
		callbackCount = callbackCount + 1
		callbackConsistent = callbackConsistent and db.players.Alice.ep == aliceEP + 3 and db.players.Bob.ep == bobEP + 3
			and not InfinityBossKillAwards:AwardLocalRaid(directRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync)
	end
end)
assert(InfinityBossKillAwards:AwardLocalRaid(directRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync))
assert(db.players.Alice.ep == aliceEP + 3 and db.players.Bob.ep == bobEP + 3)
assert(callbackCount == 2 and callbackConsistent)
assert(not InfinityBossKillAwards:AwardLocalRaid(directRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync))
InfinityBossKillAwards:InitializeLocal(db)
assert(InfinityBossKillAwards.localConfig.enabled and InfinityBossKillAwards.localConfig.kind == "ep")
assert(InfinityBossKillAwards:SetLocalConfig(true, "dkp", 3))
InfinityDKPEngine:SetSystemType("dkp")
local partialRaid = { name = "Partial", members = { Alice = { present = true }, Unknown = { present = true } } }
local aliceDKP = db.players.Alice.dkp
assert(InfinityBossKillAwards:AwardLocalRaid(partialRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync))
assert(db.players.Alice.dkp == aliceDKP + 3 and partialRaid.localBossAward.missing == 1)
assert(warnings[#warnings]:find("unregistered", 1, true))
local overflowRaid = { name = "Overflow", members = { Alice = { present = true }, Bob = { present = true } } }
local previousBob = db.players.Bob.dkp
db.players.Bob.dkp = 1000000000
assert(not InfinityBossKillAwards:AwardLocalRaid(overflowRaid, InfinityDKPEngine, InfinityDKPPoints, guildSync))
assert(db.players.Alice.dkp == aliceDKP + 3 and not overflowRaid.localBossAward)
db.players.Bob.dkp = previousBob
print("dkp_runtime: all tests passed")
