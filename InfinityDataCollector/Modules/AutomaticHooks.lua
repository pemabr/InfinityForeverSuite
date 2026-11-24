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
	
	-- Register permitted events for standalone autonomous gathering
	local events = {
		"QUEST_LOG_UPDATE",
		"QUEST_ACCEPTED",
		"QUEST_DETAIL",
		"QUEST_PROGRESS",
		"QUEST_COMPLETE",
		"LOOT_OPENED",
		"LOOT_ITEM_ROLL_WON",
		"PLAYER_TARGET_CHANGED",
		"ENCOUNTER_START",
		"ENCOUNTER_END",
		"UNIT_SPELLCAST_SUCCEEDED",
		"BANKFRAME_OPENED",
		"UPDATE_INVENTORY_DURABILITY",
	}
	for _, ev in ipairs(events) do
		pcall(self.eventFrame.RegisterEvent, self.eventFrame, ev)
	end
	
	InfinityUtils:Info("Standalone data gathering hooks initialized", "DataCollectorHooks")
	return true
end

-- Gathering spell lookup for autonomous node recording (no GathererDB required)
local GATHER_SPELLS = {
	[2366] = "herb",    -- Herb Gathering
	[2575] = "mining",  -- Mining
	[8613] = "skinning",
	[7620] = "fishing",
	[32606] = "mining",
	[50300] = "skinning",
}

-- Main event handler
function InfinityDataCollectorHooks:OnGameEvent(event, ...)
	if not InfinityDataCollectorCore or not InfinityDataCollectorCore:IsGatheringEnabled() then
		return
	end
	
	local args = { ... }
	pcall(function()
		if event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" then
			self:GatherQuestLogData()
		elseif event == "QUEST_DETAIL" then
			self:GatherQuestDetails(unpack(args))
		elseif event == "LOOT_OPENED" then
			self:GatherLootData()
		elseif event == "PLAYER_TARGET_CHANGED" then
			self:GatherTargetMobData()
		elseif event == "ENCOUNTER_START" then
			self:GatherEncounterData("start", unpack(args))
		elseif event == "ENCOUNTER_END" then
			self:GatherEncounterData("end", unpack(args))
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			self:GatherNodeFromSpell(unpack(args))
		end
	end)
end

-- Gather quest data from live WoW quest log (C_QuestLog compatible)
function InfinityDataCollectorHooks:GatherQuestLogData()
	local numEntries = InfinityUtils:GetQuestLogCount()
	local zone = GetRealZoneText and GetRealZoneText() or "Unknown"
	local px, py = InfinityUtils:GetUnitMapPosition("player")
	
	for i = 1, numEntries do
		local title, level, isHeader, questID = InfinityUtils:GetQuestLogEntry(i)
		
		if questID and type(questID) == "number" and questID > 0 and not isHeader then
			local questName = title or ("Quest #" .. questID)
			local questLevel = level or 0
			local objectiveText = ""
			local objs = InfinityUtils:GetQuestObjectives(questID)
			if objs and #objs > 0 and objs[1].text then
				objectiveText = objs[1].text
			end
			
			InfinityDataCollectorCore:RecordQuestData(questID, questName, questLevel, nil, px or 0, py or 0, zone, objectiveText, {})
		end
	end
end

-- Gather detailed quest information when viewing quest
function InfinityDataCollectorHooks:GatherQuestDetails(questID)
	local qid = questID or (GetQuestID and GetQuestID()) or 0
	if not qid or qid <= 0 then
		return
	end
	
	local questName = (GetTitleText and GetTitleText()) or InfinityUtils:GetQuestTitleByID(qid) or "Unknown"
	local questLevel = 0
	local questGiver = (UnitName and UnitName("npc")) or "Unknown"
	if InfinityUtils:IsSecret(questGiver) then questGiver = "Unknown" end
	local npcX, npcY = InfinityUtils:GetUnitMapPosition("player")
	local zone = (GetRealZoneText and GetRealZoneText()) or "Unknown"
	local questText = (GetQuestText and GetQuestText()) or ""
	
	InfinityDataCollectorCore:RecordQuestData(qid, questName, questLevel, questGiver, npcX or 0, npcY or 0, zone, questText, {})
	
	local npcGuid = UnitGUID and UnitGUID("npc")
	if npcGuid and not InfinityUtils:IsSecret(npcGuid) then
		local npcID = tonumber(string.match(npcGuid, "Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")) or tonumber(string.match(npcGuid, "Creature%-(%d+)%-")) or 0
		if npcID > 0 then
			InfinityDataCollectorCore:RecordNPCData(npcID, questGiver, npcX or 0, npcY or 0, zone, "quest_giver")
		end
	end
end

-- Gather loot data when items are looted
function InfinityDataCollectorHooks:GatherLootData()
	local numItems = GetNumLootItems and GetNumLootItems() or 0
	local targetGuid = UnitGUID and UnitGUID("target")
	local mobID = 0
	if targetGuid and not InfinityUtils:IsSecret(targetGuid) then
		mobID = tonumber(string.match(targetGuid, "Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")) or tonumber(string.match(targetGuid, "Creature%-(%d+)%-")) or 0
	end
	local mobName = UnitName and UnitName("target") or "Unknown"
	if InfinityUtils:IsSecret(mobName) then mobName = "Unknown" end

	for lootSlot = 1, numItems do
		local _, lootName, lootQuantity, rarity = GetLootSlotInfo(lootSlot)
		if lootName and lootQuantity then
			local link = GetLootSlotLink and GetLootSlotLink(lootSlot)
			local itemID = link and InfinityUtils:GetItemIDFromHyperlink(link) or nil
			if mobID > 0 and itemID then
				InfinityDataCollectorCore:RecordDropData(mobID, mobName, itemID, lootName, 0, rarity or 1)
			end
		end
	end
end

-- Autonomous mob/NPC recording when targeting units (no WowHeadDB required)
function InfinityDataCollectorHooks:GatherTargetMobData()
	if not UnitExists or not UnitExists("target") then return end
	if UnitIsPlayer and UnitIsPlayer("target") then return end

	local guid = UnitGUID and UnitGUID("target")
	if not guid or InfinityUtils:IsSecret(guid) then return end

	local mobID = tonumber(string.match(guid, "Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")) or tonumber(string.match(guid, "Creature%-(%d+)%-")) or 0
	if mobID <= 0 then return end

	local mobName = UnitName("target")
	local mobLevel = UnitLevel("target")
	local mobType = UnitCreatureType and UnitCreatureType("target") or "Creature"
	local mobClass = UnitClassification and UnitClassification("target") or "normal"
	local mobHealth = UnitHealthMax and UnitHealthMax("target") or 0

	if InfinityUtils:IsSecret(mobName) or InfinityUtils:IsSecret(mobLevel) or InfinityUtils:IsSecret(mobHealth) then
		return
	end

	local playerX, playerY = InfinityUtils:GetUnitMapPosition("player")
	local zone = (GetRealZoneText and GetRealZoneText()) or "Unknown"

	if UnitCanAttack and UnitCanAttack("player", "target") then
		InfinityDataCollectorCore:RecordMobData(mobID, mobName or "Unknown", mobLevel or 0, mobType or mobClass, playerX or 0, playerY or 0, zone, mobHealth or 0, mobHealth or 0)
	else
		InfinityDataCollectorCore:RecordNPCData(mobID, mobName or "Unknown", playerX or 0, playerY or 0, zone, "npc")
	end
end

-- Backwards-compatible alias
function InfinityDataCollectorHooks:GatherMobDeathData(unit)
	if unit == "target" then
		self:GatherTargetMobData()
	end
end

-- Gather encounter data (bosses and world bosses)
function InfinityDataCollectorHooks:GatherEncounterData(eventType, encounterID, encounterName, difficultyID, groupSize)
	if eventType == "start" then
		local bossName = encounterName or "Unknown"
		local bossID = encounterID or 0
		local zone = (GetRealZoneText and GetRealZoneText()) or "Unknown"
		
		if bossID > 0 then
			local playerX, playerY = InfinityUtils:GetUnitMapPosition("player")
			InfinityDataCollectorCore:RecordMobData(bossID, bossName, 999, "boss", playerX or 0, playerY or 0, zone, 999999, 999999)
		end
	end
end

-- Standalone gathering node auto-recorder (no GathererDB required)
function InfinityDataCollectorHooks:GatherNodeFromSpell(unit, _, spellID)
	if unit ~= "player" or not spellID or InfinityUtils:IsSecret(spellID) then return end
	local nodeType = GATHER_SPELLS[spellID]
	if not nodeType then
		local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
		if type(spellName) == "string" then
			local lower = spellName:lower()
			if lower:find("herb") or lower:find("kräuter") then nodeType = "herb"
			elseif lower:find("mining") or lower:find("bergbau") then nodeType = "mining"
			elseif lower:find("skinning") or lower:find("kürschner") then nodeType = "skinning"
			elseif lower:find("fishing") or lower:find("angeln") then nodeType = "fishing" end
		end
	end
	if not nodeType then return end

	local px, py = InfinityUtils:GetUnitMapPosition("player")
	local zone = (GetRealZoneText and GetRealZoneText()) or "Unknown"
	local nodeID = math.floor((px or 0) * 1000) * 1000 + math.floor((py or 0) * 1000)
	InfinityDataCollectorCore:RecordNodeData(nodeType, nodeID, (px or 0) * 100, (py or 0) * 100, zone, 0, 300)
	if _G.InfinityNodeDB and _G.InfinityNodeDB.RecordNode then
		pcall(function() _G.InfinityNodeDB:RecordNode(nodeType, (px or 0) * 100, (py or 0) * 100, zone, 300) end)
	end
end

-- Auto-collect gathering node data
function InfinityDataCollectorHooks:GatherNodeData()
	local px, py = InfinityUtils:GetUnitMapPosition("player")
	local zone = (GetRealZoneText and GetRealZoneText()) or "Unknown"
	if px and py and (px > 0 or py > 0) then
		local nodeID = math.floor(px * 1000) * 1000 + math.floor(py * 1000)
		InfinityDataCollectorCore:RecordNodeData("node", nodeID, px * 100, py * 100, zone, 0, 300)
	end
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
