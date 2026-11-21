-- InfinityRaidEncounters Module
-- Manages raid encounters, timers, and boss mechanics

InfinityRaidEncounters = {}
InfinityRaidEncounters.activeEncounters = {}
InfinityRaidEncounters.bosses = {}

function InfinityRaidEncounters:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityRaid", "encounters", {})
	self.activeEncounters = storageData.activeEncounters or {}
	self.bosses = storageData.bosses or {}
	
	InfinityUtils:Info("RaidEncounters module initialized", "InfinityRaid")
end

function InfinityRaidEncounters:StartEncounter(bossName, difficulty)
	local encounterId = "enc_" .. InfinityUtils:GetTimeStamp()
	
	local encounter = {
		id = encounterId,
		boss = bossName,
		difficulty = difficulty or "Normal",
		startTime = InfinityUtils:GetTimeStamp(),
		endTime = nil,
		status = "active",
		phase = 1,
		attempts = 1,
		wipes = 0,
		kills = 0,
		mechanics = {},
		debuffs = {},
	}
	
	self.activeEncounters[encounterId] = encounter
	self:SaveEncounters()
	InfinityMessaging:Publish("encounter_started", { bossName = bossName, difficulty = difficulty })
	
	return encounter
end

function InfinityRaidEncounters:EndEncounter(encounterId, killed)
	if not self.activeEncounters[encounterId] then return nil end
	
	self.activeEncounters[encounterId].endTime = InfinityUtils:GetTimeStamp()
	
	if killed then
		self.activeEncounters[encounterId].kills = (self.activeEncounters[encounterId].kills or 0) + 1
		self.activeEncounters[encounterId].status = "killed"
		InfinityMessaging:Publish("boss_killed", { bossName = self.activeEncounters[encounterId].boss })
	else
		self.activeEncounters[encounterId].wipes = (self.activeEncounters[encounterId].wipes or 0) + 1
		self.activeEncounters[encounterId].status = "wiped"
		self.activeEncounters[encounterId].attempts = (self.activeEncounters[encounterId].attempts or 1) + 1
	end
	
	self:SaveEncounters()
	
	return self.activeEncounters[encounterId]
end

function InfinityRaidEncounters:RecordMechanic(encounterId, mechanicName, severity, timestamp)
	if not self.activeEncounters[encounterId] then return nil end
	
	local mechanic = {
		name = mechanicName,
		severity = severity or "INFO",
		timestamp = timestamp or InfinityUtils:GetTimeStamp(),
	}
	
	table.insert(self.activeEncounters[encounterId].mechanics, mechanic)
	InfinityMessaging:Publish("raid_mechanic_triggered", { 
		mechanic = mechanicName,
		severity = severity 
	})
	
	return mechanic
end

function InfinityRaidEncounters:GetEncounterStats(encounterId)
	local encounter = self.activeEncounters[encounterId]
	if not encounter then return nil end
	
	local duration = 0
	if encounter.startTime and encounter.endTime then
		duration = encounter.endTime - encounter.startTime
	end
	
	return {
		boss = encounter.boss,
		difficulty = encounter.difficulty,
		status = encounter.status,
		phase = encounter.phase,
		attempts = encounter.attempts,
		kills = encounter.kills,
		wipes = encounter.wipes,
		mechanicsTriggered = #encounter.mechanics,
		durationSeconds = duration,
	}
end

function InfinityRaidEncounters:GetActiveEncounters()
	local active = {}
	for encounterId, encounter in pairs(self.activeEncounters) do
		if encounter.status == "active" then
			table.insert(active, encounter)
		end
	end
	return active
end

function InfinityRaidEncounters:SaveEncounters()
	InfinityStorageManager:SetFeatureSetting("InfinityRaid", "encounters", {
		activeEncounters = self.activeEncounters,
		bosses = self.bosses,
	})
	InfinityDataManager:UpdateSourceData("InfinityRaid", "encounters", {
		activeEncounters = self.activeEncounters,
		bosses = self.bosses,
	})
end

return InfinityRaidEncounters
