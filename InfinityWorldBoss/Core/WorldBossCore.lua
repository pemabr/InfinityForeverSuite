-- InfinityWorldBoss Core - World Boss Tracking
-- Tracks world boss respawn timers and notifies guild members

InfinityWorldBossCore = {
	bosses = {},
	respawnTimers = {},
	version = 1,
	notificationEnabled = true,
	guildSharingEnabled = true,
}

-- Register a world boss
function InfinityWorldBossCore:RegisterBoss(bossID, bossName, zone, respawnTime, difficulty)
	if type(bossID) ~= "number" or bossID <= 0 then
		return false
	end
	
	if not self.bosses[bossID] then
		self.bosses[bossID] = {
			id = bossID,
			name = bossName or "Unknown Boss",
			zone = zone or "Unknown",
			respawnTime = respawnTime or 14400,  -- 4 hours default
			difficulty = difficulty or "normal",
			lastKilled = 0,
			nextRespawn = 0,
			status = "unknown",
			killedBy = "Unknown",
			observers = {},
			firstSeen = time(),
			lastUpdated = time(),
		}
		
		InfinityUtils:Info("World boss registered: " .. bossName, "WorldBoss")
		return true
	end
	
	return false
end

-- Record boss kill
function InfinityWorldBossCore:RecordBossKill(bossID, killerName, killerGuild)
	if not self.bosses[bossID] then
		return false
	end
	
	local now = time()
	self.bosses[bossID].lastKilled = now
	self.bosses[bossID].nextRespawn = now + self.bosses[bossID].respawnTime
	self.bosses[bossID].status = "killed"
	self.bosses[bossID].killedBy = killerName or "Unknown"
	self.bosses[bossID].lastUpdated = now
	
	-- Create respawn timer
	self.respawnTimers[bossID] = {
		bossID = bossID,
		bossName = self.bosses[bossID].name,
		killedTime = now,
		respawnTime = self.bosses[bossID].respawnTime,
		nextRespawn = now + self.bosses[bossID].respawnTime,
		killedBy = killerName,
		killedByGuild = killerGuild,
		notified = false,
	}
	
	-- Publish event
	if InfinityMessaging then
		InfinityMessaging:Publish("WorldBoss:KillRecorded", bossID, killerName, killerGuild)
	end
	
	InfinityUtils:Info("Boss kill recorded: " .. self.bosses[bossID].name, "WorldBoss")
	return true
end

-- Update boss status
function InfinityWorldBossCore:UpdateBossStatus(bossID, status, details)
	if not self.bosses[bossID] then
		return false
	end
	
	self.bosses[bossID].status = status or "unknown"
	self.bosses[bossID].lastUpdated = time()
	
	-- If alive, calculate potential respawn
	if status == "alive" and self.respawnTimers[bossID] then
		self.respawnTimers[bossID].notified = false
	end
	
	return true
end

-- Get boss information
function InfinityWorldBossCore:GetBossInfo(bossID)
	return self.bosses[bossID]
end

-- Get respawn timer
function InfinityWorldBossCore:GetRespawnTimer(bossID)
	return self.respawnTimers[bossID]
end

-- Get time until respawn (in seconds)
function InfinityWorldBossCore:GetTimeToRespawn(bossID)
	local timer = self.respawnTimers[bossID]
	if not timer then
		return nil
	end
	
	local now = time()
	local timeLeft = timer.nextRespawn - now
	
	if timeLeft <= 0 then
		return 0
	end
	
	return timeLeft
end

-- Format time remaining
function InfinityWorldBossCore:FormatTimeRemaining(seconds)
	if seconds <= 0 then
		return "NOW"
	end
	
	if seconds < 60 then
		return string.format("%d sec", seconds)
	elseif seconds < 3600 then
		return string.format("%d min", math.floor(seconds / 60))
	elseif seconds < 86400 then
		return string.format("%d h %d min", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
	else
		return string.format("%d days", math.floor(seconds / 86400))
	end
end

-- Get all tracked bosses
function InfinityWorldBossCore:GetAllBosses()
	local bossList = {}
	for bossID, bossData in pairs(self.bosses) do
		table.insert(bossList, bossData)
	end
	return bossList
end

-- Get bosses by zone
function InfinityWorldBossCore:GetBossesByZone(zone)
	local bossList = {}
	for bossID, bossData in pairs(self.bosses) do
		if bossData.zone == zone then
			table.insert(bossList, bossData)
		end
	end
	return bossList
end

-- Get respawning bosses
function InfinityWorldBossCore:GetRespawningBosses()
	local respawning = {}
	for bossID, timer in pairs(self.respawnTimers) do
		if timer.nextRespawn > time() then
			table.insert(respawning, timer)
		end
	end
	return respawning
end

-- Get bosses due to respawn soon (within 1 hour)
function InfinityWorldBossCore:GetSoonRespawning()
	local soon = {}
	local now = time()
	for bossID, timer in pairs(self.respawnTimers) do
		local timeLeft = timer.nextRespawn - now
		if timeLeft > 0 and timeLeft <= 3600 then  -- Within 1 hour
			table.insert(soon, {boss = timer, timeLeft = timeLeft})
		end
	end
	return soon
end

-- Enable/disable notifications
function InfinityWorldBossCore:SetNotificationEnabled(enabled)
	self.notificationEnabled = not not enabled
	return self.notificationEnabled
end

-- Enable/disable guild sharing
function InfinityWorldBossCore:SetGuildSharingEnabled(enabled)
	self.guildSharingEnabled = not not enabled
	return self.guildSharingEnabled
end

-- Export boss data for sharing
function InfinityWorldBossCore:ExportBossData()
	return {
		bosses = self.bosses,
		respawnTimers = self.respawnTimers,
		exportTime = time(),
		version = self.version,
	}
end

-- Import boss data from peers
function InfinityWorldBossCore:ImportBossData(importedData)
	if not importedData or not importedData.respawnTimers then
		return false
	end
	
	pcall(function()
		for bossID, timer in pairs(importedData.respawnTimers) do
			if type(bossID) == "number" and type(timer) == "table" then
				-- Only update if newer
				local existing = self.respawnTimers[bossID]
				if not existing or timer.killedTime > (existing.killedTime or 0) then
					self.respawnTimers[bossID] = timer
					
					-- Update boss status
					if self.bosses[bossID] then
						self.bosses[bossID].lastKilled = timer.killedTime
						self.bosses[bossID].nextRespawn = timer.nextRespawn
						self.bosses[bossID].killedBy = timer.killedBy
					end
				end
			end
		end
	end)
	
	return true
end

-- Get statistics
function InfinityWorldBossCore:GetStatistics()
	local stats = {
		totalBosses = 0,
		trackedBosses = 0,
		aliveCount = 0,
		killedCount = 0,
		respawningCount = 0,
	}
	
	for bossID, bossData in pairs(self.bosses) do
		stats.totalBosses = stats.totalBosses + 1
		if bossData.status == "alive" then
			stats.aliveCount = stats.aliveCount + 1
		elseif bossData.status == "killed" then
			stats.killedCount = stats.killedCount + 1
		end
	end
	
	stats.trackedBosses = stats.killedCount + stats.aliveCount
	stats.respawningCount = self:CountTable(self.respawnTimers)
	
	return stats
end

function InfinityWorldBossCore:CountTable(t)
	local count = 0
	for _ in pairs(t) do count = count + 1 end
	return count
end
