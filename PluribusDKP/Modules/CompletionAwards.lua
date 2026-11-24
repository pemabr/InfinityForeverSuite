-- Completion Awards System
-- Awards EP/DKP when raid lock ends, encounters completed, or raid instance changes
-- Prevents players from farming the same encounters multiple times

local CompletionAwards = {
	config = {
		enableCompletionAwards = true,
		raidLockCompletionBonus = 100, -- EP bonus for completing full raid lock
		encounterCompletionBonus = 20, -- EP per encounter completed
		raidZoneChangeReward = 50, -- Reward for entering new raid zone
		enableWeeklyRaidBonus = true,
		weeklyRaidBonusAmount = 150, -- Bonus for completing raid in first reset
		notifyCompletion = true,
		preventDuplicateAwards = true, -- Don't award twice for same lock
		resetOnTuesday = true, -- Reset awards on Tuesday maintenance
	},
	
	raidLockStatus = {}, -- {playerName = {zone = zoneName, encounters = {bossID = true}, timestamp = time}}
	weeklyCompletions = {}, -- {playerName = {week = weekNum, year = year, zoneID = zoneID}}
	lockCompletions = {}, -- {playerName = {zone = {timestamp, encounters}}}
}

_G.PluribusCompletionAwards = CompletionAwards

function CompletionAwards:Initialize()
	PluribusUtils:Info("Completion Awards system initialized", "DKP")
	self:LoadAwardData()
	
	-- Hook raid events
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	frame:RegisterEvent("ENCOUNTER_END")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if event == "ZONE_CHANGED_NEW_AREA" then
			CompletionAwards:OnZoneChange()
		elseif event == "ENCOUNTER_END" then
			CompletionAwards:OnEncounterEnd(...)
		elseif event == "PLAYER_ENTERING_WORLD" then
			CompletionAwards:OnWorldEnter()
		end
	end)
end

function CompletionAwards:OnZoneChange()
	local playerName = UnitName("player")
	local zoneID = C_Map.GetMapIDForUiMapID(C_Map.GetBestMapID())
	
	-- Check if entering a raid zone
	local instanceType = select(2, IsInInstance())
	
	if instanceType == "raid" then
		self:OnEnterRaidZone(playerName, zoneID)
	elseif instanceType == "none" then
		-- Left a raid zone - check for completion
		if self.raidLockStatus[playerName] then
			self:CheckRaidCompletion(playerName)
		end
	end
end

function CompletionAwards:OnEnterRaidZone(playerName, zoneID)
	if not self.raidLockStatus[playerName] then
		self.raidLockStatus[playerName] = {
			zone = zoneID,
			encounters = {},
			enterTime = time(),
		}
		
		-- Check if first time in zone this week
		if self:IsFirstRaidZoneVisit(playerName, zoneID) then
			self:AwardRaidZoneBonus(playerName, zoneID)
		end
	end
end

function CompletionAwards:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
	if not success then return end
	
	local playerName = UnitName("player")
	
	if not self.raidLockStatus[playerName] then
		self.raidLockStatus[playerName] = {
			zone = C_Map.GetMapIDForUiMapID(C_Map.GetBestMapID()),
			encounters = {},
		}
	end
	
	-- Mark encounter as completed
	self.raidLockStatus[playerName].encounters[encounterID] = true
	
	-- Award encounter completion bonus
	if self.config.enableCompletionAwards and self.config.encounterCompletionBonus > 0 then
		self:AwardToRaidGroup(encounterName .. " Completion Bonus", self.config.encounterCompletionBonus)
	end
	
	self:SaveAwardData()
end

function CompletionAwards:OnWorldEnter()
	-- Check if entering a raid or leaving one
	local instanceType = select(2, IsInInstance())
	local playerName = UnitName("player")
	
	if instanceType == "none" and self.raidLockStatus[playerName] then
		-- Left raid zone
		self:CheckRaidCompletion(playerName)
	end
end

function CompletionAwards:CheckRaidCompletion(playerName)
	if not self.raidLockStatus[playerName] then return end
	
	local status = self.raidLockStatus[playerName]
	local encounterCount = 0
	
	for _ in pairs(status.encounters) do
		encounterCount = encounterCount + 1
	end
	
	-- Award completion bonus if unlocked
	if encounterCount > 0 and not status.awarded then
		if self.config.enableCompletionAwards and self.config.raidLockCompletionBonus > 0 then
			local memberData = PluribusGuildRoster:GetMember(playerName)
			if memberData then
				memberData.dkpBalance = (memberData.dkpBalance or 0) + self.config.raidLockCompletionBonus
				
				-- Record transaction
				if PluribusDKP and PluribusDKP.RecordTransaction then
					PluribusDKP:RecordTransaction({
						type = "award",
						player = playerName,
						amount = self.config.raidLockCompletionBonus,
						reason = "Raid Lock Completion (" .. encounterCount .. " encounters)",
						timestamp = time(),
					})
				end
				
				if self.config.notifyCompletion then
					PluribusUtils:Info(playerName .. " awarded " .. self.config.raidLockCompletionBonus .. " EP for raid lock completion", "DKP")
				end
			end
		end
		
		status.awarded = true
	end
	
	self:SaveAwardData()
end

function CompletionAwards:AwardRaidZoneBonus(playerName, zoneID)
	if not self.config.enableCompletionAwards or self.config.raidZoneChangeReward <= 0 then
		return
	end
	
	-- Award zone entry bonus
	local memberData = PluribusGuildRoster:GetMember(playerName)
	if memberData then
		memberData.dkpBalance = (memberData.dkpBalance or 0) + self.config.raidZoneChangeReward
		
		if PluribusDKP and PluribusDKP.RecordTransaction then
			PluribusDKP:RecordTransaction({
				type = "award",
				player = playerName,
				amount = self.config.raidZoneChangeReward,
				reason = "Raid Zone Entry Bonus",
				timestamp = time(),
			})
		end
	end
end

function CompletionAwards:AwardToRaidGroup(reason, amount)
	-- Award to all members of raid group
	local groupSize = GetNumGroupMembers()
	if groupSize == 0 then return end
	
	for i = 1, groupSize do
		local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
		if name and online then
			local memberData = PluribusGuildRoster:GetMember(name)
			if memberData then
				memberData.dkpBalance = (memberData.dkpBalance or 0) + amount
				
				if PluribusDKP and PluribusDKP.RecordTransaction then
					PluribusDKP:RecordTransaction({
						type = "award",
						player = name,
						amount = amount,
						reason = reason,
						timestamp = time(),
					})
				end
			end
		end
	end
end

function CompletionAwards:IsFirstRaidZoneVisit(playerName, zoneID)
	if not self.config.enableWeeklyRaidBonus then return false end
	
	-- Check if already visited this zone this week
	local weekNumber = self:GetCurrentWeek()
	local year = self:GetCurrentYear()
	
	if not self.weeklyCompletions[playerName] then
		self.weeklyCompletions[playerName] = {}
	end
	
	for _, visit in ipairs(self.weeklyCompletions[playerName]) do
		if visit.week == weekNumber and visit.year == year and visit.zoneID == zoneID then
			return false -- Already visited this week
		end
	end
	
	-- Mark visit
	table.insert(self.weeklyCompletions[playerName], {
		week = weekNumber,
		year = year,
		zoneID = zoneID,
		timestamp = time(),
	})
	
	return true
end

function CompletionAwards:GetCurrentWeek()
	local date = C_DateAndTime.GetCurrentCalendarTime()
	local dayOfYear = self:GetDayOfYear(date.month, date.monthDay, date.year)
	return math.floor((dayOfYear - date.weekday + 10) / 7)
end

function CompletionAwards:GetCurrentYear()
	return C_DateAndTime.GetCurrentCalendarTime().year
end

function CompletionAwards:GetDayOfYear(month, day, year)
	local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
	
	if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
		daysInMonth[2] = 29
	end
	
	local dayOfYear = day
	for i = 1, month - 1 do
		dayOfYear = dayOfYear + daysInMonth[i]
	end
	
	return dayOfYear
end

function CompletionAwards:ResetWeeklyCompletions()
	-- Called on Tuesday maintenance
	for playerName, _ in pairs(self.weeklyCompletions) do
		self.weeklyCompletions[playerName] = {}
	end
	self:SaveAwardData()
	PluribusUtils:Info("Weekly raid completions reset", "DKP")
end

function CompletionAwards:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		PluribusUtils:Info("Completion Awards config updated: " .. key .. " = " .. tostring(value), "DKP")
		self:SaveAwardData()
	end
end

function CompletionAwards:PrintConfig()
	print("|cffffd700=== Completion Awards Configuration ===|r")
	print("Enable: " .. tostring(self.config.enableCompletionAwards))
	print("Raid Lock Completion Bonus: " .. self.config.raidLockCompletionBonus)
	print("Encounter Completion Bonus: " .. self.config.encounterCompletionBonus)
	print("Raid Zone Entry Bonus: " .. self.config.raidZoneChangeReward)
	print("Weekly Raid Bonus Enabled: " .. tostring(self.config.enableWeeklyRaidBonus))
	print("Weekly Raid Bonus Amount: " .. self.config.weeklyRaidBonusAmount)
end

function CompletionAwards:SaveAwardData()
	if not _G.PluribusSavedData then
		_G.PluribusSavedData = {}
	end
	
	_G.PluribusSavedData.completionAwards = {
		config = self.config,
		raidLockStatus = self.raidLockStatus,
		weeklyCompletions = self.weeklyCompletions,
	}
end

function CompletionAwards:LoadAwardData()
	if not _G.PluribusSavedData then
		_G.PluribusSavedData = {}
		return
	end
	
	local savedData = _G.PluribusSavedData.completionAwards or {}
	
	if savedData.config then
		for key, value in pairs(savedData.config) do
			self.config[key] = value
		end
	end
	
	self.raidLockStatus = savedData.raidLockStatus or {}
	self.weeklyCompletions = savedData.weeklyCompletions or {}
end

return CompletionAwards
