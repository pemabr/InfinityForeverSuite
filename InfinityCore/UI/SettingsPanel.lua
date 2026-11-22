-- InfinityCore Settings Panel
-- Comprehensive settings and configuration UI

InfinitySettingsPanel = {
	settings = {},
	categoryFrames = {},
	currentCategory = nil,
}

function InfinitySettingsPanel:Initialize()
	-- Load default settings structure
	self:InitializeDefaultSettings()
	for category, settings in pairs(self.settings) do
		for key, setting in pairs(settings) do
			local saved = InfinityStorageManager and InfinityStorageManager:GetSetting(category, key, nil)
			if saved ~= nil then setting.value = saved end
		end
		if InfinityStorageManager and InfinityStorageManager.GetProfile then
			local saved = InfinityStorageManager:GetSetting("General", "Show Minimap Button", nil)
			if saved == nil then
				self.settings.General["Show Minimap Button"].value = InfinityStorageManager:GetProfile("minimap.enabled", true)
			elseif InfinityStorageManager.SetProfile then
				InfinityStorageManager:SetProfile("minimap.enabled", saved == true)
			end
		end
	end
	InfinityUtils:Info("Settings Panel initialized", "SettingsPanel")
end

function InfinitySettingsPanel:InitializeDefaultSettings()
	self.settings = {
		["General"] = {
			["Enable Tooltips"] = { type = "checkbox", value = true, description = "Show enhanced tooltips" },
			["Show Minimap Button"] = { type = "checkbox", value = true, description = "Show the Infinity launcher" },
			["Tooltip Delay"] = { type = "slider", value = 0.5, min = 0, max = 2, step = 0.1, description = "Delay before tooltip shows (seconds)" },
			["UI Scale"] = { type = "slider", value = 1.0, min = 0.5, max = 2.0, step = 0.1, description = "Overall UI scale" },
			["Show FPS"] = { type = "checkbox", value = false, description = "Display FPS counter" },
		},
		["Features"] = {
			["Enable Analytics"] = { type = "checkbox", value = true, description = "Track combat statistics" },
			["Enable Data Collector"] = { type = "checkbox", value = true, description = "Collect game data" },
			["Enable Notifications"] = { type = "checkbox", value = true, description = "Show notifications" },
			["Auto-Save Interval"] = { type = "slider", value = 300, min = 60, max = 3600, step = 60, description = "Auto-save interval (seconds)" },
		},
		["Appearance"] = {
			["Theme"] = { type = "dropdown", value = "default", options = {"default", "dark", "light"}, description = "UI Theme" },
			["Font Size"] = { type = "slider", value = 14, min = 10, max = 20, step = 1, description = "Default font size" },
			["Transparency"] = { type = "slider", value = 0.8, min = 0.3, max = 1.0, step = 0.05, description = "Window transparency" },
			["Compact Mode"] = { type = "checkbox", value = false, description = "Use compact UI layout" },
		},
		["Keybinds"] = {
			["Toggle Main Window"] = { type = "keybind", value = "CTRL-I", description = "Toggle main Infinity window" },
			["Toggle Analytics"] = { type = "keybind", value = "CTRL-A", description = "Toggle analytics window" },
			["Quick Search"] = { type = "keybind", value = "CTRL-F", description = "Quick search dialog" },
		},
	}
end

function InfinitySettingsPanel:GetSetting(category, key)
	if self.settings[category] and self.settings[category][key] then
		return self.settings[category][key].value
	end
	return nil
end

function InfinitySettingsPanel:SetSetting(category, key, value)
	if self.settings[category] and self.settings[category][key] then
		self.settings[category][key].value = value
		InfinityStorageManager:SetSetting(category, key, value)
		if category == "General" and key == "Show Minimap Button" and InfinityStorageManager.SetProfile then
			InfinityStorageManager:SetProfile("minimap.enabled", value == true)
			if _G.InfinityUIIntegration and InfinityUIIntegration.UpdateMinimapVisibility then
				InfinityUIIntegration:UpdateMinimapVisibility()
			end
		end
		InfinityMessaging:Publish("INFINITY_SETTING_CHANGED", category, key, value)
		return true
	end
	return false
end

function InfinitySettingsPanel:CreateSettingsFrame(parent)
	local mainFrame = CreateFrame("Frame", "InfinitySettingsFrame", parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mainFrame:SetSize(600, 500)
	mainFrame:SetPoint("CENTER")
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
	mainFrame:SetMovable(true)
	mainFrame:EnableMouse(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	
	-- Title
	local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -10)
	title:SetText("|cff00ccffInfinity Suite Settings|r")
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)
	
	-- Category list (left side)
	local categoryScroll = CreateFrame("ScrollFrame", "InfinitySettingsCategoryScroll", mainFrame, "UIPanelScrollFrameTemplate")
	categoryScroll:SetSize(120, 420)
	categoryScroll:SetPoint("TOPLEFT", 10, -35)
	
	local categoryList = CreateFrame("Frame", nil, categoryScroll, BackdropTemplateMixin and "BackdropTemplate" or nil)
	categoryList:SetSize(120, 1)
	categoryScroll:SetScrollChild(categoryList)
	
	mainFrame.categoryList = categoryList
	mainFrame.categoryScroll = categoryScroll
	
	-- Content area (right side)
	local contentFrame = CreateFrame("ScrollFrame", "InfinitySettingsContent", mainFrame, "UIPanelScrollFrameTemplate")
	contentFrame:SetSize(430, 420)
	contentFrame:SetPoint("TOPLEFT", 140, -35)
	
	local contentArea = CreateFrame("Frame", nil, contentFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	contentArea:SetSize(430, 1)
	contentFrame:SetScrollChild(contentArea)
	
	mainFrame.contentFrame = contentArea
	mainFrame.contentScroll = contentFrame
	
	-- Apply and Cancel buttons
	local applyBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
	applyBtn:SetSize(80, 22)
	applyBtn:SetPoint("BOTTOMRIGHT", -10, 10)
	applyBtn:SetText("Apply")
	applyBtn:SetScript("OnClick", function()
		InfinitySettingsPanel:ApplySettings()
		mainFrame:Hide()
	end)
	
	local cancelBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
	cancelBtn:SetSize(80, 22)
	cancelBtn:SetPoint("BOTTOMRIGHT", -100, 10)
	cancelBtn:SetText("Cancel")
	cancelBtn:SetScript("OnClick", function() mainFrame:Hide() end)
	
	-- Populate categories
	self:PopulateCategories(categoryList, mainFrame)
	
	return mainFrame
end

function InfinitySettingsPanel:PopulateCategories(categoryList, mainFrame)
	local y = 0
	for category, _ in pairs(self.settings) do
		local btn = CreateFrame("Button", nil, categoryList, "UIPanelButtonTemplate")
		btn:SetSize(110, 24)
		btn:SetPoint("TOPLEFT", 0, y)
		btn:SetText(category)
		btn:SetScript("OnClick", function()
			self:ShowCategorySettings(mainFrame, category)
		end)
		y = y - 28
	end
	categoryList:SetHeight(-y)
end

function InfinitySettingsPanel:ShowCategorySettings(mainFrame, category)
	-- Clear content
	InfinityUtils:ClearContainer(mainFrame.contentFrame)
	
	local y = 0
	local settings = self.settings[category]
	
	for key, setting in pairs(settings) do
		local label = mainFrame.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOPLEFT", 10, y)
		label:SetText(key)
		
		if setting.type == "checkbox" then
			local checkbox = CreateFrame("CheckButton", nil, mainFrame.contentFrame, "UICheckButtonTemplate")
			checkbox:SetPoint("TOPLEFT", 220, y + 2)
			checkbox:SetChecked(setting.value)
			checkbox:SetScript("OnClick", function(self)
				setting.value = self:GetChecked()
			end)
			y = y - 24
			
		elseif setting.type == "slider" then
			local slider = CreateFrame("Slider", nil, mainFrame.contentFrame, "OptionsSliderTemplate")
			slider:SetPoint("TOPLEFT", 220, y)
			slider:SetSize(100, 20)
			slider:SetMinMaxValues(setting.min, setting.max)
			slider:SetValueStep(setting.step)
			slider:SetValue(setting.value)
			slider:SetScript("OnValueChanged", function(self, value)
				setting.value = value
			end)
			y = y - 28
			
		elseif setting.type == "dropdown" then
			local dropdown = CreateFrame("Frame", nil, mainFrame.contentFrame, "UIDropDownMenuTemplate")
			dropdown:SetPoint("TOPLEFT", 220, y - 5)
			y = y - 24
		end
		
		-- Description
		local desc = mainFrame.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		desc:SetPoint("TOPLEFT", 10, y)
		desc:SetText("|cffcccccc" .. setting.description .. "|r")
		desc:SetWidth(300)
		desc:SetWordWrap(true)
		y = y - 20
	end
	
	mainFrame.contentFrame:SetHeight(-y)
	mainFrame.contentScroll:UpdateScrollChildRect()
end

function InfinitySettingsPanel:ApplySettings()
	for category, settings in pairs(self.settings) do
		for key, setting in pairs(settings) do
			InfinityStorageManager:SetSetting(category, key, setting.value)
		end
		if self.settings.General and self.settings.General["Show Minimap Button"] then
			self:SetSetting("General", "Show Minimap Button", self.settings.General["Show Minimap Button"].value == true)
		end
	end
	InfinityMessaging:Publish("INFINITY_SETTINGS_APPLIED")
	InfinityUtils:Info("Settings saved", "SettingsPanel")
end

function InfinitySettingsPanel:ShowFeatureSettings(featureName)
	local settings = InfinityStorageManager:GetFeatureSettings(featureName)
	InfinityUtils:Info("Showing settings for feature: " .. featureName, "SettingsPanel")
	return settings
end

function InfinitySettingsPanel:RegisterBlizzardSettings()
	if self.blizzardPanel then
		return self.blizzardCategory
	end
	
	local panel = CreateFrame("Frame", "InfinityBlizzardSettingsCanvas", UIParent)
	panel.name = "Infinity Suite"
	
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("|cff00ccffInfinity Suite|r Settings")
	
	local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	subtitle:SetText("Configure global options for the Infinity Forever Suite. Use /infinity for the main hub.")
	
	local y = -64
	local categoryOrder = { "General", "Features", "Appearance" }
	for _, catName in ipairs(categoryOrder) do
		local catSettings = self.settings[catName]
		if catSettings then
			local catHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			catHeader:SetPoint("TOPLEFT", 16, y)
			catHeader:SetText("|cff33ff33" .. catName .. "|r")
			y = y - 22
			
			for key, setting in pairs(catSettings) do
				local savedVal = InfinityStorageManager and InfinityStorageManager:GetSetting(catName, key, nil)
				if savedVal ~= nil then
					setting.value = savedVal
				end
				
				if setting.type == "checkbox" then
					local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
					cb:SetSize(24, 24)
					cb:SetPoint("TOPLEFT", 24, y + 4)
					cb:SetChecked(setting.value == true)
					if catName == "General" and key == "Show Minimap Button" then self.minimapCheckbox = cb end
					cb:SetScript("OnClick", function(selfBtn)
						InfinitySettingsPanel:SetSetting(catName, key, selfBtn:GetChecked() == true)
					end)
					local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
					lbl:SetPoint("LEFT", cb, "RIGHT", 6, 0)
					lbl:SetText(key .. "  |cff999999(" .. setting.description .. ")|r")
					y = y - 26
				elseif setting.type == "slider" then
					local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
					lbl:SetPoint("TOPLEFT", 28, y)
					lbl:SetText(string.format("%s: %s", key, tostring(setting.value)))
					
					local minusBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
					minusBtn:SetSize(22, 18)
					minusBtn:SetPoint("TOPLEFT", 240, y + 2)
					minusBtn:SetText("-")
					minusBtn:SetScript("OnClick", function()
						local nextVal = math.max(setting.min, (tonumber(setting.value) or setting.min) - (setting.step or 1))
						nextVal = math.floor(nextVal * 100 + 0.5) / 100
						InfinitySettingsPanel:SetSetting(catName, key, nextVal)
						lbl:SetText(string.format("%s: %s", key, tostring(nextVal)))
					end)
					
					local plusBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
					plusBtn:SetSize(22, 18)
					plusBtn:SetPoint("LEFT", minusBtn, "RIGHT", 6, 0)
					plusBtn:SetText("+")
					plusBtn:SetScript("OnClick", function()
						local nextVal = math.min(setting.max, (tonumber(setting.value) or setting.min) + (setting.step or 1))
						nextVal = math.floor(nextVal * 100 + 0.5) / 100
						InfinitySettingsPanel:SetSetting(catName, key, nextVal)
						lbl:SetText(string.format("%s: %s", key, tostring(nextVal)))
					end)
					y = y - 24
				elseif setting.type == "dropdown" and setting.options then
					local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
					lbl:SetPoint("TOPLEFT", 28, y)
					lbl:SetText(key .. ": " .. tostring(setting.value))
					
					local cycleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
					cycleBtn:SetSize(110, 20)
					cycleBtn:SetPoint("TOPLEFT", 240, y + 2)
					cycleBtn:SetText(tostring(setting.value))
					cycleBtn:SetScript("OnClick", function()
						local idx = 1
						for i, opt in ipairs(setting.options) do
							if opt == setting.value then
								idx = (i % #setting.options) + 1
								break
							end
						end
						local nextOpt = setting.options[idx]
						InfinitySettingsPanel:SetSetting(catName, key, nextOpt)
						if catName == "Appearance" and key == "Theme" and _G.InfinityUIFramework then
							_G.InfinityUIFramework:LoadTheme(nextOpt)
						end
						cycleBtn:SetText(tostring(nextOpt))
						lbl:SetText(key .. ": " .. tostring(nextOpt))
					end)
					y = y - 26
				end
			end
			y = y - 8
		end
	end
	
	local openHubBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	openHubBtn:SetSize(160, 24)
	openHubBtn:SetPoint("TOPLEFT", 24, y - 6)
	openHubBtn:SetText("Open Infinity Hub")
	openHubBtn:SetScript("OnClick", function()
		if _G.InfinityMainFrame and _G.InfinityMainFrame.Toggle then
			_G.InfinityMainFrame:Toggle()
		end
	end)
	
	self.blizzardPanel = panel
	panel:SetScript("OnShow", function()
		if self.minimapCheckbox then self.minimapCheckbox:SetChecked(self:GetSetting("General", "Show Minimap Button") == true) end
	end)
	
	if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory and _G.Settings.RegisterAddOnCategory then
		local category = _G.Settings.RegisterCanvasLayoutCategory(panel, "Infinity Suite")
		category.ID = "Infinity Suite"
		_G.Settings.RegisterAddOnCategory(category)
		self.blizzardCategory = category
	elseif _G.InterfaceOptions_AddCategory then
		_G.InterfaceOptions_AddCategory(panel)
		self.blizzardCategory = panel
	end
	
	return self.blizzardCategory
end

function InfinitySettingsPanel:OpenBlizzardSettings()
	if not self.blizzardCategory then
		self:RegisterBlizzardSettings()
	end
	if _G.Settings and _G.Settings.OpenToCategory and self.blizzardCategory then
		local catId = (type(self.blizzardCategory) == "table" and self.blizzardCategory.GetID and self.blizzardCategory:GetID()) or self.blizzardCategory.ID or "Infinity Suite"
		_G.Settings.OpenToCategory(catId)
	elseif _G.InterfaceOptionsFrame_OpenToCategory and self.blizzardPanel then
		_G.InterfaceOptionsFrame_OpenToCategory(self.blizzardPanel)
	end
end

return InfinitySettingsPanel
