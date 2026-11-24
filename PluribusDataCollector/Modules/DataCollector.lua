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

_G.PluribusDataCollector = DataCollector

function DataCollector:Initialize()
	PluribusUtils:Info("Data Collector initialized", "DataCollector")
	
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
	if not self.config.enableQuestCollection or not questID then return end
	
	local questName = PluribusUtils:GetQuestTitleByID(questID)
	if not questName then return end
	
	if PluribusData and PluribusData.GetQuest and PluribusData:GetQuest(questID) then return end
	
	local questData = {
		id = questID,
		name = questName,
		level = 0,
		type = "normal",
		startTime = time(),
		objectives = {},
	}
	
	for _, obj in ipairs(PluribusUtils:GetQuestObjectives(questID)) do
		table.insert(questData.objectives, {
			text = obj.text or "",
			type = obj.type or "object",
			completed = obj.finished or false,
		})
	end
	
	if PluribusData and PluribusData.StoreQuest then
		PluribusData:StoreQuest(questID, questData)
	end
	self.collectionStats.questsCollected = self.collectionStats.questsCollected + 1
	
	if PluribusMessaging then
		PluribusMessaging:Publish("quest_data_collected", questID, questName)
	end
end

function DataCollector:CollectLootData()
	if not self.config.enableDropCollection then return end
	
	local guid = UnitGUID and UnitGUID("target")
	if not guid or PluribusUtils:IsSecret(guid) then return end
	
	local numItems = GetNumLootItems and GetNumLootItems() or 0
	for slot = 1, numItems do
		local _, name, quantity, quality = GetLootSlotInfo(slot)
		local link = GetLootSlotLink and GetLootSlotLink(slot)
		local itemID = link and PluribusUtils:GetItemIDFromHyperlink(link) or nil
		
		if itemID then
			local lootData = {
				itemID = itemID,
				name = name,
				quantity = quantity,
				quality = quality,
				source = guid,
				timestamp = time(),
			}
			
			if PluribusData and PluribusData.StoreDrop then
				PluribusData:StoreDrop(itemID, lootData)
			end
			self.collectionStats.dropsCollected = self.collectionStats.dropsCollected + 1
		end
	end
end

function DataCollector:CollectMobData(unit)
	if not self.config.enableMobCollection then return end
	
	local name = UnitName and UnitName(unit)
	local guid = UnitGUID and UnitGUID(unit)
	local classification = UnitClassification and UnitClassification(unit)
	local level = UnitLevel and UnitLevel(unit)
	
	if not name or not guid or PluribusUtils:IsSecret(name) or PluribusUtils:IsSecret(guid) then return end
	if PluribusUtils:IsSecret(level) then level = 0 end
	
	local mobID = tonumber(guid:match("Creature%-.-%-.-%-.-%-.-%-(.-)%-")) or tonumber(guid:match("Creature%-(%d+)%-"))
	if not mobID then return end
	
	if PluribusData and PluribusData.GetMob and PluribusData:GetMob(mobID) then return end
	
	local mobData = {
		id = mobID,
		name = name,
		level = level,
		classification = classification,
		zone = GetZoneText and GetZoneText() or "Unknown",
		subzone = GetSubZoneText and GetSubZoneText() or "",
		firstSeen = time(),
		kills = 0,
		lastSeen = time(),
	}
	
	if PluribusData and PluribusData.StoreMob then
		PluribusData:StoreMob(mobID, mobData)
	end
	self.collectionStats.mobsCollected = self.collectionStats.mobsCollected + 1
end

function DataCollector:CollectNodeData(unit)
	if not self.config.enableNodeCollection then return end
	
	local name = UnitName and UnitName(unit)
	local guid = UnitGUID and UnitGUID(unit)
	
	if not name or not guid or PluribusUtils:IsSecret(name) or PluribusUtils:IsSecret(guid) then return end
	
	local nodeID = tonumber(guid:match("GameObject%-.-%-.-%-.-%-.-%-(.-)%-"))
	if not nodeID then return end
	
	if PluribusData and PluribusData.GetNode and PluribusData:GetNode(nodeID) then return end
	
	local nodeData = {
		id = nodeID,
		name = name,
		zone = GetZoneText and GetZoneText() or "Unknown",
		subzone = GetSubZoneText and GetSubZoneText() or "",
		type = self:DetermineNodeType(name),
		firstSeen = time(),
		gatherings = 0,
		lastSeen = time(),
	}
	
	if PluribusData and PluribusData.StoreNode then
		PluribusData:StoreNode(nodeID, nodeData)
	end
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
	local questName = PluribusUtils:GetQuestTitleByID(questID) or ("Quest #" .. tostring(questID or "?"))
	
	if PluribusData and PluribusData.CompleteQuest then
		PluribusData:CompleteQuest(questID)
	end
	
	if PluribusMessaging then
		PluribusMessaging:Publish("quest_completed", questID, questName)
	end
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
	PluribusUtils:Debug("Scanning zone: " .. zone, "DataCollector")
end

function DataCollector:StartCollection()
	self.collectingData = true
	self.collectionStats.startTime = time()
	PluribusUtils:Info("Data collection started", "DataCollector")
end

function DataCollector:StopCollection()
	self.collectingData = false
	local duration = time() - self.collectionStats.startTime
	PluribusUtils:Info("Data collection stopped after " .. duration .. "s", "DataCollector")
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
		PluribusUtils:Info("Data Collector config updated: " .. key .. " = " .. tostring(value), "DataCollector")
	end
end

function DataCollector:GetStats()
	return self.collectionStats
end

return DataCollector
