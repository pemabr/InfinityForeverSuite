-- InfinityCore Main Frame
-- Primary UI window for the suite

InfinityMainFrame = {}

local featureWindows = {
	InfinityAttendance = "InfinityAttendanceUI",
	InfinityCalendar = "InfinityCalendarUI",
	InfinityConsumables = "InfinityConsumablesUI",
	InfinityDataCollector = "InfinityDataCollectorUI",
	InfinityDetails = "InfinityDetailsUI",
	InfinityDKP = "InfinityDKPUI",
	InfinityEncounter = "InfinityEncounterUI",
	InfinityGather = "InfinityGatherUI",
	InfinityGatherPath = "InfinityGatherPathUI",
	InfinityGear = "InfinityGearUI",
	InfinityGearMgr = "InfinityGearMgrUI",
	InfinityGuide = "InfinityGuideUI",
	InfinityGuild = "InfinityGuildUI",
	InfinityHealer = "InfinityHealerUI",
	InfinityInventory = "InfinityInventoryUI",
	InfinityLoot = "InfinityLootUI",
	InfinityLootHistory = "InfinityLootHistoryUI",
	InfinityNavigation = "InfinityNavigationUI",
	InfinityPerformanceAnalytics = "InfinityPerformanceAnalyticsUI",
	InfinityProfiler = "InfinityProfilerUI",
	InfinityQoL = "InfinityQoLUI",
	InfinityQuestie = "InfinityQuestieUI",
	InfinityRaid = "InfinityRaidUI",
	InfinityRosterMgr = "InfinityRosterMgrUI",
	InfinityWorldBoss = "InfinityWorldBossUI",
}

local function AvailableFeatureWindow(name)
	local api = _G.C_AddOns
	local isLoaded = api and api.IsAddOnLoaded or _G.IsAddOnLoaded
	if isLoaded and not isLoaded(name) then return nil end
	local window = featureWindows[name] and _G[featureWindows[name]]
	if type(window) == "table" and type(window.Toggle) == "function" then return window end
end

function InfinityMainFrame:OpenFeature(name)
	local window = AvailableFeatureWindow(name)
	if not window then
		InfinityUtils:Warning("Feature window unavailable: " .. tostring(name), "Core")
		return false
	end
	local ok, err = pcall(window.Toggle, window)
	if not ok then
		if _G.issecretvalue and _G.issecretvalue(err) then err = nil end
		InfinityUtils:Error("Could not open " .. name .. ": " .. tostring(err or "protected error"), "Core")
		return false
	end
	return true
end

function InfinityMainFrame:IsFeatureAvailable(name)
	return AvailableFeatureWindow(name) ~= nil
end

function InfinityMainFrame:Create()
	if _G.InfinityMainWindow then
		return _G.InfinityMainWindow
	end
	
	-- Create basic frame without InfinityUIFramework dependency
	local mainFrame = CreateFrame("Frame", "InfinityMainWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mainFrame:SetSize(640, 500)
	mainFrame:SetPoint("CENTER")
	mainFrame:SetMovable(true)
	mainFrame:EnableMouse(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	mainFrame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	
	-- Set backdrop
	mainFrame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	mainFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	mainFrame:SetBackdropBorderColor(0, 0.8, 1, 0.5)
	
	-- Title bar
	local titleLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleLabel:SetPoint("TOP", 0, -10)
	titleLabel:SetText("|cff00ccffInfinity Suite|r")
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function()
		mainFrame:Hide()
		if _G.InfinityMessaging then
			pcall(function() _G.InfinityMessaging:Publish("INFINITY_WINDOW_HIDDEN", "MainWindow") end)
		end
	end)
	
	-- Tab buttons
	local tabs = {
		"Overview",
		"Characters",
		"Features",
		"Addons",
		"Settings",
		"Keybinds",
		"Debug",
	}
	
	for i, tabName in ipairs(tabs) do
		local tabBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
		tabBtn:SetSize(84, 22)
		tabBtn:SetPoint("TOPLEFT", 12 + (i-1) * 88, -36)
		tabBtn:SetText(tabName)
		tabBtn:SetScript("OnClick", function()
			self:ShowTab(mainFrame, tabName)
		end)
	end
	
	-- Content area
	mainFrame.contentFrame = CreateFrame("Frame", nil, mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mainFrame.contentFrame:SetSize(610, 420)
	mainFrame.contentFrame:SetPoint("TOP", 0, -68)
	
	-- Show overview by default
	self:ShowTab(mainFrame, "Overview")
	
	return mainFrame
end

function InfinityMainFrame:ShowTab(frame, tabName)
	frame.currentTab = tabName
	-- Clear previous content
	frame.contentFrame:SetScript("OnUpdate", nil)
	InfinityUtils:ClearContainer(frame.contentFrame)
	
	if tabName == "Overview" then
		self:ShowOverviewTab(frame)
	elseif tabName == "Characters" then
		self:ShowCharactersTab(frame)
	elseif tabName == "Features" then
		self:ShowFeaturesTab(frame)
	elseif tabName == "Addons" then
		self:ShowAddonsTab(frame)
	elseif tabName == "Settings" then
		self:ShowSettingsTab(frame)
	elseif tabName == "Keybinds" then
		self:ShowKeybindsTab(frame)
	elseif tabName == "Debug" then
		self:ShowDebugTab(frame)
	end
end

function InfinityMainFrame:RefreshIfVisible()
	if _G.InfinityMainWindow and _G.InfinityMainWindow:IsShown() then
		self:ShowTab(_G.InfinityMainWindow, _G.InfinityMainWindow.currentTab or "Overview")
	end
end

function InfinityMainFrame:ShowOverviewTab(frame)
	local y = -10
	
	-- Welcome message
	local welcome = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Welcome to Infinity Suite" .. INFINITY_COLORS.RESET)
	welcome:SetPoint("TOPLEFT", 10, y)
	welcome:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	y = y - 30
	
	-- Status info
	local stats = InfinityDataManager:GetStatistics()
	local statusInfo = {
		"Infinity Suite v" .. INFINITY_SUITE_VERSION,
		"Data Sources: " .. stats.enabledSources .. "/" .. stats.totalSources,
		"Cached Data Points: " .. stats.totalDataPoints,
		"",
		"Feature changes take effect after reloading the UI",
		"Use the Settings tab to configure features",
		"Use the Keybinds tab to manage shortcuts",
	}
	
	for _, text in ipairs(statusInfo) do
		local label = InfinityUIFramework:CreateLabel(frame.contentFrame, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
end

function InfinityMainFrame:ShowCharactersTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Your Characters" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	y = y - 30
	
	-- Current character
	local currentChar = InfinityCharacterManager and InfinityCharacterManager:GetCurrentCharacter()
	if not currentChar then
		local pendingLabel = InfinityUIFramework:CreateLabel(frame.contentFrame,
			INFINITY_COLORS.WARNING .. "Character data loading... (reopen after login)" .. INFINITY_COLORS.RESET)
		pendingLabel:SetPoint("TOPLEFT", 10, y)
		return
	end
	local currentLabel = InfinityUIFramework:CreateLabel(frame.contentFrame,
		INFINITY_COLORS.SECONDARY .. currentChar.name .. INFINITY_COLORS.RESET .. 
		" (Level " .. currentChar.level .. " " .. tostring(currentChar.class) .. ")")
	currentLabel:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	local charType = currentChar.isMain and "MAIN" or "TWINK"
	local typeColor = currentChar.isMain and INFINITY_COLORS.SUCCESS or INFINITY_COLORS.WARNING
	local typeLabel = InfinityUIFramework:CreateLabel(frame.contentFrame,
		"Status: " .. typeColor .. charType .. INFINITY_COLORS.RESET)
	typeLabel:SetPoint("TOPLEFT", 10, y)
	if not currentChar.isMain then
		local makeCurMainBtn = InfinityUIFramework:CreateButton(frame.contentFrame, "Set Current as Main", 130, 20, function()
			local key = InfinityCharacterManager:GetCharacterKey(currentChar.name, currentChar.realm)
			InfinityCharacterManager:MarkAsMain(key)
			self:ShowTab(frame, "Characters")
		end)
		makeCurMainBtn:SetPoint("TOPRIGHT", -20, y + 2)
	end
	y = y - 20
	
	if currentChar.linkedTo then
		local linkedLabel = InfinityUIFramework:CreateLabel(frame.contentFrame,
			"Linked to: " .. INFINITY_COLORS.INFO .. currentChar.linkedTo .. INFINITY_COLORS.RESET)
		linkedLabel:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
	
	y = y - 10
	
	-- All characters
	local allTitle = InfinityUIFramework:CreateLabel(frame.contentFrame, "All Characters:")
	allTitle:SetPoint("TOPLEFT", 10, y)
	y = y - 22
	
	local characters = InfinityCharacterManager:GetAllCharacters()
	table.sort(characters, function(a, b)
		if a.name == b.name then return (a.realm or "") < (b.realm or "") end
		return a.name < b.name
	end)
	local scroll = CreateFrame("ScrollFrame", nil, frame.contentFrame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, y)
	scroll:SetSize(570, math.max(1, 380 + y))
	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(540, math.max(1, #characters * 22))
	scroll:SetScrollChild(list)
	for i, char in ipairs(characters) do
		local rowY = -(i - 1) * 22
		local charStr = char.name .. " - " .. (char.realm or "?") .. " - Level " .. char.level .. " " .. tostring(char.class)
		if char.isMain then
			charStr = charStr .. " " .. INFINITY_COLORS.SUCCESS .. "[MAIN]" .. INFINITY_COLORS.RESET
		elseif char.linkedTo then
			charStr = charStr .. " " .. INFINITY_COLORS.WARNING .. "[" .. char.linkedTo .. "]" .. INFINITY_COLORS.RESET
		end
		
		local charLabel = InfinityUIFramework:CreateLabel(list, charStr)
		charLabel:SetPoint("TOPLEFT", 0, rowY)
		
		if not char.isMain then
			local targetKey = InfinityCharacterManager:GetCharacterKey(char.name, char.realm)
			local setMainBtn = InfinityUIFramework:CreateButton(list, "Set Main", 80, 18, function()
				InfinityCharacterManager:MarkAsMain(targetKey)
				self:ShowTab(frame, "Characters")
			end)
			setMainBtn:SetPoint("TOPRIGHT", 0, rowY + 2)
		end
	end
	scroll:UpdateScrollChildRect()
	
	-- Character stats
	local stats = InfinityCharacterManager:GetCharacterStats()
	local statsLabel = InfinityUIFramework:CreateLabel(frame.contentFrame,
		"Total: " .. stats.totalCharacters .. " | " ..
		stats.mains .. " Mains | " ..
		stats.twinks .. " Twinks")
	statsLabel:SetPoint("BOTTOMLEFT", 10, 10)
end

function InfinityMainFrame:ShowFeaturesTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Feature Modules" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	y = y - 30
	local hint = InfinityUIFramework:CreateLabel(frame.contentFrame, "Open loaded modules here. Enable/disable changes apply after /reload.")
	hint:SetPoint("TOPLEFT", 10, y)
	local scroll = CreateFrame("ScrollFrame", nil, frame.contentFrame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, y - 24)
	scroll:SetSize(555, 310)
	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(525, 1)
	scroll:SetScrollChild(list)
	y = -5

	local features = {}
	local api = _G.C_AddOns
	local getCount = api and api.GetNumAddOns or _G.GetNumAddOns
	local getInfo = api and api.GetAddOnInfo or _G.GetAddOnInfo
	if getCount and getInfo then
		for i = 1, getCount() do
			local name = getInfo(i)
			if type(name) == "string" and name:match("^Infinity") and name ~= INFINITY_CORE_NAME then
				table.insert(features, name)
			end
		end
	else
		for _, name in pairs(INFINITY_FEATURES) do table.insert(features, name) end
	end
	table.sort(features)
	
	for _, feature in ipairs(features) do
		local targetFeature = feature
		local isEnabled = InfinityStorageManager:IsFeatureEnabled(targetFeature)
		local nextState = not isEnabled
		local status = isEnabled == nil and INFINITY_COLORS.WARNING .. "Unavailable" or
			(isEnabled and INFINITY_COLORS.SECONDARY .. "Enabled" or "|cffccccccDisabled")
		
		local label = InfinityUIFramework:CreateLabel(list,
			targetFeature .. ": " .. status .. INFINITY_COLORS.RESET)
		label:SetPoint("TOPLEFT", 10, y)
		
		local toggleBtn = InfinityUIFramework:CreateButton(list, isEnabled and "Disable" or "Enable", 80, 20,
			function()
				InfinityStorageManager:SetFeatureEnabled(targetFeature, nextState)
				self:ShowTab(frame, "Features")
			end)
		toggleBtn:SetPoint("TOPRIGHT", -20, y + 2)
		if isEnabled == nil then toggleBtn:Disable() end
		local window = AvailableFeatureWindow(targetFeature)
		local openBtn = InfinityUIFramework:CreateButton(list, "Open", 65, 20, function()
			self:OpenFeature(targetFeature)
		end)
		openBtn:SetPoint("RIGHT", toggleBtn, "LEFT", -5, 0)
		if not window then openBtn:Disable() end
		
		y = y - 28
	end
	list:SetHeight(math.max(1, -y))
	scroll:UpdateScrollChildRect()
end

function InfinityMainFrame:ShowAddonsTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Addon Manager" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	y = y - 30
	
	-- Get all registered addons
	local addons = {}
	if _G.InfinityAddonManager and _G.InfinityAddonManager.GetAllAddons then
		addons = _G.InfinityAddonManager:GetAllAddons()
	end
	
	if #addons == 0 then
		local noAddonsLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
			INFINITY_COLORS.WARNING .. "No addons registered" .. INFINITY_COLORS.RESET)
		noAddonsLabel:SetPoint("TOPLEFT", 10, y)
		return
	end
	
	for _, addon in ipairs(addons) do
		local isEnabled = addon.enabled
		local status = isEnabled == nil and INFINITY_COLORS.WARNING .. "?" or
			(isEnabled and INFINITY_COLORS.SUCCESS .. "✓" or INFINITY_COLORS.ERROR .. "✗")
		local addonText = status .. INFINITY_COLORS.RESET .. " " .. addon.name .. " v" .. addon.version
		
		local label = InfinityUIFramework:CreateLabel(frame.contentFrame, addonText)
		label:SetPoint("TOPLEFT", 10, y)
		
		local toggleBtn = InfinityUIFramework:CreateButton(frame.contentFrame, isEnabled and "Disable" or "Enable", 70, 20, 
			function()
				if _G.InfinityAddonManager then
					_G.InfinityAddonManager:SetAddonEnabled(addon.name, not isEnabled)
					self:ShowTab(frame, "Addons")
				end
			end)
		toggleBtn:SetPoint("TOPRIGHT", -20, y - 2)
		if isEnabled == nil then toggleBtn:Disable() end
		
		y = y - 22
		if y < -370 then break end
	end
	
	-- Summary
	local enabledCount = 0
	for _, addon in ipairs(addons) do
		if addon.enabled then enabledCount = enabledCount + 1 end
	end
	
	y = y - 10
	local summaryLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.INFO .. "Enabled: " .. enabledCount .. "/" .. #addons .. INFINITY_COLORS.RESET)
	summaryLabel:SetPoint("TOPLEFT", 10, y)
end

function InfinityMainFrame:ShowSettingsTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Global Settings" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	y = y - 30
	
	-- Theme selector
	local themeLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, "Theme: ")
	themeLabel:SetPoint("TOPLEFT", 10, y)
	
	local themeDropdown = InfinityUIFramework:CreateDropdown(frame.contentFrame, 
		{"default", "dark"}, 
		InfinityStorageManager:GetProfile("theme", "default"),
		function(selected)
			InfinityUIFramework:LoadTheme(selected)
		end)
	themeDropdown:SetPoint("TOPLEFT", 80, y - 10)
	
	y = y - 35
	
	-- Minimap button toggle
	local minimapLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, "Show Minimap Button:")
	minimapLabel:SetPoint("TOPLEFT", 10, y)
	
	local minimapCheckbox = CreateFrame("CheckButton", nil, frame.contentFrame, "UICheckButtonTemplate")
	minimapCheckbox:SetPoint("TOPLEFT", 180, y)
	minimapCheckbox:SetChecked(InfinityStorageManager:GetProfile("minimap.enabled", true))
	minimapCheckbox:SetScript("OnClick", function(self)
		local enabled = self:GetChecked() == true
		if _G.InfinitySettingsPanel and InfinitySettingsPanel.SetSetting then
			InfinitySettingsPanel:SetSetting("General", "Show Minimap Button", enabled)
		else
			InfinityStorageManager:SetProfile("minimap.enabled", enabled)
			if _G.InfinityUIIntegration and InfinityUIIntegration.UpdateMinimapVisibility then
				InfinityUIIntegration:UpdateMinimapVisibility()
			end
		end
	end)
	
	y = y - 30
	
	-- Notifications toggle
	local notifLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, "Enable Notifications:")
	notifLabel:SetPoint("TOPLEFT", 10, y)
	
	local notifCheckbox = CreateFrame("CheckButton", nil, frame.contentFrame, "UICheckButtonTemplate")
	notifCheckbox:SetPoint("TOPLEFT", 180, y)
	notifCheckbox:SetChecked(InfinityStorageManager:GetProfile("notifications.enabled", true))
	notifCheckbox:SetScript("OnClick", function(self)
		InfinityStorageManager:SetProfile("notifications.enabled", self:GetChecked())
	end)
	
	y = y - 40
	local openBlizzBtn = InfinityUIFramework:CreateButton(frame.contentFrame, "Open Game AddOn Settings", 200, 24, function()
		if _G.InfinitySettingsPanel and _G.InfinitySettingsPanel.OpenBlizzardSettings then
			_G.InfinitySettingsPanel:OpenBlizzardSettings()
		end
	end)
	openBlizzBtn:SetPoint("TOPLEFT", 10, y)
end

function InfinityMainFrame:ShowKeybindsTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Keybind Management" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	y = y - 30
	
	local keybindData = InfinityCommandRegistry:GetKeybindUIData()
	
	for _, keybind in ipairs(keybindData) do
		local actionName = keybind.action
		local keyText = keybind.currentKey or "(unbound)"
		local label = InfinityUIFramework:CreateLabel(frame.contentFrame, 
			keybind.description .. ": " .. INFINITY_COLORS.SECONDARY .. keyText .. INFINITY_COLORS.RESET)
		label:SetPoint("TOPLEFT", 10, y)
		
		local bindBtn = InfinityUIFramework:CreateButton(frame.contentFrame, keybind.currentKey or "Set Key", 95, 20)
		bindBtn:SetPoint("TOPRIGHT", -75, y + 2)
		bindBtn:SetScript("OnClick", function(btn)
			btn:SetText("Press Key...")
			btn:EnableKeyboard(true)
			btn:SetPropagateKeyboardInput(false)
			btn:SetScript("OnKeyDown", function(selfBtn, key)
				if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
					return
				end
				selfBtn:EnableKeyboard(false)
				selfBtn:SetScript("OnKeyDown", nil)
				if key == "ESCAPE" then
					self:ShowTab(frame, "Keybinds")
					return
				end
				local combo = ""
				if IsAltKeyDown() then combo = combo .. "ALT-" end
				if IsControlKeyDown() then combo = combo .. "CTRL-" end
				if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
				combo = combo .. key
				InfinityCommandRegistry:SetKeybind(actionName, combo)
				self:ShowTab(frame, "Keybinds")
			end)
		end)
		
		local clearBtn = InfinityUIFramework:CreateButton(frame.contentFrame, "Clear", 50, 20, function()
			InfinityCommandRegistry:SetKeybind(actionName, "")
			self:ShowTab(frame, "Keybinds")
		end)
		clearBtn:SetPoint("TOPRIGHT", -20, y + 2)
		
		y = y - 24
		if y < -360 then break end
	end
	
	-- Reset button
	local resetBtn = InfinityUIFramework:CreateButton(frame.contentFrame, "Reset All", 100, 25,
		function()
			InfinityCommandRegistry:ResetKeybindsToDefault()
			self:ShowTab(frame, "Keybinds")
		end)
	resetBtn:SetPoint("BOTTOMLEFT", 10, 10)
end

function InfinityMainFrame:ShowDebugTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Debug Information" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	y = y - 30
	
	-- Data Manager stats
	local dataStats = InfinityDataManager:GetStatistics()
	local debugInfo = {
		"=== System Status ===",
		"Suite Version: " .. INFINITY_SUITE_VERSION,
		"",
		"=== Data Sources ===",
		"Total: " .. dataStats.totalSources,
		"Enabled: " .. dataStats.enabledSources,
		"Data Points: " .. dataStats.totalDataPoints,
		"",
		"=== Event System ===",
	}
	
	local eventStats = InfinityEventRouter:GetStatistics()
	table.insert(debugInfo, "Registered WoW Events: " .. eventStats.registeredEvents)
	table.insert(debugInfo, "Total Listeners: " .. eventStats.activeListeners .. "/" .. eventStats.totalListeners)
	
	table.insert(debugInfo, "")
	table.insert(debugInfo, "=== Commands ===")
	
	local cmdStats = InfinityCommandRegistry:GetStatistics()
	table.insert(debugInfo, "Commands: " .. cmdStats.commandCount)
	table.insert(debugInfo, "Keybinds: " .. cmdStats.keybindCount)
	
	for _, text in ipairs(debugInfo) do
		local label = InfinityUIFramework:CreateLabel(frame.contentFrame, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 15
	end
end

function InfinityMainFrame:Toggle()
	if _G.InfinityMainWindow then
		if _G.InfinityMainWindow:IsVisible() then
			_G.InfinityMainWindow:Hide()
			InfinityMessaging:Publish(INFINITY_EVENTS.WINDOW_HIDDEN, "MainWindow")
		else
			_G.InfinityMainWindow:Show()
			InfinityMessaging:Publish(INFINITY_EVENTS.WINDOW_SHOWN, "MainWindow")
		end
	else
		self:Create()
	end
end

return InfinityMainFrame
