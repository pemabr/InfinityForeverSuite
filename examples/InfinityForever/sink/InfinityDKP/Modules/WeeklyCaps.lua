-- Weekly Caps System
-- Implements point caps and limits to control DKP growth
-- Prevents single players from accumulating too much in short periods

local WeeklyCaps = {
	config = {
		enableWeeklyCaps = true,
		weeklyCapAmount = 500, -- Max points per week
		hardCapAmount = 2000, -- Lifetime max points
		capResetDay = 1, -- Monday (1 = Monday, 7 = Sunday)
		capResetTime = 0, -- Midnight server time
		enforceHardCap = true, -- Stop awarding when at hard cap
		notifyOnCapReached = true, -- Notify when player hits weekly cap
		exemptOfficers = false, -- Officers can exceed caps
	},
	
	weeklyEarnings = {}, -- {playerName = {amount = n, week = weekNumber, year = year}}
	capExemptions = {}, -- {playerName = true/false}
	
	currentWeek = 0,
	currentYear = 0,
}

_G.InfinityWeeklyCaps = WeeklyCaps

function WeeklyCaps:Initialize()
	InfinityUtils:Info("Weekly Caps system initialized", "DKP")
	
	-- Load saved cap data
	self:LoadCapData()
	
	-- Calculate current week
	self:UpdateCurrentWeek()
	
	-- Register for weekly reset
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	
	frame:SetScript("OnEvent", function(f, event)
		if event == "ZONE_CHANGED_NEW_AREA" then
			WeeklyCaps:UpdateCurrentWeek()
		end
	end)
end

function WeeklyCaps:UpdateCurrentWeek()
	local date = C_DateAndTime.GetCurrentCalendarTime()
	local year = date.year
	
	-- Calculate week number (ISO 8601)
	local dayOfYear = self:GetDayOfYear(date.month, date.monthDay, year)
	local weekNumber = math.floor((dayOfYear - date.weekday + 10) / 7)
	
	if weekNumber ~= self.currentWeek or year ~= self.currentYear then
		self.currentWeek = weekNumber
		self.currentYear = year
		InfinityUtils:Debug("Week updated: " .. year .. "-W" .. weekNumber, "DKP")
		self:ResetWeeklyEarnings()
	end
end

function WeeklyCaps:GetDayOfYear(month, day, year)
	local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
	
	-- Check for leap year
	if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
		daysInMonth[2] = 29
	end
	
	local dayOfYear = day
	for i = 1, month - 1 do
		dayOfYear = dayOfYear + daysInMonth[i]
	end
	
	return dayOfYear
end

function WeeklyCaps:ResetWeeklyEarnings()
	-- Clear earnings for players who have reached end of week
	for playerName, _ in pairs(self.weeklyEarnings) do
		local playerEarnings = self.weeklyEarnings[playerName]
		
		-- Check if player's earnings are from previous week
		if playerEarnings.week ~= self.currentWeek or playerEarnings.year ~= self.currentYear then
			self.weeklyEarnings[playerName] = {
				amount = 0,
				week = self.currentWeek,
				year = self.currentYear,
			}
		end
	end
	
	self:SaveCapData()
end

function WeeklyCaps:CanAward(playerName, awardAmount)
	if not self.config.enableWeeklyCaps then return true, nil end
	
	-- Check if officer exempt
	if self.config.exemptOfficers then
		local memberData = InfinityGuildRoster:GetMember(playerName)
		if memberData and (memberData.rank == "Guild Master" or memberData.rank == "Officer") then
			return true, nil
		end
	end
	
	-- Check hard cap
	local memberData = InfinityGuildRoster:GetMember(playerName)
	if memberData and self.config.enforceHardCap then
		local currentDKP = memberData.dkpBalance or 0
		if currentDKP >= self.config.hardCapAmount then
			return false, "HARD_CAP_REACHED"
		end
		
		-- Award would exceed hard cap?
		if currentDKP + awardAmount > self.config.hardCapAmount then
			local availableAmount = math.max(0, self.config.hardCapAmount - currentDKP)
			return true, {
				capped = true,
				actualAmount = availableAmount,
				deniedAmount = awardAmount - availableAmount,
			}
		end
	end
	
	-- Check weekly cap
	local weeklyEarnings = self:GetWeeklyEarnings(playerName)
	if weeklyEarnings + awardAmount > self.config.weeklyCapAmount then
		local availableAmount = math.max(0, self.config.weeklyCapAmount - weeklyEarnings)
		return true, {
			capped = true,
			actualAmount = availableAmount,
			deniedAmount = awardAmount - availableAmount,
			capType = "weekly",
		}
	end
	
	return true, nil
end

function WeeklyCaps:AwardDKPWithCap(playerName, awardAmount, reason)
	local canAward, capInfo = self:CanAward(playerName, awardAmount)
	
	if not canAward then
		if capInfo == "HARD_CAP_REACHED" then
			InfinityUtils:Warning(playerName .. " has reached hard cap (" .. self.config.hardCapAmount .. " DKP)", "DKP")
			if self.config.notifyOnCapReached then
				self:NotifyPlayerCapReached(playerName, "hard")
			end
		end
		return false, 0
	end
	
	local actualAmount = awardAmount
	
	-- Check if capped
	if capInfo and capInfo.capped then
		actualAmount = capInfo.actualAmount
		
		if self.config.notifyOnCapReached and capInfo.deniedAmount > 0 then
			self:NotifyPlayerCapReached(playerName, capInfo.capType, capInfo.deniedAmount)
		end
		
		InfinityUtils:Warning(playerName .. " hit " .. (capInfo.capType or "hard") .. " cap. Awarded " .. actualAmount .. " of " .. awardAmount .. " DKP", "DKP")
	end
	
	-- Award the capped amount
	if actualAmount > 0 then
		local memberData = InfinityGuildRoster:GetMember(playerName)
		if memberData then
			memberData.dkpBalance = (memberData.dkpBalance or 0) + actualAmount
			
			-- Record transaction
			if InfinityDKP and InfinityDKP.RecordTransaction then
				InfinityDKP:RecordTransaction({
					type = "award",
					player = playerName,
					amount = actualAmount,
					reason = reason .. (capInfo and capInfo.capped and " (capped)" or ""),
					timestamp = time(),
				})
			end
		end
		
		-- Track weekly earnings
		self:AddWeeklyEarnings(playerName, actualAmount)
		
		return true, actualAmount
	end
	
	return false, 0
end

function WeeklyCaps:AddWeeklyEarnings(playerName, amount)
	if not self.weeklyEarnings[playerName] then
		self.weeklyEarnings[playerName] = {
			amount = 0,
			week = self.currentWeek,
			year = self.currentYear,
		}
	end
	
	local earnings = self.weeklyEarnings[playerName]
	
	-- Check if week changed
	if earnings.week ~= self.currentWeek or earnings.year ~= self.currentYear then
		earnings.amount = 0
		earnings.week = self.currentWeek
		earnings.year = self.currentYear
	end
	
	earnings.amount = earnings.amount + amount
	self:SaveCapData()
end

function WeeklyCaps:GetWeeklyEarnings(playerName)
	if not self.weeklyEarnings[playerName] then
		return 0
	end
	
	local earnings = self.weeklyEarnings[playerName]
	
	-- Check if earnings are from current week
	if earnings.week == self.currentWeek and earnings.year == self.currentYear then
		return earnings.amount or 0
	end
	
	return 0
end

function WeeklyCaps:GetCapStatus(playerName)
	local weeklyEarnings = self:GetWeeklyEarnings(playerName)
	local memberData = InfinityGuildRoster:GetMember(playerName)
	local currentDKP = memberData and memberData.dkpBalance or 0
	
	local weeklyRemaining = math.max(0, self.config.weeklyCapAmount - weeklyEarnings)
	local hardCapRemaining = math.max(0, self.config.hardCapAmount - currentDKP)
	
	return {
		weeklyEarned = weeklyEarnings,
		weeklyRemaining = weeklyRemaining,
		currentDKP = currentDKP,
		hardCapRemaining = hardCapRemaining,
		weekNumber = self.currentWeek,
		year = self.currentYear,
	}
end

function WeeklyCaps:PrintCapStatus(playerName)
	local status = self:GetCapStatus(playerName)
	
	print("|cffffd700=== DKP Cap Status ===|r")
	print(playerName .. "'s Status:")
	print("  Current DKP: " .. status.currentDKP)
	print("  Hard Cap: " .. self.config.hardCapAmount .. " (Remaining: " .. status.hardCapRemaining .. ")")
	print("")
	print("  Week " .. status.year .. "-W" .. status.weekNumber .. ":")
	print("  Earned This Week: " .. status.weeklyEarned)
	print("  Weekly Cap: " .. self.config.weeklyCapAmount .. " (Remaining: " .. status.weeklyRemaining .. ")")
end

function WeeklyCaps:NotifyPlayerCapReached(playerName, capType, deniedAmount)
	local message = ""
	
	if capType == "hard" then
		message = string.format("|cffd00000You have reached your hard DKP cap (%d)!|r No further DKP awards until reset.",
			self.config.hardCapAmount)
	elseif capType == "weekly" then
		message = string.format("|cffd00000You have reached your weekly DKP cap (%d)!|r %d DKP points were not awarded.",
			self.config.weeklyCapAmount, deniedAmount or 0)
	end
	
	-- Send whisper to player if they're online
	-- This would require keeping player pointers, which is complex
	-- Instead, log to chat
	print(message)
end

function WeeklyCaps:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Weekly Caps config updated: " .. key .. " = " .. tostring(value), "DKP")
		self:SaveCapData()
	end
end

function WeeklyCaps:SetPlayerExemption(playerName, isExempt)
	self.capExemptions[playerName] = isExempt
	self:SaveCapData()
	InfinityUtils:Info(playerName .. " cap exemption: " .. tostring(isExempt), "DKP")
end

function WeeklyCaps:SaveCapData()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
	end
	
	_G.InfinityForeverSavedData.weeklyEarnings = self.weeklyEarnings
	_G.InfinityForeverSavedData.capConfig = self.config
	_G.InfinityForeverSavedData.capExemptions = self.capExemptions
	_G.InfinityForeverSavedData.currentWeek = self.currentWeek
	_G.InfinityForeverSavedData.currentYear = self.currentYear
end

function WeeklyCaps:LoadCapData()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
		return
	end
	
	self.weeklyEarnings = _G.InfinityForeverSavedData.weeklyEarnings or {}
	self.capExemptions = _G.InfinityForeverSavedData.capExemptions or {}
	
	if _G.InfinityForeverSavedData.capConfig then
		for key, value in pairs(_G.InfinityForeverSavedData.capConfig) do
			self.config[key] = value
		end
	end
	
	self.currentWeek = _G.InfinityForeverSavedData.currentWeek or 0
	self.currentYear = _G.InfinityForeverSavedData.currentYear or 0
end

return WeeklyCaps
