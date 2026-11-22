-- Decay System Module
-- Implements automatic DKP decay to prevent point hoarding
-- Supports configurable decay rates and schedules

local DecaySystem = {
	config = {
		enableDecay = true,
		decayRate = 0.05, -- 5% per week by default
		decaySchedule = "weekly", -- weekly, biweekly, monthly
		decayDay = 1, -- Monday (1 = Monday, 7 = Sunday)
		decayTime = 18, -- 6 PM server time
		minimumDKP = 0, -- Don't decay below this
		excludeOfficers = false, -- Officers exempt from decay
		notifyPlayers = true, -- Send notification before decay
	},
	
	decayHistory = {}, -- Track when decay was applied
	pendingDecay = {}, -- Players due for decay
	
	lastDecayRun = 0,
	decayActive = false,
}

_G.InfinityDecaySystem = DecaySystem

function DecaySystem:Initialize()
	InfinityUtils:Info("Decay System initialized", "DKP")
	
	-- Register decay events
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	
	frame:SetScript("OnEvent", function(f, event)
		if event == "ZONE_CHANGED_NEW_AREA" then
			DecaySystem:CheckDecaySchedule()
		end
	end)
	
	-- Initialize decay history from SavedVariables
	self:LoadDecayHistory()
	
	-- Check if decay is due
	self:CheckDecaySchedule()
end

function DecaySystem:CheckDecaySchedule()
	if not self.config.enableDecay then return end
	
	local now = time()
	local daysSinceLastDecay = math.floor((now - self.lastDecayRun) / 86400)
	
	-- Determine if decay is due based on schedule
	local decayDue = false
	
	if self.config.decaySchedule == "weekly" and daysSinceLastDecay >= 7 then
		decayDue = true
	elseif self.config.decaySchedule == "biweekly" and daysSinceLastDecay >= 14 then
		decayDue = true
	elseif self.config.decaySchedule == "monthly" and daysSinceLastDecay >= 30 then
		decayDue = true
	end
	
	if decayDue then
		-- Check if correct day/time
		if self:IsDecayTime() then
			self:PrepareDecayData()
		end
	end
end

function DecaySystem:IsDecayTime()
	local dateInfo = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime() or date("*t")
	local weekday = dateInfo.weekday or dateInfo.wday or 1
	local hour = dateInfo.hour or 0
	
	if weekday ~= self.config.decayDay then
		return false
	end
	
	if hour == self.config.decayTime or hour == self.config.decayTime - 1 then
		return true
	end
	
	return false
end

function DecaySystem:PrepareDecayData()
	-- Get all guild members
	local guildSize = GetNumGuildMembers()
	
	for i = 1, guildSize do
		local memberName = GetGuildMemberInfo(i)
		if memberName then
			local memberData = InfinityGuildRoster:GetMember(memberName)
			if memberData then
				table.insert(self.pendingDecay, {
					name = memberName,
					currentDKP = memberData.dkpBalance,
					decayAmount = 0,
					newDKP = memberData.dkpBalance,
				})
			end
		end
	end
	
	InfinityUtils:Info("Prepared decay for " .. #self.pendingDecay .. " members", "DKP")
	
	-- Notify guild about pending decay
	if self.config.notifyPlayers then
		self:NotifyGuildAboutDecay()
	end
end

function DecaySystem:NotifyGuildAboutDecay()
	local message = string.format(
		"|cff00ff00DKP Decay Alert:|r Decay will be applied to all members at %02d:00 server time. Decay rate: %.1f%%",
		self.config.decayTime,
		self.config.decayRate * 100
	)
	
	-- Send to guild chat if officer
	if CanEditPublicNote() then
		SendChatMessage(message, "GUILD")
	end
	
	-- Notify via system message
	print(message)
end

function DecaySystem:ApplyDecay()
	if not self.config.enableDecay then return end
	if self.decayActive then return end
	
	self.decayActive = true
	InfinityUtils:Info("Applying DKP decay...", "DKP")
	
	-- Get all guild members
	local guildSize = GetNumGuildMembers()
	local decayLog = {}
	
	for i = 1, guildSize do
		local memberName = GetGuildRosterInfo and GetGuildRosterInfo(i) or nil
		if memberName then
			local memberData = InfinityGuildRoster and InfinityGuildRoster:GetMember(memberName) or nil
			if memberData then
				if self:ShouldExcludeFromDecay(memberName, memberData) then
					InfinityUtils:Debug(memberName .. " excluded from decay", "DKP")
				else
					local currentDKP = memberData.dkpBalance or 0
					local decayAmount = currentDKP * self.config.decayRate
					local newDKP = math.max(currentDKP - decayAmount, self.config.minimumDKP)

					memberData.dkpBalance = newDKP

					table.insert(decayLog, {
						player = memberName,
						before = currentDKP,
						decayAmount = decayAmount,
						after = newDKP,
						timestamp = time(),
					})

					if InfinityDKP and InfinityDKP.RecordTransaction then
						InfinityDKP:RecordTransaction({
							type = "decay",
							player = memberName,
							amount = -decayAmount,
							reason = "Automatic decay (" .. string.format("%.1f%%", self.config.decayRate * 100) .. ")",
							timestamp = time(),
						})
					end
				end
			end
		end
	end
	
	-- Save decay history
	self.lastDecayRun = time()
	self.decayHistory[self.lastDecayRun] = {
		rate = self.config.decayRate,
		membersAffected = #decayLog,
		log = decayLog,
	}
	
	self:SaveDecayHistory()
	
	-- Announce results
	self:AnnounceDecayResults(decayLog)
	
	self.decayActive = false
	self.pendingDecay = {}
	
	InfinityUtils:Info("Decay applied to " .. #decayLog .. " members", "DKP")
end

function DecaySystem:ShouldExcludeFromDecay(playerName, memberData)
	-- Exclude officers if configured
	if self.config.excludeOfficers then
		local rank = memberData.rank
		if rank == "Guild Master" or rank == "Officer" then
			return true
		end
	end
	
	return false
end

function DecaySystem:AnnounceDecayResults(decayLog)
	local totalDecay = 0
	local minDecay = math.huge
	local maxDecay = 0
	
	for _, entry in ipairs(decayLog) do
		totalDecay = totalDecay + entry.decayAmount
		minDecay = math.min(minDecay, entry.decayAmount)
		maxDecay = math.max(maxDecay, entry.decayAmount)
	end
	
	local message = string.format(
		"|cff00ff00DKP Decay Complete:|r %d members affected. Total decayed: %.1f DKP. Range: %.1f-%.1f DKP",
		#decayLog, totalDecay, minDecay, maxDecay
	)
	
	print(message)
	
	-- Send to guild chat if officer
	if CanEditPublicNote() then
		SendChatMessage(message, "GUILD")
	end
end

function DecaySystem:GetDecayHistory()
	return self.decayHistory
end

function DecaySystem:GetDecayStatus(playerName)
	-- Get estimated next decay date
	if self.lastDecayRun == 0 then
		return "No decay history"
	end
	
	local now = time()
	local nextDecay = self.lastDecayRun
	
	if self.config.decaySchedule == "weekly" then
		nextDecay = self.lastDecayRun + (7 * 86400)
	elseif self.config.decaySchedule == "biweekly" then
		nextDecay = self.lastDecayRun + (14 * 86400)
	elseif self.config.decaySchedule == "monthly" then
		nextDecay = self.lastDecayRun + (30 * 86400)
	end
	
	local secondsUntilDecay = nextDecay - now
	local daysUntilDecay = math.floor(secondsUntilDecay / 86400)
	
	return string.format("Next decay: %d days, %d hours", 
		daysUntilDecay, 
		math.floor((secondsUntilDecay % 86400) / 3600)
	)
end

function DecaySystem:CalculateDecay(currentDKP)
	local decayAmount = currentDKP * self.config.decayRate
	local newDKP = math.max(currentDKP - decayAmount, self.config.minimumDKP)
	return newDKP, decayAmount
end

function DecaySystem:PreviewDecay()
	-- Show what decay would do to current member's DKP
	local playerName = UnitName("player")
	local memberData = InfinityGuildRoster:GetMember(playerName)
	
	if not memberData then
		print("Could not find member data")
		return
	end
	
	local currentDKP = memberData.dkpBalance or 0
	local newDKP, decayAmount = self:CalculateDecay(currentDKP)
	
	print(string.format("|cffffd700Decay Preview:|r Your DKP: %.1f → %.1f (decay: %.1f, rate: %.1f%%)",
		currentDKP, newDKP, decayAmount, self.config.decayRate * 100))
end

function DecaySystem:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Decay System config updated: " .. key .. " = " .. tostring(value), "DKP")
		self:SaveDecayHistory()
	end
end

function DecaySystem:SaveDecayHistory()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
	end
	
	_G.InfinityForeverSavedData.decayHistory = self.decayHistory
	_G.InfinityForeverSavedData.lastDecayRun = self.lastDecayRun
	_G.InfinityForeverSavedData.decayConfig = self.config
end

function DecaySystem:LoadDecayHistory()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
		return
	end
	
	self.decayHistory = _G.InfinityForeverSavedData.decayHistory or {}
	self.lastDecayRun = _G.InfinityForeverSavedData.lastDecayRun or 0
	
	if _G.InfinityForeverSavedData.decayConfig then
		for key, value in pairs(_G.InfinityForeverSavedData.decayConfig) do
			self.config[key] = value
		end
	end
end

function DecaySystem:ManualDecay()
	-- Trigger decay immediately (admin only)
	if not CanEditPublicNote() then
		print("Only guild officers can trigger manual decay")
		return
	end
	
	self:ApplyDecay()
end

return DecaySystem
