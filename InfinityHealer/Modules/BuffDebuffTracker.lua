-- Buff/Debuff Tracker
-- Tracks important buffs and debuffs on raid members

local BuffDebuffTracker = {
	buffs = {}, -- {unitId = {buffId = {name, icon, duration, expireTime}}}
	debuffs = {}, -- {unitId = {debuffId = {name, icon, duration, expireTime}}}
	
	config = {
		trackRaidBuffs = true,
		trackRaidDebuffs = true,
		notifyDebuffRemoval = true,
		scanInterval = 1.0, -- seconds between scans
	},
	
	importantBuffs = {
		"Power Word: Shield",
		"Renew",
		"Lifebloom",
		"Rejuvenation",
		"Regrowth",
		"Divine Aegis",
	},
	
	importantDebuffs = {
		"Poison",
		"Disease",
		"Curse",
		"Magic",
	},
}

_G.InfinityBuffDebuffTracker = BuffDebuffTracker

-- Initialize buff/debuff tracking
function BuffDebuffTracker:Initialize()
	InfinityUtils:Info("Buff/debuff tracker initialized", "Healer")
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("UNIT_AURA")
	frame:RegisterEvent("UNIT_BUFF")
	frame:RegisterEvent("UNIT_DEBUFF")
	
	frame:SetScript("OnEvent", function(f, event, unit)
		if BuffDebuffTracker.config.trackRaidBuffs or BuffDebuffTracker.config.trackRaidDebuffs then
			BuffDebuffTracker:OnAuraUpdate(unit)
		end
	end)
	
	-- Enable periodic scans
	C_Timer.NewTicker(self.config.scanInterval, function()
		BuffDebuffTracker:ScanRaidAuras()
	end)
end

-- Called when unit aura updates
function BuffDebuffTracker:OnAuraUpdate(unit)
	self:UpdateUnitBuffs(unit)
	self:UpdateUnitDebuffs(unit)
end

-- Scan all raid members for auras
function BuffDebuffTracker:ScanRaidAuras()
	local raidSize = GetNumGroupMembers()
	
	for i = 1, raidSize do
		local unit = "raid" .. i
		self:UpdateUnitBuffs(unit)
		self:UpdateUnitDebuffs(unit)
	end
	
	-- Also scan player
	self:UpdateUnitBuffs("player")
	self:UpdateUnitDebuffs("player")
end

-- Update buffs for unit
function BuffDebuffTracker:UpdateUnitBuffs(unit)
	if not self.buffs[unit] then
		self.buffs[unit] = {}
	end
	
	local index = 1
	local buffData = {}
	
	while true do
		local name, icon, count, debuffType, duration, expireTime = InfinityUtils:GetUnitAura(unit, index, "HELPFUL")
		if not name then
			break
		end
		
		buffData[name] = {
			name = name,
			icon = icon,
			count = count,
			duration = duration,
			expireTime = expireTime,
			remaining = expireTime - GetTime(),
		}
		
		index = index + 1
	end
	
	-- Check for new buffs
	for name, buff in pairs(buffData) do
		if not self.buffs[unit][name] then
			self:OnBuffApplied(unit, name, buff)
		end
		self.buffs[unit][name] = buff
	end
	
	-- Check for removed buffs
	for name, _ in pairs(self.buffs[unit]) do
		if not buffData[name] then
			self:OnBuffRemoved(unit, name)
			self.buffs[unit][name] = nil
		end
	end
end

-- Update debuffs for unit
function BuffDebuffTracker:UpdateUnitDebuffs(unit)
	if not self.debuffs[unit] then
		self.debuffs[unit] = {}
	end
	
	local index = 1
	local debuffData = {}
	
	while true do
		local name, icon, count, debuffType, duration, expireTime = InfinityUtils:GetUnitAura(unit, index, "HARMFUL")
		if not name then
			break
		end
		
		debuffData[name] = {
			name = name,
			icon = icon,
			count = count,
			type = debuffType,
			duration = duration,
			expireTime = expireTime,
			remaining = expireTime - GetTime(),
		}
		
		index = index + 1
	end
	
	-- Check for new debuffs
	for name, debuff in pairs(debuffData) do
		if not self.debuffs[unit][name] then
			self:OnDebuffApplied(unit, name, debuff)
		end
		self.debuffs[unit][name] = debuff
	end
	
	-- Check for removed debuffs
	for name, _ in pairs(self.debuffs[unit]) do
		if not debuffData[name] then
			self:OnDebuffRemoved(unit, name)
			self.debuffs[unit][name] = nil
		end
	end
end

-- Called when buff is applied
function BuffDebuffTracker:OnBuffApplied(unit, name, buffData)
	InfinityMessaging:Publish("buff_applied", unit, name, buffData)
end

-- Called when buff is removed
function BuffDebuffTracker:OnBuffRemoved(unit, name)
	InfinityMessaging:Publish("buff_removed", unit, name)
end

-- Called when debuff is applied
function BuffDebuffTracker:OnDebuffApplied(unit, name, debuffData)
	if self.config.notifyDebuffRemoval then
		local unitName = UnitName(unit) or unit
		InfinityUtils:Info(unitName .. " has " .. debuffData.type .. ": " .. name, "Healer")
	end
	
	InfinityMessaging:Publish("debuff_applied", unit, name, debuffData)
end

-- Called when debuff is removed
function BuffDebuffTracker:OnDebuffRemoved(unit, name)
	InfinityMessaging:Publish("debuff_removed", unit, name)
end

-- Get buffs on unit
function BuffDebuffTracker:GetUnitBuffs(unit)
	return self.buffs[unit] or {}
end

-- Get debuffs on unit
function BuffDebuffTracker:GetUnitDebuffs(unit)
	return self.debuffs[unit] or {}
end

-- Check if unit has buff
function BuffDebuffTracker:HasBuff(unit, buffName)
	local buffs = self:GetUnitBuffs(unit)
	return buffs[buffName] ~= nil
end

-- Check if unit has debuff
function BuffDebuffTracker:HasDebuff(unit, debuffName)
	local debuffs = self:GetUnitDebuffs(unit)
	return debuffs[debuffName] ~= nil
end

-- Get buff remaining time
function BuffDebuffTracker:GetBuffRemaining(unit, buffName)
	local buffs = self:GetUnitBuffs(unit)
	if buffs[buffName] then
		return math.max(0, buffs[buffName].expireTime - GetTime())
	end
	return 0
end

-- Get debuff remaining time
function BuffDebuffTracker:GetDebuffRemaining(unit, debuffName)
	local debuffs = self:GetUnitDebuffs(unit)
	if debuffs[debuffName] then
		return math.max(0, debuffs[debuffName].expireTime - GetTime())
	end
	return 0
end

-- Get all important buffs on unit
function BuffDebuffTracker:GetImportantBuffs(unit)
	local buffs = self:GetUnitBuffs(unit)
	local important = {}
	
	for _, buffName in ipairs(self.importantBuffs) do
		if buffs[buffName] then
			table.insert(important, buffs[buffName])
		end
	end
	
	return important
end

-- Get all important debuffs on unit
function BuffDebuffTracker:GetImportantDebuffs(unit)
	local debuffs = self:GetUnitDebuffs(unit)
	local important = {}
	
	for _, debuffName in ipairs(self.importantDebuffs) do
		if debuffs[debuffName] then
			table.insert(important, debuffs[debuffName])
		end
	end
	
	return important
end

-- Display buff status for player
function BuffDebuffTracker:DisplayBuffs(unit)
	unit = unit or "player"
	local unitName = UnitName(unit) or unit
	
	print("|cffffd700=== BUFFS & DEBUFFS ===|r")
	print("Unit: " .. unitName)
	
	local buffs = self:GetImportantBuffs(unit)
	print("\n|cffccccccBuffs:|r")
	if #buffs > 0 then
		for _, buff in ipairs(buffs) do
			local remaining = math.max(0, buff.expireTime - GetTime())
			print("  " .. buff.name .. " (" .. string.format("%.1f", remaining) .. "s)")
		end
	else
		print("  None")
	end
	
	local debuffs = self:GetImportantDebuffs(unit)
	print("\n|cffccccccDebuffs:|r")
	if #debuffs > 0 then
		for _, debuff in ipairs(debuffs) do
			local remaining = math.max(0, debuff.expireTime - GetTime())
			print("  " .. debuff.type .. ": " .. debuff.name .. " (" .. string.format("%.1f", remaining) .. "s)")
		end
	else
		print("  None")
	end
end

return BuffDebuffTracker
