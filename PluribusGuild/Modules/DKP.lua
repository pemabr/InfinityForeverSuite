-- PluribusGuildDKP Module
-- Manages guild DKP distribution and synchronization

PluribusGuildDKP = {}
PluribusGuildDKP.syncHistory = {}
PluribusGuildDKP.pendingSync = {}

function PluribusGuildDKP:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGuild", "dkp", {})
	self.syncHistory = storageData.syncHistory or {}
	self.pendingSync = storageData.pendingSync or {}
	
	PluribusUtils:Info("GuildDKP module initialized", "PluribusGuild")
end

function PluribusGuildDKP:AwardDKP(memberName, dkpAmount, reason, timestamp)
	local member = PluribusGuildRoster:GetMember(memberName)
	if not member then return nil end
	
	local previousBalance = member.dkpBalance or 0
	member.dkpBalance = (member.dkpBalance or 0) + dkpAmount
	
	local record = {
		member = memberName,
		amount = dkpAmount,
		reason = reason or "Manual Award",
		timestamp = timestamp or PluribusUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	self:SaveDKPData()
	PluribusMessaging:Publish("dkp_awarded", { 
		member = memberName, 
		amount = dkpAmount,
		reason = reason 
	})
	
	PluribusUtils:Info(memberName .. " awarded " .. dkpAmount .. " DKP (" .. reason .. ")", "PluribusGuild")
	
	return record
end

function PluribusGuildDKP:SpendDKP(memberName, dkpAmount, reason, timestamp)
	local member = PluribusGuildRoster:GetMember(memberName)
	if not member then return nil end
	
	if (member.dkpBalance or 0) < dkpAmount then
		PluribusUtils:Warn(memberName .. " insufficient DKP balance", "PluribusGuild")
		return nil
	end
	
	local previousBalance = member.dkpBalance or 0
	member.dkpBalance = previousBalance - dkpAmount
	
	local record = {
		member = memberName,
		amount = -dkpAmount,
		reason = reason or "Loot Purchased",
		timestamp = timestamp or PluribusUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	self:SaveDKPData()
	PluribusMessaging:Publish("dkp_spent", { 
		member = memberName, 
		amount = dkpAmount,
		reason = reason 
	})
	
	PluribusUtils:Info(memberName .. " spent " .. dkpAmount .. " DKP (" .. reason .. ")", "PluribusGuild")
	
	return record
end

function PluribusGuildDKP:ResetMemberDKP(memberName, resetAmount, reason)
	local member = PluribusGuildRoster:GetMember(memberName)
	if not member then return nil end
	
	local previousBalance = member.dkpBalance or 0
	member.dkpBalance = resetAmount or 100
	
	local record = {
		member = memberName,
		amount = (resetAmount or 100) - previousBalance,
		reason = reason or "DKP Reset",
		timestamp = PluribusUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	self:SaveDKPData()
	PluribusMessaging:Publish("member_dkp_reset", { 
		member = memberName, 
		newBalance = member.dkpBalance 
	})
	
	return record
end

function PluribusGuildDKP:GetMemberBalance(memberName)
	local member = PluribusGuildRoster:GetMember(memberName)
	if not member then return 0 end
	
	return member.dkpBalance or 0
end

function PluribusGuildDKP:GetDKPStandings(guildName)
	local members = PluribusGuildRoster:GetGuildMembers(guildName)
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

function PluribusGuildDKP:GetDKPHistory(memberName, limit)
	limit = limit or 20
	local history = {}
	
	for i = #self.syncHistory, math.max(1, #self.syncHistory - limit + 1), -1 do
		if self.syncHistory[i].member == memberName then
			table.insert(history, self.syncHistory[i])
		end
	end
	
	return history
end

function PluribusGuildDKP:SyncDKPWithGuild()
	if #self.pendingSync == 0 then
		return true
	end
	
	-- Publish sync event with all pending changes
	PluribusMessaging:Publish("guild_dkp_sync", { 
		changes = self.pendingSync,
		timestamp = PluribusUtils:GetTimeStamp()
	})
	
	-- Clear pending after sync
	self.pendingSync = {}
	self:SaveDKPData()
	
	PluribusUtils:Info("Guild DKP synced (" .. #self.pendingSync .. " changes)", "PluribusGuild")
	
	return true
end

function PluribusGuildDKP:GetSyncStatus()
	return {
		pendingChanges = #self.pendingSync,
		historicalRecords = #self.syncHistory,
		lastSync = self.syncHistory[#self.syncHistory] and self.syncHistory[#self.syncHistory].timestamp or 0,
	}
end

function PluribusGuildDKP:SaveDKPData()
	PluribusStorageManager:SetFeatureSetting("PluribusGuild", "dkp", {
		syncHistory = self.syncHistory,
		pendingSync = self.pendingSync,
	})
	PluribusDataManager:UpdateSourceData("PluribusGuild", "dkp", {
		syncHistory = self.syncHistory,
		pendingSync = self.pendingSync,
	})
end

return PluribusGuildDKP
