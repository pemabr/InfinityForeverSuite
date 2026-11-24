-- Boss Kill Awards System
-- Automatically awards DKP points when raid bosses are defeated
-- Integrates with encounter data for raid vs. dungeon detection

local BossKillAwards = {
	config = {
		enableBossKillAwards = true,
		raidBossAwardAmount = 100, -- DKP for raid boss kills
		dungeonBossAwardAmount = 50, -- DKP for dungeon boss kills
		worldBossAwardAmount = 75, -- DKP for world boss kills
		includePartialRaids = true, -- Award even if raid not full
		awardAllParticipants = true, -- Award everyone in raid or just attendees
		notifyGuild = true, -- Announce kill to guild
	},
	
	killTracker = {}, -- {bossID = {lastKillTime = time, killCount = n}}
	activeEncounter = nil,
	encounterStartTime = 0,
	encounterParticipants = {}, -- Players who participated
}

_G.PluribusBossKillAwards = BossKillAwards

function BossKillAwards:Initialize()
	PluribusUtils:Info("Boss Kill Awards system initialized", "DKP")
	
	-- Register for encounter events
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ENCOUNTER_START")
	frame:RegisterEvent("ENCOUNTER_END")
	frame:RegisterEvent("UNIT_DIED")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if event == "ENCOUNTER_START" then
			BossKillAwards:OnEncounterStart(...)
		elseif event == "ENCOUNTER_END" then
			BossKillAwards:OnEncounterEnd(...)
		elseif event == "UNIT_DIED" then
			BossKillAwards:OnUnitDied(...)
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			BossKillAwards:ResetEncounterState()
		end
	end)
	
	-- Load kill history
	self:LoadKillTracker()
end

function BossKillAwards:OnEncounterStart(encounterId, encounterName, difficultyID, numPlayers, bossIDs)
	if not self.config.enableBossKillAwards then return end
	
	self.activeEncounter = {
		id = encounterId,
		name = encounterName,
		difficulty = difficultyID,
		numPlayers = numPlayers,
		bossIDs = bossIDs,
	}
	
	self.encounterStartTime = time()
	self.encounterParticipants = {}
	
	-- Record who was in raid at start
	self:RecordEncounterParticipants()
	
	PluribusUtils:Debug("Encounter started: " .. encounterName .. " (ID: " .. encounterId .. ")", "DKP")
end

function BossKillAwards:OnEncounterEnd(encounterId, encounterName, difficultyID, numPlayers, success, bossIDs)
	if not self.config.enableBossKillAwards then return end
	if not self.activeEncounter then return end
	
	-- Only award on success
	if not success then
		PluribusUtils:Debug("Encounter failed: " .. encounterName, "DKP")
		self.activeEncounter = nil
		return
	end
	
	-- Award DKP for boss kill
	self:AwardBossKill(encounterId, encounterName, numPlayers)
	
	-- Record kill in history
	self:RecordKill(encounterId, encounterName)
	
	self.activeEncounter = nil
	self.encounterParticipants = {}
end

function BossKillAwards:RecordEncounterParticipants()
	-- Record raid composition at encounter start
	if not IsInRaid() then return end
	
	local raidSize = GetNumGroupMembers()
	for i = 1, raidSize do
		local name = GetRaidRosterInfo(i)
		if name then
			table.insert(self.encounterParticipants, name)
		end
	end
end

function BossKillAwards:AwardBossKill(encounterId, encounterName, numPlayers)
	-- Determine award amount based on encounter type
	local awardAmount = self:CalculateAwardAmount(encounterId, numPlayers)
	
	if awardAmount <= 0 then
		PluribusUtils:Debug("No award configured for boss: " .. encounterName, "DKP")
		return
	end
	
	-- Get list of recipients
	local recipients = self:DetermineRecipients()
	
	if #recipients == 0 then
		PluribusUtils:Warning("No recipients for boss kill award: " .. encounterName, "DKP")
		return
	end
	
	-- Award DKP to each recipient
	local awardCount = 0
	for _, playerName in ipairs(recipients) do
		if self:AwardDKP(playerName, awardAmount, "Boss Kill: " .. encounterName) then
			awardCount = awardCount + 1
		end
	end
	
	-- Notify guild
	if self.config.notifyGuild and awardCount > 0 then
		self:NotifyGuildAboutKill(encounterName, awardAmount, awardCount)
	end
	
	PluribusUtils:Info(encounterName .. " defeated! Awarded " .. awardAmount .. " DKP to " .. awardCount .. " members", "DKP")
end

function BossKillAwards:CalculateAwardAmount(encounterId, numPlayers)
	-- Determine encounter type from encounter database
	local encounter = nil
	if PluribusEncounterDatabase then
		encounter = PluribusEncounterDatabase:GetEncounter(encounterId)
	end
	
	-- Use encounter data to determine type
	if encounter then
		local zone = encounter.zone
		
		if zone == "Molten Core" or zone == "Blackwing Lair" or zone == "Naxxramas" or 
		   zone == "Temple of Ahn'Qiraj" or zone == "World of Warcraft" then
			return self.config.raidBossAwardAmount
		elseif zone == "Zul'Farrak" or zone == "Blackrock Spire" or zone == "Onyxia's Lair" then
			return self.config.dungeonBossAwardAmount
		elseif zone:find("World") or zone:find("Dragons") or zone:find("Outdoor") then
			return self.config.worldBossAwardAmount
		end
	end
	
	-- Fallback: use player count to guess type
	if numPlayers >= 20 then
		return self.config.raidBossAwardAmount
	elseif numPlayers >= 5 then
		return self.config.dungeonBossAwardAmount
	else
		return 0
	end
end

function BossKillAwards:DetermineRecipients()
	local recipients = {}
	
	if not IsInRaid() then
		return recipients
	end
	
	-- Award all raid members who were there
	local raidSize = GetNumGroupMembers()
	for i = 1, raidSize do
		local name = GetRaidRosterInfo(i)
		if name then
			table.insert(recipients, name)
		end
	end
	
	return recipients
end

function BossKillAwards:AwardDKP(playerName, amount, reason)
	if not PluribusDKP then return false end
	
	-- Get member data
	local memberData = PluribusGuildRoster:GetMember(playerName)
	if not memberData then
		PluribusUtils:Warning("Could not find member data for: " .. playerName, "DKP")
		return false
	end
	
	-- Award DKP
	memberData.dkpBalance = (memberData.dkpBalance or 0) + amount
	
	-- Record transaction
	if PluribusDKP.RecordTransaction then
		PluribusDKP:RecordTransaction({
			type = "award",
			category = "boss_kill",
			player = playerName,
			amount = amount,
			reason = reason,
			timestamp = time(),
		})
	end
	
	-- Publish event
	PluribusMessaging:Publish("dkp_awarded", playerName, amount, reason)
	
	return true
end

function BossKillAwards:RecordKill(bossId, bossName)
	if not self.killTracker[bossId] then
		self.killTracker[bossId] = {
			name = bossName,
			kills = 0,
			firstKillTime = time(),
			lastKillTime = time(),
		}
	else
		self.killTracker[bossId].lastKillTime = time()
		self.killTracker[bossId].kills = self.killTracker[bossId].kills + 1
	end
	
	self:SaveKillTracker()
end

function BossKillAwards:NotifyGuildAboutKill(bossName, awardAmount, recipientCount)
	local message = string.format(
		"|cff00ff00Boss Kill!|r %s defeated! +%d DKP awarded to %d members",
		bossName, awardAmount, recipientCount
	)
	
	print(message)
	
	-- Send to guild chat if in guild
	if IsInGuild() and CanEditPublicNote() then
		SendChatMessage(message, "GUILD")
	end
	
	-- Send to raid chat
	if IsInRaid() then
		SendChatMessage(message, "RAID")
	end
end

function BossKillAwards:GetKillStatistics()
	local stats = {
		totalKills = 0,
		uniqueBosses = 0,
		recentKills = {},
	}
	
	for bossId, killData in pairs(self.killTracker) do
		stats.totalKills = stats.totalKills + (killData.kills or 1)
		stats.uniqueBosses = stats.uniqueBosses + 1
		
		table.insert(stats.recentKills, {
			bossName = killData.name,
			lastKillTime = killData.lastKillTime,
			killCount = killData.kills or 1,
		})
	end
	
	-- Sort by most recent
	table.sort(stats.recentKills, function(a, b)
		return a.lastKillTime > b.lastKillTime
	end)
	
	return stats
end

function BossKillAwards:PrintKillStatistics()
	local stats = self:GetKillStatistics()
	
	print("|cffffd700=== Boss Kill Statistics ===|r")
	print("Total Kills: " .. stats.totalKills)
	print("Unique Bosses: " .. stats.uniqueBosses)
	print("")
	print("Recent Kills:")
	
	for i = 1, math.min(10, #stats.recentKills) do
		local kill = stats.recentKills[i]
		local daysSince = math.floor((time() - kill.lastKillTime) / 86400)
		print("  " .. kill.bossName .. " (" .. kill.killCount .. " times, " .. daysSince .. " days ago)")
	end
end

function BossKillAwards:ResetEncounterState()
	self.activeEncounter = nil
	self.encounterParticipants = {}
	self.encounterStartTime = 0
end

function BossKillAwards:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		PluribusUtils:Info("Boss Kill Awards config updated: " .. key .. " = " .. tostring(value), "DKP")
	end
end

function BossKillAwards:SaveKillTracker()
	if not _G.PluribusSavedData then
		_G.PluribusSavedData = {}
	end
	
	_G.PluribusSavedData.killTracker = self.killTracker
end

function BossKillAwards:LoadKillTracker()
	if not _G.PluribusSavedData then
		_G.PluribusSavedData = {}
		return
	end
	
	self.killTracker = _G.PluribusSavedData.killTracker or {}
end

function BossKillAwards:OnUnitDied(unit)
	-- Optional: Track individual unit deaths (not boss deaths, just for reference)
	-- This can be used for combat log analysis later
end

return BossKillAwards
