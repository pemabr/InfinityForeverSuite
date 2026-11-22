-- Podium/Leaderboard Display System
-- Shows current DKP standings during raids

local MODULE_NAME = "Podium"
local InfinityDKP = InfinityDKP or {}
local InfinityCore = InfinityCore or {}

InfinityDKP.Podium = {
    enabled = false,
    visible = false,
    frame = nil,
    sort_by = "dkp", -- dkp, spent, earned, ratio
    max_display = 20,
    update_rate = 1.0, -- seconds
    last_update = 0,
    
    config = {
        x = 100,
        y = 100,
        width = 400,
        height = 500,
        show_in_raid = true,
        show_in_party = false,
        auto_hide_oom = false,
    }
}

local Podium = InfinityDKP.Podium

function Podium:Initialize()
    if self.frame then
        return
    end
    
    -- Subscribe to DKP updates
    if InfinityCore.Events then
        InfinityCore.Events:Subscribe("DKP_BALANCE_CHANGED", function(player, new_balance)
            Podium:ScheduleUpdate()
        end)
        
        InfinityCore.Events:Subscribe("RAID_ENCOUNTER_END", function()
            if self.config.show_in_raid and self.visible then
                self:Refresh()
            end
        end)
    end
    
    self:CreateFrame()
end

function Podium:CreateFrame()
    if self.frame then
        return
    end
    
    local frame = CreateFrame("Frame", "InfinityPodiumFrame", UIParent, "BackdropTemplate")
    frame:SetSize(self.config.width, self.config.height)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.config.x, -self.config.y)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Title bar
    local titlebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titlebar:SetSize(self.config.width, 25)
    titlebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titlebar:SetBackdropColor(0.2, 0.2, 0.2, 1)
    
    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titlebar, "LEFT", 8, 0)
    title:SetText("DKP Leaderboard")
    
    -- Close button
    local close_btn = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    close_btn:SetPoint("RIGHT", titlebar, "RIGHT", -2, 0)
    close_btn:SetScript("OnClick", function()
        Podium:Hide()
    end)
    
    -- Make draggable
    titlebar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    titlebar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        Podium.config.x = frame:GetLeft()
        Podium.config.y = -frame:GetTop()
    end)
    
    -- Scroll frame
    local scroll = CreateFrame("ScrollFrame", "InfinityPodiumScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetSize(self.config.width - 25, self.config.height - 60)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -30)
    
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(self.config.width - 40, 10)
    scroll:SetScrollChild(content)
    
    frame.scroll = scroll
    frame.content = content
    frame:Hide()
    
    self.frame = frame
end

function Podium:GetStandings()
    if not InfinityDKP.db or not InfinityDKP.db.players then
        return {}
    end
    
    local standings = {}
    
    for player_name, player_data in pairs(InfinityDKP.db.players) do
        local balance = player_data.balance or 0
        local earned = player_data.earned or 0
        local spent = player_data.spent or 0
        
        table.insert(standings, {
            name = player_name,
            balance = balance,
            earned = earned,
            spent = spent,
            ratio = earned > 0 and (spent / earned) or 0
        })
    end
    
    -- Sort by specified criteria
    table.sort(standings, function(a, b)
        if Podium.sort_by == "dkp" then
            return a.balance > b.balance
        elseif Podium.sort_by == "spent" then
            return a.spent > b.spent
        elseif Podium.sort_by == "earned" then
            return a.earned > b.earned
        elseif Podium.sort_by == "ratio" then
            return a.ratio > b.ratio
        end
        return a.balance > b.balance
    end)
    
    return standings
end

function Podium:Refresh()
    if not self.frame or not self.visible then
        return
    end
    
    local standings = self:GetStandings()
    local content = self.frame.content
    
    -- Clear existing
    for i = #content, 1, -1 do
        content[i]:Hide()
    end
    
    local y_offset = 0
    
    for idx, standing in ipairs(standings) do
        if idx > self.max_display then
            break
        end
        
        local row = content[idx]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(content:GetWidth(), 20)
            content[idx] = row
        end
        
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y_offset)
        row:Show()
        
        -- Rank
        local rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rank:SetWidth(30)
        rank:SetText(tostring(idx))
        rank:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
        rank:SetTextColor(1, 1, 1, 1)
        
        -- Player name
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        name:SetWidth(120)
        name:SetText(standing.name)
        name:SetPoint("TOPLEFT", row, "TOPLEFT", 35, 0)
        
        -- Class color
        local class_name = GetPlayerClass(standing.name)
        if class_name then
            local class_colors = RAID_CLASS_COLORS[class_name]
            if class_colors then
                name:SetTextColor(class_colors.r, class_colors.g, class_colors.b, 1)
            end
        end
        
        -- DKP balance
        local balance_str = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        balance_str:SetWidth(70)
        balance_str:SetText(tostring(standing.balance))
        balance_str:SetPoint("TOPLEFT", row, "TOPLEFT", 160, 0)
        
        -- Color based on balance
        if standing.balance > 1000 then
            balance_str:SetTextColor(0.1, 1, 0.1, 1) -- Green
        elseif standing.balance < 0 then
            balance_str:SetTextColor(1, 0.1, 0.1, 1) -- Red
        else
            balance_str:SetTextColor(1, 1, 1, 1) -- White
        end
        
        -- Earned
        local earned_str = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        earned_str:SetWidth(60)
        earned_str:SetText(tostring(standing.earned))
        earned_str:SetPoint("TOPLEFT", row, "TOPLEFT", 240, 0)
        earned_str:SetTextColor(0.5, 1, 0.5, 1)
        
        -- Spent
        local spent_str = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        spent_str:SetWidth(60)
        spent_str:SetText(tostring(standing.spent))
        spent_str:SetPoint("TOPLEFT", row, "TOPLEFT", 310, 0)
        spent_str:SetTextColor(1, 0.5, 0.5, 1)
        
        y_offset = y_offset + 22
    end
    
    -- Update scroll child height
    content:SetHeight(math.min(#standings, self.max_display) * 22)
end

function Podium:ScheduleUpdate()
    self.last_update = GetTime()
end

function Podium:Toggle()
    if self.visible then
        self:Hide()
    else
        self:Show()
    end
end

function Podium:Show()
    if not self.frame then
        self:CreateFrame()
    end
    
    self.visible = true
    self.frame:Show()
    self:Refresh()
end

function Podium:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self.visible = false
end

function Podium:SetSortBy(sort_type)
    self.sort_by = sort_type or "dkp"
    self:Refresh()
end

function Podium:SetMaxDisplay(count)
    self.max_display = count or 20
    self:Refresh()
end

-- Register slash command
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("podium", function(args)
        if args == "toggle" then
            Podium:Toggle()
        elseif args == "show" then
            Podium:Show()
        elseif args == "hide" then
            Podium:Hide()
        elseif string.find(args, "sort") then
            local sort_type = string.match(args, "sort (%w+)")
            if sort_type then
                Podium:SetSortBy(sort_type)
            end
        else
            Podium:Toggle()
        end
    end, "Toggle DKP leaderboard display")
end

-- Auto-show in raids
if InfinityCore.Events then
    InfinityCore.Events:Subscribe("RAID_FORMED", function()
        if Podium.config.show_in_raid and not Podium.visible then
            Podium:Show()
        end
    end)
    
    InfinityCore.Events:Subscribe("RAID_DISBANDED", function()
        if Podium.visible then
            Podium:Hide()
        end
    end)
end

return InfinityDKP.Podium
