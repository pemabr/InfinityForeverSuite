-- Officer Dashboard
-- Comprehensive guild management interface for officers

local MODULE_NAME = "OfficerDashboard"
local InfinityCore = InfinityCore or {}
local InfinityDKP = InfinityDKP or {}

InfinityCore.OfficerDashboard = {
    enabled = false,
    visible = false,
    frame = nil,
    
    config = {
        x = 100,
        y = 100,
        width = 800,
        height = 600,
    },
    
    tabs = {
        "overview",
        "dkp_management",
        "loot_audits",
        "player_status",
        "settings"
    },
    
    current_tab = "overview"
}

local Dashboard = InfinityCore.OfficerDashboard

function Dashboard:Initialize()
    if self.frame then
        return
    end
    
    self:CreateFrame()
end

function Dashboard:CreateFrame()
    if self.frame then
        return
    end
    
    local frame = CreateFrame("Frame", "InfinityOfficerDashboard", UIParent, "BackdropTemplate")
    frame:SetSize(self.config.width, self.config.height)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.config.x, -self.config.y)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Title bar
    local titlebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titlebar:SetSize(self.config.width, 30)
    titlebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titlebar:SetBackdropColor(0.2, 0.2, 0.2, 1)
    
    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titlebar, "LEFT", 8, 0)
    title:SetText("Officer Dashboard")
    
    -- Close button
    local close_btn = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    close_btn:SetPoint("RIGHT", titlebar, "RIGHT", -2, 0)
    close_btn:SetScript("OnClick", function()
        Dashboard:Hide()
    end)
    
    -- Make draggable
    titlebar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    titlebar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        Dashboard.config.x = frame:GetLeft()
        Dashboard.config.y = -frame:GetTop()
    end)
    
    -- Tab buttons
    local tab_frame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tab_frame:SetSize(self.config.width, 30)
    tab_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -30)
    tab_frame:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
    
    frame.tabs = {}
    local tab_x = 5
    
    for _, tab_name in ipairs(self.tabs) do
        local tab_btn = CreateFrame("Button", nil, tab_frame, "GameMenuButtonTemplate")
        tab_btn:SetWidth(140)
        tab_btn:SetHeight(25)
        tab_btn:SetPoint("TOPLEFT", tab_frame, "TOPLEFT", tab_x, -2)
        
        local tab_label = string.upper(string.gsub(tab_name, "_", " "))
        tab_btn:SetText(tab_label)
        
        tab_btn:SetScript("OnClick", function()
            Dashboard:SwitchTab(tab_name)
        end)
        
        frame.tabs[tab_name] = tab_btn
        tab_x = tab_x + 150
    end
    
    -- Content frame
    local content_frame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content_frame:SetSize(self.config.width - 10, self.config.height - 100)
    content_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -65)
    content_frame:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
    content_frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    frame.content = content_frame
    frame:Hide()
    
    self.frame = frame
end

function Dashboard:SwitchTab(tab_name)
    self.current_tab = tab_name
    
    -- Update tab button styles
    for _, tab_btn in pairs(self.frame.tabs) do
        tab_btn:SetNormalFontObject("GameFontNormal")
    end
    
    if self.frame.tabs[tab_name] then
        self.frame.tabs[tab_name]:SetNormalFontObject("GameFontHighlight")
    end
    
    self:RefreshContent()
end

function Dashboard:RefreshContent()
    local content = self.frame.content
    
    -- Clear existing content
    for i = #content, 1, -1 do
        if content[i] and content[i]:IsObjectType("Frame") then
            content[i]:Hide()
        end
    end
    
    if self.current_tab == "overview" then
        self:ShowOverview(content)
    elseif self.current_tab == "dkp_management" then
        self:ShowDKPManagement(content)
    elseif self.current_tab == "loot_audits" then
        self:ShowLootAudits(content)
    elseif self.current_tab == "player_status" then
        self:ShowPlayerStatus(content)
    elseif self.current_tab == "settings" then
        self:ShowSettings(content)
    end
end

function Dashboard:ShowOverview(parent)
    local y = 10
    
    -- Guild stats
    local stats_title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stats_title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y)
    stats_title:SetText("Guild Statistics")
    
    y = y + 25
    
    local member_count = GetNumGuildMembers()
    local member_text = parent:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    member_text:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    member_text:SetText(string.format("Members: %d", member_count))
    
    y = y + 20
    
    -- DKP summary
    local dkp_title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dkp_title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y)
    dkp_title:SetText("DKP Summary")
    
    y = y + 25
    
    local total_points = 0
    local player_count = 0
    if InfinityDKP and InfinityDKP.db and InfinityDKP.db.players then
        for _, player_data in pairs(InfinityDKP.db.players) do
            total_points = total_points + (player_data.balance or 0)
            player_count = player_count + 1
        end
    end
    
    local dkp_text = parent:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    dkp_text:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    dkp_text:SetText(string.format("Players with DKP: %d", player_count))
    
    y = y + 20
    
    local total_text = parent:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    total_text:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    total_text:SetText(string.format("Total DKP in circulation: %d", total_points))
    
    y = y + 25
    
    -- Loot summary
    local loot_title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loot_title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y)
    loot_title:SetText("Recent Activity")
    
    y = y + 25
    
    local activity_text = parent:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    activity_text:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    
    local tx_count = 0
    if InfinityDKP and InfinityDKP.db and InfinityDKP.db.transactions then
        tx_count = #InfinityDKP.db.transactions
    end
    
    activity_text:SetText(string.format("Transactions logged: %d", tx_count))
end

function Dashboard:ShowDKPManagement(parent)
    local y = 10
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y)
    title:SetText("DKP Management Tools")
    
    y = y + 30
    
    -- Manual award button
    local award_btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    award_btn:SetWidth(120)
    award_btn:SetHeight(25)
    award_btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    award_btn:SetText("Award Points")
    award_btn:SetScript("OnClick", function()
        print("|cffff9900Coming soon: Award Points dialog|r")
    end)
    
    y = y + 30
    
    -- Decay trigger button
    local decay_btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    decay_btn:SetWidth(120)
    decay_btn:SetHeight(25)
    decay_btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    decay_btn:SetText("Apply Decay")
    decay_btn:SetScript("OnClick", function()
        if InfinityDKP and InfinityDKP.Decay and InfinityDKP.Decay.ApplyDecay then
            InfinityDKP.Decay:ApplyDecay()
            print("|cff00ff00✓ Decay applied|r")
        end
    end)
    
    y = y + 30
    
    -- View audit log button
    local audit_btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    audit_btn:SetWidth(120)
    audit_btn:SetHeight(25)
    audit_btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    audit_btn:SetText("View Audit Log")
    audit_btn:SetScript("OnClick", function()
        print("|cffff9900/dkp history <player>|r")
    end)
end

function Dashboard:ShowLootAudits(parent)
    local y = 10
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y)
    title:SetText("Loot Audit & Recovery")
    
    y = y + 30
    
    -- Recent awards
    local awards_text = parent:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    awards_text:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    awards_text:SetText("Recent loot awards listed below. Use |cffff9900/reclaim list|r in chat.")
    
    y = y + 25
    
    -- Reclaim button
    local reclaim_btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    reclaim_btn:SetWidth(120)
    reclaim_btn:SetHeight(25)
    reclaim_btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    reclaim_btn:SetText("View Reclaims")
    reclaim_btn:SetScript("OnClick", function()
        print("|cffff9900/reclaim log|r")
    end)
end

function Dashboard:ShowPlayerStatus(parent)
    local y = 10
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y)
    title:SetText("Player Status & Rankings")
    
    y = y + 30
    
    -- Top players by DKP
    local top_text = parent:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    top_text:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    top_text:SetText("View leaderboard with |cffff9900/podium show|r")
    
    y = y + 25
    
    -- View player history button
    local history_btn = CreateFrame("Button", nil, parent, "GameMenuButtonTemplate")
    history_btn:SetWidth(140)
    history_btn:SetHeight(25)
    history_btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    history_btn:SetText("View Player History")
    history_btn:SetScript("OnClick", function()
        print("|cffff9900/dkphistory <player>|r")
    end)
end

function Dashboard:ShowSettings(parent)
    local y = 10
    
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y)
    title:SetText("Settings & Configuration")
    
    y = y + 30
    
    local settings_text = parent:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    settings_text:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -y)
    settings_text:SetText("Use addon configuration panel or |cffff9900/inf config|r")
end

function Dashboard:Toggle()
    if self.visible then
        self:Hide()
    else
        self:Show()
    end
end

function Dashboard:Show()
    if not self.frame then
        self:CreateFrame()
    end
    
    self.visible = true
    self.frame:Show()
    self:RefreshContent()
end

function Dashboard:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self.visible = false
end

-- Register slash command
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("dashboard", function(args)
        if args == "toggle" then
            Dashboard:Toggle()
        elseif args == "show" then
            Dashboard:Show()
        elseif args == "hide" then
            Dashboard:Hide()
        else
            Dashboard:Toggle()
        end
    end, "Open officer dashboard (Officer only)")
end

-- Auto-show dashboard for officers
if InfinityCore.Events then
    InfinityCore.Events:Subscribe("PLAYER_ENTERING_WORLD", function()
        local _, _, rank = GetGuildInfo("player")
        if rank and rank <= 1 then
            print("|cff00ccffOfficer detected. Use |cffff9900/dashboard|r to open Officer Dashboard.|r")
        end
    end)
end

return InfinityCore.OfficerDashboard
