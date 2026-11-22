local frames, commands, timers, messages, warnings = {}, {}, {}, {}, {}
local now, secret, cursor = 0, {}, "|Hitem:123:0|h[Sword]|h"
local output, originalPrint = {}, print
print = function(message) output[#output + 1] = tostring(message) end
local widget = {}
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return rawget(self, "text") or "" end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:SetShown(value) self.shown = value end
function widget:IsShown() return self.shown end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name, parent)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local frame = setmetatable({ scripts = {}, parent = parent, shown = true, rows = false, emptyText = false }, meta)
	if name then _G[name] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
issecretvalue = function(value) return value == secret end
GetTime = function() return now end
UnitName = function() return "Alice" end
UnitAffectingCombat = function() return false end
GetGuildInfo = function() return "Guild" end
GetCursorInfo = function() return "item", 123, cursor end
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end }
InfinityUtils = {
	Info = function() end, Debug = function() end,
	Warning = function(_, message) warnings[#warnings + 1] = message end,
	DeepCopy = function(_, value) return value end,
	Split = function(_, value) local result = {}; for part in value:gmatch("%S+") do result[#result + 1] = part end; return result end,
}
InfinityMessaging = { Publish = function(_, event, data) messages[#messages + 1] = { event, data } end }
InfinityCommandRegistry = { RegisterCommand = function(_, name, callback) assert(not commands[name]); commands[name] = callback end }
InfinityLootAccessControl = { CanDoAction = function() return true end }
InfinityStorageManager = { GetFeatureSettings = function() return {} end }
INFINITY_FEATURES = { LOOT = "loot" }
dofile("InfinityLoot\\Modules\\Auctions.lua")
dofile("InfinityLoot\\UI\\AuctionUI.lua")
InfinityLootAuctions:Initialize()
InfinityLootAuctionUI:Initialize()
assert(commands.auction and commands.bid and not _G.SLASH_LOOTAUCTION1)
commands.auction({ "create", "--mode", "antisnipe", "--duration", "60", "--minbid", "10" })
local auction = InfinityLootAuctions:GetAuction("auction_1")
assert(auction and auction.itemLink == cursor and auction.itemName == "Sword")
commands.auction({ "list" })
assert(output[#output]:find("auction_1", 1, true))
assert(InfinityLootAuctionUI.frames.main:IsShown())
local row = InfinityLootAuctionUI.frames.main.listFrame.rows[1]
row.bid.scripts.OnClick()
assert(auction.bids[1].amount == 10)
assert(not InfinityLootAuctions:PlaceBid(auction.id, "Bob", 10))
assert(not InfinityLootAuctions:PlaceBid(auction.id, "Bob", secret))
now = 55
commands.bid({ auction.id, "11" })
assert(auction.bids[1].amount == 11 and auction.endTime == 65)
local frameCount = #frames
for _ = 1, 10 do InfinityLootAuctionUI:UpdateAuctionFrame() end
assert(#frames == frameCount)
now = 60
timers[1].callback()
assert(InfinityLootAuctions:GetAuction(auction.id) and timers[2].at == 65)
now = 65
assert(not InfinityLootAuctions:PlaceBid(auction.id, "Bob", 12))
timers[2].callback()
assert(not InfinityLootAuctions:GetAuction(auction.id))
local history = InfinityLootAuctions:GetAuctionHistory(1)[1]
assert(history.id == auction.id and history.winnerPrice == 11 and history.itemLink == cursor)
commands.auction({ "history" })
assert(output[#output]:find("Alice (11 GP)", 1, true))
cursor = nil
commands.auction({ "create" })
assert(not InfinityLootAuctions:GetAuction("auction_2"))
cursor = "|Hitem:123:0|h[Sword]|h"
commands.auction({ "create", "--duration", "bad" })
assert(not InfinityLootAuctions:GetAuction("auction_2"))
assert(not InfinityLootAuctions:CreateAuction(cursor, "open", secret, {}))
local tierID = InfinityLootAuctions:CreateAuction(cursor, "tiered", 30, { minimumBid = 1 })
assert(InfinityLootAuctions:PlaceBid(tierID, "Bob", 10, "MS"))
assert(InfinityLootAuctions:PlaceBid(tierID, "Bob", 5, "OS"))
local tierAuction = InfinityLootAuctions:GetAuction(tierID)
assert(#tierAuction.tierBids.MS == 0 and #tierAuction.tierBids.OS == 1)
assert(InfinityLootAuctions:CloseAuction(tierID).winningBid == 5)
local vickreyID = InfinityLootAuctions:CreateAuction(cursor, "vickrey", 30, { minimumBid = 1 })
local count = #messages
assert(InfinityLootAuctions:PlaceBid(vickreyID, "Bob", 10))
assert(InfinityLootAuctions:PlaceBid(vickreyID, "Alice", 5))
assert(#messages == count)
local result = InfinityLootAuctions:CloseAuction(vickreyID)
assert(result.winner == "Bob" and result.winningBid == 5)
dofile("InfinityCore\\UI\\UIFramework.lua")
dofile("InfinityLoot\\Modules\\AdvancedEconomy.lua")
dofile("InfinityLoot\\UI\\MainUI.lua")
InfinityLootAdvancedEconomy:Initialize()
InfinityLootAuctionUI:ShowCreateEditor()
local create = InfinityLootAuctionUI.createFrame
create.rows[5].scripts.OnClick(create.rows[5])
assert(not InfinityLootAuctions:GetAuction("auction_4"))
create.rows[5].scripts.OnClick(create.rows[5])
local guiAuction = InfinityLootAuctions:GetAuction("auction_4")
assert(guiAuction and guiAuction.biddingMode == "tiered")
InfinityLootAuctionUI:ShowBidEditor()
InfinityLootAuctionUI.bidID:SetText(guiAuction.id)
InfinityLootAuctionUI.bidAmount:SetText("20")
InfinityLootAuctionUI.bidTier:SetText("MS")
local bidFrame = InfinityLootAuctionUI.bidFrame
bidFrame.rows[1].scripts.OnClick(bidFrame.rows[1])
assert(guiAuction.tierBids.MS[1].amount == 20)
InfinityLootAuctionUI.bidAmount:SetText(secret)
bidFrame.rows[1].scripts.OnClick(bidFrame.rows[1])
assert(warnings[#warnings]:find("protected", 1, true))
InfinityLootAuctions:CloseAuction(guiAuction.id)
InfinityLootUI:ShowItemPrices()
local ui = InfinityLootUI
ui.priceItem:SetText("123")
ui.priceValue:SetText("25")
ui.priceFrame.rows[1].scripts.OnClick(ui.priceFrame.rows[1])
assert(not InfinityLootAdvancedEconomy.itemPrices[123])
ui.priceValue:SetText("30")
ui.priceFrame.rows[1].scripts.OnClick(ui.priceFrame.rows[1])
assert(not InfinityLootAdvancedEconomy.itemPrices[123])
ui.priceFrame.rows[1].scripts.OnClick(ui.priceFrame.rows[1])
assert(InfinityLootAdvancedEconomy.itemPrices[123].basePrice == 30)
ui.priceItem:SetText(secret)
ui.priceFrame.rows[1].scripts.OnClick(ui.priceFrame.rows[1])
assert(warnings[#warnings]:find("Protected input", 1, true))
dofile("InfinityLoot\\Modules\\Decay.lua")
InfinityLootAccessControl.HasPermission = function() return true end
InfinityUtils.GetTimeStamp = function() return 1000000 end
InfinityLootEPGP = {
	players = { Alice = { ep = 100, gp = 100 } },
	AddPlayer = function(_, name, ep, gp) InfinityLootEPGP.players[name] = { ep = ep, gp = gp }; return true end,
	UpdatePlayerPriority = function() end,
	AwardEP = function(_, name, value) InfinityLootEPGP.players[name].ep = InfinityLootEPGP.players[name].ep + value; return true end,
	AwardGP = function(_, name, _, value) InfinityLootEPGP.players[name].gp = InfinityLootEPGP.players[name].gp + value; return true end,
}
ui:ShowDecay()
InfinityPointAuditing = {}
ui:ShowPointAudit()
assert(ui.auditFrame:IsShown() and not ui.decayHistoryFrame)
ui.decayInput:SetText("20")
ui.decayFrame.rows[1].scripts.OnClick(ui.decayFrame.rows[1])
assert(InfinityLootDecay.config.decayPercent == 10)
InfinityLootEPGP.players.Alice.ep = 200
ui.decayFrame.rows[1].scripts.OnClick(ui.decayFrame.rows[1])
assert(InfinityLootDecay.config.decayPercent == 10)
ui.decayFrame.rows[1].scripts.OnClick(ui.decayFrame.rows[1])
assert(InfinityLootDecay.config.decayPercent == 20)
ui.decayFrame.rows[9].scripts.OnClick(ui.decayFrame.rows[9])
assert(InfinityLootEPGP.players.Alice.ep == 200)
ui.decayFrame.rows[9].scripts.OnClick(ui.decayFrame.rows[9])
assert(InfinityLootEPGP.players.Alice.ep == 160)
ui.decayFrame.rows[12].scripts.OnClick(ui.decayFrame.rows[12])
assert(ui.decayHistoryFrame.rows[1].data.text:find("Alice", 1, true))
ui.decayPlayer:SetText("Bob")
ui.decayFrame.rows[13].scripts.OnClick(ui.decayFrame.rows[13])
assert(not InfinityLootEPGP.players.Bob)
ui.decayFrame.rows[13].scripts.OnClick(ui.decayFrame.rows[13])
assert(InfinityLootEPGP.players.Bob)
ui.decayInput:SetText("15")
ui.decayFrame.rows[14].scripts.OnClick(ui.decayFrame.rows[14])
ui.decayFrame.rows[14].scripts.OnClick(ui.decayFrame.rows[14])
assert(InfinityLootEPGP.players.Bob.ep == 15)
ui.decayFrame.rows[16].scripts.OnClick(ui.decayFrame.rows[16])
assert(ui.lootPlayersFrame.rows[2].data.text:find("Bob | EP 15", 1, true))
InfinityLootAccessControl.HasPermission = function() return false end
ui.decayFrame.rows[7].scripts.OnClick(ui.decayFrame.rows[7])
assert(warnings[#warnings]:find("permission denied", 1, true))
dofile("InfinityLoot\\Modules\\EPGP.lua")
dofile("InfinityLoot\\Modules\\PointAuditing.lua")
InfinityLootEPGP.transactionHistory = {
	{ timestamp = 999980, playerName = "Alice", type = "ep_awarded", amount = 30, reason = "Boss" },
	{ timestamp = 999990, playerName = "Alice", type = "gp_awarded", amount = 10, item = "Sword" },
	{ timestamp = 999995, playerName = "Alice", type = "gp_awarded", amount = 12, item = "Hat" },
	{ timestamp = 999996, playerName = "Alice", type = "gp_awarded", amount = 8, item = "Sword" },
}
local audit = InfinityPointAuditing
assert(#audit:GetTransactionsByType("gp_awarded") == 3)
assert(audit:GetPlayerEPSources("Alice")[1].amount == 30)
assert(audit:GetPlayerGPItems("Alice")[1].itemName == "Sword" and audit:GetPlayerGPItems("Alice")[1].gp == 18)
assert(#audit:DetectAnomalies("Alice") == 1)
assert(audit:GeneratePlayerAuditReport("Alice", 1).gpSpent == 30)
ui:ShowPointAudit()
ui.auditPlayer:SetText("Alice")
ui.auditValue:SetText("1")
ui.auditFrame.rows[4].scripts.OnClick(ui.auditFrame.rows[4])
assert(ui.auditResults.rows[1].data.text:find("Boss | EP 30", 1, true))
ui.auditFrame.rows[7].scripts.OnClick(ui.auditFrame.rows[7])
assert(ui.auditResults.rows[2].data.text == "GP spent: 30")
ui.auditPlayer:SetText(secret)
ui.auditFrame.rows[4].scripts.OnClick(ui.auditFrame.rows[4])
assert(warnings[#warnings]:find("protected", 1, true))
dofile("InfinityLoot\\Modules\\LootHistory.lua")
ui:ShowAwardHistory()
ui.awardHistoryPlayer:SetText("Alice")
ui.awardHistoryItem:SetText("Sword")
ui.awardHistoryValue:SetText("25")
ui.awardHistoryFrame.rows[6].scripts.OnClick(ui.awardHistoryFrame.rows[6])
assert(#InfinityLootHistory.lootLog == 0)
ui.awardHistoryFrame.rows[6].scripts.OnClick(ui.awardHistoryFrame.rows[6])
assert(#InfinityLootHistory.lootLog == 1)
ui.awardHistoryFrame.rows[3].scripts.OnClick(ui.awardHistoryFrame.rows[3])
assert(ui.awardHistoryResults.rows[1].data.text:find("Alice | Sword | 25", 1, true))
ui.awardHistoryFrame.rows[4].scripts.OnClick(ui.awardHistoryFrame.rows[4])
assert(ui.awardHistoryResults.rows[1].data.text:find("Alice | 1 awards | total 25", 1, true))
ui.awardHistoryPlayer:SetText(secret)
ui.awardHistoryFrame.rows[6].scripts.OnClick(ui.awardHistoryFrame.rows[6])
assert(warnings[#warnings]:find("protected", 1, true) and #InfinityLootHistory.lootLog == 1)
local taxSettings = {}
InfinityStorageManager.GetFeatureSettings = function(_, name)
	if name == "taxation" then return taxSettings end
	return {}
end
dofile("InfinityLoot\\Modules\\DKPTaxation.lua")
InfinityDKPTaxation:Initialize()
ui:ShowTaxSettings()
ui.taxInput:SetText("0.5")
ui.taxFrame.rows[1].scripts.OnClick(ui.taxFrame.rows[1])
assert(InfinityDKPTaxation.config.taxRatePerGold == 0.01)
ui.taxFrame.rows[1].scripts.OnClick(ui.taxFrame.rows[1])
assert(taxSettings.config.taxRatePerGold == 0.5)
ui.taxInput:SetText("Ore")
ui.taxFrame.rows[3].scripts.OnClick(ui.taxFrame.rows[3])
ui.taxFrame.rows[3].scripts.OnClick(ui.taxFrame.rows[3])
assert(taxSettings.whitelistedItems.Ore)
ui.taxFrame.rows[7].scripts.OnClick(ui.taxFrame.rows[7])
ui.taxFrame.rows[7].scripts.OnClick(ui.taxFrame.rows[7])
assert(taxSettings.config.enableWhitelist)
InfinityDKPTaxation:Initialize()
assert(InfinityDKPTaxation.config.taxRatePerGold == 0.5 and InfinityDKPTaxation:IsWhitelisted("Ore"))
ui.taxInput:SetText(secret)
ui.taxFrame.rows[1].scripts.OnClick(ui.taxFrame.rows[1])
assert(warnings[#warnings]:find("finite", 1, true))
assert(not InfinityDKPTaxation:SetTaxRate(-1) and not InfinityDKPTaxation:SetDonationRate(math.huge))
local dkpDatabase = {}
InfinityCore = { GetDatabase = function() return dkpDatabase end }
time = function() return 1000000 end
date = os.date
dofile("InfinityDKP\\Core\\DKPEngine.lua")
dofile("InfinityDKP\\Modules\\Points.lua")
InfinityDKPEngine:Initialize()
InfinityDKPPoints:Initialize(dkpDatabase)
InfinityDKPEngine:AddPlayer("Alice")
local staleReason
InfinityDKPGuildSync = { MarkSnapshotsStale = function(_, reason) staleReason = reason end }
assert(not InfinityDKPTaxation:AwardForTax("Alice", 100))
InfinityDKPEngine.system_type = InfinityDKPEngine.SYSTEM_DKP
ui:ShowTaxSettings()
ui.taxPlayer:SetText("Alice")
ui.taxGold:SetText("100")
ui.taxFrame.rows[9].scripts.OnClick(ui.taxFrame.rows[9])
assert(InfinityDKPEngine.players.Alice.dkp == 0)
InfinityDKPEngine.players.Alice.dkp = 10
ui.taxFrame.rows[9].scripts.OnClick(ui.taxFrame.rows[9])
assert(InfinityDKPEngine.players.Alice.dkp == 10)
ui.taxFrame.rows[9].scripts.OnClick(ui.taxFrame.rows[9])
assert(InfinityDKPEngine.players.Alice.dkp == 60 and #taxSettings.taxHistory == 1)
assert(staleReason == "Local tax or donation points changed")
ui.taxInput:SetText("Ore")
ui.taxFrame.rows[10].scripts.OnClick(ui.taxFrame.rows[10])
ui.taxFrame.rows[10].scripts.OnClick(ui.taxFrame.rows[10])
assert(InfinityDKPEngine.players.Alice.dkp == 61 and #taxSettings.taxHistory == 2)
assert(#dkpDatabase.pointTransactions == 2 and dkpDatabase.pointTransactions[1].amount == 50)
assert(not InfinityDKPTaxation:AwardForDonation("Alice", 100, "Forbidden") and #taxSettings.taxHistory == 2)
InfinityDKPGuildSync.outgoing = {}
assert(not InfinityDKPTaxation:AwardForTax("Alice", 100) and InfinityDKPEngine.players.Alice.dkp == 61)
InfinityDKPGuildSync.outgoing = nil
INFINITY_EVENTS = { DATA_CHANGED = "changed" }
InfinityUtils.GetTimeStamp = function() return now end
InfinityUtils.FormatGold = function(_, amount) return tostring(amount) end
InfinityUtils.FormatTime = function(_, seconds) return tostring(seconds) end
InfinityUtils.ClearContainer = function() end
INFINITY_COLORS = { PRIMARY = "", RESET = "" }
InfinityDataManager = { RegisterSource = function() end }
dofile("InfinityLoot\\Modules\\Tracking.lua")
local tracking = InfinityLootTracking
tracking:Initialize()
local firstSession = tracking.currentSession
now = now + 10
assert(tracking:PauseSession() and tracking:GetSessionStats().elapsedSeconds == 10)
now = now + 100
assert(tracking:GetSessionStats().elapsedSeconds == 10)
local trackingTab = { contentArea = CreateFrame("Frame") }
ui:ShowTrackingTab(trackingTab)
local recordButton
for _, element in ipairs(frames) do
	if element.parent == trackingTab.contentArea and element.text == "Record" then recordButton = element end
end
assert(recordButton)
recordButton.scripts.OnClick()
ui.trackingName:SetText("Sword")
ui.trackingValue:SetText("100")
ui.trackingCategory:SetText("GEAR")
ui.trackingRecords.rows[1].scripts.OnClick(ui.trackingRecords.rows[1])
assert(tracking:GetSessionStats().totalItems == 0 and warnings[#warnings]:find("resume", 1, true))
assert(tracking:ResumeSession())
now = now + 5
assert(tracking:GetSessionStats().elapsedSeconds == 15)
ui.trackingRecords.rows[1].scripts.OnClick(ui.trackingRecords.rows[1])
ui.trackingRecords.rows[2].scripts.OnClick(ui.trackingRecords.rows[2])
ui.trackingRecords.rows[3].scripts.OnClick(ui.trackingRecords.rows[3])
ui.trackingRecords.rows[4].scripts.OnClick(ui.trackingRecords.rows[4])
ui.trackingRecords.rows[5].scripts.OnClick(ui.trackingRecords.rows[5])
local stats = tracking:GetSessionStats()
assert(stats.totalItems == 1 and stats.totalValue == 200 and stats.costs == 100
	and stats.kills == 1 and stats.lootedMobs == 1)
assert(ui.trackingRecords.rows[6].data.text == "Sword | GEAR | 100 copper")
assert(not tracking:RecordLoot("Bad", "UNKNOWN", 50))
assert(not tracking:RecordMoney(-1) and not tracking:RecordCost(secret, "Bad"))
ui.trackingValue:SetText("50000")
ui.trackingRecords.rows[1].scripts.OnClick(ui.trackingRecords.rows[1])
assert(tracking:GetSessionStats().totalValue == 50200 and warnings[#warnings]:find("HIGH VALUE", 1, true))
assert(tracking.db.sessions[tracking.currentSession].nextId == 3)
ui.trackingValue:SetText(secret)
ui.trackingRecords.rows[2].scripts.OnClick(ui.trackingRecords.rows[2])
assert(warnings[#warnings]:find("protected", 1, true) and tracking:GetSessionStats().totalValue == 50200)
assert(tracking:PauseSession())
now = now + 50
assert(tracking:EndSession() and tracking:GetSessionStats().elapsedSeconds == 15)
assert(not tracking:ResumeSession() and not tracking:EndSession())
local nextSession = tracking:StartNewSession()
now = now + 5
assert(nextSession ~= firstSession and tracking:StartNewSession() ~= nextSession)
assert(tracking:GetSessionStats(nextSession).ended and tracking:GetSessionStats(nextSession).elapsedSeconds == 5)
ui:ShowTrackingSessions()
assert(ui.trackingSessions:IsShown() and ui.trackingSessions.rows[1].data.text:find("session_", 1, true))
local oldSessionRow
for _, row in ipairs(ui.trackingSessions.rows) do
	if row.data.text:find(firstSession, 1, true) then oldSessionRow = row end
end
assert(oldSessionRow)
oldSessionRow.scripts.OnClick(oldSessionRow)
assert(ui.trackingSessionItems.rows[1].data.text == "Sword | GEAR | 50000 copper")
date = os.date
dofile("InfinityLoot\\Modules\\Commissions.lua")
InfinityLootCommissions:Initialize()
ui:ShowCommissionsManager()
ui.commissionID:SetText("42")
ui.commissionName:SetText("Daily supplies")
ui.commissionNPC:SetText("Quartermaster")
ui.commissionsFrame.rows[1].scripts.OnClick(ui.commissionsFrame.rows[1])
assert(not InfinityLootCommissions.db.commissions[42])
ui.commissionsFrame.rows[1].scripts.OnClick(ui.commissionsFrame.rows[1])
assert(InfinityLootCommissions.db.commissions[42].name == "Daily supplies")
ui.commissionsFrame.rows[3].scripts.OnClick(ui.commissionsFrame.rows[3])
assert(not InfinityLootCommissions:IsCompletedToday(42))
ui.commissionsFrame.rows[3].scripts.OnClick(ui.commissionsFrame.rows[3])
assert(InfinityLootCommissions:IsCompletedToday(42) and InfinityLootCommissions:GetStatistics().totalCompletions == 1)
ui.commissionsFrame.rows[3].scripts.OnClick(ui.commissionsFrame.rows[3])
assert(InfinityLootCommissions:GetStatistics().totalCompletions == 1)
ui.commissionsFrame.rows[2].scripts.OnClick(ui.commissionsFrame.rows[2])
assert(InfinityLootCommissions.db.commissions[42])
ui.commissionsFrame.rows[2].scripts.OnClick(ui.commissionsFrame.rows[2])
assert(not InfinityLootCommissions.db.commissions[42] and InfinityLootCommissions:GetStatistics().todayCompleted == 0)
ui.commissionID:SetText(secret)
ui.commissionsFrame.rows[1].scripts.OnClick(ui.commissionsFrame.rows[1])
assert(warnings[#warnings]:find("protected", 1, true))
InfinityDataManager.UpdateSourceData = function() end
dofile("InfinityLoot\\Modules\\LootManager.lua")
InfinityLootManager:Initialize()
ui:ShowRaidManager()
ui.raidName:SetText("Test raid")
ui.raidManagerFrame.rows[1].scripts.OnClick(ui.raidManagerFrame.rows[1])
assert(not next(InfinityLootManager.db.raids))
ui.raidManagerFrame.rows[1].scripts.OnClick(ui.raidManagerFrame.rows[1])
local localRaid = InfinityLootManager.db.raids[ui.selectedLootRaid]
assert(localRaid.name == "Test raid")
ui.raidPlayer:SetText("Alice")
ui.raidAmount:SetText("100")
ui.raidRole:SetText("Healer")
ui.raidManagerFrame.rows[2].scripts.OnClick(ui.raidManagerFrame.rows[2])
ui.raidManagerFrame.rows[2].scripts.OnClick(ui.raidManagerFrame.rows[2])
assert(localRaid.members.Alice.dkp == 100 and InfinityLootManager:GetStatistics().totalMembers == 1)
ui.raidName:SetText("Sword")
ui.raidAmount:SetText("20")
ui.raidManagerFrame.rows[3].scripts.OnClick(ui.raidManagerFrame.rows[3])
localRaid.members.Alice.dkp = 90
ui.raidManagerFrame.rows[3].scripts.OnClick(ui.raidManagerFrame.rows[3])
assert(#localRaid.lootAwarded == 0)
ui.raidManagerFrame.rows[3].scripts.OnClick(ui.raidManagerFrame.rows[3])
assert(localRaid.members.Alice.dkp == 70 and #localRaid.lootAwarded == 1)
ui.raidAmount:SetText(secret)
ui.raidManagerFrame.rows[3].scripts.OnClick(ui.raidManagerFrame.rows[3])
assert(warnings[#warnings]:find("protected", 1, true))
local tradeOpened
InfinityDKPUI = {
	Initialize = function(self) self.ShowActions = function() tradeOpened = true end end,
}
local dkpTab = { contentArea = CreateFrame("Frame") }
ui:ShowDKPTab(dkpTab)
for _, element in ipairs(frames) do
	if element.parent == dkpTab.contentArea and element.text == "Guild DKP trade" then element.scripts.OnClick() end
end
assert(tradeOpened)
dofile("InfinityLoot\\Modules\\DKPTrade.lua")
local offerRecipient, offerAmount
InfinityDKPPlayerTrading = { Offer = function(_, recipient, amount)
	offerRecipient, offerAmount = recipient, amount
	return true, "offer-1"
end }
assert(InfinityDKPTrade:RequestTrade("Bob", 5))
assert(offerRecipient == "Bob" and offerAmount == 5)
assert(not InfinityDKPTrade:ApproveTrade("Bob", 5) and not InfinityDKPTrade:DenyTrade("Bob", 5))
InfinityDKPPlayerTrading = nil
assert(not InfinityDKPTrade:RequestTrade("Bob", 5) and warnings[#warnings]:find("unavailable", 1, true))
dofile("InfinityLoot\\Modules\\Economy.lua")
InfinityLootEconomy:Initialize()
ui:ShowEconomyRecords()
ui.economyAmount:SetText("200")
ui.economySource:SetText("Vendor")
ui.economyDetail:SetText("Repair")
ui.economyRecords.rows[2].scripts.OnClick(ui.economyRecords.rows[2])
assert(#InfinityLootEconomy.db.goldTracking.spent == 0)
ui.economyRecords.rows[2].scripts.OnClick(ui.economyRecords.rows[2])
assert(InfinityLootEconomy:GetBalance() == -200)
assert(ui.economyRecords.rows[3].data.text == "Spent | 200 copper | Vendor | Repair")
local economyTab = { contentArea = CreateFrame("Frame") }
ui:ShowEconomyTab(economyTab)
local negativeBalance
for _, element in ipairs(frames) do
	if element.parent == economyTab.contentArea and element.text == "Balance: -200" then negativeBalance = true end
end
assert(negativeBalance)
ui.economyAmount:SetText(secret)
ui.economyRecords.rows[1].scripts.OnClick(ui.economyRecords.rows[1])
assert(warnings[#warnings]:find("protected", 1, true) and InfinityLootEconomy:GetBalance() == -200)
print = originalPrint
print("loot_auction_runtime: all tests passed")
