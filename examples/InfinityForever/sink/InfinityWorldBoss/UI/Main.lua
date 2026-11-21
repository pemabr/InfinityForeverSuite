-- InfinityWorldBoss UI - World Boss Tracker Window

InfinityWorldBossUI = {
	mainFrame = nil,
	timerListFrame = nil,
	timers = {},
}

-- Initialize UI
function InfinityWorldBossUI:Initialize()
	if self.mainFrame then
		return
	end
	
	-- Main frame
	local frame = CreateFrame("Frame", "InfinityWorldBossFrame", UIParent, "BasicFrameTemplate")
	frame:SetSize(500, 400)
	frame:SetPoint("CENTER", UIParent, "CENTER")
	frame:SetTitle("Infinity World Boss Tracker")
	
	-- Status summary
	local statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	statusText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
	statusText:SetJustifyH("LEFT")
	
	-- Timer list scroll frame
	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetSize(470, 320)
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
	
	local timerListFrame = CreateFrame("Frame", nil, scrollFrame)
	timerListFrame:SetSize(450, 320)
	scrollFrame:SetScrollChild(timerListFrame)
	
	-- Refresh button
	local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	refreshBtn:SetSize(100, 20)
	refreshBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
	refreshBtn:SetText("Refresh")
	refreshBtn:SetScript("OnClick", function()
		InfinityWorldBossUI:RefreshTimerList()
	end)
	
	-- Close button is in BasicFrameTemplate
	
	self.mainFrame = frame
	self.timerListFrame = timerListFrame
	self.statusText = statusText
	self.scrollFrame = scrollFrame
	
	-- Initial refresh
	self:RefreshTimerList()
	
	return frame
end

-- Refresh timer list display
function InfinityWorldBossUI:RefreshTimerList()
	if not self.mainFrame then
		self:Initialize()
	end
	
	-- Clear old entries
	for _, frame in ipairs(self.timers) do
		frame:Hide()
		frame:SetParent(nil)
	end
	self.timers = {}
	
	-- Get active timers
	local activeTimers = InfinityWorldBossTimers:GetActiveTimers()
	
	-- Update status text
	local stats = InfinityWorldBossCore:GetStatistics()
	local statusText = string.format(
		"Tracked: %d | Alive: %d | Respawning: %d | Watched: %d",
		stats.trackedBosses,
		stats.aliveCount,
		stats.respawningCount,
		#activeTimers
	)
	self.statusText:SetText(statusText)
	
	-- Add timer entries
	local yOffset = 0
	for i, timer in ipairs(activeTimers) do
		local entryFrame = CreateFrame("Frame", nil, self.timerListFrame)
		entryFrame:SetSize(430, 40)
		entryFrame:SetPoint("TOPLEFT", self.timerListFrame, "TOPLEFT", 0, -yOffset)
		
		-- Background
		local bg = entryFrame:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(entryFrame)
		if i % 2 == 0 then
			bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
		else
			bg:SetColorTexture(0.05, 0.05, 0.05, 0.3)
		end
		
		-- Boss name
		local nameText = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		nameText:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 5, -5)
		nameText:SetText(timer.bossName)
		nameText:SetTextColor(1, 1, 0, 1)  -- Gold
		nameText:SetWidth(200)
		nameText:SetJustifyH("LEFT")
		
		-- Time remaining
		local timeText = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		timeText:SetPoint("TOPRIGHT", entryFrame, "TOPRIGHT", -5, -5)
		timeText:SetText(timer.timeFormatted)
		timeText:SetTextColor(0, 1, 0, 1)  -- Green
		timeText:SetWidth(150)
		timeText:SetJustifyH("RIGHT")
		
		-- Killed by
		local killedText = entryFrame:CreateFontString(nil, "ARTWORK", "GameFontSmall")
		killedText:SetPoint("BOTTOMLEFT", entryFrame, "BOTTOMLEFT", 5, 2)
		killedText:SetText("Killed by: " .. (timer.killedBy or "Unknown"))
		killedText:SetTextColor(0.7, 0.7, 0.7, 1)
		killedText:SetWidth(420)
		killedText:SetJustifyH("LEFT")
		
		table.insert(self.timers, entryFrame)
		yOffset = yOffset + 45
	end
	
	-- Update scroll frame size
	local height = math.max(#activeTimers * 45, 320)
	self.timerListFrame:SetHeight(height)
end

-- Toggle UI visibility
function InfinityWorldBossUI:Toggle()
	if not self.mainFrame then
		self:Initialize()
	end
	
	self.mainFrame:SetShown(not self.mainFrame:IsShown())
end

-- Show UI
function InfinityWorldBossUI:Show()
	if not self.mainFrame then
		self:Initialize()
	end
	
	self.mainFrame:Show()
	self:RefreshTimerList()
end

-- Hide UI
function InfinityWorldBossUI:Hide()
	if self.mainFrame then
		self.mainFrame:Hide()
	end
end

-- Auto-update timer display every 5 seconds
function InfinityWorldBossUI:StartAutoUpdate()
	local updateFrame = CreateFrame("Frame")
	local lastUpdate = 0
	
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		lastUpdate = lastUpdate + elapsed
		if lastUpdate >= 5 then
			InfinityWorldBossUI:RefreshTimerList()
			lastUpdate = 0
		end
	end)
end
