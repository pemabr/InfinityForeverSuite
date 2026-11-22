-- InfinityLoot - Loot Tracking Module
-- Extracted from SharpiesLootTracker
-- Tracks loot values and calculates farming metrics

InfinityLootTracking = {
	sessions = {},
	currentSession = nil,
	db = {},
}

local function ValidAmount(amount)
	if _G.issecretvalue and _G.issecretvalue(amount) then return false end
	return type(amount) == "number" and amount == amount and amount >= 0
		and amount < math.huge and amount == math.floor(amount)
end

-- Session structure
local function NewSession()
	return {
		running = false,
		elapsed = 0,
		startTime = nil,
		pausedTime = nil,
		coin = 0,
		costs = 0,
		kills = 0,
		lootedMobs = 0,
		entries = {},
		nextId = 1,
		categories = {
			MATS = { value = 0, count = 0, items = {} },
			GEAR = { value = 0, count = 0, items = {} },
			JUNK = { value = 0, count = 0, items = {} },
			OTHER = { value = 0, count = 0, items = {} },
		}
	}
end

-- Initialize tracking module
function InfinityLootTracking:Initialize()
	InfinityUtils:Info("LootTracking initializing...", "InfinityLoot")
	
	-- Load saved data
	self.db = InfinityStorageManager:GetFeatureSettings(INFINITY_FEATURES.LOOT) or {}
	
	-- Register with data manager
	InfinityDataManager:RegisterSource("loot_tracking", function(data)
		InfinityUtils:Debug("Loot tracking data updated", "InfinityLoot")
	end)
	
	-- Initialize default structure
	if not self.db.sessions then
		self.db.sessions = {}
	end
	
	if not self.db.settings then
		self.db.settings = {
			priceSource = "auto",
			countQuestMoney = true,
			countCosts = true,
			alertValue = 50000,
		}
	end
	
	-- Start a default session if none exists
	if not self.currentSession then
		self:StartNewSession()
	end
	
	InfinityUtils:Info("LootTracking initialized", "InfinityLoot")
end

-- Start a new tracking session
function InfinityLootTracking:StartNewSession()
	local current = self.currentSession and self.db.sessions[self.currentSession]
	if current and not current.endTime then self:EndSession(self.currentSession) end
	local sessionId = "session_" .. InfinityUtils:GetTimeStamp()
	local base, suffix = sessionId, 1
	while self.db.sessions[sessionId] do
		sessionId = base .. "_" .. suffix
		suffix = suffix + 1
	end
	local session = NewSession()
	
	session.id = sessionId
	session.running = true
	session.startTime = InfinityUtils:GetTimeStamp()
	
	self.db.sessions[sessionId] = session
	self.currentSession = sessionId
	
	InfinityUtils:Info("New loot tracking session started", "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_tracking", "session_started", sessionId)
	
	return sessionId
end

-- Pause current session
function InfinityLootTracking:PauseSession()
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	if not session.running then return false end
	local now = InfinityUtils:GetTimeStamp()
	session.elapsed = session.elapsed + (now - session.startTime)
	session.running = false
	session.pausedTime = now
	
	InfinityUtils:Info("Loot tracking session paused", "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_tracking", "session_paused")
	
	return true
end

-- Resume current session
function InfinityLootTracking:ResumeSession()
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	if session.running or session.endTime then return false end
	session.startTime = InfinityUtils:GetTimeStamp()
	session.pausedTime = nil
	session.running = true
	
	InfinityUtils:Info("Loot tracking session resumed", "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_tracking", "session_resumed")
	
	return true
end

-- Record loot in session
function InfinityLootTracking:RecordLoot(itemLink, category, value)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	if not session.running then return false end
	category = category or "OTHER"
	if (_G.issecretvalue and (issecretvalue(itemLink) or issecretvalue(category)))
		or type(itemLink) ~= "string" or itemLink == "" or type(category) ~= "string"
		or not session.categories[category] or not ValidAmount(value) then
		InfinityUtils:Warning("Invalid loot tracking entry.", "InfinityLoot")
		return false
	end
	
	local lootEntry = {
		id = session.nextId,
		itemLink = itemLink,
		category = category,
		value = value or 0,
		timestamp = InfinityUtils:GetTimeStamp(),
	}
	
	table.insert(session.entries, lootEntry)
	
	-- Update category stats
	if session.categories[category] then
		session.categories[category].value = session.categories[category].value + value
		session.categories[category].count = session.categories[category].count + 1
		table.insert(session.categories[category].items, lootEntry)
	end
	
	-- Check if should trigger alert
	if value >= (self.db.settings.alertValue or 50000) then
		local formattedValue = InfinityUtils:FormatGold(value)
		InfinityUtils:Warning("HIGH VALUE DROP: " .. itemLink .. " (" .. formattedValue .. ")", "InfinityLoot")
	end
	
	session.nextId = session.nextId + 1
	
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_tracking", "loot_recorded", lootEntry)
	
	return true
end

-- Record mob kill
function InfinityLootTracking:RecordKill(mobName)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	if not session.running then return false end
	session.kills = session.kills + 1
	
	return true
end

-- Record mob looted
function InfinityLootTracking:RecordLootedMob(mobName)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	if not session.running then return false end
	session.lootedMobs = session.lootedMobs + 1
	
	return true
end

-- Record cost (vendor, repair, etc)
function InfinityLootTracking:RecordCost(amount, type)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	if not session.running then return false end
	if not ValidAmount(amount) then InfinityUtils:Warning("Invalid tracking cost.", "InfinityLoot"); return false end
	session.costs = session.costs + amount
	
	InfinityUtils:Debug("Cost recorded: " .. InfinityUtils:FormatGold(amount) .. " (" .. type .. ")", "InfinityLoot")
	
	return true
end

-- Record money looted
function InfinityLootTracking:RecordMoney(copperAmount)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	if not session.running then return false end
	if not ValidAmount(copperAmount) then InfinityUtils:Warning("Invalid tracked money amount.", "InfinityLoot"); return false end
	session.coin = session.coin + copperAmount
	
	return true
end

-- Get session statistics
function InfinityLootTracking:GetSessionStats(sessionId)
	sessionId = sessionId or self.currentSession
	
	if not sessionId or not self.db.sessions[sessionId] then
		return nil
	end
	
	local session = self.db.sessions[sessionId]
	
	-- Calculate total value
	local totalValue = session.coin
	for _, category in pairs(session.categories) do
		totalValue = totalValue + category.value
	end
	
	-- Calculate elapsed time
	local elapsed = session.elapsed
	if session.running and session.startTime then
		elapsed = elapsed + (InfinityUtils:GetTimeStamp() - session.startTime)
	end
	
	-- Calculate rates
	local goldPerHour = 0
	local lootPerHour = 0
	
	if elapsed > 0 then
		goldPerHour = math.floor(totalValue / (elapsed / 3600))
		lootPerHour = math.floor((#session.entries) / (elapsed / 3600))
	end
	
	return {
		id = sessionId,
		running = session.running,
		ended = session.endTime ~= nil,
		totalValue = totalValue,
		coinLooted = session.coin,
		gearValue = session.categories.GEAR.value,
		matsValue = session.categories.MATS.value,
		junkValue = session.categories.JUNK.value,
		otherValue = session.categories.OTHER.value,
		totalItems = #session.entries,
		kills = session.kills,
		lootedMobs = session.lootedMobs,
		elapsedSeconds = elapsed,
		goldPerHour = goldPerHour,
		lootPerHour = lootPerHour,
		costs = session.costs,
		netValue = totalValue - session.costs,
	}
end

-- Get loot history
function InfinityLootTracking:GetLootHistory(sessionId, limit)
	sessionId = sessionId or self.currentSession
	
	if not sessionId or not self.db.sessions[sessionId] then
		return {}
	end
	
	limit = limit or 50
	local session = self.db.sessions[sessionId]
	local result = {}
	
	for i = #session.entries, math.max(1, #session.entries - limit + 1), -1 do
		table.insert(result, session.entries[i])
	end
	
	return result
end

-- End session
function InfinityLootTracking:EndSession(sessionId)
	sessionId = sessionId or self.currentSession
	
	if not sessionId or not self.db.sessions[sessionId] then
		return false
	end
	
	local session = self.db.sessions[sessionId]
	if session.endTime then return false end
	local now = InfinityUtils:GetTimeStamp()
	if session.running and session.startTime then
		session.elapsed = session.elapsed + (now - session.startTime)
	end
	session.running = false
	session.endTime = now
	
	InfinityUtils:Info("Loot tracking session ended", "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_tracking", "session_ended", sessionId)
	
	return true
end

return InfinityLootTracking

