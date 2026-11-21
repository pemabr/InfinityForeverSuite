-- ScrollableRaidFrameManager.lua - Manage raid-wide scrollable frame grouping
-- Part of InfinityHealer addon suite
-- Render all 40 raid members with scroll-based rendering for efficiency

local ScrollableRaidFrameManager = {}
ScrollableRaidFrameManager.enabled = false
ScrollableRaidFrameManager.db = nil
ScrollableRaidFrameManager.scroll_offset = 0
ScrollableRaidFrameManager.visible_frames = {}
ScrollableRaidFrameManager.all_frames = {}

-- Configuration
ScrollableRaidFrameManager.config = {
    enabled = true,
    max_visible_rows = 8,
    frames_per_row = 5,
    frame_width = 100,
    frame_height = 50,
    enable_scrolling = true,
    update_interval = 0.5,
    enable_search = true,
    enable_filtering = true,
}

function ScrollableRaidFrameManager:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.raid_frames then
        self.db.raid_frames = {}
    end
    
    self.enabled = true
    
    -- Create parent frame
    if not self.parent_frame then
        self.parent_frame = CreateFrame("Frame", "InfinityRaidFramesScroll", UIParent)
        self.parent_frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
        self.parent_frame:SetSize(600, 500)
        self.parent_frame:EnableMouse(true)
        
        -- Create border
        self.parent_frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 16,
        })
        self.parent_frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
        self.parent_frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        
        -- Add title
        local title = self.parent_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", self.parent_frame, "TOPLEFT", 10, -10)
        title:SetText("Raid Frames")
    end
    
    -- Register for events
    InfinityCore.Events:RegisterListener("raid_joined", function(data)
        self:OnRaidJoined(data)
    end)
    
    InfinityCore.Events:RegisterListener("raid_left", function(data)
        self:OnRaidLeft()
    end)
    
    self:Log("Initialized")
end

function ScrollableRaidFrameManager:OnRaidJoined(data)
    if not self.enabled then
        return
    end
    
    -- Create frames for all raid members
    self:CreateRaidFrames(data.raid_size or 40)
    
    self:Log("Raid joined: " .. (data.raid_size or 40) .. " members")
end

function ScrollableRaidFrameManager:OnRaidLeft()
    self:DestroyRaidFrames()
    self:Log("Raid left")
end

function ScrollableRaidFrameManager:CreateRaidFrames(raidSize)
    -- Create frames for each raid member
    for i = 1, math.min(raidSize, 40) do
        local frameData = self:CreateFrameForMember(i)
        table.insert(self.all_frames, frameData)
    end
    
    -- Render visible frames
    self:RenderVisibleFrames()
end

function ScrollableRaidFrameManager:CreateFrameForMember(memberIndex)
    local unitID = "raid" .. memberIndex
    
    -- Create frame
    local frame = CreateFrame("Button", "InfinityRaidFrame" .. memberIndex, self.parent_frame)
    frame:SetSize(self.config.frame_width, self.config.frame_height)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Player name
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    nameText:SetSize(94, 15)
    nameText:SetJustifyH("LEFT")
    
    -- Health bar
    local healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -18)
    healthBar:SetSize(94, 10)
    healthBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    healthBar:SetStatusBarColor(0, 0.8, 0)
    
    -- Health text
    local healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    healthText:SetSize(90, 10)
    healthText:SetJustifyH("CENTER")
    healthText:SetTextColor(1, 1, 1, 0.8)
    
    local frameData = {
        frame = frame,
        unit = unitID,
        member_index = memberIndex,
        name_text = nameText,
        health_bar = healthBar,
        health_text = healthText,
        visible = false,
    }
    
    return frameData
end

function ScrollableRaidFrameManager:RenderVisibleFrames()
    -- Calculate visible range
    local startIndex = self.scroll_offset + 1
    local endIndex = startIndex + (self.config.max_visible_rows * self.config.frames_per_row) - 1
    
    -- Hide all frames
    for _, frameData in ipairs(self.all_frames) do
        frameData.frame:Hide()
        frameData.visible = false
    end
    
    -- Show visible frames
    local displayIndex = 1
    for i = startIndex, math.min(endIndex, #self.all_frames) do
        local frameData = self.all_frames[i]
        
        -- Calculate position
        local row = math.floor((displayIndex - 1) / self.config.frames_per_row)
        local col = (displayIndex - 1) % self.config.frames_per_row
        
        local offsetX = col * (self.config.frame_width + 2)
        local offsetY = -40 - (row * (self.config.frame_height + 2))
        
        frameData.frame:SetPoint("TOPLEFT", self.parent_frame, "TOPLEFT", offsetX + 10, offsetY)
        frameData.frame:Show()
        frameData.visible = true
        
        self:UpdateFrame(frameData)
        
        displayIndex = displayIndex + 1
    end
    
    self:Log("Rendered " .. (displayIndex - 1) .. " frames (offset: " .. self.scroll_offset .. ")")
end

function ScrollableRaidFrameManager:UpdateFrame(frameData)
    if not frameData.visible then
        return
    end
    
    local unit = frameData.unit
    
    if not UnitExists(unit) then
        frameData.frame:Hide()
        frameData.visible = false
        return
    end
    
    -- Update name
    local name = UnitName(unit)
    frameData.name_text:SetText(name or "Unknown")
    
    -- Update health
    local health = UnitHealth(unit)
    local maxHealth = UnitHealthMax(unit)
    
    if maxHealth > 0 then
        frameData.health_bar:SetValue(health / maxHealth * 100)
        frameData.health_text:SetText(math.floor(health / 100) .. "h")
    end
    
    -- Fade dead players
    if UnitIsDead(unit) then
        frameData.frame:SetAlpha(0.3)
    else
        frameData.frame:SetAlpha(1)
    end
end

function ScrollableRaidFrameManager:ScrollUp()
    if self.scroll_offset > 0 then
        self.scroll_offset = self.scroll_offset - self.config.frames_per_row
        self:RenderVisibleFrames()
    end
end

function ScrollableRaidFrameManager:ScrollDown()
    local maxOffset = math.max(0, #self.all_frames - (self.config.max_visible_rows * self.config.frames_per_row))
    
    if self.scroll_offset < maxOffset then
        self.scroll_offset = self.scroll_offset + self.config.frames_per_row
        self:RenderVisibleFrames()
    end
end

function ScrollableRaidFrameManager:SetScrollOffset(offset)
    local maxOffset = math.max(0, #self.all_frames - (self.config.max_visible_rows * self.config.frames_per_row))
    
    self.scroll_offset = math.min(math.max(0, offset), maxOffset)
    self:RenderVisibleFrames()
end

function ScrollableRaidFrameManager:DestroyRaidFrames()
    for _, frameData in ipairs(self.all_frames) do
        frameData.frame:Hide()
        frameData.frame = nil
    end
    
    self.all_frames = {}
    self.scroll_offset = 0
    
    self:Log("Raid frames destroyed")
end

function ScrollableRaidFrameManager:RefreshAll()
    for _, frameData in ipairs(self.all_frames) do
        if frameData.visible then
            self:UpdateFrame(frameData)
        end
    end
end

function ScrollableRaidFrameManager:GetFrameInfo()
    return {
        total_frames = #self.all_frames,
        visible_frames = self:CountVisibleFrames(),
        scroll_offset = self.scroll_offset,
        frames_per_row = self.config.frames_per_row,
        max_visible_rows = self.config.max_visible_rows,
    }
end

function ScrollableRaidFrameManager:CountVisibleFrames()
    local count = 0
    for _, frameData in ipairs(self.all_frames) do
        if frameData.visible then
            count = count + 1
        end
    end
    return count
end

function ScrollableRaidFrameManager:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:RenderVisibleFrames()
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function ScrollableRaidFrameManager:GetStatus()
    return {
        enabled = self.enabled,
        total_members = #self.all_frames,
        visible_frames = self:CountVisibleFrames(),
        scroll_offset = self.scroll_offset,
    }
end

function ScrollableRaidFrameManager:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[ScrollableRaidFrameManager] " .. message)
    else
        print("[ScrollableRaidFrameManager] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_RAIDSCROLL1 = "/raidscroll"
    SlashCmdList["RAIDSCROLL"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "up" then
            ScrollableRaidFrameManager:ScrollUp()
            print("Scrolled up")
        elseif cmd == "down" then
            ScrollableRaidFrameManager:ScrollDown()
            print("Scrolled down")
        elseif cmd == "scroll" then
            if args and args ~= "" then
                local offset = tonumber(args)
                if offset then
                    ScrollableRaidFrameManager:SetScrollOffset(offset)
                    print("Scroll offset: " .. offset)
                end
            else
                print("Usage: /raidscroll scroll <offset>")
            end
        elseif cmd == "status" then
            local status = ScrollableRaidFrameManager:GetStatus()
            print("Raid Scroll Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "info" then
            local info = ScrollableRaidFrameManager:GetFrameInfo()
            print("Raid Frame Info:")
            for k, v in pairs(info) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Raid Scroll Commands:")
            print("  /raidscroll up - Scroll up")
            print("  /raidscroll down - Scroll down")
            print("  /raidscroll scroll <offset> - Set scroll offset")
            print("  /raidscroll status - Show status")
            print("  /raidscroll info - Show frame info")
        end
    end
end

return ScrollableRaidFrameManager
