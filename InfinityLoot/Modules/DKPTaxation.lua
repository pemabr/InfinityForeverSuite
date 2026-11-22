-- DKP Taxation & Donation System
-- Award DKP for taxes and donations to guild bank

local InfinityDKPTaxation = {}
_G.InfinityDKPTaxation = InfinityDKPTaxation

InfinityDKPTaxation.config = {
	enableTaxation = true,
	taxRatePerGold = 0.01, -- DKP per 1 gold
	enableDonations = true,
	donationRatePerGold = 0.015, -- DKP per 1 gold
	enableWhitelist = false,
	enableBlacklist = false,
}

InfinityDKPTaxation.whitelistedItems = {} -- Items that count toward taxes
InfinityDKPTaxation.blacklistedItems = {} -- Items that don't count toward taxes
InfinityDKPTaxation.taxHistory = {} -- {player, gold, dkp, timestamp, type}
InfinityDKPTaxation.maxHistorySize = 5000

function InfinityDKPTaxation:Initialize()
	local settings = InfinityStorageManager:GetFeatureSettings("taxation") or {}
	self.config = settings.config or self.config
	self.whitelistedItems = settings.whitelistedItems or {}
	self.blacklistedItems = settings.blacklistedItems or {}
	self.taxHistory = settings.taxHistory or {}
	InfinityUtils:Info("DKP Taxation system initialized", "Taxation")
end

function InfinityDKPTaxation:AwardForTax(playerName, goldAmount, reason)
	if not self.config.enableTaxation then
		return false
	end
	
	local dkpAmount = math.floor(goldAmount * self.config.taxRatePerGold)
	
	if dkpAmount > 0 then
		InfinityLootEPGP:AwardGP(playerName, dkpAmount, "tax:" .. reason)
		self:_LogTaxation(playerName, goldAmount, dkpAmount, "tax", reason)
		InfinityMessaging:Publish("dkp_tax_awarded", playerName, goldAmount, dkpAmount)
		return true
	end
	
	return false
end

function InfinityDKPTaxation:AwardForDonation(playerName, goldAmount, itemName, reason)
	if not self.config.enableDonations then
		return false
	end
	
	-- Check item filtering
	if self.config.enableBlacklist and self:IsBlacklisted(itemName) then
		InfinityUtils:Warning("Item " .. itemName .. " is blacklisted", "Taxation")
		return false
	end
	
	if self.config.enableWhitelist and not self:IsWhitelisted(itemName) then
		InfinityUtils:Warning("Item " .. itemName .. " is not whitelisted", "Taxation")
		return false
	end
	
	local dkpAmount = math.floor(goldAmount * self.config.donationRatePerGold)
	
	if dkpAmount > 0 then
		InfinityLootEPGP:AwardGP(playerName, dkpAmount, "donation:" .. (itemName or "gold"))
		self:_LogTaxation(playerName, goldAmount, dkpAmount, "donation", reason)
		InfinityMessaging:Publish("dkp_donation_awarded", playerName, goldAmount, dkpAmount, itemName)
		return true
	end
	
	return false
end

function InfinityDKPTaxation:SetTaxRate(ratePerGold)
	self.config.taxRatePerGold = ratePerGold
	InfinityUtils:Info("Tax rate set to " .. ratePerGold .. " DKP per gold", "Taxation")
	self:_SaveSettings()
end

function InfinityDKPTaxation:SetDonationRate(ratePerGold)
	self.config.donationRatePerGold = ratePerGold
	InfinityUtils:Info("Donation rate set to " .. ratePerGold .. " DKP per gold", "Taxation")
	self:_SaveSettings()
end

function InfinityDKPTaxation:Whitelist(itemName)
	if not self.whitelistedItems[itemName] then
		self.whitelistedItems[itemName] = true
		self:_SaveSettings()
		return true
	end
	return false
end

function InfinityDKPTaxation:Blacklist(itemName)
	if not self.blacklistedItems[itemName] then
		self.blacklistedItems[itemName] = true
		self:_SaveSettings()
		return true
	end
	return false
end

function InfinityDKPTaxation:RemoveWhitelist(itemName)
	if self.whitelistedItems[itemName] then
		self.whitelistedItems[itemName] = nil
		self:_SaveSettings()
		return true
	end
	return false
end

function InfinityDKPTaxation:RemoveBlacklist(itemName)
	if self.blacklistedItems[itemName] then
		self.blacklistedItems[itemName] = nil
		self:_SaveSettings()
		return true
	end
	return false
end

function InfinityDKPTaxation:IsWhitelisted(itemName)
	return self.whitelistedItems[itemName] or false
end

function InfinityDKPTaxation:IsBlacklisted(itemName)
	return self.blacklistedItems[itemName] or false
end

function InfinityDKPTaxation:GetTaxHistory(playerName)
	if not playerName then
		return self.taxHistory
	end
	
	local history = {}
	for _, entry in ipairs(self.taxHistory) do
		if entry.player == playerName then
			table.insert(history, entry)
		end
	end
	return history
end

function InfinityDKPTaxation:GetTotalTaxed(playerName)
	local total = 0
	for _, entry in ipairs(self.taxHistory) do
		if entry.player == playerName and entry.type == "tax" then
			total = total + entry.dkp
		end
	end
	return total
end

function InfinityDKPTaxation:GetTotalDonated(playerName)
	local total = 0
	for _, entry in ipairs(self.taxHistory) do
		if entry.player == playerName and entry.type == "donation" then
			total = total + entry.dkp
		end
	end
	return total
end

function InfinityDKPTaxation:_LogTaxation(playerName, goldAmount, dkpAmount, type, reason)
	table.insert(self.taxHistory, {
		player = playerName,
		gold = goldAmount,
		dkp = dkpAmount,
		timestamp = GetTime(),
		type = type,
		reason = reason,
	})
	
	if #self.taxHistory > self.maxHistorySize then
		table.remove(self.taxHistory, 1)
	end
end

function InfinityDKPTaxation:_SaveSettings()
	InfinityStorageManager:SetFeatureSettings("taxation", {
		config = self.config,
		whitelistedItems = self.whitelistedItems,
		blacklistedItems = self.blacklistedItems,
		taxHistory = self.taxHistory,
	})
end

return InfinityDKPTaxation
