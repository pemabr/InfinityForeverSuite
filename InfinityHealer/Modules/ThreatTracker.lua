-- InfinityHealer - Threat Tracking Module
-- Tracks threat/aggro status for raid members to help healers position safely

local ThreatTracker = {}
_G.InfinityThreatTracker = ThreatTracker

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

ThreatTracker.config = {
	updateInterval = 0.5, -- Update threat every 500ms
	threatAlertThreshold = 80, -- Alert when >80% threat
	criticalThreatThreshold = 95, -- Critical at >95%
	colors = {
		safe = {r = 0.2, g = 0.8, g = 0.2}, -- Green
		warning = {r = 1, g = 0.8, b = 0.2}, -- Yellow
		critical = {r = 1, g = 0.2, b = 0.2}, -- Red
	}
}

ThreatTracker.unitThreat = {} -- {unitToken = {threat, isTanking, threatPercent, targetName}}
ThreatTracker.threatHistory = {} -- {unitToken = [{timestamp, threat, percent}]}
ThreatTracker.maxHistorySize = 60 -- Keep 30 seconds at 2 Hz

-- ============================================================================
-- THREAT CALCULATION
-- ============================================================================

--- Get threat status for a unit
function ThreatTracker:GetThreatForUnit(unitToken)
	if not UnitExists(unitToken) then
		return nil
	end
	
	-- Use UnitThreatSituation API if available
	local isTanking, threatStatus, threatPercent = UnitThreatSituation(unitToken)
	local targetName = UnitName(unitToken)
	
	local threatData = {
		unitToken = unitToken,
		isTanking = isTanking or false,
		threat = threatPercent or 0,
		threatPercent = threatPercent or 0,
		targetName = targetName,
		alertState = self:GetAlertState(threatPercent or 0),
		timestamp = GetTime()
	}
	
	-- Store in history
	if not self.threatHistory[unitToken] then
		self.threatHistory[unitToken] = {}
	end
	
	table.insert(self.threatHistory[unitToken], {
		timestamp = GetTime(),
		threat = threatPercent or 0
	})
	
	-- Prune old history
	while #self.threatHistory[unitToken] > self.maxHistorySize do
		table.remove(self.threatHistory[unitToken], 1)
	end
	
	return threatData
end

--- Get alert state based on threat percentage
function ThreatTracker:GetAlertState(threatPercent)
	if threatPercent >= self.config.criticalThreatThreshold then
		return "critical" -- Immediate danger
	elseif threatPercent >= self.config.threatAlertThreshold then
		return "warning" -- Should move soon
	else
		return "safe" -- Safe
	end
end

--- Get threat color for UI rendering
function ThreatTracker:GetThreatColor(threatPercent)
	local state = self:GetAlertState(threatPercent)
	
	if state == "critical" then
		return self.config.colors.critical
	elseif state == "warning" then
		return self.config.colors.warning
	else
		return self.config.colors.safe
	end
end

-- ============================================================================
-- THREAT MANAGEMENT
-- ============================================================================

--- Update threat for all raid members
function ThreatTracker:UpdateRaidThreats()
	local groupSize = GetNumGroupMembers()
	
	if groupSize == 0 then
		return
	end
	
	for i = 1, groupSize do
		local unitToken
		if groupSize <= 5 then
			unitToken = i == 1 and "player" or ("party" .. (i - 1))
		else
			unitToken = "raid" .. i
		end
		
		if UnitExists(unitToken) then
			self.unitThreat[unitToken] = self:GetThreatForUnit(unitToken)
		end
	end
end

--- Get threat for specific unit
function ThreatTracker:GetUnitThreat(unitToken)
	return self.unitThreat[unitToken] or {
		unitToken = unitToken,
		isTanking = false,
		threat = 0,
		threatPercent = 0,
		alertState = "safe"
	}
end

--- Get all units in critical threat
function ThreatTracker:GetCriticalThreats()
	local critical = {}
	
	for unitToken, threat in pairs(self.unitThreat) do
		if threat.alertState == "critical" then
			table.insert(critical, threat)
		end
	end
	
	return critical
end

--- Get all units in warning threat
function ThreatTracker:GetWarningThreats()
	local warnings = {}
	
	for unitToken, threat in pairs(self.unitThreat) do
		if threat.alertState == "warning" then
			table.insert(warnings, threat)
		end
	end
	
	return warnings
end

--- Get highest threat targets
function ThreatTracker:GetHighestThreats(limit)
	local threats = {}
	
	for unitToken, threat in pairs(self.unitThreat) do
		table.insert(threats, threat)
	end
	
	-- Sort by threat descending
	table.sort(threats, function(a, b)
		return a.threatPercent > b.threatPercent
	end)
	
	-- Return top N
	local result = {}
	for i = 1, math.min(limit or 5, #threats) do
		table.insert(result, threats[i])
	end
	
	return result
end

--- Check if tanks have threat
function ThreatTracker:VerifyTankThreat()
	local tanks = {}
	
	for unitToken, threat in pairs(self.unitThreat) do
		if threat.isTanking then
			table.insert(tanks, threat)
		end
	end
	
	-- Should have at least one tank with threat
	return #tanks > 0, tanks
end

-- ============================================================================
-- THREAT HISTORY & ANALYSIS
-- ============================================================================

--- Get threat history for a unit
function ThreatTracker:GetThreatHistory(unitToken)
	return self.threatHistory[unitToken] or {}
end

--- Get average threat over time window
function ThreatTracker:GetAverageThreat(unitToken, timeWindow)
	timeWindow = timeWindow or 5 -- Default 5 seconds
	local now = GetTime()
	local cutoff = now - timeWindow
	
	local history = self:GetThreatHistory(unitToken)
	local sum = 0
	local count = 0
	
	for _, entry in ipairs(history) do
		if entry.timestamp >= cutoff then
			sum = sum + entry.threat
			count = count + 1
		end
	end
	
	return count > 0 and (sum / count) or 0
end

--- Get threat trend (rising, stable, falling)
function ThreatTracker:GetThreatTrend(unitToken)
	local history = self:GetThreatHistory(unitToken)
	
	if #history < 2 then
		return "stable"
	end
	
	-- Compare last 3 values
	local recent = {}
	for i = math.max(1, #history - 2), #history do
		table.insert(recent, history[i].threat)
	end
	
	if recent[#recent] > recent[1] then
		return "rising"
	elseif recent[#recent] < recent[1] then
		return "falling"
	else
		return "stable"
	end
end

--- Get threat per second (rate of threat gain)
function ThreatTracker:GetThreatRate(unitToken)
	local history = self:GetThreatHistory(unitToken)
	
	if #history < 2 then
		return 0
	end
	
	local latest = history[#history]
	local previous = history[#history - 1]
	
	local timeDiff = latest.timestamp - previous.timestamp
	if timeDiff == 0 then return 0 end
	
	local threatDiff = latest.threat - previous.threat
	return threatDiff / timeDiff
end

-- ============================================================================
-- THREAT POSITIONING HELPER
-- ============================================================================

--- Get suggested positioning for unit based on threat
function ThreatTracker:GetSuggestedPosition(unitToken)
	local threat = self:GetUnitThreat(unitToken)
	
	if threat.alertState == "critical" then
		return "REPOSITION_URGENT", "Move away from boss immediately!"
	elseif threat.alertState == "warning" then
		return "REPOSITION_SOON", "Consider repositioning away from boss"
	else
		return "SAFE", "Safe positioning"
	end
end

--- Get threat advisory message
function ThreatTracker:GetThreatAdvisory()
	local critical = self:GetCriticalThreats()
	local warnings = self:GetWarningThreats()
	
	if #critical > 0 then
		local names = {}
		for _, threat in ipairs(critical) do
			table.insert(names, UnitName(threat.unitToken))
		end
		return "CRITICAL: " .. table.concat(names, ", ") .. " have EXTREME THREAT!"
	elseif #warnings > 0 then
		local names = {}
		for _, threat in ipairs(warnings) do
			table.insert(names, UnitName(threat.unitToken))
		end
		return "WARNING: " .. table.concat(names, ", ") .. " gaining threat"
	else
		return "Threat: Normal"
	end
end

-- ============================================================================
-- THREAT-BASED HEALING PRIORITY
-- ============================================================================

--- Get healing priority considering threat positions
-- Units with low threat should be healed near the tank
-- Units with high threat should be topped quickly before they die
function ThreatTracker:GetThreatAwareHealingPriority()
	local priority = {}
	
	for unitToken, threat in pairs(self.unitThreat) do
		local health = UnitHealth(unitToken) or 100
		local maxHealth = UnitHealthMax(unitToken) or 100
		local healthPercent = (health / maxHealth) * 100
		
		-- Score based on health + threat
		-- Low health + high threat = highest priority
		local threatWeight = threat.threatPercent / 100
		local healthWeight = (100 - healthPercent) / 100
		
		local score = (threatWeight * 0.3) + (healthWeight * 0.7)
		
		table.insert(priority, {
			unitToken = unitToken,
			name = UnitName(unitToken),
			health = healthPercent,
			threat = threat.threatPercent,
			score = score
		})
	end
	
	-- Sort by priority score descending
	table.sort(priority, function(a, b)
		return a.score > b.score
	end)
	
	return priority
end

-- ============================================================================
-- INTEGRATION WITH HEALER FRAMES
-- ============================================================================

--- Register threat changes with healer frame
function ThreatTracker:RegisterFrameCallback(callback)
	if not self.frameCallbacks then
		self.frameCallbacks = {}
	end
	table.insert(self.frameCallbacks, callback)
end

--- Notify frames of threat changes
function ThreatTracker:NotifyFrameUpdate(unitToken)
	if not self.frameCallbacks then
		return
	end
	
	local threat = self:GetUnitThreat(unitToken)
	for _, callback in ipairs(self.frameCallbacks) do
		xpcall(callback, function(err)
			InfinityUtils:Warning("Frame callback error: " .. tostring(err), "Threat")
		end, unitToken, threat)
	end
end

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

function ThreatTracker:Initialize()
	InfinityUtils:Info("ThreatTracker initializing...", "Threat")
	
	-- Create update frame
	local updateFrame = CreateFrame("Frame")
	local elapsed = 0
	
	updateFrame:SetScript("OnUpdate", function(f, delta)
		elapsed = elapsed + delta
		
		if elapsed >= self.config.updateInterval then
			self:UpdateRaidThreats()
			elapsed = 0
		end
	end)
	
	InfinityUtils:Info("ThreatTracker initialized", "Threat")
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

if InfinityCommandRegistry then
	InfinityCommandRegistry:RegisterCommand("threat", function(args)
		if not args or #args == 0 then
			local advisory = ThreatTracker:GetThreatAdvisory()
			print("|cff00ccffThreat:|r " .. advisory)
		elseif args[1] == "list" then
			local threats = ThreatTracker:GetHighestThreats(10)
			print("|cff00ccffTop Threats:|r")
			for i, threat in ipairs(threats) do
				print(string.format("  %d. %s: %.1f%%", i, UnitName(threat.unitToken), threat.threatPercent))
			end
		elseif args[1] == "critical" then
			local critical = ThreatTracker:GetCriticalThreats()
			if #critical > 0 then
				print("|cffff4444CRITICAL THREATS:|r")
				for _, threat in ipairs(critical) do
					print("  " .. UnitName(threat.unitToken) .. ": " .. threat.threatPercent .. "%")
				end
			else
				print("No critical threats")
			end
		end
	end, {"threats"})
end

print("[INFO] Threat Tracker module loaded successfully")
