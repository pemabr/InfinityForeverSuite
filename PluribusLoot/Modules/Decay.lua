-- Decay Module
-- Handles periodic decay of EP/GP, interval awards, and scheduled point adjustments

local PluribusLootDecay = {}
_G.PluribusLootDecay = PluribusLootDecay

-- Configuration
PluribusLootDecay.config = {
	-- Decay settings
	decayEnabled = true,
	decayPercent = 10, -- 10% decay per interval
	decayInterval = 604800, -- 7 days (604800 seconds)
	decayMinimum = 0, -- Don't decay below 0
	decayRoundMode = "floor", -- floor, ceil, or round
	
	-- Interval awards
	intervalAwardEnabled = true,
	attendanceAwardPerInterval = 50, -- EP per attendance interval
	attendanceCheckInterval = 86400, -- 24 hours
	
	-- Boss kill awards
	bossKillAwardEnabled = true,
	bossKillEP = 100, -- EP per boss kill
	
	-- Raid completion awards
	raidCompletionEnabled = true,
	raidCompletionEP = 150, -- EP at raid end
	
	-- Caps
	weeklyEPCap = 2000, -- Max EP gain per week
	lifetimeGPCap = nil, -- No lifetime GP cap by default
	
	-- Minimum thresholds
	minGPThreshold = 50, -- Minimum GP when receiving loot
	
	-- Admin only
	adminOnly = true,
}

-- Decay tracking
PluribusLootDecay.lastDecayTime = {} -- {playerName = timestamp}
PluribusLootDecay.lastAwardTime = {} -- {playerName = timestamp}
PluribusLootDecay.weeklyEPGained = {} -- {playerName = ep_gained_this_week}
PluribusLootDecay.decayHistory = {} -- {player = {timestamp, oldValue, newValue, ...}, ...}

-- Callbacks
PluribusLootDecay.callbacks = {}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize decay system
function PluribusLootDecay:Initialize()
	PluribusUtils:Info("Decay system initialized", "Decay")
end

-- ============================================================================
-- DECAY SYSTEM
-- ============================================================================

--- Apply EP/GP decay to all players
-- @return success: bool
function PluribusLootDecay:ApplyDecayToAll()
	if not self.config.decayEnabled then
		return false
	end
	
	local affectedPlayers = 0
	local currentTime = PluribusUtils:GetTimeStamp()
	
	for playerName, playerData in pairs(PluribusLootEPGP.players) do
		local lastDecay = self.lastDecayTime[playerName] or 0
		local timeSinceDecay = currentTime - lastDecay
		
		-- Check if enough time has passed for decay
		if timeSinceDecay >= self.config.decayInterval then
			local oldEP = playerData.ep
			local oldGP = playerData.gp
			
			-- Apply decay
			playerData.ep = self:ApplyDecay(playerData.ep)
			playerData.gp = self:ApplyDecay(playerData.gp)
			
			self.lastDecayTime[playerName] = currentTime
			affectedPlayers = affectedPlayers + 1
			
			-- Log decay
			table.insert(self.decayHistory, {
				playerName = playerName,
				timestamp = currentTime,
				epBefore = oldEP,
				epAfter = playerData.ep,
				gpBefore = oldGP,
				gpAfter = playerData.gp,
				decayPercent = self.config.decayPercent,
			})
			
			-- Update priority
			PluribusLootEPGP:UpdatePlayerPriority(playerName)
			
			-- Trigger event
			self:TriggerCallback("player_decayed", playerName, oldEP, playerData.ep, oldGP, playerData.gp)
		end
	end
	
	if affectedPlayers > 0 then
		PluribusUtils:Info(affectedPlayers .. " players affected by decay", "Decay")
		self:TriggerCallback("decay_applied", affectedPlayers)
	end
	
	return true
end

--- Apply decay calculation to a value
-- @param value: number
-- @return decayedValue: number
function PluribusLootDecay:ApplyDecay(value)
	if value == 0 then
		return 0
	end
	
	local decayAmount = (value * self.config.decayPercent) / 100
	local newValue = value - decayAmount
	
	-- Apply rounding
	if self.config.decayRoundMode == "ceil" then
		newValue = math.ceil(newValue)
	elseif self.config.decayRoundMode == "round" then
		newValue = math.floor(newValue + 0.5)
	else
		newValue = math.floor(newValue)
	end
	
	-- Apply minimum
	if newValue < self.config.decayMinimum then
		newValue = self.config.decayMinimum
	end
	
	return newValue
end

--- Set decay percentage
-- @param percent: number (0-100)
-- @return success: bool
function PluribusLootDecay:SetDecayPercent(percent)
	if not self:IsAdminOnly() then
		return false
	end
	
	percent = tonumber(percent) or 10
	if percent < 0 or percent > 100 then
		PluribusUtils:Warning("Decay percent must be 0-100", "Decay")
		return false
	end
	
	self.config.decayPercent = percent
	PluribusUtils:Info("Decay set to " .. percent .. "%", "Decay")
	self:TriggerCallback("decay_percent_changed", percent)
	return true
end

--- Set decay interval
-- @param seconds: number (interval in seconds)
-- @return success: bool
function PluribusLootDecay:SetDecayInterval(seconds)
	if not self:IsAdminOnly() then
		return false
	end
	
	seconds = tonumber(seconds) or 604800
	if seconds < 3600 then -- Minimum 1 hour
		PluribusUtils:Warning("Decay interval minimum is 3600 seconds (1 hour)", "Decay")
		return false
	end
	
	self.config.decayInterval = seconds
	PluribusUtils:Info("Decay interval set to " .. seconds .. " seconds", "Decay")
	self:TriggerCallback("decay_interval_changed", seconds)
	return true
end

--- Enable/disable decay
-- @param enabled: bool
-- @return success: bool
function PluribusLootDecay:SetDecayEnabled(enabled)
	if not self:IsAdminOnly() then
		return false
	end
	
	self.config.decayEnabled = enabled
	PluribusUtils:Info("Decay " .. (enabled and "enabled" or "disabled"), "Decay")
	self:TriggerCallback("decay_enabled_changed", enabled)
	return true
end

--- Get decay history
-- @param limit: number (default 100)
-- @return history: table
function PluribusLootDecay:GetDecayHistory(limit)
	limit = limit or 100
	local result = {}
	
	for i = #self.decayHistory, math.max(1, #self.decayHistory - limit + 1), -1 do
		table.insert(result, self.decayHistory[i])
	end
	
	return result
end

--- Export decay history
-- @return historyString: string
function PluribusLootDecay:ExportDecayHistory(limit)
	limit = limit or 100
	local export = "DECAY HISTORY\n"
	export = export .. "==============\n\n"
	
	for i = #self.decayHistory, math.max(1, #self.decayHistory - limit + 1), -1 do
		local entry = self.decayHistory[i]
		export = export .. string.format("%s | %s | EP: %d→%d, GP: %d→%d (-%d%%)\n",
			PluribusUtils:FormatTimeStamp(entry.timestamp),
			entry.playerName,
			entry.epBefore, entry.epAfter,
			entry.gpBefore, entry.gpAfter,
			entry.decayPercent)
	end
	
	return export
end

-- ============================================================================
-- INTERVAL AWARDS
-- ============================================================================

--- Award EP to raiders for attendance
-- Called periodically for raid participants
-- @param playerName: string
-- @return success: bool
function PluribusLootDecay:AwardAttendanceEP(playerName)
	if not self.config.intervalAwardEnabled then
		return false
	end
	
	local currentTime = PluribusUtils:GetTimeStamp()
	local lastAward = self.lastAwardTime[playerName] or 0
	local timeSinceAward = currentTime - lastAward
	
	-- Check if enough time has passed
	if timeSinceAward < self.config.attendanceCheckInterval then
		return false
	end
	
	-- Award EP
	local epAmount = self.config.attendanceAwardPerInterval
	local success = PluribusLootEPGP:AwardEP(playerName, epAmount)
	
	if success then
		self.lastAwardTime[playerName] = currentTime
		PluribusUtils:Info(playerName .. " awarded " .. epAmount .. " EP for attendance", "Decay")
		self:TriggerCallback("attendance_ep_awarded", playerName, epAmount)
	end
	
	return success
end

--- Award EP to all active raid members
-- @return success: bool
function PluribusLootDecay:AwardAllAttendanceEP()
	if not self.config.intervalAwardEnabled then
		return false
	end
	
	local affectedPlayers = 0
	
	for playerName, _ in pairs(PluribusLootEPGP.players) do
		if self:AwardAttendanceEP(playerName) then
			affectedPlayers = affectedPlayers + 1
		end
	end
	
	if affectedPlayers > 0 then
		PluribusUtils:Info(affectedPlayers .. " players awarded attendance EP", "Decay")
		self:TriggerCallback("batch_attendance_ep_awarded", affectedPlayers)
	end
	
	return true
end

--- Set attendance award amount
-- @param epAmount: number
-- @return success: bool
function PluribusLootDecay:SetAttendanceAwardAmount(epAmount)
	if not self:IsAdminOnly() then
		return false
	end
	
	epAmount = tonumber(epAmount) or 50
	if epAmount < 0 then
		PluribusUtils:Warning("Attendance award must be >= 0", "Decay")
		return false
	end
	
	self.config.attendanceAwardPerInterval = epAmount
	PluribusUtils:Info("Attendance award set to " .. epAmount .. " EP", "Decay")
	self:TriggerCallback("attendance_award_changed", epAmount)
	return true
end

--- Set attendance check interval
-- @param seconds: number
-- @return success: bool
function PluribusLootDecay:SetAttendanceCheckInterval(seconds)
	if not self:IsAdminOnly() then
		return false
	end
	
	seconds = tonumber(seconds) or 86400
	if seconds < 60 then
		PluribusUtils:Warning("Attendance interval minimum is 60 seconds", "Decay")
		return false
	end
	
	self.config.attendanceCheckInterval = seconds
	PluribusUtils:Info("Attendance check interval set to " .. seconds .. " seconds", "Decay")
	self:TriggerCallback("attendance_interval_changed", seconds)
	return true
end

-- ============================================================================
-- WEEKLY EP CAP
-- ============================================================================

--- Get current week's EP gain for player
-- @param playerName: string
-- @return epGained: number
function PluribusLootDecay:GetWeeklyEPGain(playerName)
	return self.weeklyEPGained[playerName] or 0
end

--- Get remaining EP available this week
-- @param playerName: string
-- @return remaining: number
function PluribusLootDecay:GetRemainingWeeklyEP(playerName)
	local gained = self:GetWeeklyEPGain(playerName)
	local remaining = self.config.weeklyEPCap - gained
	return math.max(0, remaining)
end

--- Check if player can receive EP this week
-- @param playerName: string
-- @param amount: number
-- @return canReceive: bool
function PluribusLootDecay:CanReceiveEP(playerName, amount)
	if not self.config.weeklyEPCap or self.config.weeklyEPCap == 0 then
		return true
	end
	
	local remaining = self:GetRemainingWeeklyEP(playerName)
	return remaining >= amount
end

--- Award EP with weekly cap enforcement
-- @param playerName: string
-- @param amount: number
-- @return success: bool, amountAwarded: number
function PluribusLootDecay:AwardEPWithCap(playerName, amount)
	if not self.config.weeklyEPCap or self.config.weeklyEPCap == 0 then
		-- No cap, award full amount
		local success = PluribusLootEPGP:AwardEP(playerName, amount)
		return success, amount
	end
	
	local remaining = self:GetRemainingWeeklyEP(playerName)
	local amountToAward = math.min(amount, remaining)
	
	if amountToAward == 0 then
		PluribusUtils:Warning(playerName .. " has reached weekly EP cap", "Decay")
		self:TriggerCallback("weekly_cap_reached", playerName)
		return false, 0
	end
	
	local success = PluribusLootEPGP:AwardEP(playerName, amountToAward)
	
	if success then
		self.weeklyEPGained[playerName] = (self.weeklyEPGained[playerName] or 0) + amountToAward
		if amountToAward < amount then
			PluribusUtils:Warning(playerName .. " awarded " .. amountToAward .. "/" .. amount .. " EP (cap reached)", "Decay")
		end
	end
	
	return success, amountToAward
end

--- Set weekly EP cap
-- @param amount: number (0 = no cap)
-- @return success: bool
function PluribusLootDecay:SetWeeklyEPCap(amount)
	if not self:IsAdminOnly() then
		return false
	end
	
	amount = tonumber(amount) or 0
	if amount < 0 then
		amount = 0
	end
	
	self.config.weeklyEPCap = amount
	PluribusUtils:Info("Weekly EP cap set to " .. (amount == 0 and "unlimited" or amount) .. " EP", "Decay")
	self:TriggerCallback("weekly_ep_cap_changed", amount)
	return true
end

--- Reset weekly EP counters (usually called at start of week)
-- @return success: bool
function PluribusLootDecay:ResetWeeklyEPCounters()
	if not self:IsAdminOnly() then
		return false
	end
	
	local playerCount = 0
	for playerName, _ in pairs(PluribusLootEPGP.players) do
		self.weeklyEPGained[playerName] = 0
		playerCount = playerCount + 1
	end
	
	PluribusUtils:Info("Weekly EP counters reset for " .. playerCount .. " players", "Decay")
	self:TriggerCallback("weekly_ep_reset", playerCount)
	return true
end

-- ============================================================================
-- MINIMUM GP THRESHOLD
-- ============================================================================

--- Get minimum GP threshold
-- @return threshold: number
function PluribusLootDecay:GetMinGPThreshold()
	return self.config.minGPThreshold
end

--- Check if player meets minimum GP threshold
-- @param playerName: string
-- @return meetsThreshold: bool
function PluribusLootDecay:MeetsMinGPThreshold(playerName)
	local player = PluribusLootEPGP.players[playerName]
	if not player then
		return false
	end
	
	return player.gp >= self.config.minGPThreshold
end

--- Set minimum GP threshold
-- @param amount: number
-- @return success: bool
function PluribusLootDecay:SetMinGPThreshold(amount)
	if not self:IsAdminOnly() then
		return false
	end
	
	amount = tonumber(amount) or 0
	if amount < 0 then
		amount = 0
	end
	
	self.config.minGPThreshold = amount
	PluribusUtils:Info("Minimum GP threshold set to " .. amount, "Decay")
	self:TriggerCallback("min_gp_threshold_changed", amount)
	return true
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Check if player is admin
-- @return isAdmin: bool
function PluribusLootDecay:IsAdminOnly()
	if not self.config.adminOnly then
		return true
	end
	
	-- Check with PluribusLoot access control
	if PluribusLootAccessControl and PluribusLootAccessControl.HasPermission then
		return PluribusLootAccessControl:HasPermission(UnitName("player"), "configure_decay")
	end
	
	return true
end

--- Register callback
-- @param callback: function
function PluribusLootDecay:RegisterCallback(callback)
	if type(callback) ~= "function" then
		return false
	end
	table.insert(self.callbacks, callback)
	return true
end

--- Trigger callback
-- @param event: string
-- @param ...: varargs
function PluribusLootDecay:TriggerCallback(event, ...)
	for _, callback in ipairs(self.callbacks) do
		pcall(callback, event, ...)
	end
end

return PluribusLootDecay
