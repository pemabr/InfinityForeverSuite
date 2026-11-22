-- InfinityDKP Main UI
-- Fully functional tabbed DKP/EPGP/SK/Zero-Sum management interface for WoW Forever

local InfinityDKPUI = {
	currentTab = "Players",
	initialized = false,
}
_G.InfinityDKPUI = InfinityDKPUI

function InfinityDKPUI:Initialize()
	if self.initialized then return end
	local UI = _G.InfinityUIFramework

	self.frame = UI:CreateFrame("InfinityDKPMainFrame", UIParent, 720, 480, "InfinityForever — DKP & EPGP Ledger")
	self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	-- Functional tab buttons (previously unwired)
	local tabs = { "Players", "Auctions", "History", "Reports" }
	self.tabButtons = {}
	for i, tabName in ipairs(tabs) do
		local tab = UI:CreateButton(self.frame, tabName, 160, 28, function()
			self:SelectTab(tabName)
		end)
		tab:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16 + (i - 1) * 172, -44)
		self.tabButtons[tabName] = tab
	end

	-- Content area
	self.content = CreateFrame("Frame", nil, self.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -80)
	self.content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -16, 16)
	UI:ApplyBackdrop(self.content, 0.09, 0.11, 0.16, 0.95, 0.22, 0.28, 0.38, 0.85)

	self.frame:Hide()
	self.initialized = true
	self:SelectTab("Players")
end

function InfinityDKPUI:SelectTab(tabName)
	self.currentTab = tabName
	for name, btn in pairs(self.tabButtons or {}) do
		btn:SetActiveState(name == tabName)
	end
	self:Update()
end

function InfinityDKPUI:Toggle()
	if not self.initialized then
		self:Initialize()
	end
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Show()
	end
end

function InfinityDKPUI:Show()
	if not self.initialized then
		self:Initialize()
	end
	self.frame:Show()
	self:Update()
end

function InfinityDKPUI:Hide()
	if self.frame then
		self.frame:Hide()
	end
end

function InfinityDKPUI:Update()
	if not self.initialized or not self.frame:IsShown() then
		return
	end
	local UI = _G.InfinityUIFramework
	UI:ClearContainer(self.content)

	if self.currentTab == "Players" then
		self:RenderPlayersTab()
	elseif self.currentTab == "Auctions" then
		self:RenderAuctionsTab()
	elseif self.currentTab == "History" then
		self:RenderHistoryTab()
	elseif self.currentTab == "Reports" then
		self:RenderReportsTab()
	end
end

function InfinityDKPUI:RenderPlayersTab()
	local UI = _G.InfinityUIFramework
	local engine = _G.InfinityDKPEngine

	-- Mode switchers
	local modes = { "epgp", "dkp", "sk", "zero" }
	for i, mode in ipairs(modes) do
		local btn = UI:CreateButton(self.content, string.upper(mode), 76, 24, function()
			if engine then
				engine:SetSystemType(mode)
				self:Update()
			end
		end, engine and engine.system_type == mode)
		btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14 + (i - 1) * 82, -12)
	end

	local decayBtn = UI:CreateButton(self.content, "Apply 10% Decay", 130, 24, function()
		if engine then
			engine:ApplyEPDecay(10)
			UI:ShowNotification("Applied 10% EP decay across all tracked players.")
			self:Update()
		end
	end)
	decayBtn:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -14, -12)

	local header = UI:CreateLabel(self.content, string.format("%-4s %-20s %-10s %-10s %-10s %-10s", "#", "Player", "EP", "GP", "DKP", "Priority"), 0.65, 0.72, 0.82)
	header:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, -48)

	local ranked = engine and engine:GetRankedPlayers() or {}
	if #ranked == 0 then
		local empty = UI:CreateLabel(self.content, "No players registered in InfinityDKPEngine yet.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, -76)
		return
	end

	local y = -72
	for i, player in ipairs(ranked) do
		if i > 13 then break end
		local row = UI:CreateLabel(
			self.content,
			string.format("%-4d %-20s %-10d %-10d %-10d %-10.2f", i, player.name, player.ep or 0, player.gp or 0, player.dkp or 0, player.priority or 0)
		)
		row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, y)
		y = y - 22
	end
end

function InfinityDKPUI:RenderAuctionsTab()
	local UI = _G.InfinityUIFramework
	local auctions = (_G.InfinityLootAuctions and _G.InfinityLootAuctions.GetActiveAuctions)
		and _G.InfinityLootAuctions:GetActiveAuctions() or {}

	local openBtn = UI:CreateButton(self.content, "Open Full Auction Desk", 180, 26, function()
		if _G.InfinityLootAuctionUI and _G.InfinityLootAuctionUI.CreateAuctionFrame then
			_G.InfinityLootAuctionUI:CreateAuctionFrame()
		end
	end, true)
	openBtn:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -14, -12)

	local title = UI:CreateLabel(self.content, "Active Loot Auctions (" .. tostring(#auctions) .. ")", 0.95, 0.97, 1.0, "GameFontNormal")
	title:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, -16)

	if #auctions == 0 then
		local empty = UI:CreateLabel(self.content, "No active auctions running. Open the Auction Desk or run /loot auction create.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, -52)
		return
	end

	local y = -52
	for _, auc in ipairs(auctions) do
		local remaining = math.max(0, math.floor((auc.endTime or 0) - GetTime()))
		local line = string.format("%s  |  Mode: %s  |  Bids: %d  |  %ds left", auc.itemName or "Item", auc.biddingMode or "open", #(auc.bids or {}), remaining)
		local row = UI:CreateLabel(self.content, line)
		row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, y)
		y = y - 24
	end
end

function InfinityDKPUI:RenderHistoryTab()
	local UI = _G.InfinityUIFramework
	local history = (_G.InfinityLootAuctions and _G.InfinityLootAuctions.GetAuctionHistory)
		and _G.InfinityLootAuctions:GetAuctionHistory(12) or {}

	local title = UI:CreateLabel(self.content, "Resolved Auction & Loot History", 0.95, 0.97, 1.0, "GameFontNormal")
	title:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, -16)

	if #history == 0 then
		local empty = UI:CreateLabel(self.content, "No loot awards recorded in this session yet.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, -52)
		return
	end

	local y = -50
	for i, h in ipairs(history) do
		local row = UI:CreateLabel(
			self.content,
			string.format("%d. %s -> %s (%d pts, %s)", i, h.itemName or "Item", h.winner or "No Winner", h.winningBid or 0, h.biddingMode or "open")
		)
		row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, y)
		y = y - 22
	end
end

function InfinityDKPUI:RenderReportsTab()
	local UI = _G.InfinityUIFramework
	local engine = _G.InfinityDKPEngine
	local stats = engine and engine:GetStats() or { total_players = 0, total_ep = 0, total_gp = 0, avg_ep = 0, avg_gp = 0 }

	local title = UI:CreateLabel(self.content, "Guild Economy Report", 0.95, 0.97, 1.0, "GameFontNormal")
	title:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, -16)

	local lines = {
		string.format("Active Point System: %s", string.upper(engine and engine.system_type or "epgp")),
		string.format("Tracked Raiders: %d", stats.total_players or 0),
		string.format("Total Effort Points (EP): %d (Avg %.1f)", stats.total_ep or 0, stats.avg_ep or 0),
		string.format("Total Gear Points (GP): %d (Avg %.1f)", stats.total_gp or 0, stats.avg_gp or 0),
	}
	local y = -50
	for _, text in ipairs(lines) do
		local row = UI:CreateLabel(self.content, text)
		row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 14, y)
		y = y - 24
	end
end

return InfinityDKPUI
