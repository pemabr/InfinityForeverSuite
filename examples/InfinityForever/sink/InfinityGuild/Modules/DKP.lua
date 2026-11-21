-- InfinityGuildDKP Module
-- Manages guild DKP distribution and synchronization

InfinityGuildDKP = {}
InfinityGuildDKP.syncHistory = {}
InfinityGuildDKP.pendingSync = {}

function InfinityGuildDKP:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGuild", "dkp", {})
	self.syncHistory = storageData.syncHistory or {}
	self.pendingSync = storageData.pendingSync or {}
	
	InfinityUtils:Info("GuildDKP module initialized", "InfinityGuild")
end

function InfinityGuildDKP:AwardDKP(memberName, dkpAmount, reason, timestamp)
	local member = InfinityGuildRoster:GetMember(memberName)
	if not member then return nil end
	
	local previousBalance = member.dkpBalance or 0
	member.dkpBalance = (member.dkpBalance or 0) + dkpAmount
	
	local record = {
		member = memberName,
		amount = dkpAmount,
		reason = reason or "Manual Award",
		timestamp = timestamp or InfinityUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	self:SaveDKPData()
	InfinityMessaging:Publish("dkp_awarded", { 
		member = memberName, 
		amount = dkpAmount,
		reason = reason 
	})
	
	InfinityUtils:Info(memberName .. " awarded " .. dkpAmount .. " DKP (" .. reason .. ")", "InfinityGuild")
	
	return record
end

function InfinityGuildDKP:SpendDKP(memberName, dkpAmount, reason, timestamp)
	local member = InfinityGuildRoster:GetMember(memberName)
	if not member then return nil end
	
	if (member.dkpBalance or 0) < dkpAmount then
		InfinityUtils:Warn(memberName .. " insufficient DKP balance", "InfinityGuild")
		return nil
	end
	
	local previousBalance = member.dkpBalance or 0
	member.dkpBalance = previousBalance - dkpAmount
	
	local record = {
		member = memberName,
		amount = -dkpAmount,
		reason = reason or "Loot Purchased",
		timestamp = timestamp or InfinityUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	self:SaveDKPData()
	InfinityMessaging:Publish("dkp_spent", { 
		member = memberName, 
		amount = dkpAmount,
		reason = reason 
	})
	
	InfinityUtils:Info(memberName .. " spent " .. dkpAmount .. " DKP (" .. reason .. ")", "InfinityGuild")
	
	return record
end

function InfinityGuildDKP:ResetMemberDKP(memberName, resetAmount, reason)
	local member = InfinityGuildRoster:GetMember(memberName)
	if not member then return nil end
	
	local previousBalance = member.dkpBalance or 0
	member.dkpBalance = resetAmount or 100
	
	local record = {
		member = memberName,
		amount = (resetAmount or 100) - previousBalance,
		reason = reason or "DKP Reset",
		timestamp = InfinityUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	self:SaveDKPData()
	InfinityMessaging:Publish("member_dkp_reset", { 
		member = memberName, 
		newBalance = member.dkpBalance 
	})
	
	return record
end

function InfinityGuildDKP:GetMemberBalance(memberName)
	local member = InfinityGuildRoster:GetMember(memberName)
	if not member then return 0 end
	
	return member.dkpBalance or 0
end

function InfinityGuildDKP:GetDKPStandings(guildName)
	local members = InfinityGuildRoster:GetGuildMembers(guildName)
	local standings = {}
	
	for _, member in ipairs(members) do
		if member.active then
			table.insert(standings, {
				name = member.name,
				class = member.class,
				level = member.level,
				rank = member.rank,
				dkp = member.dkpBalance or 0,
			})
		end
	end
	
	-- Sort by DKP descending
	table.sort(standings, function(a, b) return a.dkp > b.dkp end)
	
	return standings
end

function InfinityGuildDKP:GetDKPHistory(memberName, limit)
	limit = limit or 20
	local history = {}
	
	for i = #self.syncHistory, math.max(1, #self.syncHistory - limit + 1), -1 do
		if self.syncHistory[i].member == memberName then
			table.insert(history, self.syncHistory[i])
		end
	end
	
	return history
end

function InfinityGuildDKP:SyncDKPWithGuild()
	if #self.pendingSync == 0 then
		return true
	end
	
	-- Publish sync event with all pending changes
	InfinityMessaging:Publish("guild_dkp_sync", { 
		changes = self.pendingSync,
		timestamp = InfinityUtils:GetTimeStamp()
	})
	
	-- Clear pending after sync
	self.pendingSync = {}
	self:SaveDKPData()
	
	InfinityUtils:Info("Guild DKP synced (" .. #self.pendingSync .. " changes)", "InfinityGuild")
	
	return true
end

function InfinityGuildDKP:GetSyncStatus()
	return {
		pendingChanges = #self.pendingSync,
		historicalRecords = #self.syncHistory,
		lastSync = self.syncHistory[#self.syncHistory] and self.syncHistory[#self.syncHistory].timestamp or 0,
	}
end

function InfinityGuildDKP:SaveDKPData()
	InfinityStorageManager:SetFeatureSetting("InfinityGuild", "dkp", {
		syncHistory = self.syncHistory,
		pendingSync = self.pendingSync,
	})
	InfinityDataManager:UpdateSourceData("InfinityGuild", "dkp", {
		syncHistory = self.syncHistory,
		pendingSync = self.pendingSync,
	})
end

return InfinityGuildDKP
