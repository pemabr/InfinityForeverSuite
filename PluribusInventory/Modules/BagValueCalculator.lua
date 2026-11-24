-- Bag Value Calculator
-- Calculates total inventory value using price API integrations

local BagValueCalculator = {
	cachedValues = {},
	totalValue = 0,
	updateInterval = 5, -- Update every 5 seconds
	lastUpdate = 0,
	enableCache = true,
	cacheTTL = 60, -- Cache prices for 60 seconds
}

_G.PluribusBagValueCalculator = BagValueCalculator

local function SafeGetContainerNumSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then
		return C_Container.GetContainerNumSlots(bag) or 0
	elseif GetContainerNumSlots then
		return GetContainerNumSlots(bag) or 0
	end
	return 0
end

local function SafeGetSlotInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if type(info) == "table" then
			return info.iconFileID, info.stackCount or 1, info.hyperlink
		end
		return nil, 0, nil
	elseif GetContainerItemInfo then
		local texture, count = GetContainerItemInfo(bag, slot)
		local link = GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
		return texture, count or 1, link
	end
	return nil, 0, nil
end

-- Initialize calculator
function BagValueCalculator:Initialize()
	PluribusUtils:Info("Bag value calculator initialized", "Inventory")
	
	-- Register for bag update events
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("BAG_UPDATE")
	frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
	frame:RegisterEvent("ITEM_LOCK_CHANGED")
	
	frame:SetScript("OnEvent", function(f, event, bagId)
		BagValueCalculator:OnBagUpdate(bagId)
	end)
	
	-- Register update loop
	self:RegisterUpdateLoop()
end

-- Register update loop
function BagValueCalculator:RegisterUpdateLoop()
	local frame = CreateFrame("Frame")
	frame:SetScript("OnUpdate", function(self, elapsed)
		BagValueCalculator:OnUpdate(elapsed)
	end)
end

-- Handle bag updates
function BagValueCalculator:OnBagUpdate(bagId)
	-- Schedule value recalculation
	self.lastUpdate = self.updateInterval + 1 -- Force update on next OnUpdate
end

-- Main update loop
function BagValueCalculator:OnUpdate(elapsed)
	self.lastUpdate = self.lastUpdate + elapsed
	
	if self.lastUpdate < self.updateInterval then
		return
	end
	
	self.lastUpdate = 0
	
	-- Scan bags and calculate value
	self:CalculateInventoryValue()
end

-- Calculate total inventory value
function BagValueCalculator:CalculateInventoryValue()
	local totalValue = 0
	local itemCount = 0
	
	if not PluribusBagTracker then
		return 0
	end
	
	-- Scan all bags
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, SafeGetContainerNumSlots(bag) do
			local texture, count, itemLink = SafeGetSlotInfo(bag, slot)
			if texture and itemLink then
				local value = self:GetItemValue(itemLink)
				totalValue = totalValue + (value * (count or 1))
				itemCount = itemCount + 1
			end
		end
	end
	
	self.totalValue = totalValue
	
	PluribusMessaging:Publish("inventory_value_changed", totalValue, itemCount)
	
	return totalValue
end

-- Get single item value
function BagValueCalculator:GetItemValue(itemLink)
	if not itemLink then
		return 0
	end
	
	-- Check cache first
	if self.enableCache and self.cachedValues[itemLink] then
		local cached = self.cachedValues[itemLink]
		if GetTime() - cached.time < self.cacheTTL then
			return cached.value
		end
	end
	
	-- Extract item ID from link
	local itemId = tonumber(itemLink:match("item:(%d+)"))
	if not itemId then
		return 0
	end
	
	local value = 0
	
	-- Try TSM prices first (most accurate)
	if _G.TSM and _G.TSM.Utils and _G.TSM.Utils.GetItemPrice then
		value = _G.TSM.Utils.GetItemPrice("DBMarket", itemId) or 0
	end
	
	-- Fallback to Auctionator
	if value == 0 and _G.Auctionator then
		value = _G.Auctionator.API.v1.GetAuctionPrice(itemId) or 0
	end
	
	-- Fallback to Auctioneer
	if value == 0 and _G.AucAdvanced then
		value = _G.AucAdvanced.API.GetMarketPrice(itemId) or 0
	end
	
	-- Fallback to vendor price (11th return value of GetItemInfo is sellPrice)
	if value == 0 then
		local _, _, _, _, _, _, _, _, _, _, vendorPrice = PluribusUtils:GetItemInfo(itemLink)
		value = vendorPrice or 0
	end
	
	-- Cache the value
	if self.enableCache then
		self.cachedValues[itemLink] = {
			value = value,
			time = GetTime(),
		}
	end
	
	return value
end

-- Get total inventory value in copper
function BagValueCalculator:GetTotalValue()
	return self.totalValue
end

-- Format value as gold/silver/copper
function BagValueCalculator:FormatValue(copperAmount)
	local gold = math.floor(copperAmount / 10000)
	local silver = math.floor((copperAmount % 10000) / 100)
	local copper = copperAmount % 100
	
	if gold > 0 then
		return string.format("|cffffd700%dg|r |cffc7b377%ds|r |cffeda55f%dc|r", gold, silver, copper)
	elseif silver > 0 then
		return string.format("|cffc7b377%ds|r |cffeda55f%dc|r", silver, copper)
	else
		return string.format("|cffeda55f%dc|r", copper)
	end
end

-- Get inventory value breakdown by quality
function BagValueCalculator:GetValueByQuality()
	local breakdown = {
		[0] = 0, -- Poor (gray)
		[1] = 0, -- Common (white)
		[2] = 0, -- Uncommon (green)
		[3] = 0, -- Rare (blue)
		[4] = 0, -- Epic (purple)
		[5] = 0, -- Legendary (orange)
		[6] = 0, -- Artifact
	}
	
	-- Scan all bags
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, SafeGetContainerNumSlots(bag) do
			local texture, count, itemLink = SafeGetSlotInfo(bag, slot)
			if texture and itemLink then
				local _, _, quality = PluribusUtils:GetItemInfo(itemLink)
				if quality then
					local value = self:GetItemValue(itemLink)
					breakdown[quality] = (breakdown[quality] or 0) + (value * (count or 1))
				end
			end
		end
	end
	
	return breakdown
end

-- Compare bag values over time
function BagValueCalculator:GetValueTrend(timeWindow)
	timeWindow = timeWindow or 3600 -- Default 1 hour
	
	-- This would require persistent data storage
	-- For now, return current value
	return self.totalValue
end

-- Get items above value threshold
function BagValueCalculator:GetValueableItems(minValue)
	local items = {}
	
	-- Scan all bags
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, SafeGetContainerNumSlots(bag) do
			local texture, count, itemLink = SafeGetSlotInfo(bag, slot)
			if texture and itemLink then
				local value = self:GetItemValue(itemLink)
				if value >= minValue then
					table.insert(items, {
						link = itemLink,
						value = value,
						count = count or 1,
						totalValue = value * (count or 1),
						bag = bag,
						slot = slot,
					})
				end
			end
		end
	end
	
	-- Sort by value
	table.sort(items, function(a, b)
		return a.totalValue > b.totalValue
	end)
	
	return items
end

-- Get items by profession requirement
function BagValueCalculator:GetItemsByProfession(profession)
	local items = {}
	
	-- This would require profession database
	-- For now, return empty list
	
	return items
end

-- Clear price cache
function BagValueCalculator:ClearCache()
	self.cachedValues = {}
end

-- Set cache TTL
function BagValueCalculator:SetCacheTTL(ttl)
	self.cacheTTL = ttl
end

-- Display inventory value
function BagValueCalculator:DisplayValue()
	local value = self:GetTotalValue()
	local formatted = self:FormatValue(value)
	
	print("Inventory Value: " .. formatted)
	
	-- Show breakdown by quality
	local breakdown = self:GetValueByQuality()
	print("Breakdown by quality:")
	local qualities = {"Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact"}
	for quality = 0, 6 do
		if breakdown[quality] > 0 then
			print("  " .. qualities[quality + 1] .. ": " .. self:FormatValue(breakdown[quality]))
		end
	end
	
	-- Show top items
	local top = self:GetValueableItems(1000) -- Items worth 10+ silver
	if #top > 0 then
		print("Top items by value:")
		for i = 1, math.min(5, #top) do
			local item = top[i]
			print("  " .. item.link .. " x" .. item.count .. " = " .. self:FormatValue(item.totalValue))
		end
	end
end

return BagValueCalculator
