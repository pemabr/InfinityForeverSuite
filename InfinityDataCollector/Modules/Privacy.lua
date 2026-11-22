-- InfinityDataCollector Privacy & Sanitization Module
-- Removes personal information from shared data based on guild membership

InfinityDataCollectorPrivacy = {
	sanitizationLevel = "guild",  -- "none", "guild", "anonymous"
	guildMembers = {},
	version = 1,
}

-- Sanitization levels:
-- "none"      = Share full data with everyone
-- "guild"     = Share full data with guild members, sanitized data with others
-- "anonymous" = Share only anonymized statistics

-- Initialize guild member cache
function InfinityDataCollectorPrivacy:InitializeGuildMemberCache()
	self.guildMembers = {}
	
	-- Get current guild
	local guildName = GetGuildInfo("player")
	if not guildName then
		return
	end
	
	-- Cache all guild members
	local numMembers = GetNumGuildMembers()
	for i = 1, numMembers do
		local name = GetGuildRosterInfo(i)
		if name then
			self.guildMembers[name] = true
		end
	end
end

-- Check if player is in same guild
function InfinityDataCollectorPrivacy:IsGuildMember(playerName)
	if not playerName then
		return false
	end
	
	-- If not initialized, do it now
	if not next(self.guildMembers) then
		self:InitializeGuildMemberCache()
	end
	
	return self.guildMembers[playerName] or false
end

-- Sanitize a single quest entry
function InfinityDataCollectorPrivacy:SanitizeQuestEntry(questData, playerName)
	if not questData then
		return nil
	end
	
	local isGuildMember = self:IsGuildMember(playerName)
	
	if self.sanitizationLevel == "none" or isGuildMember then
		return questData
	end
	
	if self.sanitizationLevel == "anonymous" then
		-- Remove identifying information
		return {
			id = questData.id,
			name = questData.name,
			level = questData.level,
			zone = questData.zone,
			objective = questData.objective,
			-- Don't include: giver location, rewards details, timestamps
		}
	end
	
	if self.sanitizationLevel == "guild" then
		-- Share location but not reward details
		return {
			id = questData.id,
			name = questData.name,
			level = questData.level,
			giver = questData.giver,
			giver_location = questData.giver_location,
			zone = questData.zone,
			objective = questData.objective,
			-- Don't include: exact reward values, timestamps
		}
	end
	
	return nil
end

-- Sanitize a single mob entry
function InfinityDataCollectorPrivacy:SanitizeMobEntry(mobData, playerName)
	if not mobData then
		return nil
	end
	
	local isGuildMember = self:IsGuildMember(playerName)
	
	if self.sanitizationLevel == "none" or isGuildMember then
		return mobData
	end
	
	if self.sanitizationLevel == "anonymous" then
		-- Very limited data
		return {
			id = mobData.id,
			name = mobData.name,
			level = mobData.level,
			type = mobData.type,
			-- Don't include: locations, sightings data
		}
	end
	
	if self.sanitizationLevel == "guild" then
		-- Include some location data
		return {
			id = mobData.id,
			name = mobData.name,
			level = mobData.level,
			type = mobData.type,
			locations = mobData.locations,
			avgHealth = mobData.avgHealth,
			-- Don't include: sighting timestamps
		}
	end
	
	return nil
end

-- Sanitize a single drop entry
function InfinityDataCollectorPrivacy:SanitizeDropEntry(dropData, playerName)
	if not dropData then
		return nil
	end
	
	local isGuildMember = self:IsGuildMember(playerName)
	
	if self.sanitizationLevel == "none" or isGuildMember then
		return dropData
	end
	
	if self.sanitizationLevel == "anonymous" then
		-- Only share that item can drop (no rates)
		return {
			mobID = dropData.mobID,
			mobName = dropData.mobName,
			itemID = dropData.itemID,
			itemName = dropData.itemName,
			-- Don't include: dropRate, rarity, sightings
		}
	end
	
	if self.sanitizationLevel == "guild" then
		-- Share with rarity
		return {
			mobID = dropData.mobID,
			mobName = dropData.mobName,
			itemID = dropData.itemID,
			itemName = dropData.itemName,
			rarity = dropData.rarity,
			sightings = dropData.sightings,
		}
	end
	
	return nil
end

-- Sanitize a single node entry
function InfinityDataCollectorPrivacy:SanitizeNodeEntry(nodeData, playerName)
	if not nodeData then
		return nil
	end
	
	local isGuildMember = self:IsGuildMember(playerName)
	
	if self.sanitizationLevel == "none" or isGuildMember then
		return nodeData
	end
	
	if self.sanitizationLevel == "anonymous" then
		-- Very limited data
		return {
			type = nodeData.type,
			id = nodeData.id,
			level = nodeData.level,
			respawnTime = nodeData.respawnTime,
			-- Don't include: locations, sightings
		}
	end
	
	if self.sanitizationLevel == "guild" then
		-- Include locations
		return {
			type = nodeData.type,
			id = nodeData.id,
			level = nodeData.level,
			respawnTime = nodeData.respawnTime,
			locations = nodeData.locations,
			sightings = nodeData.sightings,
		}
	end
	
	return nil
end

-- Sanitize an NPC entry
function InfinityDataCollectorPrivacy:SanitizeNPCEntry(npcData, playerName)
	if not npcData then
		return nil
	end
	
	local isGuildMember = self:IsGuildMember(playerName)
	
	if self.sanitizationLevel == "none" or isGuildMember then
		return npcData
	end
	
	if self.sanitizationLevel == "anonymous" then
		-- Only name and type
		return {
			id = npcData.id,
			name = npcData.name,
			type = npcData.type,
		}
	end
	
	if self.sanitizationLevel == "guild" then
		-- Include locations
		return {
			id = npcData.id,
			name = npcData.name,
			locations = npcData.locations,
			type = npcData.type,
		}
	end
	
	return nil
end

-- Sanitize entire data export for sharing
function InfinityDataCollectorPrivacy:SanitizeDataExport(exportData, requestingPlayer)
	if not exportData then
		return nil
	end
	
	local sanitized = {
		quests = {},
		mobs = {},
		drops = {},
		nodes = {},
		npcs = {},
		exportTime = exportData.exportTime,
		version = exportData.version,
		sanitized = true,
		sanitizationLevel = self.sanitizationLevel,
	}
	
	-- Sanitize quests
	if exportData.quests then
		for questID, questData in pairs(exportData.quests) do
			local sanitized_quest = self:SanitizeQuestEntry(questData, requestingPlayer)
			if sanitized_quest then
				sanitized.quests[questID] = sanitized_quest
			end
		end
	end
	
	-- Sanitize mobs
	if exportData.mobs then
		for mobID, mobData in pairs(exportData.mobs) do
			local sanitized_mob = self:SanitizeMobEntry(mobData, requestingPlayer)
			if sanitized_mob then
				sanitized.mobs[mobID] = sanitized_mob
			end
		end
	end
	
	-- Sanitize drops
	if exportData.drops then
		for dropKey, dropData in pairs(exportData.drops) do
			local sanitized_drop = self:SanitizeDropEntry(dropData, requestingPlayer)
			if sanitized_drop then
				sanitized.drops[dropKey] = sanitized_drop
			end
		end
	end
	
	-- Sanitize nodes
	if exportData.nodes then
		for nodeKey, nodeData in pairs(exportData.nodes) do
			local sanitized_node = self:SanitizeNodeEntry(nodeData, requestingPlayer)
			if sanitized_node then
				sanitized.nodes[nodeKey] = sanitized_node
			end
		end
	end
	
	-- Sanitize NPCs
	if exportData.npcs then
		for npcID, npcData in pairs(exportData.npcs) do
			local sanitized_npc = self:SanitizeNPCEntry(npcData, requestingPlayer)
			if sanitized_npc then
				sanitized.npcs[npcID] = sanitized_npc
			end
		end
	end
	
	return sanitized
end

-- Set sanitization level
function InfinityDataCollectorPrivacy:SetSanitizationLevel(level)
	if level == "none" or level == "guild" or level == "anonymous" then
		self.sanitizationLevel = level
		InfinityUtils:Info("Sanitization level set to: " .. level, "Privacy")
		return true
	end
	return false
end

-- Get sanitization level
function InfinityDataCollectorPrivacy:GetSanitizationLevel()
	return self.sanitizationLevel
end

-- Remove player from guild cache (for update)
function InfinityDataCollectorPrivacy:RefreshGuildCache()
	self.guildMembers = {}
	self:InitializeGuildMemberCache()
end
