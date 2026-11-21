-- InfinityCore Addon Manager UI
-- Manage individual addon settings and configuration

InfinityAddonManager = {
	addons = {},
	currentAddon = nil,
}

function InfinityAddonManager:Initialize()
	InfinityUtils:Info("Addon Manager initialized", "AddonManager")
end

function InfinityAddonManager:RegisterAddon(name, version, config)
	self.addons[name] = {
		name = name,
		version = version,
		enabled = config.enabled ~= false,
		description = config.description or "No description",
		author = config.author or "Unknown",
		category = config.category or "Other",
		settings = config.settings or {},
	}
end

function InfinityAddonManager:GetAddonInfo(name)
	return self.addons[name]
end

function InfinityAddonManager:GetAllAddons()
	local addonList = {}
	for name, info in pairs(self.addons) do
		table.insert(addonList, info)
	end
	table.sort(addonList, function(a, b) return a.name < b.name end)
	return addonList
end

function InfinityAddonManager:IsAddonEnabled(name)
	if self.addons[name] then
		return self.addons[name].enabled
	end
	return false
end

function InfinityAddonManager:SetAddonEnabled(name, enabled)
	if self.addons[name] then
		self.addons[name].enabled = enabled
		InfinityStorageManager:SetAddonSetting(name, "enabled", enabled)
		InfinityMessaging:Publish("INFINITY_ADDON_STATE_CHANGED", name, enabled)
		return true
	end
	return false
end

function InfinityAddonManager:CreateManagerWindow()
	local mainFrame = CreateFrame("Frame", "InfinityAddonManager", UIParent)
	mainFrame:SetSize(700, 500)
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
	title:SetText("|cff00ccffInfinity Suite - Addon Manager|r")
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)
	
	-- Addon list (left side)
	local listScroll = CreateFrame("ScrollFrame", "InfinityAddonListScroll", mainFrame, "UIPanelScrollFrameTemplate")
	listScroll:SetSize(180, 420)
	listScroll:SetPoint("TOPLEFT", 10, -35)
	
	local addonList = CreateFrame("Frame", nil, listScroll)
	addonList:SetSize(180, 1)
	listScroll:SetScrollChild(addonList)
	
	mainFrame.addonList = addonList
	mainFrame.listScroll = listScroll
	
	-- Details area (right side)
	local detailsFrame = CreateFrame("Frame", nil, mainFrame)
	detailsFrame:SetSize(480, 420)
	detailsFrame:SetPoint("TOPLEFT", 200, -35)
	mainFrame.detailsFrame = detailsFrame
	
	-- Populate addon list
	self:RefreshAddonList(mainFrame)
	
	-- Search box
	local searchLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	searchLabel:SetPoint("TOPLEFT", 10, -460)
	searchLabel:SetText("Search:")
	
	local searchBox = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
	searchBox:SetSize(180, 20)
	searchBox:SetPoint("TOPLEFT", 60, -462)
	searchBox:SetScript("OnTextChanged", function(self)
		self:RefreshAddonList(mainFrame)
	end)
	mainFrame.searchBox = searchBox
	
	return mainFrame
end

function InfinityAddonManager:RefreshAddonList(mainFrame)
	-- Clear list
	for i = mainFrame.addonList:GetNumChildren(), 1, -1 do
		mainFrame.addonList:GetChild(i):Hide()
	end
	
	local searchText = (mainFrame.searchBox and mainFrame.searchBox:GetText() or ""):lower()
	local y = 0
	local addons = self:GetAllAddons()
	
	for _, addonInfo in ipairs(addons) do
		if searchText == "" or addonInfo.name:lower():find(searchText, 1, true) or 
		   addonInfo.description:lower():find(searchText, 1, true) then
			
			local btn = CreateFrame("Button", nil, mainFrame.addonList)
			btn:SetSize(170, 30)
			btn:SetPoint("TOPLEFT", 0, y)
			btn:SetBackdrop({
				bgFile = "Interface/Tooltips/UI-Tooltip-Background",
				tile = true,
				tileSize = 16,
			})
			btn:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
			
			local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			text:SetPoint("LEFT", 5, 0)
			text:SetText(addonInfo.name)
			
			local status = addonInfo.enabled and "|cff00ff00✓|r" or "|cffff0000✗|r"
			local statusText = btn:CreateFontString(nil, "OVERLAY", "GameFontSmall")
			statusText:SetPoint("RIGHT", -5, 0)
			statusText:SetText(status)
			
			btn:SetScript("OnClick", function()
				self:ShowAddonDetails(mainFrame, addonInfo)
			end)
			
			y = y - 32
		end
	end
	
	mainFrame.addonList:SetHeight(-y)
	mainFrame.listScroll:UpdateScrollChildRect()
end

function InfinityAddonManager:ShowAddonDetails(mainFrame, addonInfo)
	-- Clear details
	for i = mainFrame.detailsFrame:GetNumChildren(), 1, -1 do
		mainFrame.detailsFrame:GetChild(i):Hide()
	end
	
	local y = 0
	
	-- Title
	local nameText = mainFrame.detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	nameText:SetPoint("TOPLEFT", 10, y)
	nameText:SetText(addonInfo.name)
	y = y - 30
	
	-- Version
	local versionText = mainFrame.detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
	versionText:SetPoint("TOPLEFT", 10, y)
	versionText:SetText("Version: " .. addonInfo.version)
	y = y - 20
	
	-- Author
	local authorText = mainFrame.detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
	authorText:SetPoint("TOPLEFT", 10, y)
	authorText:SetText("Author: " .. addonInfo.author)
	y = y - 20
	
	-- Category
	local categoryText = mainFrame.detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
	categoryText:SetPoint("TOPLEFT", 10, y)
	categoryText:SetText("Category: " .. addonInfo.category)
	y = y - 25
	
	-- Description
	local descLabel = mainFrame.detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	descLabel:SetPoint("TOPLEFT", 10, y)
	descLabel:SetText("Description:")
	y = y - 20
	
	local descText = mainFrame.detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	descText:SetPoint("TOPLEFT", 10, y)
	descText:SetPoint("RIGHT", -10, 0)
	descText:SetWordWrap(true)
	descText:SetText(addonInfo.description)
	descText:SetHeight(60)
	y = y - 80
	
	-- Enable/Disable button
	local toggleBtn = CreateFrame("Button", nil, mainFrame.detailsFrame, "UIPanelButtonTemplate")
	toggleBtn:SetSize(100, 25)
	toggleBtn:SetPoint("TOPLEFT", 10, y)
	toggleBtn:SetText(addonInfo.enabled and "Disable" or "Enable")
	toggleBtn:SetScript("OnClick", function()
		self:SetAddonEnabled(addonInfo.name, not addonInfo.enabled)
		self:RefreshAddonList(mainFrame)
	end)
	
	-- Status
	local statusLabel = mainFrame.detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	statusLabel:SetPoint("TOPLEFT", 120, y + 2)
	local statusColor = addonInfo.enabled and "|cff00ff00" or "|cffff0000"
	local statusStr = addonInfo.enabled and "ENABLED" or "DISABLED"
	statusLabel:SetText("Status: " .. statusColor .. statusStr .. "|r")
end

function InfinityAddonManager:Toggle()
	if _G.InfinityAddonManager and _G.InfinityAddonManager:IsVisible() then
		_G.InfinityAddonManager:Hide()
	else
		if not _G.InfinityAddonManager then
			_G.InfinityAddonManager = self:CreateManagerWindow()
		else
			_G.InfinityAddonManager:Show()
		end
	end
end

return InfinityAddonManager

