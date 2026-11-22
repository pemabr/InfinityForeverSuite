-- InfinityGuildRoster Module
-- Manages guild member data, tracking, and synchronization

InfinityGuildRoster = {}
InfinityGuildRoster.members = {}
InfinityGuildRoster.guilds = {}

function InfinityGuildRoster:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGuild", "roster", {})
	self.members = storageData.members or {}
	self.guilds = storageData.guilds or {}
	
	if not self.eventFrame then
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame:RegisterEvent("PLAYER_LOGIN")
		self.eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
		self.eventFrame:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_LOGIN" then
				InfinityGuildRoster:RequestRoster()
			elseif InfinityGuildRoster:ScanGuildRoster() then
				local window = _G.InfinityGuildWindow
				if window and window:IsShown() and window.currentTab == "roster" and _G.InfinityGuildUI then
					_G.InfinityGuildUI:ShowTab(window, "roster")
				end
			end
		end)
	end
	self:ScanGuildRoster()

	InfinityUtils:Info("GuildRoster module initialized", "InfinityGuild")
end

function InfinityGuildRoster:RequestRoster()
	if not IsInGuild or not IsInGuild() then
		return false
	end
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	elseif GuildRoster then
		GuildRoster()
	else
		InfinityUtils:Warning("Guild roster request is unavailable", "InfinityGuild")
		return false
	end
	return true
end

function InfinityGuildRoster:RegisterGuild(guildName, guildTag, guildLevel)
	if not guildName then return end
	
	local guild = {
		name = guildName,
		tag = guildTag or "GUILD",
		level = guildLevel or 1,
		memberCount = 0,
		created = InfinityUtils:GetTimeStamp(),
		roster = {},
		treasury = 0,
	}
	
	self.guilds[guildName] = guild
	self:SaveRoster()
	InfinityMessaging:Publish("guild_registered", { guild = guildName })
	InfinityUtils:Info("Registered guild: " .. guildName, "InfinityGuild")
	
	return guild
end

function InfinityGuildRoster:AddMember(guildName, memberName, rank, class, level, joinDate)
	if not self.guilds[guildName] then
		return nil
	end
	
	local member = {
		name = memberName,
		class = class or "UNKNOWN",
		level = level or 1,
		rank = rank or "Member",
		joinDate = joinDate or InfinityUtils:GetTimeStamp(),
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
	InfinityMessaging:Publish("member_joined", { 
		guild = guildName, 
		member = memberName,
		rank = rank,
		class = class 
	})
	
	return member
end

function InfinityGuildRoster:RemoveMember(guildName, memberName)
	if not self.members[memberName] then return end
	
	self.members[memberName] = nil
	if self.guilds[guildName] and self.guilds[guildName].roster then
		self.guilds[guildName].roster[memberName] = nil
		self.guilds[guildName].memberCount = (self.guilds[guildName].memberCount or 1) - 1
	end
	
	self:SaveRoster()
	InfinityMessaging:Publish("member_left", { guild = guildName, member = memberName })
	
	return true
end

function InfinityGuildRoster:UpdateMemberRank(memberName, newRank)
	if not self.members[memberName] then return nil end
	
	self.members[memberName].rank = newRank
	self:SaveRoster()
	InfinityMessaging:Publish("member_promoted", { member = memberName, rank = newRank })
	
	return self.members[memberName]
end

function InfinityGuildRoster:GetGuildMembers(guildName)
	if not self.guilds[guildName] then return {} end
	
	local members = {}
	for memberName, _ in pairs(self.guilds[guildName].roster) do
		if self.members[memberName] then
			table.insert(members, self.members[memberName])
		end
	end
	
	return members
end

function InfinityGuildRoster:GetMember(memberName)
	return self.members[memberName]
end

function InfinityGuildRoster:GetGuild(guildName)
	return self.guilds[guildName]
end

function InfinityGuildRoster:GetMemberStats(memberName)
	local member = self.members[memberName]
	if not member then return nil end
	
	return {
		name = member.name,
		class = member.class,
		level = member.level,
		rank = member.rank,
		joinedDaysAgo = math.floor((InfinityUtils:GetTimeStamp() - member.joinDate) / 86400),
		dkpBalance = member.dkpBalance,
		epBalance = member.epBalance,
		gpBalance = member.gpBalance,
		active = member.active,
	}
end

function InfinityGuildRoster:SetMemberNotes(memberName, notes)
	if not self.members[memberName] then return nil end
	
	self.members[memberName].notes = notes
	self:SaveRoster()
	
	return self.members[memberName]
end

function InfinityGuildRoster:GetGuildStats(guildName)
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

function InfinityGuildRoster:SaveRoster()
	InfinityStorageManager:SetFeatureSetting("InfinityGuild", "roster", {
		members = self.members,
		guilds = self.guilds,
	})
	InfinityDataManager:UpdateSourceData("InfinityGuild", "roster", {
		members = self.members,
		guilds = self.guilds,
	})
end

function InfinityGuildRoster:ScanGuildRoster()
	if not IsInGuild or not IsInGuild() then
		return false
	end
	local guildName = GetGuildInfo("player")
	if not guildName or guildName == "" then
		return false
	end
	if not self.guilds[guildName] then
		self.guilds[guildName] = {
			name = guildName,
			tag = guildName:sub(1, 4):upper(),
			level = 1,
			memberCount = 0,
			created = InfinityUtils:GetTimeStamp(),
			roster = {},
			treasury = 0,
		}
	end
	local guild = self.guilds[guildName]
	guild.roster = guild.roster or {}
	local total = GetNumGuildMembers and GetNumGuildMembers() or 0
	local count = 0
	local roster = {}
	for i = 1, total do
		local name, rank, rankIndex, level, _, _, _, _, online, _, classFile = GetGuildRosterInfo(i)
		if name then
			count = count + 1
			local shortName = name:match("^([^%-]+)") or name
			local existing = self.members[shortName] or {}
			self.members[shortName] = {
				name = shortName,
				fullName = name,
				class = classFile or existing.class or "UNKNOWN",
				level = level or existing.level or 1,
				rank = rank or (rankIndex == 0 and "Guild Master" or "Member"),
				rankIndex = rankIndex,
				joinDate = existing.joinDate or InfinityUtils:GetTimeStamp(),
				dkpBalance = existing.dkpBalance or 0,
				epBalance = existing.epBalance or 0,
				gpBalance = existing.gpBalance or 0,
				notes = existing.notes or "",
				active = online == true,
			}
			roster[shortName] = true
		end
	end
	if count > 0 then
		guild.roster = roster
		guild.memberCount = count
		self:SaveRoster()
	end
	return count > 0
end

return InfinityGuildRoster
