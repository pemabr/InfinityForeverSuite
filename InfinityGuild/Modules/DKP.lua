-- InfinityGuildDKP Module
-- Manages guild DKP distribution and synchronization

InfinityGuildDKP = {}
InfinityGuildDKP.syncHistory = {}
InfinityGuildDKP.pendingSync = {}

local function Inputs(memberName, amount, reason, defaultReason, allowZero)
	if _G.issecretvalue and (issecretvalue(memberName) or issecretvalue(amount) or issecretvalue(reason)) then
		InfinityUtils:Warning("Protected local DKP input.", "InfinityGuild")
		return nil
	end
	if type(memberName) ~= "string" or memberName == "" or type(amount) ~= "number"
		or amount ~= amount or amount < (allowZero and 0 or 1) or amount > 1000000000
		or amount ~= math.floor(amount) or (reason ~= nil and type(reason) ~= "string") then
		InfinityUtils:Warning("Enter a player and a valid whole DKP amount.", "InfinityGuild")
		return nil
	end
	local member = InfinityGuildRoster:GetMember(memberName)
	if _G.issecretvalue and issecretvalue(member) then member = nil end
	if type(member) ~= "table" then
		InfinityUtils:Warning("Local guild member not found.", "InfinityGuild")
		return nil
	end
	local balance = member.dkpBalance
	if _G.issecretvalue and issecretvalue(balance) then
		InfinityUtils:Warning("Local DKP balance is protected.", "InfinityGuild")
		return nil
	end
	if balance == nil then balance = 0 end
	if type(balance) ~= "number" or balance ~= balance or math.abs(balance) > 1000000000 then
		InfinityUtils:Warning("Invalid local DKP balance.", "InfinityGuild")
		return nil
	end
	return member, balance, reason or defaultReason
end

function InfinityGuildDKP:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGuild", "dkp", {})
	self.syncHistory = storageData.syncHistory or {}
	self.pendingSync = storageData.pendingSync or {}
	
	InfinityUtils:Info("GuildDKP module initialized", "InfinityGuild")
end

function InfinityGuildDKP:AwardDKP(memberName, dkpAmount, reason, timestamp)
	if (_G.issecretvalue and issecretvalue(timestamp)) or (timestamp ~= nil and
		(type(timestamp) ~= "number" or timestamp ~= timestamp or timestamp < 0 or timestamp >= math.huge)) then
		InfinityUtils:Warning("Invalid local DKP timestamp.", "InfinityGuild"); return nil
	end
	local member, previousBalance, normalizedReason = Inputs(memberName, dkpAmount, reason, "Manual Award")
	if not member then return nil end
	if previousBalance + dkpAmount > 1000000000 then
		InfinityUtils:Warning("Local DKP balance exceeds its limit.", "InfinityGuild"); return nil
	end
	member.dkpBalance = previousBalance + dkpAmount
	
	local record = {
		member = memberName,
		amount = dkpAmount,
		reason = normalizedReason,
		timestamp = timestamp or InfinityUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	InfinityGuildRoster:SaveRoster()
	self:SaveDKPData()
	InfinityMessaging:Publish("dkp_awarded", { 
		member = memberName, 
		amount = dkpAmount,
		reason = normalizedReason
	})
	
	InfinityUtils:Info(memberName .. " awarded " .. dkpAmount .. " DKP (" .. normalizedReason .. ")", "InfinityGuild")
	
	return record
end

function InfinityGuildDKP:SpendDKP(memberName, dkpAmount, reason, timestamp)
	if (_G.issecretvalue and issecretvalue(timestamp)) or (timestamp ~= nil and
		(type(timestamp) ~= "number" or timestamp ~= timestamp or timestamp < 0 or timestamp >= math.huge)) then
		InfinityUtils:Warning("Invalid local DKP timestamp.", "InfinityGuild"); return nil
	end
	local member, previousBalance, normalizedReason = Inputs(memberName, dkpAmount, reason, "Loot Purchased")
	if not member then return nil end
	
	if previousBalance < dkpAmount then
		InfinityUtils:Warning(memberName .. " insufficient DKP balance", "InfinityGuild")
		return nil
	end
	
	member.dkpBalance = previousBalance - dkpAmount
	
	local record = {
		member = memberName,
		amount = -dkpAmount,
		reason = normalizedReason,
		timestamp = timestamp or InfinityUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	InfinityGuildRoster:SaveRoster()
	self:SaveDKPData()
	InfinityMessaging:Publish("dkp_spent", { 
		member = memberName, 
		amount = dkpAmount,
		reason = normalizedReason
	})
	
	InfinityUtils:Info(memberName .. " spent " .. dkpAmount .. " DKP (" .. normalizedReason .. ")", "InfinityGuild")
	
	return record
end

function InfinityGuildDKP:ResetMemberDKP(memberName, resetAmount, reason)
	if _G.issecretvalue and issecretvalue(resetAmount) then
		InfinityUtils:Warning("Protected local DKP input.", "InfinityGuild"); return nil
	end
	if resetAmount == nil then resetAmount = 100 end
	local member, previousBalance, normalizedReason = Inputs(memberName, resetAmount, reason, "DKP Reset", true)
	if not member then return nil end
	
	member.dkpBalance = resetAmount
	
	local record = {
		member = memberName,
		amount = resetAmount - previousBalance,
		reason = normalizedReason,
		timestamp = InfinityUtils:GetTimeStamp(),
		previousBalance = previousBalance,
		newBalance = member.dkpBalance,
	}
	
	table.insert(self.syncHistory, record)
	table.insert(self.pendingSync, record)
	
	InfinityGuildRoster:SaveRoster()
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
	
	if limit <= 0 then return history end
	for i = #self.syncHistory, 1, -1 do
		if self.syncHistory[i].member == memberName then
			table.insert(history, self.syncHistory[i])
			if #history >= limit then break end
		end
	end
	
	return history
end

function InfinityGuildDKP:SyncDKPWithGuild()
	InfinityUtils:Warning("These local guild balances cannot be synchronized. Use InfinityDKP guild snapshots separately.", "InfinityGuild")
	return false
end

function InfinityGuildDKP:GetSyncStatus()
	return {
		pendingChanges = #self.pendingSync,
		historicalRecords = #self.syncHistory,
		lastSync = nil,
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
