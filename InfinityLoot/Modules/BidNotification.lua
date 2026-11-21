-- Bid Notification System
-- Notifies players when they're outbid during auctions
-- Provides popups, chat messages, and UI alerts

local BidNotification = {
	config = {
		enableNotifications = true,
		enablePopups = true,
		enableChatNotification = true,
		enableSoundAlert = true,
		popupDuration = 10, -- seconds
		popupPosition = "TopRight", -- TopRight, TopLeft, BottomRight, BottomLeft, Center
		soundFile = 1192703, -- Default UI notification sound
		notifyImmediate = true, -- Notify instantly vs. batch notifications
	},
	
	activePopups = {}, -- {auctionID = popupFrame}
	queuedNotifications = {}, -- Notifications waiting to be shown
	lastNotificationTime = {}, -- Rate limiting per player
}

_G.InfinityBidNotification = BidNotification

function BidNotification:Initialize()
	InfinityUtils:Info("Bid Notification system initialized", "Loot")
	
	-- Create notification frame if doesn't exist
	if not _G.InfinityBidNotificationFrame then
		self:CreateNotificationFrame()
	end
end

function BidNotification:CreateNotificationFrame()
	local frame = CreateFrame("Frame", "InfinityBidNotificationFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetSize(300, 100)
	frame:SetPoint(self.config.popupPosition, 0, -10)
	frame:Hide()
	
	_G.InfinityBidNotificationFrame = frame
end

function BidNotification:NotifyOutbid(auctionID, itemName, yourBid, newBid, outbidBy)
	if not self.config.enableNotifications then return end
	
	-- Rate limit notifications
	local playerName = UnitName("player")
	local now = time()
	if self.lastNotificationTime[playerName] and now - self.lastNotificationTime[playerName] < 2 then
		-- Queue for later
		table.insert(self.queuedNotifications, {
			type = "outbid",
			auctionID = auctionID,
			itemName = itemName,
			yourBid = yourBid,
			newBid = newBid,
			outbidBy = outbidBy,
			timestamp = now,
		})
		return
	end
	
	self.lastNotificationTime[playerName] = now
	
	-- Create notification message
	local message = string.format("You were outbid on %s!\nYour bid: %d, New bid: %d (+%d)",
		itemName, yourBid, newBid, outbidBy)
	
	-- Send to chat if enabled
	if self.config.enableChatNotification then
		print("|cffff6b6b" .. message .. "|r")
	end
	
	-- Show popup if enabled
	if self.config.enablePopups then
		self:ShowPopup(auctionID, itemName, yourBid, newBid)
	end
	
	-- Play sound if enabled
	if self.config.enableSoundAlert then
		PlaySoundFile(self.config.soundFile, "Master")
	end
end

function BidNotification:ShowPopup(auctionID, itemName, yourBid, newBid)
	-- Close existing popup for this auction if any
	if self.activePopups[auctionID] then
		self.activePopups[auctionID]:Hide()
	end
	
	-- Create new popup frame
	local popup = CreateFrame("Frame", "BidNotificationPopup_" .. auctionID, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	popup:SetSize(300, 100)
	popup:SetPoint(self.config.popupPosition, 20, -20)
	popup:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = {left = 11, right = 11, top = 12, bottom = 11}
	})
	popup:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	
	-- Add title
	local title = popup:CreateFontString(nil, "OVERLAY", (GameFontBold and "GameFontBold" or "GameFontNormalLarge"))
	title:SetPoint("TOPLEFT", 15, -15)
	title:SetText("|cffff6b6bOutbid!|r")
	title:SetTextColor(1, 0.42, 0.42)
	
	-- Add item name
	local itemText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	itemText:SetPoint("TOPLEFT", 15, -35)
	itemText:SetText(itemName)
	itemText:SetWidth(270)
	itemText:SetWordWrap(true)
	
	-- Add bid info
	local bidText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	bidText:SetPoint("TOPLEFT", 15, -60)
	bidText:SetText(string.format("Your bid: %d  |  New bid: %d", yourBid, newBid))
	bidText:SetTextColor(1, 1, 0.5)
	
	-- Add close button
	local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function()
		popup:Hide()
		BidNotification.activePopups[auctionID] = nil
	end)
	
	popup:Show()
	self.activePopups[auctionID] = popup
	
	-- Auto-hide after duration
	C_Timer.After(self.config.popupDuration, function()
		if popup:IsShown() then
			popup:Hide()
			BidNotification.activePopups[auctionID] = nil
		end
	end)
end

function BidNotification:NotifyWon(auctionID, itemName, finalBid)
	if not self.config.enableNotifications then return end
	
	-- Create success notification
	local message = string.format("|cff00ff00✓ You won %s for %d!|r", itemName, finalBid)
	print(message)
	
	-- Play success sound
	if self.config.enableSoundAlert then
		PlaySoundFile(1192710, "Master") -- Success sound
	end
	
	-- Show popup
	if self.config.enablePopups then
		self:ShowSuccessPopup(auctionID, itemName, finalBid)
	end
end

function BidNotification:ShowSuccessPopup(auctionID, itemName, finalBid)
	local popup = CreateFrame("Frame", "BidSuccessPopup_" .. auctionID, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	popup:SetSize(300, 80)
	popup:SetPoint(self.config.popupPosition, 20, -20)
	popup:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = {left = 11, right = 11, top = 12, bottom = 11}
	})
	popup:SetBackdropColor(0.1, 0.3, 0.1, 0.9)
	
	local title = popup:CreateFontString(nil, "OVERLAY", (GameFontBold and "GameFontBold" or "GameFontNormalLarge"))
	title:SetPoint("TOPLEFT", 15, -15)
	title:SetText("|cff00ff00✓ Won!|r")
	title:SetTextColor(0.5, 1, 0.5)
	
	local text = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", 15, -35)
	text:SetText(itemName .. " - " .. finalBid .. " points")
	text:SetWidth(270)
	text:SetWordWrap(true)
	
	local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function()
		popup:Hide()
	end)
	
	popup:Show()
	C_Timer.After(self.config.popupDuration, function()
		popup:Hide()
	end)
end

function BidNotification:NotifyAuctionStarted(itemName, startingBid)
	if not self.config.enableChatNotification then return end
	
	print(string.format("|cffffd700Auction started: %s (Starting bid: %d)|r", itemName, startingBid))
end

function BidNotification:NotifyAuctionEnded(itemName, winner, finalBid)
	if not self.config.enableChatNotification then return end
	
	print(string.format("|cffffd700Auction ended: %s won by %s for %d|r", itemName, winner, finalBid))
end

function BidNotification:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Bid Notification config updated: " .. key .. " = " .. tostring(value), "Loot")
	end
end

function BidNotification:SetPopupPosition(position)
	-- Valid positions: TopRight, TopLeft, BottomRight, BottomLeft, Center
	if position:match("^Top") or position:match("^Bottom") or position == "Center" then
		self.config.popupPosition = position
		local frame = _G.InfinityBidNotificationFrame
		if frame then
			frame:ClearAllPoints()
			frame:SetPoint(position, 0, -10)
		end
	end
end

function BidNotification:SetSoundEnabled(enabled)
	self.config.enableSoundAlert = enabled
end

function BidNotification:SetChatNotificationEnabled(enabled)
	self.config.enableChatNotification = enabled
end

function BidNotification:SetPopupEnabled(enabled)
	self.config.enablePopups = enabled
end

function BidNotification:SetPopupDuration(seconds)
	self.config.popupDuration = math.max(1, seconds)
end

function BidNotification:CloseAllPopups()
	for auctionID, popup in pairs(self.activePopups) do
		if popup and popup:IsShown() then
			popup:Hide()
		end
	end
	self.activePopups = {}
end

function BidNotification:PrintConfig()
	print("|cffffd700=== Bid Notification Configuration ===|r")
	print("Enable Notifications: " .. tostring(self.config.enableNotifications))
	print("Enable Popups: " .. tostring(self.config.enablePopups))
	print("Enable Chat Notification: " .. tostring(self.config.enableChatNotification))
	print("Enable Sound Alert: " .. tostring(self.config.enableSoundAlert))
	print("Popup Duration: " .. self.config.popupDuration .. " seconds")
	print("Popup Position: " .. self.config.popupPosition)
end

return BidNotification
