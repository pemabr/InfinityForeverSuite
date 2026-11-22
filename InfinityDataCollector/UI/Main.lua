-- InfinityDataCollector UI - Statistics and Settings

InfinityDataCollectorUI = {
	mainFrame = nil,
	tabs = {},
	currentTab = "stats",
}

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function KnowledgeID(value)
	value = Public(value)
	if type(value) ~= "string" or not value:match("^%s*%d+%s*$") then return nil end
	local id = tonumber(value)
	if not id or id < 1 or id > 1000000000 then return nil end
	return id
end

local function KnowledgeText(value)
	value = Public(value)
	if type(value) ~= "string" or value == "" then return "Unknown" end
	return value:gsub("[%c|]", "")
end

local function KnowledgeNumber(value, maximum)
	value = Public(value)
	if type(value) == "number" and value == value and value >= 0
		and value <= maximum and value == math.floor(value) then return value end
end

local function BuildSettings(parent)
	local entries = {
		{ key = "gatheringToggle", title = "Enable Data Gathering",
			get = function() return InfinityDataCollectorCore:IsGatheringEnabled() end,
			set = function(value) return InfinityDataCollectorCore:SetGatheringEnabled(value) end },
		{ key = "sharingToggle", title = "Enable guild quest/drop snapshots",
			description = "Only IDs, names, quest levels and item rarity are shared.\nSend and apply snapshots explicitly in the Network tab.",
			get = function() return InfinityDataCollectorNetwork.shareEnabled end,
			set = function(value) return InfinityDataCollectorNetwork:SetSharingEnabled(value) end },
		{ key = "liveToggle", title = "Live guild quest/drop knowledge",
			description = "Shares observed quest and drop IDs/names automatically.\nGuild peers merge missing records and sync while online.",
			get = function() return InfinityGuildKnowledge.db and InfinityGuildKnowledge.db.enabled end,
			set = function(value) return InfinityGuildKnowledge:SetEnabled(value) end },
		{ key = "nodesToggle", title = "Share guild gathering positions",
			description = "Shares saved and future herb/ore positions, including approximate player\nlocation at collection. Requires Infinity Gather.",
			get = function() return InfinityGuildGatherKnowledge.db and InfinityGuildGatherKnowledge.db.enabled end,
			set = function(value) return InfinityGuildGatherKnowledge:SetEnabled(value) end },
		{ key = "recipesToggle", title = "Share guild recipe reports",
			description = "Shares your character name and learned recipes when you open your\nprofession. Reports may become outdated.",
			get = function() return InfinityGuildRecipes.db and InfinityGuildRecipes.db.enabled end,
			set = function(value) return InfinityGuildRecipes:SetEnabled(value) end },
		{ key = "offersToggle", title = "Share quest-offer positions",
			description = "Shares approximate player location when opening an NPC quest offer,\nthe quest ID and the NPC name.",
			get = function() return InfinityGuildQuestPositions.db and InfinityGuildQuestPositions.db.enabled end,
			set = function(value) return InfinityGuildQuestPositions:SetEnabled(value) end },
		{ key = "bossesToggle", title = "Share world-boss encounter reports",
			description = "Shares registered boss encounter IDs, names and kill times.\nReports may refer to another layer.",
			get = function() return InfinityGuildBossReports.db and InfinityGuildBossReports.db.enabled end,
			set = function(value) return InfinityGuildBossReports:SetEnabled(value) end },
		{ key = "bagsToggle", title = "Share guild bag item reports",
			description = "Shares character name and ALL bag item IDs/counts across characters.\nRequires Infinity Inventory; shared copies remain after disabling.",
			get = function() return InfinityGuildBagReports.db and InfinityGuildBagReports.db.enabled end,
			set = function(value) return InfinityGuildBagReports:SetEnabled(value) end },
	}
	local controls, y = { frame = parent }, -10
	for _, entry in ipairs(entries) do
		local item = entry
		local toggle = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		toggle:SetSize(20, 20)
		toggle:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
		toggle:SetChecked(not not item.get())
		toggle:SetScript("OnClick", function(button)
			button:SetChecked(not not item.set(button:GetChecked()))
			local ui = InfinityDataCollectorUI
			if ui.tabs.settings then ui.tabs.settings.refreshFunc() end
			if ui.blizzardControls then ui.blizzardControls.refreshFunc() end
		end)
		local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("LEFT", toggle, "RIGHT", 5, 0)
		label:SetText(item.title)
		if item.description then
			local description = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			description:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -3)
			description:SetText(item.description)
			y = y - 64
		else
			y = y - 35
		end
		controls[item.key] = toggle
	end
	controls.refreshFunc = function()
		for _, entry in ipairs(entries) do controls[entry.key]:SetChecked(not not entry.get()) end
	end
	return controls
end

function InfinityDataCollectorUI:RegisterBlizzardSettings()
	if self.blizzardCategory then return self.blizzardCategory end
	local settings = _G.Settings
	local modern = settings and settings.RegisterCanvasLayoutCategory and settings.RegisterAddOnCategory
	if not modern and not _G.InterfaceOptions_AddCategory then
		InfinityUtils:Warning("Game settings are unavailable; use /datacollector settings.", "DataCollector")
		return nil
	end

	local panel = CreateFrame("Frame", nil, UIParent)
	panel.name = "Infinity Data Collector"
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	title:SetText(panel.name)
	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -45)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 12)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(460, 510)
	scroll:SetScrollChild(content)
	self.blizzardControls = BuildSettings(content)
	panel:SetScript("OnShow", function() self.blizzardControls.refreshFunc() end)

	local suite = _G.InfinitySettingsPanel
	if modern then
		if suite and suite.blizzardCategory and suite.blizzardCategory ~= suite.blizzardPanel
			and settings.RegisterCanvasLayoutSubcategory then
			self.blizzardCategory = settings.RegisterCanvasLayoutSubcategory(suite.blizzardCategory, panel, panel.name)
		else
			self.blizzardCategory = settings.RegisterCanvasLayoutCategory(panel, panel.name)
			settings.RegisterAddOnCategory(self.blizzardCategory)
		end
	else
		if suite and suite.blizzardCategory == suite.blizzardPanel then panel.parent = "Infinity Suite" end
		_G.InterfaceOptions_AddCategory(panel)
		self.blizzardCategory = panel
	end
	self.blizzardPanel = panel
	return self.blizzardCategory
end

-- Initialize UI
function InfinityDataCollectorUI:Initialize()
	if self.mainFrame then
		return
	end
	
	-- Main frame
	local frame = CreateFrame("Frame", "InfinityDataCollectorFrame", UIParent, "BasicFrameTemplate")
	frame:SetSize(500, 600)
	frame:SetPoint("CENTER", UIParent, "CENTER")
	if frame.SetTitle then
		frame:SetTitle("Infinity Data Collector")
	elseif frame.TitleText then
		frame.TitleText:SetText("Infinity Data Collector")
	end
	
	-- Close button already in BasicFrameTemplate
	
	-- Tab buttons
	local statsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	statsBtn:SetSize(80, 20)
	statsBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
	statsBtn:SetText("Statistics")
	statsBtn:SetScript("OnClick", function()
		InfinityDataCollectorUI:ShowTab("stats")
	end)
	
	local settingsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	settingsBtn:SetSize(80, 20)
	settingsBtn:SetPoint("LEFT", statsBtn, "RIGHT", 5, 0)
	settingsBtn:SetText("Settings")
	settingsBtn:SetScript("OnClick", function()
		InfinityDataCollectorUI:ShowTab("settings")
	end)
	
	local networkBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	networkBtn:SetSize(80, 20)
	networkBtn:SetPoint("LEFT", settingsBtn, "RIGHT", 5, 0)
	networkBtn:SetText("Network")
	networkBtn:SetScript("OnClick", function()
		InfinityDataCollectorUI:ShowTab("network")
	end)

	local knowledgeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	knowledgeBtn:SetSize(80, 20)
	knowledgeBtn:SetPoint("LEFT", networkBtn, "RIGHT", 5, 0)
	knowledgeBtn:SetText("Knowledge")
	knowledgeBtn:SetScript("OnClick", function()
		InfinityDataCollectorUI:ShowTab("knowledge")
	end)
	
	-- Statistics tab
	local statsTab = CreateFrame("Frame", nil, frame)
	statsTab:SetSize(480, 520)
	statsTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
	
	local statsText = statsTab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	statsText:SetPoint("TOPLEFT", statsTab, "TOPLEFT", 0, 0)
	statsText:SetText("Data Gathering Statistics\n\n")
	
	self.tabs["stats"] = {
		frame = statsTab,
		text = statsText,
		refreshFunc = function()
			InfinityDataCollectorUI:RefreshStatistics()
		end
	}
	local externalSync = CreateFrame("Button", nil, statsTab, "UIPanelButtonTemplate")
	externalSync:SetSize(150, 22)
	externalSync:SetPoint("TOPLEFT", statsTab, "TOPLEFT", 0, -300)
	externalSync:SetText("Sync external data")
	externalSync:SetScript("OnClick", function()
		self:SyncExternalDatabases()
		self:RefreshStatistics()
	end)
	local autoSync = CreateFrame("Button", nil, statsTab, "UIPanelButtonTemplate")
	autoSync:SetSize(150, 22)
	autoSync:SetPoint("LEFT", externalSync, "RIGHT", 8, 0)
	autoSync:SetScript("OnClick", function()
		self:ToggleAutoSync()
		self:RefreshStatistics()
	end)
	self.tabs.stats.externalSync = externalSync
	self.tabs.stats.autoSync = autoSync
	
	-- Settings tab
	local settingsTab = CreateFrame("Frame", nil, frame)
	settingsTab:SetSize(480, 520)
	settingsTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
	settingsTab:Hide()
	
	self.tabs["settings"] = BuildSettings(settingsTab)
	
	-- Network tab
	local networkTab = CreateFrame("Frame", nil, frame)
	networkTab:SetSize(480, 520)
	networkTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
	networkTab:Hide()
	
	local networkText = networkTab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	networkText:SetPoint("TOPLEFT", networkTab, "TOPLEFT", 0, 0)
	networkText:SetText("Network Status\n\n")
	
	self.tabs["network"] = {
		frame = networkTab,
		text = networkText,
		refreshFunc = function()
			InfinityDataCollectorUI:RefreshNetworkStatus()
		end
	}
	local function Request(module, label)
		if module:SyncNext() then
			print(label .. " sync requested.")
		else
			InfinityUtils:Warning(label .. " is disabled, busy, or has no online peer yet.", "Network")
		end
	end
	local actions = {
		{ "send", "Send snapshot", function() InfinityDataCollectorNetwork:Send() end },
		{ "apply", "Apply snapshot", function() InfinityDataCollectorNetwork:Apply() end },
		{ "discard", "Discard snapshot", function() InfinityDataCollectorNetwork:Discard() end },
		{ "live", "Sync quests/drops", function() Request(InfinityGuildKnowledge, "Guild knowledge") end },
		{ "nodes", "Sync gathering", function() Request(InfinityGuildGatherKnowledge, "Guild gathering positions") end },
		{ "recipes", "Sync recipes", function() Request(InfinityGuildRecipes, "Guild recipes") end },
		{ "offers", "Sync quest offers", function() Request(InfinityGuildQuestPositions, "Guild quest offers") end },
		{ "bosses", "Sync boss reports", function() Request(InfinityGuildBossReports, "Guild boss reports") end },
		{ "bags", "Sync bag reports", function() Request(InfinityGuildBagReports, "Guild bag reports") end },
		{ "crafters", "Find crafters", function() InfinityGuildRecipes:Toggle() end },
		{ "stock", "Find guild stock", function() InfinityGuildBagReports:Toggle() end },
		{ "settings", "Sharing settings", function() self:ShowTab("settings") end },
	}
	self.tabs.network.buttons = {}
	for index, action in ipairs(actions) do
		local entry = action
		local button = CreateFrame("Button", nil, networkTab, "UIPanelButtonTemplate")
		button:SetSize(145, 22)
		button:SetPoint("TOPLEFT", networkTab, "TOPLEFT", ((index - 1) % 3) * 152, -205 - math.floor((index - 1) / 3) * 27)
		button:SetText(entry[2])
		button:SetScript("OnClick", function()
			entry[3]()
			self:RefreshNetworkStatus()
		end)
		self.tabs.network.buttons[entry[1]] = button
	end

	local knowledgeTab = CreateFrame("Frame", nil, frame)
	knowledgeTab:SetSize(480, 520)
	knowledgeTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -60)
	knowledgeTab:Hide()

	local idLabel = knowledgeTab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	idLabel:SetPoint("TOPLEFT", knowledgeTab, "TOPLEFT", 0, -6)
	idLabel:SetText("Quest or creature ID:")
	local idInput = CreateFrame("EditBox", nil, knowledgeTab, "InputBoxTemplate")
	idInput:SetSize(100, 20)
	idInput:SetPoint("LEFT", idLabel, "RIGHT", 12, 0)
	idInput:SetAutoFocus(false)
	idInput:SetMaxLetters(10)

	local result = knowledgeTab:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	result:SetPoint("TOPLEFT", knowledgeTab, "TOPLEFT", 0, -45)
	result:SetWidth(470)
	result:SetJustifyH("LEFT")
	result:SetText("Enter an ID and select Quest or Drops.\nIncludes local and received guild knowledge.")

	local selection = { page = 1 }
	local function RefreshKnowledge()
		local id = selection.id
		if not id then
			result:SetText("Enter a valid quest or creature ID.")
			return
		end
		local data = InfinityDataCollectorCore.gatheredData
		if selection.kind == "quest" then
			local quest = Public(data.quests[id])
			if type(quest) ~= "table" then result:SetText("No quest knowledge for ID " .. id .. "."); return end
			local level = KnowledgeNumber(quest.level, 1000)
			result:SetText("Quest " .. id .. ": " .. KnowledgeText(quest.name)
				.. "\nLevel: " .. (level and level > 0 and tostring(level) or "Unknown"))
			return
		end
		local drops = {}
		for _, raw in pairs(data.drops) do
			local drop = Public(raw)
			if type(drop) == "table" and Public(drop.mobID) == id then
				local item = KnowledgeNumber(drop.itemID, 1000000000)
				if item and item > 0 then drops[#drops + 1] = drop end
			end
		end
		table.sort(drops, function(a, b) return a.itemID < b.itemID end)
		if #drops == 0 then result:SetText("No drop knowledge for creature ID " .. id .. "."); return end
		local pages = math.ceil(#drops / 10)
		selection.page = math.max(1, math.min(selection.page, pages))
		local lines = { "Creature " .. id .. " - " .. #drops .. " drops (page " .. selection.page .. "/" .. pages .. ")" }
		for index = (selection.page - 1) * 10 + 1, math.min(selection.page * 10, #drops) do
			local drop = drops[index]
			local rarity = KnowledgeNumber(drop.rarity, 10)
			lines[#lines + 1] = drop.itemID .. ": " .. KnowledgeText(drop.itemName)
				.. (rarity and " (quality " .. rarity .. ")" or "")
		end
		result:SetText(table.concat(lines, "\n"))
	end
	local function Search(kind)
		selection.id, selection.kind, selection.page = KnowledgeID(idInput:GetText()), kind, 1
		RefreshKnowledge()
	end
	local questBtn = CreateFrame("Button", nil, knowledgeTab, "UIPanelButtonTemplate")
	questBtn:SetSize(65, 20)
	questBtn:SetPoint("LEFT", idInput, "RIGHT", 10, 0)
	questBtn:SetText("Quest")
	questBtn:SetScript("OnClick", function() Search("quest") end)
	local dropsBtn = CreateFrame("Button", nil, knowledgeTab, "UIPanelButtonTemplate")
	dropsBtn:SetSize(65, 20)
	dropsBtn:SetPoint("LEFT", questBtn, "RIGHT", 5, 0)
	dropsBtn:SetText("Drops")
	dropsBtn:SetScript("OnClick", function() Search("drops") end)

	local previous = CreateFrame("Button", nil, knowledgeTab, "UIPanelButtonTemplate")
	previous:SetSize(80, 20)
	previous:SetPoint("BOTTOMLEFT", knowledgeTab, "BOTTOMLEFT", 0, 0)
	previous:SetText("Previous")
	previous:SetScript("OnClick", function() selection.page = selection.page - 1; RefreshKnowledge() end)
	local nextPage = CreateFrame("Button", nil, knowledgeTab, "UIPanelButtonTemplate")
	nextPage:SetSize(80, 20)
	nextPage:SetPoint("LEFT", previous, "RIGHT", 5, 0)
	nextPage:SetText("Next")
	nextPage:SetScript("OnClick", function() selection.page = selection.page + 1; RefreshKnowledge() end)
	self.tabs["knowledge"] = { frame = knowledgeTab, input = idInput, text = result,
		questButton = questBtn, dropsButton = dropsBtn, nextButton = nextPage, previousButton = previous,
		refreshFunc = function() if selection.id then RefreshKnowledge() end end }
	
	self.mainFrame = frame
	frame:Hide()
	
	-- Refresh initial tab
	self:ShowTab("stats")
	
	return frame
end

-- Show a specific tab
function InfinityDataCollectorUI:ShowTab(tabName)
	if not self.tabs[tabName] then
		return
	end
	
	-- Hide all tabs
	for name, tabData in pairs(self.tabs) do
		if tabData.frame then
			tabData.frame:Hide()
		end
	end
	
	-- Show selected tab
	self.tabs[tabName].frame:Show()
	self.currentTab = tabName
	
	-- Refresh if function exists
	if self.tabs[tabName].refreshFunc then
		self.tabs[tabName].refreshFunc()
	end
end

-- Refresh statistics display
function InfinityDataCollectorUI:RefreshStatistics()
	if not self.tabs["stats"] or not self.tabs["stats"].text then
		return
	end
	
	local stats = InfinityDataCollectorCore:GetStatistics()
	local gatheringStats = InfinityDataCollectorHooks:GetGatheringStats()
	local networkStats = InfinityDataCollectorNetwork:GetNetworkStats()
	
	local text = string.format(
		"Data Gathering Statistics\n\n" ..
		"Collected Data:\n" ..
		"  Quests: %d\n" ..
		"  Mobs: %d\n" ..
		"  Drops: %d\n" ..
		"  Nodes: %d\n" ..
		"  NPCs: %d\n\n" ..
		"Last Updates:\n" ..
		"  Quests: %s\n" ..
		"  Mobs: %s\n" ..
		"  Nodes: %s\n\n" ..
		"Network:\n" ..
		"  Pending Records: %d\n" ..
		"  Sharing: %s\n",
		stats.questCount or 0,
		stats.mobCount or 0,
		stats.dropCount or 0,
		stats.nodeCount or 0,
		stats.npcCount or 0,
		self:FormatTime(stats.lastQuestUpdate),
		self:FormatTime(stats.lastMobUpdate),
		self:FormatTime(stats.lastNodeUpdate),
		networkStats.pendingCount or 0,
		networkStats.shareEnabled and "Enabled" or "Disabled"
	)
	
	self.tabs["stats"].text:SetText(text)
	self.tabs.stats.autoSync:SetText("Auto-sync: " .. (self:GetAutoSyncEnabled() and "On" or "Off"))
end

-- Refresh network status display
function InfinityDataCollectorUI:RefreshNetworkStatus()
	if not self.tabs["network"] or not self.tabs["network"].text then
		return
	end
	
	local networkStats = InfinityDataCollectorNetwork:GetNetworkStats()
	local text = string.format(
		"Guild snapshot sync: %s\nEnabled: %s\nSending: %s\nReceiving: %s\nPending: %s\n" ..
		"Live quest/drop knowledge: %s\nGuild gathering positions: %s\nGuild recipe reports: %s\nGuild quest offers: %s\nGuild boss reports: %s\nGuild bag reports: %s",
		networkStats.available and "Available" or "Unavailable",
		networkStats.shareEnabled and "Yes" or "No",
		networkStats.sending and "Yes" or "No",
		networkStats.receiving and "Yes" or "No",
		networkStats.pendingCount and (networkStats.pendingCount .. " records from " .. networkStats.sender) or "None",
		InfinityGuildKnowledge.available and (InfinityGuildKnowledge.db.enabled and "On" or "Off") or "Unavailable",
		InfinityGuildGatherKnowledge.available and (InfinityGuildGatherKnowledge.db.enabled and "On" or "Off") or "Unavailable",
		InfinityGuildRecipes.available and (InfinityGuildRecipes.db.enabled and "On" or "Off") or "Unavailable",
		InfinityGuildQuestPositions.available and (InfinityGuildQuestPositions.db.enabled and "On" or "Off") or "Unavailable",
		InfinityGuildBossReports.available and (InfinityGuildBossReports.db.enabled and "On" or "Off") or "Unavailable",
		InfinityGuildBagReports.available and (InfinityGuildBagReports.db.enabled and "On" or "Off") or "Unavailable"
	)
	
	self.tabs["network"].text:SetText(text)
end

-- Format timestamp for display
function InfinityDataCollectorUI:FormatTime(timestamp)
	if not timestamp or timestamp == 0 then
		return "Never"
	end
	
	local secondsAgo = time() - timestamp
	if secondsAgo < 60 then
		return "Just now"
	elseif secondsAgo < 3600 then
		return string.format("%d min ago", math.floor(secondsAgo / 60))
	elseif secondsAgo < 86400 then
		return string.format("%d hours ago", math.floor(secondsAgo / 3600))
	else
		return string.format("%d days ago", math.floor(secondsAgo / 86400))
	end
end

-- Toggle UI visibility
function InfinityDataCollectorUI:Toggle()
	if not self.mainFrame then
		self:Initialize()
	end
	
	self.mainFrame:SetShown(not self.mainFrame:IsShown())
end

-- Show UI
function InfinityDataCollectorUI:Show()
	if not self.mainFrame then
		self:Initialize()
	end
	
	self.mainFrame:Show()
end

-- Hide UI
function InfinityDataCollectorUI:Hide()
	if self.mainFrame then
		self.mainFrame:Hide()
	end
end
