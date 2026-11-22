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

_G.InfinityBossKillAwards = BossKillAwards

local function ValidLocalConfig(config)
	if _G.issecretvalue and (issecretvalue(config) or (type(config) == "table" and
		(issecretvalue(config.enabled) or issecretvalue(config.amount) or issecretvalue(config.kind)))) then return false end
	return type(config) == "table" and type(config.enabled) == "boolean"
		and type(config.amount) == "number" and config.amount == config.amount and config.amount >= 1
		and config.amount <= 1000000000 and config.amount == math.floor(config.amount)
		and (config.kind == "dkp" or config.kind == "ep")
end

function BossKillAwards:InitializeLocal(db)
	if db.localBossAwards == nil then db.localBossAwards = { enabled = false, amount = 10, kind = "dkp" } end
	local config = db.localBossAwards
	if not ValidLocalConfig(config) then error("Invalid saved local boss award settings") end
	self.localConfig, self.localDB = config, db
end

function BossKillAwards:SetLocalConfig(enabled, kind, amount)
	local nextConfig = { enabled = enabled, kind = kind, amount = amount }
	if not ValidLocalConfig(nextConfig) or type(self.localDB) ~= "table"
		or self.localDB.localBossAwards ~= self.localConfig or not ValidLocalConfig(self.localConfig) then
		InfinityUtils:Warning("Invalid local boss award settings.", "DKP"); return false
	end
	self.localConfig.enabled, self.localConfig.kind, self.localConfig.amount = enabled, kind, amount
	return true
end

function BossKillAwards:HasValidLocalConfig()
	return ValidLocalConfig(self.localConfig) and type(self.localDB) == "table"
		and self.localDB.localBossAwards == self.localConfig
end

function BossKillAwards:AwardLocalRaid(raid, engine, points, sync)
	local config = self.localConfig
	if not ValidLocalConfig(config) then
		InfinityUtils:Warning("Boss award skipped: invalid configuration.", "DKP"); return false
	end
	if not config.enabled then return false end
	local kind, amount = config.kind, config.amount
	if _G.issecretvalue and issecretvalue(raid) then raid = nil end
	if type(raid) ~= "table" or (_G.issecretvalue and issecretvalue(raid.members)) or type(raid.members) ~= "table" then
		InfinityUtils:Warning("Boss award skipped: attendance unavailable.", "DKP"); return false
	end
	if (_G.issecretvalue and issecretvalue(raid.attendanceIncomplete)) or raid.attendanceIncomplete then
		InfinityUtils:Warning("Boss award skipped: attendance was incomplete.", "DKP"); return false
	end
	if _G.issecretvalue and issecretvalue(raid.localBossAward) then
		InfinityUtils:Warning("Boss award skipped: protected award state.", "DKP"); return false
	end
	if raid.localBossAward then return false end
	if not engine or type(engine.db) ~= "table" or type(engine.players) ~= "table"
		or engine.players ~= engine.db.players or not points or type(points.point_history) ~= "table"
		or points.point_history ~= engine.db.pointTransactions or engine.db.localBossAwards ~= config
		or type(engine.TriggerCallback) ~= "function" or type(points.TriggerCallback) ~= "function" then
		InfinityUtils:Warning("Boss award skipped: local points unavailable.", "DKP"); return false
	end
	if sync and ((_G.issecretvalue and issecretvalue(sync.outgoing)) or sync.outgoing) then
		InfinityUtils:Warning("Boss award skipped while a points snapshot is sending.", "DKP"); return false
	end
	if (_G.issecretvalue and issecretvalue(engine.system_type))
		or (kind == "dkp" and engine.system_type ~= "dkp")
		or (kind == "ep" and engine.system_type ~= "epgp") then
		InfinityUtils:Warning("Boss award skipped: selected points type does not match the local system.", "DKP"); return false
	end
	local boss = raid.name
	if _G.issecretvalue and issecretvalue(boss) then boss = nil end
	if type(boss) ~= "string" or boss == "" then
		InfinityUtils:Warning("Boss award skipped: encounter name unavailable.", "DKP"); return false
	end
	local recipients, missing = {}, 0
	for name, attendance in pairs(raid.members) do
		if _G.issecretvalue and (issecretvalue(name) or issecretvalue(attendance)) then
			InfinityUtils:Warning("Boss award skipped: protected attendance.", "DKP"); return false
		end
		if type(name) ~= "string" or name == "" or type(attendance) ~= "table"
			or (_G.issecretvalue and issecretvalue(attendance.present)) or type(attendance.present) ~= "boolean" then
			InfinityUtils:Warning("Boss award skipped: invalid attendance.", "DKP"); return false
		end
		if attendance.present then
			local player = engine.players[name]
			if _G.issecretvalue and issecretvalue(player) then
				InfinityUtils:Warning("Boss award skipped: protected player.", "DKP"); return false
			end
			if player == nil then
				missing = missing + 1
			elseif type(player) ~= "table" then
				InfinityUtils:Warning("Boss award skipped: invalid local player.", "DKP"); return false
			else
				local balance = player[kind]
				if _G.issecretvalue and issecretvalue(balance) then
					InfinityUtils:Warning("Boss award skipped: protected balance.", "DKP"); return false
				end
				if balance == nil then balance = 0 end
				if type(balance) ~= "number" or balance ~= balance or math.abs(balance) > 1000000000
					or balance + amount > 1000000000 then
					InfinityUtils:Warning("Boss award skipped: invalid or capped balance.", "DKP"); return false
				end
				recipients[#recipients + 1] = { name = name, player = player, balance = balance }
			end
		end
	end
	if #recipients == 0 then
		InfinityUtils:Warning("Boss award skipped: no recorded participants have local points.", "DKP"); return false
	end
	table.sort(recipients, function(a, b) return a.name < b.name end)
	local now, timestamp, reason = time(), date("%Y-%m-%d %H:%M:%S"), "Boss kill: " .. boss
	for _, entry in ipairs(recipients) do
		entry.player[kind] = entry.balance + amount
		entry.player.last_seen = now
		table.insert(points.point_history, { player = entry.name, type = kind, amount = amount,
			reason = reason, time = now, timestamp = timestamp })
	end
	raid.localBossAward = { kind = kind, amount = amount, recipients = #recipients, missing = missing }
	if sync and type(sync.MarkSnapshotsStale) == "function" then sync:MarkSnapshotsStale("Local boss award changed points") end
	for _, entry in ipairs(recipients) do
		engine:TriggerCallback(kind == "dkp" and "dkp_adjusted" or "ep_awarded", entry.name, amount, reason)
		points:TriggerCallback("transaction_logged", entry.name, kind, amount)
	end
	if missing > 0 then InfinityUtils:Warning("Boss award skipped " .. missing .. " unregistered local players.", "DKP") end
	InfinityUtils:Info("Local boss award: " .. #recipients .. " players, " .. amount .. " " .. kind:upper() .. ".", "DKP")
	return true
end

function BossKillAwards:Initialize()
	InfinityUtils:Info("Boss Kill Awards system initialized", "DKP")
	
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
	
	InfinityUtils:Debug("Encounter started: " .. encounterName .. " (ID: " .. encounterId .. ")", "DKP")
end

function BossKillAwards:OnEncounterEnd(encounterId, encounterName, difficultyID, numPlayers, success, bossIDs)
	if not self.config.enableBossKillAwards then return end
	if not self.activeEncounter then return end
	
	-- Only award on success
	if not success then
		InfinityUtils:Debug("Encounter failed: " .. encounterName, "DKP")
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
		InfinityUtils:Debug("No award configured for boss: " .. encounterName, "DKP")
		return
	end
	
	-- Get list of recipients
	local recipients = self:DetermineRecipients()
	
	if #recipients == 0 then
		InfinityUtils:Warning("No recipients for boss kill award: " .. encounterName, "DKP")
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
	
	InfinityUtils:Info(encounterName .. " defeated! Awarded " .. awardAmount .. " DKP to " .. awardCount .. " members", "DKP")
end

function BossKillAwards:CalculateAwardAmount(encounterId, numPlayers)
	-- Determine encounter type from encounter database
	local encounter = nil
	if InfinityEncounterDatabase then
		encounter = InfinityEncounterDatabase:GetEncounter(encounterId)
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
	if not InfinityDKP then return false end
	
	-- Get member data
	local memberData = InfinityGuildRoster:GetMember(playerName)
	if not memberData then
		InfinityUtils:Warning("Could not find member data for: " .. playerName, "DKP")
		return false
	end
	
	-- Award DKP
	memberData.dkpBalance = (memberData.dkpBalance or 0) + amount
	
	-- Record transaction
	if InfinityDKP.RecordTransaction then
		InfinityDKP:RecordTransaction({
			type = "award",
			category = "boss_kill",
			player = playerName,
			amount = amount,
			reason = reason,
			timestamp = time(),
		})
	end
	
	-- Publish event
	InfinityMessaging:Publish("dkp_awarded", playerName, amount, reason)
	
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
		InfinityUtils:Info("Boss Kill Awards config updated: " .. key .. " = " .. tostring(value), "DKP")
	end
end

function BossKillAwards:SaveKillTracker()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
	end
	
	_G.InfinityForeverSavedData.killTracker = self.killTracker
end

function BossKillAwards:LoadKillTracker()
	if not _G.InfinityForeverSavedData then
		_G.InfinityForeverSavedData = {}
		return
	end
	
	self.killTracker = _G.InfinityForeverSavedData.killTracker or {}
end

function BossKillAwards:OnUnitDied(unit)
	-- Optional: Track individual unit deaths (not boss deaths, just for reference)
	-- This can be used for combat log analysis later
end

return BossKillAwards
