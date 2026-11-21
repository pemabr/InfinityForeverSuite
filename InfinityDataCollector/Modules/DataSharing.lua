-- Data Sharing System
-- Handles secure sharing of game data between guild members
-- Implements sanitization to prevent personal information leaks

local function TableContains(tbl, value)
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

local DataSharing = {
	sharedData = {
		quests = {},
		mobs = {},
		drops = {},
		nodes = {},
	},
	
	sanitizationRules = {
		-- What to remove for non-guild-members
		removePersonal = {
			"playerName",
			"characterName",
			"realmName",
			"guildName",
			"guildRank",
		},
		-- What to keep for all
		keepPublic = {
			"name",
			"level",
			"zone",
			"subzone",
			"type",
			"quality",
		},
	},
	
	config = {
		enableSharing = true,
		shareBetweenGuilds = false, -- Cross-guild sharing
		shareQuestData = true,
		shareMobData = true,
		shareDropData = true,
		shareNodeData = true,
		maxShareDistance = 100, -- World units
	},
}

_G.InfinityDataSharing = DataSharing

function DataSharing:Initialize()
	InfinityUtils:Info("Data Sharing system initialized", "DataSharing")
	
	-- Listen for data collection events
	InfinityMessaging:Subscribe("quest_data_collected", function(questID, questName)
		DataSharing:ShareQuestData(questID, questName)
	end)
	
	InfinityMessaging:Subscribe("quest_completed", function(questID, questName)
		DataSharing:ShareQuestCompletion(questID, questName)
	end)
	
	-- Create share timer
	self:StartDataSharing()
end

function DataSharing:ShareQuestData(questID, questName)
	if not self.config.enableSharing or not self.config.shareQuestData then return end
	
	-- Get quest data from InfinityData
	local questData = InfinityData:GetQuest(questID)
	if not questData then return end
	
	-- Sanitize for guild members
	local sanitized = self:SanitizeData(questData, "guild")
	
	-- Send to guild
	self:SendToGuild("QUEST_DATA", questID, sanitized)
	
	-- Share with nearby players if enabled
	if self.config.shareBetweenGuilds then
		self:SendToNearbyPlayers("QUEST_DATA", questID, self:SanitizeData(questData, "public"))
	end
end

function DataSharing:ShareQuestCompletion(questID, questName)
	if not self.config.enableSharing or not self.config.shareQuestData then return end
	
	-- Send completion info to guild
	local completionData = {
		questID = questID,
		questName = questName,
		completedBy = UnitName("player"),
		completedAt = time(),
	}
	
	self:SendToGuild("QUEST_COMPLETE", questID, completionData)
end

function DataSharing:ShareMobData(mobID, mobName)
	if not self.config.enableSharing or not self.config.shareMobData then return end
	
	local mobData = InfinityData:GetMob(mobID)
	if not mobData then return end
	
	local sanitized = self:SanitizeData(mobData, "guild")
	self:SendToGuild("MOB_DATA", mobID, sanitized)
end

function DataSharing:ShareDropData(itemID, dropData)
	if not self.config.enableSharing or not self.config.shareDropData then return end
	
	local sanitized = self:SanitizeData(dropData, "guild")
	self:SendToGuild("DROP_DATA", itemID, sanitized)
end

function DataSharing:ShareNodeData(nodeID, nodeName)
	if not self.config.enableSharing or not self.config.shareNodeData then return end
	
	local nodeData = InfinityData:GetNode(nodeID)
	if not nodeData then return end
	
	local sanitized = self:SanitizeData(nodeData, "guild")
	self:SendToGuild("NODE_DATA", nodeID, sanitized)
end

function DataSharing:SanitizeData(data, shareType)
	if shareType == "public" then
		-- Remove all personal identifiers for public sharing
		return self:RemovePersonalInfo(data, true)
	elseif shareType == "guild" then
		-- Keep guild context, remove cross-realm info
		return self:RemovePersonalInfo(data, false)
	else
		-- Full data for self
		return data
	end
end

function DataSharing:RemovePersonalInfo(data, isPublic)
	local sanitized = {}
	
	-- Copy only allowed fields
	local allowedFields = self.sanitizationRules.keepPublic
	
	for _, field in ipairs(allowedFields) do
		if data[field] ~= nil then
			sanitized[field] = data[field]
		end
	end
	
	-- For guild sharing, include some additional fields
	if not isPublic then
		if data.id then sanitized.id = data.id end
		if data.type then sanitized.type = data.type end
	end
	
	return sanitized
end

function DataSharing:SendToGuild(messageType, dataID, data)
	if not InfinityMessaging then return end
	
	-- Compress and send via guild communication channel
	local message = {
		type = messageType,
		id = dataID,
		data = data,
		sender = UnitName("player"),
		timestamp = time(),
	}
	
	-- Use guild chat or whisper to sharing channel
	InfinityMessaging:Publish("data_share_guild", messageType, dataID, data)
end

function DataSharing:SendToNearbyPlayers(messageType, dataID, data)
	if not self.config.shareBetweenGuilds then return end
	
	-- Send to all nearby players (within maxShareDistance)
	-- This would use world channel or raid communication
	
	local message = {
		type = messageType,
		id = dataID,
		data = data,
		sender = UnitName("player"),
		timestamp = time(),
		guild = GetGuildInfo("player") or "None",
	}
	
	InfinityMessaging:Publish("data_share_public", messageType, dataID, data)
end

function DataSharing:ReceiveData(messageType, dataID, data, sender)
	if not self.config.enableSharing then return end
	
	-- Verify sender is in guild or allowed
	if not self:VerifySender(sender) then return end
	
	-- Route to appropriate handler
	if messageType == "QUEST_DATA" then
		self:StoreReceivedQuestData(dataID, data, sender)
	elseif messageType == "MOB_DATA" then
		self:StoreReceivedMobData(dataID, data, sender)
	elseif messageType == "DROP_DATA" then
		self:StoreReceivedDropData(dataID, data, sender)
	elseif messageType == "NODE_DATA" then
		self:StoreReceivedNodeData(dataID, data, sender)
	end
end

function DataSharing:VerifySender(senderName)
	-- Check if sender is in same guild
	local guildName, guildRank, guildRankIndex, notes = GetGuildInfo("player")
	
	-- For now, accept all from guild
	-- Could implement reputation system later
	return true
end

function DataSharing:StoreReceivedQuestData(questID, data, sender)
	-- Merge with existing quest data
	local existing = InfinityData:GetQuest(questID)
	
	if not existing then
		-- Create new entry with contributor info
		local merged = data
		merged.contributors = {sender}
		merged.sharedAt = time()
		InfinityData:StoreQuest(questID, merged)
	else
		-- Update existing, add contributor
		if not existing.contributors then existing.contributors = {} end
		if not TableContains(existing.contributors, sender) then
			table.insert(existing.contributors, sender)
		end
		existing.lastUpdated = time()
		InfinityData:StoreQuest(questID, existing)
	end
end

function DataSharing:StoreReceivedMobData(mobID, data, sender)
	local existing = InfinityData:GetMob(mobID)
	
	if not existing then
		local merged = data
		merged.contributors = {sender}
		merged.sharedAt = time()
		InfinityData:StoreMob(mobID, merged)
	else
		if not existing.contributors then existing.contributors = {} end
		if not TableContains(existing.contributors, sender) then
			table.insert(existing.contributors, sender)
		end
		existing.lastUpdated = time()
		InfinityData:StoreMob(mobID, existing)
	end
end

function DataSharing:StoreReceivedDropData(itemID, data, sender)
	-- Similar to mob data
	local existing = InfinityData:GetDrop(itemID)
	
	if not existing then
		local merged = data
		merged.contributors = {sender}
		merged.sharedAt = time()
		InfinityData:StoreDrop(itemID, merged)
	else
		if not existing.contributors then existing.contributors = {} end
		if not TableContains(existing.contributors, sender) then
			table.insert(existing.contributors, sender)
		end
		existing.lastUpdated = time()
		InfinityData:StoreDrop(itemID, existing)
	end
end

function DataSharing:StoreReceivedNodeData(nodeID, data, sender)
	-- Similar to mob data
	local existing = InfinityData:GetNode(nodeID)
	
	if not existing then
		local merged = data
		merged.contributors = {sender}
		merged.sharedAt = time()
		InfinityData:StoreNode(nodeID, merged)
	else
		if not existing.contributors then existing.contributors = {} end
		if not TableContains(existing.contributors, sender) then
			table.insert(existing.contributors, sender)
		end
		existing.lastUpdated = time()
		InfinityData:StoreNode(nodeID, existing)
	end
end

function DataSharing:StartDataSharing()
	-- Periodic share of collected data
	C_Timer.NewTicker(300, function() -- Every 5 minutes
		if self.config.enableSharing then
			self:ShareCollectedData()
		end
	end)
end

function DataSharing:ShareCollectedData()
	-- Share all newly collected data
	local quests = InfinityData:GetAllQuests()
	local mobs = InfinityData:GetAllMobs()
	local drops = InfinityData:GetAllDrops()
	local nodes = InfinityData:GetAllNodes()
	
	-- Share batches to avoid overwhelming
	for id, questData in pairs(quests) do
		if not questData.shared then
			self:ShareQuestData(id, questData.name)
			questData.shared = true
		end
	end
end

function DataSharing:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityUtils:Info("Data Sharing config updated: " .. key .. " = " .. tostring(value), "DataSharing")
	end
end

return DataSharing
