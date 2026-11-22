-- Tooltip Price Information System
-- Displays item values on tooltips in-game
-- Shows baseline prices, ascending values, and player GP cost

local TooltipPrices = {
	config = {
		enableTooltipPrices = true,
		showBasellePrice = true,
		showAscendingValue = true,
		showPlayerCost = true,
		priceColor = "|cffffd700", -- Gold color
		tooltipPosition = "right", -- right, left, bottom
	},
	
	itemPriceCache = {}, -- {itemID = {base = n, ascending = n, lastUpdate = time}}
}

_G.InfinityTooltipPrices = TooltipPrices

function TooltipPrices:Initialize()
	InfinityUtils:Info("Tooltip Prices system initialized", "Loot")
	
	-- Hook tooltips
	GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
		TooltipPrices:OnTooltipSetItem(tooltip)
	end)
	
	ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
		TooltipPrices:OnTooltipSetItem(tooltip)
	end)
end

function TooltipPrices:OnTooltipSetItem(tooltip)
	if not self.config.enableTooltipPrices then return end
	
	local name, link = tooltip:GetItem()
	if not link then return end
	
	-- Extract item ID from link
	local itemID = self:ExtractItemID(link)
	if not itemID then return end
	
	-- Get price info
	local priceInfo = self:GetItemPriceInfo(itemID)
	if not priceInfo then return end
	
	-- Add tooltip lines
	self:AddPriceLinesToTooltip(tooltip, itemID, priceInfo)
end

function TooltipPrices:ExtractItemID(link)
	-- Extract from |cff9d9d9d|Hitem:12345:0:0:0:0:0:0:0:85:0|h[Item Name]|h|r
	if not link then return nil end
	
	local itemID = link:match("|Hitem:(%d+):")
	return tonumber(itemID)
end

function TooltipPrices:GetItemPriceInfo(itemID)
	-- Check cache first
	local cached = self.itemPriceCache[itemID]
	if cached and (time() - cached.lastUpdate) < 300 then
		return cached
	end
	
	-- Query InfinityLoot for prices
	local basePrice = 0
	local ascendingValue = 0
	
	if InfinityLoot and InfinityLoot.GetItemBasePrice then
		basePrice = InfinityLoot:GetItemBasePrice(itemID) or 0
	end
	
	if InfinityLoot and InfinityLoot.GetItemAscendingValue then
		ascendingValue = InfinityLoot:GetItemAscendingValue(itemID) or 0
	end
	
	-- Cache result
	self.itemPriceCache[itemID] = {
		base = basePrice,
		ascending = ascendingValue,
		lastUpdate = time(),
	}
	
	return self.itemPriceCache[itemID]
end

function TooltipPrices:AddPriceLinesToTooltip(tooltip, itemID, priceInfo)
	-- Add empty line separator
	tooltip:AddLine(" ")
	
	-- Add base price
	if self.config.showBasellePrice and priceInfo.base > 0 then
		tooltip:AddLine(self.config.priceColor .. "Base Price: " .. priceInfo.base .. " GP|r")
	end
	
	-- Add ascending value
	if self.config.showAscendingValue and priceInfo.ascending > 0 then
		local ascendingStr = self.config.priceColor .. "Ascending: " .. priceInfo.ascending .. " GP|r"
		if priceInfo.ascending > priceInfo.base then
			ascendingStr = self.config.priceColor .. "Ascending: " .. priceInfo.ascending .. " GP (+inflation)|r"
		end
		tooltip:AddLine(ascendingStr)
	end
	
	-- Add player cost (if player in guild)
	if self.config.showPlayerCost then
		local playerCost = self:CalculatePlayerCost(itemID, priceInfo)
		if playerCost and playerCost > 0 then
			tooltip:AddLine(self.config.priceColor .. "Your Cost: " .. playerCost .. " GP|r")
		end
	end
	
	tooltip:Show()
end

function TooltipPrices:CalculatePlayerCost(itemID, priceInfo)
	local playerName = UnitName("player")
	local memberData = InfinityGuildRoster:GetMember(playerName)
	
	if not memberData then return 0 end
	
	-- Get player's class
	local playerClass = select(2, UnitClass("player"))
	
	-- Apply class discount if applicable
	local costMultiplier = 1.0
	
	-- Check if item is wearable by player class
	-- This is a simplified check; real implementation would check armor/item class
	
	local baseCost = priceInfo.ascending or priceInfo.base
	return math.floor(baseCost * costMultiplier)
end

function TooltipPrices:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Tooltip Prices config updated: " .. key .. " = " .. tostring(value), "Loot")
	end
end

function TooltipPrices:ClearCache()
	self.itemPriceCache = {}
	InfinityUtils:Info("Tooltip price cache cleared", "Loot")
end

function TooltipPrices:PrintConfig()
	print("|cffffd700=== Tooltip Prices Configuration ===|r")
	print("Enable Tooltip Prices: " .. tostring(self.config.enableTooltipPrices))
	print("Show Base Price: " .. tostring(self.config.showBasellePrice))
	print("Show Ascending Value: " .. tostring(self.config.showAscendingValue))
	print("Show Player Cost: " .. tostring(self.config.showPlayerCost))
	print("Color: " .. self.config.priceColor .. "Gold|r")
	print("Position: " .. self.config.tooltipPosition)
end

return TooltipPrices
