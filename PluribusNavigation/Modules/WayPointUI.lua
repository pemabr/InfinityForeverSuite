-- Waypoint UI Module
local PluribusWayPointUI = {}
_G.PluribusWayPointUI = PluribusWayPointUI

PluribusWayPointUI.frame = nil
PluribusWayPointUI.waypoints = {}

function PluribusWayPointUI:Initialize()
	PluribusUtils:Info("Waypoint UI initialized", "Navigation")
end

function PluribusWayPointUI:Toggle()
	if not self.frame then
		self:CreateFrame()
	end
	
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self.frame:Show()
	end
end

function PluribusWayPointUI:CreateFrame()
	local frame = CreateFrame("Frame", "PluribusWayPointFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(300, 400)
	frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -60)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle("Navigation Waypoints")
	
	-- Scroll frame for waypoints
	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetSize(280, 350)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
	
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(260, 1)
	scroll:SetScrollChild(content)
	
	frame.scroll = scroll
	frame.content = content
	self.frame = frame
end

function PluribusWayPointUI:AddWaypoint(description, x, y, zone)
	if not self.frame then
		self:CreateFrame()
	end
	
	local text = self.frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", self.frame.content, "TOPLEFT", 5, -5 - (#self.waypoints * 20))
	text:SetText(description .. " (" .. math.floor(x * 100) .. ", " .. math.floor(y * 100) .. ")")
end

return PluribusWayPointUI
