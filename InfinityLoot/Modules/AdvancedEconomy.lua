-- InfinityLoot Advanced Economy System
-- Handles item pricing, valuation, multipliers, and economic analysis

InfinityLootAdvancedEconomy = {
	db = {},
	itemPrices = {}, -- itemId -> price
	itemValues = {}, -- Track ascending valuation per item
	slotMultipliers = {}, -- Armor slot -> coefficient
	classMultipliers = {}, -- Class -> coefficient (Plate armor cheaper for Plate wearers)
	rarityMultipliers = {}, -- Rarity -> coefficient
	version = "1.0.0",
}

-- Initialize advanced economy system
function InfinityLootAdvancedEconomy:Initialize()
	InfinityUtils:Info("Advanced Economy system initializing...", "InfinityLoot")
	self.initialized = false
	self.db = InfinityStorageManager:GetFeatureSettings(INFINITY_FEATURES.LOOT)
	if type(self.db) ~= "table" then error("Loot settings are unavailable") end
	for _, key in ipairs({ "itemPrices", "itemValues" }) do
		if self.db[key] == nil then self.db[key] = {} end
		if type(self.db[key]) ~= "table" then error("Invalid saved economy data: " .. key) end
	end
	self.itemPrices = self.db.itemPrices
	self.itemValues = self.db.itemValues
	
	-- Initialize default multipliers
	self:InitializeSlotMultipliers()
	self:InitializeClassMultipliers()
	self:InitializeRarityMultipliers()
	
	self.initialized = true
	InfinityUtils:Info("Advanced Economy system initialized", "InfinityLoot")
end

-- ============================================================================
-- ITEM PRICING SYSTEM
-- ============================================================================

-- Set static price for an item
function InfinityLootAdvancedEconomy:SetItemPrice(itemId, basePrice)
	basePrice = tonumber(basePrice)
	if not itemId or not basePrice or basePrice ~= basePrice or basePrice < 0 or basePrice == math.huge then
		InfinityUtils:Warning("Invalid item price parameters", "Economy")
		return false
	end
	
	self.itemPrices[itemId] = {
		basePrice = basePrice,
		setTime = GetTime(),
		source = "manual",
	}
	if _G.InfinityTooltipPrices then _G.InfinityTooltipPrices:ClearCache() end
	
	InfinityUtils:Debug("Item price set: " .. itemId .. " = " .. basePrice, "Economy")
	return true
end

-- Get item price with all modifiers applied
function InfinityLootAdvancedEconomy:GetItemValue(itemId, slot, class, rarity, armorType)
	if not self.itemPrices[itemId] then
		return 0 -- Default if no price set
	end
	
	local basePrice = self.itemPrices[itemId].basePrice
	
	-- Apply slot multiplier (shields cost more than armor)
	local slotMult = 1.0
	if slot then
		slotMult = self.slotMultipliers[slot] or 1.0
	end
	
	-- Apply class multiplier (plate wearers get plate armor cheaper)
	local classMult = 1.0
	if class and armorType then
		classMult = self:GetClassMultiplier(class, armorType)
	end
	
	-- Apply rarity multiplier
	local rarityMult = 1.0
	if rarity then
		rarityMult = self.rarityMultipliers[rarity] or 1.0
	end
	
	local finalValue = math.floor(basePrice * slotMult * classMult * rarityMult)
	return finalValue
end

-- ============================================================================
-- ASCENDING VALUATION SYSTEM
-- ============================================================================

-- Apply ascending valuation to an item (price increases with each award)
-- Used to prevent bias toward expensive items
function InfinityLootAdvancedEconomy:GetAscendingValue(itemId, awardCount)
	awardCount = awardCount or 0
	
	if not self.itemPrices[itemId] then
		return 0
	end
	
	local basePrice = self.itemPrices[itemId].basePrice
	
	-- Ascending valuation formula:
	-- Award 1 at 50% of base price
	-- Award 2 at 70% of base price
	-- Award 3 at 85% of base price
	-- Award 4+ at 100% of base price
	local multiplier = 1.0
	if awardCount == 1 then
		multiplier = 0.5
	elseif awardCount == 2 then
		multiplier = 0.7
	elseif awardCount == 3 then
		multiplier = 0.85
	else
		multiplier = 1.0
	end
	
	local ascendingValue = math.floor(basePrice * multiplier)
	return ascendingValue
end

-- Record ascending valuation for item
function InfinityLootAdvancedEconomy:RecordItemAward(itemId)
	if not self.itemValues[itemId] then
		self.itemValues[itemId] = {
			awardCount = 0,
			lastAwardTime = 0,
			totalSpent = 0,
		}
	end
	
	self.itemValues[itemId].awardCount = self.itemValues[itemId].awardCount + 1
	self.itemValues[itemId].lastAwardTime = GetTime()
	
	InfinityUtils:Debug("Item award recorded: " .. itemId, "Economy")
	return self.itemValues[itemId].awardCount
end

-- ============================================================================
-- SLOT MULTIPLIERS
-- ============================================================================

function InfinityLootAdvancedEconomy:InitializeSlotMultipliers()
	-- Blizzard item slot names
	self.slotMultipliers = {
		["INVTYPE_HEAD"] = 1.0,
		["INVTYPE_NECK"] = 0.5, -- Neck cheap
		["INVTYPE_SHOULDER"] = 1.0,
		["INVTYPE_BODY"] = 0.3, -- Chest piece (covered by other slots)
		["INVTYPE_CHEST"] = 1.2, -- Chest expensive (main armor)
		["INVTYPE_WAIST"] = 0.8,
		["INVTYPE_LEGS"] = 1.0,
		["INVTYPE_FEET"] = 0.8,
		["INVTYPE_WRIST"] = 0.5,
		["INVTYPE_HAND"] = 1.0,
		["INVTYPE_FINGER"] = 0.5, -- Rings cheap
		["INVTYPE_TRINKET"] = 0.6, -- Trinkets lower value
		["INVTYPE_BACK"] = 0.4, -- Cloak very cheap
		["INVTYPE_2HWEAPON"] = 1.5, -- 2H weapons expensive
		["INVTYPE_WEAPON"] = 1.2, -- Main hand weapon
		["INVTYPE_SHIELD"] = 1.4, -- Shields expensive
		["INVTYPE_RANGED"] = 1.1, -- Ranged weapon
		["INVTYPE_RELIC"] = 0.6, -- Relic slots
	}
end

-- ============================================================================
-- CLASS MULTIPLIERS
-- ============================================================================

function InfinityLootAdvancedEconomy:InitializeClassMultipliers()
	-- Players of a specific class can equip their armor type cheaper
	self.classMultipliers = {
		["Warrior"] = { ["PLATE"] = 0.8, ["MAIL"] = 1.0, ["LEATHER"] = 1.0, ["CLOTH"] = 1.0 },
		["Paladin"] = { ["PLATE"] = 0.8, ["MAIL"] = 1.0, ["LEATHER"] = 1.0, ["CLOTH"] = 1.0 },
		["Hunter"] = { ["MAIL"] = 0.8, ["PLATE"] = 1.0, ["LEATHER"] = 1.0, ["CLOTH"] = 1.0 },
		["Rogue"] = { ["LEATHER"] = 0.8, ["PLATE"] = 1.0, ["MAIL"] = 1.0, ["CLOTH"] = 1.0 },
		["Priest"] = { ["CLOTH"] = 0.8, ["PLATE"] = 1.0, ["MAIL"] = 1.0, ["LEATHER"] = 1.0 },
		["Deathknight"] = { ["PLATE"] = 0.8, ["MAIL"] = 1.0, ["LEATHER"] = 1.0, ["CLOTH"] = 1.0 },
		["Shaman"] = { ["MAIL"] = 0.8, ["PLATE"] = 1.0, ["LEATHER"] = 1.0, ["CLOTH"] = 1.0 },
		["Mage"] = { ["CLOTH"] = 0.8, ["PLATE"] = 1.0, ["MAIL"] = 1.0, ["LEATHER"] = 1.0 },
		["Warlock"] = { ["CLOTH"] = 0.8, ["PLATE"] = 1.0, ["MAIL"] = 1.0, ["LEATHER"] = 1.0 },
		["Druid"] = { ["LEATHER"] = 0.8, ["PLATE"] = 1.0, ["MAIL"] = 1.0, ["CLOTH"] = 1.0 },
		["Monk"] = { ["LEATHER"] = 0.8, ["PLATE"] = 1.0, ["MAIL"] = 1.0, ["CLOTH"] = 1.0 },
		["Demon Hunter"] = { ["LEATHER"] = 0.8, ["PLATE"] = 1.0, ["MAIL"] = 1.0, ["CLOTH"] = 1.0 },
	}
end

-- Get class multiplier for armor type
function InfinityLootAdvancedEconomy:GetClassMultiplier(class, armorType)
	if not self.classMultipliers[class] then
		return 1.0
	end
	
	return self.classMultipliers[class][armorType] or 1.0
end

-- ============================================================================
-- RARITY MULTIPLIERS
-- ============================================================================

function InfinityLootAdvancedEconomy:InitializeRarityMultipliers()
	self.rarityMultipliers = {
		["Trash"] = 0.5, -- Gray items
		["Common"] = 0.7, -- White
		["Uncommon"] = 0.9, -- Green
		["Rare"] = 1.2, -- Blue
		["Epic"] = 1.5, -- Purple
		["Legendary"] = 2.0, -- Orange
		["Artifact"] = 2.5, -- Green text
	}
end

-- ============================================================================
-- RANGE-BASED PRICING (Min/Max Per Slot)
-- ============================================================================

-- Set min/max price range for a specific slot
function InfinityLootAdvancedEconomy:SetSlotPriceRange(slot, minPrice, maxPrice)
	if not self.db.slotRanges then
		self.db.slotRanges = {}
	end
	
	self.db.slotRanges[slot] = {
		minPrice = minPrice,
		maxPrice = maxPrice,
		setTime = GetTime(),
	}
	
	InfinityUtils:Debug("Slot price range set: " .. slot .. " (" .. minPrice .. "-" .. maxPrice .. ")", "Economy")
	return true
end

-- Set min/max price range for specific item
function InfinityLootAdvancedEconomy:SetItemPriceRange(itemId, minPrice, maxPrice)
	if not self.db.itemRanges then
		self.db.itemRanges = {}
	end
	
	self.db.itemRanges[itemId] = {
		minPrice = minPrice,
		maxPrice = maxPrice,
		setTime = GetTime(),
	}
	
	InfinityUtils:Debug("Item price range set: " .. itemId .. " (" .. minPrice .. "-" .. maxPrice .. ")", "Economy")
	return true
end

-- Get price with range enforcement
function InfinityLootAdvancedEconomy:GetItemValueWithRange(itemId, slot)
	local value = self:GetItemValue(itemId, slot)
	
	-- Check item-specific range
	if self.db.itemRanges and self.db.itemRanges[itemId] then
		local range = self.db.itemRanges[itemId]
		if value < range.minPrice then
			value = range.minPrice
		elseif value > range.maxPrice then
			value = range.maxPrice
		end
	end
	
	-- Check slot range
	if self.db.slotRanges and self.db.slotRanges[slot] then
		local range = self.db.slotRanges[slot]
		if value < range.minPrice then
			value = range.minPrice
		elseif value > range.maxPrice then
			value = range.maxPrice
		end
	end
	
	return value
end

-- ============================================================================
-- ECONOMY ANALYSIS
-- ============================================================================

-- Get economy statistics
function InfinityLootAdvancedEconomy:GetEconomyStats()
	local stats = {
		totalItemsTracked = 0,
		totalValueAwarded = 0,
		averageItemValue = 0,
		mostExpensiveItem = nil,
		cheapestItem = nil,
		slotStats = {},
	}
	
	local totalValue = 0
	local maxValue = 0
	local minValue = math.huge
	local maxItemId = nil
	local minItemId = nil
	
	for itemId, priceData in pairs(self.itemPrices) do
		stats.totalItemsTracked = stats.totalItemsTracked + 1
		local price = priceData.basePrice
		totalValue = totalValue + price
		
		if price > maxValue then
			maxValue = price
			maxItemId = itemId
		end
		if price < minValue then
			minValue = price
			minItemId = itemId
		end
	end
	
	if stats.totalItemsTracked > 0 then
		stats.averageItemValue = math.floor(totalValue / stats.totalItemsTracked)
		stats.mostExpensiveItem = maxItemId
		stats.cheapestItem = minItemId
		stats.totalValueAwarded = totalValue
	end
	
	return stats
end

-- Get suggested price based on rarity and slot
function InfinityLootAdvancedEconomy:SuggestPrice(rarity, slot)
	-- Base prices by rarity
	local rarityBase = {
		["Trash"] = 0,
		["Common"] = 5,
		["Uncommon"] = 15,
		["Rare"] = 50,
		["Epic"] = 150,
		["Legendary"] = 500,
		["Artifact"] = 1000,
	}
	
	local basePrice = rarityBase[rarity] or 50
	
	-- Apply slot multiplier
	local slotMult = self.slotMultipliers[slot] or 1.0
	
	local suggestedPrice = math.floor(basePrice * slotMult)
	return suggestedPrice
end

-- ============================================================================
-- TRANSACTION LEDGER
-- ============================================================================

-- Record an economic transaction
function InfinityLootAdvancedEconomy:RecordTransaction(playerName, itemId, amount, type)
	if not self.db.transactions then
		self.db.transactions = {}
	end
	
	local transaction = {
		playerName = playerName,
		itemId = itemId,
		amount = amount,
		type = type, -- "award", "cost", "adjustment"
		timestamp = GetTime(),
		source = "manual",
	}
	
	table.insert(self.db.transactions, transaction)
	
	-- Update item tracking
	if type == "cost" and self.itemValues[itemId] then
		self.itemValues[itemId].totalSpent = self.itemValues[itemId].totalSpent + amount
	end
	
	InfinityUtils:Debug("Transaction recorded: " .. playerName .. " " .. type, "Economy")
	return true
end

-- Get transaction history
function InfinityLootAdvancedEconomy:GetTransactionHistory(playerName, limit)
	if not self.db.transactions then
		return {}
	end
	
	limit = limit or 50
	local history = {}
	
	for i = #self.db.transactions, math.max(1, #self.db.transactions - limit + 1), -1 do
		local trans = self.db.transactions[i]
		if playerName == nil or trans.playerName == playerName then
			table.insert(history, trans)
		end
	end
	
	return history
end

-- ============================================================================
-- DATA EXPORT & IMPORT
-- ============================================================================

-- Export economy data
function InfinityLootAdvancedEconomy:ExportData()
	return {
		itemPrices = InfinityUtils:DeepCopy(self.itemPrices),
		itemValues = InfinityUtils:DeepCopy(self.itemValues),
		slotMultipliers = InfinityUtils:DeepCopy(self.slotMultipliers),
		classMultipliers = InfinityUtils:DeepCopy(self.classMultipliers),
		rarityMultipliers = InfinityUtils:DeepCopy(self.rarityMultipliers),
		transactions = self.db.transactions and InfinityUtils:DeepCopy(self.db.transactions) or {},
		exportTime = GetTime(),
	}
end

-- Import economy data
function InfinityLootAdvancedEconomy:ImportData(data)
	if type(data) ~= "table"
		or (data.itemPrices ~= nil and type(data.itemPrices) ~= "table")
		or (data.itemValues ~= nil and type(data.itemValues) ~= "table")
		or (data.transactions ~= nil and type(data.transactions) ~= "table") then
		InfinityUtils:Warning("Invalid economy import data", "Economy")
		return false
	end
	
	self.itemPrices = data.itemPrices or self.itemPrices
	self.itemValues = data.itemValues or self.itemValues
	self.db.itemPrices = self.itemPrices
	self.db.itemValues = self.itemValues
	self.db.transactions = data.transactions or {}
	if _G.InfinityTooltipPrices then _G.InfinityTooltipPrices:ClearCache() end
	
	InfinityUtils:Info("Economy data imported", "Economy")
	return true
end

-- ============================================================================
-- PERFORMANCE MONITORING
-- ============================================================================

function InfinityLootAdvancedEconomy:GetStats()
	return {
		itemsTracked = #self.itemPrices,
		transactionCount = self.db.transactions and #self.db.transactions or 0,
		slotRanges = self.db.slotRanges and #self.db.slotRanges or 0,
		itemRanges = self.db.itemRanges and #self.db.itemRanges or 0,
	}
end

return InfinityLootAdvancedEconomy
