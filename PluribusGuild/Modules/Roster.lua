-- PluribusGuildRoster Module
-- Manages guild member data, tracking, and synchronization

PluribusGuildRoster = {}
PluribusGuildRoster.members = {}
PluribusGuildRoster.guilds = {}

function PluribusGuildRoster:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGuild", "roster", {})
	self.members = storageData.members or {}
	self.guilds = storageData.guilds or {}
	
	PluribusUtils:Info("GuildRoster module initialized", "PluribusGuild")
end

function PluribusGuildRoster:RegisterGuild(guildName, guildTag, guildLevel)
	if not guildName then return end
	
	local guild = {
		name = guildName,
		tag = guildTag or "GUILD",
		level = guildLevel or 1,
		memberCount = 0,
		created = PluribusUtils:GetTimeStamp(),
		roster = {},
		treasury = 0,
	}
	
	self.guilds[guildName] = guild
	self:SaveRoster()
	PluribusMessaging:Publish("guild_registered", { guild = guildName })
	PluribusUtils:Info("Registered guild: " .. guildName, "PluribusGuild")
	
	return guild
end

function PluribusGuildRoster:AddMember(guildName, memberName, rank, class, level, joinDate)
	if not self.guilds[guildName] then
		return nil
	end
	
	local member = {
		name = memberName,
		class = class or "UNKNOWN",
		level = level or 1,
		rank = rank or "Member",
		joinDate = joinDate or PluribusUtils:GetTimeStamp(),
		dkpBalance = 0,
		epBalance = 0,
		gpBalance = 0,
		notes = "",
		active = true,
	}
	
	self.members[memberName] = member
	self.guilds[guildName].roster[memberName] = true
	self.guilds[guildName].memberCount = (self.guilds[guildName].memberCount or 0) + 1
	
	self:SaveRoster()
	PluribusMessaging:Publish("member_joined", { 
		guild = guildName, 
		member = memberName,
		rank = rank,
		class = class 
	})
	
	return member
end

function PluribusGuildRoster:RemoveMember(guildName, memberName)
	if not self.members[memberName] then return end
	
	self.members[memberName] = nil
	if self.guilds[guildName] and self.guilds[guildName].roster then
		self.guilds[guildName].roster[memberName] = nil
		self.guilds[guildName].memberCount = (self.guilds[guildName].memberCount or 1) - 1
	end
	
	self:SaveRoster()
	PluribusMessaging:Publish("member_left", { guild = guildName, member = memberName })
	
	return true
end

function PluribusGuildRoster:UpdateMemberRank(memberName, newRank)
	if not self.members[memberName] then return nil end
	
	self.members[memberName].rank = newRank
	self:SaveRoster()
	PluribusMessaging:Publish("member_promoted", { member = memberName, rank = newRank })
	
	return self.members[memberName]
end

function PluribusGuildRoster:GetGuildMembers(guildName)
	if not self.guilds[guildName] then return {} end
	
	local members = {}
	for memberName, _ in pairs(self.guilds[guildName].roster) do
		if self.members[memberName] then
			table.insert(members, self.members[memberName])
		end
	end
	
	return members
end

function PluribusGuildRoster:GetMember(memberName)
	return self.members[memberName]
end

function PluribusGuildRoster:GetGuild(guildName)
	return self.guilds[guildName]
end

function PluribusGuildRoster:GetMemberStats(memberName)
	local member = self.members[memberName]
	if not member then return nil end
	
	return {
		name = member.name,
		class = member.class,
		level = member.level,
		rank = member.rank,
		joinedDaysAgo = math.floor((PluribusUtils:GetTimeStamp() - member.joinDate) / 86400),
		dkpBalance = member.dkpBalance,
		epBalance = member.epBalance,
		gpBalance = member.gpBalance,
		active = member.active,
	}
end

function PluribusGuildRoster:SetMemberNotes(memberName, notes)
	if not self.members[memberName] then return nil end
	
	self.members[memberName].notes = notes
	self:SaveRoster()
	
	return self.members[memberName]
end

function PluribusGuildRoster:GetGuildStats(guildName)
	local guild = self.guilds[guildName]
	if not guild then return nil end
	
	local totalDKP = 0
	local activeCount = 0
	local totalLevel = 0
	
	for memberName, _ in pairs(guild.roster) do
		local member = self.members[memberName]
		if member then
			totalDKP = totalDKP + (member.dkpBalance or 0)
			totalLevel = totalLevel + (member.level or 1)
			if member.active then activeCount = activeCount + 1 end
		end
	end
	
	return {
		name = guild.name,
		level = guild.level,
		memberCount = guild.memberCount or 0,
		activeMembers = activeCount,
		averageLevel = guild.memberCount > 0 and (totalLevel / guild.memberCount) or 0,
		totalDKPOutstanding = totalDKP,
		treasury = guild.treasury or 0,
	}
end

function PluribusGuildRoster:SaveRoster()
	PluribusStorageManager:SetFeatureSetting("PluribusGuild", "roster", {
		members = self.members,
		guilds = self.guilds,
	})
	PluribusDataManager:UpdateSourceData("PluribusGuild", "roster", {
		members = self.members,
		guilds = self.guilds,
	})
end

return PluribusGuildRoster
