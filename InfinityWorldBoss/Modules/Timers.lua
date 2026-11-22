local Timers = {}
_G.InfinityWorldBossTimers = Timers

function Timers:Initialize()
	if self.frame then return end
	local frame, elapsed = CreateFrame("Frame"), 0
	frame:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed < 5 then return end
		elapsed = 0
		self:Update()
	end)
	self.frame = frame
end

function Timers:Update()
	local now = time()
	for _, entry in ipairs(InfinityWorldBossCore:GetAllBosses()) do
		local boss = entry.boss
		if boss.lastKilled and not boss.notified and now >= boss.lastKilled + boss.interval then
			boss.notified = true
			print("World boss estimate elapsed: " .. boss.name .. ". Actual spawn status is unknown.")
		end
	end
	local ui = _G.InfinityWorldBossUI
	if ui and ui.frame and ui.frame:IsShown() then ui:Refresh() end
end

return Timers
