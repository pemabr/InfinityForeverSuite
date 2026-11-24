-- Infinity Gear Manager
-- Equipment tracking and comparison

InfinityGearTracker = {
	equipment = {},
	stats = {},
	comparisons = {},
	version = 1,
}

function InfinityGearTracker:Initialize()
	InfinityDataManager:RegisterSource("gear_tracking", function(data) end)
	self:ScanEquipment()
	InfinityUtils:Info("Gear Tracker initialized", "Gear")
end

function InfinityGearTracker:ScanEquipment()
	self.equipment = {}
	
	-- Scan all equipment slots
	local slots = {
		"HeadSlot", "NeckSlot", "ShoulderSlot", "ChestSlot", "WaistSlot", "LegsSlot", 
		"FeetSlot", "WristSlot", "HandsSlot", "FingerSlot", "TrinketSlot", "BackSlot", 
		"MainHandSlot", "SecondaryHandSlot"
	}
	
	for _, slotName in ipairs(slots) do
		local slotID = GetInventorySlotInfo(slotName)
		if slotID then
			local itemLink = GetInventoryItemLink("player", slotID)
			if itemLink then
				local itemID = InfinityUtils:GetItemIDFromHyperlink(itemLink)
				local itemName, _, itemRarity, itemLevel = InfinityUtils:GetItemInfo(itemID or itemLink)
				
				if itemName then
					self.equipment[slotName] = {
						name = itemName,
						itemID = itemID,
						link = itemLink,
						slot = slotName,
						rarity = itemRarity or 0,
						level = itemLevel or 0,
						equippedTime = InfinityUtils:GetTimeStamp(),
					}
				end
			end
		end
	end
	
	self:CalculateStats()
	return self.equipment
end

function InfinityGearTracker:CalculateStats()
	self.stats = {
		totalItems = 0,
		averageILevel = 0,
		rarityBreakdown = {},
		lastUpdated = InfinityUtils:GetTimeStamp(),
	}
	
	local totalILevel = 0
	local iLevelCount = 0
	
	for slot, item in pairs(self.equipment) do
		self.stats.totalItems = self.stats.totalItems + 1
		
		if item.level and item.level > 0 then
			totalILevel = totalILevel + item.level
			iLevelCount = iLevelCount + 1
		end
		
		local rarity = item.rarity or 0
		self.stats.rarityBreakdown[rarity] = (self.stats.rarityBreakdown[rarity] or 0) + 1
	end
	
	if iLevelCount > 0 then
		self.stats.averageILevel = math.floor(totalILevel / iLevelCount)
	end
end

function InfinityGearTracker:GetEquipmentBySlot(slot)
	return self.equipment[slot]
end

function InfinityGearTracker:GetAllEquipment()
	local result = {}
	for slot, item in pairs(self.equipment) do
		table.insert(result, item)
	end
	return result
end

function InfinityGearTracker:GetEquipmentByRarity(rarity)
	local result = {}
	for slot, item in pairs(self.equipment) do
		if item.rarity == rarity then
			table.insert(result, item)
		end
	end
	return result
end

function InfinityGearTracker:CompareItems(item1Link, item2Link)
	local id1 = InfinityUtils:GetItemIDFromHyperlink(item1Link)
	local id2 = InfinityUtils:GetItemIDFromHyperlink(item2Link)
	
	local name1, _, rarity1, level1 = InfinityUtils:GetItemInfo(id1 or item1Link)
	local name2, _, rarity2, level2 = InfinityUtils:GetItemInfo(id2 or item2Link)
	
	local comparison = {
		item1 = {
			name = name1,
			id = id1,
			rarity = rarity1,
			level = level1 or 0,
		},
		item2 = {
			name = name2,
			id = id2,
			rarity = rarity2,
			level = level2 or 0,
		},
		upgrade = (level2 or 0) > (level1 or 0),
		ilevelDiff = (level2 or 0) - (level1 or 0),
	}
	
	return comparison
end

function InfinityGearTracker:GetUpgradeItems()
	-- This would typically compare against known better items
	local upgrades = {}
	
	-- Get current equipment
	local current = self:GetAllEquipment()
	
	-- For now, return items below max level
	local maxLevel = 0
	for _, item in ipairs(current) do
		if item.level and item.level > maxLevel then
			maxLevel = item.level
		end
	end
	
	for _, item in ipairs(current) do
		if item.level and item.level < (maxLevel - 10) then
			table.insert(upgrades, item)
		end
	end
	
	return upgrades
end

function InfinityGearTracker:GetStats()
	return self.stats
end

function InfinityGearTracker:ExportGear()
	return {
		equipment = InfinityUtils:DeepCopy(self.equipment),
		stats = InfinityUtils:DeepCopy(self.stats),
		exportTime = InfinityUtils:GetTimeStamp(),
		character = InfinityCharacterManager:GetCurrentCharacter(),
	}
end

return InfinityGearTracker
