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
		local slotId = GetInventorySlotInfo and GetInventorySlotInfo(slot)
		local itemId = slotId and GetInventoryItemID and GetInventoryItemID("player", slotId)
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
	local rawStats = InfinityUtils:GetItemStats("item:" .. tostring(itemId))
	if type(rawStats) == "table" then
		for stat, weight in pairs(self.stats.weights) do
			local statValue = rawStats[stat]
			if statValue then
				stats[stat] = statValue
			end
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

	-- Classic / WoW Forever Tier 3 BiS item level benchmark (~86)
	local baseScore = math.min(85, (avgIlvl / 86) * 85)
	local enchantBonus = gearCount > 0 and ((enchantedCount / gearCount) * 15) or 0
	self.gearData.optimization = math.min(100, math.floor(baseScore + enchantBonus + 0.5))
end

-- Called when equipment changes
function GearOptimizer:OnEquipmentChanged(slot)
	self:ScanCurrentGear()
	if InfinityMessaging and InfinityMessaging.Publish then
		InfinityMessaging:Publish("gear_optimization_changed", self.gearData.optimization)
	end
end

-- Find real upgrade recommendations based on lowest item-level equipped slots
function GearOptimizer:GetUpgradeRecommendations()
	local recommendations = {}
	for slot, currentItem in pairs(self.gearData.currentGear) do
		if currentItem then
			local ilvl = currentItem.ilvl or 0
			local targetSource = nil
			if ilvl < 55 then
				targetSource = "Level 60 Pre-BiS Dungeons (Stratholme / Scholomance / UBRS)"
			elseif ilvl < 66 then
				targetSource = "Molten Core / Onyxia / Zul'Gurub"
			elseif ilvl < 76 then
				targetSource = "Blackwing Lair / Temple of Ahn'Qiraj (AQ40)"
			elseif ilvl < 85 then
				targetSource = "Naxxramas Tier 3"
			end
			if targetSource then
				table.insert(recommendations, {
					slot = slot,
					currentName = currentItem.name or "Equipped Item",
					currentIlvl = ilvl,
					recommendedSource = targetSource,
					priority = math.max(1, 86 - ilvl),
				})
			end
		end
	end
	table.sort(recommendations, function(a, b) return a.priority > b.priority end)
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
