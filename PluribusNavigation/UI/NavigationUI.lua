-- PluribusNavigation UI Module
-- Waypoint Input, Classic Azeroth Raid/City Presets, Live Distance Readout & Compass Arrow

local PluribusNavigationUI = {
	mainWindow = nil,
	activeWaypoint = nil,
}
_G.PluribusNavigationUI = PluribusNavigationUI

local PRESET_WAYPOINTS = {
	{ name = "Naxxramas (Eastern Plaguelands)", zone = "Eastern Plaguelands", x = 39.2, y = 26.4 },
	{ name = "Blackrock Mountain (MC / BWL)", zone = "Burning Steppes", x = 29.4, y = 38.2 },
	{ name = "Gates of Ahn'Qiraj (AQ20 / AQ40)", zone = "Silithus", x = 28.6, y = 92.4 },
	{ name = "Onyxia's Lair (Dustwallow Marsh)", zone = "Dustwallow Marsh", x = 52.2, y = 76.1 },
	{ name = "Zul'Gurub (Stranglethorn Vale)", zone = "Stranglethorn Vale", x = 53.8, y = 17.6 },
	{ name = "Azuregos Spawn (Azshara)", zone = "Azshara", x = 56.1, y = 80.5 },
	{ name = "Lord Kazzak (Blasted Lands)", zone = "Blasted Lands", x = 32.4, y = 48.2 },
}

function PluribusNavigationUI:Initialize()
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("Navigation UI initialized", "Navigation")
	end
end

function PluribusNavigationUI:SetWaypoint(name, zone, x, y)
	self.activeWaypoint = { name = name, zone = zone, x = tonumber(x) or 50, y = tonumber(y) or 50 }
	if _G.PluribusNavigator and _G.PluribusNavigator.SetWaypoint then
		pcall(function() _G.PluribusNavigator:SetWaypoint(self.activeWaypoint.x, self.activeWaypoint.y, name) end)
	end
	PluribusUIFramework:ShowNotification(string.format("Waypoint set: %s (%.1f, %.1f)", name, self.activeWaypoint.x, self.activeWaypoint.y), 2.5)
	if self.mainWindow and self.mainWindow:IsShown() then
		self:Refresh()
	end
end

function PluribusNavigationUI:Toggle()
	if not self.mainWindow then self:CreateMainWindow() end
	self.mainWindow:SetShown(not self.mainWindow:IsShown())
	if self.mainWindow:IsShown() then self:Refresh() end
end

function PluribusNavigationUI:CreateMainWindow()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusNavigationMainWindow",
		UIParent,
		600,
		450,
		"Pluribus Navigation",
		"Waypoints & Azeroth Raid Presets"
	)
	frame:SetPoint("CENTER")

	-- Custom waypoint form
	local formCard = PluribusUIFramework:CreateCard(frame, 576, 84, "Set Custom Waypoint")
	formCard:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)

	local nLbl = PluribusUIFramework:CreateLabel(formCard, "Label:")
	nLbl:SetPoint("TOPLEFT", formCard, "TOPLEFT", 12, -38)
	local nBox = PluribusUIFramework:CreateInputBox(formCard, 150, 22)
	nBox:SetPoint("LEFT", nLbl, "RIGHT", 6, 0)
	nBox:SetText("Custom Pin")

	local xLbl = PluribusUIFramework:CreateLabel(formCard, "X:")
	xLbl:SetPoint("LEFT", nBox, "RIGHT", 10, 0)
	local xBox = PluribusUIFramework:CreateInputBox(formCard, 52, 22)
	xBox:SetPoint("LEFT", xLbl, "RIGHT", 4, 0)
	xBox:SetText("50.0")

	local yLbl = PluribusUIFramework:CreateLabel(formCard, "Y:")
	yLbl:SetPoint("LEFT", xBox, "RIGHT", 10, 0)
	local yBox = PluribusUIFramework:CreateInputBox(formCard, 52, 22)
	yBox:SetPoint("LEFT", yLbl, "RIGHT", 4, 0)
	yBox:SetText("50.0")

	local setBtn = PluribusUIFramework:CreateButton(formCard, "Set Pin", 80, 24, function()
		local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
		PluribusNavigationUI:SetWaypoint(nBox:GetText(), zone, xBox:GetText(), yBox:GetText())
	end, true)
	setBtn:SetPoint("LEFT", yBox, "RIGHT", 10, 0)

	local clrBtn = PluribusUIFramework:CreateButton(formCard, "Clear", 64, 24, function()
		PluribusNavigationUI.activeWaypoint = nil
		PluribusNavigationUI:Refresh()
	end)
	clrBtn:SetPoint("LEFT", setBtn, "RIGHT", 6, 0)

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetSize(576, 304)
	frame.body:SetPoint("TOPLEFT", formCard, "BOTTOMLEFT", 0, -10)

	self.mainWindow = frame
	self:Refresh()
end

function PluribusNavigationUI:Refresh()
	if not self.mainWindow then return end
	local b = self.mainWindow.body
	PluribusUIFramework:ClearContainer(b)

	local activeText = self.activeWaypoint
		and string.format("|cff4ade80Active Target:|r %s — %s (%.1f, %.1f)", self.activeWaypoint.name, self.activeWaypoint.zone, self.activeWaypoint.x, self.activeWaypoint.y)
		or "|cff94a3b8No active waypoint. Choose a raid entrance below or enter custom coordinates.|r"

	local statusCard = PluribusUIFramework:CreateCard(b, 576, 44)
	statusCard:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local stLbl = PluribusUIFramework:CreateLabel(statusCard, activeText)
	stLbl:SetPoint("LEFT", statusCard, "LEFT", 12, 0)

	local presetCard = PluribusUIFramework:CreateCard(b, 576, 246, "Classic Raid & World Boss Entrances")
	presetCard:SetPoint("TOPLEFT", statusCard, "BOTTOMLEFT", 0, -10)

	local y = -32
	for idx, wp in ipairs(PRESET_WAYPOINTS) do
		local row = PluribusUIFramework:CreateListRow(presetCard, 552, 26, idx, function()
			PluribusNavigationUI:SetWaypoint(wp.name, wp.zone, wp.x, wp.y)
		end)
		row:SetPoint("TOPLEFT", presetCard, "TOPLEFT", 12, y)

		local l = PluribusUIFramework:CreateLabel(row, "|cff38bdf8" .. wp.name .. "|r")
		l:SetPoint("LEFT", row, "LEFT", 8, 0)
		local r = PluribusUIFramework:CreateLabel(row, string.format("|cfffbbf24%.1f, %.1f|r", wp.x, wp.y))
		r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		y = y - 28
	end
end

return PluribusNavigationUI
