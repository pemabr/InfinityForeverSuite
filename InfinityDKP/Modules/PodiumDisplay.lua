-- PodiumDisplay.lua - Display DKP leaderboard standings
-- Part of InfinityDKP addon suite
-- Shows current player standings sorted by DKP, GP, priority (DKP/GP ratio)

local PodiumDisplay = {}
PodiumDisplay.enabled = false
PodiumDisplay.db = nil
PodiumDisplay.frame = nil
PodiumDisplay.rows = {}
PodiumDisplay.maxRows = 20
PodiumDisplay.sortOrder = {}

-- Configuration
PodiumDisplay.config = {
    enabled = true,
    max_display = 20,
    sort_by = "dkp", -- dkp, gp, priority, name
    sort_descending = true,
    update_interval = 1.0,
    position = { x = 100, y = 100 },
    width = 500,
    height = 400,
    show_gp = true,
    show_dkp = true,
    show_priority = true,
    show_class = true,
}

function PodiumDisplay:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDKP")
    if not self.db or not self.db.players then
        self:Log("No DKP database found")
        return
    end
    
    self.enabled = true
    
    -- Create UI frame
    self:CreateFrame()
    
    -- Register for events
    InfinityCore.Events:RegisterListener("dkp_awarded", function(player, amount)
        self:RefreshPodium()
    end)
    
    InfinityCore.Events:RegisterListener("gp_awarded", function(player, amount)
        self:RefreshPodium()
    end)
    
    InfinityCore.Events:RegisterListener("dkp_decayed", function()
        self:RefreshPodium()
    end)
    
    InfinityCore.Events:RegisterListener("loot_awarded", function()
        self:RefreshPodium()
    end)
    
    self:Log("Initialized")
end

function PodiumDisplay:CreateFrame()
    if self.frame then
        return
    end
    
    -- Create main frame
    local frame = CreateFrame("Frame", "InfinityPodiumDisplay", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetWidth(self.config.width)
    frame:SetHeight(self.config.height)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", self.config.position.x, -self.config.position.y)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    title:SetText("DKP Podium")
    
    -- Subtitle (sort by)
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Sorted by: " .. (self.config.sort_by or "dkp"))
    subtitle:SetTextColor(0.8, 0.8, 0.8, 1)
    self.subtitle = subtitle
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Header row
    self:CreateHeaderRow(frame)
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    
    local content = CreateFrame("Frame", nil, scrollFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    content:SetWidth(frame:GetWidth() - 16)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    
    -- Create rows
    local prevRow = nil
    for i = 1, self.config.max_display do
        local row = self:CreateRow(content, i)
        if prevRow then
            row.frame:SetPoint("TOPLEFT", prevRow.frame, "BOTTOMLEFT", 0, -2)
        else
            row.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        end
        self.rows[i] = row
        prevRow = row
    end
    
    self.frame = frame
    frame:Show()
end

function PodiumDisplay:CreateHeaderRow(parent)
    local header = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    header:SetWidth(parent:GetWidth())
    header:SetHeight(20)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -34)
    
    -- Rank
    local rankHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankHeader:SetPoint("LEFT", header, "LEFT", 0, 0)
    rankHeader:SetWidth(30)
    rankHeader:SetJustifyH("CENTER")
    rankHeader:SetText("Rank")
    rankHeader:SetTextColor(1, 1, 0, 1)
    
    -- Name
    local nameHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader:SetPoint("LEFT", rankHeader, "RIGHT", 10, 0)
    nameHeader:SetWidth(80)
    nameHeader:SetJustifyH("LEFT")
    nameHeader:SetText("Name")
    nameHeader:SetTextColor(1, 1, 0, 1)
    
    -- Class
    local classHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classHeader:SetPoint("LEFT", nameHeader, "RIGHT", 10, 0)
    classHeader:SetWidth(60)
    classHeader:SetJustifyH("CENTER")
    classHeader:SetText("Class")
    classHeader:SetTextColor(1, 1, 0, 1)
    
    -- DKP
    local dkpHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dkpHeader:SetPoint("LEFT", classHeader, "RIGHT", 10, 0)
    dkpHeader:SetWidth(60)
    dkpHeader:SetJustifyH("RIGHT")
    dkpHeader:SetText("DKP")
    dkpHeader:SetTextColor(0, 1, 0, 1)
    
    -- GP
    local gpHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gpHeader:SetPoint("LEFT", dkpHeader, "RIGHT", 10, 0)
    gpHeader:SetWidth(60)
    gpHeader:SetJustifyH("RIGHT")
    gpHeader:SetText("GP")
    gpHeader:SetTextColor(1, 0.5, 0, 1)
    
    -- Priority
    local priorityHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priorityHeader:SetPoint("LEFT", gpHeader, "RIGHT", 10, 0)
    priorityHeader:SetWidth(60)
    priorityHeader:SetJustifyH("RIGHT")
    priorityHeader:SetText("Priority")
    priorityHeader:SetTextColor(1, 1, 0, 1)
end

function PodiumDisplay:CreateRow(parent, index)
    local row = {}
    row.index = index
    
    -- Row frame
    local frame = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetWidth(parent:GetWidth())
    frame:SetHeight(20)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.3)
    
    -- Rank
    local rank = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rank:SetPoint("LEFT", frame, "LEFT", 2, 0)
    rank:SetWidth(30)
    rank:SetJustifyH("CENTER")
    row.rank = rank
    
    -- Name
    local name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT", rank, "RIGHT", 10, 0)
    name:SetWidth(80)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1, 1, 1, 1)
    row.name = name
    
    -- Class
    local class = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    class:SetPoint("LEFT", name, "RIGHT", 10, 0)
    class:SetWidth(60)
    class:SetJustifyH("CENTER")
    row.class = class
    
    -- DKP
    local dkp = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dkp:SetPoint("LEFT", class, "RIGHT", 10, 0)
    dkp:SetWidth(60)
    dkp:SetJustifyH("RIGHT")
    dkp:SetTextColor(0, 1, 0, 1)
    row.dkp = dkp
    
    -- GP
    local gp = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gp:SetPoint("LEFT", dkp, "RIGHT", 10, 0)
    gp:SetWidth(60)
    gp:SetJustifyH("RIGHT")
    gp:SetTextColor(1, 0.5, 0, 1)
    row.gp = gp
    
    -- Priority (DKP/GP ratio)
    local priority = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    priority:SetPoint("LEFT", gp, "RIGHT", 10, 0)
    priority:SetWidth(60)
    priority:SetJustifyH("RIGHT")
    priority:SetTextColor(1, 1, 0, 1)
    row.priority = priority
    
    -- Hover effect
    frame:SetScript("OnEnter", function()
        frame:SetBackdropColor(0.2, 0.2, 0.3, 0.5)
    end)
    
    frame:SetScript("OnLeave", function()
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.3)
    end)
    
    row.frame = frame
    return row
end

function PodiumDisplay:RefreshPodium()
    if not self.enabled or not self.frame or not self.db then
        return
    end
    
    -- Get all players
    local players = self.db.players or {}
    self.sortOrder = {}
    
    -- Sort players
    for playerName, playerData in pairs(players) do
        table.insert(self.sortOrder, {
            name = playerName,
            dkp = playerData.dkp or 0,
            gp = playerData.gp or 0,
            class = playerData.class or "Unknown",
            priority = self:CalculatePriority(playerData.dkp or 0, playerData.gp or 0),
        })
    end
    
    -- Sort by selected criteria
    table.sort(self.sortOrder, function(a, b)
        local sortBy = self.config.sort_by or "dkp"
        local aVal = a[sortBy] or 0
        local bVal = b[sortBy] or 0
        
        if self.config.sort_descending then
            return aVal > bVal
        else
            return aVal < bVal
        end
    end)
    
    -- Update rows
    for i = 1, self.config.max_display do
        local playerData = self.sortOrder[i]
        local row = self.rows[i]
        
        if playerData then
            self:UpdateRow(row, playerData, i)
            row.frame:Show()
        else
            row.frame:Hide()
        end
    end
    
    -- Update subtitle
    if self.subtitle then
        self.subtitle:SetText("Sorted by: " .. (self.config.sort_by or "dkp") .. " (" .. tostring(#self.sortOrder) .. " players)")
    end
end

function PodiumDisplay:UpdateRow(row, playerData, rank)
    if not playerData then
        row.frame:Hide()
        return
    end
    
    -- Rank
    row.rank:SetText(tostring(rank))
    
    -- Name
    row.name:SetText(playerData.name)
    
    -- Class
    local classColor = self:GetClassColor(playerData.class)
    row.class:SetText(playerData.class)
    row.class:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
    
    -- DKP
    row.dkp:SetText(math.floor(playerData.dkp or 0))
    
    -- GP
    row.gp:SetText(math.floor(playerData.gp or 0))
    
    -- Priority (DKP/GP ratio)
    local priority = playerData.priority or 0
    if priority > 2 then
        row.priority:SetTextColor(1, 0, 0, 1) -- Red: very high priority
    elseif priority > 1 then
        row.priority:SetTextColor(1, 1, 0, 1) -- Yellow: high priority
    elseif priority > 0.5 then
        row.priority:SetTextColor(1, 0.5, 0, 1) -- Orange: medium priority
    else
        row.priority:SetTextColor(0, 1, 0, 1) -- Green: low priority
    end
    
    row.priority:SetText(string.format("%.2f", priority))
end

function PodiumDisplay:CalculatePriority(dkp, gp)
    if gp == 0 then
        return dkp > 0 and 999 or 0
    end
    return dkp / gp
end

function PodiumDisplay:GetClassColor(class)
    local classColors = {
        ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43 },
        ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73 },
        ["HUNTER"] = { r = 0.67, g = 0.83, b = 0.45 },
        ["ROGUE"] = { r = 1, g = 0.96, b = 0.41 },
        ["PRIEST"] = { r = 1, g = 1, b = 1 },
        ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
        ["SHAMAN"] = { r = 0, g = 0.44, b = 0.87 },
        ["MAGE"] = { r = 0.41, g = 0.80, b = 0.94 },
        ["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79 },
        ["MONK"] = { r = 0, g = 1, b = 0.60 },
        ["DRUID"] = { r = 1, g = 0.49, b = 0.04 },
        ["DEMONHUNTER"] = { r = 0.64, g = 0.19, b = 0.79 },
    }
    return classColors[class] or { r = 1, g = 1, b = 1 }
end

function PodiumDisplay:SetSortBy(sortBy)
    if sortBy == "dkp" or sortBy == "gp" or sortBy == "priority" or sortBy == "name" then
        self.config.sort_by = sortBy
        self:RefreshPodium()
        self:Log("Sort order changed to: " .. sortBy)
        return true
    end
    return false
end

function PodiumDisplay:ToggleSortOrder()
    self.config.sort_descending = not self.config.sort_descending
    self:RefreshPodium()
    self:Log("Sort order: " .. (self.config.sort_descending and "descending" or "ascending"))
end

function PodiumDisplay:Toggle()
    if self.frame then
        self.frame:SetShown(not self.frame:IsShown())
    end
end

function PodiumDisplay:Show()
    if self.frame then
        self.frame:Show()
    end
end

function PodiumDisplay:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function PodiumDisplay:GetStatus()
    return {
        enabled = self.enabled,
        frame_visible = self.frame and self.frame:IsShown() or false,
        total_players = #self.sortOrder,
        sort_by = self.config.sort_by,
        sort_descending = self.config.sort_descending,
    }
end

function PodiumDisplay:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[PodiumDisplay] " .. message)
    else
        print("[PodiumDisplay] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_PODIUM1 = "/podium"
    SlashCmdList["PODIUM"] = function(msg)
        if not PodiumDisplay.enabled then
            local ui = _G.InfinityDKPUI
            if ui and type(ui.Show) == "function" and (msg == "" or msg == "show" or msg == "toggle") then
                ui.selectedTab = "Players"
                if (msg == "" or msg == "toggle") and type(ui.Toggle) == "function" then ui:Toggle()
                else ui:Show() end
            elseif ui and msg == "hide" and type(ui.Hide) == "function" then
                ui:Hide()
            else
                InfinityUtils:Warning("Legacy podium is unavailable. Use the DKP Players tab for standings.", "DKP")
            end
            return
        end
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "" or cmd == "toggle" then
            PodiumDisplay:Toggle()
        elseif cmd == "show" then
            PodiumDisplay:Show()
        elseif cmd == "hide" then
            PodiumDisplay:Hide()
        elseif cmd == "sort" then
            if args and args ~= "" then
                PodiumDisplay:SetSortBy(args:lower())
            else
                print("Usage: /podium sort [dkp|gp|priority|name]")
            end
        elseif cmd == "reverse" then
            PodiumDisplay:ToggleSortOrder()
        elseif cmd == "status" then
            local status = PodiumDisplay:GetStatus()
            print("Podium Display Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Podium Display Commands:")
            print("  /podium toggle - Toggle display visibility")
            print("  /podium show - Show display")
            print("  /podium hide - Hide display")
            print("  /podium sort [dkp|gp|priority|name] - Sort by criteria")
            print("  /podium reverse - Reverse sort order")
            print("  /podium status - Show current status")
        end
    end
end

return PodiumDisplay
