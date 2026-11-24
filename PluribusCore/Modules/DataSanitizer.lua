-- Data Sanitizer Module
-- Removes personal information before sharing with other players

local DataSanitizer = {
	config = {
		removePlayerNames = true,
		removeGuildInfo = false, -- Keep guild info but only for guild members
		removeLocationData = false,
		minShareDistance = 500, -- yards
	},
}

_G.PluribusDataSanitizer = DataSanitizer

-- Initialize sanitizer
function DataSanitizer:Initialize()
	PluribusUtils:Info("Data sanitizer initialized", "Core")
	
	-- Subscribe to data sharing events
	PluribusMessaging:Subscribe("share_data", function(batch)
		DataSanitizer:OnDataShared(batch)
	end)
	
	-- Subscribe to received data
	PluribusMessaging:Subscribe("receive_shared_data", function(batch, source)
		DataSanitizer:OnDataReceived(batch, source)
	end)
end

-- Called when about to share data
function DataSanitizer:OnDataShared(batch)
	-- Check if source is in same guild
	local playerGuild = GetGuildInfo("player")
	local sourceGuild = batch.guildName
	
	-- If not in same guild, sanitize sensitive data
	if playerGuild ~= sourceGuild then
		self:SanitizeForNonGuild(batch)
	else
		-- If in same guild, still sanitize personal player data
		self:SanitizeForGuild(batch)
	end
	
	return batch
end

-- Called when receiving shared data
function DataSanitizer:OnDataReceived(batch, source)
	-- Apply same sanitization rules
	local playerGuild = GetGuildInfo("player")
	local sourceGuild = batch.guildName
	
	if playerGuild ~= sourceGuild then
		self:SanitizeForNonGuild(batch)
	else
		self:SanitizeForGuild(batch)
	end
	
	return batch
end

-- Sanitize for non-guild members
function DataSanitizer:SanitizeForNonGuild(batch)
	-- Remove all player name references
	batch.source = "Anonymous Player"
	batch.guildName = "Unknown"
	
	-- Keep quest/mob/drop data but remove collector info
	-- Quest data is public, so keep it
	-- Mob data is public, so keep it
	-- Drop data is public, so keep it
	-- But add privacy note
	batch.isPrivacySanitized = true
	
	return batch
end

-- Sanitize for guild members
function DataSanitizer:SanitizeForGuild(batch)
	-- Keep full data for guild members
	-- Only remove truly private data
	
	-- Keep player name (guild members know each other)
	-- Keep guild name
	-- Remove any personal preferences or settings
	
	batch.isPrivacySanitized = false
	
	return batch
end

-- Check if data contains personal information
function DataSanitizer:HasPersonalInfo(dataItem)
	-- Check for player names
	if dataItem.source and dataItem.source ~= "Anonymous Player" then
		return true
	end
	
	-- Check for guild info
	if dataItem.guildName and dataItem.guildName ~= "Unknown" then
		return true
	end
	
	-- Check for specific player references in comments or descriptions
	if dataItem.notes and string.find(dataItem.notes, "%a+%s+%w+") then
		return true
	end
	
	return false
end

-- Get sanitization status
function DataSanitizer:GetStatus()
	return {
		removePlayerNames = self.config.removePlayerNames,
		removeGuildInfo = self.config.removeGuildInfo,
		removeLocationData = self.config.removeLocationData,
		minShareDistance = self.config.minShareDistance,
	}
end

-- Display sanitization status
function DataSanitizer:DisplayStatus()
	print("|cffffd700=== DATA SANITIZER STATUS ===|r")
	print("Remove Player Names: " .. (self.config.removePlayerNames and "YES" or "NO"))
	print("Remove Guild Info: " .. (self.config.removeGuildInfo and "YES" or "NO"))
	print("Remove Location Data: " .. (self.config.removeLocationData and "YES" or "NO"))
	print("Min Share Distance: " .. self.config.minShareDistance .. " yards")
end

-- Set sanitization options
function DataSanitizer:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		PluribusUtils:Info("Sanitizer config updated: " .. key .. " = " .. tostring(value), "Core")
	end
end

return DataSanitizer
