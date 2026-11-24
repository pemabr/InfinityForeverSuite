-- Aura Tracking Module
local PluribusAuraTracking = {}
_G.PluribusAuraTracking = PluribusAuraTracking

PluribusAuraTracking.auraCache = {}
PluribusAuraTracking.dispelablDebuffs = {}

function PluribusAuraTracking:Initialize()
	PluribusUtils:Info("Aura tracking initialized", "Healer")
end

function PluribusAuraTracking:UpdateAuras(unitToken)
	if not self.auraCache[unitToken] then
		self.auraCache[unitToken] = {}
	end
	
	local auras = {}
	for i = 1, 32 do
		local name, icon, count, dispelType, duration, expirationTime = PluribusUtils:GetUnitAura(unitToken, i, "HELPFUL")
		if not name then break end
		table.insert(auras, {name = name, icon = icon, duration = duration, dispel = dispelType})
	end
	
	self.auraCache[unitToken] = auras
	return auras
end

function PluribusAuraTracking:GetAuras(unitToken)
	return self.auraCache[unitToken] or {}
end

return PluribusAuraTracking
