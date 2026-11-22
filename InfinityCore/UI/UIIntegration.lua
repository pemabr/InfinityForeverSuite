-- InfinityCore UI Integration
-- Integrates all UI components without requiring chat commands

InfinityUIIntegration = {}

local features = {
	{ "InfinityAttendance", "Attendance" }, { "InfinityCalendar", "Calendar" },
	{ "InfinityConsumables", "Consumables" }, { "InfinityDataCollector", "Data Collector" },
	{ "InfinityDetails", "Combat Details" }, { "InfinityDKP", "DKP" },
	{ "InfinityEncounter", "Encounters" }, { "InfinityGather", "Gathering" },
	{ "InfinityGatherPath", "Gather Routes" }, { "InfinityGear", "Gear" },
	{ "InfinityGearMgr", "Gear Manager" }, { "InfinityGuide", "Guides" },
	{ "InfinityGuild", "Guild" }, { "InfinityHealer", "Healing" },
	{ "InfinityInventory", "Inventory" }, { "InfinityLoot", "Loot" },
	{ "InfinityLootHistory", "Loot History" }, { "InfinityNavigation", "Navigation" },
	{ "InfinityPerformanceAnalytics", "Analytics" }, { "InfinityProfiler", "Profiler" },
	{ "InfinityQoL", "Quality of Life" }, { "InfinityQuestie", "Quests" },
	{ "InfinityRaid", "Raid" }, { "InfinityRosterMgr", "Guild Roster" },
	{ "InfinityWorldBoss", "World Bosses" },
}

local groups = {
	map = { "InfinityQuestie", "InfinityGuide", "InfinityNavigation", "InfinityGather", "InfinityGatherPath", "InfinityWorldBoss" },
	guild = { "InfinityGuild", "InfinityRosterMgr", "InfinityAttendance", "InfinityDKP", "InfinityLoot", "InfinityDataCollector" },
	skills = { "InfinityInventory", "InfinityConsumables", "InfinityGear", "InfinityGearMgr", "InfinityDataCollector" },
	character = { "InfinityInventory", "InfinityGear", "InfinityGearMgr", "InfinityConsumables" },
	calendar = { "InfinityCalendar", "InfinityAttendance", "InfinityRaid" },
	bank = { "InfinityInventory", "InfinityGuild", "InfinityDKP" },
	guildbank = { "InfinityGuild", "InfinityDKP", "InfinityLoot" },
	auction = { "InfinityInventory", "InfinityLoot", "InfinityDKP" },
}

local shortcuts = {
	map = {
		{ "InfinityQuestie", "Quest Waypoint", "InfinityQuestieUI", "ShowSelectedWaypoint" },
		{ "InfinityQuestie", "Quest Locations", "InfinityQuestieUI", "ShowSelectedLocations" },
		{ "InfinityQuestie", "Search Quests", "InfinityQuestieUI", "ShowSearch" },
		{ "InfinityGuide", "My Guides", "InfinityGuideUI", "ShowGuides" },
	},
	skills = {
		{ "InfinityInventory", "Recipe Reagents", "InfinityInventoryUI", "ShowRecipe" },
		{ "InfinityDataCollector", "Guild Crafters", "InfinityGuildRecipes", "OpenForProfession" },
	},
	bank = {
		{ "InfinityInventory", "My Bank", "InfinityInventoryUI", "OpenCurrentBank" },
	},
	guildbank = {
		{ "InfinityDKP", "Guild Bank Log", "InfinityDKPUI", "ShowGuildBankLog" },
	},
	auction = {
		{ "InfinityInventory", "Auction Prices", "InfinityAuctionPrices", "Toggle" },
		{ "InfinityInventory", "Shopping Lists", "InfinityShoppingLists", "Toggle" },
	},
}

local hosts = {
	{ "WorldMapFrame", "map" }, { "CommunitiesFrame", "guild" }, { "GuildFrame", "guild" },
	{ "PlayerSpellsFrame", "skills" }, { "SpellBookFrame", "skills" },
	{ "ProfessionsFrame", "skills" }, { "TradeSkillFrame", "skills" },
	{ "CharacterFrame", "character" }, { "CalendarFrame", "calendar" },
	{ "BankFrame", "bank" }, { "GuildBankFrame", "guildbank" }, { "AuctionHouseFrame", "auction" },
}

local function Public(value)
	if _G.issecretvalue and issecretvalue(value) then return nil end
	return value
end

local function InCombat()
	if not _G.InCombatLockdown then return false end
	local value = InCombatLockdown()
	return (_G.issecretvalue and issecretvalue(value)) or value == true
end

local function Tooltip(button, title, description)
	if not _G.GameTooltip then return end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetText(title)
	if description and GameTooltip.AddLine then GameTooltip:AddLine(description, 1, 1, 1, true) end
	GameTooltip:Show()
end

local function Coordinate(value)
	value = Public(value)
	if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
end

function InfinityUIIntegration:PositionMenu(frame, anchor)
	frame:ClearAllPoints()
	if not anchor or not anchor.GetCenter or not anchor.GetEffectiveScale
		or not UIParent.GetCenter or not UIParent.GetEffectiveScale then
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		return
	end
	local x, y = anchor:GetCenter()
	local cx, cy = UIParent:GetCenter()
	x, y, cx, cy = Coordinate(x), Coordinate(y), Coordinate(cx), Coordinate(cy)
	local scale, parentScale = Coordinate(anchor:GetEffectiveScale()), Coordinate(UIParent:GetEffectiveScale())
	if not x or not y or not cx or not cy or not scale or scale <= 0 or not parentScale or parentScale <= 0 then
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		return
	end
	local ratio = scale / parentScale
	local width = anchor.GetWidth and Coordinate(anchor:GetWidth()) or 0
	local menuWidth = Coordinate(frame:GetWidth()) or 474
	local menuHeight = Coordinate(frame:GetHeight()) or 80
	local right = UIParent.GetRight and Coordinate(UIParent:GetRight())
	local offset = width * ratio / 2 + menuWidth / 2 + 6
	x, y = x * ratio, y * ratio
	if right and x + offset + menuWidth / 2 > right then offset = -offset end
	frame:SetPoint("CENTER", UIParent, "CENTER", x + offset - cx, y - menuHeight / 2 + 12 - cy)
end

function InfinityUIIntegration:ShowMenu(anchor, group)
	if self.menu and self.menu:IsShown() and self.menuAnchor == anchor and self.menuGroup == group then
		self.menu:Hide()
		return
	end
	if not self.menu then
		local frame = InfinityUIFramework:CreateFrame("InfinityLauncherMenu", UIParent, 474, 100)
		frame:SetFrameStrata("DIALOG")
		frame:SetClampedToScreen(true)
		frame.title = InfinityUIFramework:CreateLabel(frame, "Infinity Suite")
		frame.title:SetPoint("TOPLEFT", 12, -12)
		frame.empty = InfinityUIFramework:CreateLabel(frame, "No related modules loaded.")
		frame.empty:SetPoint("TOPLEFT", 12, -40)
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -3, -3)
		close:SetScript("OnClick", function() frame:Hide() end)
		frame.buttons = {}
		frame:Hide()
		self.menu = frame
	end
	local frame, wanted, entries = self.menu, {}, {}
	if group and groups[group] then
		for _, name in ipairs(groups[group]) do wanted[name] = true end
	end
	for _, entry in ipairs(shortcuts[group] or {}) do
		local target = _G[entry[3]]
		if InfinityMainFrame:IsFeatureAvailable(entry[1]) and type(target) == "table" and type(target[entry[4]]) == "function" then
			entries[#entries + 1] = entry
		end
	end
	for _, entry in ipairs(features) do
		if (not group or wanted[entry[1]]) and InfinityMainFrame:IsFeatureAvailable(entry[1]) then
			entries[#entries + 1] = entry
		end
	end
	if not group then table.insert(entries, 1, { nil, "Suite Settings" }) end
	for i, entry in ipairs(entries) do
		local button = frame.buttons[i]
		if not button then
			button = InfinityUIFramework:CreateButton(frame, "", 145, 24)
			button:SetPoint("TOPLEFT", 12 + ((i - 1) % 3) * 152, -36 - math.floor((i - 1) / 3) * 28)
			button:SetScript("OnClick", function(clicked)
				local name = clicked.featureName
				frame:Hide()
				if clicked.targetName then
					local target = _G[clicked.targetName]
					if not InfinityMainFrame:IsFeatureAvailable(name) or type(target) ~= "table"
						or type(target[clicked.targetMethod]) ~= "function" then
						InfinityUtils:Warning("Feature unavailable: " .. clicked.featureLabel, "Core")
					else
						local ok, err = pcall(target[clicked.targetMethod], target)
						if not ok then
							if _G.issecretvalue and issecretvalue(err) then err = nil end
							InfinityUtils:Error("Could not open " .. clicked.featureLabel .. ": " .. tostring(err or "protected error"), "Core")
						end
					end
				elseif name then InfinityMainFrame:OpenFeature(name) else InfinityMainFrame:Toggle() end
			end)
			button:SetScript("OnEnter", function(clicked)
				Tooltip(clicked, clicked.featureLabel, clicked.featureName or "Open the suite window.")
			end)
			button:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
			frame.buttons[i] = button
		end
		button.featureName, button.featureLabel, button.targetName, button.targetMethod = entry[1], entry[2], entry[3], entry[4]
		button:SetText(entry[2])
		button:Show()
	end
	for i = #entries + 1, #frame.buttons do frame.buttons[i]:Hide() end
	if #entries == 0 then frame.empty:Show() else frame.empty:Hide() end
	frame:SetHeight(math.max(80, 46 + math.ceil(#entries / 3) * 28))
	self:PositionMenu(frame, anchor)
	self.menuAnchor, self.menuGroup = anchor, group
	frame:Show()
end

function InfinityUIIntegration:UpdateMinimapVisibility()
	if not self.minimapButton then return end
	if InCombat() then self.visibilityPending = true; return end
	self.visibilityPending = false
	local enabled = Public(InfinityStorageManager:GetProfile("minimap.enabled", true))
	if enabled == false then
		self.minimapButton:Hide()
		if self.menu and self.menuAnchor == self.minimapButton then self.menu:Hide() end
	else
		self.minimapButton:Show()
	end
end

function InfinityUIIntegration:PositionMinimap()
	local button = self.minimapButton
	if not button or InCombat() then return end
	local angle = Public(InfinityStorageManager:GetProfile("minimap.angle", 45))
	local width = Minimap.GetWidth and Public(Minimap:GetWidth())
	if type(angle) ~= "number" or angle ~= angle or math.abs(angle) > 360 then angle = 45 end
	if type(width) ~= "number" or width ~= width or width < 30 or width > 1000 then width = 140 end
	local radians, radius = math.rad(angle), width / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function InfinityUIIntegration:PositionHostButton(button, panel)
	if InCombat() then return end
	local right = panel.GetRight and Public(panel:GetRight())
	local screenRight = UIParent.GetRight and Public(UIParent:GetRight())
	button:ClearAllPoints()
	if type(right) == "number" and type(screenRight) == "number" and right + 80 < screenRight then
		button:SetPoint("TOPLEFT", panel, "TOPRIGHT", 3, -45)
	else
		button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -45)
	end
end

function InfinityUIIntegration:AttachNavigation()
	if InCombat() then self.navigationPending = true; return end
	self.navigationPending = false
	if not self.minimapButton and _G.Minimap then
		local button = CreateFrame("Button", "InfinityMinimapButton", Minimap)
		button:SetSize(30, 30)
		button:SetFrameStrata("MEDIUM")
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetSize(20, 20)
		icon:SetPoint("CENTER")
		icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
		local border = button:CreateTexture(nil, "OVERLAY")
		border:SetSize(53, 53)
		border:SetPoint("TOPLEFT")
		border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:RegisterForDrag("LeftButton")
		button:SetScript("OnClick", function(_, mouseButton)
			if mouseButton == "RightButton" then InfinityMainFrame:Toggle()
			else self:ShowMenu(button) end
		end)
		button:SetScript("OnEnter", function() Tooltip(button, "Infinity Suite", "Left: menu | Right: suite | Drag: move") end)
		button:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
		button:SetScript("OnDragStart", function()
			if InCombat() or not _G.GetCursorPosition or not Minimap.GetCenter or not Minimap.GetEffectiveScale then
				InfinityUtils:Warning("Minimap button cannot be moved right now.", "Core")
				return
			end
			button:SetScript("OnUpdate", function()
				if InCombat() then button:SetScript("OnUpdate", nil); return end
				local x, y = GetCursorPosition()
				local cx, cy = Minimap:GetCenter()
				local scale = Minimap:GetEffectiveScale()
				x, y, cx, cy, scale = Public(x), Public(y), Public(cx), Public(cy), Public(scale)
				if type(x) ~= "number" or type(y) ~= "number" or type(cx) ~= "number"
					or type(cy) ~= "number" or type(scale) ~= "number" or scale <= 0 or scale >= math.huge
					or math.abs(x) >= math.huge or math.abs(y) >= math.huge
					or math.abs(cx) >= math.huge or math.abs(cy) >= math.huge then return end
				local dx, dy = x / scale - cx, y / scale - cy
				local angle
				if math.atan2 then angle = math.atan2(dy, dx)
				elseif dx > 0 then angle = math.atan(dy / dx)
				elseif dx < 0 then angle = math.atan(dy / dx) + (dy >= 0 and math.pi or -math.pi)
				elseif dy ~= 0 then angle = dy > 0 and math.pi / 2 or -math.pi / 2
				else return end
				angle = math.deg(angle)
				if angle == angle then
					InfinityStorageManager:SetProfile("minimap.angle", angle)
					self:PositionMinimap()
				end
			end)
		end)
		button:SetScript("OnDragStop", function() button:SetScript("OnUpdate", nil) end)
		self.minimapButton = button
		self:PositionMinimap()
		self:UpdateMinimapVisibility()
	end
	self.hostButtons = self.hostButtons or {}
	for _, host in ipairs(hosts) do
		local panel, group = _G[host[1]], host[2]
		if panel and not self.hostButtons[panel] then
			local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
			button:SetSize(75, 22)
			local level = panel.GetFrameLevel and Public(panel:GetFrameLevel())
			if type(level) == "number" and level >= 0 and level < 1000 then button:SetFrameLevel(level + 10) end
			self:PositionHostButton(button, panel)
			button:SetText("Infinity")
			button:SetScript("OnClick", function() self:ShowMenu(button, group) end)
			button:SetScript("OnEnter", function() Tooltip(button, "Infinity Suite", "Open related tools.") end)
			button:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
			button:SetScript("OnShow", function() self:PositionHostButton(button, panel) end)
			button:SetScript("OnHide", function()
				if self.menu and self.menuAnchor == button then self.menu:Hide() end
			end)
			self.hostButtons[panel] = button
		end
	end
end

function InfinityUIIntegration:InitializeNavigation()
	if self.navigationEvents then return end
	local events = CreateFrame("Frame")
	events:RegisterEvent("ADDON_LOADED")
	events:RegisterEvent("PLAYER_LOGIN")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("BANKFRAME_OPENED")
	events:RegisterEvent("GUILDBANKFRAME_OPENED")
	events:RegisterEvent("AUCTION_HOUSE_SHOW")
	events:SetScript("OnEvent", function(_, event)
		if event ~= "PLAYER_REGEN_ENABLED" or self.navigationPending then self:AttachNavigation() end
		if event == "PLAYER_REGEN_ENABLED" and self.visibilityPending then self:UpdateMinimapVisibility() end
	end)
	self.navigationEvents = events
	self:AttachNavigation()
end

function InfinityUIIntegration:Initialize()
	-- Make sure UI Framework is initialized
	if _G.InfinityUIFramework and _G.InfinityUIFramework.Initialize then
		_G.InfinityUIFramework:Initialize()
	end
	
	-- Initialize Settings Panel
	if _G.InfinitySettingsPanel and _G.InfinitySettingsPanel.Initialize then
		_G.InfinitySettingsPanel:Initialize()
	end
	
	-- Initialize Addon Manager
	if _G.InfinityAddonManager and _G.InfinityAddonManager.Initialize then
		_G.InfinityAddonManager:Initialize()
	end
	
	-- Set up event subscriptions
	if _G.InfinityMessaging then
		_G.InfinityMessaging:Subscribe("INFINITY_SETTING_CHANGED", function(category, key, value)
			InfinityUtils:Info("Setting changed: " .. category .. "." .. key, "UI")
		end)
	end
	self:InitializeNavigation()
	
	InfinityUtils:Info("UI Integration initialized", "UIIntegration")
end

return InfinityUIIntegration
