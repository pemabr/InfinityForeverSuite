-- InfinityCore UI Framework
-- Shared UI components and styling

InfinityUIFramework = {
	theme = "default",
	fonts = {},
	colors = {},
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
	end
	
	-- Notify subscribers
	InfinityMessaging:Publish(INFINITY_EVENTS.UI_THEME_CHANGED, themeName)
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
