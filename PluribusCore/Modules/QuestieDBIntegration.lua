-- QuestieDB Integration
-- Integrates with QuestieDB addon to access quest/NPC database

local QuestieDBIntegration = {
	questieAvailable = false,
	cachedData = {
		quests = {}, -- {id = questData}
		npcs = {}, -- {id = npcData}
		items = {}, -- {id = itemData}
		objects = {}, -- {id = objectData}
	},
	cacheTTL = 3600, -- 1 hour
	lastCacheTime = 0,
}

_G.PluribusQuestieDBIntegration = QuestieDBIntegration

-- Initialize QuestieDB integration
function QuestieDBIntegration:Initialize()
	PluribusUtils:Info("QuestieDB integration initialized", "Core")
	
	-- Check if Questie is loaded
	C_Timer.After(1, function()
		QuestieDBIntegration:CheckQuestieAvailability()
	end)
	
	-- Subscribe to data requests
	PluribusMessaging:Subscribe("request_quest_data", function(questId)
		QuestieDBIntegration:OnQuestDataRequested(questId)
	end)
	
	PluribusMessaging:Subscribe("request_npc_data", function(npcId)
		QuestieDBIntegration:OnNPCDataRequested(npcId)
	end)
end

-- Check if optional Questie addon is available
function QuestieDBIntegration:CheckQuestieAvailability()
	if _G.QuestieDB then
		self.questieAvailable = true
		PluribusUtils:Info("Optional QuestieDB found and linked", "Core")
	else
		self.questieAvailable = false
		PluribusUtils:Debug("Running in standalone quest mode (QuestieDB optional)", "Core")
	end
end

-- Get quest data (optional QuestieDB, then native WoW quest log & local collector)
function QuestieDBIntegration:GetQuestData(questId)
	-- Check cache first
	if self.cachedData.quests[questId] then
		return self.cachedData.quests[questId]
	end
	
	-- Try optional QuestieDB
	if self.questieAvailable and _G.QuestieDB and _G.QuestieDB.Quest and _G.QuestieDB.Quest[questId] then
		local questData = _G.QuestieDB.Quest[questId]
		
		local data = {
			id = questId,
			name = questData[1] or "Unknown",
			level = questData[7] or 0,
			minLevel = questData[8] or 0,
			objectives = questData[2] or {},
			rewards = questData[3] or {},
			startNPC = questData[4] or 0,
			endNPC = questData[5] or 0,
			description = questData[9] or "",
		}
		
		self.cachedData.quests[questId] = data
		return data
	end
	
	-- Standalone fallback to live WoW C_QuestLog API
	local questName = PluribusUtils:GetQuestTitleByID(questId)
	if questName then
		local data = {
			id = questId,
			name = questName,
			level = 0,
			minLevel = 0,
			objectives = PluribusUtils:GetQuestObjectives(questId),
			rewards = {},
			startNPC = 0,
			endNPC = 0,
			description = "",
		}
		
		self.cachedData.quests[questId] = data
		return data
	end
	
	return nil
end

-- Get NPC data from QuestieDB
function QuestieDBIntegration:GetNPCData(npcId)
	-- Check cache first
	if self.cachedData.npcs[npcId] then
		return self.cachedData.npcs[npcId]
	end
	
	-- Try QuestieDB
	if self.questieAvailable and QuestieDB.NPC[npcId] then
		local npcData = QuestieDB.NPC[npcId]
		
		local data = {
			id = npcId,
			name = npcData[1] or "Unknown",
			level = npcData[2] or 0,
			type = npcData[3] or "humanoid",
			location = npcData[4] or {zone = 0, x = 0, y = 0},
			questStarts = npcData[5] or {},
			questEnds = npcData[6] or {},
			drops = npcData[7] or {},
		}
		
		-- Cache result
		self.cachedData.npcs[npcId] = data
		return data
	end
	
	return nil
end

-- Get item data from QuestieDB
function QuestieDBIntegration:GetItemData(itemId)
	-- Check cache first
	if self.cachedData.items[itemId] then
		return self.cachedData.items[itemId]
	end
	
	-- Try QuestieDB
	if self.questieAvailable and QuestieDB.Item[itemId] then
		local itemData = QuestieDB.Item[itemId]
		
		local data = {
			id = itemId,
			name = itemData[1] or "Unknown",
			rarity = itemData[2] or 0,
			level = itemData[3] or 0,
			type = itemData[4] or "misc",
			droppedBy = itemData[5] or {},
			questReward = itemData[6] or false,
			vendorPrice = itemData[7] or 0,
		}
		
		-- Cache result
		self.cachedData.items[itemId] = data
		return data
	end
	
	-- Fallback to game API
	local itemName, itemLink, rarity, itemLevel = PluribusUtils:GetItemInfo(itemId)
	if itemName then
		local data = {
			id = itemId,
			name = itemName,
			rarity = rarity or 0,
			level = itemLevel or 0,
			type = "unknown",
			droppedBy = {},
			questReward = false,
			vendorPrice = 0,
		}
		
		self.cachedData.items[itemId] = data
		return data
	end
	
	return nil
end

-- Called when quest data is requested
function QuestieDBIntegration:OnQuestDataRequested(questId)
	local data = self:GetQuestData(questId)
	if data then
		PluribusMessaging:Publish("quest_data_response", questId, data)
	end
end

-- Called when NPC data is requested
function QuestieDBIntegration:OnNPCDataRequested(npcId)
	local data = self:GetNPCData(npcId)
	if data then
		PluribusMessaging:Publish("npc_data_response", npcId, data)
	end
end

-- Get all quest starts for zone
function QuestieDBIntegration:GetQuestStartsInZone(zoneId)
	if not self.questieAvailable then
		return {}
	end
	
	local quests = {}
	for questId, questData in pairs(QuestieDB.Quest or {}) do
		-- Check if quest is in this zone
		if questData[10] == zoneId then -- Quest zone ID
			table.insert(quests, questId)
		end
	end
	
	return quests
end

-- Get all NPCs in zone
function QuestieDBIntegration:GetNPCsInZone(zoneId)
	if not self.questieAvailable then
		return {}
	end
	
	local npcs = {}
	for npcId, npcData in pairs(QuestieDB.NPC or {}) do
		-- Check if NPC is in this zone
		if npcData[4] and npcData[4].zone == zoneId then
			table.insert(npcs, npcId)
		end
	end
	
	return npcs
end

-- Clear cache (optional)
function QuestieDBIntegration:ClearCache()
	self.cachedData = {
		quests = {},
		npcs = {},
		items = {},
		objects = {},
	}
	self.lastCacheTime = 0
	PluribusUtils:Info("QuestieDB cache cleared", "Core")
end

-- Get cache statistics
function QuestieDBIntegration:GetCacheStats()
	return {
		questsCache = PluribusUtils:TableSize(self.cachedData.quests),
		npcsCache = PluribusUtils:TableSize(self.cachedData.npcs),
		itemsCache = PluribusUtils:TableSize(self.cachedData.items),
		objectsCache = PluribusUtils:TableSize(self.cachedData.objects),
		available = self.questieAvailable,
	}
end

-- Display integration status
function QuestieDBIntegration:DisplayStatus()
	local stats = self:GetCacheStats()
	
	print("|cffffd700=== QUESTIEDB INTEGRATION ===|r")
	print("QuestieDB Available: " .. (stats.available and "YES" or "NO"))
	print("Cached Quests: " .. stats.questsCache)
	print("Cached NPCs: " .. stats.npcsCache)
	print("Cached Items: " .. stats.itemsCache)
	print("Cached Objects: " .. stats.objectsCache)
end

return QuestieDBIntegration
