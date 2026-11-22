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

    local start = InfinityUIFramework:CreateButton(self.frame, "Start", 90, 22, function()
        local tracker = InfinityAttendanceTracker
        local current = tracker:GetCurrentRaid()
        if current and not current.end_time then
            InfinityUtils:Warning("Attendance tracking is already running.", "Attendance")
        else
            tracker:StartTracking()
        end
        self:Update()
    end)
    start:SetPoint("TOPLEFT", 12, -38)
    local finish = InfinityUIFramework:CreateButton(self.frame, "End", 90, 22, function()
        local tracker = InfinityAttendanceTracker
        local current = tracker:GetCurrentRaid()
        if not current or current.end_time then
            InfinityUtils:Warning("No attendance tracking is running.", "Attendance")
        else
            tracker:EndTracking()
        end
        self:Update()
    end)
    finish:SetPoint("LEFT", start, "RIGHT", 8, 0)
    self.autoButton = InfinityUIFramework:CreateButton(self.frame, "Auto", 140, 22, function()
        local tracker = InfinityAttendanceTracker
        tracker:SetAutoTracking(not tracker.auto_tracking)
        self:Update()
    end)
    self.autoButton:SetPoint("LEFT", finish, "RIGHT", 8, 0)
    
    -- Content
    self.content = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 12, -72)
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
        local raid = InfinityAttendanceTracker:GetCurrentRaid()
        self.content:SetText((raid and not raid.end_time and "Tracking active.\n" or "Tracking stopped.\n")
            .. "Session data is not saved across reloads.\n" .. report)
        self.autoButton:SetText(InfinityAttendanceTracker.auto_tracking and "Auto: on" or "Auto: off")
    end
end

return InfinityAttendanceUI
