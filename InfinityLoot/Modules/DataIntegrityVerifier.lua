-- Data Integrity Verifier
-- Validates data consistency and detects corruption

local DataIntegrityVerifier = {
	errorLog = {},
	warningLog = {},
	checksums = {},
}

-- Verify EPGP data integrity
function DataIntegrityVerifier:VerifyEPGPData()
	local errors = {}
	
	if not InfinityLootEPGP or not InfinityLootEPGP.playerData then
		table.insert(errors, "EPGP system not initialized")
		return errors
	end
	
	for playerName, data in pairs(InfinityLootEPGP.playerData) do
		-- Validate required fields
		if type(data.ep) ~= "number" or data.ep < 0 then
			table.insert(errors, "Invalid EP for " .. playerName .. ": " .. tostring(data.ep))
		end
		
		if type(data.gp) ~= "number" or data.gp < 0 then
			table.insert(errors, "Invalid GP for " .. playerName .. ": " .. tostring(data.gp))
		end
		
		-- Validate priority (EP / max(GP, 1))
		if data.priority then
			local expectedPriority = data.ep / math.max(data.gp, 1)
			if math.abs(data.priority - expectedPriority) > 0.01 then
				table.insert(errors, "Priority mismatch for " .. playerName)
			end
		end
		
		-- Validate timestamps
		if data.lastUpdated and type(data.lastUpdated) ~= "number" then
			table.insert(errors, "Invalid timestamp for " .. playerName)
		end
	end
	
	return errors
end

-- Verify loot history integrity
function DataIntegrityVerifier:VerifyLootHistory()
	local errors = {}
	
	if not InfinityLootHistory or not InfinityLootHistory.awards then
		return errors
	end
	
	for i, award in ipairs(InfinityLootHistory.awards) do
		-- Validate required fields
		if not award.playerName or award.playerName == "" then
			table.insert(errors, "Missing player name at index " .. i)
		end
		
		if not award.itemName or award.itemName == "" then
			table.insert(errors, "Missing item name at index " .. i)
		end
		
		if type(award.gp) ~= "number" or award.gp < 0 then
			table.insert(errors, "Invalid GP value at index " .. i)
		end
		
		if type(award.timestamp) ~= "number" then
			table.insert(errors, "Invalid timestamp at index " .. i)
		end
	end
	
	return errors
end

-- Verify DKP transaction history
function DataIntegrityVerifier:VerifyDKPTransactions()
	local errors = {}
	
	if not InfinityPointAuditing or not InfinityPointAuditing.transactions then
		return errors
	end
	
	for i, txn in ipairs(InfinityPointAuditing.transactions) do
		-- Validate transaction type
		local validTypes = {
			ep_awarded = true,
			gp_awarded = true,
			decay_applied = true,
			dkp_trade = true,
			dkp_tax = true,
		}
		
		if not validTypes[txn.type] then
			table.insert(errors, "Unknown transaction type at index " .. i .. ": " .. tostring(txn.type))
		end
		
		-- Validate amounts
		if type(txn.amount) ~= "number" then
			table.insert(errors, "Invalid amount at transaction index " .. i)
		end
		
		if type(txn.timestamp) ~= "number" or txn.timestamp <= 0 then
			table.insert(errors, "Invalid timestamp at transaction index " .. i)
		end
	end
	
	return errors
end

-- Check for orphaned references
function DataIntegrityVerifier:CheckOrphanedReferences()
	local orphans = {}
	local playerNames = {}
	
	-- Collect all player names
	if InfinityLootEPGP and InfinityLootEPGP.playerData then
		for name in pairs(InfinityLootEPGP.playerData) do
			playerNames[name] = true
		end
	end
	
	-- Check loot history for missing players
	if InfinityLootHistory and InfinityLootHistory.awards then
		for i, award in ipairs(InfinityLootHistory.awards) do
			if award.playerName and not playerNames[award.playerName] then
				table.insert(orphans, {
					type = "loot_history",
					player = award.playerName,
					index = i,
				})
			end
		end
	end
	
	-- Check transactions for missing players
	if InfinityPointAuditing and InfinityPointAuditing.transactions then
		for i, txn in ipairs(InfinityPointAuditing.transactions) do
			if txn.playerName and not playerNames[txn.playerName] then
				table.insert(orphans, {
					type = "transaction",
					player = txn.playerName,
					index = i,
				})
			end
		end
	end
	
	return orphans
end

-- Verify data consistency
function DataIntegrityVerifier:VerifyDataConsistency()
	local errors = {}
	
	if not InfinityLootEPGP or not InfinityLootHistory then
		return errors
	end
	
	-- Sum of loot should equal GP in player data
	local gpByPlayer = {}
	
	if InfinityLootHistory.awards then
		for i, award in ipairs(InfinityLootHistory.awards) do
			if not gpByPlayer[award.playerName] then
				gpByPlayer[award.playerName] = 0
			end
			gpByPlayer[award.playerName] = gpByPlayer[award.playerName] + award.gp
		end
	end
	
	-- Compare with EPGP data
	for playerName, totalGP in pairs(gpByPlayer) do
		if InfinityLootEPGP.playerData[playerName] then
			local recordedGP = InfinityLootEPGP.playerData[playerName].gp
			if recordedGP ~= totalGP then
				table.insert(errors, "GP mismatch for " .. playerName .. ": recorded=" .. recordedGP .. ", calculated=" .. totalGP)
			end
		end
	end
	
	return errors
end

-- Generate comprehensive verification report
function DataIntegrityVerifier:GenerateReport()
	local report = {
		timestamp = GetTime(),
		sections = {},
		totalErrors = 0,
		totalWarnings = 0,
	}
	
	local epgpErrors = self:VerifyEPGPData()
	report.sections.epgp = {
		name = "EPGP System",
		errors = epgpErrors,
		passed = #epgpErrors == 0,
	}
	report.totalErrors = report.totalErrors + #epgpErrors
	
	local historyErrors = self:VerifyLootHistory()
	report.sections.history = {
		name = "Loot History",
		errors = historyErrors,
		passed = #historyErrors == 0,
	}
	report.totalErrors = report.totalErrors + #historyErrors
	
	local txnErrors = self:VerifyDKPTransactions()
	report.sections.transactions = {
		name = "DKP Transactions",
		errors = txnErrors,
		passed = #txnErrors == 0,
	}
	report.totalErrors = report.totalErrors + #txnErrors
	
	local orphans = self:CheckOrphanedReferences()
	report.sections.orphans = {
		name = "Orphaned References",
		errors = orphans,
		passed = #orphans == 0,
	}
	report.totalWarnings = report.totalWarnings + #orphans
	
	local consistency = self:VerifyDataConsistency()
	report.sections.consistency = {
		name = "Data Consistency",
		errors = consistency,
		passed = #consistency == 0,
	}
	report.totalErrors = report.totalErrors + #consistency
	
	return report
end

-- Display integrity report
function DataIntegrityVerifier:DisplayReport()
	local report = self:GenerateReport()
	
	print("|cffffd700=== DATA INTEGRITY VERIFICATION ===|r")
	print("Timestamp: " .. date("%H:%M:%S", report.timestamp))
	print("")
	
	for sectionName, section in pairs(report.sections) do
		if section.passed then
			print("|cff00ff00✓|r " .. section.name .. " - OK")
		else
			print("|cffff0000✗|r " .. section.name .. " - " .. #section.errors .. " error(s)")
			for i = 1, math.min(5, #section.errors) do
				print("    " .. section.errors[i].type or section.errors[i])
			end
			if #section.errors > 5 then
				print("    ... and " .. (#section.errors - 5) .. " more")
			end
		end
	end
	
	print("")
	print("|cffffd700Total Errors:|r " .. report.totalErrors)
	print("|cffffd700Total Warnings:|r " .. report.totalWarnings)
	
	if report.totalErrors == 0 and report.totalWarnings == 0 then
		print("|cff00ff00✓ All data integrity checks passed!|r")
	else
		print("|cffff0000⚠ Data integrity issues detected|r")
	end
end

-- Auto-repair data
function DataIntegrityVerifier:AutoRepair()
	local repaired = 0
	
	-- Remove orphaned references
	local orphans = self:CheckOrphanedReferences()
	for i, orphan in ipairs(orphans) do
		if orphan.type == "loot_history" then
			table.remove(InfinityLootHistory.awards, orphan.index)
			repaired = repaired + 1
		end
	end
	
	-- Recalculate priorities
	if InfinityLootEPGP then
		for playerName, data in pairs(InfinityLootEPGP.playerData) do
			InfinityLootEPGP:UpdatePlayerPriority(playerName)
			repaired = repaired + 1
		end
	end
	
	return repaired
end

-- Register slash commands
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityLoot" then
		_G.InfinityDataIntegrityVerifier = DataIntegrityVerifier
		
		SLASH_VERIFY1 = "/verify"
		SlashCmdList.VERIFY = function()
			DataIntegrityVerifier:DisplayReport()
		end
		
		SLASH_REPAIR1 = "/repair"
		SlashCmdList.REPAIR = function()
			local count = DataIntegrityVerifier:AutoRepair()
			InfinityUtils:Info("Repaired " .. count .. " data issues", "DataIntegrity")
			DataIntegrityVerifier:DisplayReport()
		end
		
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

return DataIntegrityVerifier
