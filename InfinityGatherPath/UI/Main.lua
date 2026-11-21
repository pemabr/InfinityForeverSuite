-- Main UI
-- Gathering route manager

local InfinityGatherPathUI = {}

function InfinityGatherPathUI:Initialize()
    self.frame = CreateFrame("Frame", "InfinityGatherPathMainFrame", UIParent)
    self.frame:SetSize(500, 400)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 300, -100)
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
    title:SetText("Infinity GatherPath")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Routes display
    self.routes_text = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.routes_text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    self.routes_text:SetWidth(480)
    self.routes_text:SetJustifyH("LEFT")
    self.routes_text:SetText("No routes recorded")
    
    self.frame:Hide()
    self.initialized = true
end

function InfinityGatherPathUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:SetShown(not self.frame:IsShown())
end

function InfinityGatherPathUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
    self:Update()
end

function InfinityGatherPathUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    if InfinityRoutes then
        local routes = InfinityRoutes:GetRoutes()
        local text = "Available Routes:\n\n"
        
        local count = 0
        for routeID, route in pairs(routes) do
            text = text .. string.format("• %s (%d nodes in %s)\n",
                route.name, #route.nodes, route.zone)
            count = count + 1
        end
        
        if count == 0 then
            text = "No routes recorded"
        end
        
        self.routes_text:SetText(text)
    end
end

return InfinityGatherPathUI
