-- Mana/Resource Tracker
-- Tracks healer mana and resource consumption

local ResourceTracker = {
	playerResources = {
		mana = 0,
		maxMana = 0,
		manaPercent = 0,
		manaRegenRate = 0, -- per second
		lastManaTime = 0,
		lastManaValue = 0,
	},
	
	raidResources = {}, -- {unitId = {mana, maxMana, manaPercent}}
	
	config = {
		warningThreshold = 20, -- Warn when below 20% mana
		criticalThreshold = 10, -- Critical at 10% mana
		trackRaidMana = true,
		notifyLowMana = true,
	},
	
	stats = {
		averageManaUsage = 0,
		peakManaUsage = 0,
		lowestManaPoint = 100,
		highestManaRegenRate = 0,
	},
}

_G.InfinityResourceTracker = ResourceTracker

-- Initialize resource tracking
function ResourceTracker:Initialize()
	InfinityUtils:Info("Resource tracker initialized", "Healer")
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("UNIT_MANA")
	frame:RegisterEvent("UNIT_MAXMANA")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	
	frame:SetScript("OnEvent", function(f, event, unit)
		if event == "PLAYER_ENTERING_WORLD" then
			ResourceTracker:OnWorldEnter()
		else
			if unit == "player" or unit == "player" then
				ResourceTracker:UpdatePlayerResources()
			elseif string.find(unit, "raid") then
				ResourceTracker:UpdateRaidResources(unit)
			end
		end
	end)
	
	-- Enable periodic tracking
	C_Timer.NewTicker(1.0, function()
		ResourceTracker:UpdatePlayerResources()
		if ResourceTracker.config.trackRaidMana then
			ResourceTracker:ScanRaidResources()
		end
	end)
end

-- Called on world enter
function ResourceTracker:OnWorldEnter()
	self:ResetStats()
	self:UpdatePlayerResources()
end

-- Update player resources
function ResourceTracker:UpdatePlayerResources()
	local newMana = UnitMana("player")
	local maxMana = UnitMaxMana("player")
	local manaPercent = maxMana > 0 and (newMana / maxMana) * 100 or 0
	
	-- Calculate mana regen rate
	if self.playerResources.lastManaTime > 0 then
		local timeDiff = GetTime() - self.playerResources.lastManaTime
		if timeDiff > 0 then
			local manaDiff = newMana - self.playerResources.lastManaValue
			self.playerResources.manaRegenRate = manaDiff / timeDiff
			
			-- Track stats
			self.stats.highestManaRegenRate = math.max(self.stats.highestManaRegenRate, self.playerResources.manaRegenRate)
		end
	end
	
	-- Check mana thresholds
	if manaPercent < self.config.criticalThreshold then
		self:OnCriticalMana(manaPercent)
	elseif manaPercent < self.config.warningThreshold then
		self:OnLowMana(manaPercent)
	end
	
	-- Update stats
	self.stats.lowestManaPoint = math.min(self.stats.lowestManaPoint, manaPercent)
	self.stats.averageManaUsage = (self.stats.averageManaUsage + manaPercent) / 2
	
	-- Update player resources
	self.playerResources.mana = newMana
	self.playerResources.maxMana = maxMana
	self.playerResources.manaPercent = manaPercent
	self.playerResources.lastManaTime = GetTime()
	self.playerResources.lastManaValue = newMana
	
	InfinityMessaging:Publish("player_resource_changed", newMana, maxMana, manaPercent)
end

-- Called when mana is low
function ResourceTracker:OnLowMana(manaPercent)
	if self.config.notifyLowMana then
		InfinityUtils:Warning("Low mana: " .. string.format("%.1f%%", manaPercent), "Healer")
	end
	
	InfinityMessaging:Publish("low_mana", manaPercent)
end

-- Called when mana is critical
function ResourceTracker:OnCriticalMana(manaPercent)
	InfinityUtils:Warning("CRITICAL MANA: " .. string.format("%.1f%%", manaPercent), "Healer")
	InfinityMessaging:Publish("critical_mana", manaPercent)
end

-- Update raid resources
function ResourceTracker:UpdateRaidResources(unit)
	local mana = UnitMana(unit)
	local maxMana = UnitMaxMana(unit)
	local manaPercent = maxMana > 0 and (mana / maxMana) * 100 or 0
	
	self.raidResources[unit] = {
		mana = mana,
		maxMana = maxMana,
		manaPercent = manaPercent,
	}
end

-- Scan all raid members for resources
function ResourceTracker:ScanRaidResources()
	local raidSize = GetNumGroupMembers()
	
	for i = 1, raidSize do
		local unit = "raid" .. i
		self:UpdateRaidResources(unit)
	end
end

-- Get player mana percent
function ResourceTracker:GetPlayerManaPercent()
	return self.playerResources.manaPercent
end

-- Get player mana regen rate
function ResourceTracker:GetManaRegenRate()
	return self.playerResources.manaRegenRate
end

-- Get raid member mana percent
function ResourceTracker:GetRaidManaPercent(unit)
	if self.raidResources[unit] then
		return self.raidResources[unit].manaPercent
	end
	return 0
end

-- Get healers with low mana
function ResourceTracker:GetLowManaHealers()
	local lowMana = {}
	
	for unit, resources in pairs(self.raidResources) do
		if resources.manaPercent < self.config.warningThreshold then
			table.insert(lowMana, {
				unit = unit,
				name = UnitName(unit) or unit,
				manaPercent = resources.manaPercent,
			})
		end
	end
	
	return lowMana
end

-- Get average raid mana
function ResourceTracker:GetAverageRaidMana()
	local totalManaPercent = 0
	local count = 0
	
	for _, resources in pairs(self.raidResources) do
		totalManaPercent = totalManaPercent + resources.manaPercent
		count = count + 1
	end
	
	return count > 0 and (totalManaPercent / count) or 0
end

-- Reset statistics
function ResourceTracker:ResetStats()
	self.stats = {
		averageManaUsage = 0,
		peakManaUsage = 0,
		lowestManaPoint = 100,
		highestManaRegenRate = 0,
	}
end

-- Display resource status
function ResourceTracker:DisplayResources()
	local player = self.playerResources
	
	print("|cffffd700=== RESOURCE STATUS ===|r")
	print("Your Mana: " .. string.format("%.1f%%", player.manaPercent))
	print("  " .. player.mana .. " / " .. player.maxMana)
	print("Mana Regen: " .. string.format("%.1f", player.manaRegenRate) .. " per second")
	
	local lowMana = self:GetLowManaHealers()
	if #lowMana > 0 then
		print("\n|cffff0000Low Mana Healers:|r")
		for _, healer in ipairs(lowMana) do
			print("  " .. healer.name .. ": " .. string.format("%.1f%%", healer.manaPercent))
		end
	end
	
	print("\nAverage Raid Mana: " .. string.format("%.1f%%", self:GetAverageRaidMana()))
	
	print("\n|cffccccccStatistics:|r")
	print("Lowest Mana: " .. string.format("%.1f%%", self.stats.lowestManaPoint))
	print("Highest Regen: " .. string.format("%.1f", self.stats.highestManaRegenRate) .. " per second")
end

-- Estimate time to critical mana
function ResourceTracker:EstimateTimeToCritical()
	local manaPercent = self.playerResources.manaPercent
	local regenRate = self.playerResources.manaRegenRate
	
	if regenRate >= 0 then
		return -1 -- Not losing mana
	end
	
	-- Calculate time to reach critical (10%)
	local criticalPercent = self.config.criticalThreshold
	local maxMana = self.playerResources.maxMana
	local currentMana = self.playerResources.mana
	local criticalMana = (criticalPercent / 100) * maxMana
	
	local manaToDrain = currentMana - criticalMana
	local timeSeconds = manaToDrain / math.abs(regenRate)
	
	return math.max(0, timeSeconds)
end

return ResourceTracker
