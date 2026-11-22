-- InfinityCore Main Frame
-- Upgraded WoW Forever primary suite hub with non-overlapping tabs and BackdropTemplate safety

InfinityMainFrame = {}

function InfinityMainFrame:Create()
	if _G.InfinityMainWindow then
		return _G.InfinityMainWindow
	end

	local UI = _G.InfinityUIFramework
	local mainFrame = UI:CreateFrame("InfinityMainWindow", UIParent, 680, 460, "InfinityForever Suite Hub")
	mainFrame:SetPoint("CENTER")

	if mainFrame.closeBtn then
		mainFrame.closeBtn:SetScript("OnClick", function()
			mainFrame:Hide()
			if _G.InfinityMessaging then
				pcall(function() _G.InfinityMessaging:Publish("INFINITY_WINDOW_HIDDEN", "MainWindow") end)
			end
		end)
	end

	-- 7 evenly sized tabs fitting cleanly inside 680px width
	local tabs = { "Overview", "Characters", "Features", "Addons", "Settings", "Keybinds", "Debug" }
	mainFrame.tabButtons = {}
	local tabWidth = 88
	for i, tabName in ipairs(tabs) do
		local tabBtn = UI:CreateButton(mainFrame, tabName, tabWidth, 26, function()
			self:ShowTab(mainFrame, tabName)
		end)
		tabBtn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14 + (i - 1) * (tabWidth + 5), -44)
		mainFrame.tabButtons[tabName] = tabBtn
	end

	-- Content panel
	local contentFrame = CreateFrame("Frame", nil, mainFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	contentFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -78)
	contentFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 14)
	UI:ApplyBackdrop(contentFrame, 0.09, 0.11, 0.16, 0.95, 0.22, 0.28, 0.38, 0.85)
	mainFrame.contentFrame = contentFrame

	self:ShowTab(mainFrame, "Overview")
	return mainFrame
end

function InfinityMainFrame:ShowTab(frame, tabName)
	local UI = _G.InfinityUIFramework
	frame.contentFrame:SetScript("OnUpdate", nil)
	UI:ClearContainer(frame.contentFrame)

	for name, btn in pairs(frame.tabButtons or {}) do
		btn:SetActiveState(name == tabName)
	end

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

function InfinityMainFrame:ShowOverviewTab(frame)
	local UI = _G.InfinityUIFramework
	local y = -16

	local welcome = UI:CreateLabel(frame.contentFrame, "InfinityForever Suite — WoW Forever (Interface 16001)", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	welcome:SetPoint("TOPLEFT", 16, y)
	y = y - 34

	local stats = InfinityDataManager and InfinityDataManager:GetStatistics() or { enabledSources = 0, totalSources = 0, totalDataPoints = 0 }
	local lines = {
		"Suite Version: " .. tostring(INFINITY_SUITE_VERSION or "1.1.0"),
		"Active Data Sources: " .. tostring(stats.enabledSources) .. " / " .. tostring(stats.totalSources),
		"Cached Data Points: " .. tostring(stats.totalDataPoints),
		"",
		"Quick Launch Modules:",
	}
	for _, text in ipairs(lines) do
		local lbl = UI:CreateLabel(frame.contentFrame, text)
		lbl:SetPoint("TOPLEFT", 16, y)
		y = y - 20
	end

	local dashBtn = UI:CreateButton(frame.contentFrame, "Officer Dashboard", 145, 28, function()
		if InfinityCore and InfinityCore.OfficerDashboard then
			InfinityCore.OfficerDashboard:Show()
		end
	end, true)
	dashBtn:SetPoint("TOPLEFT", 16, y - 6)

	local dkpBtn = UI:CreateButton(frame.contentFrame, "DKP Manager", 130, 28, function()
		if _G.InfinityDKPUI then _G.InfinityDKPUI:Show() end
	end)
	dkpBtn:SetPoint("LEFT", dashBtn, "RIGHT", 10, 0)

	local aucBtn = UI:CreateButton(frame.contentFrame, "Loot Auctions", 130, 28, function()
		if _G.InfinityLootAuctionUI and _G.InfinityLootAuctionUI.CreateAuctionFrame then
			_G.InfinityLootAuctionUI:CreateAuctionFrame()
		end
	end)
	aucBtn:SetPoint("LEFT", dkpBtn, "RIGHT", 10, 0)
end

function InfinityMainFrame:ShowCharactersTab(frame)
	local UI = _G.InfinityUIFramework
	local y = -16
	local title = UI:CreateLabel(frame.contentFrame, "Characters & Alt Links", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, y)
	y = y - 32

	if not InfinityCharacterManager then return end
	local currentChar = InfinityCharacterManager:GetCurrentCharacter()
	if currentChar then
		local curr = UI:CreateLabel(frame.contentFrame, currentChar.name .. " — Level " .. tostring(currentChar.level) .. " " .. tostring(currentChar.class))
		curr:SetPoint("TOPLEFT", 16, y)
		y = y - 24
	end

	local characters = InfinityCharacterManager:GetAllCharacters() or {}
	for i, char in ipairs(characters) do
		if i > 10 then break end
		local tag = char.isMain and " [MAIN]" or (char.linkedTo and (" [" .. char.linkedTo .. "]") or "")
		local lbl = UI:CreateLabel(frame.contentFrame, char.name .. " — Lv " .. tostring(char.level) .. " " .. tostring(char.class) .. tag, 0.80, 0.85, 0.92)
		lbl:SetPoint("TOPLEFT", 24, y)
		y = y - 20
	end
end

function InfinityMainFrame:ShowFeaturesTab(frame)
	local UI = _G.InfinityUIFramework
	local y = -16
	local title = UI:CreateLabel(frame.contentFrame, "Feature Modules", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, y)
	y = y - 34

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
		local isEnabled = InfinityStorageManager and InfinityStorageManager:IsFeatureEnabled(feature)
		local status = isEnabled and "|cff4ade80Enabled|r" or "|cff94a3b8Disabled|r"
		local lbl = UI:CreateLabel(frame.contentFrame, tostring(feature) .. " — " .. status)
		lbl:SetPoint("TOPLEFT", 16, y)

		local toggleBtn = UI:CreateButton(frame.contentFrame, isEnabled and "Disable" or "Enable", 84, 22, function()
			if InfinityStorageManager then
				InfinityStorageManager:SetFeatureEnabled(feature, not isEnabled)
			end
			if InfinityMessaging and INFINITY_EVENTS then
				InfinityMessaging:Publish(INFINITY_EVENTS.FEATURE_ENABLED, feature, not isEnabled)
			end
			self:ShowTab(frame, "Features")
		end, not isEnabled)
		toggleBtn:SetPoint("TOPRIGHT", frame.contentFrame, "TOPRIGHT", -16, y + 3)
		y = y - 32
	end
end

function InfinityMainFrame:ShowAddonsTab(frame)
	local UI = _G.InfinityUIFramework
	local y = -16
	local title = UI:CreateLabel(frame.contentFrame, "Registered Suite Addons", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, y)
	y = y - 32

	local addons = (_G.InfinityAddonManager and _G.InfinityAddonManager.GetAllAddons)
		and _G.InfinityAddonManager:GetAllAddons() or {}

	if #addons == 0 then
		local empty = UI:CreateLabel(frame.contentFrame, "No addons registered yet.", 0.7, 0.75, 0.82)
		empty:SetPoint("TOPLEFT", 16, y)
		return
	end

	for i, addon in ipairs(addons) do
		if i > 10 then break end
		local isEnabled = addon.enabled == true
		local badge = isEnabled and "|cff4ade80ON|r" or "|cfff87171OFF|r"
		local lbl = UI:CreateLabel(frame.contentFrame, badge .. "  " .. addon.name .. " v" .. tostring(addon.version))
		lbl:SetPoint("TOPLEFT", 16, y)

		local btn = UI:CreateButton(frame.contentFrame, isEnabled and "Disable" or "Enable", 80, 22, function()
			_G.InfinityAddonManager:SetAddonEnabled(addon.name, not isEnabled)
			self:ShowTab(frame, "Addons")
		end)
		btn:SetPoint("TOPRIGHT", frame.contentFrame, "TOPRIGHT", -16, y + 3)
		y = y - 28
	end
end

function InfinityMainFrame:ShowSettingsTab(frame)
	local UI = _G.InfinityUIFramework
	local y = -16
	local title = UI:CreateLabel(frame.contentFrame, "Global Suite Settings", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, y)
	y = y - 36

	local minimapCb = UI:CreateCheckbox(
		frame.contentFrame,
		"Show Minimap Launcher Button",
		InfinityStorageManager and InfinityStorageManager:GetProfile("minimap.enabled", true),
		function(val)
			if InfinityStorageManager then InfinityStorageManager:SetProfile("minimap.enabled", val) end
		end
	)
	minimapCb:SetPoint("TOPLEFT", 16, y)
	y = y - 34

	local notifCb = UI:CreateCheckbox(
		frame.contentFrame,
		"Enable Toast Notifications",
		InfinityStorageManager and InfinityStorageManager:GetProfile("notifications.enabled", true),
		function(val)
			if InfinityStorageManager then InfinityStorageManager:SetProfile("notifications.enabled", val) end
		end
	)
	notifCb:SetPoint("TOPLEFT", 16, y)
end

function InfinityMainFrame:ShowKeybindsTab(frame)
	local UI = _G.InfinityUIFramework
	local y = -16
	local title = UI:CreateLabel(frame.contentFrame, "Keybind Management", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, y)
	y = y - 32

	local keybindData = InfinityCommandRegistry and InfinityCommandRegistry:GetKeybindUIData() or {}
	for i, kb in ipairs(keybindData) do
		if i > 10 then break end
		local lbl = UI:CreateLabel(frame.contentFrame, tostring(kb.description) .. ": |cff4ade80" .. tostring(kb.currentKey or "(unbound)") .. "|r")
		lbl:SetPoint("TOPLEFT", 16, y)
		y = y - 22
	end

	local resetBtn = UI:CreateButton(frame.contentFrame, "Reset Defaults", 120, 26, function()
		if InfinityCommandRegistry then
			InfinityCommandRegistry:ResetKeybindsToDefault()
		end
		self:ShowTab(frame, "Keybinds")
	end)
	resetBtn:SetPoint("BOTTOMLEFT", frame.contentFrame, "BOTTOMLEFT", 16, 16)
end

function InfinityMainFrame:ShowDebugTab(frame)
	local UI = _G.InfinityUIFramework
	local y = -16
	local title = UI:CreateLabel(frame.contentFrame, "Suite Diagnostics", 0.22, 0.74, 0.97, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, y)
	y = y - 32

	local dataStats = InfinityDataManager and InfinityDataManager:GetStatistics() or { totalSources = 0, enabledSources = 0, totalDataPoints = 0 }
	local eventStats = InfinityEventRouter and InfinityEventRouter:GetStatistics() or { registeredEvents = 0, activeListeners = 0, totalListeners = 0 }
	local cmdStats = InfinityCommandRegistry and InfinityCommandRegistry:GetStatistics() or { commandCount = 0, keybindCount = 0 }

	local rows = {
		"Suite Version: " .. tostring(INFINITY_SUITE_VERSION or "1.1.0"),
		"Data Sources: " .. tostring(dataStats.enabledSources) .. " / " .. tostring(dataStats.totalSources),
		"Cached Data Points: " .. tostring(dataStats.totalDataPoints),
		"Registered WoW Events: " .. tostring(eventStats.registeredEvents),
		"Event Listeners: " .. tostring(eventStats.activeListeners) .. " / " .. tostring(eventStats.totalListeners),
		"Slash Commands: " .. tostring(cmdStats.commandCount),
		"Registered Keybinds: " .. tostring(cmdStats.keybindCount),
	}
	for _, text in ipairs(rows) do
		local lbl = UI:CreateLabel(frame.contentFrame, text)
		lbl:SetPoint("TOPLEFT", 16, y)
		y = y - 22
	end
end

function InfinityMainFrame:Toggle()
	if _G.InfinityMainWindow then
		if _G.InfinityMainWindow:IsVisible() then
			_G.InfinityMainWindow:Hide()
		else
			_G.InfinityMainWindow:Show()
		end
	else
		self:Create():Show()
	end
end

return InfinityMainFrame
