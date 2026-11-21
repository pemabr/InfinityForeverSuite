-- Main UI
-- Encounter window and status display

local InfinityEncounterUI = {}

function InfinityEncounterUI:Initialize()
    self.frame = CreateFrame("Frame", "InfinityEncounterMainFrame", UIParent)
    self.frame:SetSize(400, 300)
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
    title:SetText("Infinity Encounter")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Status text
    self.status_text = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.status_text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    self.status_text:SetWidth(380)
    self.status_text:SetJustifyH("LEFT")
    self.status_text:SetText("No encounter active")
    
    -- Abilities section
    self.abilities_frame = CreateFrame("Frame", nil, self.frame)
    self.abilities_frame:SetSize(380, 100)
    self.abilities_frame:SetPoint("TOPLEFT", self.status_text, "BOTTOMLEFT", 0, -20)
    
    -- Timer section
    self.timer_frame = CreateFrame("Frame", nil, self.frame)
    self.timer_frame:SetSize(380, 50)
    self.timer_frame:SetPoint("TOPLEFT", self.abilities_frame, "BOTTOMLEFT", 0, -10)
    
    self.frame:Hide()
    self.initialized = true
end

function InfinityEncounterUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:SetShown(not self.frame:IsShown())
end

function InfinityEncounterUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
end

function InfinityEncounterUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function InfinityEncounterUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    -- Update status
    local boss = InfinityEncounterMgr:GetCurrentBoss()
    if boss then
        local text = string.format("Boss: %s\nHealth: %.1f%% (%d/%d)", 
            boss.name, boss.healthPercent, boss.health, boss.maxHealth)
        self.status_text:SetText(text)
    else
        self.status_text:SetText("No boss in combat")
    end
    
    -- Update timers
    if InfinityEncounterTimer then
        local timers = InfinityEncounterTimer:GetActiveTimers()
        local timerText = ""
        for i = 1, math.min(3, #timers) do
            local timer = timers[i]
            local remaining = timer:GetRemaining()
            timerText = timerText .. string.format("%s: %.1fs\n", timer.name, remaining)
        end
        
        if timerText == "" then
            timerText = "No active timers"
        end
        
        if not self.timer_text then
            self.timer_text = self.timer_frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            self.timer_text:SetPoint("TOPLEFT", self.timer_frame, "TOPLEFT", 0, 0)
            self.timer_text:SetWidth(380)
            self.timer_text:SetJustifyH("LEFT")
        end
        self.timer_text:SetText(timerText)
    end
end

return InfinityEncounterUI
