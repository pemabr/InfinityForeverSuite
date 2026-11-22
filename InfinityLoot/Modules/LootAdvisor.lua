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
	local itemId = InfinityUtils:GetItemIDFromLink(itemLink)
	
	if itemId then
		table.insert(self.pendingLoot, {
			itemId = itemId,
			name = itemName or "Unknown",
			link = itemLink,
			quantity = quantity or 1,
			rarity = itemRarity,
			level = itemLevel,
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

-- Get fairness score (priority based on EPGP/DKP balance and recent loot history)
function LootAdvisor:GetFairnessScore(playerName)
	local score = 50
	if _G.InfinityLootEPGP and _G.InfinityLootEPGP.GetPlayerPR then
		local pr = _G.InfinityLootEPGP:GetPlayerPR(playerName)
		if pr and pr > 0 then
			score = math.min(100, pr * 25)
		end
	elseif _G.InfinityDKPEngine and _G.InfinityDKPEngine.GetPlayerPriority then
		local prio = _G.InfinityDKPEngine:GetPlayerPriority(playerName)
		if prio and prio > 0 then
			score = math.min(100, prio * 25)
		end
	end
	if _G.InfinityLootHistory and _G.InfinityLootHistory.lootLog then
		local recentAwards = 0
		local cutoff = time() - (7 * 86400)
		for i = #_G.InfinityLootHistory.lootLog, 1, -1 do
			local e = _G.InfinityLootHistory.lootLog[i]
			if e.timestamp and e.timestamp < cutoff then break end
			if e.playerName == playerName then
				recentAwards = recentAwards + 1
			end
		end
		score = math.max(5, score - (recentAwards * 10))
	end
	return score
end

-- Get performance score (from InfinityPerformanceAnalytics or InfinityDetails)
function LootAdvisor:GetPerformanceScore(playerName)
	if _G.InfinityPerformanceAnalyticsMeter and _G.InfinityPerformanceAnalyticsMeter.players then
		local p = _G.InfinityPerformanceAnalyticsMeter.players[playerName]
		if p and (p.totalDamage or 0) > 0 then
			return math.min(100, 40 + math.log10(p.totalDamage) * 10)
		end
	end
	if _G.InfinityDetailsActor and _G.InfinityDetailsActor.GetActorByName then
		local actor = _G.InfinityDetailsActor:GetActorByName(playerName)
		if actor and ((actor.damage_total or 0) > 0 or (actor.healing_total or 0) > 0) then
			return math.min(100, 40 + math.log10((actor.damage_total or 0) + (actor.healing_total or 0)) * 10)
		end
	end
	return 50
end

-- Get need score based on class armor/role compatibility with the item
function LootAdvisor:GetNeedScore(class, loot)
	local armorByClass = {
		WARRIOR = "Plate", PALADIN = "Plate", DEATHKNIGHT = "Plate",
		HUNTER = "Mail", SHAMAN = "Mail", EVOKER = "Mail",
		ROGUE = "Leather", DRUID = "Leather", MONK = "Leather", DEMONHUNTER = "Leather",
		PRIEST = "Cloth", MAGE = "Cloth", WARLOCK = "Cloth",
	}
	if loot and (loot.link or loot.itemId) then
		local _, _, _, _, _, itemType, itemSubType = InfinityUtils:GetItemInfo(loot.link or loot.itemId)
		if itemType == "Armor" and itemSubType and armorByClass[class] then
			if itemSubType == armorByClass[class] then
				return 90
			elseif itemSubType == "Miscellaneous" or itemSubType == "Rings" or itemSubType == "Neck" or itemSubType == "Trinkets" then
				return 75
			elseif itemSubType == "Cloaks" or itemSubType == "Back" then
				return 70
			else
				return 15
			end
		end
	end
	return 50
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
