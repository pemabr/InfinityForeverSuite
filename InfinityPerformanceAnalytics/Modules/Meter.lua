-- Infinity Analytics - DPS/HPS Meter Module
-- Tracks damage and healing output in real-time

InfinityPerformanceAnalyticsMeter = {
	combatLog = {},
	currentSession = nil,
	players = {},
	bosses = {},
	version = 1,
	maxSessionDuration = 3600, -- 1 hour in seconds
}

function InfinityPerformanceAnalyticsMeter:Initialize()
	InfinityDataManager:RegisterSource("analytics", function(data) end)
	InfinityUtils:Info("Analytics Meter initialized", "Analytics")
end

function InfinityPerformanceAnalyticsMeter:StartSession(sessionName)
	if not sessionName or sessionName == "" then
		InfinityUtils:Warning("Session name required", "Analytics")
		return false
	end
	
	self.currentSession = {
		name = sessionName,
		startTime = InfinityUtils:GetTimeStamp(),
		duration = 0,
		players = {},
		bosses = {},
		totalDamage = 0,
		totalHealing = 0,
	}
	
	self.players = {}
	InfinityUtils:Info("Combat session started: " .. sessionName, "Analytics")
	InfinityMessaging:Publish("analytics_session_start", { session = sessionName })
	return true
end

function InfinityPerformanceAnalyticsMeter:EndSession()
	if not self.currentSession then
		return false
	end
	
	self.currentSession.duration = InfinityUtils:GetTimeStamp() - self.currentSession.startTime
	
	-- Save session to history
	table.insert(self.combatLog, self.currentSession)
	
	-- Limit history size
	if #self.combatLog > 100 then
		table.remove(self.combatLog, 1)
	end
	
	InfinityUtils:Info("Combat session ended: " .. self.currentSession.name, "Analytics")
	InfinityMessaging:Publish("analytics_session_end", { session = self.currentSession })
	
	local sessionCopy = self.currentSession
	self.currentSession = nil
	return sessionCopy
end

function InfinityPerformanceAnalyticsMeter:RecordDamage(sourceName, targetName, spellName, amount, spellSchool)
	if not self.currentSession then
		return false
	end
	
	-- Get or create player entry
	if not self.players[sourceName] then
		self.players[sourceName] = {
			name = sourceName,
			totalDamage = 0,
			damageEvents = {},
			spells = {},
			dps = 0,
		}
	end
	
	local player = self.players[sourceName]
	player.totalDamage = player.totalDamage + amount
	self.currentSession.totalDamage = self.currentSession.totalDamage + amount
	
	-- Record spell usage
	if not player.spells[spellName] then
		player.spells[spellName] = {
			name = spellName,
			hits = 0,
			totalDamage = 0,
		}
	end
	player.spells[spellName].hits = player.spells[spellName].hits + 1
	player.spells[spellName].totalDamage = player.spells[spellName].totalDamage + amount
	
	-- Record event
	table.insert(player.damageEvents, {
		time = InfinityUtils:GetTimeStamp(),
		target = targetName,
		spell = spellName,
		amount = amount,
		school = spellSchool,
	})
	
	-- Limit event history
	if #player.damageEvents > 1000 then
		table.remove(player.damageEvents, 1)
	end
	
	return true
end

function InfinityPerformanceAnalyticsMeter:RecordHealing(sourceName, targetName, spellName, amount)
	if not self.currentSession then
		return false
	end
	
	-- Get or create player entry
	if not self.players[sourceName] then
		self.players[sourceName] = {
			name = sourceName,
			totalHealing = 0,
			healingEvents = {},
			spells = {},
			hps = 0,
		}
	end
	
	local player = self.players[sourceName]
	player.totalHealing = (player.totalHealing or 0) + amount
	self.currentSession.totalHealing = self.currentSession.totalHealing + amount
	
	-- Record spell usage
	if not player.spells[spellName] then
		player.spells[spellName] = {
			name = spellName,
			hits = 0,
			totalHealing = 0,
		}
	end
	player.spells[spellName].hits = player.spells[spellName].hits + 1
	player.spells[spellName].totalHealing = (player.spells[spellName].totalHealing or 0) + amount
	
	-- Record event
	table.insert(player.healingEvents or {}, {
		time = InfinityUtils:GetTimeStamp(),
		target = targetName,
		spell = spellName,
		amount = amount,
	})
	
	return true
end

function InfinityPerformanceAnalyticsMeter:GetPlayerStats(playerName)
	if not self.players[playerName] then
		return nil
	end
	
	local player = self.players[playerName]
	local sessionDuration = (InfinityUtils:GetTimeStamp() - self.currentSession.startTime) or 1
	
	player.dps = math.floor((player.totalDamage or 0) / math.max(sessionDuration, 1))
	player.hps = math.floor(((player.totalHealing or 0) / math.max(sessionDuration, 1)))
	
	return player
end

function InfinityPerformanceAnalyticsMeter:GetTopDamageDealer(limit)
	limit = limit or 5
	local sorted = {}
	
	for _, player in pairs(self.players) do
		table.insert(sorted, player)
	end
	
	table.sort(sorted, function(a, b)
		return (a.totalDamage or 0) > (b.totalDamage or 0)
	end)
	
	local result = {}
	for i = 1, math.min(limit, #sorted) do
		table.insert(result, sorted[i])
	end
	
	return result
end

function InfinityPerformanceAnalyticsMeter:GetTopHealer(limit)
	limit = limit or 5
	local sorted = {}
	
	for _, player in pairs(self.players) do
		table.insert(sorted, player)
	end
	
	table.sort(sorted, function(a, b)
		return (a.totalHealing or 0) > (b.totalHealing or 0)
	end)
	
	local result = {}
	for i = 1, math.min(limit, #sorted) do
		table.insert(result, sorted[i])
	end
	
	return result
end

function InfinityPerformanceAnalyticsMeter:GetSessionHistory(limit)
	limit = limit or 20
	local result = {}
	
	for i = #self.combatLog, math.max(1, #self.combatLog - limit + 1), -1 do
		table.insert(result, self.combatLog[i])
	end
	
	return result
end

function InfinityPerformanceAnalyticsMeter:ExportSessionData()
	if not self.currentSession then
		return nil
	end
	
	return InfinityUtils:DeepCopy(self.currentSession)
end

return InfinityPerformanceAnalyticsMeter

