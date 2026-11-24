-- DKP Taxation & Donation System
-- Award DKP for taxes and donations to guild bank

local PluribusDKPTaxation = {}
_G.PluribusDKPTaxation = PluribusDKPTaxation

PluribusDKPTaxation.config = {
	enableTaxation = true,
	taxRatePerGold = 0.01, -- DKP per 1 gold
	enableDonations = true,
	donationRatePerGold = 0.015, -- DKP per 1 gold
	enableWhitelist = false,
	enableBlacklist = false,
}

PluribusDKPTaxation.whitelistedItems = {} -- Items that count toward taxes
PluribusDKPTaxation.blacklistedItems = {} -- Items that don't count toward taxes
PluribusDKPTaxation.taxHistory = {} -- {player, gold, dkp, timestamp, type}
PluribusDKPTaxation.maxHistorySize = 5000

function PluribusDKPTaxation:Initialize()
	local settings = PluribusStorageManager:GetFeatureSettings("taxation") or {}
	self.config = settings.config or self.config
	self.whitelistedItems = settings.whitelistedItems or {}
	self.blacklistedItems = settings.blacklistedItems or {}
	self.taxHistory = settings.taxHistory or {}
	PluribusUtils:Info("DKP Taxation system initialized", "Taxation")
end

function PluribusDKPTaxation:AwardForTax(playerName, goldAmount, reason)
	if not self.config.enableTaxation then
		return false
	end
	
	local dkpAmount = math.floor(goldAmount * self.config.taxRatePerGold)
	
	if dkpAmount > 0 then
		PluribusLootEPGP:AwardGP(playerName, dkpAmount, "tax:" .. reason)
		self:_LogTaxation(playerName, goldAmount, dkpAmount, "tax", reason)
		PluribusMessaging:Publish("dkp_tax_awarded", playerName, goldAmount, dkpAmount)
		return true
	end
	
	return false
end

function PluribusDKPTaxation:AwardForDonation(playerName, goldAmount, itemName, reason)
	if not self.config.enableDonations then
		return false
	end
	
	-- Check item filtering
	if self.config.enableBlacklist and self:IsBlacklisted(itemName) then
		PluribusUtils:Warning("Item " .. itemName .. " is blacklisted", "Taxation")
		return false
	end
	
	if self.config.enableWhitelist and not self:IsWhitelisted(itemName) then
		PluribusUtils:Warning("Item " .. itemName .. " is not whitelisted", "Taxation")
		return false
	end
	
	local dkpAmount = math.floor(goldAmount * self.config.donationRatePerGold)
	
	if dkpAmount > 0 then
		PluribusLootEPGP:AwardGP(playerName, dkpAmount, "donation:" .. (itemName or "gold"))
		self:_LogTaxation(playerName, goldAmount, dkpAmount, "donation", reason)
		PluribusMessaging:Publish("dkp_donation_awarded", playerName, goldAmount, dkpAmount, itemName)
		return true
	end
	
	return false
end

function PluribusDKPTaxation:SetTaxRate(ratePerGold)
	self.config.taxRatePerGold = ratePerGold
	PluribusUtils:Info("Tax rate set to " .. ratePerGold .. " DKP per gold", "Taxation")
	self:_SaveSettings()
end

function PluribusDKPTaxation:SetDonationRate(ratePerGold)
	self.config.donationRatePerGold = ratePerGold
	PluribusUtils:Info("Donation rate set to " .. ratePerGold .. " DKP per gold", "Taxation")
	self:_SaveSettings()
end

function PluribusDKPTaxation:Whitelist(itemName)
	if not self.whitelistedItems[itemName] then
		self.whitelistedItems[itemName] = true
		self:_SaveSettings()
		return true
	end
	return false
end

function PluribusDKPTaxation:Blacklist(itemName)
	if not self.blacklistedItems[itemName] then
		self.blacklistedItems[itemName] = true
		self:_SaveSettings()
		return true
	end
	return false
end

function PluribusDKPTaxation:RemoveWhitelist(itemName)
	if self.whitelistedItems[itemName] then
		self.whitelistedItems[itemName] = nil
		self:_SaveSettings()
		return true
	end
	return false
end

function PluribusDKPTaxation:RemoveBlacklist(itemName)
	if self.blacklistedItems[itemName] then
		self.blacklistedItems[itemName] = nil
		self:_SaveSettings()
		return true
	end
	return false
end

function PluribusDKPTaxation:IsWhitelisted(itemName)
	return self.whitelistedItems[itemName] or false
end

function PluribusDKPTaxation:IsBlacklisted(itemName)
	return self.blacklistedItems[itemName] or false
end

function PluribusDKPTaxation:GetTaxHistory(playerName)
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

function PluribusDKPTaxation:GetTotalTaxed(playerName)
	local total = 0
	for _, entry in ipairs(self.taxHistory) do
		if entry.player == playerName and entry.type == "tax" then
			total = total + entry.dkp
		end
	end
	return total
end

function PluribusDKPTaxation:GetTotalDonated(playerName)
	local total = 0
	for _, entry in ipairs(self.taxHistory) do
		if entry.player == playerName and entry.type == "donation" then
			total = total + entry.dkp
		end
	end
	return total
end

function PluribusDKPTaxation:_LogTaxation(playerName, goldAmount, dkpAmount, type, reason)
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

function PluribusDKPTaxation:_SaveSettings()
	PluribusStorageManager:SetFeatureSettings("taxation", {
		config = self.config,
		whitelistedItems = self.whitelistedItems,
		blacklistedItems = self.blacklistedItems,
		taxHistory = self.taxHistory,
	})
end

return PluribusDKPTaxation
