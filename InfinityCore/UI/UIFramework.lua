-- InfinityCore UI Framework
-- Shared UI components and styling

InfinityUIFramework = {
	theme = "default",
	fonts = {},
	colors = {},
	windows = {},
}

-- Initialize framework
function InfinityUIFramework:Initialize()
	self.theme = InfinityStorageManager:GetProfile("theme", "default")
	self:LoadTheme(self.theme)
	InfinityUtils:Info("UI Framework initialized", "UIFramework")
end

-- Load theme
function InfinityUIFramework:LoadTheme(themeName)
	self.theme = themeName
	InfinityStorageManager:SetProfile("theme", themeName)
	
	-- Apply theme colors and fonts
	if themeName == "default" then
		self:ApplyDefaultTheme()
	elseif themeName == "dark" then
		self:ApplyDarkTheme()
	elseif themeName == "light" then
		self:ApplyLightTheme()
	end
	
	-- Notify subscribers
	if InfinityMessaging then
		InfinityMessaging:Publish(INFINITY_EVENTS.UI_THEME_CHANGED, themeName)
	end
end

-- Default theme
function InfinityUIFramework:ApplyDefaultTheme()
	self.colors = {
		window_bg = "Interface/Tooltips/UI-Tooltip-Background",
		header_bg = "Interface/Tooltips/UI-Tooltip-Border",
		primary = "|cff00ccff",
		secondary = "|cff33ff33",
		text = "|cffffffffff",
		text_muted = "|cffcccccc",
		success = "|cff33ff33",
		warning = "|cffff9900",
		error = "|cffff3333",
	}
end

-- Dark theme
function InfinityUIFramework:ApplyDarkTheme()
	self.colors = {
		window_bg = "Interface\\FrameGeneral\\UI-Background-Rock",
		header_bg = "Interface\\ChatFrame\\ChatFrameBackground",
		primary = "|cff00ccff",
		secondary = "|cff33ff33",
		text = "|cffffffff",
		text_muted = "|cff999999",
		success = "|cff33ff33",
		warning = "|cffff9900",
		error = "|cffff3333",
	}
end

-- Light theme
function InfinityUIFramework:ApplyLightTheme()
	self.colors = {
		window_bg = "Interface\\Buttons\\WHITE8X8",
		header_bg = "Interface\\Tooltips\\UI-Tooltip-Border",
		primary = "|cff0066ff",
		secondary = "|cff00aa00",
		text = "|cff000000",
		text_muted = "|cff666666",
		success = "|cff00aa00",
		warning = "|cffff6600",
		error = "|cffff0000",
	}
end

-- Create a standard frame
function InfinityUIFramework:CreateFrame(name, parent, width, height)
	local frame = CreateFrame("Frame", name, parent)
	frame:SetSize(width, height)
	
	-- Add background
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
	
	-- Add border
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	frame:SetBackdropBorderColor(0, 0.8, 1, 0.5)
	
	return frame
end

-- Create a button
function InfinityUIFramework:CreateButton(parent, text, width, height, onclick)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width, height)
	btn:SetText(text)
	
	if onclick then
		btn:SetScript("OnClick", onclick)
	end
	
	return btn
end

-- Create a text label
function InfinityUIFramework:CreateLabel(parent, text, r, g, b)
	r = r or 1
	g = g or 1
	b = b or 1
	
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetText(text)
	label:SetTextColor(r, g, b, 1)
	
	return label
end

-- Create a dropdown
function InfinityUIFramework:CreateDropdown(parent, options, selected, onchange)
	local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
	
	local function DropdownInit(self, level)
		for _, option in ipairs(options) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option
			info.value = option
			info.func = function(self)
				UIDropDownMenu_SetSelectedValue(dropdown, option)
				if onchange then
					onchange(option)
				end
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end
	
	UIDropDownMenu_Initialize(dropdown, DropdownInit)
	UIDropDownMenu_SetSelectedValue(dropdown, selected or options[1])
	
	return dropdown
end

-- Create an input field
function InfinityUIFramework:CreateInputBox(parent, width, height, onchange)
	local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	input:SetSize(width, height)
	input:SetAutoFocus(false)
	
	if onchange then
		input:SetScript("OnTextChanged", onchange)
	end
	
	return input
end

-- Create a scroll frame with content
function InfinityUIFramework:CreateScrollFrame(parent, name, width, height)
	local scroll = CreateFrame("ScrollFrame", name or "InfinityScroll", parent, "UIPanelScrollFrameTemplate")
	scroll:SetSize(width, height)
	
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(width, 1)
	scroll:SetScrollChild(content)
	
	scroll.content = content
	
	return scroll
end

-- Create a slider
function InfinityUIFramework:CreateSlider(parent, minVal, maxVal, stepVal, initialVal, onchange)
	local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(stepVal)
	slider:SetValue(initialVal or minVal)
	
	if onchange then
		slider:SetScript("OnValueChanged", function(self, value)
			onchange(value)
		end)
	end
	
	return slider
end

-- Create a checkbox
function InfinityUIFramework:CreateCheckbox(parent, text, checked, onchange)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox:SetChecked(checked or false)
	
	if text then
		local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
		label:SetText(text)
	end
	
	if onchange then
		checkbox:SetScript("OnClick", function(self)
			onchange(self:GetChecked())
		end)
	end
	
	return checkbox
end

-- Show a simple message box
function InfinityUIFramework:ShowMessageBox(title, text, buttons)
	local dialog = CreateFrame("Frame", "InfinityMessageBox", UIParent)
	dialog:SetSize(400, 200)
	dialog:SetPoint("CENTER")
	dialog:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	dialog:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
	dialog:SetBackdropBorderColor(0, 0.8, 1, 0.8)
	
	-- Title
	local titleText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("TOP", 0, -10)
	titleText:SetText(title)
	
	-- Message text
	local msgText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	msgText:SetPoint("TOPLEFT", 10, -40)
	msgText:SetPoint("BOTTOMRIGHT", -10, 50)
	msgText:SetWordWrap(true)
	msgText:SetText(text)
	
	-- Buttons
	if buttons then
		local btnCount = #buttons
		local btnWidth = 80
		local startX = -(btnCount * (btnWidth + 10)) / 2
		
		for i, btn in ipairs(buttons) do
			local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
			button:SetSize(btnWidth, 24)
			button:SetPoint("BOTTOM", startX + (i-1) * (btnWidth + 10), 10)
			button:SetText(btn.text)
			button:SetScript("OnClick", function()
				if btn.callback then
					btn.callback()
				end
				dialog:Hide()
			end)
		end
	end
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function() dialog:Hide() end)
	
	dialog:Show()
	return dialog
end

-- Create a tab control
function InfinityUIFramework:CreateTabControl(parent, tabs, onTabChanged)
	local tabControl = CreateFrame("Frame", nil, parent)
	tabControl.tabs = {}
	tabControl.tabButtons = {}
	
	local buttonWidth = 100
	for i, tab in ipairs(tabs) do
		local btn = self:CreateButton(tabControl, tab.name, buttonWidth, 24, function()
			tabControl:SelectTab(i)
			if onTabChanged then
				onTabChanged(tab)
			end
		end)
		btn:SetPoint("TOPLEFT", (i-1) * (buttonWidth + 2), 0)
		tabControl.tabButtons[i] = btn
		tabControl.tabs[i] = tab
	end
	
	-- Tab content area
	tabControl.contentFrame = CreateFrame("Frame", nil, tabControl)
	tabControl.contentFrame:SetPoint("TOPLEFT", 0, -30)
	tabControl.contentFrame:SetPoint("BOTTOMRIGHT", 0, 0)
	
	function tabControl:SelectTab(index)
		-- Hide all content
		for _, content in ipairs(self.tabs) do
			if content.frame then
				content.frame:Hide()
			end
		end
		
		-- Show selected
		if self.tabs[index] and self.tabs[index].frame then
			self.tabs[index].frame:Show()
		end
		
		-- Highlight button
		for i, btn in ipairs(self.tabButtons) do
			if i == index then
				btn:SetAlpha(1)
			else
				btn:SetAlpha(0.6)
			end
		end
	end
	
	-- Select first tab by default
	if #tabs > 0 then
		tabControl:SelectTab(1)
	end
	
	return tabControl
end

return InfinityUIFramework
	
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetText(text)
	label:SetTextColor(r, g, b)
	
	return label
end

-- Create a text input field
function InfinityUIFramework:CreateEditBox(parent, width, height)
	local editbox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	editbox:SetSize(width, height)
	editbox:SetAutoFocus(false)
	
	return editbox
end

-- Create a dropdown menu
function InfinityUIFramework:CreateDropdown(parent, options, defaultValue, onSelect)
	local dropdown = CreateFrame("Button", nil, parent, "UIDropDownMenuTemplate")
	
	local function InitializeDropdown()
		for _, option in ipairs(options) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option
			info.func = function()
				UIDropDownMenu_SetSelectedValue(dropdown, option)
				if onSelect then
					onSelect(option)
				end
			end
			UIDropDownMenu_AddButton(info)
		end
	end
	
	UIDropDownMenu_Initialize(dropdown, InitializeDropdown)
	UIDropDownMenu_SetSelectedValue(dropdown, defaultValue)
	
	return dropdown
end

-- Create a scrollable list
function InfinityUIFramework:CreateScrollList(parent, width, height, numRows)
	local container = self:CreateFrame(parent:GetName() .. "ScrollContainer", parent, width, height)
	
	local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
	scrollFrame:SetSize(width - 30, height)
	scrollFrame:SetPoint("LEFT", 5, 0)
	
	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(width - 30, numRows * 20)
	scrollFrame:SetScrollChild(content)
	
	return {
		container = container,
		scrollFrame = scrollFrame,
		content = content,
	}
end

-- Display a simple dialog
function InfinityUIFramework:ShowDialog(title, message, buttonText, callback)
	local dialog = self:CreateFrame("InfinityDialog", UIParent, 400, 200)
	dialog:SetPoint("CENTER")
	
	-- Title
	local titleLabel = self:CreateLabel(dialog, title)
	titleLabel:SetPoint("TOP", 0, -10)
	
	-- Message
	local msgLabel = self:CreateLabel(dialog, message)
	msgLabel:SetPoint("CENTER", 0, 20)
	msgLabel:SetWidth(380)
	msgLabel:SetWordWrap(true)
	
	-- Button
	local btn = self:CreateButton(dialog, buttonText or "OK", 100, 25, function()
		if callback then
			callback()
		end
		dialog:Hide()
	end)
	btn:SetPoint("BOTTOM", 0, 10)
	
	return dialog
end

-- Create a notification
function InfinityUIFramework:ShowNotification(message, duration)
	duration = duration or 3
	
	local notif = self:CreateFrame("InfinityNotification", UIParent, 300, 50)
	notif:SetPoint("TOPRIGHT", -20, -20)
	
	local msgLabel = self:CreateLabel(notif, message)
	msgLabel:SetPoint("CENTER")
	
	-- Auto-hide
	notif:SetScript("OnUpdate", function(self, elapsed)
		if not self.hideTime then
			self.hideTime = GetTime() + duration
		end
		if GetTime() >= self.hideTime then
			self:Hide()
		end
	end)
	
	return notif
end

return InfinityUIFramework
