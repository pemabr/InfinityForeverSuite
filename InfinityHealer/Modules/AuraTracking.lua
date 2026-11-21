-- Aura Tracking Module
local InfinityAuraTracking = {}
_G.InfinityAuraTracking = InfinityAuraTracking

InfinityAuraTracking.auraCache = {}
InfinityAuraTracking.dispelablDebuffs = {}

function InfinityAuraTracking:Initialize()
	InfinityUtils:Info("Aura tracking initialized", "Healer")
end

function InfinityAuraTracking:UpdateAuras(unitToken)
	if not self.auraCache[unitToken] then
		self.auraCache[unitToken] = {}
	end
	
	local auras = {}
	for i = 1, 32 do
		local name, icon, count, dispelType, duration, expirationTime = UnitAura(unitToken, i, "HELPFUL")
		if name then
			table.insert(auras, {name = name, icon = icon, duration = duration, dispel = dispelType})
		end
	end
	
	self.auraCache[unitToken] = auras
	return auras
end

function InfinityAuraTracking:GetAuras(unitToken)
	return self.auraCache[unitToken] or {}
end

return InfinityAuraTracking
