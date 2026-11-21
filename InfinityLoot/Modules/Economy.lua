-- InfinityLoot - Economy Module
-- Handles gold flow, market analysis, and financial tracking

InfinityLootEconomy = {
	db = {},
}

-- Initialize economy module
function InfinityLootEconomy:Initialize()
	InfinityUtils:Info("Economy module initializing...", "InfinityLoot")
	
	-- Load saved data
	self.db = InfinityStorageManager:GetFeatureSettings(INFINITY_FEATURES.LOOT) or {}
	
	-- Register with data manager
	InfinityDataManager:RegisterSource("loot_economy", function(data)
		InfinityUtils:Debug("Economy data updated", "InfinityLoot")
	end)
	
	-- Initialize default structure
	if not self.db.goldTracking then
		self.db.goldTracking = {
			earned = {},
			spent = {},
			merchants = {},
		}
	end
	
	InfinityUtils:Info("Economy module initialized", "InfinityLoot")
end

-- Record gold earned
function InfinityLootEconomy:RecordEarnings(amount, source, description)
	if not self.db.goldTracking then
		self.db.goldTracking = { earned = {}, spent = {}, merchants = {} }
	end
	
	local entry = {
		amount = amount,
		source = source or "unknown",
		description = description,
		timestamp = InfinityUtils:GetTimeStamp(),
	}
	
	table.insert(self.db.goldTracking.earned, entry)
	
	InfinityUtils:Debug("Earnings recorded: " .. InfinityUtils:FormatGold(amount), "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_economy", "earnings_recorded", entry)
	
	return true
end

-- Record gold spent
function InfinityLootEconomy:RecordSpending(amount, merchant, item)
	if not self.db.goldTracking then
		self.db.goldTracking = { earned = {}, spent = {}, merchants = {} }
	end
	
	local entry = {
		amount = amount,
		merchant = merchant,
		item = item,
		timestamp = InfinityUtils:GetTimeStamp(),
	}
	
	table.insert(self.db.goldTracking.spent, entry)
	
	-- Track merchant spending
	if merchant then
		if not self.db.goldTracking.merchants[merchant] then
			self.db.goldTracking.merchants[merchant] = 0
		end
		self.db.goldTracking.merchants[merchant] = self.db.goldTracking.merchants[merchant] + amount
	end
	
	InfinityUtils:Debug("Spending recorded: " .. InfinityUtils:FormatGold(amount), "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "loot_economy", "spending_recorded", entry)
	
	return true
end

-- Get balance
function InfinityLootEconomy:GetBalance()
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
function InfinityLootEconomy:GetSummary(timeframe)
	timeframe = timeframe or 86400 * 7  -- Default 1 week
	local cutoffTime = InfinityUtils:GetTimeStamp() - timeframe
	
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
function InfinityLootEconomy:GetTopMerchants(limit)
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

return InfinityLootEconomy

