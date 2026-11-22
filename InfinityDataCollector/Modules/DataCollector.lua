-- Data Collector - Main Module
-- Handles collection of game data: quests, mobs, drops, gather nodes
-- Coordinates with QuestieDB, game APIs, and other data sources

local DataCollector = {
	collectingData = false,
	collectionStats = {
		questsCollected = 0,
		mobsCollected = 0,
		dropsCollected = 0,
		nodesCollected = 0,
		startTime = 0,
	},
	
	config = {
		enableQuestCollection = true,
		enableMobCollection = true,
		enableDropCollection = true,
		enableNodeCollection = true,
		batchSize = 50,
		updateInterval = 1.0,
	},
}

_G.InfinityDataCollectorLegacy = DataCollector

function DataCollector:Initialize()
	InfinityUtils:Info("Data Collector initialized", "DataCollector")
	
	-- Create event frame
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("QUEST_ACCEPTED")
	frame:RegisterEvent("QUEST_COMPLETE")
	frame:RegisterEvent("LOOT_OPENED")
	frame:RegisterEvent("UNIT_SPELLCAST_START")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		DataCollector:HandleEvent(event, ...)
	end)
	
	-- Start periodic data collection
	self:StartCollection()
end

function DataCollector:HandleEvent(event, ...)
	if event == "QUEST_ACCEPTED" then
		local questID = ...
		if questID then
			self:CollectQuestData(questID)
		end
	elseif event == "QUEST_COMPLETE" then
		local questID = ...
		if questID then
			self:CompleteQuest(questID)
		end
	elseif event == "LOOT_OPENED" then
		self:CollectLootData()
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		self:OnZoneChange()
	end
end

function DataCollector:CollectQuestData(questID)
	if not self.config.enableQuestCollection then return end
	
	local questName = GetQuestLogTitle(questID)
	if not questName then return end
	
	-- Check if quest data already exists
	if InfinityData:GetQuest(questID) then return end
	
	-- Collect quest information
	local questData = {
		id = questID,
		name = questName,
		level = GetQuestLogQuestLevel(questID),
		type = GetQuestLogQuestType(questID),
		startTime = time(),
		objectives = {},
	}
	
	-- Get objectives
	for i = 1, GetNumQuestLeaderBoards(questID) do
		local text, type, done = GetQuestLogLeaderBoardInfo(questID, i)
		table.insert(questData.objectives, {
			text = text,
			type = type,
			completed = done,
		})
	end
	
	-- Store in data system
	InfinityData:StoreQuest(questID, questData)
	self.collectionStats.questsCollected = self.collectionStats.questsCollected + 1
	
	-- Publish event for other addons
	InfinityMessaging:Publish("quest_data_collected", questID, questName)
end

function DataCollector:CollectLootData()
	if not self.config.enableDropCollection then return end
	
	local guid = GetLootSourceType()
	if not guid then return end
	
	-- Scan all loot
	for slot = 1, GetNumLootItems() do
		local icon, name, quantity, quality, bound, canUse, itemID = GetLootSlotInfo(slot)
		
		if itemID then
			local lootData = {
				itemID = itemID,
				name = name,
				quantity = quantity,
				quality = quality,
				source = guid,
				timestamp = time(),
			}
			
			-- Store drop data
			InfinityData:StoreDrop(itemID, lootData)
			self.collectionStats.dropsCollected = self.collectionStats.dropsCollected + 1
		end
	end
end

function DataCollector:CollectMobData(unit)
	if not self.config.enableMobCollection then return end
	
	local name = UnitName(unit)
	local guid = UnitGUID(unit)
	local classification = UnitClassification(unit)
	local level = UnitLevel(unit)
	
	if not name or not guid then return end
	
	-- Check if mob already tracked
	local mobID = tonumber(guid:match("Creature%-.-%-.-%-.-%-.-%-(.-)%-"))
	if not mobID then return end
	
	if InfinityData:GetMob(mobID) then return end
	
	-- Collect mob information
	local mobData = {
		id = mobID,
		name = name,
		level = level,
		classification = classification,
		zone = GetZoneText(),
		subzone = GetSubZoneText(),
		firstSeen = time(),
		kills = 0,
		lastSeen = time(),
	}
	
	InfinityData:StoreMob(mobID, mobData)
	self.collectionStats.mobsCollected = self.collectionStats.mobsCollected + 1
end

function DataCollector:CollectNodeData(unit)
	if not self.config.enableNodeCollection then return end
	
	local name = UnitName(unit)
	local guid = UnitGUID(unit)
	
	if not name or not guid then return end
	
	-- Check if node already tracked
	local nodeID = tonumber(guid:match("GameObject%-.-%-.-%-.-%-.-%-(.-)%-"))
	if not nodeID then return end
	
	if InfinityData:GetNode(nodeID) then return end
	
	-- Collect node information
	local nodeData = {
		id = nodeID,
		name = name,
		zone = GetZoneText(),
		subzone = GetSubZoneText(),
		type = self:DetermineNodeType(name),
		firstSeen = time(),
		gatherings = 0,
		lastSeen = time(),
	}
	
	InfinityData:StoreNode(nodeID, nodeData)
	self.collectionStats.nodesCollected = self.collectionStats.nodesCollected + 1
end

function DataCollector:DetermineNodeType(nodeName)
	if nodeName:find("Ore") then return "ore"
	elseif nodeName:find("Herb") then return "herb"
	elseif nodeName:find("Treasure") then return "treasure"
	else return "other"
	end
end

function DataCollector:CompleteQuest(questID)
	local questName = GetQuestLogTitle(questID)
	if not questName then return end
	
	-- Mark quest as complete in data system
	InfinityData:CompleteQuest(questID)
	
	-- Publish completion event
	InfinityMessaging:Publish("quest_completed", questID, questName)
end

function DataCollector:OnZoneChange()
	-- Zone changed - collect any new mobs and nodes in zone
	if self.config.enableMobCollection or self.config.enableNodeCollection then
		self:ScanCurrentZone()
	end
end

function DataCollector:ScanCurrentZone()
	-- This would scan the current zone for entities
	-- Limited by WoW API visibility restrictions
	local zone = GetZoneText()
	InfinityUtils:Debug("Scanning zone: " .. zone, "DataCollector")
end

function DataCollector:StartCollection()
	self.collectingData = true
	self.collectionStats.startTime = time()
	InfinityUtils:Info("Data collection started", "DataCollector")
end

function DataCollector:StopCollection()
	self.collectingData = false
	local duration = time() - self.collectionStats.startTime
	InfinityUtils:Info("Data collection stopped after " .. duration .. "s", "DataCollector")
	self:PrintCollectionStats()
end

function DataCollector:PrintCollectionStats()
	print("|cffffd700=== Data Collection Statistics ===|r")
	print("Quests collected: " .. self.collectionStats.questsCollected)
	print("Mobs collected: " .. self.collectionStats.mobsCollected)
	print("Drops collected: " .. self.collectionStats.dropsCollected)
	print("Nodes collected: " .. self.collectionStats.nodesCollected)
	print("Duration: " .. (time() - self.collectionStats.startTime) .. " seconds")
end

function DataCollector:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Data Collector config updated: " .. key .. " = " .. tostring(value), "DataCollector")
	end
end

function DataCollector:GetStats()
	return self.collectionStats
end

return DataCollector
