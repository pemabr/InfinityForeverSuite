-- PluribusQuestie Main UI
-- Modern Flat Quest Tracker, Live Quest Log Scanner, Database Search, and Route Optimizer

local PluribusQuestieUI = {
	currentTab = "active",
	searchQuery = "",
}
_G.PluribusQuestieUI = PluribusQuestieUI

function PluribusQuestieUI:Initialize()
	if self.initialized and self.frame then return end

	local frame = PluribusUIFramework:CreateFrame(
		"PluribusQuestieMainFrame",
		UIParent,
		560,
		490,
		"Pluribus Questie",
		"Quest Tracker, Search & Optimal Routing"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", -180, 0)

	local tabs = {
		{ name = "Active Quests", key = "active" },
		{ name = "Database Search", key = "search" },
		{ name = "Optimal Route", key = "route" },
	}
	local tabBar = PluribusUIFramework:CreateTabBar(frame, tabs, function(tabKey)
		PluribusQuestieUI.currentTab = tabKey
		PluribusQuestieUI:Update()
	end, 536)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	local searchBox = PluribusUIFramework:CreateInputBox(frame, 360, 24, function(box)
		PluribusQuestieUI.searchQuery = box:GetText() or ""
		PluribusQuestieUI:Update()
	end)
	searchBox:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -8)
	frame.searchBox = searchBox

	local scanBtn = PluribusUIFramework:CreateButton(frame, "Sync Quest Log", 136, 24, function()
		PluribusQuestieUI:SyncFromWoWQuestLog()
		PluribusQuestieUI:Update()
		PluribusUIFramework:ShowNotification("Synced active WoW Quest Log.", 2)
	end, true)
	scanBtn:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)

	local listCard = PluribusUIFramework:CreateCard(frame, 536, 360)
	listCard:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -10)

	local scroll = PluribusUIFramework:CreateScrollFrame(listCard, "PluribusQuestieScroll", 522, 346)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 6, -6)
	self.content = scroll.content

	frame:Hide()
	self.frame = frame
	self.initialized = true
	tabBar:SelectTab("active")
end

function PluribusQuestieUI:SyncFromWoWQuestLog()
	if _G.PluribusQuestieDBSync and _G.PluribusQuestieDBSync.SyncFromNativeQuestLog then
		_G.PluribusQuestieDBSync:SyncFromNativeQuestLog()
		return
	end
	if not PluribusUtils or not PluribusUtils.GetQuestLogCount then return end
	local count = PluribusUtils:GetQuestLogCount()
	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	for i = 1, count do
		local title, level, isHeader, questID = PluribusUtils:GetQuestLogEntry(i)
		if title and not isHeader and _G.PluribusQuestTracker and _G.PluribusQuestTracker.AcceptQuest then
			pcall(function() _G.PluribusQuestTracker:AcceptQuest(questID or i, title, level, zone) end)
		end
	end
end

function PluribusQuestieUI:Toggle()
	if not self.initialized then self:Initialize() end
	self.frame:SetShown(not self.frame:IsShown())
	if self.frame:IsShown() then
		self:SyncFromWoWQuestLog()
		self:Update()
	end
end

function PluribusQuestieUI:Show()
	if not self.initialized then self:Initialize() end
	self.frame:Show()
	self:SyncFromWoWQuestLog()
	self:Update()
end

function PluribusQuestieUI:Update()
	if not self.initialized or not self.frame or not self.frame:IsShown() then return end
	PluribusUIFramework:ClearContainer(self.content)

	local q = (self.searchQuery or ""):lower()
	local y = -2

	if self.currentTab == "active" then
		local activeQuests = (_G.PluribusQuestTracker and _G.PluribusQuestTracker.GetActiveQuests) and _G.PluribusQuestTracker:GetActiveQuests() or {}
		local idx = 0
		for questID, quest in pairs(activeQuests) do
			local name = tostring(quest.name or ("Quest #" .. tostring(questID)))
			if q == "" or name:lower():find(q, 1, true) then
				idx = idx + 1
				local row = PluribusUIFramework:CreateListRow(self.content, 496, 28, idx)
				row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
				local l = PluribusUIFramework:CreateLabel(row, "|cfffbbf24[" .. tostring(quest.level or 60) .. "]|r " .. name)
				l:SetPoint("LEFT", row, "LEFT", 8, 0)
				local r = PluribusUIFramework:CreateLabel(row, "|cff4ade80ACTIVE|r")
				r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				y = y - 30
			end
		end
		if idx == 0 then
			local empty = PluribusUIFramework:CreateLabel(self.content, "|cff94a3b8No active quests tracked yet. Click 'Sync Quest Log' to import your current WoW quests.|r")
			empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, -10)
			empty:SetWidth(480)
			empty:SetWordWrap(true)
		end

	elseif self.currentTab == "search" then
		local results = (_G.PluribusQuestDB and _G.PluribusQuestDB.SearchQuests) and _G.PluribusQuestDB:SearchQuests(q ~= "" and q or "a") or {}
		for idx, quest in ipairs(results) do
			if idx > 25 then break end
			local row = PluribusUIFramework:CreateListRow(self.content, 496, 28, idx)
			row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
			local l = PluribusUIFramework:CreateLabel(row, "|cff38bdf8" .. tostring(quest.name) .. "|r")
			l:SetPoint("LEFT", row, "LEFT", 8, 0)
			local r = PluribusUIFramework:CreateLabel(row, "|cff94a3b8Lv " .. tostring(quest.level or "?") .. " — " .. tostring(quest.zone or "Azeroth") .. "|r")
			r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			y = y - 30
		end
		if #results == 0 then
			local empty = PluribusUIFramework:CreateLabel(self.content, "|cff94a3b8Type a quest name in the search box above to query PluribusQuestDB.|r")
			empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, -10)
		end

	elseif self.currentTab == "route" then
		local activeQuests = (_G.PluribusQuestTracker and _G.PluribusQuestTracker.GetActiveQuests) and _G.PluribusQuestTracker:GetActiveQuests() or {}
		local ids = {}
		for qid, _ in pairs(activeQuests) do table.insert(ids, qid) end
		local route = (#ids > 0 and _G.PluribusQuestRouter and _G.PluribusQuestRouter.CalculateRoute) and _G.PluribusQuestRouter:CalculateRoute(ids) or nil
		if route and route.waypoints and #route.waypoints > 0 then
			for idx, wp in ipairs(route.waypoints) do
				local row = PluribusUIFramework:CreateListRow(self.content, 496, 28, idx)
				row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 2, y)
				local l = PluribusUIFramework:CreateLabel(row, string.format("|cff4ade80#%d|r  %s", idx, tostring(wp.name or "Waypoint")))
				l:SetPoint("LEFT", row, "LEFT", 8, 0)
				local r = PluribusUIFramework:CreateLabel(row, "|cff94a3b8" .. tostring(wp.zone or "") .. "|r")
				r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				y = y - 30
			end
		else
			local empty = PluribusUIFramework:CreateLabel(self.content, "|cff94a3b8Sync at least one active quest to compute an optimized nearest-neighbor route.|r")
			empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, -10)
			empty:SetWidth(480)
			empty:SetWordWrap(true)
		end
	end

	self.content:SetHeight(math.max(330, -y + 12))
end

return PluribusQuestieUI
