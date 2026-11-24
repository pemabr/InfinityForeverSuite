-- PluribusNavigation UI & Graphical Compass Arrow HUD
-- Rotating Compass Arrow HUD, World Map side tab integration, categorized Azeroth destinations,
-- live Guildmate GPS waypoints, and /way coordinate support.

local PluribusNavigationUI = {
	mainWindow = nil,
	hudFrame = nil,
	activeWaypoint = nil,
	selectedCat = "Raids",
	worldMapAttached = false,
}
_G.PluribusNavigationUI = PluribusNavigationUI

PluribusNavigationUI.DESTINATIONS = {
	Raids = {
		{ name = "Naxxramas", zone = "Eastern Plaguelands", x = 39.2, y = 26.4, icon = "Interface\\Icons\\Spell_Shadow_RaiseDead" },
		{ name = "Blackrock Mountain (MC / BWL)", zone = "Burning Steppes", x = 29.4, y = 38.2, icon = "Interface\\Icons\\Spell_Fire_LavaSpawn" },
		{ name = "Gates of Ahn'Qiraj (AQ20 / AQ40)", zone = "Silithus", x = 28.6, y = 92.4, icon = "Interface\\Icons\\INV_Misc_QirajiCrystal_05" },
		{ name = "Onyxia's Lair", zone = "Dustwallow Marsh", x = 52.2, y = 76.1, icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
		{ name = "Zul'Gurub", zone = "Stranglethorn Vale", x = 53.8, y = 17.6, icon = "Interface\\Icons\\INV_Bijou_Green" },
	},
	Dungeons = {
		{ name = "Stratholme (Main / Service)", zone = "Eastern Plaguelands", x = 31.2, y = 14.0, icon = "Interface\\Icons\\INV_Misc_Bone_Skull_01" },
		{ name = "Scholomance", zone = "Western Plaguelands", x = 69.4, y = 73.1, icon = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
		{ name = "Dire Maul", zone = "Feralas", x = 59.1, y = 44.3, icon = "Interface\\Icons\\INV_Misc_Key_14" },
		{ name = "Blackrock Depths / UBRS", zone = "Searing Gorge", x = 35.1, y = 84.9, icon = "Interface\\Icons\\INV_Hammer_04" },
		{ name = "Scarlet Monastery", zone = "Tirisfal Glades", x = 85.2, y = 32.5, icon = "Interface\\Icons\\INV_Shield_10" },
	},
	Cities = {
		{ name = "Stormwind City", zone = "Elwynn Forest", x = 32.0, y = 49.5, icon = "Interface\\Icons\\INV_BannerPVP_02" },
		{ name = "Ironforge", zone = "Dun Morogh", x = 53.3, y = 34.8, icon = "Interface\\Icons\\Trade_BlackSmithing" },
		{ name = "Orgrimmar", zone = "Durotar", x = 45.8, y = 12.6, icon = "Interface\\Icons\\INV_BannerPVP_01" },
		{ name = "Undercity", zone = "Tirisfal Glades", x = 61.8, y = 65.2, icon = "Interface\\Icons\\Spell_Shadow_Charm" },
		{ name = "Booty Bay", zone = "Stranglethorn Vale", x = 27.4, y = 77.2, icon = "Interface\\Icons\\INV_Misc_Coin_01" },
		{ name = "Gadgetzan", zone = "Tanaris", x = 52.3, y = 27.6, icon = "Interface\\Icons\\Trade_Engineering" },
	},
	Bosses = {
		{ name = "Azuregos Spawn", zone = "Azshara", x = 56.1, y = 80.5, icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
		{ name = "Lord Kazzak", zone = "Blasted Lands", x = 32.4, y = 48.2, icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
		{ name = "Emeriss / Dragons (Duskwood)", zone = "Duskwood", x = 46.8, y = 37.5, icon = "Interface\\Icons\\Spell_Nature_AbolishMagic" },
		{ name = "Dragons of Nightmare (Ashenvale)", zone = "Ashenvale", x = 93.7, y = 35.6, icon = "Interface\\Icons\\Spell_Nature_AbolishMagic" },
	},
}

-- Create / show the sleek graphical floating Compass Arrow HUD
function PluribusNavigationUI:EnsureCompassHUD()
	if self.hudFrame then return self.hudFrame end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end

	local hud = CreateFrame("Frame", "PluribusCompassHUD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	hud:SetSize(224, 62)
	hud:SetPoint("TOP", UIParent, "TOP", 0, -110)
	hud:SetFrameStrata("HIGH")
	hud:SetMovable(true)
	hud:EnableMouse(true)
	hud:SetClampedToScreen(true)
	hud:RegisterForDrag("LeftButton")
	hud:SetScript("OnDragStart", function(f) f:StartMoving() end)
	hud:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
	UI:ApplyBackdrop(hud, 0.06, 0.09, 0.15, 0.94, 0.22, 0.74, 0.97, 0.92)

	-- Circular compass housing on the left
	local dial = CreateFrame("Frame", nil, hud, BackdropTemplateMixin and "BackdropTemplate" or nil)
	dial:SetSize(46, 46)
	dial:SetPoint("LEFT", hud, "LEFT", 8, 0)
	UI:ApplyBackdrop(dial, 0.04, 0.06, 0.11, 0.96, 0.92, 0.72, 0.22, 0.90)

	local arrow = dial:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(34, 34)
	arrow:SetPoint("CENTER", dial, "CENTER", 0, 0)
	arrow:SetTexture("Interface\\AddOns\\PluribusCore\\Media\\CompassArrow")
	hud.arrow = arrow

	local title = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", dial, "TOPRIGHT", 8, -2)
	title:SetWidth(134)
	title:SetJustifyH("LEFT")
	title:SetText("|cff38bdf8Compass Ready|r")
	hud.title = title

	local meta = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
	meta:SetWidth(134)
	meta:SetJustifyH("LEFT")
	meta:SetTextColor(0.80, 0.88, 0.96, 1)
	meta:SetText("Pick a waypoint")
	hud.meta = meta

	local dist = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dist:SetPoint("BOTTOMLEFT", dial, "BOTTOMRIGHT", 8, 2)
	dist:SetTextColor(0.29, 0.87, 0.50, 1)
	dist:SetText("")
	hud.dist = dist

	local closeBtn = UI:CreateButton(hud, "X", 20, 18, function()
		PluribusNavigationUI:ClearWaypoint()
		hud:Hide()
	end)
	closeBtn:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -5, -5)

	-- Live compass bearing & distance update loop
	local accum = 0
	hud:SetScript("OnUpdate", function(selfHud, elapsed)
		accum = accum + (elapsed or 0)
		if accum < 0.08 then return end
		accum = 0
		local wp = PluribusNavigationUI.activeWaypoint
		if not wp then return end

		local px, py = 0, 0
		if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
			local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
			px, py = (ux or 0) * 100, (uy or 0) * 100
		end
		local dx = (wp.x or 50) - px
		local dy = (wp.y or 50) - py
		local distUnits = math.sqrt(dx * dx + dy * dy)
		local yards = math.floor(distUnits * 28)

		-- Facing angle (radians, 0 = North, counter-clockwise in WoW API)
		local facing = (GetPlayerFacing and GetPlayerFacing()) or 0
		-- Map coords: +x is East, +y is South -> world North is -dy
		local targetAngle = math.atan2(-dx, -dy)
		local relAngle = targetAngle - facing
		if selfHud.arrow.SetRotation then
			pcall(selfHud.arrow.SetRotation, selfHud.arrow, relAngle)
		end

		if yards < 15 then
			selfHud.dist:SetText("|cff4ade80Arrived! (<15 yds)|r")
		else
			selfHud.dist:SetText(string.format("|cff4ade80~%d yds|r  |cff94a3b8(%.1f, %.1f)|r", yards, wp.x, wp.y))
		end
	end)

	hud:Hide()
	self.hudFrame = hud
	return hud
end

function PluribusNavigationUI:ToggleCompassHUD()
	local hud = self:EnsureCompassHUD()
	if not hud then return end
	if hud:IsShown() then
		hud:Hide()
	else
		hud:Show()
		if self.activeWaypoint then
			hud.title:SetText("|cff38bdf8" .. tostring(self.activeWaypoint.name):sub(1, 22) .. "|r")
			hud.meta:SetText(tostring(self.activeWaypoint.zone or "Azeroth"))
		else
			hud.title:SetText("|cff38bdf8Pluribus Compass|r")
			hud.meta:SetText("Use /nav or /way X Y")
			hud.dist:SetText("|cfffbbf24Drag to reposition|r")
		end
	end
end

function PluribusNavigationUI:ClearWaypoint()
	self.activeWaypoint = nil
	if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
	if self.hudFrame then self.hudFrame:Hide() end
	if self.mainWindow and self.mainWindow:IsShown() then self:Refresh() end
end

function PluribusNavigationUI:SetWaypoint(name, zone, x, y, mapID)
	local nx = math.max(0, math.min(100, tonumber(x) or 50))
	local ny = math.max(0, math.min(100, tonumber(y) or 50))
	self.activeWaypoint = {
		name = tostring(name or "Waypoint"),
		zone = tostring(zone or (GetRealZoneText and GetRealZoneText()) or "Azeroth"),
		x = nx,
		y = ny,
		mapID = tonumber(mapID) or 0,
	}

	-- Sync with native WoW user waypoint if supported on this client
	if mapID and mapID > 0 and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
		pcall(function()
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, nx / 100, ny / 100))
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
				C_SuperTrack.SetSuperTrackedUserWaypoint(true)
			end
		end)
	end
	if _G.PluribusNavigator and _G.PluribusNavigator.SetWaypoint then
		pcall(function() _G.PluribusNavigator:SetWaypoint(nx, ny, self.activeWaypoint.name) end)
	end

	-- Automatically pop up the graphical Compass Arrow HUD!
	local hud = self:EnsureCompassHUD()
	if hud then
		hud.title:SetText("|cff38bdf8" .. self.activeWaypoint.name:sub(1, 22) .. "|r")
		hud.meta:SetText(self.activeWaypoint.zone)
		hud:Show()
	end

	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification(string.format("|cff4ade80Compass locked:|r %s (%.1f, %.1f)", self.activeWaypoint.name, nx, ny), 3)
	end
	if self.mainWindow and self.mainWindow:IsShown() then self:Refresh() end
end

-- Attach an unmistakable Navigation side tab directly onto WoW's World Map (M)
function PluribusNavigationUI:AttachToWorldMap()
	local host = _G.WorldMapFrame
	if not host or self.worldMapAttached or not _G.PluribusUIFramework then return end
	if _G.PluribusHive and _G.PluribusHive:GetConfig().attachSideTabs == false then return end
	self.worldMapAttached = true

	local UI = _G.PluribusUIFramework
	local tab = UI:CreateSideTab(host, 1, {
		icon = "Interface\\Icons\\INV_Misc_Map_01",
		title = "Pluribus Navigation & Compass",
		tooltip = "Set Raid, Dungeon, City, or Guildmate GPS waypoints with the on-screen Compass Arrow.",
		yOffset = -64,
		onClick = function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Navigation")
			else
				PluribusNavigationUI:Toggle()
			end
		end,
	})
	host._plbNavSideTab = tab
end

-- Shared graphical Navigation renderer (embedded directly in MainFrame's Navigation tab & standalone window)
function PluribusNavigationUI:RenderEmbedded(parent, width, height, onRefresh)
	local UI = _G.PluribusUIFramework
	if not UI or not parent then return end
	width = width or 724
	height = height or 440

	-- Graphical Header Banner with Compass Arrow preview & HUD toggle
	local activeSub = self.activeWaypoint
		and string.format("|cff4ade80Active Compass:|r %s — %s (%.1f, %.1f)", self.activeWaypoint.name, self.activeWaypoint.zone, self.activeWaypoint.x, self.activeWaypoint.y)
		or "Pick any Raid, Dungeon, Capital City, World Boss, or Online Guildmate — or type /way X Y Name."
	local banner = UI:CreateBannerCard(parent, width, 56, "Interface\\AddOns\\PluribusCore\\Media\\CompassArrow",
		"|cff38bdf8Azeroth Compass & Guild GPS Navigation|r", activeSub, 0.22, 0.74, 0.97)
	banner:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -10)

	local hudBtn = UI:CreateButton(banner, (self.hudFrame and self.hudFrame:IsShown()) and "Hide Compass" or "Show Compass", 112, 24, function()
		PluribusNavigationUI:ToggleCompassHUD()
		if onRefresh then onRefresh() end
	end, true)
	hudBtn:SetPoint("RIGHT", banner, "RIGHT", -10, 0)

	if self.activeWaypoint then
		local clrBtn = UI:CreateButton(banner, "Clear Pin", 76, 24, function()
			PluribusNavigationUI:ClearWaypoint()
			if onRefresh then onRefresh() end
		end)
		clrBtn:SetPoint("RIGHT", hudBtn, "LEFT", -6, 0)
	end

	-- Custom coordinate quick bar
	local formCard = UI:CreateCard(parent, width, 40)
	formCard:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -8)

	local nLbl = UI:CreateLabel(formCard, "Custom Pin:", 0.78, 0.86, 0.94)
	nLbl:SetPoint("LEFT", formCard, "LEFT", 10, 0)
	local nBox = UI:CreateInputBox(formCard, 180, 22)
	nBox:SetPoint("LEFT", nLbl, "RIGHT", 6, 0)
	nBox:SetText("My Waypoint")

	local xLbl = UI:CreateLabel(formCard, "X:", 0.78, 0.86, 0.94)
	xLbl:SetPoint("LEFT", nBox, "RIGHT", 10, 0)
	local xBox = UI:CreateInputBox(formCard, 52, 22)
	xBox:SetPoint("LEFT", xLbl, "RIGHT", 4, 0)
	xBox:SetText("50.0")

	local yLbl = UI:CreateLabel(formCard, "Y:", 0.78, 0.86, 0.94)
	yLbl:SetPoint("LEFT", xBox, "RIGHT", 10, 0)
	local yBox = UI:CreateInputBox(formCard, 52, 22)
	yBox:SetPoint("LEFT", yLbl, "RIGHT", 4, 0)
	yBox:SetText("50.0")

	local setBtn = UI:CreateButton(formCard, "Navigate Here", 110, 24, function()
		local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
		PluribusNavigationUI:SetWaypoint(nBox:GetText(), zone, xBox:GetText(), yBox:GetText())
		if onRefresh then onRefresh() end
	end, true)
	setBtn:SetPoint("LEFT", yBox, "RIGHT", 10, 0)

	-- Category Tabs (Raids | Dungeons | Cities | Bosses | Guildmates GPS)
	local cats = {
		{ key = "Raids",    label = "Raids" },
		{ key = "Dungeons", label = "Dungeons" },
		{ key = "Cities",   label = "Cities" },
		{ key = "Bosses",   label = "World Bosses" },
		{ key = "Guild",    label = "Guildmates GPS" },
	}
	local catX = 12
	for _, cat in ipairs(cats) do
		local bW = cat.key == "Guild" and 126 or 98
		local b = UI:CreateButton(parent, cat.label, bW, 24, function()
			PluribusNavigationUI.selectedCat = cat.key
			if onRefresh then onRefresh() end
		end)
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", catX, -120)
		b:SetActiveState(self.selectedCat == cat.key)
		catX = catX + bW + 6
	end

	local scroll = UI:CreateScrollFrame(parent, "PluribusNavListScroll", width, math.max(200, height - 160))
	scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -150)

	local y = -2
	local rowW = width - 26
	if self.selectedCat == "Guild" then
		local members = (_G.PluribusHive and _G.PluribusHive:GetOnlineMembers()) or {}
		local idx = 0
		for _, m in ipairs(members) do
			if not m.isSelf then
				idx = idx + 1
				local row = UI:CreateListRow(scroll.content, rowW, 34, idx, function()
					PluribusNavigationUI:SetWaypoint(m.name .. " (Guild)", m.zone or "Azeroth", (m.x or 0.5) * 100, (m.y or 0.5) * 100, m.mapID)
					if onRefresh then onRefresh() end
				end)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

				local cIcon = UI:CreateClassIcon(row, m.class, 24)
				cIcon:SetPoint("LEFT", row, "LEFT", 6, 0)

				local _, _, _, hex = UI:GetClassColor(m.class)
				local l1 = UI:CreateLabel(row, string.format("%s%s|r  |cff94a3b8Lv%d · %s|r", hex, m.name, m.level or 60, m.zone or "Azeroth"))
				l1:SetPoint("LEFT", cIcon, "RIGHT", 8, 0)

				local goBtn = UI:CreateButton(row, "Set Waypoint", 92, 22, function()
					PluribusNavigationUI:SetWaypoint(m.name .. " (Guild)", m.zone or "Azeroth", (m.x or 0.5) * 100, (m.y or 0.5) * 100, m.mapID)
					if onRefresh then onRefresh() end
				end, true)
				goBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
				y = y - 36
			end
		end
		if idx == 0 then
			local em = UI:CreateLabel(scroll.content, "No online guildmates with GPS pings right now. Guildmates' positions sync automatically in the background.", 0.68, 0.78, 0.88)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -8)
		end
	else
		local list = self.DESTINATIONS[self.selectedCat] or self.DESTINATIONS.Raids
		for idx, wp in ipairs(list) do
			local row = UI:CreateListRow(scroll.content, rowW, 36, idx, function()
				PluribusNavigationUI:SetWaypoint(wp.name, wp.zone, wp.x, wp.y)
				if onRefresh then onRefresh() end
			end)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			local badge = UI:CreateIconBadge(row, wp.icon or "Interface\\Icons\\INV_Misc_Map_01", 26, 0.22, 0.74, 0.97)
			badge:SetPoint("LEFT", row, "LEFT", 6, 0)

			local l1 = UI:CreateLabel(row, "|cffffffff" .. wp.name .. "|r")
			l1:SetPoint("TOPLEFT", badge, "TOPRIGHT", 8, -1)
			local l2 = UI:CreateLabel(row, string.format("%s  ·  |cfffbbf24%.1f, %.1f|r", wp.zone, wp.x, wp.y), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 8, 1)

			local goBtn = UI:CreateButton(row, "Compass ->", 86, 22, function()
				PluribusNavigationUI:SetWaypoint(wp.name, wp.zone, wp.x, wp.y)
				if onRefresh then onRefresh() end
			end, true)
			goBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			y = y - 38
		end
	end
	scroll.content:SetHeight(math.max(200, math.abs(y) + 12))
end

function PluribusNavigationUI:Toggle()
	if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
		_G.PluribusMainFrame:OpenToTab("Navigation")
		return
	end
	if not self.mainWindow then self:CreateMainWindow() end
	self.mainWindow:SetShown(not self.mainWindow:IsShown())
	if self.mainWindow:IsShown() then self:Refresh() end
end

function PluribusNavigationUI:CreateMainWindow()
	local frame = PluribusUIFramework:CreateFrame("PluribusNavigationMainWindow", UIParent, 660, 460, "Pluribus Navigation", "Compass & Waypoints")
	frame:SetPoint("CENTER")
	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -40)
	frame.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	self.mainWindow = frame
	self:Refresh()
end

function PluribusNavigationUI:Refresh()
	if not self.mainWindow then return end
	PluribusUIFramework:ClearContainer(self.mainWindow.body)
	self:RenderEmbedded(self.mainWindow.body, 636, 412, function() PluribusNavigationUI:Refresh() end)
end

function PluribusNavigationUI:Initialize()
	self:AttachToWorldMap()
	local f = CreateFrame("Frame")
	pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function()
		PluribusNavigationUI:AttachToWorldMap()
	end)
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("Navigation UI & Compass HUD initialized (/nav, /way)", "Navigation")
	end
end

return PluribusNavigationUI
