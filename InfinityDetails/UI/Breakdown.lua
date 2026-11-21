-- Breakdown Window
-- Individual actor performance breakdown

local InfinityDetailsBreakdown = {}
_G.InfinityDetailsBreakdown = InfinityDetailsBreakdown

function InfinityDetailsBreakdown:Initialize()
    self.frame = CreateFrame("Frame", "InfinityDetailsBreakdownFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame:SetSize(500, 400)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
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
    title:SetText("Infinity Details - Breakdown")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Actor list
    self.actor_list = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.actor_list:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    self.actor_list:SetWidth(480)
    self.actor_list:SetJustifyH("LEFT")
    self.actor_list:SetText("No actor data")
    
    self.frame:Hide()
    self.initialized = true
end

function InfinityDetailsBreakdown:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:SetShown(not self.frame:IsShown())
end

function InfinityDetailsBreakdown:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
end

function InfinityDetailsBreakdown:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    if InfinityDetailsActor then
        local topDamageDealers = InfinityDetailsActor:GetTopDamageDealers(5)
        local text = "Top Damage Dealers:\n\n"
        
        for i, actor in ipairs(topDamageDealers) do
            text = text .. string.format("%d. %s: %d damage (%d hits)\n",
                i, actor.name, actor.damage_total, actor.damage_hits)
        end
        
        self.actor_list:SetText(text)
    end
end

return InfinityDetailsBreakdown
