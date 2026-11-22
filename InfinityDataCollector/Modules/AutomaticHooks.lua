-- InfinityDataCollector Autonomous Hook Module
-- Automatically hooks game events to gather data without user input

InfinityDataCollectorHooks = {
	hooked = {},
	eventFrame = nil,
	questCache = {},
	mobCache = {},
}

-- Initialize event hooking
function InfinityDataCollectorHooks:Initialize()
	if self.eventFrame then
		return
	end
	
	self.eventFrame = CreateFrame("Frame")
	self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
		self:OnGameEvent(event, ...)
	end)
	
	-- Register events for autonomous gathering
	self.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")           -- Quest data
	self.eventFrame:RegisterEvent("QUEST_DETAIL")               -- Quest details
	self.eventFrame:RegisterEvent("QUEST_PROGRESS")             -- Quest progress
	self.eventFrame:RegisterEvent("QUEST_COMPLETE")             -- Quest completion
	self.eventFrame:RegisterEvent("LOOT_OPENED")                -- Drop data
	self.eventFrame:RegisterEvent("LOOT_ITEM_ROLL_WON")        -- Drop data
	self.eventFrame:RegisterEvent("UNIT_DIED")                  -- Mob death tracking
	self.eventFrame:RegisterEvent("ENCOUNTER_START")            -- Boss data
	self.eventFrame:RegisterEvent("ENCOUNTER_END")              -- Boss data
	self.eventFrame:RegisterEvent("NPC_CHAT")                   -- NPC interactions
	self.eventFrame:RegisterEvent("BANKFRAME_OPENED")           -- Banker data
	self.eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY") -- Equipment tracking
	
	-- Register for gathering node data via minimap
	self.eventFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
	
	InfinityUtils:Info("Data gathering hooks initialized", "DataCollectorHooks")
	return true
end

-- Main event handler
function InfinityDataCollectorHooks:OnGameEvent(event, ...)
	if not InfinityDataCollectorCore or not InfinityDataCollectorCore:IsGatheringEnabled() then
		return
	end
	
	local args = { ... }
	pcall(function()
		if event == "QUEST_LOG_UPDATE" then
			self:GatherQuestLogData()
		elseif event == "QUEST_DETAIL" then
			self:GatherQuestDetails(unpack(args))
		elseif event == "LOOT_OPENED" then
			self:GatherLootData()
		elseif event == "UNIT_DIED" then
			self:GatherMobDeathData(unpack(args))
		elseif event == "ENCOUNTER_START" then
			self:GatherEncounterData("start", unpack(args))
		elseif event == "ENCOUNTER_END" then
			self:GatherEncounterData("end", unpack(args))
		end
	end)
end

-- Gather quest data from quest log
function InfinityDataCollectorHooks:GatherQuestLogData()
	local numEntries = C_QuestLog and C_QuestLog.GetNumEntries and C_QuestLog:GetNumEntries() or GetNumQuestLogEntries()
	
	for i = 1, numEntries do
		local questLogTitleText, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask = GetQuestLogTitle(i)
		
		if questID and questID > 0 and not isHeader then
			-- Get quest details
			local questName = questLogTitleText or "Unknown"
			local questLevel = level or 0
			local zone = GetRealZoneText() or "Unknown"
			local objective = "Unknown"
			
			-- Get quest objective
			local objectiveText = GetObjectiveText()
			if objectiveText and objectiveText ~= "" then
				objective = objectiveText
			end
			
			-- Record quest data
			InfinityDataCollectorCore:RecordQuestData(questID, questName, questLevel, nil, 0, 0, zone, objective, {})
		end
	end
end

-- Gather detailed quest information when viewing quest
function InfinityDataCollectorHooks:GatherQuestDetails(questID)
	if not questID or questID <= 0 then
		return
	end
	
	local questName = GetTitleText() or "Unknown"
	local questLevel = tonumber(string.match(GetQuestLogTitle(questID) or "", "(%d+)")) or 0
	local questGiver = UnitName("npc") or "Unknown"
	local npcX, npcY = GetPlayerMapPosition("npc")
	local zone = GetRealZoneText() or "Unknown"
	local questText = GetQuestText() or "Unknown"
	
	InfinityDataCollectorCore:RecordQuestData(questID, questName, questLevel, questGiver, npcX or 0, npcY or 0, zone, questText, {})
	
	-- Record NPC quest giver
	local npcID = tonumber(string.match(questName or "", "(%d+)")) or 0
	if npcID > 0 then
		InfinityDataCollectorCore:RecordNPCData(npcID, questGiver, npcX or 0, npcY or 0, zone, "quest_giver")
	end
end

-- Gather loot data when items are looted
function InfinityDataCollectorHooks:GatherLootData()
	for lootSlot = 1, GetNumLootItems() do
		local iconTexture, lootName, lootQuantity, rarity, locked, isQuestItem, questID, questLogIndex, minLevel, actualQuality, lootSource = GetLootSlotInfo(lootSlot)
		
		if lootName and lootQuantity then
			local lootType, lootID = GetLootSlotLink(lootSlot)
			
			-- Extract mob ID from combat log context
			local mobID = UnitGUID("target") and tonumber(string.match(UnitGUID("target"), "Creature%-(%d+)%-")) or 0
			
			if mobID > 0 and lootID then
				local mobName = UnitName("target") or "Unknown"
				InfinityDataCollectorCore:RecordDropData(mobID, mobName, lootID, lootName, 0, actualQuality or 1)
			end
		end
	end
end

-- Gather mob data when mobs die
function InfinityDataCollectorHooks:GatherMobDeathData(unit)
	if unit ~= "target" then
		return
	end
	
	local mobName = UnitName("target")
	local mobLevel = UnitLevel("target")
	local mobType = UnitCreatureType("target")
	local mobClass = UnitClassification("target")
	local mobHealth = UnitHealthMax("target")
	local guid = UnitGUID("target")
	local mobID = guid and tonumber(string.match(guid, "Creature%-(%d+)%-")) or 0
	
	if mobID > 0 then
		local playerX, playerY = GetPlayerMapPosition("player")
		local zone = GetRealZoneText() or "Unknown"
		
		InfinityDataCollectorCore:RecordMobData(mobID, mobName, mobLevel, mobType or mobClass, playerX or 0, playerY or 0, zone, mobHealth, mobHealth)
	end
end

-- Gather encounter data (bosses and world bosses)
function InfinityDataCollectorHooks:GatherEncounterData(eventType, encounterID, encounterName, difficultyID, groupSize)
	if eventType == "start" then
		-- Record boss encounter start
		local bossName = encounterName or "Unknown"
		local bossID = encounterID or 0
		local difficulty = difficultyID or 0
		local zone = GetRealZoneText() or "Unknown"
		
		if bossID > 0 then
			local playerX, playerY = GetPlayerMapPosition("player")
			InfinityDataCollectorCore:RecordMobData(bossID, bossName, 999, "boss", playerX or 0, playerY or 0, zone, 999999, 999999)
		end
	end
end

-- Auto-collect gathering node data from minimap
function InfinityDataCollectorHooks:GatherNodeData()
	-- This would hook into minimap scanning to find nodes
	-- For now, provides hook point for external integration
end

-- Merge external database data (QuestieDB, etc)
function InfinityDataCollectorHooks:MergeExternalData(externalDB, dataType)
	if not externalDB then
		return false
	end
	
	pcall(function()
		if dataType == "questie" then
			-- Merge Questie quest data
			for questID, questData in pairs(externalDB) do
				if type(questData) == "table" and questID > 0 then
					local zone = questData.zone or "Unknown"
					local name = questData.name or "Unknown"
					local level = questData.level or 0
					
					InfinityDataCollectorCore:RecordQuestData(questID, name, level, nil, 0, 0, zone, "", {})
				end
			end
		elseif dataType == "wowhead" then
			-- Merge WowHead data
			for mobID, mobData in pairs(externalDB) do
				if type(mobData) == "table" and mobID > 0 then
					local zone = mobData.zone or "Unknown"
					local name = mobData.name or "Unknown"
					local level = mobData.level or 0
					
					InfinityDataCollectorCore:RecordMobData(mobID, name, level, mobData.type, 0, 0, zone, 0, mobData.health or 0)
				end
			end
		end
	end)
	
	return true
end

-- Get active gathering stats
function InfinityDataCollectorHooks:GetGatheringStats()
	return InfinityDataCollectorCore:GetStatistics()
end

-- Start autonomous gathering
function InfinityDataCollectorHooks:Start()
	self:Initialize()
	InfinityDataCollectorCore:SetGatheringEnabled(true)
	InfinityUtils:Info("Autonomous data gathering started", "DataCollectorHooks")
end

-- Stop autonomous gathering
function InfinityDataCollectorHooks:Stop()
	InfinityDataCollectorCore:SetGatheringEnabled(false)
	InfinityUtils:Info("Autonomous data gathering stopped", "DataCollectorHooks")
end
