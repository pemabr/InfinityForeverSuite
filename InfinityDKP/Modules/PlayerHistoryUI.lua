-- Player DKP History UI
-- Shows personal DKP balance, transaction history, and statistics

local MODULE_NAME = "PlayerHistoryUI"
local InfinityDKP = InfinityDKP or {}
local InfinityCore = InfinityCore or {}

InfinityDKP.PlayerHistoryUI = {
    enabled = false,
    visible = false,
    frame = nil,
    current_player = nil,
    
    config = {
        x = 400,
        y = 100,
        width = 500,
        height = 600,
    }
}

local HistoryUI = InfinityDKP.PlayerHistoryUI

function HistoryUI:Initialize()
    if self.frame then
        return
    end
    
    -- Subscribe to DKP changes
    if InfinityCore.Events then
        InfinityCore.Events:Subscribe("DKP_BALANCE_CHANGED", function(player)
            if HistoryUI.visible and HistoryUI.current_player == player then
                HistoryUI:Refresh()
            end
        end)
    end
    
    self:CreateFrame()
end

function HistoryUI:CreateFrame()
    if self.frame then
        return
    end
    
    local frame = CreateFrame("Frame", "InfinityPlayerHistoryFrame", UIParent, "BackdropTemplate")
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
    title:SetText("DKP History")
    frame.title = title
    
    -- Close button
    local close_btn = CreateFrame("Button", nil, titlebar, "UIPanelCloseButton")
    close_btn:SetPoint("RIGHT", titlebar, "RIGHT", -2, 0)
    close_btn:SetScript("OnClick", function()
        HistoryUI:Hide()
    end)
    
    -- Make draggable
    titlebar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    titlebar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        HistoryUI.config.x = frame:GetLeft()
        HistoryUI.config.y = -frame:GetTop()
    end)
    
    -- Info section
    local info_frame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    info_frame:SetSize(self.config.width - 10, 60)
    info_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -35)
    info_frame:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
    info_frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    
    frame.info = {}
    
    -- Player name
    frame.info.name = info_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.info.name:SetPoint("TOPLEFT", info_frame, "TOPLEFT", 8, -8)
    frame.info.name:SetText("Player: Unknown")
    
    -- Current balance
    frame.info.balance = info_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.info.balance:SetPoint("TOPLEFT", info_frame, "TOPLEFT", 8, -25)
    frame.info.balance:SetText("Balance: 0")
    
    -- Earned this week
    frame.info.earned_week = info_frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    frame.info.earned_week:SetPoint("TOPRIGHT", info_frame, "TOPRIGHT", -8, -8)
    frame.info.earned_week:SetText("Week: +0")
    
    -- Spent this week
    frame.info.spent_week = info_frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    frame.info.spent_week:SetPoint("TOPRIGHT", info_frame, "TOPRIGHT", -8, -25)
    frame.info.spent_week:SetText("Spent: -0")
    
    -- Scroll frame for history
    local scroll = CreateFrame("ScrollFrame", "InfinityPlayerHistoryScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetSize(self.config.width - 25, self.config.height - 120)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -105)
    
    local content = CreateFrame("Frame", nil, scroll, BackdropTemplateMixin and "BackdropTemplate" or nil)
    content:SetSize(self.config.width - 40, 10)
    scroll:SetScrollChild(content)
    
    frame.scroll = scroll
    frame.content = content
    frame:Hide()
    
    self.frame = frame
end

function HistoryUI:GetPlayerBalance(player_name)
    if not InfinityDKP or not InfinityDKP.db or not InfinityDKP.db.players then
        return 0
    end
    
    local player_data = InfinityDKP.db.players[player_name]
    if not player_data then
        return 0
    end
    
    return player_data.balance or 0
end

function HistoryUI:GetPlayerTransactions(player_name, limit)
    limit = limit or 100
    
    if not InfinityDKP or not InfinityDKP.db or not InfinityDKP.db.transactions then
        return {}
    end
    
    local transactions = {}
    local count = 0
    
    -- Iterate in reverse order (most recent first)
    for i = #InfinityDKP.db.transactions, 1, -1 do
        local tx = InfinityDKP.db.transactions[i]
        
        if tx.player == player_name then
            table.insert(transactions, tx)
            count = count + 1
            
            if count >= limit then
                break
            end
        end
    end
    
    return transactions
end

function HistoryUI:RefreshInfo()
    if not self.frame or not self.current_player then
        return
    end
    
    local player = self.current_player
    local balance = self:GetPlayerBalance(player)
    
    self.frame.title:SetText("DKP History - " .. player)
    self.frame.info.name:SetText("Player: " .. player)
    
    -- Color based on balance
    local balance_color = "|cffffffff"
    if balance > 1000 then
        balance_color = "|cff00ff00" -- Green
    elseif balance < 0 then
        balance_color = "|cffff0000" -- Red
    end
    
    self.frame.info.balance:SetText(balance_color .. "Balance: " .. tostring(balance) .. "|r")
    
    -- Calculate week earned/spent
    local now = GetServerTime()
    local week_start = now - ((now % 604800)) -- Seconds in week
    
    local earned_week = 0
    local spent_week = 0
    
    local transactions = self:GetPlayerTransactions(player, 1000)
    for _, tx in ipairs(transactions) do
        if tx.timestamp and tx.timestamp > week_start then
            if tx.amount > 0 then
                earned_week = earned_week + tx.amount
            else
                spent_week = spent_week - tx.amount
            end
        end
    end
    
    self.frame.info.earned_week:SetText("|cff00ff00Week: +" .. tostring(earned_week) .. "|r")
    self.frame.info.spent_week:SetText("|cffff0000Spent: -" .. tostring(spent_week) .. "|r")
end

function HistoryUI:Refresh()
    if not self.frame or not self.current_player then
        return
    end
    
    self:RefreshInfo()
    
    local transactions = self:GetPlayerTransactions(self.current_player, 50)
    local content = self.frame.content
    
    -- Clear existing
    for i = #content, 1, -1 do
        content[i]:Hide()
    end
    
    local y_offset = 0
    
    for idx, tx in ipairs(transactions) do
        local row = content[idx]
        if not row then
            row = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
            row:SetSize(content:GetWidth(), 20)
            content[idx] = row
        end
        
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y_offset)
        row:Show()
        
        -- Date/time
        local date_str = row:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        date_str:SetWidth(100)
        date_str:SetText(date("%m/%d %H:%M", tx.timestamp or 0))
        date_str:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
        date_str:SetTextColor(0.7, 0.7, 0.7, 1)
        
        -- Amount
        local amount_str = row:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        amount_str:SetWidth(60)
        
        local color
        if tx.amount > 0 then
            amount_str:SetText("+" .. tostring(tx.amount))
            color = { 0.3, 1, 0.3 }
        else
            amount_str:SetText(tostring(tx.amount))
            color = { 1, 0.3, 0.3 }
        end
        
        amount_str:SetPoint("TOPLEFT", row, "TOPLEFT", 110, 0)
        amount_str:SetTextColor(color[1], color[2], color[3], 1)
        
        -- Reason/description
        local reason_str = row:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        reason_str:SetWidth(250)
        reason_str:SetText(tx.reason or "Unknown")
        reason_str:SetPoint("TOPLEFT", row, "TOPLEFT", 180, 0)
        reason_str:SetTextColor(1, 1, 1, 0.8)
        
        -- Balance after
        local balance_after_str = row:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        balance_after_str:SetWidth(60)
        balance_after_str:SetText("→ " .. tostring(tx.balance_after or 0))
        balance_after_str:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, 0)
        balance_after_str:SetTextColor(0.5, 0.7, 1, 1)
        
        y_offset = y_offset + 22
    end
    
    -- Update scroll child height
    content:SetHeight(math.max(#transactions * 22, 10))
end

function HistoryUI:ShowPlayer(player_name)
    if not player_name then
        return
    end
    
    if not self.frame then
        self:CreateFrame()
    end
    
    self.current_player = player_name
    self.visible = true
    self.frame:Show()
    self:Refresh()
end

function HistoryUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self.visible = false
end

function HistoryUI:Toggle()
    if self.visible then
        self:Hide()
    else
        self:ShowPlayer(UnitName("player"))
    end
end

-- Register slash command
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("dkphistory", function(args)
        if args == "toggle" then
            HistoryUI:Toggle()
        elseif args == "show" then
            local player = UnitName("player")
            HistoryUI:ShowPlayer(player)
        elseif args ~= "" then
            HistoryUI:ShowPlayer(args)
        else
            HistoryUI:Toggle()
        end
    end, "Show DKP history for a player")
end

return InfinityDKP.PlayerHistoryUI
