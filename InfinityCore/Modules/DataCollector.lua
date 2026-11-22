-- Data Collector Module
-- Gathers game data (quests, mobs, drops, gather nodes) and queues for sharing

local DataCollector = {
	collectingEnabled = true,
	batchSize = 50,
	maxQueueSize = 500,
	
	queues = {
		questData = {},
		mobData = {},
		dropData = {},
		gatherNodeData = {},
	},
	
	database = {
		seenQuests = {}, -- {questId = timestamp}
		seenMobs = {}, -- {mobId = {name, level, timestamp}}
		seenDrops = {}, -- {itemId = {mobId, dropRate, timestamp}}
		seenNodes = {}, -- {nodeId = {type, coords, timestamp}}
	},
	
	config = {
		collectQuestData = true,
		collectMobData = true,
		collectDropData = true,
		collectGatherNodes = true,
		shareDuringCombat = false,
		minShareInterval = 5, -- seconds
		lastShareTime = 0,
	},
}

_G.InfinityCoreDataCollector = DataCollector
if not _G.InfinityDataCollector then _G.InfinityDataCollector = DataCollector end

-- Initialize data collector
function DataCollector:Initialize()
	InfinityUtils:Info("Data collector initialized", "Core")
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("QUEST_ACCEPTED")
	frame:RegisterEvent("QUEST_TURNED_IN")
	if InfinityUtils:CanUseCombatLogEvent() then
		pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")
	end
	frame:RegisterEvent("LOOT_OPENED")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if not DataCollector.collectingEnabled then
			return
		end
		
		if event == "QUEST_ACCEPTED" then
			DataCollector:OnQuestAccepted(...)
		elseif event == "QUEST_TURNED_IN" then
			DataCollector:OnQuestTurnIn(...)
		elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
			DataCollector:OnCombatLogEvent(...)
		elseif event == "LOOT_OPENED" then
			DataCollector:OnLootOpened()
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			DataCollector:OnZoneChanged()
		end
	end)
	
	-- Enable periodic sharing
	C_Timer.NewTicker(10, function()
		if DataCollector:ShouldShare() then
			DataCollector:ShareBatch()
		end
	end)
end

-- Check if we should share data
function DataCollector:ShouldShare()
	-- Don't share during combat
	if self.config.shareDuringCombat == false and UnitAffectingCombat("player") then
		return false
	end
	
	-- Check share interval
	local timeSinceShare = GetTime() - self.config.lastShareTime
	if timeSinceShare < self.config.minShareInterval then
		return false
	end
	
	-- Check if we have data to share
	local totalQueued = #self.queues.questData + #self.queues.mobData + 
	                   #self.queues.dropData + #self.queues.gatherNodeData
	
	return totalQueued > 0
end

-- Share a batch of data
function DataCollector:ShareBatch()
	local batch = {
		quests = {},
		mobs = {},
		drops = {},
		nodes = {},
		source = UnitName("player"),
		realm = GetRealmName(),
		guildName = GetGuildInfo("player"),
		timestamp = GetServerTime(),
	}
	
	-- Gather quest data
	for i = 1, math.min(self.batchSize, #self.queues.questData) do
		table.insert(batch.quests, self.queues.questData[i])
	end
	for i = 1, #batch.quests do
		table.remove(self.queues.questData, 1)
	end
	
	-- Gather mob data
	for i = 1, math.min(self.batchSize, #self.queues.mobData) do
		table.insert(batch.mobs, self.queues.mobData[i])
	end
	for i = 1, #batch.mobs do
		table.remove(self.queues.mobData, 1)
	end
	
	-- Gather drop data
	for i = 1, math.min(self.batchSize, #self.queues.dropData) do
		table.insert(batch.drops, self.queues.dropData[i])
	end
	for i = 1, #batch.drops do
		table.remove(self.queues.dropData, 1)
	end
	
	-- Gather node data
	for i = 1, math.min(self.batchSize, #self.queues.gatherNodeData) do
		table.insert(batch.nodes, self.queues.gatherNodeData[i])
	end
	for i = 1, #batch.nodes do
		table.remove(self.queues.gatherNodeData, 1)
	end
	
	-- Only send if we have data
	if #batch.quests > 0 or #batch.mobs > 0 or #batch.drops > 0 or #batch.nodes > 0 then
		InfinityMessaging:Publish("share_data", batch)
		self.config.lastShareTime = GetTime()
	end
end

-- Quest accepted
function DataCollector:OnQuestAccepted(questId)
	if not self.config.collectQuestData then
		return
	end
	if (_G.issecretvalue and _G.issecretvalue(questId))
		or type(questId) ~= "number" or questId ~= questId or questId <= 0
		or questId >= math.huge or questId ~= math.floor(questId) then return end
	local api = _G.C_QuestLog
	if not api then return end
	local questName, questLevel
	if api.GetTitleForQuestID then questName = api.GetTitleForQuestID(questId) end
	if _G.issecretvalue and _G.issecretvalue(questName) then questName = nil end
	if api.GetLogIndexForQuestID and api.GetInfo then
		local index = api.GetLogIndexForQuestID(questId)
		if not (_G.issecretvalue and _G.issecretvalue(index)) and type(index) == "number" and index > 0 then
			local info = api.GetInfo(index)
			if not (_G.issecretvalue and _G.issecretvalue(info)) and type(info) == "table" then
				questName = questName or info.title
				questLevel = info.level
			end
		end
	end
	if (_G.issecretvalue and _G.issecretvalue(questName)) or type(questName) ~= "string" then return end
	if _G.issecretvalue and _G.issecretvalue(questLevel) then questLevel = nil end
	local zone = _G.GetZoneText and GetZoneText()
	if (_G.issecretvalue and _G.issecretvalue(zone)) or type(zone) ~= "string" then zone = nil end

	local questData = {
		id = questId,
		name = questName,
		level = questLevel,
		zone = zone,
		timestamp = GetServerTime(),
	}
	
	table.insert(self.queues.questData, questData)
	self:CheckQueueSize()
	
	self.database.seenQuests[questId] = GetServerTime()
end

-- Quest completed
function DataCollector:OnQuestComplete(questId)
	-- Could track quest completion time
	InfinityMessaging:Publish("quest_completed", questId)
end

-- Quest turned in
function DataCollector:OnQuestTurnIn(questId)
	if (_G.issecretvalue and _G.issecretvalue(questId)) or type(questId) ~= "number"
		or questId ~= questId or questId <= 0 or questId >= math.huge or questId ~= math.floor(questId) then return end
	self:OnQuestComplete(questId)
end

-- Combat log event - track mobs and drops
function DataCollector:OnCombatLogEvent(timestamp, subevent, hideCaster, casterGUID, casterName, casterFlags, casterRaidFlags, targetGUID, targetName, targetFlags, targetRaidFlags, spellId, spellName, ...)
	-- Only track NPC deaths
	if subevent ~= "UNIT_DIED" then
		return
	end
	
	-- Check if target is a mob/NPC
	if not bit.band(targetFlags, COMBATLOG_OBJECT_TYPE_NPC) then
		return
	end
	
	if not self.config.collectMobData then
		return
	end
	
	-- Extract mob info from GUID
	local mobId = tonumber(string.match(targetGUID, "Creature%-0%-0%-0%-%d+%-(%d+)"))
	if not mobId then
		return
	end
	
	-- Store mob data
	if not self.database.seenMobs[mobId] then
		self.database.seenMobs[mobId] = {
			name = targetName,
			level = UnitLevel(targetName) or 0,
			type = "humanoid",
			zone = GetZoneText(),
			timestamp = GetServerTime(),
		}
		
		local mobData = {
			id = mobId,
			name = targetName,
			level = self.database.seenMobs[mobId].level,
			zone = self.database.seenMobs[mobId].zone,
			timestamp = GetServerTime(),
		}
		
		table.insert(self.queues.mobData, mobData)
		self:CheckQueueSize()
	end
end

-- Loot opened - track drops
function DataCollector:OnLootOpened()
	if not self.config.collectDropData then
		return
	end
	if not _G.GetNumLootItems or not _G.GetLootSlotLink then return end
	local numLoot = GetNumLootItems()
	if (_G.issecretvalue and _G.issecretvalue(numLoot)) or type(numLoot) ~= "number"
		or numLoot ~= numLoot or numLoot < 0 or numLoot > 1000 or numLoot ~= math.floor(numLoot) then return end
	local zone = _G.GetZoneText and GetZoneText()
	if (_G.issecretvalue and _G.issecretvalue(zone)) or type(zone) ~= "string" then zone = nil end
	for i = 1, numLoot do
		local itemLink = GetLootSlotLink(i)
		if not (_G.issecretvalue and _G.issecretvalue(itemLink)) and type(itemLink) == "string" then
			local itemId = tonumber(string.match(itemLink, "item:(%d+):"))
			if itemId then
				if not self.database.seenDrops[itemId] then
					local itemName, _, itemRarity = InfinityUtils:GetItemInfo(itemId)
					if _G.issecretvalue and _G.issecretvalue(itemName) then itemName = nil end
					if _G.issecretvalue and _G.issecretvalue(itemRarity) then itemRarity = nil end
					self.database.seenDrops[itemId] = {
						name = itemName,
						rarity = itemRarity,
						timestamp = GetServerTime(),
					}
					
					local dropData = {
						itemId = itemId,
						itemName = self.database.seenDrops[itemId].name,
						rarity = self.database.seenDrops[itemId].rarity,
						zone = zone,
						timestamp = GetServerTime(),
					}
					
					table.insert(self.queues.dropData, dropData)
					self:CheckQueueSize()
				end
			end
		end
	end
end

-- Zone changed - check for gather nodes nearby
function DataCollector:OnZoneChanged()
	if not self.config.collectGatherNodes then
		return
	end
	
	-- This would require scanning for visible objects
	-- For now, we track mining/herbalism events through item acquisition
end

-- Check queue size and prevent overflow
function DataCollector:CheckQueueSize()
	local totalQueued = #self.queues.questData + #self.queues.mobData + 
	                   #self.queues.dropData + #self.queues.gatherNodeData
	
	if totalQueued > self.maxQueueSize then
		-- Share immediately if queue is too large
		self:ShareBatch()
	end
end

-- Get database statistics
function DataCollector:GetStats()
	return {
		questsTracked = InfinityUtils:TableSize(self.database.seenQuests),
		mobsTracked = InfinityUtils:TableSize(self.database.seenMobs),
		dropsTracked = InfinityUtils:TableSize(self.database.seenDrops),
		nodesTracked = InfinityUtils:TableSize(self.database.seenNodes),
		questsQueued = #self.queues.questData,
		mobsQueued = #self.queues.mobData,
		dropsQueued = #self.queues.dropData,
		nodesQueued = #self.queues.gatherNodeData,
	}
end

-- Display collection statistics
function DataCollector:DisplayStats()
	local stats = self:GetStats()
	
	print("|cffffd700=== DATA COLLECTION STATS ===|r")
	print("Quests Tracked: " .. stats.questsTracked .. " (" .. stats.questsQueued .. " queued)")
	print("Mobs Tracked: " .. stats.mobsTracked .. " (" .. stats.mobsQueued .. " queued)")
	print("Drops Tracked: " .. stats.dropsTracked .. " (" .. stats.dropsQueued .. " queued)")
	print("Nodes Tracked: " .. stats.nodesTracked .. " (" .. stats.nodesQueued .. " queued)")
	print("Collecting: " .. (self.collectingEnabled and "YES" or "NO"))
end

-- Toggle collection
function DataCollector:SetEnabled(enabled)
	self.collectingEnabled = enabled
	InfinityUtils:Info("Data collection " .. (enabled and "enabled" or "disabled"), "Core")
end

return DataCollector
