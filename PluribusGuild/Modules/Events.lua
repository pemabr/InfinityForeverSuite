-- PluribusGuildEvents Module
-- Manages guild events, raids, and member activity tracking

PluribusGuildEvents = {}
PluribusGuildEvents.events = {}
PluribusGuildEvents.raids = {}

function PluribusGuildEvents:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGuild", "events", {})
	self.events = storageData.events or {}
	self.raids = storageData.raids or {}
	
	PluribusUtils:Info("GuildEvents module initialized", "PluribusGuild")
end

function PluribusGuildEvents:CreateRaid(raidName, raidType, difficulty, timestamp)
	local raidId = "raid_" .. PluribusUtils:GetTimeStamp()
	
	local raid = {
		id = raidId,
		name = raidName,
		type = raidType or "DUNGEON",
		difficulty = difficulty or "Normal",
		created = timestamp or PluribusUtils:GetTimeStamp(),
		started = nil,
		completed = nil,
		status = "planned",
		participants = {},
		bosses = {},
		lootDistributed = {},
	}
	
	self.raids[raidId] = raid
	self:SaveEvents()
	PluribusMessaging:Publish("raid_created", { raidId = raidId, name = raidName })
	
	return raid
end

function PluribusGuildEvents:AddRaidParticipant(raidId, memberName, role)
	if not self.raids[raidId] then return nil end
	
	self.raids[raidId].participants[memberName] = {
		name = memberName,
		role = role or "DPS",
		joinTime = PluribusUtils:GetTimeStamp(),
		active = true,
	}
	
	self:SaveEvents()
	PluribusMessaging:Publish("raid_participant_added", { 
		raidId = raidId, 
		member = memberName,
		role = role 
	})
	
	return self.raids[raidId].participants[memberName]
end

function PluribusGuildEvents:StartRaid(raidId)
	if not self.raids[raidId] then return nil end
	
	self.raids[raidId].started = PluribusUtils:GetTimeStamp()
	self.raids[raidId].status = "active"
	
	self:SaveEvents()
	PluribusMessaging:Publish("raid_started", { raidId = raidId })
	
	return self.raids[raidId]
end

function PluribusGuildEvents:CompleteRaid(raidId)
	if not self.raids[raidId] then return nil end
	
	self.raids[raidId].completed = PluribusUtils:GetTimeStamp()
	self.raids[raidId].status = "completed"
	
	self:SaveEvents()
	PluribusMessaging:Publish("raid_completed", { raidId = raidId })
	
	return self.raids[raidId]
end

function PluribusGuildEvents:RecordBossKill(raidId, bossName, timestamp)
	if not self.raids[raidId] then return nil end
	
	local kill = {
		boss = bossName,
		timestamp = timestamp or PluribusUtils:GetTimeStamp(),
		participantCount = self:GetRaidParticipantCount(raidId),
	}
	
	table.insert(self.raids[raidId].bosses, kill)
	self:SaveEvents()
	PluribusMessaging:Publish("boss_killed", { 
		raidId = raidId, 
		boss = bossName 
	})
	
	return kill
end

function PluribusGuildEvents:RecordLootDrop(raidId, itemName, bossName, memberWinner, dkpSpent)
	if not self.raids[raidId] then return nil end
	
	local loot = {
		item = itemName,
		boss = bossName,
		winner = memberWinner,
		dkpSpent = dkpSpent or 0,
		timestamp = PluribusUtils:GetTimeStamp(),
	}
	
	table.insert(self.raids[raidId].lootDistributed, loot)
	self:SaveEvents()
	PluribusMessaging:Publish("loot_distributed", { 
		raidId = raidId, 
		item = itemName,
		winner = memberWinner 
	})
	
	return loot
end

function PluribusGuildEvents:GetRaid(raidId)
	return self.raids[raidId]
end

function PluribusGuildEvents:GetActiveRaids()
	local active = {}
	
	for raidId, raid in pairs(self.raids) do
		if raid.status == "active" then
			table.insert(active, raid)
		end
	end
	
	return active
end

function PluribusGuildEvents:GetRaidParticipantCount(raidId)
	if not self.raids[raidId] then return 0 end
	
	local count = 0
	for _, _ in pairs(self.raids[raidId].participants) do
		count = count + 1
	end
	
	return count
end

function PluribusGuildEvents:GetRaidStats(raidId)
	local raid = self.raids[raidId]
	if not raid then return nil end
	
	local duration = 0
	if raid.started and raid.completed then
		duration = raid.completed - raid.started
	end
	
	return {
		name = raid.name,
		type = raid.type,
		difficulty = raid.difficulty,
		status = raid.status,
		participantCount = self:GetRaidParticipantCount(raidId),
		bossesFelled = #raid.bosses,
		lootCount = #raid.lootDistributed,
		totalDKPSpent = function()
			local total = 0
			for _, loot in ipairs(raid.lootDistributed) do
				total = total + (loot.dkpSpent or 0)
			end
			return total
		end,
		durationSeconds = duration,
	}
end

function PluribusGuildEvents:CreateEvent(eventName, eventType, eventDate, description)
	local eventId = "event_" .. PluribusUtils:GetTimeStamp()
	
	local event = {
		id = eventId,
		name = eventName,
		type = eventType or "social",
		scheduledDate = eventDate or PluribusUtils:GetTimeStamp(),
		description = description or "",
		created = PluribusUtils:GetTimeStamp(),
		attendees = {},
		status = "scheduled",
	}
	
	self.events[eventId] = event
	self:SaveEvents()
	PluribusMessaging:Publish("guild_event_created", { eventId = eventId, name = eventName })
	
	return event
end

function PluribusGuildEvents:GetUpcomingEvents(daysAhead)
	daysAhead = daysAhead or 7
	local upcoming = {}
	local now = PluribusUtils:GetTimeStamp()
	local maxTime = now + (daysAhead * 86400)
	
	for eventId, event in pairs(self.events) do
		if event.scheduledDate >= now and event.scheduledDate <= maxTime and event.status == "scheduled" then
			table.insert(upcoming, event)
		end
	end
	
	table.sort(upcoming, function(a, b) return a.scheduledDate < b.scheduledDate end)
	
	return upcoming
end

function PluribusGuildEvents:SaveEvents()
	PluribusStorageManager:SetFeatureSetting("PluribusGuild", "events", {
		events = self.events,
		raids = self.raids,
	})
	PluribusDataManager:UpdateSourceData("PluribusGuild", "events", {
		events = self.events,
		raids = self.raids,
	})
end

return PluribusGuildEvents
