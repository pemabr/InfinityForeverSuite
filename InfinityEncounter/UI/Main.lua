-- InfinityEncounter Main UI
-- Live Boss Health Bar, Ability Countdown StatusBars, and 10s Pull Timer Controls

local InfinityEncounterUI = {
	lastUpdate = 0,
	timerBars = {},
}
_G.InfinityEncounterUI = InfinityEncounterUI

function InfinityEncounterUI:Initialize()
	if self.initialized and self.frame then return end

	local frame = InfinityUIFramework:CreateFrame(
		"InfinityEncounterMainFrame",
		UIParent,
		460,
		380,
		"Infinity Encounter",
		"Boss Timers & Alerts"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)

	-- Quick controls
	local pullBtn = InfinityUIFramework:CreateButton(frame, "Pull 10s", 88, 24, function()
		if _G.InfinityEncounterTimer and _G.InfinityEncounterTimer.CreateTimer then
			_G.InfinityEncounterTimer:CreateTimer("Pull Countdown", 10)
		end
		if _G.InfinityEncounterAlerts and _G.InfinityEncounterAlerts.SendAlert then
			_G.InfinityEncounterAlerts:SendAlert("Pull in 10 seconds!", _G.InfinityEncounterAlerts.LEVEL_WARNING)
		end
		InfinityUIFramework:ShowNotification("|cfffbbf24Pull timer started: 10s|r", 2.5)
		InfinityEncounterUI:Update(true)
	end, true)
	pullBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)

	local testBtn = InfinityUIFramework:CreateButton(frame, "Test Timers", 96, 24, function()
		if _G.InfinityEncounterTimer and _G.InfinityEncounterTimer.CreateTimer then
			_G.InfinityEncounterTimer:CreateTimer("Locust Swarm", 25)
			_G.InfinityEncounterTimer:CreateTimer("Frost Blast", 18)
			_G.InfinityEncounterTimer:CreateTimer("Void Zone", 12)
		end
		InfinityEncounterUI:Update(true)
	end)
	testBtn:SetPoint("LEFT", pullBtn, "RIGHT", 8, 0)

	local resetBtn = InfinityUIFramework:CreateButton(frame, "Reset", 74, 24, function()
		if _G.InfinityEncounterMgr and _G.InfinityEncounterMgr.Reset then _G.InfinityEncounterMgr:Reset() end
		if _G.InfinityEncounterAbilities and _G.InfinityEncounterAbilities.Reset then _G.InfinityEncounterAbilities:Reset() end
		if _G.InfinityEncounterAlerts and _G.InfinityEncounterAlerts.Clear then _G.InfinityEncounterAlerts:Clear() end
		if _G.InfinityEncounterTimer and _G.InfinityEncounterTimer.timers then _G.InfinityEncounterTimer.timers = {} end
		InfinityEncounterUI:Update(true)
	end)
	resetBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)

	-- Boss health bar card
	local bossCard = InfinityUIFramework:CreateCard(frame, 436, 74, "Active Boss Target")
	bossCard:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -80)

	local bossBar = InfinityUIFramework:CreateStatusBar(bossCard, 412, 26, 0.88, 0.24, 0.26)
	bossBar:SetPoint("TOPLEFT", bossCard, "TOPLEFT", 12, -34)
	bossBar:SetBarData(0, "No boss engaged", "Idle")
	self.bossBar = bossBar

	-- Active ability timers card
	local timersCard = InfinityUIFramework:CreateCard(frame, 436, 206, "Upcoming Boss Ability Timers")
	timersCard:SetPoint("TOPLEFT", bossCard, "BOTTOMLEFT", 0, -10)
	self.timersCard = timersCard

	-- Pre-allocate 6 reusable StatusBars for zero-GC live 0.1s updates
	self.timerBars = {}
	for i = 1, 6 do
		local tb = InfinityUIFramework:CreateStatusBar(timersCard, 412, 24, 0.16, 0.56, 0.94)
		tb:SetPoint("TOPLEFT", timersCard, "TOPLEFT", 12, -32 - (i - 1) * 28)
		tb:Hide()
		self.timerBars[i] = tb
	end

	local emptyLbl = InfinityUIFramework:CreateLabel(timersCard, "|cff94a3b8No active ability timers. Click 'Pull 10s' or 'Test Timers' to preview.|r")
	emptyLbl:SetPoint("TOPLEFT", timersCard, "TOPLEFT", 12, -36)
	self.emptyTimersLabel = emptyLbl

	frame:Hide()
	self.frame = frame
	self.initialized = true
end

function InfinityEncounterUI:Toggle()
	if not self.initialized then self:Initialize() end
	self.frame:SetShown(not self.frame:IsShown())
	if self.frame:IsShown() then self:Update(true) end
end

function InfinityEncounterUI:Show()
	if not self.initialized then self:Initialize() end
	self.frame:Show()
	self:Update(true)
end

function InfinityEncounterUI:Hide()
	if self.frame then self.frame:Hide() end
end

function InfinityEncounterUI:Update(force)
	if not self.initialized or not self.frame or not self.frame:IsShown() then return end
	local now = GetTime and GetTime() or 0
	if not force and (now - self.lastUpdate) < 0.1 then return end
	self.lastUpdate = now

	-- Boss health status bar
	local boss = (_G.InfinityEncounterMgr and _G.InfinityEncounterMgr.GetCurrentBoss) and _G.InfinityEncounterMgr:GetCurrentBoss() or nil
	if boss then
		local pct = boss.healthPercent or 0
		self.bossBar:SetBarData(pct, "|cffffffff" .. tostring(boss.name) .. "|r", string.format("%.1f%% (%d / %d)", pct, boss.health or 0, boss.maxHealth or 0), 0.88, 0.24, 0.26)
	else
		self.bossBar:SetBarData(0, "|cff94a3b8No boss engaged|r", "Out of combat", 0.35, 0.42, 0.52)
	end

	-- Active ability timers
	local active = (_G.InfinityEncounterTimer and _G.InfinityEncounterTimer.GetActiveTimers) and _G.InfinityEncounterTimer:GetActiveTimers() or {}
	if #active == 0 then
		self.emptyTimersLabel:Show()
		for i = 1, #self.timerBars do self.timerBars[i]:Hide() end
		return
	end

	self.emptyTimersLabel:Hide()
	for i = 1, #self.timerBars do
		local timer = active[i]
		local bar = self.timerBars[i]
		if timer then
			local rem = (timer.GetRemaining and timer:GetRemaining()) or 0
			local total = math.max(1, timer.duration or 15)
			local pct = math.max(0, math.min(100, (rem / total) * 100))
			local r, g, b = 0.16, 0.56, 0.94
			if rem <= 5 then
				r, g, b = 0.92, 0.28, 0.28
			elseif rem <= 10 then
				r, g, b = 0.94, 0.68, 0.18
			end
			bar:SetBarData(pct, tostring(timer.name or "Ability"), string.format("%.1fs", rem), r, g, b)
			bar:Show()
		else
			bar:Hide()
		end
	end
end

return InfinityEncounterUI
