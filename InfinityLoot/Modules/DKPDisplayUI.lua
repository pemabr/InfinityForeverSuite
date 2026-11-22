-- DKP UI Display Module
-- Handles visual components for DKP auctions: bid bars, popups, queues, leaderboards

local InfinityDKPUI = {}
_G.InfinityDKPUI = InfinityDKPUI

-- Configuration
InfinityDKPUI.config = {
	enableBidBars = true,
	enablePopups = true,
	enableLootQueue = true,
	enableLeaderboard = true,
	enableAntiSnipeCountdown = true,
	maxQueueItems = 10,
	updateFrequency = 0.1, -- seconds
}

-- UI State
InfinityDKPUI.bidBars = {} -- {itemId = frame}
InfinityDKPUI.popups = {} -- Active notification popups
InfinityDKPUI.lootQueueFrame = nil
InfinityDKPUI.leaderboardFrame = nil
InfinityDKPUI.mainWindow = nil

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize DKP UI system
function InfinityDKPUI:Initialize()
	InfinityUtils:Info("DKP UI System initialized", "DKP UI")
	
	-- Create main window frame (initially hidden)
	self:CreateMainWindow()
	
	-- Register for auction events
	InfinityMessaging:Subscribe(INFINITY_EVENTS.DATA_CHANGED, function(source, action, data)
		if source == "dkp" or source == "auction" then
			InfinityDKPUI:OnAuctionDataChanged(action, data)
		end
	end)
end

-- ============================================================================
-- MAIN WINDOW
-- ============================================================================

--- Create main DKP UI window
function InfinityDKPUI:CreateMainWindow()
	if self.mainWindow then
		return
	end
	
	local frame = CreateFrame("Frame", "InfinityDKPMainWindow", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(800, 600)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	
	frame:SetTitle("Infinity DKP System")
	
	-- Create tabs
	self:CreateMainWindowTabs(frame)
	
	self.mainWindow = frame
end

--- Create tab system for main window
function InfinityDKPUI:CreateMainWindowTabs(parentFrame)
	-- Tab container
	local tabFrame = CreateFrame("Frame", nil, parentFrame)
	tabFrame:SetSize(780, 30)
	tabFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -35)
	
	-- Tabs: Standing, Auction, History, Settings
	local tabs = {"Standing", "Auction", "History", "Settings"}
	local tabButtons = {}
	
	for i, tabName in ipairs(tabs) do
		local button = CreateFrame("Button", nil, tabFrame)
		button:SetSize(100, 25)
		button:SetPoint("TOPLEFT", tabFrame, "TOPLEFT", (i-1) * 110, 0)
		
		-- Simple button text (would use proper button template in production)
		local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("CENTER", button, "CENTER")
		text:SetText(tabName)
		
		button:SetScript("OnClick", function()
			InfinityDKPUI:SelectTab(tabName)
		end)
		
		tabButtons[tabName] = button
	end
	
	parentFrame.tabs = tabButtons
end

--- Select main window tab
function InfinityDKPUI:SelectTab(tabName)
	if tabName == "Standing" then
		self:ShowLeaderboard()
	elseif tabName == "Auction" then
		self:ShowAuctionCenter()
	elseif tabName == "History" then
		self:ShowLootHistory()
	elseif tabName == "Settings" then
		self:ShowSettings()
	end
end

--- Toggle main window visibility
function InfinityDKPUI:ToggleWindow()
	if self.mainWindow then
		if self.mainWindow:IsShown() then
			self.mainWindow:Hide()
		else
			self.mainWindow:Show()
		end
	end
end

-- ============================================================================
-- BID BARS
-- ============================================================================

--- Create bid bar for auction item
-- @param itemId: number
-- @param currentBid: number (DKP)
-- @param bidCount: number
-- @return frameReference: frame
function InfinityDKPUI:CreateBidBar(itemId, currentBid, bidCount)
	local barFrame = CreateFrame("Frame", nil, UIParent)
	barFrame:SetSize(300, 25)
	
	-- Background
	barFrame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4}
	})
	barFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	barFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
	
	-- Current bid display
	local bidText = barFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	bidText:SetPoint("LEFT", barFrame, "LEFT", 10, 0)
	bidText:SetText("Bid: " .. currentBid .. " DKP (" .. bidCount .. " bids)")
	
	-- Bid progress bar (visual indicator)
	local progressBar = CreateFrame("StatusBar", nil, barFrame)
	progressBar:SetSize(150, 15)
	progressBar:SetPoint("RIGHT", barFrame, "RIGHT", -10, 0)
	progressBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	progressBar:SetStatusBarColor(0.2, 0.8, 0.2, 1) -- Green
	
	-- Set value (0-100 scale relative to max possible bid)
	local normalizedBid = math.min(currentBid / 500, 1) -- Normalize to 500 DKP max
	progressBar:SetValue(normalizedBid * 100)
	
	-- Store metadata
	barFrame.itemId = itemId
	barFrame.bidText = bidText
	barFrame.progressBar = progressBar
	barFrame.currentBid = currentBid
	barFrame.bidCount = bidCount
	
	self.bidBars[itemId] = barFrame
	
	return barFrame
end

--- Update bid bar display
-- @param itemId: number
-- @param newBid: number
-- @param newBidCount: number
function InfinityDKPUI:UpdateBidBar(itemId, newBid, newBidCount)
	local bar = self.bidBars[itemId]
	if not bar then
		return
	end
	
	-- Update text
	bar.bidText:SetText("Bid: " .. newBid .. " DKP (" .. newBidCount .. " bids)")
	
	-- Update progress
	local normalizedBid = math.min(newBid / 500, 1)
	bar.progressBar:SetValue(normalizedBid * 100)
	
	-- Change color based on intensity (green -> yellow -> red)
	if normalizedBid < 0.3 then
		bar.progressBar:SetStatusBarColor(0.2, 0.8, 0.2, 1) -- Green
	elseif normalizedBid < 0.7 then
		bar.progressBar:SetStatusBarColor(1, 0.8, 0.2, 1) -- Yellow
	else
		bar.progressBar:SetStatusBarColor(0.8, 0.2, 0.2, 1) -- Red
	end
	
	bar.currentBid = newBid
	bar.bidCount = newBidCount
end

--- Remove bid bar
-- @param itemId: number
function InfinityDKPUI:RemoveBidBar(itemId)
	local bar = self.bidBars[itemId]
	if bar then
		bar:Hide()
		bar = nil
		self.bidBars[itemId] = nil
	end
end

-- ============================================================================
-- NOTIFICATION POPUPS
-- ============================================================================

--- Show outbid notification popup
-- @param playerName: string
-- @param itemName: string
-- @param newBid: number
function InfinityDKPUI:ShowOutbidPopup(playerName, itemName, newBid)
	if not self.config.enablePopups then
		return
	end
	
	local popup = CreateFrame("Frame", nil, UIParent)
	popup:SetSize(300, 50)
	popup:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -100)
	
	-- Set backdrop
	popup:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4}
	})
	popup:SetBackdropColor(0.8, 0.2, 0.2, 0.9)
	popup:SetBackdropBorderColor(1, 1, 1, 1)
	
	-- Text
	local text = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", popup, "CENTER")
	text:SetText("OUTBID!\n" .. playerName .. " bid " .. newBid .. " DKP\nfor " .. itemName)
	text:SetJustifyH("CENTER")
	
	-- Auto-fade
	local elapsed = 0
	popup:SetScript("OnUpdate", function(f, delta)
		elapsed = elapsed + delta
		if elapsed > 5 then
			f:FadeOut(0.5, function()
				f:Hide()
				table.remove(InfinityDKPUI.popups, table.find(InfinityDKPUI.popups, f) or 0)
			end)
		end
	end)
	
	table.insert(self.popups, popup)
	popup:Show()
end

--- Show bid update notification
-- @param message: string
-- @param color: table {r, g, b}
function InfinityDKPUI:ShowNotification(message, color)
	color = color or {r = 0.2, g = 0.8, b = 0.2}
	
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(300, 30)
	frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -50 - (#self.popups * 60))
	
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4}
	})
	frame:SetBackdropColor(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.8)
	frame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
	
	-- Text
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", frame, "CENTER")
	text:SetText(message)
	
	-- Auto-fade
	local elapsed = 0
	frame:SetScript("OnUpdate", function(f, delta)
		elapsed = elapsed + delta
		if elapsed > 3 then
			f:FadeOut(0.3, function()
				f:Hide()
				table.remove(InfinityDKPUI.popups, table.find(InfinityDKPUI.popups, f) or 0)
			end)
		end
	end)
	
	table.insert(self.popups, frame)
	frame:Show()
end

-- ============================================================================
-- LOOT QUEUE DISPLAY
-- ============================================================================

--- Create loot queue display frame
function InfinityDKPUI:CreateLootQueueFrame()
	if self.lootQueueFrame then
		return
	end
	
	local frame = CreateFrame("Frame", "InfinityLootQueue", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(400, 300)
	frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -150)
	frame:SetTitle("Loot Queue")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	
	-- Scroll list for queue items
	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetSize(380, 250)
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
	
	local listFrame = CreateFrame("Frame", nil, scrollFrame)
	listFrame:SetSize(380, 1) -- Height will be adjusted dynamically
	scrollFrame:SetScrollChild(listFrame)
	
	frame.scrollFrame = scrollFrame
	frame.listFrame = listFrame
	
	self.lootQueueFrame = frame
	
	return frame
end

--- Update loot queue display
-- @param queueItems: table (array of {itemName, currentBid, timeRemaining})
function InfinityDKPUI:UpdateLootQueue(queueItems)
	if not self.lootQueueFrame then
		self:CreateLootQueueFrame()
	end
	
	local listFrame = self.lootQueueFrame.listFrame
	
	-- Clear existing items
	for i = #listFrame, 1, -1 do
		listFrame[i]:Hide()
		listFrame[i] = nil
	end
	
	-- Add new items
	local yOffset = 0
	for i, item in ipairs(queueItems) do
		if i > self.config.maxQueueItems then
			break
		end
		
		local itemFrame = CreateFrame("Frame", nil, listFrame)
		itemFrame:SetSize(380, 25)
		itemFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -yOffset)
		
		itemFrame:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		})
		itemFrame:SetBackdropColor(0.05 + (i * 0.05), 0.05, 0.1, 0.5)
		
		-- Item number and name
		local text = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("LEFT", itemFrame, "LEFT", 5, 0)
		text:SetText("#" .. i .. ": " .. (item.itemName or "Unknown"))
		
		-- Current bid
		local bidText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		bidText:SetPoint("CENTER", itemFrame, "CENTER")
		bidText:SetText("Bid: " .. (item.currentBid or 0) .. " DKP")
		
		-- Time remaining
		local timeText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		timeText:SetPoint("RIGHT", itemFrame, "RIGHT", -5, 0)
		timeText:SetText(math.floor(item.timeRemaining or 0) .. "s")
		
		yOffset = yOffset + 30
		table.insert(listFrame, itemFrame)
	end
	
	-- Adjust list frame height
	listFrame:SetHeight(math.max(yOffset, 1))
end

--- Show loot queue window
function InfinityDKPUI:ShowLootQueue()
	if not self.lootQueueFrame then
		self:CreateLootQueueFrame()
	end
	self.lootQueueFrame:Show()
end

--- Hide loot queue window
function InfinityDKPUI:HideLootQueue()
	if self.lootQueueFrame then
		self.lootQueueFrame:Hide()
	end
end

-- ============================================================================
-- LEADERBOARD DISPLAY
-- ============================================================================

--- Create leaderboard frame
function InfinityDKPUI:CreateLeaderboardFrame()
	if self.leaderboardFrame then
		return
	end
	
	local frame = CreateFrame("Frame", "InfinityLeaderboard", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(500, 400)
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -150)
	frame:SetTitle("DKP Leaderboard")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	
	-- Scroll list for players
	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetSize(480, 350)
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -35)
	
	local listFrame = CreateFrame("Frame", nil, scrollFrame)
	listFrame:SetSize(480, 1)
	scrollFrame:SetScrollChild(listFrame)
	
	frame.scrollFrame = scrollFrame
	frame.listFrame = listFrame
	
	self.leaderboardFrame = frame
	
	return frame
end

--- Update leaderboard display
-- @param players: table (array of {name, dkp, spent, rank})
function InfinityDKPUI:UpdateLeaderboard(players)
	if not self.leaderboardFrame then
		self:CreateLeaderboardFrame()
	end
	
	local listFrame = self.leaderboardFrame.listFrame
	
	-- Clear existing
	for i = #listFrame, 1, -1 do
		listFrame[i]:Hide()
		listFrame[i] = nil
	end
	
	-- Add players
	local yOffset = 0
	for rank, player in ipairs(players) do
		local playerFrame = CreateFrame("Frame", nil, listFrame)
		playerFrame:SetSize(480, 25)
		playerFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -yOffset)
		
		-- Gradient background based on rank
		local color = {r = 0.1, g = 0.1, b = 0.1}
		if rank == 1 then
			color = {r = 0.8, g = 0.6, b = 0.1} -- Gold for #1
		elseif rank == 2 then
			color = {r = 0.6, g = 0.6, b = 0.6} -- Silver for #2
		elseif rank == 3 then
			color = {r = 0.8, g = 0.4, b = 0.0} -- Bronze for #3
		end
		
		playerFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
		playerFrame:SetBackdropColor(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.6)
		
		-- Rank and name
		local rankText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		rankText:SetPoint("LEFT", playerFrame, "LEFT", 5, 0)
		rankText:SetText(rank .. ". " .. (player.name or "Unknown") .. " (" .. (player.class or "?") .. ")")
		rankText:SetWidth(200)
		rankText:SetJustifyH("LEFT")
		
		-- DKP
		local dkpText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		dkpText:SetPoint("CENTER", playerFrame, "CENTER", 100, 0)
		dkpText:SetText(player.dkp or 0)
		
		-- Spent
		local spentText = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		spentText:SetPoint("RIGHT", playerFrame, "RIGHT", -5, 0)
		spentText:SetText("Spent: " .. (player.spent or 0))
		
		yOffset = yOffset + 30
		table.insert(listFrame, playerFrame)
	end
	
	-- Adjust height
	listFrame:SetHeight(math.max(yOffset, 1))
end

--- Show leaderboard
function InfinityDKPUI:ShowLeaderboard()
	if not self.leaderboardFrame then
		self:CreateLeaderboardFrame()
	end
	
	-- Get current standings
	if InfinityLootEPGP and InfinityLootEPGP.playerStats then
		local players = {}
		for playerName, stats in pairs(InfinityLootEPGP.playerStats) do
			table.insert(players, {
				name = playerName,
				dkp = stats.dkp or 0,
				spent = stats.spent or 0,
			})
		end
		
		-- Sort by DKP (highest first)
		table.sort(players, function(a, b)
			return a.dkp > b.dkp
		end)
		
		self:UpdateLeaderboard(players)
	end
	
	self.leaderboardFrame:Show()
end

-- ============================================================================
-- ANTI-SNIPE COUNTDOWN
-- ============================================================================

--- Create anti-snipe countdown display
-- @param itemId: number
-- @param timeRemaining: number (seconds)
-- @return frameReference: frame
function InfinityDKPUI:CreateAntiSnipeCountdown(itemId, timeRemaining)
	if not self.config.enableAntiSnipeCountdown then
		return nil
	end
	
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(100, 30)
	
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4}
	})
	
	-- Countdown text
	local countdownText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	countdownText:SetPoint("CENTER", frame, "CENTER")
	countdownText:SetText(math.ceil(timeRemaining))
	
	frame.itemId = itemId
	frame.countdownText = countdownText
	frame.timeRemaining = timeRemaining
	frame.elapsed = 0
	
	-- Update countdown
	frame:SetScript("OnUpdate", function(f, delta)
		f.elapsed = f.elapsed + delta
		f.timeRemaining = f.timeRemaining - delta
		
		if f.elapsed >= 0.1 then
			f.elapsed = 0
			local displayTime = math.ceil(f.timeRemaining)
			f.countdownText:SetText(displayTime)
			
			-- Change color as time runs out
			local color = {r = 0.2, g = 0.8, b = 0.2}
			if displayTime <= 3 then
				color = {r = 0.8, g = 0.2, b = 0.2} -- Red
			elseif displayTime <= 10 then
				color = {r = 0.8, g = 0.8, b = 0.2} -- Yellow
			end
			
			f.countdownText:SetTextColor(color.r, color.g, color.b)
		end
		
		if f.timeRemaining <= 0 then
			f:Hide()
			InfinityDKPUI.bidBars[f.itemId] = nil
		end
	end)
	
	return frame
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

--- Handle auction data changes
function InfinityDKPUI:OnAuctionDataChanged(action, data)
	if action == "bid_placed" then
		self:OnBidPlaced(data)
	elseif action == "outbid" then
		self:OnOutbid(data)
	elseif action == "auction_closed" then
		self:OnAuctionClosed(data)
	elseif action == "queue_updated" then
		self:OnQueueUpdated(data)
	elseif action == "standings_updated" then
		self:OnStandingsUpdated(data)
	end
end

--- Handle bid placed event
function InfinityDKPUI:OnBidPlaced(data)
	self:UpdateBidBar(data.itemId, data.bid, data.bidCount)
	
	if data.isPlayerBid then
		self:ShowNotification("Bid accepted: " .. data.bid .. " DKP", {r = 0.2, g = 0.8, b = 0.2})
	end
end

--- Handle outbid event
function InfinityDKPUI:OnOutbid(data)
	self:ShowOutbidPopup(data.outbidder, data.itemName, data.newBid)
end

--- Handle auction closed event
function InfinityDKPUI:OnAuctionClosed(data)
	self:RemoveBidBar(data.itemId)
	self:ShowNotification("Sold to " .. data.winner .. " for " .. data.finalBid .. " DKP", {r = 0.8, g = 0.6, b = 0.2})
end

--- Handle queue updated event
function InfinityDKPUI:OnQueueUpdated(data)
	if self.lootQueueFrame and self.lootQueueFrame:IsShown() then
		self:UpdateLootQueue(data.queueItems)
	end
end

--- Handle standings updated event
function InfinityDKPUI:OnStandingsUpdated(data)
	if self.leaderboardFrame and self.leaderboardFrame:IsShown() then
		self:ShowLeaderboard()
	end
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get display color for award type
-- @param awardType: string ("MS", "OS", "OFFSPEC", "BANK")
-- @return color: table {r, g, b}
function InfinityDKPUI:GetAwardColor(awardType)
	if awardType == "MS" then
		return {r = 0.2, g = 0.8, b = 0.2} -- Green
	elseif awardType == "OS" then
		return {r = 0.8, g = 0.8, b = 0.2} -- Yellow
	elseif awardType == "OFFSPEC" then
		return {r = 0.8, g = 0.4, b = 0.2} -- Orange
	else
		return {r = 0.6, g = 0.6, b = 0.6} -- Gray (Bank)
	end
end

--- Format DKP value for display
-- @param value: number
-- @return formatted: string
function InfinityDKPUI:FormatDKP(value)
	if value >= 1000 then
		return string.format("%.1fk", value / 1000)
	else
		return tostring(math.floor(value))
	end
end

return InfinityDKPUI
