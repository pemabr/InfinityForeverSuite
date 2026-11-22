-- Loot Queue Display System
-- Shows upcoming items in the loot auction queue
-- Displays preview of next items to be auctioned

local LootQueueDisplay = {
	config = {
		enableQueueDisplay = true,
		queueSize = 5, -- Show next 5 items
		updateFrequency = 1.0, -- Update every 1 second
		displayFormat = "compact", -- compact, detailed, tooltip
		sortBy = "time", -- time, rarity, slot
		showImages = true,
		popoutWindow = true,
	},
	
	queueFrame = nil,
	currentQueue = {},
	lastUpdate = 0,
}

_G.InfinityLootQueueDisplay = LootQueueDisplay

function LootQueueDisplay:Initialize()
	InfinityUtils:Info("Loot Queue Display initialized", "Loot")
	
	if self.config.popoutWindow then
		self:CreateQueueWindow()
	end
	
	-- Set up update timer
	C_Timer.NewTicker(self.config.updateFrequency, function()
		LootQueueDisplay:UpdateQueueDisplay()
	end)
end

function LootQueueDisplay:CreateQueueWindow()
	-- Create main frame
	local frame = CreateFrame("Frame", "InfinityLootQueueFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetSize(350, 300)
	frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 200)
	
	if InfinityUIFramework and InfinityUIFramework.ApplyBackdrop then
		InfinityUIFramework:ApplyBackdrop(frame, 0.06, 0.08, 0.12, 0.94, 0.22, 0.30, 0.42, 0.95)
	end
	
	-- Title bar
	local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("TOPLEFT", 10, -10)
	titleText:SetText("|cffffd700Loot Queue|r")
	titleText:SetWidth(300)
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)
	
	-- Create scroll frame for queue items
	local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
	scrollFrame:SetPoint("TOPLEFT", 10, -30)
	scrollFrame:SetSize(330, 260)
	
	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(330, 1)
	scrollFrame:SetScrollChild(content)
	
	-- Add scroll bar
	local scrollBar = CreateFrame("ScrollBar", nil, scrollFrame, "UIPanelScrollBarTemplate")
	scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, -16)
	scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 16)
	scrollFrame:SetScrollBar(scrollBar)
	
	frame:Hide()
	
	self.queueFrame = frame
	self.queueContent = content
	self.queueScroll = scrollFrame
	
	return frame
end

function LootQueueDisplay:UpdateQueueDisplay()
	if not self.config.enableQueueDisplay then return end
	
	local now = time()
	if now - self.lastUpdate < self.config.updateFrequency then return end
	
	self.lastUpdate = now
	
	-- Get current queue from loot system
	self.currentQueue = self:GetCurrentQueue()
	
	if self.queueFrame and self.queueFrame:IsShown() then
		self:RefreshQueueWindow()
	end
end

function LootQueueDisplay:GetCurrentQueue()
	if not InfinityLoot or not InfinityLoot.GetAuctionQueue then
		return {}
	end
	
	local queue = InfinityLoot:GetAuctionQueue()
	local result = {}
	
	-- Get next N items
	for i = 1, math.min(self.config.queueSize, #queue) do
		table.insert(result, {
			index = i,
			item = queue[i],
			timestamp = time(),
		})
	end
	
	return result
end

function LootQueueDisplay:RefreshQueueWindow()
	local content = self.queueContent
	if not content then return end
	
	-- Clear existing items
	for i = 1, #content.queueItems or {} do
		if content.queueItems[i] then
			content.queueItems[i]:Hide()
		end
	end
	content.queueItems = {}
	
	-- Add queue items
	local yOffset = 0
	for i, entry in ipairs(self.currentQueue) do
		local itemFrame = self:CreateQueueItemDisplay(content, entry, yOffset)
		table.insert(content.queueItems, itemFrame)
		yOffset = yOffset - 50
	end
	
	-- Update content size
	content:SetHeight(math.max(300, math.abs(yOffset)))
end

function LootQueueDisplay:CreateQueueItemDisplay(parent, entry, yOffset)
	local itemFrame = CreateFrame("Frame", nil, parent)
	itemFrame:SetSize(320, 45)
	itemFrame:SetPoint("TOPLEFT", 0, yOffset)
	
	-- Background
	itemFrame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		tile = true,
		tileSize = 16,
		insets = {left = 2, right = 2, top = 2, bottom = 2}
	})
	itemFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	
	-- Item number
	local numberText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	numberText:SetPoint("TOPLEFT", 5, -5)
	numberText:SetText("#" .. entry.index)
	numberText:SetTextColor(1, 1, 0.5)
	numberText:SetWidth(30)
	
	-- Item name
	local itemName = entry.item and entry.item.name or "Unknown Item"
	local nameText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("TOPLEFT", 35, -5)
	nameText:SetText(itemName)
	nameText:SetWidth(260)
	nameText:SetWordWrap(false)
	
	-- Rarity color
	local rarity = entry.item and entry.item.rarity or 0
	local rarityColor = self:GetRarityColor(rarity)
	nameText:SetTextColor(rarityColor.r, rarityColor.g, rarityColor.b)
	
	-- Item level/slot info
	local slot = entry.item and entry.item.slot or "Unknown"
	local infoText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
	infoText:SetPoint("TOPLEFT", 35, -20)
	infoText:SetText(slot)
	infoText:SetTextColor(0.7, 0.7, 0.7)
	
	-- Estimated duration
	local durationText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
	durationText:SetPoint("TOPRIGHT", -5, -20)
	durationText:SetText("~" .. (entry.index * 2) .. " min")
	durationText:SetTextColor(0.7, 0.7, 0.7)
	
	return itemFrame
end

function LootQueueDisplay:GetRarityColor(rarity)
	-- WoW rarity colors
	local colors = {
		{r = 0.9, g = 0.9, b = 0.9}, -- Common (white)
		{r = 0.1, g = 1.0, b = 0.1}, -- Uncommon (green)
		{r = 0.0, g = 0.0, b = 1.0}, -- Rare (blue)
		{r = 1.0, g = 0.5, b = 0.0}, -- Epic (purple)
		{r = 1.0, g = 0.8, b = 0.0}, -- Legendary (orange)
		{r = 1.0, g = 0.0, b = 0.0}, -- Artifact (red)
	}
	return colors[rarity + 1] or colors[1]
end

function LootQueueDisplay:ShowQueueWindow()
	if self.queueFrame then
		self.queueFrame:Show()
		self:RefreshQueueWindow()
	end
end

function LootQueueDisplay:HideQueueWindow()
	if self.queueFrame then
		self.queueFrame:Hide()
	end
end

function LootQueueDisplay:ToggleQueueWindow()
	if self.queueFrame then
		if self.queueFrame:IsShown() then
			self:HideQueueWindow()
		else
			self:ShowQueueWindow()
		end
	end
end

function LootQueueDisplay:SetQueueSize(size)
	self.config.queueSize = math.max(1, math.min(10, size))
	self:UpdateQueueDisplay()
end

function LootQueueDisplay:SetUpdateFrequency(seconds)
	self.config.updateFrequency = math.max(0.5, seconds)
end

function LootQueueDisplay:SetSortBy(sortField)
	if sortField == "time" or sortField == "rarity" or sortField == "slot" then
		self.config.sortBy = sortField
		self:UpdateQueueDisplay()
	end
end

function LootQueueDisplay:PrintQueueStatus()
	print("|cffffd700=== Loot Queue Status ===|r")
	print("Queue Display: " .. tostring(self.config.enableQueueDisplay))
	print("Queue Size: " .. self.config.queueSize)
	print("Update Frequency: " .. self.config.updateFrequency .. "s")
	print("Current Queue Items: " .. #self.currentQueue)
	print("")
	
	for i, entry in ipairs(self.currentQueue) do
		local itemName = entry.item and entry.item.name or "Unknown"
		print(string.format("  %d. %s", i, itemName))
	end
end

function LootQueueDisplay:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Loot Queue config updated: " .. key .. " = " .. tostring(value), "Loot")
	end
end

return LootQueueDisplay
