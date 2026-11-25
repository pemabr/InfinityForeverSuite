-- PluribusLoot - Loot Tracking Module
-- Tracks loot values and calculates farming metrics

PluribusLootTracking = {
	sessions = {},
	currentSession = nil,
	db = {},
}

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
function PluribusLootTracking:Initialize()
	PluribusUtils:Info("LootTracking initializing...", "PluribusLoot")
	
	-- Load saved data
	self.db = PluribusStorageManager:GetFeatureSettings(PLURIBUS_FEATURES.LOOT) or {}
	
	-- Register with data manager
	PluribusDataManager:RegisterSource("loot_tracking", function(data)
		PluribusUtils:Debug("Loot tracking data updated", "PluribusLoot")
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
	
	PluribusUtils:Info("LootTracking initialized", "PluribusLoot")
end

-- Start a new tracking session
function PluribusLootTracking:StartNewSession()
	local sessionId = "session_" .. PluribusUtils:GetTimeStamp()
	local session = NewSession()
	
	session.id = sessionId
	session.running = true
	session.startTime = PluribusUtils:GetTimeStamp()
	
	self.db.sessions[sessionId] = session
	self.currentSession = sessionId
	
	PluribusUtils:Info("New loot tracking session started", "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_tracking", "session_started", sessionId)
	
	return sessionId
end

-- Pause current session
function PluribusLootTracking:PauseSession()
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	session.running = false
	session.pausedTime = PluribusUtils:GetTimeStamp()
	
	PluribusUtils:Info("Loot tracking session paused", "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_tracking", "session_paused")
	
	return true
end

-- Resume current session
function PluribusLootTracking:ResumeSession()
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	if session.pausedTime then
		-- Add pause duration to elapsed
		session.elapsed = session.elapsed + (PluribusUtils:GetTimeStamp() - session.pausedTime)
		session.pausedTime = nil
	end
	session.running = true
	
	PluribusUtils:Info("Loot tracking session resumed", "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_tracking", "session_resumed")
	
	return true
end

-- Record loot in session
function PluribusLootTracking:RecordLoot(itemLink, category, value)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	category = category or "OTHER"
	
	local lootEntry = {
		id = session.nextId,
		itemLink = itemLink,
		category = category,
		value = value or 0,
		timestamp = PluribusUtils:GetTimeStamp(),
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
		local formattedValue = PluribusUtils:FormatGold(value)
		local msg = PLURIBUS_COLORS.WARNING .. "HIGH VALUE DROP: " .. itemLink .. " (" .. formattedValue .. ")" .. PLURIBUS_COLORS.RESET
		PluribusUIFramework:ShowNotification(msg, 5)
	end
	
	session.nextId = session.nextId + 1
	
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_tracking", "loot_recorded", lootEntry)
	
	return true
end

-- Record mob kill
function PluribusLootTracking:RecordKill(mobName)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	session.kills = session.kills + 1
	
	return true
end

-- Record mob looted
function PluribusLootTracking:RecordLootedMob(mobName)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	session.lootedMobs = session.lootedMobs + 1
	
	return true
end

-- Record cost (vendor, repair, etc)
function PluribusLootTracking:RecordCost(amount, type)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	session.costs = session.costs + amount
	
	PluribusUtils:Debug("Cost recorded: " .. PluribusUtils:FormatGold(amount) .. " (" .. type .. ")", "PluribusLoot")
	
	return true
end

-- Record money looted
function PluribusLootTracking:RecordMoney(copperAmount)
	if not self.currentSession or not self.db.sessions[self.currentSession] then
		return false
	end
	
	local session = self.db.sessions[self.currentSession]
	session.coin = session.coin + copperAmount
	
	return true
end

-- Get session statistics
function PluribusLootTracking:GetSessionStats(sessionId)
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
		elapsed = elapsed + (PluribusUtils:GetTimeStamp() - session.startTime)
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
function PluribusLootTracking:GetLootHistory(sessionId, limit)
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
function PluribusLootTracking:EndSession(sessionId)
	sessionId = sessionId or self.currentSession
	
	if not sessionId or not self.db.sessions[sessionId] then
		return false
	end
	
	local session = self.db.sessions[sessionId]
	session.running = false
	session.endTime = PluribusUtils:GetTimeStamp()
	
	-- Calculate final elapsed time
	if session.startTime then
		session.elapsed = session.elapsed + (session.endTime - session.startTime)
	end
	
	PluribusUtils:Info("Loot tracking session ended", "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_tracking", "session_ended", sessionId)
	
	return true
end

return PluribusLootTracking

