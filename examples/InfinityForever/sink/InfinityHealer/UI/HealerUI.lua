-- Healer UI Module
local InfinityHealerUI = {}
_G.InfinityHealerUI = InfinityHealerUI

InfinityHealerUI.mainWindow = nil
InfinityHealerUI.settingsFrame = nil

function InfinityHealerUI:Initialize()
	InfinityUtils:Info("Healer UI initialized", "Healer")
end

function InfinityHealerUI:Toggle()
	if not self.mainWindow then
		self:CreateMainWindow()
	end
	
	if self.mainWindow:IsShown() then
		self.mainWindow:Hide()
	else
		self.mainWindow:Show()
	end
end

function InfinityHealerUI:CreateMainWindow()
	local frame = CreateFrame("Frame", "InfinityHealerMainWindow", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(400, 300)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle("Infinity Healer Settings")
	
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", frame, "CENTER")
	text:SetText("Healer UI - Settings Coming Soon")
	
	self.mainWindow = frame
end

return InfinityHealerUI
