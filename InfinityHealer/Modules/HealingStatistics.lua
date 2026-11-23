-- Healing Statistics Tracker
-- Tracks healing done, overhealing, efficiency, and spell usage

local HealingStats = {
	sessionStats = {
		totalHealing = 0,
		totalOverhealing = 0,
		totalAbsorb = 0,
		spellCount = {},
		playerHealing = {}, -- {playerName = totalHealing}
		playerOverhealing = {},
		startTime = 0,
		raidSize = 0,
	},
	
	config = {
		trackSpells = true,
		trackPlayers = true,
		trackCriticals = true,
		minHealValue = 0,
	},
	
	spellDatabase = {}, -- {spellId = {name, cost, castTime, cooldown}}
}

_G.InfinityHealingStats = HealingStats

-- Initialize healing tracker
function HealingStats:Initialize()
	InfinityUtils:Info("Healing stats tracker initialized", "Healer")
	
	-- Register for combat log events
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then
			HealingStats:OnCombatLogEvent(...)
		elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
			HealingStats:ResetSession()
		end
	end)
	
	self:ResetSession()
end

-- Reset session statistics
function HealingStats:ResetSession()
	self.sessionStats = {
		totalHealing = 0,
		totalOverhealing = 0,
		totalAbsorb = 0,
		spellCount = {},
		playerHealing = {},
		playerOverhealing = {},
		startTime = GetTime(),
		raidSize = GetNumGroupMembers(),
	}
end

-- Handle combat log events
function HealingStats:OnCombatLogEvent(timestamp, subevent, hideCaster, casterGUID, casterName, casterFlags, casterRaidFlags, targetGUID, targetName, targetFlags, targetRaidFlags, ...)
	-- Only track our own heals
	if casterGUID ~= UnitGUID("player") then
		return
	end
	
	-- Track different healing events
	if subevent == "SPELL_HEAL" then
		self:OnSpellHeal(casterName, targetName, ...)
	elseif subevent == "SPELL_ABSORBED" then
		self:OnSpellAbsorbed(casterName, targetName, ...)
	elseif subevent == "SPELL_CAST_SUCCESS" then
		self:OnSpellCast(casterName, ...)
	end
end

-- Track healing spell cast
function HealingStats:OnSpellHeal(casterName, targetName, spellId, spellName, spellSchool, amount, overhealing, absorb, critical, glyphBonus, ...)
	-- Update spell count
	if not self.sessionStats.spellCount[spellName] then
		self.sessionStats.spellCount[spellName] = {
			casts = 0,
			healing = 0,
			overhealing = 0,
			crits = 0,
			avgCast = 0,
		}
	end
	
	local stats = self.sessionStats.spellCount[spellName]
	stats.casts = stats.casts + 1
	stats.healing = stats.healing + amount
	stats.overhealing = stats.overhealing + overhealing
	
	if critical then
		stats.crits = stats.crits + 1
	end
	
	-- Update total session stats
	self.sessionStats.totalHealing = self.sessionStats.totalHealing + amount
	self.sessionStats.totalOverhealing = self.sessionStats.totalOverhealing + overhealing
	
	-- Update player healing stats
	if not self.sessionStats.playerHealing[targetName] then
		self.sessionStats.playerHealing[targetName] = 0
		self.sessionStats.playerOverhealing[targetName] = 0
	end
	
	self.sessionStats.playerHealing[targetName] = self.sessionStats.playerHealing[targetName] + amount
	self.sessionStats.playerOverhealing[targetName] = self.sessionStats.playerOverhealing[targetName] + overhealing
	
	InfinityMessaging:Publish("heal_cast", targetName, spellName, amount, overhealing, critical)
end

-- Track spell absorb
function HealingStats:OnSpellAbsorbed(casterName, targetName, spellId, spellName, spellSchool, absorbAmount, spellAbsorbCaster, spellAbsorbName, ...)
	self.sessionStats.totalAbsorb = self.sessionStats.totalAbsorb + absorbAmount
	
	InfinityMessaging:Publish("heal_absorbed", targetName, spellAbsorbName, absorbAmount)
end

-- Track spell cast (for mana tracking, cooldowns)
function HealingStats:OnSpellCast(casterName, spellId, spellName, ...)
	-- Store spell info if we don't have it
	if spellId and not self.spellDatabase[spellId] then
		local icon, castTime, cooldown, range
		if C_Spell and C_Spell.GetSpellInfo then
			local info = C_Spell.GetSpellInfo(spellId or spellName)
			if info then
				icon = info.iconID
				castTime = info.castTime
				range = info.maxRange
			end
		elseif GetSpellInfo then
			local _, _, i, ct, minR, maxR = GetSpellInfo(spellId or spellName)
			icon, castTime, range = i, ct, maxR
		end
		self.spellDatabase[spellId] = {
			name = spellName,
			icon = icon,
			castTime = castTime,
			cooldown = cooldown or 0,
			range = range,
		}
	end
end

-- Get total healing done
function HealingStats:GetTotalHealing()
	return self.sessionStats.totalHealing
end

-- Get total overhealing
function HealingStats:GetTotalOverhealing()
	return self.sessionStats.totalOverhealing
end

-- Get overheal percentage
function HealingStats:GetOverhealPercentage()
	local total = self.sessionStats.totalHealing + self.sessionStats.totalOverhealing
	if total == 0 then
		return 0
	end
	return (self.sessionStats.totalOverhealing / total) * 100
end

-- Get healing efficiency (healing / (healing + overhealing))
function HealingStats:GetEfficiency()
	return 100 - self:GetOverhealPercentage()
end

-- Get spell statistics
function HealingStats:GetSpellStats(spellName)
	return self.sessionStats.spellCount[spellName]
end

-- Get top healing spells
function HealingStats:GetTopSpells(count)
	count = count or 5
	local spells = {}
	
	for spellName, stats in pairs(self.sessionStats.spellCount) do
		table.insert(spells, {
			name = spellName,
			healing = stats.healing,
			casts = stats.casts,
			overhealing = stats.overhealing,
		})
	end
	
	-- Sort by total healing
	table.sort(spells, function(a, b)
		return a.healing > b.healing
	end)
	
	-- Return top N
	local result = {}
	for i = 1, math.min(count, #spells) do
		result[i] = spells[i]
	end
	
	return result
end

-- Get player healing statistics
function HealingStats:GetPlayerStats(playerName)
	return {
		healing = self.sessionStats.playerHealing[playerName] or 0,
		overhealing = self.sessionStats.playerOverhealing[playerName] or 0,
	}
end

-- Get top healed players
function HealingStats:GetTopHealedPlayers(count)
	count = count or 5
	local players = {}
	
	for playerName, healing in pairs(self.sessionStats.playerHealing) do
		table.insert(players, {
			name = playerName,
			healing = healing,
			overhealing = self.sessionStats.playerOverhealing[playerName] or 0,
		})
	end
	
	-- Sort by total healing received
	table.sort(players, function(a, b)
		return a.healing > b.healing
	end)
	
	-- Return top N
	local result = {}
	for i = 1, math.min(count, #players) do
		result[i] = players[i]
	end
	
	return result
end

-- Get session duration
function HealingStats:GetSessionDuration()
	return GetTime() - self.sessionStats.startTime
end

-- Get healing per second
function HealingStats:GetHealingPerSecond()
	local duration = self:GetSessionDuration()
	if duration == 0 then
		return 0
	end
	return self.sessionStats.totalHealing / duration
end

-- Display healing statistics
function HealingStats:DisplayStats()
	local duration = self:GetSessionDuration()
	local hps = self:GetHealingPerSecond()
	local efficiency = self:GetEfficiency()
	
	print("|cffffd700=== HEALING STATISTICS ===|r")
	print("Duration: " .. string.format("%.1f", duration / 60) .. " minutes")
	print("Total Healing: " .. self:FormatValue(self.sessionStats.totalHealing))
	print("Total Overhealing: " .. self:FormatValue(self.sessionStats.totalOverhealing))
	print("HPS (Healing Per Second): " .. string.format("%.1f", hps))
	print("Efficiency: " .. string.format("%.1f%%", efficiency))
	
	-- Top spells
	print("\n|cffccccccTop Healing Spells:|r")
	local topSpells = self:GetTopSpells(5)
	for i, spell in ipairs(topSpells) do
		print(string.format("  %d. %s: %s x%d", i, spell.name, self:FormatValue(spell.healing), spell.casts))
	end
	
	-- Top healed players
	print("\n|cffccccccMost Healed Players:|r")
	local topPlayers = self:GetTopHealedPlayers(5)
	for i, player in ipairs(topPlayers) do
		print(string.format("  %d. %s: %s", i, player.name, self:FormatValue(player.healing)))
	end
end

-- Format healing value
function HealingStats:FormatValue(amount)
	if amount >= 1000000 then
		return string.format("%.2fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("%.1fK", amount / 1000)
	else
		return string.format("%d", amount)
	end
end

return HealingStats
