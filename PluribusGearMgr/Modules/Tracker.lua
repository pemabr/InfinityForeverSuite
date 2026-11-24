-- Pluribus Gear Manager
-- Equipment tracking and comparison

PluribusGearTracker = {
	equipment = {},
	stats = {},
	comparisons = {},
	version = 1,
}

function PluribusGearTracker:Initialize()
	PluribusDataManager:RegisterSource("gear_tracking", function(data) end)
	self:ScanEquipment()
	PluribusUtils:Info("Gear Tracker initialized", "Gear")
end

function PluribusGearTracker:ScanEquipment()
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
				local itemID = PluribusUtils:GetItemIDFromHyperlink(itemLink)
				local itemName, _, itemRarity, itemLevel = PluribusUtils:GetItemInfo(itemID or itemLink)
				
				if itemName then
					self.equipment[slotName] = {
						name = itemName,
						itemID = itemID,
						link = itemLink,
						slot = slotName,
						rarity = itemRarity or 0,
						level = itemLevel or 0,
						equippedTime = PluribusUtils:GetTimeStamp(),
					}
				end
			end
		end
	end
	
	self:CalculateStats()
	return self.equipment
end

function PluribusGearTracker:CalculateStats()
	self.stats = {
		totalItems = 0,
		averageILevel = 0,
		rarityBreakdown = {},
		lastUpdated = PluribusUtils:GetTimeStamp(),
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

function PluribusGearTracker:GetEquipmentBySlot(slot)
	return self.equipment[slot]
end

function PluribusGearTracker:GetAllEquipment()
	local result = {}
	for slot, item in pairs(self.equipment) do
		table.insert(result, item)
	end
	return result
end

function PluribusGearTracker:GetEquipmentByRarity(rarity)
	local result = {}
	for slot, item in pairs(self.equipment) do
		if item.rarity == rarity then
			table.insert(result, item)
		end
	end
	return result
end

function PluribusGearTracker:CompareItems(item1Link, item2Link)
	local id1 = PluribusUtils:GetItemIDFromHyperlink(item1Link)
	local id2 = PluribusUtils:GetItemIDFromHyperlink(item2Link)
	
	local name1, _, rarity1, level1 = PluribusUtils:GetItemInfo(id1 or item1Link)
	local name2, _, rarity2, level2 = PluribusUtils:GetItemInfo(id2 or item2Link)
	
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

function PluribusGearTracker:GetUpgradeItems()
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

function PluribusGearTracker:GetStats()
	return self.stats
end

function PluribusGearTracker:ExportGear()
	return {
		equipment = PluribusUtils:DeepCopy(self.equipment),
		stats = PluribusUtils:DeepCopy(self.stats),
		exportTime = PluribusUtils:GetTimeStamp(),
		character = PluribusCharacterManager:GetCurrentCharacter(),
	}
end

return PluribusGearTracker
