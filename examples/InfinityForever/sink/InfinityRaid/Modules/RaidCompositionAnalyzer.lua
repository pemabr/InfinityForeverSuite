-- Raid Composition Analyzer
-- Analyzes raid composition, role balance, and optimization

local RaidCompositionAnalyzer = {
	currentRaid = {
		players = {}, -- {name = {class, role, level, spec}}
		composition = {}, -- {class = count}
		roleBalance = {}, -- {tank = count, healer = count, dps = count}
		bosses = {}, -- {name = {health, phase, mechanics}}
	},
	
	config = {
		optimalTankCount = 2,
		optimalHealerCount = 4,
		optimalDpsCount = 14,
		requirementThreshold = 20, -- DPS requirement per 1000 boss health
	},
}

_G.InfinityRaidCompositionAnalyzer = RaidCompositionAnalyzer

-- Initialize analyzer
function RaidCompositionAnalyzer:Initialize()
	InfinityUtils:Info("Raid composition analyzer initialized", "Raid")
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if event == "GROUP_ROSTER_UPDATE" then
			RaidCompositionAnalyzer:OnRosterUpdate()
		else
			RaidCompositionAnalyzer:RefreshAnalysis()
		end
	end)
	
	-- Subscribe to messages
	InfinityMessaging:Subscribe("raid_composition_needed", function()
		RaidCompositionAnalyzer:PublishAnalysis()
	end)
end

-- Update raid composition
function RaidCompositionAnalyzer:OnRosterUpdate()
	self:ScanRaid()
	self:AnalyzeComposition()
	self:PublishAnalysis()
end

-- Scan current raid
function RaidCompositionAnalyzer:ScanRaid()
	self.currentRaid.players = {}
	self.currentRaid.composition = {}
	self.currentRaid.roleBalance = {
		tank = 0,
		healer = 0,
		dps = 0,
	}
	
	local raidSize = GetNumGroupMembers()
	
	for i = 1, raidSize do
		local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
		
		if name then
			self.currentRaid.players[name] = {
				class = class,
				fileName = fileName,
				level = level,
				role = role or "DAMAGER",
				subgroup = subgroup,
				online = online,
				isDead = isDead,
			}
			
			-- Update composition count
			self.currentRaid.composition[fileName] = (self.currentRaid.composition[fileName] or 0) + 1
			
			-- Update role balance
			if role == "TANK" then
				self.currentRaid.roleBalance.tank = self.currentRaid.roleBalance.tank + 1
			elseif role == "HEALER" then
				self.currentRaid.roleBalance.healer = self.currentRaid.roleBalance.healer + 1
			elseif role == "DAMAGER" then
				self.currentRaid.roleBalance.dps = self.currentRaid.roleBalance.dps + 1
			end
		end
	end
end

-- Analyze raid composition
function RaidCompositionAnalyzer:AnalyzeComposition()
	local analysis = {
		totalPlayers = InfinityUtils:TableSize(self.currentRaid.players),
		composition = self.currentRaid.composition,
		roleBalance = self.currentRaid.roleBalance,
		issues = {},
		recommendations = {},
	}
	
	-- Check role balance
	local tank = analysis.roleBalance.tank
	local healer = analysis.roleBalance.healer
	local dps = analysis.roleBalance.dps
	
	if tank < self.config.optimalTankCount then
		table.insert(analysis.issues, "Tank shortage: " .. tank .. "/" .. self.config.optimalTankCount)
		table.insert(analysis.recommendations, "Need more tanks")
	end
	
	if healer < self.config.optimalHealerCount then
		table.insert(analysis.issues, "Healer shortage: " .. healer .. "/" .. self.config.optimalHealerCount)
		table.insert(analysis.recommendations, "Need more healers")
	end
	
	if dps < self.config.optimalDpsCount then
		table.insert(analysis.issues, "DPS shortage: " .. dps .. "/" .. self.config.optimalDpsCount)
		table.insert(analysis.recommendations, "Need more DPS")
	end
	
	-- Check class diversity
	local classCount = InfinityUtils:TableSize(analysis.composition)
	if classCount < 4 then
		table.insert(analysis.recommendations, "Low class diversity (" .. classCount .. " classes)")
	end
	
	-- Check level requirements
	for name, player in pairs(self.currentRaid.players) do
		if player.level < UnitLevel("player") - 5 then
			table.insert(analysis.issues, name .. " is under-leveled")
		end
	end
	
	self.currentRaid.analysis = analysis
	return analysis
end

-- Publish analysis
function RaidCompositionAnalyzer:PublishAnalysis()
	if self.currentRaid.analysis then
		InfinityMessaging:Publish("raid_analysis", self.currentRaid.analysis)
	end
end

-- Get composition summary
function RaidCompositionAnalyzer:GetCompositionSummary()
	local summary = ""
	
	for class, count in pairs(self.currentRaid.composition) do
		if summary ~= "" then
			summary = summary .. ", "
		end
		summary = summary .. count .. "x " .. class
	end
	
	return summary
end

-- Get DPS potential estimate
function RaidCompositionAnalyzer:EstimateDPSPotential()
	-- Very rough estimate based on class and level
	-- Would need extensive data to be accurate
	
	local totalDPS = 0
	
	for name, player in pairs(self.currentRaid.players) do
		if player.role == "DAMAGER" then
			local baseDPS = player.level * 2 -- Very rough estimate
			totalDPS = totalDPS + baseDPS
		end
	end
	
	return totalDPS
end

-- Get role statistics
function RaidCompositionAnalyzer:GetRoleStats()
	local stats = {}
	
	for name, player in pairs(self.currentRaid.players) do
		local role = player.role or "DAMAGER"
		if not stats[role] then
			stats[role] = {
				count = 0,
				players = {},
			}
		end
		stats[role].count = stats[role].count + 1
		table.insert(stats[role].players, name)
	end
	
	return stats
end

-- Refresh analysis
function RaidCompositionAnalyzer:RefreshAnalysis()
	self:ScanRaid()
	self:AnalyzeComposition()
end

-- Display raid composition
function RaidCompositionAnalyzer:DisplayComposition()
	print("|cffffd700=== RAID COMPOSITION ===|r")
	print("Total Players: " .. self.currentRaid.analysis.totalPlayers)
	print("Tanks: " .. self.currentRaid.roleBalance.tank)
	print("Healers: " .. self.currentRaid.roleBalance.healer)
	print("DPS: " .. self.currentRaid.roleBalance.dps)
	print("\nClass Breakdown: " .. self:GetCompositionSummary())
	
	if #self.currentRaid.analysis.issues > 0 then
		print("\n|cffff0000Issues:|r")
		for _, issue in ipairs(self.currentRaid.analysis.issues) do
			print("  - " .. issue)
		end
	end
	
	if #self.currentRaid.analysis.recommendations > 0 then
		print("\n|cff00ff00Recommendations:|r")
		for _, rec in ipairs(self.currentRaid.analysis.recommendations) do
			print("  - " .. rec)
		end
	end
end

return RaidCompositionAnalyzer
