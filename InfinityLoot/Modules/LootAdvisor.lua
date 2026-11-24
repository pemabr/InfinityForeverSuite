-- Loot Advisor Module
-- Provides real-time loot decisions and fair distribution recommendations

local LootAdvisor = {
	pendingLoot = {}, -- {itemId = {name, quantity, priority}}
	
	config = {
		enableRecommendations = true,
		fairnessWeight = 0.5, -- 0-1, how much to weight fair distribution
		performanceWeight = 0.3, -- How much to weight performance metrics
		needWeight = 0.2, -- How much to weight item need/usefulness
	},
	
	stats = {
		itemsAwarded = 0,
		totalValue = 0,
		fairnessScore = 0,
	},
}

_G.InfinityLootAdvisor = LootAdvisor

-- Initialize loot advisor
function LootAdvisor:Initialize()
	InfinityUtils:Info("Loot advisor initialized", "Loot")
	
	-- Subscribe to loot events
	InfinityMessaging:Subscribe("loot_opened", function(itemLink, quantity)
		LootAdvisor:OnLootOpened(itemLink, quantity)
	end)
	
	InfinityMessaging:Subscribe("loot_awarded", function(player, item, value)
		LootAdvisor:OnLootAwarded(player, item, value)
	end)
end

-- Called when loot is opened
function LootAdvisor:OnLootOpened(itemLink, quantity)
	if not itemLink then
		return
	end
	
	local itemName, _, itemRarity, itemLevel = InfinityUtils:GetItemInfo(itemLink)
	local itemId = InfinityUtils:GetItemIDFromHyperlink(itemLink)
	
	if itemId or itemName then
		table.insert(self.pendingLoot, {
			itemId = itemId,
			name = itemName or itemLink,
			link = itemLink,
			quantity = quantity or 1,
			rarity = itemRarity or 1,
			level = itemLevel or 0,
		})
	end
end

-- Called when loot is awarded
function LootAdvisor:OnLootAwarded(player, item, value)
	-- Remove from pending
	for i, loot in ipairs(self.pendingLoot) do
		if loot.name == item then
			table.remove(self.pendingLoot, i)
			break
		end
	end
	
	-- Update stats
	self.stats.itemsAwarded = self.stats.itemsAwarded + 1
	self.stats.totalValue = self.stats.totalValue + value
end

-- Get loot recommendations
function LootAdvisor:GetRecommendations()
	if not self.config.enableRecommendations or #self.pendingLoot == 0 then
		return {}
	end
	
	local recommendations = {}
	
	for _, loot in ipairs(self.pendingLoot) do
		local candidates = self:GetCandidates(loot)
		if #candidates > 0 then
			table.insert(recommendations, {
				item = loot,
				candidate = candidates[1],
				alternatives = self:GetAlternatives(candidates),
				score = candidates[1].score,
			})
		end
	end
	
	return recommendations
end

-- Get candidates for item
function LootAdvisor:GetCandidates(loot)
	local candidates = {}
	
	-- Get raid members
	local raidSize = GetNumGroupMembers()
	for i = 1, raidSize do
		local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		
		if name and online and not isDead then
			local score = self:CalculateScore(name, class, loot)
			
			table.insert(candidates, {
				name = name,
				class = class,
				role = role,
				score = score,
			})
		end
	end
	
	-- Sort by score (highest first)
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)
	
	return candidates
end

-- Calculate priority score for candidate
function LootAdvisor:CalculateScore(playerName, class, loot)
	local fairnessComponent = self:GetFairnessScore(playerName) * self.config.fairnessWeight
	local performanceComponent = self:GetPerformanceScore(playerName) * self.config.performanceWeight
	local needComponent = self:GetNeedScore(class, loot) * self.config.needWeight
	
	return fairnessComponent + performanceComponent + needComponent
end

-- Get fairness score (priority based on real EPGP PR or DKP balance)
function LootAdvisor:GetFairnessScore(playerName)
	if _G.InfinityDKPEngine and _G.InfinityDKPEngine.GetPlayer then
		local p = _G.InfinityDKPEngine:GetPlayer(playerName)
		if p then
			local pr = _G.InfinityDKPEngine.CalculatePR and _G.InfinityDKPEngine:CalculatePR(playerName) or 0
			if pr and pr > 0 then
				return math.min(100, pr * 25)
			end
			return math.min(100, math.max(10, (p.dkp or p.ep or 50) * 0.25))
		end
	end
	return 50
end

-- Get performance score (derived from live InfinityDetails combat meters)
function LootAdvisor:GetPerformanceScore(playerName)
	if _G.InfinityDetailsActor and _G.InfinityDetailsActor.GetAllActors then
		local best = 1
		local mine = 0
		for _, actor in pairs(_G.InfinityDetailsActor:GetAllActors()) do
			local total = (actor.damage_total or 0) + (actor.healing_total or 0)
			if total > best then best = total end
			if actor.name == playerName then mine = total end
		end
		if mine > 0 then
			return math.min(100, (mine / best) * 100)
		end
	end
	return 50
end

-- Get need score (class armor & weapon usability match)
function LootAdvisor:GetNeedScore(class, loot)
	local cls = string.upper(tostring(class or ""))
	local itemSubType = loot and loot.itemSubType or nil
	if not itemSubType and loot and loot.itemLink then
		local _, _, _, _, _, _, subType = InfinityUtils:GetItemInfo(loot.itemLink)
		itemSubType = subType
	end

	local preferredArmor = {
		WARRIOR = "Plate", PALADIN = "Plate",
		HUNTER = "Mail", SHAMAN = "Mail",
		ROGUE = "Leather", DRUID = "Leather",
		PRIEST = "Cloth", MAGE = "Cloth", WARLOCK = "Cloth",
	}

	if itemSubType and preferredArmor[cls] then
		if itemSubType == preferredArmor[cls] then
			return 90
		elseif itemSubType == "Miscellaneous" or itemSubType == "Cloaks" then
			return 70
		end
	end
	return 55
end

-- Get alternative candidates
function LootAdvisor:GetAlternatives(candidates)
	local alternatives = {}
	
	for i = 2, math.min(3, #candidates) do
		table.insert(alternatives, candidates[i])
	end
	
	return alternatives
end

-- Display recommendations
function LootAdvisor:DisplayRecommendations()
	local recommendations = self:GetRecommendations()
	
	if #recommendations == 0 then
		print("No pending loot or recommendations")
		return
	end
	
	print("|cffffd700=== LOOT ADVISOR RECOMMENDATIONS ===|r")
	
	for _, rec in ipairs(recommendations) do
		print("\n|cffcccccc" .. rec.item.name .. "|r")
		print("  Recommended: " .. rec.candidate.name .. " (" .. rec.candidate.class .. ")")
		print("  Score: " .. string.format("%.1f", rec.score))
		
		if #rec.alternatives > 0 then
			print("  Alternatives:")
			for _, alt in ipairs(rec.alternatives) do
				print("    - " .. alt.name .. " (" .. alt.class .. ")")
			end
		end
	end
end

-- Get distribution statistics
function LootAdvisor:GetStats()
	return {
		itemsAwarded = self.stats.itemsAwarded,
		totalValue = self.stats.totalValue,
		averageValue = self.stats.itemsAwarded > 0 and (self.stats.totalValue / self.stats.itemsAwarded) or 0,
		fairnessScore = self.stats.fairnessScore,
	}
end

-- Display advisor status
function LootAdvisor:DisplayStatus()
	local stats = self:GetStats()
	
	print("|cffffd700=== LOOT ADVISOR STATUS ===|r")
	print("Items Awarded: " .. stats.itemsAwarded)
	print("Total Value: " .. InfinityUtils:FormatNumber(stats.totalValue))
	print("Average Value: " .. InfinityUtils:FormatNumber(stats.averageValue))
	print("Fairness Score: " .. string.format("%.1f%%", stats.fairnessScore))
end

return LootAdvisor
