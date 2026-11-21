-- InfinityWorldBoss Respawn Timer Module
-- Tracks respawn timers and sends notifications

InfinityWorldBossTimers = {
	activeTimers = {},
	notificationSettings = {
		enableChat = true,
		enableScreen = true,
		enableSound = true,
		notifyWhenMinutesLeft = 60,
		notifyWhenMinutesLeft_30 = 30,
		notifyWhenMinutesLeft_5 = 5,
	},
	updateFrame = nil,
}

-- Initialize timer system
function InfinityWorldBossTimers:Initialize()
	if self.updateFrame then
		return
	end
	
	self.updateFrame = CreateFrame("Frame")
	self.updateFrame:SetScript("OnUpdate", function(self, elapsed)
		InfinityWorldBossTimers:OnUpdate(elapsed)
	end)
	
	InfinityUtils:Info("World boss timer system initialized", "WorldBossTimers")
end

-- Main update loop - check for respawns
function InfinityWorldBossTimers:OnUpdate(elapsed)
	local now = time()
	
	for bossID, timer in pairs(InfinityWorldBossCore.respawnTimers) do
		if timer.nextRespawn and timer.nextRespawn > 0 then
			local timeLeft = timer.nextRespawn - now
			
			-- Boss has respawned
			if timeLeft <= 0 then
				if not timer.notified then
					self:NotifyBossRespawned(bossID, timer)
					timer.notified = true
				end
			end
			
			-- Send notifications at different intervals
			if not timer.notified then
				if timeLeft > 0 and timeLeft <= (self.notificationSettings.notifyWhenMinutesLeft_5 * 60) then
					if not timer.notified_5min then
						self:NotifyBossRespawning(bossID, timer, 5)
						timer.notified_5min = true
					end
				elseif timeLeft > 0 and timeLeft <= (self.notificationSettings.notifyWhenMinutesLeft_30 * 60) then
					if not timer.notified_30min then
						self:NotifyBossRespawning(bossID, timer, 30)
						timer.notified_30min = true
					end
				elseif timeLeft > 0 and timeLeft <= (self.notificationSettings.notifyWhenMinutesLeft * 60) then
					if not timer.notified_1hr then
						self:NotifyBossRespawning(bossID, timer, 60)
						timer.notified_1hr = true
					end
				end
			end
		end
	end
end

-- Send notification when boss is respawning soon
function InfinityWorldBossTimers:NotifyBossRespawning(bossID, timer, minutesLeft)
	local bossData = InfinityWorldBossCore:GetBossInfo(bossID)
	if not bossData then
		return
	end
	
	local message = string.format(
		"|cFFFF6B6B[World Boss]|r %s will respawn in %d minutes (Killed by: %s)",
		bossData.name,
		minutesLeft,
		timer.killedBy or "Unknown"
	)
	
	if self.notificationSettings.enableChat then
		print(message)
	end
	
	if self.notificationSettings.enableScreen then
		self:ShowScreenAlert(message)
	end
	
	if self.notificationSettings.enableSound then
		PlaySoundFile("Sound\\Interface\\Alarm ClockWarning3.ogg", "Master")
	end
	
	-- Publish event for other addons
	if InfinityMessaging then
		InfinityMessaging:Publish("WorldBoss:RespawningNotification", bossID, minutesLeft)
	end
end

-- Send notification when boss has respawned
function InfinityWorldBossTimers:NotifyBossRespawned(bossID, timer)
	local bossData = InfinityWorldBossCore:GetBossInfo(bossID)
	if not bossData then
		return
	end
	
	local message = string.format(
		"|cFFFFD700[World Boss]|r %s has RESPAWNED in %s!",
		bossData.name,
		bossData.zone
	)
	
	if self.notificationSettings.enableChat then
		print(message)
	end
	
	if self.notificationSettings.enableScreen then
		self:ShowScreenAlert(message, true)  -- Prominent alert
	end
	
	if self.notificationSettings.enableSound then
		PlaySoundFile("Sound\\Doodad\\BellTollHuge.ogg", "Master")
	end
	
	-- Send to guild if enabled
	if InfinityWorldBossCore.guildSharingEnabled and IsInGuild() then
		SendChatMessage(message, "GUILD")
	end
	
	-- Publish event for other addons
	if InfinityMessaging then
		InfinityMessaging:Publish("WorldBoss:RespawnedNotification", bossID)
	end
end

-- Show screen alert
function InfinityWorldBossTimers:ShowScreenAlert(message, prominent)
	-- Use UIFrameFadeIn for simple notification
	local frame = CreateFrame("Frame", "WorldBossAlert", UIParent)
	frame:SetSize(400, 60)
	frame:SetPoint("TOP", UIParent, "TOP", 0, 50)
	
	local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
	bgTexture:SetAllPoints(frame)
	bgTexture:SetColorTexture(0, 0, 0, 0.8)
	
	local text = frame:CreateFontString(nil, "ARTWORK", prominent and "GameFontBig" or "GameFontNormal")
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	text:SetText(message)
	text:SetTextColor(1, 1, 1, 1)
	
	-- Auto-remove after 10 seconds
	C_Timer.After(10, function()
		if frame and frame:IsVisible() then
			frame:Hide()
		end
	end)
end

-- Set notification settings
function InfinityWorldBossTimers:SetNotificationSetting(setting, value)
	if self.notificationSettings[setting] ~= nil then
		self.notificationSettings[setting] = value
		return true
	end
	return false
end

-- Get notification settings
function InfinityWorldBossTimers:GetNotificationSettings()
	return self.notificationSettings
end

-- Check boss status and update timers
function InfinityWorldBossTimers:CheckBossStatus(bossID)
	local boss = InfinityWorldBossCore:GetBossInfo(bossID)
	if not boss then
		return nil
	end
	
	local timer = InfinityWorldBossCore:GetRespawnTimer(bossID)
	if not timer then
		return {
			status = "unknown",
			bossName = boss.name,
			zone = boss.zone,
			timeRemaining = nil,
		}
	end
	
	local timeLeft = InfinityWorldBossCore:GetTimeToRespawn(bossID)
	
	return {
		status = timeLeft and timeLeft > 0 and "respawning" or "alive",
		bossName = boss.name,
		zone = boss.zone,
		timeRemaining = timeLeft,
		timeFormatted = timeLeft and InfinityWorldBossCore:FormatTimeRemaining(timeLeft) or "Now",
		killedBy = timer.killedBy,
		killedByGuild = timer.killedByGuild,
		killedTime = timer.killedTime,
	}
end

-- Get all current timers
function InfinityWorldBossTimers:GetActiveTimers()
	local timers = {}
	
	for bossID, timer in pairs(InfinityWorldBossCore.respawnTimers) do
		local timeLeft = InfinityWorldBossCore:GetTimeToRespawn(bossID)
		if timeLeft and timeLeft > 0 then
			table.insert(timers, {
				bossID = bossID,
				bossName = timer.bossName,
				timeLeft = timeLeft,
				timeFormatted = InfinityWorldBossCore:FormatTimeRemaining(timeLeft),
				nextRespawn = timer.nextRespawn,
				killedBy = timer.killedBy,
			})
		end
	end
	
	-- Sort by time until respawn
	table.sort(timers, function(a, b)
		return a.timeLeft < b.timeLeft
	end)
	
	return timers
end

-- Enable/disable sound notifications
function InfinityWorldBossTimers:SetSoundEnabled(enabled)
	self.notificationSettings.enableSound = not not enabled
	return self.notificationSettings.enableSound
end

-- Enable/disable screen notifications
function InfinityWorldBossTimers:SetScreenAlertsEnabled(enabled)
	self.notificationSettings.enableScreen = not not enabled
	return self.notificationSettings.enableScreen
end

-- Enable/disable chat notifications
function InfinityWorldBossTimers:SetChatNotificationsEnabled(enabled)
	self.notificationSettings.enableChat = not not enabled
	return self.notificationSettings.enableChat
end
