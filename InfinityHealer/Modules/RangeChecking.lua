-- Range Checking Module
local InfinityRangeChecking = {}
_G.InfinityRangeChecking = InfinityRangeChecking

InfinityRangeChecking.rangeCache = {}
InfinityRangeChecking.lastRangeCheck = {}

function InfinityRangeChecking:Initialize()
	InfinityUtils:Info("Range checking initialized", "Healer")
end

function InfinityRangeChecking:CheckRange(unitToken, maxRange)
	maxRange = maxRange or 40
	
	if not UnitExists(unitToken) then
		return false
	end
	
	local inRange = UnitInRange(unitToken)
	self.rangeCache[unitToken] = inRange
	
	return inRange
end

function InfinityRangeChecking:IsInRange(unitToken)
	return self.rangeCache[unitToken] or false
end

function InfinityRangeChecking:RefreshRange(unitToken)
	return self:CheckRange(unitToken)
end

return InfinityRangeChecking
