-- Gear Optimizer Module
-- Analyzes gear, recommends upgrades, and tracks optimization score

local GearOptimizer = {
	config = {
		enableRecommendations = true,
		minimumIlvlIncrease = 2,
		considerStats = true,
		considerEnchants = true,
		considerGems = true,
	},
	
	gearData = {
		currentGear = {}, -- {slot = {id, ilvl, stats}}
		availableUpgrades = {},
		optimization = 0, -- 0-100 score
	},
	
	stats = {
		weights = {
			["STRENGTH"] = 1.0,
			["AGILITY"] = 1.0,
			["STAMINA"] = 0.5,
			["INTELLECT"] = 1.0,
			["SPIRIT"] = 0.3,
			["ARMOR"] = 0.1,
		},
	},
}

_G.InfinityGearOptimizer = GearOptimizer

-- Initialize gear optimizer
function GearOptimizer:Initialize()
	InfinityUtils:Info("Gear optimizer initialized", "Gear")
	
	-- Subscribe to equipment change events
	InfinityMessaging:Subscribe("player_equipment_changed", function(slot)
		GearOptimizer:OnEquipmentChanged(slot)
	end)
	
	-- Subscribe to level up
	InfinityMessaging:Subscribe("player_level_changed", function()
		GearOptimizer:RefreshAnalysis()
	end)
	
	-- Initial scan
	C_Timer.After(2, function()
		GearOptimizer:ScanCurrentGear()
	end)
end

-- Scan current gear
function GearOptimizer:ScanCurrentGear()
	local slots = {
		"HeadSlot", "NeckSlot", "ShoulderSlot", "ChestSlot", "WaistSlot",
		"LegsSlot", "FeetSlot", "WristSlot", "HandsSlot", "FingerSlot0",
		"FingerSlot1", "TrinketSlot0", "TrinketSlot1", "BackSlot", "MainHandSlot", "SecondaryHandSlot"
	}
	
	self.gearData.currentGear = {}
	
	for _, slot in ipairs(slots) do
		local itemId = GetInventoryItemID("player", GetInventorySlotInfo(slot))
		if itemId then
			local itemName, itemLink, rarity, ilvl, minLevel, itemType = InfinityUtils:GetItemInfo(itemId)
			local stats = self:GetItemStats(itemId)
			
			self.gearData.currentGear[slot] = {
				id = itemId,
				name = itemName,
				ilvl = ilvl,
				rarity = rarity,
				type = itemType,
				stats = stats,
			}
		end
	end
	
	self:CalculateOptimizationScore()
end

-- Get item stats
function GearOptimizer:GetItemStats(itemId)
	local stats = {}
	
	for stat, weight in pairs(self.stats.weights) do
		local rawStats = InfinityUtils:GetItemStats("item:" .. itemId)
		local statValue = type(rawStats) == "table" and rawStats[stat] or nil
		if statValue then
			stats[stat] = statValue
		end
	end
	
	return stats
end

-- Calculate optimization score
function GearOptimizer:CalculateOptimizationScore()
	-- Score based on:
	-- - Item level average
	-- - Stat distribution
	-- - Enchantment coverage
	-- - Gem coverage
	
	local totalIlvl = 0
	local gearCount = 0
	local enchantedCount = 0
	local gemmedCount = 0
	
	for slot, item in pairs(self.gearData.currentGear) do
		if item then
			totalIlvl = totalIlvl + (item.ilvl or 0)
			gearCount = gearCount + 1
			
			-- Check if enchanted (would require additional API calls)
			-- Check if has gems (would require additional API calls)
		end
	end
	
	local avgIlvl = gearCount > 0 and (totalIlvl / gearCount) or 0
	
	-- Score formula: 0-100 scaled against Forever current tier baseline
	self.gearData.optimization = math.min(100, math.floor((avgIlvl / 500) * 100 + 0.5))
end

-- Called when equipment changes
function GearOptimizer:OnEquipmentChanged(slot)
	self:ScanCurrentGear()
	InfinityMessaging:Publish("gear_optimization_changed", self.gearData.optimization)
end

-- Find upgrade recommendations by scanning player bags for higher iLvl items matching slot equipLoc
function GearOptimizer:GetUpgradeRecommendations()
	local recommendations = {}
	local slotByEquipLoc = {
		INVTYPE_HEAD = "HeadSlot",
		INVTYPE_NECK = "NeckSlot",
		INVTYPE_SHOULDER = "ShoulderSlot",
		INVTYPE_CHEST = "ChestSlot",
		INVTYPE_ROBE = "ChestSlot",
		INVTYPE_WAIST = "WaistSlot",
		INVTYPE_LEGS = "LegsSlot",
		INVTYPE_FEET = "FeetSlot",
		INVTYPE_WRIST = "WristSlot",
		INVTYPE_HAND = "HandsSlot",
		INVTYPE_FINGER = "Finger0Slot",
		INVTYPE_TRINKET = "Trinket0Slot",
		INVTYPE_CLOAK = "BackSlot",
		INVTYPE_WEAPON = "MainHandSlot",
		INVTYPE_2HWEAPON = "MainHandSlot",
		INVTYPE_WEAPONMAINHAND = "MainHandSlot",
		INVTYPE_WEAPONOFFHAND = "SecondaryHandSlot",
		INVTYPE_SHIELD = "SecondaryHandSlot",
		INVTYPE_HOLDABLE = "SecondaryHandSlot",
	}
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, InfinityUtils:GetBagSlots(bag) do
			local link = InfinityUtils:GetBagItemLink(bag, slot)
			if link then
				local name, _, rarity, ilvl, _, _, _, _, equipLoc = InfinityUtils:GetItemInfo(link)
				local targetSlot = equipLoc and slotByEquipLoc[equipLoc]
				local equipped = targetSlot and self.gearData.currentGear[targetSlot]
				if targetSlot and ilvl and (not equipped or ilvl > (equipped.ilvl or 0)) then
					table.insert(recommendations, {
						slot = targetSlot,
						itemName = name,
						itemLink = link,
						ilvl = ilvl,
						rarity = rarity,
						ilvlGain = ilvl - (equipped and equipped.ilvl or 0),
						source = "bag",
					})
				end
			end
		end
	end
	table.sort(recommendations, function(a, b) return (a.ilvlGain or 0) > (b.ilvlGain or 0) end)
	return recommendations
end

-- Get gear analysis
function GearOptimizer:GetAnalysis()
	return {
		optimization = self.gearData.optimization,
		averageIlvl = self:GetAverageIlvl(),
		gearCount = InfinityUtils:TableSize(self.gearData.currentGear),
		recommendations = self:GetUpgradeRecommendations(),
	}
end

-- Get average item level
function GearOptimizer:GetAverageIlvl()
	local totalIlvl = 0
	local count = 0
	
	for slot, item in pairs(self.gearData.currentGear) do
		if item and item.ilvl then
			totalIlvl = totalIlvl + item.ilvl
			count = count + 1
		end
	end
	
	return count > 0 and (totalIlvl / count) or 0
end

-- Refresh analysis
function GearOptimizer:RefreshAnalysis()
	self:ScanCurrentGear()
	InfinityUtils:Info("Gear analysis refreshed", "Gear")
end

-- Display gear analysis
function GearOptimizer:DisplayAnalysis()
	local analysis = self:GetAnalysis()
	
	print("|cffffd700=== GEAR OPTIMIZATION ===|r")
	print("Optimization Score: " .. string.format("%.1f%%", analysis.optimization))
	print("Average Item Level: " .. string.format("%.1f", analysis.averageIlvl))
	print("Gear Pieces: " .. analysis.gearCount)
	
	if #analysis.recommendations > 0 then
		print("\n|cffccccccUpgrade Recommendations:|r")
		for i, rec in ipairs(analysis.recommendations) do
			print(string.format("  %d. %s (Ilvl: %d → %d)", i, rec.name, rec.currentIlvl, rec.recommendedIlvl))
		end
	else
		print("\n|cff00ff00No upgrades available|r")
	end
end

-- Set stat weights
function GearOptimizer:SetStatWeights(weights)
	for stat, weight in pairs(weights) do
		self.stats.weights[stat] = weight
	end
	
	self:RefreshAnalysis()
	InfinityUtils:Info("Gear stat weights updated", "Gear")
end

return GearOptimizer
