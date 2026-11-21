-- RaidFrameEngine.lua - Core raid frame rendering engine
-- Part of InfinityHealer addon suite
-- Provides foundational frame management and rendering for raid/party display

local RaidFrameEngine = {}
RaidFrameEngine.enabled = false
RaidFrameEngine.db = nil
RaidFrameEngine.frames = {}
RaidFrameEngine.framePool = {}
RaidFrameEngine.groups = {}

-- Configuration
RaidFrameEngine.config = {
    enabled = true,
    frame_width = 100,
    frame_height = 50,
    group_spacing = 5,
    frame_spacing = 2,
    max_frames = 40,
    layout_mode = "raid", -- raid, party, solo
    groups_per_row = 5,
    frames_per_group = 8,
    show_names = true,
    show_health = true,
    show_mana = true,
    update_interval = 0.1,
    combat_throttle = 0.5, -- Slower updates in combat
}

function RaidFrameEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    self.enabled = true
    
    -- Create parent frame container
    self:CreateFrameContainer()
    
    -- Register for events
    InfinityCore.Events:RegisterListener("raid_start", function()
        self:OnRaidStart()
    end)
    
    InfinityCore.Events:RegisterListener("raid_end", function()
        self:OnRaidEnd()
    end)
    
    InfinityCore.Events:RegisterListener("group_members_changed", function()
        self:OnGroupChanged()
    end)
    
    self:Log("Initialized with layout mode: " .. self.config.layout_mode)
end

function RaidFrameEngine:CreateFrameContainer()
    if self.frameContainer then
        return
    end
    
    -- Create main container frame
    local container = CreateFrame("Frame", "InfinityRaidFrameContainer", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    container:SetWidth(self.config.frame_width * self.config.groups_per_row + 
                      (self.config.group_spacing * (self.config.groups_per_row - 1)))
    container:SetHeight(self.config.frame_height * math.ceil(self.config.max_frames / self.config.frames_per_group) + 
                       (self.config.group_spacing * math.ceil(self.config.max_frames / self.config.frames_per_group)))
    
    -- Position on screen
    container:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -100)
    
    self.frameContainer = container
    self:Log("Frame container created")
end

function RaidFrameEngine:OnRaidStart()
    if not self.enabled then
        return
    end
    
    -- Get raid members
    local raidMembers = self:GetRaidMembers()
    
    -- Layout raid members
    self:LayoutFrames(raidMembers)
    
    self:Log("Raid started with " .. #raidMembers .. " members")
end

function RaidFrameEngine:OnRaidEnd()
    if not self.enabled then
        return
    end
    
    -- Clear all frames
    self:ClearAllFrames()
    
    self:Log("Raid ended")
end

function RaidFrameEngine:OnGroupChanged()
    if not self.enabled then
        return
    end
    
    -- Refresh current layout
    local members = self:GetCurrentMembers()
    self:LayoutFrames(members)
end

function RaidFrameEngine:GetRaidMembers()
    local members = {}
    for i = 1, 40 do
        local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
        if name then
            table.insert(members, {
                name = name,
                subgroup = subgroup,
                class = fileName,
                level = level,
                online = online,
            })
        end
    end
    return members
end

function RaidFrameEngine:GetPartyMembers()
    local members = {}
    for i = 1, 5 do
        local name = UnitName("party" .. i)
        if name then
            table.insert(members, {
                name = name,
                class = select(2, UnitClass("party" .. i)),
                level = UnitLevel("party" .. i),
                online = true,
            })
        end
    end
    return members
end

function RaidFrameEngine:GetCurrentMembers()
    if IsInRaid() then
        return self:GetRaidMembers()
    else
        return self:GetPartyMembers()
    end
end

function RaidFrameEngine:LayoutFrames(members)
    if not members or #members == 0 then
        self:ClearAllFrames()
        return
    end
    
    -- Clear existing layout
    self:ClearAllFrames()
    
    -- Group members by subgroup (or by 5s for party)
    local groups = self:GroupMembers(members)
    
    -- Layout groups
    local groupIndex = 1
    local frameIndex = 1
    
    for _, group in ipairs(groups) do
        local groupFrame = self:CreateGroupFrame(groupIndex, group)
        
        for _, member in ipairs(group) do
            local memberFrame = self:CreateMemberFrame(frameIndex, member, groupFrame)
            self.frames[frameIndex] = memberFrame
            frameIndex = frameIndex + 1
        end
        
        self.groups[groupIndex] = groupFrame
        groupIndex = groupIndex + 1
    end
    
    self:Log("Laid out " .. frameIndex - 1 .. " frames in " .. groupIndex - 1 .. " groups")
end

function RaidFrameEngine:GroupMembers(members)
    local groups = {}
    
    if IsInRaid() then
        -- Group by subgroup (8 per group typically)
        local subgroups = {}
        for _, member in ipairs(members) do
            local subgroup = member.subgroup or 1
            if not subgroups[subgroup] then
                subgroups[subgroup] = {}
            end
            table.insert(subgroups[subgroup], member)
        end
        
        -- Convert to array
        for i = 1, 8 do
            if subgroups[i] then
                table.insert(groups, subgroups[i])
            end
        end
    else
        -- Party: single group of 5
        table.insert(groups, members)
    end
    
    return groups
end

function RaidFrameEngine:CreateGroupFrame(groupIndex, members)
    local groupName = "InfinityGroupFrame_" .. groupIndex
    local groupFrame = CreateFrame("Frame", groupName, self.frameContainer, BackdropTemplateMixin and "BackdropTemplate" or nil)
    
    -- Calculate group position
    local groupsPerRow = self.config.groups_per_row
    local row = math.floor((groupIndex - 1) / groupsPerRow)
    local col = math.fmod((groupIndex - 1), groupsPerRow)
    
    local x = col * (self.config.frame_width + self.config.group_spacing)
    local y = -row * (self.config.frame_height + self.config.group_spacing)
    
    groupFrame:SetPoint("TOPLEFT", self.frameContainer, "TOPLEFT", x, y)
    groupFrame:SetWidth(self.config.frame_width)
    groupFrame:SetHeight(self.config.frame_height * #members)
    
    groupFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    groupFrame:SetBackdropColor(0, 0, 0, 0.3)
    groupFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
    
    return groupFrame
end

function RaidFrameEngine:CreateMemberFrame(frameIndex, member, parentFrame)
    local frameName = "InfinityMemberFrame_" .. frameIndex
    local frame = CreateFrame("Frame", frameName, parentFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    
    frame:SetWidth(self.config.frame_width)
    frame:SetHeight(self.config.frame_height)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = true,
        tileSize = 16
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    
    -- Position in group
    local row = math.fmod((frameIndex - 1), self.config.frames_per_group)
    frame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -row * self.config.frame_height)
    
    -- Player name
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
    nameText:SetWidth(self.config.frame_width - 8)
    nameText:SetJustifyH("LEFT")
    nameText:SetText(member.name)
    
    local classColor = self:GetClassColor(member.class)
    nameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
    
    frame.nameText = nameText
    frame.member = member
    
    -- Health bar
    if self.config.show_health then
        local healthBar = CreateFrame("StatusBar", nil, frame)
        healthBar:SetWidth(self.config.frame_width - 8)
        healthBar:SetHeight(10)
        healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -18)
        healthBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
        healthBar:SetStatusBarColor(0, 1, 0, 1)
        
        frame.healthBar = healthBar
    end
    
    -- Mana bar
    if self.config.show_mana then
        local manaBar = CreateFrame("StatusBar", nil, frame)
        manaBar:SetWidth(self.config.frame_width - 8)
        manaBar:SetHeight(6)
        manaBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -30)
        manaBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
        manaBar:SetStatusBarColor(0, 0.5, 1, 1)
        
        frame.manaBar = manaBar
    end
    
    -- Click handler
    frame:SetScript("OnMouseDown", function(self, button)
        RaidFrameEngine:OnFrameClick(self, button)
    end)
    
    -- Hover effect
    frame:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.7)
    end)
    
    frame:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    end)
    
    return frame
end

function RaidFrameEngine:OnFrameClick(frame, button)
    if button == "LeftButton" then
        -- Fire event for click handlers
        InfinityCore.Events:Fire("frame_clicked", {
            player = frame.member.name,
            button = button,
        })
    end
end

function RaidFrameEngine:GetClassColor(class)
    local colors = {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
        PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
        HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
        ROGUE = { r = 1, g = 0.96, b = 0.41 },
        PRIEST = { r = 1, g = 1, b = 1 },
        DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
        SHAMAN = { r = 0, g = 0.44, b = 0.87 },
        MAGE = { r = 0.41, g = 0.80, b = 0.94 },
        WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
        MONK = { r = 0, g = 1, b = 0.60 },
        DRUID = { r = 1, g = 0.49, b = 0.04 },
        DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    }
    return colors[class] or { r = 1, g = 1, b = 1 }
end

function RaidFrameEngine:ClearAllFrames()
    for i, frame in ipairs(self.frames) do
        if frame then
            frame:Hide()
            frame:SetParent(nil)
        end
    end
    
    for i, group in ipairs(self.groups) do
        if group then
            group:Hide()
            group:SetParent(nil)
        end
    end
    
    self.frames = {}
    self.groups = {}
end

function RaidFrameEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function RaidFrameEngine:GetStatus()
    return {
        enabled = self.enabled,
        frame_count = #self.frames,
        group_count = #self.groups,
        layout_mode = self.config.layout_mode,
    }
end

function RaidFrameEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[RaidFrameEngine] " .. message)
    else
        print("[RaidFrameEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_RAIDFRAMES1 = "/raidframes"
    SlashCmdList["RAIDFRAMES"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "toggle" then
            if RaidFrameEngine.frameContainer then
                RaidFrameEngine.frameContainer:SetShown(not RaidFrameEngine.frameContainer:IsShown())
            end
        elseif cmd == "config" then
            local key, value = args:match("^(%S+)%s+(.+)$")
            if key then
                RaidFrameEngine:SetConfig(key, tonumber(value) or value)
            else
                print("Usage: /raidframes config <key> <value>")
            end
        elseif cmd == "status" then
            local status = RaidFrameEngine:GetStatus()
            print("Raid Frame Engine Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Raid Frame Engine Commands:")
            print("  /raidframes toggle - Toggle frame visibility")
            print("  /raidframes config <key> <value> - Set configuration")
            print("  /raidframes status - Show system status")
        end
    end
end

return RaidFrameEngine
