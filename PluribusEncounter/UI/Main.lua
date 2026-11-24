-- PluribusEncounter Main UI
-- Live Boss Health Bar, Ability Countdown StatusBars, and 10s Pull Timer Controls

local PluribusEncounterUI = {
	lastUpdate = 0,
	timerBars = {},
}
_G.PluribusEncounterUI = PluribusEncounterUI

function PluribusEncounterUI:Initialize()
	if self.initialized and self.frame then return end

	local frame = PluribusUIFramework:CreateFrame(
		"PluribusEncounterMainFrame",
		UIParent,
		460,
		380,
		"Pluribus Encounter",
		"Boss Timers & Alerts"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)

	-- Quick controls
	local pullBtn = PluribusUIFramework:CreateButton(frame, "Pull 10s", 88, 24, function()
		if _G.PluribusEncounterTimer and _G.PluribusEncounterTimer.CreateTimer then
			_G.PluribusEncounterTimer:CreateTimer("Pull Countdown", 10)
		end
		if _G.PluribusEncounterAlerts and _G.PluribusEncounterAlerts.SendAlert then
			_G.PluribusEncounterAlerts:SendAlert("Pull in 10 seconds!", _G.PluribusEncounterAlerts.LEVEL_WARNING)
		end
		PluribusUIFramework:ShowNotification("|cfffbbf24Pull timer started: 10s|r", 2.5)
		PluribusEncounterUI:Update(true)
	end, true)
	pullBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)

	local testBtn = PluribusUIFramework:CreateButton(frame, "Test Timers", 96, 24, function()
		if _G.PluribusEncounterTimer and _G.PluribusEncounterTimer.CreateTimer then
			_G.PluribusEncounterTimer:CreateTimer("Locust Swarm", 25)
			_G.PluribusEncounterTimer:CreateTimer("Frost Blast", 18)
			_G.PluribusEncounterTimer:CreateTimer("Void Zone", 12)
		end
		PluribusEncounterUI:Update(true)
	end)
	testBtn:SetPoint("LEFT", pullBtn, "RIGHT", 8, 0)

	local resetBtn = PluribusUIFramework:CreateButton(frame, "Reset", 74, 24, function()
		if _G.PluribusEncounterMgr and _G.PluribusEncounterMgr.Reset then _G.PluribusEncounterMgr:Reset() end
		if _G.PluribusEncounterAbilities and _G.PluribusEncounterAbilities.Reset then _G.PluribusEncounterAbilities:Reset() end
		if _G.PluribusEncounterAlerts and _G.PluribusEncounterAlerts.Clear then _G.PluribusEncounterAlerts:Clear() end
		if _G.PluribusEncounterTimer and _G.PluribusEncounterTimer.timers then _G.PluribusEncounterTimer.timers = {} end
		PluribusEncounterUI:Update(true)
	end)
	resetBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)

	-- Boss health bar card
	local bossCard = PluribusUIFramework:CreateCard(frame, 436, 74, "Active Boss Target")
	bossCard:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -80)

	local bossBar = PluribusUIFramework:CreateStatusBar(bossCard, 412, 26, 0.88, 0.24, 0.26)
	bossBar:SetPoint("TOPLEFT", bossCard, "TOPLEFT", 12, -34)
	bossBar:SetBarData(0, "No boss engaged", "Idle")
	self.bossBar = bossBar

	-- Active ability timers card
	local timersCard = PluribusUIFramework:CreateCard(frame, 436, 206, "Upcoming Boss Ability Timers")
	timersCard:SetPoint("TOPLEFT", bossCard, "BOTTOMLEFT", 0, -10)
	self.timersCard = timersCard

	-- Pre-allocate 6 reusable StatusBars for zero-GC live 0.1s updates
	self.timerBars = {}
	for i = 1, 6 do
		local tb = PluribusUIFramework:CreateStatusBar(timersCard, 412, 24, 0.16, 0.56, 0.94)
		tb:SetPoint("TOPLEFT", timersCard, "TOPLEFT", 12, -32 - (i - 1) * 28)
		tb:Hide()
		self.timerBars[i] = tb
	end

	local emptyLbl = PluribusUIFramework:CreateLabel(timersCard, "|cff94a3b8No active ability timers. Click 'Pull 10s' or 'Test Timers' to preview.|r")
	emptyLbl:SetPoint("TOPLEFT", timersCard, "TOPLEFT", 12, -36)
	self.emptyTimersLabel = emptyLbl

	frame:Hide()
	self.frame = frame
	self.initialized = true
end

function PluribusEncounterUI:Toggle()
	if not self.initialized then self:Initialize() end
	self.frame:SetShown(not self.frame:IsShown())
	if self.frame:IsShown() then self:Update(true) end
end

function PluribusEncounterUI:Show()
	if not self.initialized then self:Initialize() end
	self.frame:Show()
	self:Update(true)
end

function PluribusEncounterUI:Hide()
	if self.frame then self.frame:Hide() end
end

function PluribusEncounterUI:Update(force)
	if not self.initialized or not self.frame or not self.frame:IsShown() then return end
	local now = GetTime and GetTime() or 0
	if not force and (now - self.lastUpdate) < 0.1 then return end
	self.lastUpdate = now

	-- Boss health status bar
	local boss = (_G.PluribusEncounterMgr and _G.PluribusEncounterMgr.GetCurrentBoss) and _G.PluribusEncounterMgr:GetCurrentBoss() or nil
	if boss then
		local pct = boss.healthPercent or 0
		self.bossBar:SetBarData(pct, "|cffffffff" .. tostring(boss.name) .. "|r", string.format("%.1f%% (%d / %d)", pct, boss.health or 0, boss.maxHealth or 0), 0.88, 0.24, 0.26)
	else
		self.bossBar:SetBarData(0, "|cff94a3b8No boss engaged|r", "Out of combat", 0.35, 0.42, 0.52)
	end

	-- Active ability timers
	local active = (_G.PluribusEncounterTimer and _G.PluribusEncounterTimer.GetActiveTimers) and _G.PluribusEncounterTimer:GetActiveTimers() or {}
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

return PluribusEncounterUI
