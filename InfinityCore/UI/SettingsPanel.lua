-- InfinityCore Settings Panel
-- Comprehensive flat settings, live theme switching, and keybind viewer for WoW Forever

InfinitySettingsPanel = {
	settings = {},
	categoryOrder = { "General", "Appearance", "Features", "Keybinds" },
	currentCategory = "General",
}

function InfinitySettingsPanel:Initialize()
	self:InitializeDefaultSettings()
	if InfinityUtils and InfinityUtils.Info then
		InfinityUtils:Info("Settings Panel initialized", "SettingsPanel")
	end
end

function InfinitySettingsPanel:InitializeDefaultSettings()
	self.settings = {
		["General"] = {
			{ key = "Enable Tooltips", type = "checkbox", value = true, description = "Display enhanced DKP, item price, and guild tooltips" },
			{ key = "Show Minimap Orb", type = "checkbox", value = true, description = "Show quick launcher orb around the minimap" },
			{ key = "UI Scale", type = "slider", value = 1.0, min = 0.7, max = 1.4, step = 0.05, description = "Overall Infinity UI frame scale" },
			{ key = "Show FPS", type = "checkbox", value = false, description = "Track frame-rate metrics in performance profiler" },
		},
		["Appearance"] = {
			{ key = "Theme", type = "choice", value = InfinityUIFramework and InfinityUIFramework.theme or "obsidian", options = { "obsidian", "light" }, description = "Switch global suite color palette" },
			{ key = "Compact Mode", type = "checkbox", value = false, description = "Use denser row spacing in raid tables and meters" },
			{ key = "Class Colored Names", type = "checkbox", value = true, description = "Color player names by WoW class across all windows" },
		},
		["Features"] = {
			{ key = "Enable Analytics", type = "checkbox", value = true, description = "Track real-time combat performance and DPS/HPS segments" },
			{ key = "Enable Data Collector", type = "checkbox", value = true, description = "Record quest, drop, and node data automatically" },
			{ key = "Enable Notifications", type = "checkbox", value = true, description = "Show non-blocking toast alerts for auctions and boss timers" },
			{ key = "Auto-Save Interval", type = "slider", value = 300, min = 60, max = 1800, step = 60, description = "SavedVariables flush interval (seconds)" },
		},
		["Keybinds"] = {
			{ key = "Toggle Suite Hub", type = "readonly", value = "/infinity (or Minimap Left-Click)", description = "Open Infinity Suite main hub" },
			{ key = "Officer Dashboard", type = "readonly", value = "/officer (or Minimap Right-Click)", description = "Open EPGP / DKP / Audit officer console" },
			{ key = "Live Auction Desk", type = "readonly", value = "/loot auction ui", description = "Open real-time loot auction window" },
			{ key = "Combat Meters", type = "readonly", value = "/details", description = "Toggle real-time DPS / HPS / Threat meters" },
		},
	}
end

function InfinitySettingsPanel:GetSetting(category, key)
	local list = self.settings[category]
	if not list then return nil end
	for _, item in ipairs(list) do
		if item.key == key then return item.value end
	end
	return nil
end

function InfinitySettingsPanel:SetSetting(category, key, value)
	local list = self.settings[category]
	if not list then return false end
	for _, item in ipairs(list) do
		if item.key == key then
			item.value = value
			if InfinityStorageManager and InfinityStorageManager.SetSetting then
				InfinityStorageManager:SetSetting(category, key, value)
			end
			if category == "Appearance" and key == "Theme" and InfinityUIFramework then
				InfinityUIFramework:LoadTheme(value)
			end
			if category == "General" and key == "Show Minimap Orb" and _G.InfinityMinimapButton then
				_G.InfinityMinimapButton:SetShown(value == true)
			end
			if InfinityMessaging and InfinityMessaging.Publish then
				InfinityMessaging:Publish("INFINITY_SETTING_CHANGED", category, key, value)
			end
			return true
		end
	end
	return false
end

function InfinitySettingsPanel:CreateSettingsFrame(parent)
	if not next(self.settings) then
		self:InitializeDefaultSettings()
	end

	local mainFrame = InfinityUIFramework:CreateFrame(
		"InfinitySettingsFrame",
		parent or UIParent,
		660,
		470,
		"Infinity Suite — Settings",
		"Global Preferences"
	)
	mainFrame:SetPoint("CENTER")

	-- Left category column
	local catCard = InfinityUIFramework:CreateCard(mainFrame, 150, 370)
	catCard:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -48)
	mainFrame.categoryButtons = {}

	for idx, catName in ipairs(self.categoryOrder) do
		local btn = InfinityUIFramework:CreateButton(catCard, catName, 134, 28, function()
			InfinitySettingsPanel:ShowCategorySettings(mainFrame, catName)
		end)
		btn:SetPoint("TOPLEFT", catCard, "TOPLEFT", 8, -10 - (idx - 1) * 34)
		mainFrame.categoryButtons[catName] = btn
	end

	-- Right settings card
	local contentCard = InfinityUIFramework:CreateCard(mainFrame, 476, 370)
	contentCard:SetPoint("TOPLEFT", catCard, "TOPRIGHT", 10, 0)

	local scroll = InfinityUIFramework:CreateScrollFrame(contentCard, "InfinitySettingsScroll", 460, 356)
	scroll:SetPoint("TOPLEFT", contentCard, "TOPLEFT", 8, -8)
	mainFrame.contentFrame = scroll.content
	mainFrame.contentScroll = scroll

	-- Footer buttons
	local applyBtn = InfinityUIFramework:CreateButton(mainFrame, "Save & Apply", 120, 28, function()
		InfinitySettingsPanel:ApplySettings()
		mainFrame:Hide()
	end, true)
	applyBtn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -12, 12)

	local closeBtn = InfinityUIFramework:CreateButton(mainFrame, "Close", 90, 28, function()
		mainFrame:Hide()
	end)
	closeBtn:SetPoint("RIGHT", applyBtn, "LEFT", -8, 0)

	self:ShowCategorySettings(mainFrame, self.currentCategory or "General")
	return mainFrame
end

function InfinitySettingsPanel:ShowCategorySettings(mainFrame, category)
	self.currentCategory = category
	if mainFrame.categoryButtons then
		for name, btn in pairs(mainFrame.categoryButtons) do
			btn:SetActiveState(name == category)
		end
	end

	local container = mainFrame.contentFrame
	InfinityUIFramework:ClearContainer(container)

	local heading = InfinityUIFramework:CreateLabel(container, "|cff38bdf8" .. category .. " Settings|r", nil, nil, nil, "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -6)

	local y = -38
	local list = self.settings[category] or {}
	for _, setting in ipairs(list) do
		local row = InfinityUIFramework:CreateCard(container, 430, 56)
		row:SetPoint("TOPLEFT", container, "TOPLEFT", 4, y)

		local lbl = InfinityUIFramework:CreateLabel(row, setting.key)
		lbl:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)

		local desc = InfinityUIFramework:CreateLabel(row, "|cff94a3b8" .. (setting.description or "") .. "|r")
		desc:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)
		desc:SetWidth(270)

		if setting.type == "checkbox" then
			local cb = InfinityUIFramework:CreateCheckbox(row, nil, setting.value, function(checked)
				InfinitySettingsPanel:SetSetting(category, setting.key, checked)
			end)
			cb:SetPoint("RIGHT", row, "RIGHT", -12, 0)
		elseif setting.type == "slider" then
			local valText = InfinityUIFramework:CreateLabel(row, "|cfffbbf24" .. tostring(setting.value) .. "|r")
			valText:SetPoint("RIGHT", row, "RIGHT", -14, 10)

			local minusBtn = InfinityUIFramework:CreateButton(row, "-", 24, 20, function()
				local nv = math.max(setting.min, math.floor(((setting.value - setting.step) * 100) + 0.5) / 100)
				InfinitySettingsPanel:SetSetting(category, setting.key, nv)
				valText:SetText("|cfffbbf24" .. tostring(nv) .. "|r")
			end)
			minusBtn:SetPoint("RIGHT", row, "RIGHT", -46, -10)

			local plusBtn = InfinityUIFramework:CreateButton(row, "+", 24, 20, function()
				local nv = math.min(setting.max, math.floor(((setting.value + setting.step) * 100) + 0.5) / 100)
				InfinitySettingsPanel:SetSetting(category, setting.key, nv)
				valText:SetText("|cfffbbf24" .. tostring(nv) .. "|r")
			end)
			plusBtn:SetPoint("RIGHT", row, "RIGHT", -14, -10)
		elseif setting.type == "choice" then
			local xOff = -10
			for i = #setting.options, 1, -1 do
				local opt = setting.options[i]
				local optBtn = InfinityUIFramework:CreateButton(row, opt:gsub("^%l", string.upper), 68, 22, function()
					InfinitySettingsPanel:SetSetting(category, setting.key, opt)
					InfinitySettingsPanel:ShowCategorySettings(mainFrame, category)
				end, setting.value == opt)
				optBtn:SetPoint("RIGHT", row, "RIGHT", xOff, 0)
				xOff = xOff - 74
			end
		elseif setting.type == "readonly" then
			local valLbl = InfinityUIFramework:CreateLabel(row, "|cff38bdf8" .. tostring(setting.value) .. "|r")
			valLbl:SetPoint("RIGHT", row, "RIGHT", -12, 0)
		end

		y = y - 62
	end

	container:SetHeight(math.max(340, -y + 10))
end

function InfinitySettingsPanel:ApplySettings()
	for category, list in pairs(self.settings) do
		for _, setting in ipairs(list) do
			if InfinityStorageManager and InfinityStorageManager.SetSetting then
				InfinityStorageManager:SetSetting(category, setting.key, setting.value)
			end
		end
	end
	if InfinityMessaging and InfinityMessaging.Publish then
		InfinityMessaging:Publish("INFINITY_SETTINGS_APPLIED")
	end
	InfinityUIFramework:ShowNotification("|cff4ade80Infinity settings saved.|r", 2.5)
end

function InfinitySettingsPanel:Toggle()
	if not _G.InfinitySettingsFrame then
		_G.InfinitySettingsFrame = self:CreateSettingsFrame(UIParent)
		_G.InfinitySettingsFrame:Show()
		return
	end
	_G.InfinitySettingsFrame:SetShown(not _G.InfinitySettingsFrame:IsShown())
end

function InfinitySettingsPanel:ShowFeatureSettings(featureName)
	if InfinityStorageManager and InfinityStorageManager.GetFeatureSettings then
		return InfinityStorageManager:GetFeatureSettings(featureName)
	end
	return {}
end

_G.InfinitySettingsPanel = InfinitySettingsPanel
return InfinitySettingsPanel
