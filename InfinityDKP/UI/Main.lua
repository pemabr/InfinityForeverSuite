-- Main UI
-- DKP management interface

local InfinityDKPUI = {}

function InfinityDKPUI:Initialize()
    self.frame = CreateFrame("Frame", "InfinityDKPMainFrame", UIParent)
    self.frame:SetSize(600, 400)
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
    local title = self.frame:CreateFontString(nil, "ARTWORK", "GameFontBold")
    title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -10)
    title:SetText("Infinity DKP Management")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self.frame:Hide() end)
    
    -- Tabs
    local tabsFrame = CreateFrame("Frame", nil, self.frame)
    tabsFrame:SetSize(580, 30)
    tabsFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    
    local tabs = {"Players", "Auctions", "History", "Reports"}
    for i, tabName in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, tabsFrame)
        tab:SetSize(140, 25)
        tab:SetPoint("TOPLEFT", tabsFrame, "TOPLEFT", (i-1) * 145, 0)
        tab:SetNormalFontObject(GameFontNormal)
        tab:SetText(tabName)
        tab:SetNormalTexture("Interface/Buttons/UI-Panel-Button-Up")
        tab:SetPushedTexture("Interface/Buttons/UI-Panel-Button-Down")
    end
    
    -- Content area
    self.content = CreateFrame("Frame", nil, self.frame)
    self.content:SetSize(580, 320)
    self.content:SetPoint("TOPLEFT", tabsFrame, "BOTTOMLEFT", 0, -10)
    
    -- Player list
    self.player_list = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.player_list:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, 0)
    self.player_list:SetWidth(580)
    self.player_list:SetJustifyH("LEFT")
    self.player_list:SetText("Loading player data...")
    
    self.frame:Hide()
    self.initialized = true
end

function InfinityDKPUI:Toggle()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:SetShown(not self.frame:IsShown())
end

function InfinityDKPUI:Show()
    if not self.initialized then
        self:Initialize()
    end
    self.frame:Show()
    self:Update()
end

function InfinityDKPUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function InfinityDKPUI:Update()
    if not self.initialized or not self.frame:IsShown() then
        return
    end
    
    if InfinityDKPEngine then
        local ranked = InfinityDKPEngine:GetRankedPlayers()
        local text = ""
        
        for i, player in ipairs(ranked) do
            if i > 15 then break end
            text = text .. string.format("%-3d %-20s %-8d %-8d %-10.2f\n",
                i, player.name, player.ep, player.gp, player.priority)
        end
        
        if text == "" then
            text = "No players registered"
        end
        
        self.player_list:SetText(text)
    end
end

return InfinityDKPUI
