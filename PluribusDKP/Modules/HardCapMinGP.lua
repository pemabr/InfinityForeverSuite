-- Hard Cap & Minimum GP System
-- Enforces cost floors on items and bidding limits
-- Prevents players from bidding below minimum GP threshold

local HardCapMinGP = {
	config = {
		enableMinimumGP = true,
		globalMinimumGP = 50, -- Min cost across all items
		enablePerItemMinGP = true,
		perItemMinGPTable = {}, -- {itemID = minimumGP}
		enableBidLimits = true,
		maxBidPercentage = 150, -- Can't bid more than 150% of item's normal cost
		notifyOnInvalidBid = true,
	},
	
	itemGPHistory = {}, -- {itemID = {minGP, timestamp}}
	overrides = {}, -- {itemID = overrideMinGP}
}

_G.PluribusHardCapMinGP = HardCapMinGP

function HardCapMinGP:Initialize()
	PluribusUtils:Info("Hard Cap & Min GP system initialized", "DKP")
	self:LoadSystemData()
end

function HardCapMinGP:GetEffectiveMinimumGP(itemID)
	if not self.config.enableMinimumGP then
		return 0
	end
	
	-- Check item override first
	if self.overrides[itemID] then
		return self.overrides[itemID]
	end
	
	-- Check per-item minimum
	if self.config.enablePerItemMinGP and self.perItemMinGPTable[itemID] then
		return self.perItemMinGPTable[itemID]
	end
	
	-- Use global minimum
	return self.config.globalMinimumGP
end

function HardCapMinGP:IsValidBid(itemID, bidAmount, normalCost)
	if not self.config.enableMinimumGP then
		return true
	end
	
	-- Check minimum GP
	local minimumGP = self:GetEffectiveMinimumGP(itemID)
	if bidAmount < minimumGP then
		return false, "BELOW_MINIMUM_GP", {
			required = minimumGP,
			offered = bidAmount,
			shortfall = minimumGP - bidAmount,
		}
	end
	
	-- Check max bid limit
	if self.config.enableBidLimits and normalCost and normalCost > 0 then
		local maxAllowedBid = (normalCost * self.config.maxBidPercentage) / 100
		if bidAmount > maxAllowedBid then
			return false, "EXCEEDS_MAX_BID", {
				normal = normalCost,
				maxAllowed = maxAllowedBid,
				offered = bidAmount,
				excess = bidAmount - maxAllowedBid,
			}
		end
	end
	
	return true
end

function HardCapMinGP:CanPlayerBid(playerName, itemID, bidAmount, normalCost)
	-- Check min GP validity
	local isValid, invalidReason, details = self:IsValidBid(itemID, bidAmount, normalCost)
	if not isValid then
		return false, invalidReason, details
	end
	
	-- Check if player has enough DKP
	local memberData = PluribusGuildRoster:GetMember(playerName)
	if not memberData then
		return false, "PLAYER_NOT_FOUND"
	end
	
	local currentDKP = memberData.dkpBalance or 0
	if currentDKP < bidAmount then
		return false, "INSUFFICIENT_DKP", {
			have = currentDKP,
			need = bidAmount,
			shortfall = bidAmount - currentDKP,
		}
	end
	
	return true
end

function HardCapMinGP:SetItemMinimumGP(itemID, minimumGP)
	self.overrides[itemID] = minimumGP
	self:LogItemGPChange(itemID, minimumGP)
	self:SaveSystemData()
	PluribusUtils:Info("Item " .. itemID .. " minimum GP set to " .. minimumGP, "DKP")
end

function HardCapMinGP:SetGlobalMinimumGP(minimumGP)
	self.config.globalMinimumGP = minimumGP
	self:SaveSystemData()
	PluribusUtils:Info("Global minimum GP set to " .. minimumGP, "DKP")
end

function HardCapMinGP:SetMaxBidPercentage(percentage)
	self.config.maxBidPercentage = percentage
	self:SaveSystemData()
	PluribusUtils:Info("Max bid percentage set to " .. percentage .. "%", "DKP")
end

function HardCapMinGP:LogItemGPChange(itemID, minimumGP)
	if not self.itemGPHistory[itemID] then
		self.itemGPHistory[itemID] = {}
	end
	
	table.insert(self.itemGPHistory[itemID], {
		minimumGP = minimumGP,
		timestamp = time(),
	})
	
	-- Keep only last 100 entries per item
	if #self.itemGPHistory[itemID] > 100 then
		table.remove(self.itemGPHistory[itemID], 1)
	end
end

function HardCapMinGP:GetItemGPHistory(itemID)
	return self.itemGPHistory[itemID] or {}
end

function HardCapMinGP:PrintBidValidation(itemID, bidAmount, normalCost)
	local isValid, reason, details = self:IsValidBid(itemID, bidAmount, normalCost)
	
	print("|cffffd700=== Bid Validation ===|r")
	print("Item ID: " .. itemID)
	print("Bid Amount: " .. bidAmount)
	print("Normal Cost: " .. (normalCost or "Unknown"))
	print("")
	
	if isValid then
		print("|cff00ff00✓ Bid is VALID|r")
	else
		print("|cffff0000✗ Bid is INVALID|r")
		print("Reason: " .. reason)
		
		if details then
			if reason == "BELOW_MINIMUM_GP" then
				print("  Required: " .. details.required)
				print("  Offered: " .. details.offered)
				print("  Shortfall: " .. details.shortfall)
			elseif reason == "EXCEEDS_MAX_BID" then
				print("  Normal Cost: " .. details.normal)
				print("  Max Allowed: " .. details.maxAllowed)
				print("  Offered: " .. details.offered)
				print("  Excess: " .. details.excess)
			end
		end
	end
end

function HardCapMinGP:GetBidValidationMessage(itemID, bidAmount, normalCost)
	local isValid, reason, details = self:IsValidBid(itemID, bidAmount, normalCost)
	
	if isValid then
		return "|cff00ff00Bid accepted|r"
	end
	
	if reason == "BELOW_MINIMUM_GP" then
		return string.format("|cffff0000Bid too low!|r Minimum: %d (you bid %d, need %d more)",
			details.required, details.offered, details.shortfall)
	elseif reason == "EXCEEDS_MAX_BID" then
		return string.format("|cffff0000Bid too high!|r Maximum: %d (you bid %d, excess: %d)",
			details.maxAllowed, details.offered, details.excess)
	end
	
	return "Invalid bid"
end

function HardCapMinGP:WhitelistItem(itemID, reason)
	-- Exempt item from GP restrictions
	self.overrides[itemID] = 0
	PluribusUtils:Info("Item " .. itemID .. " whitelisted: " .. (reason or "No reason"), "DKP")
	self:SaveSystemData()
end

function HardCapMinGP:BlacklistItem(itemID, minimumGP, reason)
	-- Set high minimum GP for item (effectively blacklist)
	self.overrides[itemID] = minimumGP or 99999
	PluribusUtils:Info("Item " .. itemID .. " blacklisted with minimum " .. (minimumGP or 99999) .. ": " .. (reason or "No reason"), "DKP")
	self:SaveSystemData()
end

function HardCapMinGP:IsBlacklisted(itemID)
	if not self.overrides[itemID] then
		return false
	end
	
	-- If override is very high (>9999), consider it blacklisted
	return self.overrides[itemID] >= 9999
end

function HardCapMinGP:RemoveOverride(itemID)
	self.overrides[itemID] = nil
	PluribusUtils:Info("Item " .. itemID .. " override removed", "DKP")
	self:SaveSystemData()
end

function HardCapMinGP:GetAllOverrides()
	return CopyTable(self.overrides)
end

function HardCapMinGP:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		PluribusUtils:Info("Hard Cap config updated: " .. key .. " = " .. tostring(value), "DKP")
		self:SaveSystemData()
	end
end

function HardCapMinGP:PrintConfig()
	print("|cffffd700=== Hard Cap & Min GP Configuration ===|r")
	print("Enable Minimum GP: " .. tostring(self.config.enableMinimumGP))
	print("Global Minimum GP: " .. self.config.globalMinimumGP)
	print("Enable Per-Item Minimum: " .. tostring(self.config.enablePerItemMinGP))
	print("Enable Bid Limits: " .. tostring(self.config.enableBidLimits))
	print("Max Bid Percentage: " .. self.config.maxBidPercentage .. "%")
	print("Notify On Invalid Bid: " .. tostring(self.config.notifyOnInvalidBid))
	print("")
	print("Active Item Overrides: " .. self:CountOverrides())
end

function HardCapMinGP:CountOverrides()
	local count = 0
	for _ in pairs(self.overrides) do
		count = count + 1
	end
	return count
end

function HardCapMinGP:SaveSystemData()
	if not _G.PluribusSavedData then
		_G.PluribusSavedData = {}
	end
	
	_G.PluribusSavedData.hardCapMinGP = {
		config = self.config,
		overrides = self.overrides,
		itemGPHistory = self.itemGPHistory,
	}
end

function HardCapMinGP:LoadSystemData()
	if not _G.PluribusSavedData then
		_G.PluribusSavedData = {}
		return
	end
	
	local savedData = _G.PluribusSavedData.hardCapMinGP or {}
	
	if savedData.config then
		for key, value in pairs(savedData.config) do
			self.config[key] = value
		end
	end
	
	self.overrides = savedData.overrides or {}
	self.itemGPHistory = savedData.itemGPHistory or {}
end

return HardCapMinGP
