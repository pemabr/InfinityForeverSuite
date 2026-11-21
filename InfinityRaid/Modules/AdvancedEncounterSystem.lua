-- InfinityRaid - Advanced Encounter System
-- Tracks raid encounters, mechanics, loot, and provides encounter-specific tools

local EncounterSystem = {}
_G.InfinityEncounterSystem = EncounterSystem

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

EncounterSystem.encounters = {} -- {encounterId = encounterData}
EncounterSystem.currentEncounter = nil
EncounterSystem.encounterActive = false
EncounterSystem.encounterStartTime = 0
EncounterSystem.raidDifficulty = "Normal" -- Normal, Heroic, Mythic

-- ============================================================================
-- ENCOUNTER DATABASE
-- ============================================================================

--- Register encounter
function EncounterSystem:RegisterEncounter(encounterId, data)
	self.encounters[encounterId] = {
		id = encounterId,
		name = data.name or "Unknown Boss",
		zone = data.zone or "Unknown Zone",
		difficulty = data.difficulty or "Normal",
		raidSize = data.raidSize or 20,
		bosses = data.bosses or {data.name},
		
		-- Mechanics
		mechanics = data.mechanics or {},
		--  {mechanic, description, timing, difficulty}
		
		-- Strategy
		composition = data.composition or {
			tanks = 2,
			healers = 4,
			dps = 14
		},
		
		-- Loot table
		loot = data.loot or {},
		-- {itemId, itemName, source, difficulty}
		
		-- Encounter data
		health = data.health or 1000000,
		enrage = data.enrage or 300, -- Seconds until enrage
		
		-- Statistics
		attempts = 0,
		kills = 0,
		wipes = 0,
		bestTime = 0,
		firstKillDate = nil,
		
		-- Custom flags
		flags = data.flags or {}
	}
	
	InfinityUtils:Info(string.format("Registered encounter: %s (%s)", data.name, data.zone), "Encounter")
end

--- Get encounter by ID
function EncounterSystem:GetEncounter(encounterId)
	return self.encounters[encounterId]
end

--- Get encounter by name
function EncounterSystem:FindEncounterByName(bossName)
	for id, encounter in pairs(self.encounters) do
		if encounter.name == bossName then
			return encounter
		end
		
		-- Check boss list
		for _, boss in ipairs(encounter.bosses) do
			if boss == bossName then
				return encounter
			end
		end
	end
	
	return nil
end

-- ============================================================================
-- ENCOUNTER TRACKING
-- ============================================================================

--- Start encounter
function EncounterSystem:StartEncounter(encounterId)
	local encounter = self:GetEncounter(encounterId)
	if not encounter then
		return false
	end
	
	self.currentEncounter = encounter
	self.encounterActive = true
	self.encounterStartTime = GetTime()
	encounter.attempts = encounter.attempts + 1
	
	InfinityUtils:Info(string.format("Encounter started: %s (Attempt %d)", encounter.name, encounter.attempts), "Encounter")
	
	return true
end

--- End encounter successfully
function EncounterSystem:EndEncounterSuccess()
	if not self.currentEncounter or not self.encounterActive then
		return
	end
	
	local encounter = self.currentEncounter
	encounter.kills = encounter.kills + 1
	
	local duration = GetTime() - self.encounterStartTime
	if encounter.bestTime == 0 or duration < encounter.bestTime then
		encounter.bestTime = duration
	end
	
	if not encounter.firstKillDate then
		encounter.firstKillDate = date("%Y-%m-%d %H:%M:%S")
	end
	
	self.encounterActive = false
	
	InfinityUtils:Info(string.format("Encounter defeated: %s in %.1fs", encounter.name, duration), "Encounter")
end

--- End encounter as wipe
function EncounterSystem:EndEncounterWipe()
	if not self.currentEncounter or not self.encounterActive then
		return
	end
	
	local encounter = self.currentEncounter
	encounter.wipes = encounter.wipes + 1
	
	local duration = GetTime() - self.encounterStartTime
	
	self.encounterActive = false
	
	InfinityUtils:Info(string.format("Encounter wipe: %s (Attempt %d, %.1fs)", 
		encounter.name, encounter.attempts, duration), "Encounter")
end

--- Get encounter duration
function EncounterSystem:GetEncounterDuration()
	if not self.encounterActive then
		return 0
	end
	
	return GetTime() - self.encounterStartTime
end

--- Get time remaining until enrage
function EncounterSystem:GetTimeToEnrage()
	if not self.currentEncounter or not self.encounterActive then
		return nil
	end
	
	local elapsed = self:GetEncounterDuration()
	local timeLeft = self.currentEncounter.enrage - elapsed
	
	return math.max(0, timeLeft)
end

--- Get enrage warning
function EncounterSystem:GetEnrageWarning()
	if not self.currentEncounter then
		return nil
	end
	
	local timeLeft = self:GetTimeToEnrage()
	
	if timeLeft == nil then
		return nil
	elseif timeLeft < 30 then
		return "CRITICAL", string.format("ENRAGE IN %.0f SECONDS", timeLeft)
	elseif timeLeft < 60 then
		return "WARNING", string.format("Enrage in %.0f seconds", timeLeft)
	else
		return "INFO", string.format("Enrage in %.0f seconds", timeLeft)
	end
end

-- ============================================================================
-- MECHANICS TRACKING
-- ============================================================================

--- Register encounter mechanic
function EncounterSystem:RegisterMechanic(encounterId, mechanic)
	local encounter = self:GetEncounter(encounterId)
	if not encounter then
		return
	end
	
	table.insert(encounter.mechanics, {
		name = mechanic.name,
		description = mechanic.description,
		timing = mechanic.timing, -- When it happens
		difficulty = mechanic.difficulty or "Normal",
		coreTeam = mechanic.coreTeam or false, -- Critical for core team?
		roles = mechanic.roles or {}, -- Which roles are affected
		actions = mechanic.actions or {} -- What players should do
	})
end

--- Get mechanics for current encounter
function EncounterSystem:GetCurrentMechanics()
	if not self.currentEncounter then
		return {}
	end
	
	return self.currentEncounter.mechanics or {}
end

--- Get mechanics by difficulty
function EncounterSystem:GetMechanicsByDifficulty(encounterId, difficulty)
	local encounter = self:GetEncounter(encounterId)
	if not encounter then
		return {}
	end
	
	local result = {}
	for _, mechanic in ipairs(encounter.mechanics) do
		if mechanic.difficulty == difficulty then
			table.insert(result, mechanic)
		end
	end
	
	return result
end

--- Alert for specific mechanic
function EncounterSystem:AlertMechanic(mechanicName)
	local mechanics = self:GetCurrentMechanics()
	
	for _, mechanic in ipairs(mechanics) do
		if mechanic.name == mechanicName then
			local severity = "INFO"
			if mechanic.coreTeam then
				severity = "CRITICAL"
			elseif mechanic.difficulty == "Hard" then
				severity = "WARNING"
			end
			
			return severity, string.format("%s: %s", mechanic.name, mechanic.description)
		end
	end
	
	return nil
end

-- ============================================================================
-- COMPOSITION CHECKING
-- ============================================================================

--- Get recommended composition
function EncounterSystem:GetRecommendedComposition(encounterId)
	local encounter = self:GetEncounter(encounterId)
	if not encounter then
		return nil
	end
	
	return encounter.composition
end

--- Check if raid composition is suitable
function EncounterSystem:CheckComposition(encounterId, raidComposition)
	local recommended = self:GetRecommendedComposition(encounterId)
	if not recommended then
		return true, "No composition requirement" -- No recommendation
	end
	
	local issues = {}
	
	-- Check tank count
	if raidComposition.tanks < recommended.tanks then
		table.insert(issues, string.format("Need at least %d tanks (have %d)", 
			recommended.tanks, raidComposition.tanks))
	end
	
	-- Check healer count
	if raidComposition.healers < recommended.healers then
		table.insert(issues, string.format("Need at least %d healers (have %d)",
			recommended.healers, raidComposition.healers))
	end
	
	-- Check DPS count
	if raidComposition.dps < recommended.dps then
		table.insert(issues, string.format("Need at least %d DPS (have %d)",
			recommended.dps, raidComposition.dps))
	end
	
	if #issues > 0 then
		return false, table.concat(issues, "\n")
	end
	
	return true, "Composition suitable"
end

-- ============================================================================
-- LOOT MANAGEMENT
-- ============================================================================

--- Get loot table for encounter
function EncounterSystem:GetLootTable(encounterId, difficulty)
	local encounter = self:GetEncounter(encounterId)
	if not encounter then
		return {}
	end
	
	local loot = {}
	for _, item in ipairs(encounter.loot) do
		if not difficulty or item.difficulty == difficulty then
			table.insert(loot, item)
		end
	end
	
	return loot
end

--- Add loot to encounter
function EncounterSystem:AddLoot(encounterId, itemId, itemName, difficulty, source)
	local encounter = self:GetEncounter(encounterId)
	if not encounter then
		return
	end
	
	table.insert(encounter.loot, {
		itemId = itemId,
		name = itemName,
		difficulty = difficulty or "Normal",
		source = source or "Boss Drop",
		dropRate = 100
	})
end

--- Get item drop rate for encounter
function EncounterSystem:GetDropRate(encounterId, itemName)
	local loot = self:GetLootTable(encounterId)
	
	for _, item in ipairs(loot) do
		if item.name == itemName then
			return item.dropRate
		end
	end
	
	return 0
end

-- ============================================================================
-- ENCOUNTER STATISTICS
-- ============================================================================

--- Get encounter stats
function EncounterSystem:GetEncounterStats(encounterId)
	local encounter = self:GetEncounter(encounterId)
	if not encounter then
		return nil
	end
	
	local attempts = encounter.attempts
	local kills = encounter.kills
	local wipes = encounter.wipes
	local winRate = attempts > 0 and (kills / attempts * 100) or 0
	
	return {
		name = encounter.name,
		attempts = attempts,
		kills = kills,
		wipes = wipes,
		winRate = winRate,
		bestTime = encounter.bestTime,
		firstKill = encounter.firstKillDate
	}
end

--- Print encounter statistics
function EncounterSystem:PrintEncounterStats(encounterId)
	local stats = self:GetEncounterStats(encounterId)
	if not stats then
		print("No stats for encounter")
		return
	end
	
	print("|cff00ccff" .. stats.name .. "|r Statistics:")
	print(string.format("  Attempts: %d", stats.attempts))
	print(string.format("  Kills: %d", stats.kills))
	print(string.format("  Wipes: %d", stats.wipes))
	print(string.format("  Win Rate: %.1f%%", stats.winRate))
	
	if stats.bestTime > 0 then
		print(string.format("  Best Time: %.0f seconds", stats.bestTime))
	end
	
	if stats.firstKill then
		print(string.format("  First Kill: %s", stats.firstKill))
	end
end

-- ============================================================================
-- ENCOUNTER WARNINGS
-- ============================================================================

--- Get active warnings
function EncounterSystem:GetActiveWarnings()
	local warnings = {}
	
	if not self.encounterActive then
		return warnings
	end
	
	-- Enrage warning
	local enrageSev, enrageMsg = self:GetEnrageWarning()
	if enrageSev then
		table.insert(warnings, {
			severity = enrageSev,
			message = enrageMsg,
			type = "ENRAGE"
		})
	end
	
	return warnings
end

-- ============================================================================
-- INTEGRATION WITH OTHER SYSTEMS
-- ============================================================================

--- Create encounter from boss death
function EncounterSystem:CreateEncounterFromBossDeath(bossName, zoneId)
	local encounter = self:FindEncounterByName(bossName)
	
	if not encounter then
		-- Auto-register new encounter
		local encounterId = "boss_" .. bossName:gsub(" ", "_"):lower()
		self:RegisterEncounter(encounterId, {
			name = bossName,
			zone = GetZoneText(),
			difficulty = self.raidDifficulty
		})
		
		encounter = self:GetEncounter(encounterId)
	end
	
	return encounter
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function EncounterSystem:Initialize()
	InfinityUtils:Info("EncounterSystem initializing...", "Encounter")
	
	-- Register default encounters
	-- This would typically load from a database
	-- Example registration:
	--[[
	self:RegisterEncounter("boss_1", {
		name = "Example Boss",
		zone = "Raid Zone",
		raidSize = 20,
		composition = {tanks = 2, healers = 4, dps = 14},
		mechanics = {}
	})
	]]
	
	InfinityUtils:Info("EncounterSystem initialized", "Encounter")
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

if InfinityCommandRegistry then
	InfinityCommandRegistry:RegisterCommand("encounter", function(args)
		if not args or #args == 0 then
			if EncounterSystem.currentEncounter then
				print("|cff00ccffCurrent Encounter:|r " .. EncounterSystem.currentEncounter.name)
				print(string.format("Duration: %.0f seconds", EncounterSystem:GetEncounterDuration()))
				
				local severity, msg = EncounterSystem:GetEnrageWarning()
				if msg then
					print("|cff00ccff" .. msg .. "|r")
				end
			else
				print("No active encounter")
			end
		elseif args[1] == "stats" and args[2] then
			EncounterSystem:PrintEncounterStats(args[2])
		elseif args[1] == "mechanics" then
			local mechanics = EncounterSystem:GetCurrentMechanics()
			if #mechanics > 0 then
				print("|cff00ccffEncounter Mechanics:|r")
				for _, mechanic in ipairs(mechanics) do
					print(string.format("  - %s: %s", mechanic.name, mechanic.description))
				end
			else
				print("No mechanics")
			end
		end
	end, {"enc", "boss"})
end

print("[INFO] Encounter System loaded successfully")
