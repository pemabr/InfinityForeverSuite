-- PluribusLoot Initialization
-- Loot management, tracking, and economy features

local function InitializePluribusLoot()
	PluribusUtils:Info("PluribusLoot initializing...", "PluribusLoot")
	
	-- Check if core is ready
	if not _G.PluribusCore or not _G.PluribusDataManager then
		PluribusUtils:Warning("PluribusCore not ready, deferring initialization", "PluribusLoot")
		return
	end
	
	-- Initialize all modules
	if PluribusLootManager then pcall(function() PluribusLootManager:Initialize() end) end
	if PluribusLootTracking then pcall(function() PluribusLootTracking:Initialize() end) end
	if PluribusLootEconomy then pcall(function() PluribusLootEconomy:Initialize() end) end
	if PluribusLootCommissions then pcall(function() PluribusLootCommissions:Initialize() end) end
	if PluribusLootAuctions then pcall(function() PluribusLootAuctions:Initialize() end) end
	if PluribusLootAdvancedEconomy then pcall(function() PluribusLootAdvancedEconomy:Initialize() end) end
	if PluribusLootEPGP then pcall(function() PluribusLootEPGP:Initialize() end) end
	if PluribusLootDecay then pcall(function() PluribusLootDecay:Initialize() end) end
	if PluribusLootHistory then pcall(function() PluribusLootHistory:Initialize() end) end
	if PluribusDKPUI then pcall(function() PluribusDKPUI:Initialize() end) end
	if PluribusDKPTrade then pcall(function() PluribusDKPTrade:Initialize() end) end
	if PluribusDKPTaxation then pcall(function() PluribusDKPTaxation:Initialize() end) end
	if PluribusPointAuditing then pcall(function() PluribusPointAuditing:Initialize() end) end
	if PluribusLootAccessControl then pcall(function() PluribusLootAccessControl:Initialize() end) end
	if PluribusLootAuctionIntegration then pcall(function() PluribusLootAuctionIntegration:Initialize() end) end
	if PluribusLootAuctionUI then pcall(function() PluribusLootAuctionUI:Initialize() end) end
	if PluribusPerformanceOptimizer then
		if PluribusPerformanceOptimizer.Enable then
			pcall(function() PluribusPerformanceOptimizer:Enable() end)
		elseif PluribusPerformanceOptimizer.Initialize then
			pcall(function() PluribusPerformanceOptimizer:Initialize() end)
		end
	end
	if PluribusCompatibilityChecker and PluribusCompatibilityChecker.RegisterAddonsForChecking then
		pcall(function() PluribusCompatibilityChecker:RegisterAddonsForChecking() end)
	end
	if PluribusDataIntegrityVerifier then pcall(function() PluribusDataIntegrityVerifier:Initialize() end) end
	if PluribusDiagnosticsConsole then pcall(function() PluribusDiagnosticsConsole:Initialize() end) end
	
	-- Register global exports
	_G.PluribusLootManager = PluribusLootManager
	_G.PluribusLootTracking = PluribusLootTracking
	_G.PluribusLootEconomy = PluribusLootEconomy
	_G.PluribusLootCommissions = PluribusLootCommissions
	_G.PluribusLootAuctions = PluribusLootAuctions
	_G.PluribusLootAdvancedEconomy = PluribusLootAdvancedEconomy
	_G.PluribusLootEPGP = PluribusLootEPGP
	_G.PluribusLootDecay = PluribusLootDecay
	_G.PluribusLootHistory = PluribusLootHistory
	_G.PluribusDKPUI = PluribusDKPUI
	_G.PluribusDKPTrade = PluribusDKPTrade
	_G.PluribusDKPTaxation = PluribusDKPTaxation
	_G.PluribusPointAuditing = PluribusPointAuditing
	_G.PluribusLootAccessControl = PluribusLootAccessControl
	_G.PluribusLootAuctionIntegration = PluribusLootAuctionIntegration
	_G.PluribusLootAuctionUI = PluribusLootAuctionUI
	_G.PluribusPerformanceOptimizer = PluribusPerformanceOptimizer
	_G.PluribusCompatibilityChecker = PluribusCompatibilityChecker
	_G.PluribusDataIntegrityVerifier = PluribusDataIntegrityVerifier
	_G.PluribusDiagnosticsConsole = PluribusDiagnosticsConsole
	
	-- Register slash command
	PluribusCommandRegistry:RegisterCommand("loot", function(args, msg)
		if not args or #args == 0 then
			PluribusLootUI:Toggle()
		elseif args[1] == "stats" then
			local stats = PluribusLootManager:GetStatistics()
			PluribusUtils:Info("=== Loot Manager Stats ===", "PluribusLoot")
			PluribusUtils:Info("Total Raids: " .. stats.totalRaids, "PluribusLoot")
			PluribusUtils:Info("Total Members: " .. stats.totalMembers, "PluribusLoot")
			PluribusUtils:Info("Total Loot: " .. stats.totalLootAwarded, "PluribusLoot")
		elseif args[1] == "tracking" then
			local trackStats = PluribusLootTracking:GetSessionStats()
			if trackStats then
				PluribusUtils:Info("=== Loot Tracking Stats ===", "PluribusLoot")
				PluribusUtils:Info("Session Value: " .. PluribusUtils:FormatGold(trackStats.totalValue), "PluribusLoot")
				PluribusUtils:Info("Gold/Hour: " .. PluribusUtils:FormatGold(trackStats.goldPerHour), "PluribusLoot")
				PluribusUtils:Info("Items Looted: " .. trackStats.totalItems, "PluribusLoot")
			end
		end
	end, {"lm"})
	
	-- Decay system slash commands
	PluribusCommandRegistry:RegisterCommand("decay", function(args, msg)
		if not args or #args == 0 then
			PluribusUtils:Info("=== Decay System ===", "Decay")
			PluribusUtils:Info("Enabled: " .. (PluribusLootDecay.config.decayEnabled and "Yes" or "No"), "Decay")
			PluribusUtils:Info("Decay: " .. PluribusLootDecay.config.decayPercent .. "% every " .. (PluribusLootDecay.config.decayInterval/86400) .. " days", "Decay")
			PluribusUtils:Info("Weekly EP Cap: " .. (PluribusLootDecay.config.weeklyEPCap == 0 and "Unlimited" or PluribusLootDecay.config.weeklyEPCap), "Decay")
			PluribusUtils:Info("Min GP Threshold: " .. PluribusLootDecay.config.minGPThreshold, "Decay")
		elseif args[1] == "apply" then
			PluribusLootDecay:ApplyDecayToAll()
		elseif args[1] == "percent" and args[2] then
			PluribusLootDecay:SetDecayPercent(args[2])
		elseif args[1] == "interval" and args[2] then
			PluribusLootDecay:SetDecayInterval(tonumber(args[2]) or 604800)
		elseif args[1] == "enable" then
			PluribusLootDecay:SetDecayEnabled(true)
		elseif args[1] == "disable" then
			PluribusLootDecay:SetDecayEnabled(false)
		elseif args[1] == "weeklycap" and args[2] then
			PluribusLootDecay:SetWeeklyEPCap(tonumber(args[2]) or 2000)
		elseif args[1] == "resetweekly" then
			PluribusLootDecay:ResetWeeklyEPCounters()
		elseif args[1] == "minggp" and args[2] then
			PluribusLootDecay:SetMinGPThreshold(tonumber(args[2]) or 50)
		elseif args[1] == "history" then
			local history = PluribusLootDecay:ExportDecayHistory(50)
			print(history)
		end
	end, {})
	
	-- Interval awards slash commands
	PluribusCommandRegistry:RegisterCommand("awards", function(args, msg)
		if not args or #args == 0 then
			PluribusUtils:Info("=== Interval Awards ===", "Decay")
			PluribusUtils:Info("Enabled: " .. (PluribusLootDecay.config.intervalAwardEnabled and "Yes" or "No"), "Decay")
			PluribusUtils:Info("Attendance Award: " .. PluribusLootDecay.config.attendanceAwardPerInterval .. " EP", "Decay")
			PluribusUtils:Info("Check Interval: " .. (PluribusLootDecay.config.attendanceCheckInterval/3600) .. " hours", "Decay")
		elseif args[1] == "award" and args[2] then
			PluribusLootDecay:AwardAllAttendanceEP()
		elseif args[1] == "amount" and args[2] then
			PluribusLootDecay:SetAttendanceAwardAmount(tonumber(args[2]) or 50)
		elseif args[1] == "interval" and args[2] then
			PluribusLootDecay:SetAttendanceCheckInterval(tonumber(args[2]) or 86400)
		end
	end, {})
	
	-- Transaction history / auditing slash commands
	PluribusCommandRegistry:RegisterCommand("audit", function(args, msg)
		if not args or #args == 0 then
			local stats = PluribusLootEPGP:GetTransactionStats()
			PluribusUtils:Info("=== EPGP Audit Statistics ===", "EPGP")
			PluribusUtils:Info("Total Transactions: " .. stats.totalTransactions, "EPGP")
			PluribusUtils:Info("EP Awards: " .. stats.epAwardedTransactions, "EPGP")
			PluribusUtils:Info("GP Awards: " .. stats.gpAwardedTransactions, "EPGP")
			PluribusUtils:Info("Decays: " .. stats.decayTransactions, "EPGP")
			PluribusUtils:Info("Resets: " .. stats.resetTransactions, "EPGP")
		elseif args[1] == "player" and args[2] then
			local history = PluribusLootEPGP:GetPlayerTransactionHistory(args[2], 50)
			PluribusUtils:Info("=== Transaction History: " .. args[2] .. " ===", "EPGP")
			for i, trans in ipairs(history) do
				local timestamp = PluribusUtils:FormatTimeStamp(trans.timestamp) or "?"
				print(string.format("[%s] %s - %s", timestamp, trans.type, trans.reason or ""))
			end
		elseif args[1] == "ep" and args[2] then
			local history = PluribusLootEPGP:GetPlayerEPHistory(args[2], 50)
			PluribusUtils:Info("=== EP History: " .. args[2] .. " ===", "EPGP")
			for i, entry in ipairs(history) do
				local timestamp = PluribusUtils:FormatTimeStamp(entry.timestamp) or "?"
				print(string.format("[%s] %d → %d (change: %+d) - %s", timestamp, entry.oldValue, entry.newValue, entry.change, entry.reason))
			end
		elseif args[1] == "gp" and args[2] then
			local history = PluribusLootEPGP:GetPlayerGPHistory(args[2], 50)
			PluribusUtils:Info("=== GP History: " .. args[2] .. " ===", "EPGP")
			for i, entry in ipairs(history) do
				local timestamp = PluribusUtils:FormatTimeStamp(entry.timestamp) or "?"
				print(string.format("[%s] %s: %d → %d (change: %+d) - %s", timestamp, entry.item or "Unknown", entry.oldValue, entry.newValue, entry.change, entry.reason))
			end
		elseif args[1] == "export" then
			local export = PluribusLootEPGP:ExportTransactionHistory(500)
			print(export)
		elseif args[1] == "type" and args[2] then
			local history = PluribusLootEPGP:GetTransactionsByType(args[2], 100)
			PluribusUtils:Info("=== Transactions of type: " .. args[2] .. " ===", "EPGP")
			PluribusUtils:Info("Found: " .. #history .. " transaction(s)", "EPGP")
		end
	end, {})
	
	-- Loot history slash commands
	PluribusCommandRegistry:RegisterCommand("loothistory", function(args, msg)
		if not args or #args == 0 then
			local analysis = PluribusLootHistory:GetLootAnalysis()
			PluribusUtils:Info("=== Loot History ===", "LootHistory")
			PluribusUtils:Info("Total Loot Awards: " .. analysis.totalAwards, "LootHistory")
			PluribusUtils:Info("Total Value: " .. analysis.totalValue, "LootHistory")
			PluribusUtils:Info("Average Value: " .. analysis.averageValue, "LootHistory")
			PluribusUtils:Info("Highest Award: " .. analysis.highestAward, "LootHistory")
		elseif args[1] == "player" and args[2] then
			local history = PluribusLootHistory:GetPlayerLootHistory(args[2], 50)
			PluribusUtils:Info("=== Loot for " .. args[2] .. " ===", "LootHistory")
			for i, entry in ipairs(history) do
				local timestamp = PluribusUtils:FormatTimeStamp(entry.timestamp) or "?"
				print(string.format("[%s] %s (Value: %d) - %s", timestamp, entry.itemName, entry.value, entry.reason))
			end
		elseif args[1] == "top" then
			local topPlayers = PluribusLootHistory:GetTopLootRecipients(10, "value")
			PluribusUtils:Info("=== Top Loot Recipients (by value) ===", "LootHistory")
			for rank, player in ipairs(topPlayers) do
				print(string.format("%d. %s - %d awards, Total: %d, Avg: %d", rank, player.name, player.totalAwards, player.totalValue, player.averageValue))
			end
		elseif args[1] == "items" then
			local topItems = PluribusLootHistory:GetMostAwardedItems(10)
			PluribusUtils:Info("=== Most Awarded Items ===", "LootHistory")
			for rank, item in ipairs(topItems) do
				print(string.format("%d. Item %s - Awarded %d times, Total Value: %d", rank, item.itemId, item.awardCount, item.totalValue))
			end
		elseif args[1] == "export" then
			local export = PluribusLootHistory:ExportLootHistory(500)
			print(export)
		elseif args[1] == "comparison" then
			local report = PluribusLootHistory:ExportPlayerComparisonReport()
			print(report)
		end
	end, {"lh"})
	
	-- DKP UI slash commands
	PluribusCommandRegistry:RegisterCommand("dkpui", function(args, msg)
		if not args or #args == 0 then
			PluribusDKPUI:ToggleWindow()
		elseif args[1] == "leaderboard" or args[1] == "standing" then
			PluribusDKPUI:ShowLeaderboard()
		elseif args[1] == "queue" then
			PluribusDKPUI:ShowLootQueue()
		elseif args[1] == "hide" then
			if PluribusDKPUI.mainWindow then
				PluribusDKPUI.mainWindow:Hide()
			end
		end
	end, {"dkp"})
	
	-- DKP Trading slash commands
	PluribusCommandRegistry:RegisterCommand("dkptrade", function(args, msg)
		if not args or #args == 0 then
			PluribusUtils:Info("=== DKP Trading ===", "DKPTrade")
			PluribusUtils:Info("Usage: /dkptrade <player> <amount>", "DKPTrade")
			PluribusUtils:Info("       /dkptrade history [player]", "DKPTrade")
		elseif args[1] == "history" then
			local history = PluribusDKPTrade:GetTradeHistory()
			if args[2] then
				history = PluribusDKPTrade:GetTradesByPlayer(args[2])
			end
			PluribusUtils:Info("=== DKP Trade History ===", "DKPTrade")
			for i, trade in ipairs(history) do
				print(string.format("%s → %s: %d DKP", trade.from, trade.to, trade.amount))
			end
		elseif args[2] and tonumber(args[2]) then
			local targetPlayer = args[1]
			local amount = tonumber(args[2])
			PluribusDKPTrade:RequestTrade(targetPlayer, amount)
		end
	end, {"trade"})
	
	-- DKP Taxation slash commands
	PluribusCommandRegistry:RegisterCommand("dkptax", function(args, msg)
		if not args or #args == 0 then
			PluribusUtils:Info("=== DKP Taxation Config ===", "Taxation")
			PluribusUtils:Info("Tax Rate: " .. PluribusDKPTaxation.config.taxRatePerGold .. " DKP per gold", "Taxation")
			PluribusUtils:Info("Donation Rate: " .. PluribusDKPTaxation.config.donationRatePerGold .. " DKP per gold", "Taxation")
			PluribusUtils:Info("Enabled: " .. (PluribusDKPTaxation.config.enableTaxation and "Yes" or "No"), "Taxation")
		elseif args[1] == "rate" and args[2] then
			PluribusDKPTaxation:SetTaxRate(tonumber(args[2]))
		elseif args[1] == "donation" and args[2] then
			PluribusDKPTaxation:SetDonationRate(tonumber(args[2]))
		elseif args[1] == "whitelist" and args[2] then
			PluribusDKPTaxation:Whitelist(args[2])
			PluribusUtils:Info("Item " .. args[2] .. " whitelisted", "Taxation")
		elseif args[1] == "blacklist" and args[2] then
			PluribusDKPTaxation:Blacklist(args[2])
			PluribusUtils:Info("Item " .. args[2] .. " blacklisted", "Taxation")
		elseif args[1] == "history" and args[2] then
			local history = PluribusDKPTaxation:GetTaxHistory(args[2])
			PluribusUtils:Info("=== Tax History for " .. args[2] .. " ===", "Taxation")
			for i, entry in ipairs(history) do
				print(string.format("%s: +%d DKP (%d gold) - %s", entry.type, entry.dkp, entry.gold, entry.reason))
			end
			local totalTax = PluribusDKPTaxation:GetTotalTaxed(args[2])
			local totalDonate = PluribusDKPTaxation:GetTotalDonated(args[2])
			PluribusUtils:Info("Total from taxes: " .. totalTax .. " DKP", "Taxation")
			PluribusUtils:Info("Total from donations: " .. totalDonate .. " DKP", "Taxation")
		end
	end, {"tax"})
	
	-- Point auditing slash commands
	PluribusCommandRegistry:RegisterCommand("pointaudit", function(args, msg)
		if not args or #args == 0 then
			PluribusUtils:Info("=== Point Auditing System ===", "Auditing")
			PluribusUtils:Info("Usage: /pointaudit <player> [days]", "Auditing")
			PluribusUtils:Info("       /pointaudit sources <player> - Show EP sources", "Auditing")
			PluribusUtils:Info("       /pointaudit items <player> - Show GP items", "Auditing")
			PluribusUtils:Info("       /pointaudit anomalies <player> - Detect suspicious activity", "Auditing")
		elseif args[1] == "sources" and args[2] then
			local sources = PluribusPointAuditing:GetPlayerEPSources(args[2], 10)
			PluribusUtils:Info("=== EP Sources for " .. args[2] .. " ===", "Auditing")
			for i, source in ipairs(sources) do
				print(string.format("%d. %s: %d EP (%d awards)", i, source.reason, source.amount, source.count))
			end
		elseif args[1] == "items" and args[2] then
			local items = PluribusPointAuditing:GetPlayerGPItems(args[2], 10)
			PluribusUtils:Info("=== GP Items for " .. args[2] .. " ===", "Auditing")
			for i, item in ipairs(items) do
				print(string.format("%d. %s: %d GP total (%.1f avg)", i, item.itemName, item.gp, item.avgCost))
			end
		elseif args[1] == "anomalies" and args[2] then
			local anomalies = PluribusPointAuditing:DetectAnomalies(args[2])
			PluribusUtils:Info("=== Anomalies for " .. args[2] .. " ===", "Auditing")
			if #anomalies == 0 then
				PluribusUtils:Info("No anomalies detected", "Auditing")
			else
				for i, anomaly in ipairs(anomalies) do
					print(string.format("[%s] %s - %s", anomaly.severity, anomaly.type, anomaly.detail))
				end
			end
		elseif args[2] then
			local days = tonumber(args[2]) or 30
			local report = PluribusPointAuditing:GeneratePlayerAuditReport(args[1], days)
			PluribusUtils:Info("=== Audit Report: " .. args[1] .. " (" .. days .. " days) ===", "Auditing")
			print(string.format("EP Gained: %d", report.epGained))
			print(string.format("GP Spent: %d", report.gpSpent))
			print(string.format("Net Points: %+d", report.netPoints))
		end
	end, {"audit"})
	
	-- Register keybind
	PluribusCommandRegistry:RegisterKeybind("TOGGLE_LOOT_MANAGER", "Toggle Loot Manager", function()
		PluribusLootUI:Toggle()
	end)
	
	PluribusCommandRegistry:RegisterKeybind("TOGGLE_DKP_UI", "Toggle DKP UI", function()
		PluribusDKPUI:ToggleWindow()
	end)
	
	-- Mark feature as enabled by default
	PluribusStorageManager:SetFeatureEnabled(PLURIBUS_FEATURES.LOOT, true)
	
	PluribusUtils:Info("PluribusLoot initialized successfully", "PluribusLoot")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.FEATURE_ENABLED, PLURIBUS_FEATURES.LOOT, true)
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Loot management",
			author = "Pluribus Suite Team",
			category = "Loot",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusLoot" then
		-- Wait for PluribusCore to be ready
		if _G.PluribusCore and _G.PluribusDataManager then
			InitializePluribusLoot()
		else
			-- Defer initialization if core isn't ready
			local retry = 0
			local retryFrame = CreateFrame("Frame")
			retryFrame:SetScript("OnUpdate", function(f, elapsed)
				retry = retry + elapsed
				if retry > 0.5 then
					if _G.PluribusCore and _G.PluribusDataManager then
						InitializePluribusLoot()
						f:Hide()
					end
				end
			end)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


