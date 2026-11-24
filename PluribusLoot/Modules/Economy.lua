-- PluribusLoot - Economy Module
-- Handles gold flow, market analysis, and financial tracking

PluribusLootEconomy = {
	db = {},
}

-- Initialize economy module
function PluribusLootEconomy:Initialize()
	PluribusUtils:Info("Economy module initializing...", "PluribusLoot")
	
	-- Load saved data
	self.db = PluribusStorageManager:GetFeatureSettings(PLURIBUS_FEATURES.LOOT) or {}
	
	-- Register with data manager
	PluribusDataManager:RegisterSource("loot_economy", function(data)
		PluribusUtils:Debug("Economy data updated", "PluribusLoot")
	end)
	
	-- Initialize default structure
	if not self.db.goldTracking then
		self.db.goldTracking = {
			earned = {},
			spent = {},
			merchants = {},
		}
	end
	
	PluribusUtils:Info("Economy module initialized", "PluribusLoot")
end

-- Record gold earned
function PluribusLootEconomy:RecordEarnings(amount, source, description)
	if not self.db.goldTracking then
		self.db.goldTracking = { earned = {}, spent = {}, merchants = {} }
	end
	
	local entry = {
		amount = amount,
		source = source or "unknown",
		description = description,
		timestamp = PluribusUtils:GetTimeStamp(),
	}
	
	table.insert(self.db.goldTracking.earned, entry)
	
	PluribusUtils:Debug("Earnings recorded: " .. PluribusUtils:FormatGold(amount), "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_economy", "earnings_recorded", entry)
	
	return true
end

-- Record gold spent
function PluribusLootEconomy:RecordSpending(amount, merchant, item)
	if not self.db.goldTracking then
		self.db.goldTracking = { earned = {}, spent = {}, merchants = {} }
	end
	
	local entry = {
		amount = amount,
		merchant = merchant,
		item = item,
		timestamp = PluribusUtils:GetTimeStamp(),
	}
	
	table.insert(self.db.goldTracking.spent, entry)
	
	-- Track merchant spending
	if merchant then
		if not self.db.goldTracking.merchants[merchant] then
			self.db.goldTracking.merchants[merchant] = 0
		end
		self.db.goldTracking.merchants[merchant] = self.db.goldTracking.merchants[merchant] + amount
	end
	
	PluribusUtils:Debug("Spending recorded: " .. PluribusUtils:FormatGold(amount), "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.DATA_CHANGED, "loot_economy", "spending_recorded", entry)
	
	return true
end

-- Get balance
function PluribusLootEconomy:GetBalance()
	if not self.db.goldTracking then
		return 0
	end
	
	local earned = 0
	local spent = 0
	
	for _, entry in ipairs(self.db.goldTracking.earned or {}) do
		earned = earned + entry.amount
	end
	
	for _, entry in ipairs(self.db.goldTracking.spent or {}) do
		spent = spent + entry.amount
	end
	
	return earned - spent
end

-- Get economics summary
function PluribusLootEconomy:GetSummary(timeframe)
	timeframe = timeframe or 86400 * 7  -- Default 1 week
	local cutoffTime = PluribusUtils:GetTimeStamp() - timeframe
	
	local summary = {
		totalEarned = 0,
		totalSpent = 0,
		transactions = 0,
		merchants = {},
	}
	
	for _, entry in ipairs(self.db.goldTracking.earned or {}) do
		if entry.timestamp >= cutoffTime then
			summary.totalEarned = summary.totalEarned + entry.amount
			summary.transactions = summary.transactions + 1
		end
	end
	
	for _, entry in ipairs(self.db.goldTracking.spent or {}) do
		if entry.timestamp >= cutoffTime then
			summary.totalSpent = summary.totalSpent + entry.amount
			summary.transactions = summary.transactions + 1
			
			if entry.merchant then
				if not summary.merchants[entry.merchant] then
					summary.merchants[entry.merchant] = 0
				end
				summary.merchants[entry.merchant] = summary.merchants[entry.merchant] + entry.amount
			end
		end
	end
	
	summary.balance = summary.totalEarned - summary.totalSpent
	
	return summary
end

-- Get top merchants
function PluribusLootEconomy:GetTopMerchants(limit)
	limit = limit or 10
	
	if not self.db.goldTracking or not self.db.goldTracking.merchants then
		return {}
	end
	
	local merchants = {}
	for name, amount in pairs(self.db.goldTracking.merchants) do
		table.insert(merchants, {
			name = name,
			amount = amount,
		})
	end
	
	table.sort(merchants, function(a, b)
		return a.amount > b.amount
	end)
	
	local result = {}
	for i = 1, math.min(limit, #merchants) do
		table.insert(result, merchants[i])
	end
	
	return result
end

return PluribusLootEconomy

