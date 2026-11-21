-- Infinity Roster Manager
-- Guild roster tracking and member management

InfinityRosterManager = {
	members = {},
	guildName = "",
	guildLevel = 0,
	version = 1,
	maxMembers = 1000,
}

function InfinityRosterManager:Initialize()
	InfinityDataManager:RegisterSource("guild_roster", function(data) end)
	self:ScanGuild()
	InfinityUtils:Info("Roster Manager initialized", "Roster")
end

function InfinityRosterManager:ScanGuild()
	if not IsInGuild() then
		return false
	end
	
	self.guildName = GetGuildInfo("player")
	local guildLevel = _G.GetGuildLevel and select(2, _G.GetGuildLevel()) or 0
	self.guildLevel = guildLevel or 0
	
	-- Get total members
	local totalMembers = GetNumGuildMembers()
	self.members = {}
	
	for i = 1, totalMembers do
		local name, rank, rankIndex, level, class, zone, note, officerNote, isOnline, status, classFileName, achievementPoints, achLevel, mobile = GetGuildRosterInfo(i)
		
		if name then
			local charKey = name .. "-" .. GetRealmName()
			self.members[charKey] = {
				name = name,
				rank = rank,
				rankIndex = rankIndex,
				level = level,
				class = class,
				classFileName = classFileName,
				zone = zone,
				note = note,
				officerNote = officerNote,
				isOnline = isOnline,
				status = status,
				achievementPoints = achievementPoints,
				lastSeen = InfinityUtils:GetTimeStamp(),
			}
			
			-- Link to character manager if applicable
			if InfinityCharacterManager then
				InfinityCharacterManager:LinkCharacterToMain(name, name)
			end
		end
	end
	
	InfinityUtils:Info("Guild roster scanned: " .. totalMembers .. " members", "Roster")
	return true
end

function InfinityRosterManager:GetMemberInfo(memberName)
	local charKey = memberName .. "-" .. GetRealmName()
	return self.members[charKey]
end

function InfinityRosterManager:GetMembersByRank(rank)
	local result = {}
	for key, member in pairs(self.members) do
		if member.rank == rank then
			table.insert(result, member)
		end
	end
	return result
end

function InfinityRosterManager:GetOnlineMembers()
	local result = {}
	for key, member in pairs(self.members) do
		if member.isOnline then
			table.insert(result, member)
		end
	end
	return result
end

function InfinityRosterManager:GetMembersByClass(class)
	local result = {}
	for key, member in pairs(self.members) do
		if member.classFileName == class then
			table.insert(result, member)
		end
	end
	return result
end

function InfinityRosterManager:GetRosterStats()
	local stats = {
		totalMembers = 0,
		onlineMembers = 0,
		byRank = {},
		byClass = {},
		byLevel = {},
		averageLevel = 0,
	}
	
	local totalLevel = 0
	
	for key, member in pairs(self.members) do
		stats.totalMembers = stats.totalMembers + 1
		
		if member.isOnline then
			stats.onlineMembers = stats.onlineMembers + 1
		end
		
		-- By rank
		if not stats.byRank[member.rank] then
			stats.byRank[member.rank] = 0
		end
		stats.byRank[member.rank] = stats.byRank[member.rank] + 1
		
		-- By class
		if not stats.byClass[member.classFileName] then
			stats.byClass[member.classFileName] = 0
		end
		stats.byClass[member.classFileName] = stats.byClass[member.classFileName] + 1
		
		-- By level
		if not stats.byLevel[member.level] then
			stats.byLevel[member.level] = 0
		end
		stats.byLevel[member.level] = stats.byLevel[member.level] + 1
		
		totalLevel = totalLevel + member.level
	end
	
	if stats.totalMembers > 0 then
		stats.averageLevel = math.floor(totalLevel / stats.totalMembers)
	end
	
	return stats
end

function InfinityRosterManager:ExportRoster()
	local export = {
		guildName = self.guildName,
		guildLevel = self.guildLevel,
		exportTime = InfinityUtils:GetTimeStamp(),
		members = {}
	}
	
	for key, member in pairs(self.members) do
		table.insert(export.members, InfinityUtils:DeepCopy(member))
	end
	
	return export
end

function InfinityRosterManager:FindMembersByZone(zone)
	local result = {}
	for key, member in pairs(self.members) do
		if member.zone == zone then
			table.insert(result, member)
		end
	end
	return result
end

function InfinityRosterManager:GetGuildInfo()
	return {
		name = self.guildName,
		level = self.guildLevel,
		totalMembers = #self.members,
		scanTime = InfinityUtils:GetTimeStamp(),
	}
end

return InfinityRosterManager
