-- Inventory UI Module
local InfinityInventoryUI = {}
_G.InfinityInventoryUI = InfinityInventoryUI

InfinityInventoryUI.mainFrame = nil

function InfinityInventoryUI:Initialize()
	InfinityUtils:Info("Inventory UI initialized", "Inventory")
end

function InfinityInventoryUI:Toggle()
	if not self.mainFrame then
		self:CreateFrame()
	end
	
	if self.mainFrame:IsShown() then
		self.mainFrame:Hide()
	else
		self.mainFrame:Show()
	end
end

function InfinityInventoryUI:CreateFrame()
	local frame = CreateFrame("Frame", "InfinityInventoryFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(400, 500)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle("Inventory Manager")
	
	-- Bag value display
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
	text:SetText("Bag Value: Calculating...")
	
	frame.bagValueText = text
	self.mainFrame = frame
end

return InfinityInventoryUI
