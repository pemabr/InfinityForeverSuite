-- InfinityWorldBoss UI — World Boss Respawn Tracker Window
-- Modern flat UIFramework with KPI tiles, live respawn StatusBars, and quick Kill Recording

InfinityWorldBossUI = {
	mainFrame = nil,
	timerListFrame = nil,
	timers = {},
}

local CLASSIC_WORLD_BOSSES = {
	{ id = "azuregos", name = "Azuregos", zone = "Azshara" },
	{ id = "kazzak", name = "Lord Kazzak", zone = "Blasted Lands" },
	{ id = "emeriss", name = "Emeriss", zone = "Duskwood" },
	{ id = "lethon", name = "Lethon", zone = "Hinterlands" },
	{ id = "taerar", name = "Taerar", zone = "Ashenvale" },
	{ id = "ysondre", name = "Ysondre", zone = "Feralas" },
}

function InfinityWorldBossUI:Initialize()
	if self.mainFrame then return self.mainFrame end

	local frame = InfinityUIFramework:CreateFrame(
		"InfinityWorldBossFrame",
		UIParent,
		600,
		460,
		"Infinity World Boss Tracker",
		"Spawn Windows & Guild Alerts"
	)
	frame:SetPoint("CENTER")

	-- KPI strip
	frame.mTracked = InfinityUIFramework:CreateMetricTile(frame, 138, 56, "Tracked", 6, "|cff38bdf8")
	frame.mTracked:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)
	frame.mAlive = InfinityUIFramework:CreateMetricTile(frame, 138, 56, "Likely Up", 0, "|cff4ade80")
	frame.mAlive:SetPoint("LEFT", frame.mTracked, "RIGHT", 8, 0)
	frame.mRespawn = InfinityUIFramework:CreateMetricTile(frame, 138, 56, "Respawning", 0, "|cfffbbf24")
	frame.mRespawn:SetPoint("LEFT", frame.mAlive, "RIGHT", 8, 0)
	frame.mWatched = InfinityUIFramework:CreateMetricTile(frame, 138, 56, "Active Timers", 0, "|cffa855f7")
	frame.mWatched:SetPoint("LEFT", frame.mRespawn, "RIGHT", 8, 0)

	-- List card
	local listCard = InfinityUIFramework:CreateCard(frame, 576, 294, "World Boss Spawn Status")
	listCard:SetPoint("TOPLEFT", frame.mTracked, "BOTTOMLEFT", 0, -10)

	local scroll = InfinityUIFramework:CreateScrollFrame(listCard, "InfinityWorldBossScroll", 560, 254)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 8, -32)
	self.timerListFrame = scroll.content

	local refreshBtn = InfinityUIFramework:CreateButton(frame, "Refresh Timers", 116, 26, function()
		InfinityWorldBossUI:RefreshTimerList()
	end, true)
	refreshBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)

	local shareBtn = InfinityUIFramework:CreateButton(frame, "Announce to Guild", 136, 26, function()
		local active = (_G.InfinityWorldBossTimers and _G.InfinityWorldBossTimers.GetActiveTimers) and _G.InfinityWorldBossTimers:GetActiveTimers() or {}
		local summary = "[InfinityWorldBoss] Active respawn timers: " .. tostring(#active)
		if SendChatMessage and IsInGuild and IsInGuild() then
			pcall(SendChatMessage, summary, "GUILD")
		end
		InfinityUIFramework:ShowNotification(summary, 2.5)
	end)
	shareBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)

	self.mainFrame = frame
	self:RefreshTimerList()
	return frame
end

function InfinityWorldBossUI:RefreshTimerList()
	if not self.mainFrame then self:Initialize() end
	InfinityUIFramework:ClearContainer(self.timerListFrame)

	local activeTimers = (_G.InfinityWorldBossTimers and _G.InfinityWorldBossTimers.GetActiveTimers) and _G.InfinityWorldBossTimers:GetActiveTimers() or {}
	local stats = (_G.InfinityWorldBossCore and _G.InfinityWorldBossCore.GetStatistics) and _G.InfinityWorldBossCore:GetStatistics() or {
		trackedBosses = #CLASSIC_WORLD_BOSSES, aliveCount = #CLASSIC_WORLD_BOSSES, respawningCount = 0
	}

	self.mainFrame.mTracked:SetValue(stats.trackedBosses or #CLASSIC_WORLD_BOSSES)
	self.mainFrame.mAlive:SetValue(stats.aliveCount or 0, "|cff4ade80")
	self.mainFrame.mRespawn:SetValue(stats.respawningCount or 0, "|cfffbbf24")
	self.mainFrame.mWatched:SetValue(#activeTimers, "|cffa855f7")

	local timerByName = {}
	for _, t in ipairs(activeTimers) do
		timerByName[tostring(t.bossName or ""):lower()] = t
	end

	local y = -2
	for idx, boss in ipairs(CLASSIC_WORLD_BOSSES) do
		local t = timerByName[boss.name:lower()]
		local row = InfinityUIFramework:CreateListRow(self.timerListFrame, 534, 38, idx)
		row:SetPoint("TOPLEFT", self.timerListFrame, "TOPLEFT", 2, y)

		local nameLbl = InfinityUIFramework:CreateLabel(row, "|cfffbbf24" .. boss.name .. "|r  |cff94a3b8(" .. boss.zone .. ")|r")
		nameLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -5)

		local statusStr = t and ("|cfffbbf24Respawn: " .. tostring(t.timeFormatted or "Pending") .. "|r") or "|cff4ade80Spawn Window Open|r"
		local subLbl = InfinityUIFramework:CreateLabel(row, statusStr)
		subLbl:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 4)

		local killBtn = InfinityUIFramework:CreateButton(row, "Mark Killed", 92, 22, function()
			if _G.InfinityWorldBossCore and _G.InfinityWorldBossCore.RecordBossKill then
				pcall(function() _G.InfinityWorldBossCore:RecordBossKill(boss.name, UnitName and UnitName("player") or "Guild") end)
			end
			if _G.InfinityWorldBossTimers and _G.InfinityWorldBossTimers.StartTimer then
				pcall(function() _G.InfinityWorldBossTimers:StartTimer(boss.name, 72 * 3600, UnitName and UnitName("player") or "Guild") end)
			end
			InfinityUIFramework:ShowNotification("Recorded kill for " .. boss.name .. "!", 2.5)
			InfinityWorldBossUI:RefreshTimerList()
		end)
		killBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

		y = y - 42
	end

	self.timerListFrame:SetHeight(math.max(250, -y + 10))
end

function InfinityWorldBossUI:Toggle()
	if not self.mainFrame then self:Initialize() end
	self.mainFrame:SetShown(not self.mainFrame:IsShown())
	if self.mainFrame:IsShown() then self:RefreshTimerList() end
end

function InfinityWorldBossUI:Show()
	if not self.mainFrame then self:Initialize() end
	self.mainFrame:Show()
	self:RefreshTimerList()
end

function InfinityWorldBossUI:Hide()
	if self.mainFrame then self.mainFrame:Hide() end
end

function InfinityWorldBossUI:StartAutoUpdate()
	if self._autoFrame then return end
	local updateFrame = CreateFrame("Frame")
	local lastUpdate = 0
	updateFrame:SetScript("OnUpdate", function(_, elapsed)
		lastUpdate = lastUpdate + elapsed
		if lastUpdate >= 5 then
			if InfinityWorldBossUI.mainFrame and InfinityWorldBossUI.mainFrame:IsShown() then
				InfinityWorldBossUI:RefreshTimerList()
			end
			lastUpdate = 0
		end
	end)
	self._autoFrame = updateFrame
end

_G.InfinityWorldBossUI = InfinityWorldBossUI
return InfinityWorldBossUI
