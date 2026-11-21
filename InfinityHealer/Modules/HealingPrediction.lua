-- Healing Prediction Module
-- Tracks incoming heals and predicts health values

local InfinityHealingPrediction = {}
_G.InfinityHealingPrediction = InfinityHealingPrediction

InfinityHealingPrediction.incomingHeals = {} -- {unitToken = [{amount, healer, time, spell}]}
InfinityHealingPrediction.hotTracking = {} -- {unitToken = [{name, duration, start, caster}]}
InfinityHealingPrediction.healEvents = {}

function InfinityHealingPrediction:Initialize()
	InfinityUtils:Info("Healing prediction initialized", "Prediction")
end

function InfinityHealingPrediction:RegisterIncomingHeal(targetUnit, amount, healer, spellId)
	if not self.incomingHeals[targetUnit] then
		self.incomingHeals[targetUnit] = {}
	end
	
	table.insert(self.incomingHeals[targetUnit], {
		amount = amount,
		healer = healer,
		time = GetTime(),
		spellId = spellId,
	})
end

function InfinityHealingPrediction:GetPredictedHealth(unitToken)
	local current = UnitHealth(unitToken)
	local maxHealth = UnitHealthMax(unitToken)
	local incoming = 0
	
	if self.incomingHeals[unitToken] then
		local now = GetTime()
		for _, heal in ipairs(self.incomingHeals[unitToken]) do
			if now - heal.time < 2 then
				incoming = incoming + heal.amount
			end
		end
	end
	
	return math.min(current + incoming, maxHealth), incoming
end

function InfinityHealingPrediction:TrackHoT(unitToken, spellName, duration, caster)
	if not self.hotTracking[unitToken] then
		self.hotTracking[unitToken] = {}
	end
	
	table.insert(self.hotTracking[unitToken], {
		name = spellName,
		duration = duration,
		start = GetTime(),
		caster = caster,
	})
end

function InfinityHealingPrediction:GetHoTsOnUnit(unitToken)
	local hots = {}
	
	if self.hotTracking[unitToken] then
		local now = GetTime()
		for _, hot in ipairs(self.hotTracking[unitToken]) do
			local elapsed = now - hot.start
			if elapsed < hot.duration then
				table.insert(hots, {
					name = hot.name,
					remaining = hot.duration - elapsed,
					caster = hot.caster,
				})
			end
		end
	end
	
	return hots
end

function InfinityHealingPrediction:ClearExpiredHeals()
	local now = GetTime()
	
	for unitToken, heals in pairs(self.incomingHeals) do
		for i = #heals, 1, -1 do
			if now - heals[i].time > 2 then
				table.remove(heals, i)
			end
		end
		
		if #heals == 0 then
			self.incomingHeals[unitToken] = nil
		end
	end
end

return InfinityHealingPrediction
