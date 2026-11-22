-- InfinityLoot Initialization
-- Loot management, tracking, and economy features

local function InitializeInfinityLoot()
	InfinityUtils:Info("InfinityLoot initializing...", "InfinityLoot")
	
	-- Check if core is ready
	if not _G.InfinityCore or not _G.InfinityDataManager then
		InfinityUtils:Warning("InfinityCore not ready, deferring initialization", "InfinityLoot")
		return
	end
	
	local function InitializeModule(name, module)
		if not module then return end
		local ok, err = pcall(function() module:Initialize() end)
		if not ok then
			if _G.issecretvalue and _G.issecretvalue(err) then err = nil end
			InfinityUtils:Error(name .. " initialization failed: " .. tostring(err or "protected error"), "InfinityLoot")
		end
	end
	-- Initialize all modules
	InitializeModule("Loot manager", InfinityLootManager)
	InitializeModule("Loot tracking", InfinityLootTracking)
	InitializeModule("Loot economy", InfinityLootEconomy)
	InitializeModule("Commissions", InfinityLootCommissions)
	InitializeModule("Auctions", InfinityLootAuctions)
	if InfinityLootAdvancedEconomy then
		local ok, err = pcall(function() InfinityLootAdvancedEconomy:Initialize() end)
		if not ok then InfinityUtils:Error("Advanced Economy initialization failed: " .. tostring(err), "InfinityLoot") end
	end
	InitializeModule("Loot EP/GP", InfinityLootEPGP)
	InitializeModule("Decay", InfinityLootDecay)
	InitializeModule("Loot history", InfinityLootHistory)
	if InfinityLootDKPUI then
		local ok, err = pcall(function() InfinityLootDKPUI:Initialize() end)
		if not ok then InfinityUtils:Error("Loot DKP UI initialization failed: " .. tostring(err), "InfinityLoot") end
	end
	InitializeModule("Loot trade", InfinityDKPTrade)
	InitializeModule("Loot taxation", InfinityDKPTaxation)
	InitializeModule("Point audit", InfinityPointAuditing)
	InitializeModule("Loot access control", InfinityLootAccessControl)
	InitializeModule("Tooltip prices", InfinityTooltipPrices)
	InitializeModule("Auction integration", InfinityLootAuctionIntegration)
	if InfinityLootAuctionUI then
		local ok, err = pcall(function() InfinityLootAuctionUI:Initialize() end)
		if not ok then InfinityUtils:Error("Auction UI initialization failed: " .. tostring(err), "InfinityLoot") end
	end
	if InfinityLootPerformanceOptimizer and InfinityLootPerformanceOptimizer.Enable then InfinityLootPerformanceOptimizer:Enable() end
	if InfinityCompatibilityChecker and InfinityCompatibilityChecker.RegisterAddonsForChecking then InfinityCompatibilityChecker:RegisterAddonsForChecking() end
	
	-- Register global exports
	_G.InfinityLootManager = InfinityLootManager
	_G.InfinityLootTracking = InfinityLootTracking
	_G.InfinityLootEconomy = InfinityLootEconomy
	_G.InfinityLootCommissions = InfinityLootCommissions
	_G.InfinityLootAuctions = InfinityLootAuctions
	_G.InfinityLootAdvancedEconomy = InfinityLootAdvancedEconomy
	_G.InfinityLootEPGP = InfinityLootEPGP
	_G.InfinityLootDecay = InfinityLootDecay
	_G.InfinityLootHistory = InfinityLootHistory
	_G.InfinityLootDKPUI = InfinityLootDKPUI
	_G.InfinityDKPTrade = InfinityDKPTrade
	_G.InfinityDKPTaxation = InfinityDKPTaxation
	_G.InfinityPointAuditing = InfinityPointAuditing
	_G.InfinityLootAccessControl = InfinityLootAccessControl
	_G.InfinityLootAuctionIntegration = InfinityLootAuctionIntegration
	_G.InfinityLootAuctionUI = InfinityLootAuctionUI
	_G.InfinityLootPerformanceOptimizer = InfinityLootPerformanceOptimizer
	_G.InfinityCompatibilityChecker = InfinityCompatibilityChecker
	_G.InfinityDataIntegrityVerifier = InfinityDataIntegrityVerifier
	_G.InfinityDiagnosticsConsole = InfinityDiagnosticsConsole
	
	-- Register slash command
	InfinityCommandRegistry:RegisterCommand("loot", function(args, msg)
		if not args or #args == 0 then
			InfinityLootUI:Toggle()
		elseif args[1] == "price" then
			local itemID = args[2] and tonumber(args[2])
			if not InfinityLootAdvancedEconomy.initialized then
				print("Local loot prices are unavailable: economy initialization failed.")
			elseif #args ~= 3 or not itemID or itemID <= 0 or itemID == math.huge or itemID ~= math.floor(itemID)
				or not InfinityLootAdvancedEconomy:SetItemPrice(itemID, args[3]) then
				print("Usage: /loot price <itemID> <non-negative GP>")
			else
				print("Local tooltip price set for item " .. itemID .. ": " .. args[3] .. " GP (not guild-synchronized).")
			end
		elseif args[1] == "stats" then
			local stats = InfinityLootManager:GetStatistics()
			InfinityUtils:Info("=== Loot Manager Stats ===", "InfinityLoot")
			InfinityUtils:Info("Total Raids: " .. stats.totalRaids, "InfinityLoot")
			InfinityUtils:Info("Total Members: " .. stats.totalMembers, "InfinityLoot")
			InfinityUtils:Info("Total Loot: " .. stats.totalLootAwarded, "InfinityLoot")
		elseif args[1] == "tracking" then
			local trackStats = InfinityLootTracking:GetSessionStats()
			if trackStats then
				InfinityUtils:Info("=== Loot Tracking Stats ===", "InfinityLoot")
				InfinityUtils:Info("Session Value: " .. InfinityUtils:FormatGold(trackStats.totalValue), "InfinityLoot")
				InfinityUtils:Info("Gold/Hour: " .. InfinityUtils:FormatGold(trackStats.goldPerHour), "InfinityLoot")
				InfinityUtils:Info("Items Looted: " .. trackStats.totalItems, "InfinityLoot")
			end
		elseif args[1] == "auction" then
			InfinityLootAuctionUI:HandleAuctionCommand(args)
		elseif args[1] == "bid" then
			InfinityLootAuctionUI:HandleBidCommand(args)
		elseif args[1] == "list" then
			InfinityLootAuctionUI:ShowAuctionList()
		elseif args[1] == "audit" then
			InfinityLootAuctionUI:ShowAuditLog()
		elseif args[1] == "role" then
			InfinityLootAuctionUI:HandleRoleCommand(args)
		elseif args[1] == "debug" then
			InfinityLootAuctionUI:HandleDebugCommand(args)
		else
			InfinityLootAuctionUI:ShowHelp()
		end
	end, {"lm"})
	
	-- Decay system slash commands
	InfinityCommandRegistry:RegisterCommand("decay", function(args, msg)
		if not args or #args == 0 then
			InfinityUtils:Info("=== Decay System ===", "Decay")
			InfinityUtils:Info("Enabled: " .. (InfinityLootDecay.config.decayEnabled and "Yes" or "No"), "Decay")
			InfinityUtils:Info("Decay: " .. InfinityLootDecay.config.decayPercent .. "% every " .. (InfinityLootDecay.config.decayInterval/86400) .. " days", "Decay")
			InfinityUtils:Info("Weekly EP Cap: " .. (InfinityLootDecay.config.weeklyEPCap == 0 and "Unlimited" or InfinityLootDecay.config.weeklyEPCap), "Decay")
			InfinityUtils:Info("Min GP Threshold: " .. InfinityLootDecay.config.minGPThreshold, "Decay")
		elseif args[1] == "apply" then
			InfinityLootDecay:ApplyDecayToAll()
		elseif args[1] == "percent" and args[2] then
			InfinityLootDecay:SetDecayPercent(args[2])
		elseif args[1] == "interval" and args[2] then
			InfinityLootDecay:SetDecayInterval(tonumber(args[2]) or 604800)
		elseif args[1] == "enable" then
			InfinityLootDecay:SetDecayEnabled(true)
		elseif args[1] == "disable" then
			InfinityLootDecay:SetDecayEnabled(false)
		elseif args[1] == "weeklycap" and args[2] then
			InfinityLootDecay:SetWeeklyEPCap(tonumber(args[2]) or 2000)
		elseif args[1] == "resetweekly" then
			InfinityLootDecay:ResetWeeklyEPCounters()
		elseif args[1] == "minggp" and args[2] then
			InfinityLootDecay:SetMinGPThreshold(tonumber(args[2]) or 50)
		elseif args[1] == "history" then
			local history = InfinityLootDecay:ExportDecayHistory(50)
			print(history)
		end
	end, {})
	
	-- Interval awards slash commands
	InfinityCommandRegistry:RegisterCommand("awards", function(args, msg)
		if not args or #args == 0 then
			InfinityUtils:Info("=== Interval Awards ===", "Decay")
			InfinityUtils:Info("Enabled: " .. (InfinityLootDecay.config.intervalAwardEnabled and "Yes" or "No"), "Decay")
			InfinityUtils:Info("Attendance Award: " .. InfinityLootDecay.config.attendanceAwardPerInterval .. " EP", "Decay")
			InfinityUtils:Info("Check Interval: " .. (InfinityLootDecay.config.attendanceCheckInterval/3600) .. " hours", "Decay")
		elseif args[1] == "award" and args[2] then
			InfinityLootDecay:AwardAllAttendanceEP()
		elseif args[1] == "amount" and args[2] then
			InfinityLootDecay:SetAttendanceAwardAmount(tonumber(args[2]) or 50)
		elseif args[1] == "interval" and args[2] then
			InfinityLootDecay:SetAttendanceCheckInterval(tonumber(args[2]) or 86400)
		end
	end, {})
	
	-- Transaction history / auditing slash commands
	InfinityCommandRegistry:RegisterCommand("audit", function(args, msg)
		if not args or #args == 0 then
			local stats = InfinityLootEPGP:GetTransactionStats()
			InfinityUtils:Info("=== EPGP Audit Statistics ===", "EPGP")
			InfinityUtils:Info("Total Transactions: " .. stats.totalTransactions, "EPGP")
			InfinityUtils:Info("EP Awards: " .. stats.epAwardedTransactions, "EPGP")
			InfinityUtils:Info("GP Awards: " .. stats.gpAwardedTransactions, "EPGP")
			InfinityUtils:Info("Decays: " .. stats.decayTransactions, "EPGP")
			InfinityUtils:Info("Resets: " .. stats.resetTransactions, "EPGP")
		elseif args[1] == "player" and args[2] then
			local history = InfinityLootEPGP:GetPlayerTransactionHistory(args[2], 50)
			InfinityUtils:Info("=== Transaction History: " .. args[2] .. " ===", "EPGP")
			for i, trans in ipairs(history) do
				local timestamp = InfinityUtils:FormatTimeStamp(trans.timestamp) or "?"
				print(string.format("[%s] %s - %s", timestamp, trans.type, trans.reason or ""))
			end
		elseif args[1] == "ep" and args[2] then
			local history = InfinityLootEPGP:GetPlayerEPHistory(args[2], 50)
			InfinityUtils:Info("=== EP History: " .. args[2] .. " ===", "EPGP")
			for i, entry in ipairs(history) do
				local timestamp = InfinityUtils:FormatTimeStamp(entry.timestamp) or "?"
				print(string.format("[%s] %d → %d (change: %+d) - %s", timestamp, entry.oldValue, entry.newValue, entry.change, entry.reason))
			end
		elseif args[1] == "gp" and args[2] then
			local history = InfinityLootEPGP:GetPlayerGPHistory(args[2], 50)
			InfinityUtils:Info("=== GP History: " .. args[2] .. " ===", "EPGP")
			for i, entry in ipairs(history) do
				local timestamp = InfinityUtils:FormatTimeStamp(entry.timestamp) or "?"
				print(string.format("[%s] %s: %d → %d (change: %+d) - %s", timestamp, entry.item or "Unknown", entry.oldValue, entry.newValue, entry.change, entry.reason))
			end
		elseif args[1] == "export" then
			local export = InfinityLootEPGP:ExportTransactionHistory(500)
			print(export)
		elseif args[1] == "type" and args[2] then
			local history = InfinityLootEPGP:GetTransactionsByType(args[2], 100)
			InfinityUtils:Info("=== Transactions of type: " .. args[2] .. " ===", "EPGP")
			InfinityUtils:Info("Found: " .. #history .. " transaction(s)", "EPGP")
		end
	end, {})
	
	-- Loot history slash commands
	InfinityCommandRegistry:RegisterCommand("loothistory", function(args, msg)
		if not args or #args == 0 then
			local analysis = InfinityLootHistory:GetLootAnalysis()
			InfinityUtils:Info("=== Loot History ===", "LootHistory")
			InfinityUtils:Info("Total Loot Awards: " .. analysis.totalAwards, "LootHistory")
			InfinityUtils:Info("Total Value: " .. analysis.totalValue, "LootHistory")
			InfinityUtils:Info("Average Value: " .. analysis.averageValue, "LootHistory")
			InfinityUtils:Info("Highest Award: " .. analysis.highestAward, "LootHistory")
		elseif args[1] == "player" and args[2] then
			local history = InfinityLootHistory:GetPlayerLootHistory(args[2], 50)
			InfinityUtils:Info("=== Loot for " .. args[2] .. " ===", "LootHistory")
			for i, entry in ipairs(history) do
				local timestamp = InfinityUtils:FormatTimeStamp(entry.timestamp) or "?"
				print(string.format("[%s] %s (Value: %d) - %s", timestamp, entry.itemName, entry.value, entry.reason))
			end
		elseif args[1] == "top" then
			local topPlayers = InfinityLootHistory:GetTopLootRecipients(10, "value")
			InfinityUtils:Info("=== Top Loot Recipients (by value) ===", "LootHistory")
			for rank, player in ipairs(topPlayers) do
				print(string.format("%d. %s - %d awards, Total: %d, Avg: %d", rank, player.name, player.totalAwards, player.totalValue, player.averageValue))
			end
		elseif args[1] == "items" then
			local topItems = InfinityLootHistory:GetMostAwardedItems(10)
			InfinityUtils:Info("=== Most Awarded Items ===", "LootHistory")
			for rank, item in ipairs(topItems) do
				print(string.format("%d. Item %s - Awarded %d times, Total Value: %d", rank, item.itemId, item.awardCount, item.totalValue))
			end
		elseif args[1] == "export" then
			local export = InfinityLootHistory:ExportLootHistory(500)
			print(export)
		elseif args[1] == "comparison" then
			local report = InfinityLootHistory:ExportPlayerComparisonReport()
			print(report)
		end
	end, {"lh"})
	
	-- DKP UI slash commands
	InfinityCommandRegistry:RegisterCommand("dkpui", function(args, msg)
		if not args or #args == 0 then
			InfinityLootDKPUI:ToggleWindow()
		elseif args[1] == "leaderboard" or args[1] == "standing" then
			InfinityLootDKPUI:ShowLeaderboard()
		elseif args[1] == "queue" then
			InfinityLootDKPUI:ShowLootQueue()
		elseif args[1] == "hide" then
			if InfinityLootDKPUI.mainWindow then
				InfinityLootDKPUI.mainWindow:Hide()
			end
		end
	end, {})
	
	-- DKP Trading slash commands
	InfinityCommandRegistry:RegisterCommand("dkptrade", function(args, msg)
		if not args or #args == 0 then
			InfinityUtils:Info("=== DKP Trading ===", "DKPTrade")
			InfinityUtils:Info("Usage: /dkptrade <player> <amount>", "DKPTrade")
			InfinityUtils:Info("       /dkptrade history [player]", "DKPTrade")
		elseif args[1] == "history" then
			local trading = _G.InfinityDKPPlayerTrading
			if not trading or type(trading.List) ~= "function" then
				InfinityUtils:Warning("InfinityDKP guild trading is unavailable.", "DKPTrade")
			else
				if args[2] then InfinityUtils:Info("Showing all active trades; player filtering is unavailable.", "DKPTrade") end
				trading:List()
			end
		elseif args[2] and tonumber(args[2]) then
			local targetPlayer = args[1]
			local amount = tonumber(args[2])
			InfinityDKPTrade:RequestTrade(targetPlayer, amount)
		end
	end, {"trade"})
	
	-- DKP Taxation slash commands
	InfinityCommandRegistry:RegisterCommand("dkptax", function(args, msg)
		if not args or #args == 0 then
			InfinityUtils:Info("=== DKP Taxation Config ===", "Taxation")
			InfinityUtils:Info("Tax Rate: " .. InfinityDKPTaxation.config.taxRatePerGold .. " DKP per gold", "Taxation")
			InfinityUtils:Info("Donation Rate: " .. InfinityDKPTaxation.config.donationRatePerGold .. " DKP per gold", "Taxation")
			InfinityUtils:Info("Enabled: " .. (InfinityDKPTaxation.config.enableTaxation and "Yes" or "No"), "Taxation")
		elseif args[1] == "rate" and args[2] then
			if not InfinityDKPTaxation:SetTaxRate(tonumber(args[2])) then
				InfinityUtils:Warning("Enter a non-negative finite tax rate.", "Taxation")
			end
		elseif args[1] == "donation" and args[2] then
			if not InfinityDKPTaxation:SetDonationRate(tonumber(args[2])) then
				InfinityUtils:Warning("Enter a non-negative finite donation rate.", "Taxation")
			end
		elseif args[1] == "whitelist" and args[2] then
			InfinityDKPTaxation:Whitelist(args[2])
			InfinityUtils:Info("Item " .. args[2] .. " whitelisted", "Taxation")
		elseif args[1] == "blacklist" and args[2] then
			InfinityDKPTaxation:Blacklist(args[2])
			InfinityUtils:Info("Item " .. args[2] .. " blacklisted", "Taxation")
		elseif args[1] == "history" and args[2] then
			local history = InfinityDKPTaxation:GetTaxHistory(args[2])
			InfinityUtils:Info("=== Tax History for " .. args[2] .. " ===", "Taxation")
			for i, entry in ipairs(history) do
				print(string.format("%s: +%d DKP (%d gold) - %s", entry.type, entry.dkp, entry.gold, entry.reason))
			end
			local totalTax = InfinityDKPTaxation:GetTotalTaxed(args[2])
			local totalDonate = InfinityDKPTaxation:GetTotalDonated(args[2])
			InfinityUtils:Info("Total from taxes: " .. totalTax .. " DKP", "Taxation")
			InfinityUtils:Info("Total from donations: " .. totalDonate .. " DKP", "Taxation")
		end
	end, {"tax"})
	
	-- Point auditing slash commands
	InfinityCommandRegistry:RegisterCommand("pointaudit", function(args, msg)
		if not args or #args == 0 then
			InfinityUtils:Info("=== Point Auditing System ===", "Auditing")
			InfinityUtils:Info("Usage: /pointaudit <player> [days]", "Auditing")
			InfinityUtils:Info("       /pointaudit sources <player> - Show EP sources", "Auditing")
			InfinityUtils:Info("       /pointaudit items <player> - Show GP items", "Auditing")
			InfinityUtils:Info("       /pointaudit anomalies <player> - Detect suspicious activity", "Auditing")
		elseif args[1] == "sources" and args[2] then
			local sources = InfinityPointAuditing:GetPlayerEPSources(args[2], 10)
			InfinityUtils:Info("=== EP Sources for " .. args[2] .. " ===", "Auditing")
			for i, source in ipairs(sources) do
				print(string.format("%d. %s: %d EP (%d awards)", i, source.reason, source.amount, source.count))
			end
		elseif args[1] == "items" and args[2] then
			local items = InfinityPointAuditing:GetPlayerGPItems(args[2], 10)
			InfinityUtils:Info("=== GP Items for " .. args[2] .. " ===", "Auditing")
			for i, item in ipairs(items) do
				print(string.format("%d. %s: %d GP total (%.1f avg)", i, item.itemName, item.gp, item.avgCost))
			end
		elseif args[1] == "anomalies" and args[2] then
			local anomalies = InfinityPointAuditing:DetectAnomalies(args[2])
			InfinityUtils:Info("=== Anomalies for " .. args[2] .. " ===", "Auditing")
			if #anomalies == 0 then
				InfinityUtils:Info("No anomalies detected", "Auditing")
			else
				for i, anomaly in ipairs(anomalies) do
					print(string.format("[%s] %s - %s", anomaly.severity, anomaly.type, anomaly.detail))
				end
			end
		elseif args[2] then
			local days = tonumber(args[2]) or 30
			local report = InfinityPointAuditing:GeneratePlayerAuditReport(args[1], days)
			InfinityUtils:Info("=== Audit Report: " .. args[1] .. " (" .. days .. " days) ===", "Auditing")
			print(string.format("EP Gained: %d", report.epGained))
			print(string.format("GP Spent: %d", report.gpSpent))
			print(string.format("Net Points: %+d", report.netPoints))
		end
	end, {})
	
	-- Register keybind
	InfinityCommandRegistry:RegisterKeybind("TOGGLE_LOOT_MANAGER", "Toggle Loot Manager", function()
		InfinityLootUI:Toggle()
	end)
	
	InfinityCommandRegistry:RegisterKeybind("TOGGLE_DKP_UI", "Toggle DKP UI", function()
		if _G.InfinityDKPUI and _G.InfinityDKPUI.Toggle then
			_G.InfinityDKPUI:Toggle()
		end
	end)
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityLoot", "1.2.2", {
			description = "Loot management",
			author = "Infinity Suite Team",
			category = "Loot",
			enabled = true,
			settings = {{}}
		})
	end
	
	InfinityUtils:Info("InfinityLoot initialized successfully", "InfinityLoot")
	InfinityMessaging:Publish(INFINITY_EVENTS.FEATURE_ENABLED, INFINITY_FEATURES.LOOT, true)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityLoot" then
		-- Wait for InfinityCore to be ready
		if _G.InfinityCore and _G.InfinityDataManager then
			InitializeInfinityLoot()
		else
			-- Defer initialization if core isn't ready
			local retry = 0
			local retryFrame = CreateFrame("Frame")
			retryFrame:SetScript("OnUpdate", function(f, elapsed)
				retry = retry + elapsed
				if retry > 0.5 then
					if _G.InfinityCore and _G.InfinityDataManager then
						InitializeInfinityLoot()
						f:Hide()
					end
				end
			end)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


