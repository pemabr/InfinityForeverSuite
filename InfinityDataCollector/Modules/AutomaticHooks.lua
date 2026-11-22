-- InfinityDataCollector Autonomous Hook Module
-- Automatically hooks game events to gather data without user input

InfinityDataCollectorHooks = {
	hooked = {},
	eventFrame = nil,
	questCache = {},
	mobCache = {},
}

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function PositiveID(value)
	return type(value) == "number" and value == value and value > 0
		and value < math.huge and value == math.floor(value)
end

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
	self.eventFrame:RegisterEvent("LOOT_OPENED")                -- Drop data
	self.eventFrame:RegisterEvent("LOOT_CLOSED")
	
	InfinityUtils:Info("Data gathering hooks initialized", "DataCollectorHooks")
	return true
end

-- Main event handler
function InfinityDataCollectorHooks:OnGameEvent(event, ...)
	if event == "LOOT_CLOSED" then
		self.lootSessionSeen = nil
		return
	end
	if not InfinityDataCollectorCore:IsGatheringEnabled() then
		return
	end

	if event == "QUEST_LOG_UPDATE" then
		self:GatherQuestLogData()
	elseif event == "QUEST_DETAIL" then
		self:GatherQuestDetails()
	elseif event == "LOOT_OPENED" then
		self:GatherLootData()
	end
end

-- Gather quest data from quest log
function InfinityDataCollectorHooks:GatherQuestLogData()
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
		local numEntries = Public(C_QuestLog.GetNumQuestLogEntries())
		if type(numEntries) ~= "number" or numEntries ~= numEntries or numEntries < 0
			or numEntries > 10000 or numEntries ~= math.floor(numEntries) then return end
		local current = {}
		for i = 1, numEntries do
			local info = Public(C_QuestLog.GetInfo(i))
			if type(info) == "table" then
				local header, id, name, level = Public(info.isHeader), Public(info.questID), Public(info.title), Public(info.level)
				local hiddenHeader = _G.issecretvalue and _G.issecretvalue(info.isHeader)
				if not hiddenHeader and not header and PositiveID(id) and type(name) == "string" then
					if type(level) ~= "number" or level ~= level or level >= math.huge then level = nil end
					local previous = self.questCache[id]
					current[id] = { name = name, level = level }
					if not previous or previous.name ~= name or previous.level ~= level then
						InfinityDataCollectorCore:RecordQuestData(id, name, level, nil, nil, nil, nil, nil, nil)
						if _G.InfinityGuildKnowledge then InfinityGuildKnowledge:ObserveQuest(id, name, level) end
					end
				end
			end
		end
		self.questCache = current
		return
	end
end

-- Gather detailed quest information when viewing quest
function InfinityDataCollectorHooks:GatherQuestDetails()
	local questID = _G.GetQuestID and Public(GetQuestID())
	local questName = _G.GetTitleText and Public(GetTitleText())
	if not PositiveID(questID) or type(questName) ~= "string" then return end
	local questGiver = _G.UnitName and Public(UnitName("npc"))
	local questText = _G.GetQuestText and Public(GetQuestText())
	local zone = _G.GetRealZoneText and Public(GetRealZoneText())
	if type(questGiver) ~= "string" then questGiver = nil end
	if type(questText) ~= "string" then questText = nil end
	if type(zone) ~= "string" then zone = nil end
	InfinityDataCollectorCore:RecordQuestData(questID, questName, nil, questGiver, nil, nil, zone, questText, nil)
	if _G.InfinityGuildKnowledge then InfinityGuildKnowledge:ObserveQuest(questID, questName, 0) end
	if _G.InfinityGuildQuestPositions then InfinityGuildQuestPositions:ObserveOffer(questID, questGiver) end
end

-- Gather loot data when items are looted
function InfinityDataCollectorHooks:GatherLootData()
	if not _G.GetNumLootItems or not _G.GetLootSourceInfo or not _G.GetLootSlotLink or not _G.GetLootSlotInfo then return end
	local count = Public(GetNumLootItems())
	if type(count) ~= "number" or count ~= count or count < 0 or count > 1000 or count ~= math.floor(count) then return end
	self.lootSessionSeen = self.lootSessionSeen or {}
	for slot = 1, count do
		local source, _, additionalSource = GetLootSourceInfo(slot)
		local hiddenSource = _G.issecretvalue and _G.issecretvalue(additionalSource)
		source, additionalSource = Public(source), Public(additionalSource)
		local link = Public(GetLootSlotLink(slot))
		if not hiddenSource and type(source) == "string" and additionalSource == nil and type(link) == "string" then
			local mobID = tonumber(source:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
			local itemID = tonumber(link:match("item:(%d+)"))
			local key = source .. ":" .. (itemID or "")
			if PositiveID(mobID) and PositiveID(itemID) and not self.lootSessionSeen[key] then
				local _, name, _, _, rarity = GetLootSlotInfo(slot)
				name, rarity = Public(name), Public(rarity)
				if type(name) ~= "string" then name = nil end
				if type(rarity) ~= "number" then rarity = nil end
				local target = _G.UnitGUID and Public(UnitGUID("target"))
				local mobName = target == source and _G.UnitName and Public(UnitName("target"))
				if type(mobName) ~= "string" then mobName = nil end
				InfinityDataCollectorCore:RecordDropData(mobID, mobName, itemID, name, nil, rarity)
				if _G.InfinityGuildKnowledge then InfinityGuildKnowledge:ObserveDrop(mobID, mobName, itemID, name, rarity) end
				self.lootSessionSeen[key] = true
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
	if _G.issecretvalue and _G.issecretvalue(guid) then
		return
	end
	local mobID = guid and tonumber(string.match(guid, "Creature%-(%d+)%-")) or 0
	
	if mobID > 0 then
		local playerX, playerY = InfinityUtils:GetPlayerCoords()
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
			local playerX, playerY = InfinityUtils:GetPlayerCoords()
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
