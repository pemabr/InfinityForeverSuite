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
		InfinityUtils:Warning("Tax awards are disabled.", "Taxation")
		return false
	end
	return self:_Award(playerName, goldAmount, self.config.taxRatePerGold, "tax", reason)
end

function InfinityDKPTaxation:AwardForDonation(playerName, goldAmount, itemName, reason)
	if not self.config.enableDonations then
		InfinityUtils:Warning("Donation awards are disabled.", "Taxation")
		return false
	end
	if _G.issecretvalue and _G.issecretvalue(itemName) then
		InfinityUtils:Warning("Donation item is protected.", "Taxation"); return false
	end
	if type(itemName) ~= "string" or itemName == "" or itemName:find("[%c]") then
		InfinityUtils:Warning("Enter a donation item.", "Taxation"); return false
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
	
	return self:_Award(playerName, goldAmount, self.config.donationRatePerGold, "donation", reason, itemName)
end

function InfinityDKPTaxation:_Award(playerName, goldAmount, rate, kind, reason, itemName)
	if _G.issecretvalue and (issecretvalue(playerName) or issecretvalue(goldAmount)
		or issecretvalue(rate) or issecretvalue(reason)) then
		InfinityUtils:Warning("Tax award input is protected.", "Taxation"); return false
	end
	if type(playerName) ~= "string" or playerName == "" or playerName:find("[%c]")
		or type(goldAmount) ~= "number" or goldAmount ~= goldAmount or goldAmount <= 0 or goldAmount >= math.huge
		or type(rate) ~= "number" or rate ~= rate or rate < 0 or rate >= math.huge
		or (reason ~= nil and (type(reason) ~= "string" or reason:find("[%c]"))) then
		InfinityUtils:Warning("Invalid tax award input.", "Taxation"); return false
	end
	local engine = _G.InfinityDKPEngine
	if not engine or type(engine.db) ~= "table" or type(engine.SYSTEM_DKP) ~= "string"
		or engine.system_type ~= engine.SYSTEM_DKP
		or type(engine.AdjustDKP) ~= "function" then
		InfinityUtils:Warning("Initialized InfinityDKP in DKP mode is required.", "Taxation"); return false
	end
	local points = _G.InfinityDKPPoints
	if not points or type(points.LogTransaction) ~= "function"
		or type(engine.db.pointTransactions) ~= "table" or points.point_history ~= engine.db.pointTransactions then
		InfinityUtils:Warning("InfinityDKP point history is unavailable.", "Taxation"); return false
	end
	if _G.InfinityDKPGuildSync and InfinityDKPGuildSync.outgoing then
		InfinityUtils:Warning("Wait for the current DKP snapshot to finish.", "Taxation"); return false
	end
	local amount = goldAmount * rate
	if amount ~= amount or amount >= math.huge or amount < 1 or amount > 1000000000 then
		InfinityUtils:Warning("Calculated DKP must be between 1 and 1000000000.", "Taxation"); return false
	end
	amount = math.floor(amount)
	reason = reason or ("Manual " .. kind .. (itemName and (": " .. itemName) or ""))
	if not engine:AdjustDKP(playerName, amount, reason) then
		InfinityUtils:Warning("DKP award failed; check the local player and balance.", "Taxation"); return false
	end
	points:LogTransaction(playerName, "dkp", amount, reason)
	self:_LogTaxation(playerName, goldAmount, amount, kind, reason)
	self:_SaveSettings()
	if _G.InfinityDKPGuildSync and type(InfinityDKPGuildSync.MarkSnapshotsStale) == "function" then
		InfinityDKPGuildSync:MarkSnapshotsStale("Local tax or donation points changed")
	end
	if _G.InfinityDKPUI and type(InfinityDKPUI.Update) == "function" then InfinityDKPUI:Update() end
	InfinityMessaging:Publish(kind == "tax" and "dkp_tax_awarded" or "dkp_donation_awarded",
		playerName, goldAmount, amount, itemName)
	return true
end

function InfinityDKPTaxation:SetTaxRate(ratePerGold)
	if _G.issecretvalue and _G.issecretvalue(ratePerGold) then return false end
	if type(ratePerGold) ~= "number" or ratePerGold ~= ratePerGold or ratePerGold < 0 or ratePerGold >= math.huge then return false end
	self.config.taxRatePerGold = ratePerGold
	InfinityUtils:Info("Tax rate set to " .. ratePerGold .. " DKP per gold", "Taxation")
	self:_SaveSettings()
	return true
end

function InfinityDKPTaxation:SetDonationRate(ratePerGold)
	if _G.issecretvalue and _G.issecretvalue(ratePerGold) then return false end
	if type(ratePerGold) ~= "number" or ratePerGold ~= ratePerGold or ratePerGold < 0 or ratePerGold >= math.huge then return false end
	self.config.donationRatePerGold = ratePerGold
	InfinityUtils:Info("Donation rate set to " .. ratePerGold .. " DKP per gold", "Taxation")
	self:_SaveSettings()
	return true
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
		timestamp = InfinityUtils:GetTimeStamp(),
		type = type,
		reason = reason,
	})
	
	if #self.taxHistory > self.maxHistorySize then
		table.remove(self.taxHistory, 1)
	end
end

function InfinityDKPTaxation:_SaveSettings()
	local settings = InfinityStorageManager:GetFeatureSettings("taxation")
	settings.config = self.config
	settings.whitelistedItems = self.whitelistedItems
	settings.blacklistedItems = self.blacklistedItems
	settings.taxHistory = self.taxHistory
end

return InfinityDKPTaxation
