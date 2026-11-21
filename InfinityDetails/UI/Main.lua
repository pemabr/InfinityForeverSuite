-- Main UI
-- DPS/HPS/Threat meters window

local InfinityDetailsUI = {}

function InfinityDetailsUI:Initialize()
    self.frame = CreateFrame("Frame", "InfinityDetailsMainFrame", UIParent)
    self.frame:SetSize(700, 500)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.8)
    self.frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    
    -- Title
    local title = self.frame:CreateFontString(nil, "ARTWORK", "GameFontBold")
    title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -10)
    title:SetText("Infinity Details - Meters")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Meters display
    self.dps_text = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.dps_text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    self.dps_text:SetWidth(680)
    self.dps_text:SetJustifyH("LEFT")
    self.dps_text:SetText("DPS Meter\nNo combat data")
    
    self.frame:Hide()
    self.initialized = true
end

function InfinityDetailsUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:SetShown(not self.frame:IsShown())
end

function InfinityDetailsUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
    self:Update()
end

function InfinityDetailsUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    if InfinityDetailsReports then
        local report = InfinityDetailsReports:GenerateDPSReport()
        self.dps_text:SetText(report)
    end
end

return InfinityDetailsUI
