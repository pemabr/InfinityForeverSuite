-- Range Checking Module
local PluribusRangeChecking = {}
_G.PluribusRangeChecking = PluribusRangeChecking

PluribusRangeChecking.rangeCache = {}
PluribusRangeChecking.lastRangeCheck = {}

function PluribusRangeChecking:Initialize()
	PluribusUtils:Info("Range checking initialized", "Healer")
end

function PluribusRangeChecking:CheckRange(unitToken, maxRange)
	maxRange = maxRange or 40
	
	if not UnitExists(unitToken) then
		return false
	end
	
	local inRange = UnitInRange(unitToken)
	self.rangeCache[unitToken] = inRange
	
	return inRange
end

function PluribusRangeChecking:IsInRange(unitToken)
	return self.rangeCache[unitToken] or false
end

function PluribusRangeChecking:RefreshRange(unitToken)
	return self:CheckRange(unitToken)
end

return PluribusRangeChecking
