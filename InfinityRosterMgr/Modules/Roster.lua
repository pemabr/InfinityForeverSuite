-- Infinity Roster Manager
-- Guild roster tracking and member management

InfinityRosterManager = {
	members = {},
	guildName = "",
	guildLevel = 0,
	version = 1,
	maxMembers = 1000,
}

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function RealmKey(name)
	if name:find("-", 1, true) then return name end
	local realm = _G.GetRealmName and Public(GetRealmName())
	if type(realm) ~= "string" or realm == "" then return nil end
	return name .. "-" .. realm
end

function InfinityRosterManager:Initialize()
	InfinityDataManager:RegisterSource("guild_roster", function(data) end)
	self:ScanGuild()
	InfinityUtils:Info("Roster Manager initialized", "Roster")
end

function InfinityRosterManager:ScanGuild()
	local function Fail(message)
		if self.scanError ~= message then InfinityUtils:Warning(message, "Roster") end
		self.scanError = message
		return false
	end
	if not _G.IsInGuild or not Public(IsInGuild()) then return Fail("Guild roster unavailable: not in a guild.") end
	if not _G.GetGuildInfo or not _G.GetNumGuildMembers or not _G.GetGuildRosterInfo then
		return Fail("Guild roster API unavailable.")
	end
	local guildName = Public(GetGuildInfo("player"))
	local totalMembers = Public(GetNumGuildMembers())
	if type(guildName) ~= "string" or guildName == "" or type(totalMembers) ~= "number"
		or totalMembers < 1 or totalMembers > 10000 or totalMembers ~= math.floor(totalMembers) then
		return Fail("Guild roster is not ready.")
	end
	local guildLevel = _G.GetGuildLevel and Public(select(2, GetGuildLevel())) or 0
	local members = {}
	for i = 1, totalMembers do
		local name, rank, rankIndex, level, class, zone, note, officerNote, isOnline, status, classFileName, achievementPoints, achLevel, mobile = GetGuildRosterInfo(i)
		name, rank, rankIndex, level, class, zone = Public(name), Public(rank), Public(rankIndex), Public(level), Public(class), Public(zone)
		note, officerNote, isOnline, status, classFileName, achievementPoints = Public(note), Public(officerNote), Public(isOnline), Public(status), Public(classFileName), Public(achievementPoints)
		local charKey = type(name) == "string" and name ~= "" and RealmKey(name)
		if not charKey or members[charKey] then return Fail("Guild roster is incomplete or protected.") end
		members[charKey] = {
			name = name, rank = type(rank) == "string" and rank or "Unknown",
			rankIndex = type(rankIndex) == "number" and rankIndex or nil,
			level = type(level) == "number" and level or 0,
			class = type(class) == "string" and class or "Unknown",
			classFileName = type(classFileName) == "string" and classFileName or "UNKNOWN",
			zone = type(zone) == "string" and zone or "Unknown",
			note = type(note) == "string" and note or nil,
			officerNote = type(officerNote) == "string" and officerNote or nil,
			isOnline = isOnline == true or isOnline == 1,
			status = status, achievementPoints = achievementPoints, lastSeen = InfinityUtils:GetTimeStamp(),
		}
	end
	self.guildName, self.guildLevel, self.members, self.scanError = guildName, type(guildLevel) == "number" and guildLevel or 0, members, nil
	InfinityUtils:Info("Guild roster scanned: " .. totalMembers .. " members", "Roster")
	return true
end

function InfinityRosterManager:GetMemberInfo(memberName)
	local charKey = type(memberName) == "string" and RealmKey(memberName)
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
	local count = 0
	for _ in pairs(self.members) do count = count + 1 end
	return {
		name = self.guildName,
		level = self.guildLevel,
		totalMembers = count,
		scanTime = InfinityUtils:GetTimeStamp(),
	}
end

return InfinityRosterManager
