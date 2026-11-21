-- Main UI
-- Attendance window

local InfinityAttendanceUI = {}
_G.InfinityAttendanceUI = InfinityAttendanceUI

function InfinityAttendanceUI:Initialize()
    self.frame = CreateFrame("Frame", "InfinityAttendanceMainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame:SetSize(500, 350)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
    self.frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.8)
    self.frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    
    -- Title
    local title = self.frame:CreateFontString(nil, "ARTWORK", (GameFontBold and "GameFontBold" or "GameFontNormalLarge"))
    title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -10)
    title:SetText("Infinity Attendance")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Content
    self.content = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.content:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    self.content:SetWidth(480)
    self.content:SetJustifyH("LEFT")
    self.content:SetText("No raids tracked yet")
    
    self.frame:Hide()
    self.initialized = true
end

function InfinityAttendanceUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:SetShown(not self.frame:IsShown())
    if self.frame:IsShown() then
        self:Update()
    end
end

function InfinityAttendanceUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
    self:Update()
end

function InfinityAttendanceUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    if InfinityAttendanceStats then
        local report = InfinityAttendanceStats:GetAttendanceReport()
        self.content:SetText(report)
    end
end

return InfinityAttendanceUI
