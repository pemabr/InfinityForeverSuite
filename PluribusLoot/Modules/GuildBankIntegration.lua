-- Guild Bank Integration
-- Tracks guild bank activity and integrates with DKP system

local GuildBankIntegration = {
	bankData = {
		tabs = {}, -- {tabNumber = {items}}
		lastScan = 0,
		contents = {}, -- {itemId = {quantity, tab, slot}}
	},
	
	config = {
		trackWithdrawals = true,
		trackDeposits = true,
		grantDKPForDeposits = true,
		dkpPerGold = 0.001, -- 1000 gold = 1 DKP
		dkpPerAHValue = 0.001,
	},
	
	auditLog = {}, -- {timestamp = {action, player, item, quantity}}
}

_G.PluribusGuildBankIntegration = GuildBankIntegration

-- Initialize guild bank tracking
function GuildBankIntegration:Initialize()
	PluribusUtils:Info("Guild bank integration initialized", "Guild")
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("GUILDBANKLOG_UPDATE")
	frame:RegisterEvent("GUILDBANK_UPDATE_TABS")
	frame:RegisterEvent("GUILDBANK_UPDATE_MONEY")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if event == "GUILDBANKLOG_UPDATE" then
			GuildBankIntegration:OnBankLogUpdate()
		elseif event == "GUILDBANK_UPDATE_TABS" or event == "GUILDBANK_UPDATE_MONEY" then
			GuildBankIntegration:OnBankUpdate()
		end
	end)
	
	-- Subscribe to DKP donation events
	PluribusMessaging:Subscribe("dkp_donation", function(player, amount, item)
		GuildBankIntegration:OnDKPDonation(player, amount, item)
	end)
end

-- Called when guild bank log updates
function GuildBankIntegration:OnBankLogUpdate()
	local numLogs = GetNumGuildBankLogs()
	
	for i = 1, numLogs do
		local player, operation, day, hour, itemLink, quantity, itemValue, money = GetGuildBankLog(i)
		
		if player then
			local logEntry = {
				timestamp = GetServerTime(),
				player = player,
				operation = operation, -- DEPOSIT, WITHDRAWAL, REPAIR
				item = itemLink,
				quantity = quantity or 0,
				itemValue = itemValue or 0,
				money = money or 0,
			}
			
			table.insert(self.auditLog, logEntry)
			
			if operation == "WITHDRAWAL" and self.config.trackWithdrawals then
				self:OnWithdrawal(player, itemLink, quantity, itemValue)
			elseif operation == "DEPOSIT" and self.config.trackDeposits then
				self:OnDeposit(player, itemLink, quantity, itemValue)
			end
		end
	end
end

-- Called when guild bank is updated
function GuildBankIntegration:OnBankUpdate()
	-- Rescan bank contents
	local numTabs = GetNumGuildBankTabs()
	
	for tab = 1, numTabs do
		for slot = 1, 98 do
			local texture, itemCount, locked = GetGuildBankTabInfo(tab, slot)
			local itemLink = GetGuildBankItemLink(tab, slot)
			
			if itemLink then
				local itemId = tonumber(string.match(itemLink, "item:(%d+):"))
				
				if not self.bankData.contents[itemId] then
					self.bankData.contents[itemId] = {
						quantity = 0,
						tabs = {},
					}
				end
				
				self.bankData.contents[itemId].quantity = self.bankData.contents[itemId].quantity + itemCount
				self.bankData.contents[itemId].tabs[tab] = (self.bankData.contents[itemId].tabs[tab] or 0) + itemCount
			end
		end
	end
	
	self.bankData.lastScan = GetTime()
end

-- Called on item withdrawal
function GuildBankIntegration:OnWithdrawal(player, itemLink, quantity, itemValue)
	PluribusUtils:Info(player .. " withdrew " .. (itemLink or "item") .. " x" .. (quantity or 1), "Guild")
	
	-- Could log withdrawal
	PluribusMessaging:Publish("guild_bank_withdrawal", player, itemLink, quantity, itemValue)
end

-- Called on item deposit
function GuildBankIntegration:OnDeposit(player, itemLink, quantity, itemValue)
	PluribusUtils:Info(player .. " deposited " .. (itemLink or "item") .. " x" .. (quantity or 1), "Guild")
	
	-- Award DKP if enabled
	if self.config.grantDKPForDeposits then
		local dkpAmount = self:CalculateDKPForDeposit(itemValue, quantity)
		
		if dkpAmount > 0 then
			PluribusMessaging:Publish("dkp_donation", player, dkpAmount, itemLink)
			PluribusUtils:Info("Awarded " .. dkpAmount .. " DKP to " .. player .. " for deposit", "Guild")
		end
	end
	
	PluribusMessaging:Publish("guild_bank_deposit", player, itemLink, quantity, itemValue)
end

-- Called on DKP donation
function GuildBankIntegration:OnDKPDonation(player, amount, item)
	-- Log the donation
	local entry = {
		timestamp = GetServerTime(),
		player = player,
		dkpAmount = amount,
		item = item,
		source = "guild_bank",
	}
	
	table.insert(self.auditLog, entry)
end

-- Calculate DKP for deposit
function GuildBankIntegration:CalculateDKPForDeposit(value, quantity)
	if not value or value == 0 then
		return 0
	end
	
	-- Use auction house value if available, else vendor value
	local ahValue = value * (quantity or 1)
	
	-- Calculate DKP (use auction house value)
	local dkpAmount = ahValue * self.config.dkpPerAHValue
	
	return math.floor(dkpAmount)
end

-- Get bank contents summary
function GuildBankIntegration:GetBankContents()
	return self.bankData.contents
end

-- Get bank activity log
function GuildBankIntegration:GetActivityLog(timeframe)
	timeframe = timeframe or 86400 -- Default 1 day
	local cutoffTime = GetServerTime() - timeframe
	
	local log = {}
	
	for _, entry in ipairs(self.auditLog) do
		if entry.timestamp > cutoffTime then
			table.insert(log, entry)
		end
	end
	
	return log
end

-- Get top contributors
function GuildBankIntegration:GetTopContributors(count, timeframe)
	count = count or 10
	timeframe = timeframe or 86400
	
	local contributors = {}
	local cutoffTime = GetServerTime() - timeframe
	
	for _, entry in ipairs(self.auditLog) do
		if entry.timestamp > cutoffTime and entry.operation == "DEPOSIT" then
			if not contributors[entry.player] then
				contributors[entry.player] = {
					depositsCount = 0,
					totalValue = 0,
				}
			end
			
			contributors[entry.player].depositsCount = contributors[entry.player].depositsCount + 1
			contributors[entry.player].totalValue = contributors[entry.player].totalValue + (entry.itemValue or 0)
		end
	end
	
	-- Convert to array and sort
	local sorted = {}
	for player, stats in pairs(contributors) do
		table.insert(sorted, {
			player = player,
			depositsCount = stats.depositsCount,
			totalValue = stats.totalValue,
		})
	end
	
	table.sort(sorted, function(a, b)
		return a.totalValue > b.totalValue
	end)
	
	-- Return top N
	local result = {}
	for i = 1, math.min(count, #sorted) do
		result[i] = sorted[i]
	end
	
	return result
end

-- Display guild bank status
function GuildBankIntegration:DisplayStatus()
	print("|cffffd700=== GUILD BANK STATUS ===|r")
	print("Grant DKP for Deposits: " .. (self.config.grantDKPForDeposits and "YES" or "NO"))
	print("DKP Per Gold: " .. self.config.dkpPerGold)
	print("DKP Per AH Value: " .. self.config.dkpPerAHValue)
	print("Total Audit Entries: " .. #self.auditLog)
	
	local topContributors = self:GetTopContributors(5, 604800) -- Last 7 days
	
	if #topContributors > 0 then
		print("\n|cffccccccTop Contributors (Last 7 Days):|r")
		for i, contrib in ipairs(topContributors) do
			print(string.format("  %d. %s: %d deposits (%.1fK gold value)", i, contrib.player, contrib.depositsCount, contrib.totalValue / 1000))
		end
	end
end

-- Set configuration
function GuildBankIntegration:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		PluribusUtils:Info("Guild bank config updated: " .. key .. " = " .. tostring(value), "Guild")
	end
end

return GuildBankIntegration
