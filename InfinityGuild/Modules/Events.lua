-- InfinityGuildEvents Module
-- Manages guild events, raids, and member activity tracking

InfinityGuildEvents = {}
InfinityGuildEvents.events = {}
InfinityGuildEvents.raids = {}

function InfinityGuildEvents:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGuild", "events", {})
	self.events = storageData.events or {}
	self.raids = storageData.raids or {}
	
	InfinityUtils:Info("GuildEvents module initialized", "InfinityGuild")
end

function InfinityGuildEvents:CreateRaid(raidName, raidType, difficulty, timestamp)
	local raidId = "raid_" .. InfinityUtils:GetTimeStamp()
	local base, suffix = raidId, 1
	while self.raids[raidId] do
		raidId = base .. "_" .. suffix
		suffix = suffix + 1
	end
	
	local raid = {
		id = raidId,
		name = raidName,
		type = raidType or "DUNGEON",
		difficulty = difficulty or "Normal",
		created = timestamp or InfinityUtils:GetTimeStamp(),
		started = nil,
		completed = nil,
		status = "planned",
		participants = {},
		bosses = {},
		lootDistributed = {},
	}
	
	self.raids[raidId] = raid
	self:SaveEvents()
	InfinityMessaging:Publish("raid_created", { raidId = raidId, name = raidName })
	
	return raid
end

function InfinityGuildEvents:AddRaidParticipant(raidId, memberName, role)
	if not self.raids[raidId] then return nil end
	
	self.raids[raidId].participants[memberName] = {
		name = memberName,
		role = role or "DPS",
		joinTime = InfinityUtils:GetTimeStamp(),
		active = true,
	}
	
	self:SaveEvents()
	InfinityMessaging:Publish("raid_participant_added", { 
		raidId = raidId, 
		member = memberName,
		role = role 
	})
	
	return self.raids[raidId].participants[memberName]
end

function InfinityGuildEvents:StartRaid(raidId)
	if not self.raids[raidId] then return nil end
	
	self.raids[raidId].started = InfinityUtils:GetTimeStamp()
	self.raids[raidId].status = "active"
	
	self:SaveEvents()
	InfinityMessaging:Publish("raid_started", { raidId = raidId })
	
	return self.raids[raidId]
end

function InfinityGuildEvents:CompleteRaid(raidId)
	if not self.raids[raidId] then return nil end
	
	self.raids[raidId].completed = InfinityUtils:GetTimeStamp()
	self.raids[raidId].status = "completed"
	
	self:SaveEvents()
	InfinityMessaging:Publish("raid_completed", { raidId = raidId })
	
	return self.raids[raidId]
end

function InfinityGuildEvents:RecordBossKill(raidId, bossName, timestamp)
	if not self.raids[raidId] then return nil end
	
	local kill = {
		boss = bossName,
		timestamp = timestamp or InfinityUtils:GetTimeStamp(),
		participantCount = self:GetRaidParticipantCount(raidId),
	}
	
	table.insert(self.raids[raidId].bosses, kill)
	self:SaveEvents()
	InfinityMessaging:Publish("boss_killed", { 
		raidId = raidId, 
		boss = bossName 
	})
	
	return kill
end

function InfinityGuildEvents:RecordLootDrop(raidId, itemName, bossName, memberWinner, dkpSpent)
	if not self.raids[raidId] then return nil end
	
	local loot = {
		item = itemName,
		boss = bossName,
		winner = memberWinner,
		dkpSpent = dkpSpent or 0,
		timestamp = InfinityUtils:GetTimeStamp(),
	}
	
	table.insert(self.raids[raidId].lootDistributed, loot)
	self:SaveEvents()
	InfinityMessaging:Publish("loot_distributed", { 
		raidId = raidId, 
		item = itemName,
		winner = memberWinner 
	})
	
	return loot
end

function InfinityGuildEvents:GetRaid(raidId)
	return self.raids[raidId]
end

function InfinityGuildEvents:GetActiveRaids()
	local active = {}
	
	for raidId, raid in pairs(self.raids) do
		if raid.status == "active" then
			table.insert(active, raid)
		end
	end
	
	return active
end

function InfinityGuildEvents:GetRaidParticipantCount(raidId)
	if not self.raids[raidId] then return 0 end
	
	local count = 0
	for _, _ in pairs(self.raids[raidId].participants) do
		count = count + 1
	end
	
	return count
end

function InfinityGuildEvents:GetRaidStats(raidId)
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

function InfinityGuildEvents:CreateEvent(eventName, eventType, eventDate, description)
	local eventId = "event_" .. InfinityUtils:GetTimeStamp()
	local base, suffix = eventId, 1
	while self.events[eventId] do
		eventId = base .. "_" .. suffix
		suffix = suffix + 1
	end
	
	local event = {
		id = eventId,
		name = eventName,
		type = eventType or "social",
		scheduledDate = eventDate or InfinityUtils:GetTimeStamp(),
		description = description or "",
		created = InfinityUtils:GetTimeStamp(),
		attendees = {},
		status = "scheduled",
	}
	
	self.events[eventId] = event
	self:SaveEvents()
	InfinityMessaging:Publish("guild_event_created", { eventId = eventId, name = eventName })
	
	return event
end

function InfinityGuildEvents:GetUpcomingEvents(daysAhead)
	daysAhead = daysAhead or 7
	local upcoming = {}
	local now = InfinityUtils:GetTimeStamp()
	local maxTime = now + (daysAhead * 86400)
	
	for eventId, event in pairs(self.events) do
		if event.scheduledDate >= now and event.scheduledDate <= maxTime and event.status == "scheduled" then
			table.insert(upcoming, event)
		end
	end
	
	table.sort(upcoming, function(a, b) return a.scheduledDate < b.scheduledDate end)
	
	return upcoming
end

function InfinityGuildEvents:SaveEvents()
	InfinityStorageManager:SetFeatureSetting("InfinityGuild", "events", {
		events = self.events,
		raids = self.raids,
	})
	InfinityDataManager:UpdateSourceData("InfinityGuild", "events", {
		events = self.events,
		raids = self.raids,
	})
end

return InfinityGuildEvents
