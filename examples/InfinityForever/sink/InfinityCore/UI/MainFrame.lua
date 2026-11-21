-- InfinityCore Main Frame
-- Primary UI window for the suite

InfinityMainFrame = {}

function InfinityMainFrame:Create()
	if _G.InfinityMainWindow then
		return _G.InfinityMainWindow
	end
	
	local mainFrame = InfinityUIFramework:CreateFrame("InfinityMainWindow", UIParent, 500, 400)
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
	
	-- Title bar
	local titleLabel = InfinityUIFramework:CreateLabel(mainFrame, INFINITY_COLORS.PRIMARY .. "Infinity Suite" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOP", 0, -10)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 16)
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function()
		mainFrame:Hide()
		InfinityMessaging:Publish(INFINITY_EVENTS.WINDOW_HIDDEN, "MainWindow")
	end)
	
	-- Tab buttons
	local tabs = {
		"Overview",
		"Characters",
		"Features",
		"Settings",
		"Keybinds",
		"Debug",
	}
	
	for i, tabName in ipairs(tabs) do
		local tabBtn = InfinityUIFramework:CreateButton(mainFrame, tabName, 80, 20, function()
			self:ShowTab(mainFrame, tabName)
		end)
		tabBtn:SetPoint("TOPLEFT", 10 + (i-1) * 90, -35)
	end
	
	-- Content area
	mainFrame.contentFrame = CreateFrame("Frame", nil, mainFrame)
	mainFrame.contentFrame:SetSize(480, 320)
	mainFrame.contentFrame:SetPoint("TOP", 0, -60)
	
	-- Show overview by default
	self:ShowTab(mainFrame, "Overview")
	
	return mainFrame
end

function InfinityMainFrame:ShowTab(frame, tabName)
	-- Clear previous content
	frame.contentFrame:SetScript("OnUpdate", nil)
	for i = 1, frame.contentFrame:GetNumChildren() do
		frame.contentFrame:GetChild(i):Hide()
	end
	
	if tabName == "Overview" then
		self:ShowOverviewTab(frame)
	elseif tabName == "Characters" then
		self:ShowCharactersTab(frame)
	elseif tabName == "Features" then
		self:ShowFeaturesTab(frame)
	elseif tabName == "Settings" then
		self:ShowSettingsTab(frame)
	elseif tabName == "Keybinds" then
		self:ShowKeybindsTab(frame)
	elseif tabName == "Debug" then
		self:ShowDebugTab(frame)
	end
end

function InfinityMainFrame:ShowOverviewTab(frame)
	local y = -10
	
	-- Welcome message
	local welcome = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Welcome to Infinity Suite" .. INFINITY_COLORS.RESET)
	welcome:SetPoint("TOPLEFT", 10, y)
	welcome:SetFont("Fonts/FRIZQT__.TTF", 14)
	
	y = y - 30
	
	-- Status info
	local stats = InfinityDataManager:GetStatistics()
	local statusInfo = {
		"Infinity Suite v" .. INFINITY_SUITE_VERSION,
		"Data Sources: " .. stats.enabledSources .. "/" .. stats.totalSources,
		"Cached Data Points: " .. stats.totalDataPoints,
		"",
		"Use the Feature tab to enable/disable modules",
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
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14)
	
	y = y - 30
	
	-- Current character
	local currentChar = InfinityCharacterManager:GetCurrentCharacter()
	local currentLabel = InfinityUIFramework:CreateLabel(frame.contentFrame,
		INFINITY_COLORS.SECONDARY .. currentChar.name .. INFINITY_COLORS.RESET .. 
		" (Level " .. currentChar.level .. " " .. currentChar.class .. ")")
	currentLabel:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	local charType = currentChar.isMain and "MAIN" or "TWINK"
	local typeColor = currentChar.isMain and INFINITY_COLORS.SUCCESS or INFINITY_COLORS.WARNING
	local typeLabel = InfinityUIFramework:CreateLabel(frame.contentFrame,
		"Status: " .. typeColor .. charType .. INFINITY_COLORS.RESET)
	typeLabel:SetPoint("TOPLEFT", 10, y)
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
	y = y - 20
	
	local characters = InfinityCharacterManager:GetAllCharacters()
	for i, char in ipairs(characters) do
		if i > 8 then break end
		
		local charStr = char.name .. " - Level " .. char.level .. " " .. char.class
		if char.isMain then
			charStr = charStr .. " " .. INFINITY_COLORS.SUCCESS .. "[MAIN]" .. INFINITY_COLORS.RESET
		elseif char.linkedTo then
			charStr = charStr .. " " .. INFINITY_COLORS.WARNING .. "[" .. char.linkedTo .. "]" .. INFINITY_COLORS.RESET
		end
		
		local charLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, charStr)
		charLabel:SetPoint("TOPLEFT", 20, y)
		y = y - 15
	end
	
	-- Character stats
	y = y - 10
	local stats = InfinityCharacterManager:GetCharacterStats()
	local statsLabel = InfinityUIFramework:CreateLabel(frame.contentFrame,
		"Total: " .. stats.totalCharacters .. " | " ..
		stats.mains .. " Mains | " ..
		stats.twinks .. " Twinks")
	statsLabel:SetPoint("TOPLEFT", 10, y)
end

function InfinityMainFrame:ShowFeaturesTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Feature Modules" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14)
	
	y = y - 30
	
	local features = {
		INFINITY_FEATURES.LOOT,
		INFINITY_FEATURES.GUILD,
		INFINITY_FEATURES.RAID,
		INFINITY_FEATURES.GATHER,
		INFINITY_FEATURES.GUIDE,
		INFINITY_FEATURES.GEAR,
		INFINITY_FEATURES.QOL,
	}
	
	for _, feature in ipairs(features) do
		local isEnabled = InfinityStorageManager:IsFeatureEnabled(feature)
		local status = isEnabled and INFINITY_COLORS.SECONDARY .. "✓ Enabled" or "|cffcccccc✗ Disabled"
		
		local label = InfinityUIFramework:CreateLabel(frame.contentFrame, 
			feature .. ": " .. status .. INFINITY_COLORS.RESET)
		label:SetPoint("TOPLEFT", 10, y)
		
		local toggleBtn = InfinityUIFramework:CreateButton(frame.contentFrame, isEnabled and "Disable" or "Enable", 70, 20, 
			function()
				InfinityStorageManager:SetFeatureEnabled(feature, not isEnabled)
				InfinityMessaging:Publish(INFINITY_EVENTS.FEATURE_ENABLED, feature, not isEnabled)
				self:ShowTab(frame, "Features")
			end)
		toggleBtn:SetPoint("TOPRIGHT", -20, y - 2)
		
		y = y - 25
	end
end

function InfinityMainFrame:ShowSettingsTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Global Settings" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14)
	
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
		InfinityStorageManager:SetProfile("minimap.enabled", self:GetChecked())
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
end

function InfinityMainFrame:ShowKeybindsTab(frame)
	local y = -10
	
	local titleLabel = InfinityUIFramework:CreateLabel(frame.contentFrame, 
		INFINITY_COLORS.PRIMARY .. "Keybind Management" .. INFINITY_COLORS.RESET)
	titleLabel:SetPoint("TOPLEFT", 10, y)
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14)
	
	y = y - 30
	
	local keybindData = InfinityCommandRegistry:GetKeybindUIData()
	
	for _, keybind in ipairs(keybindData) do
		local keyText = keybind.currentKey or "(unbound)"
		local label = InfinityUIFramework:CreateLabel(frame.contentFrame, 
			keybind.description .. ": " .. INFINITY_COLORS.SECONDARY .. keyText .. INFINITY_COLORS.RESET)
		label:SetPoint("TOPLEFT", 10, y)
		
		y = y - 20
		if y < -300 then break end
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
	titleLabel:SetFont("Fonts/FRIZQT__.TTF", 14)
	
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
