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
	InfinityUtils:Info("Settings Panel initialized", "SettingsPanel")
end

function InfinitySettingsPanel:InitializeDefaultSettings()
	self.settings = {
		["General"] = {
			["Enable Tooltips"] = { type = "checkbox", value = true, description = "Show enhanced tooltips" },
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
		InfinityMessaging:Publish("INFINITY_SETTING_CHANGED", category, key, value)
		return true
	end
	return false
end

function InfinitySettingsPanel:CreateSettingsFrame(parent)
	local mainFrame = CreateFrame("Frame", "InfinitySettingsFrame", parent)
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
	
	local categoryList = CreateFrame("Frame", nil, categoryScroll)
	categoryList:SetSize(120, 1)
	categoryScroll:SetScrollChild(categoryList)
	
	mainFrame.categoryList = categoryList
	mainFrame.categoryScroll = categoryScroll
	
	-- Content area (right side)
	local contentFrame = CreateFrame("ScrollFrame", "InfinitySettingsContent", mainFrame, "UIPanelScrollFrameTemplate")
	contentFrame:SetSize(430, 420)
	contentFrame:SetPoint("TOPLEFT", 140, -35)
	
	local contentArea = CreateFrame("Frame", nil, contentFrame)
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
	for i = mainFrame.contentFrame:GetNumChildren(), 1, -1 do
		mainFrame.contentFrame:GetChild(i):Hide()
	end
	
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
	end
	InfinityMessaging:Publish("INFINITY_SETTINGS_APPLIED")
	InfinityUtils:Info("Settings saved", "SettingsPanel")
end

function InfinitySettingsPanel:ShowFeatureSettings(featureName)
	local settings = InfinityStorageManager:GetFeatureSettings(featureName)
	InfinityUtils:Info("Showing settings for feature: " .. featureName, "SettingsPanel")
	return settings
end

return InfinitySettingsPanel
