-- GroupLayoutEngine.lua - Group-based frame layout management
-- Part of InfinityHealer addon suite
-- Manages frame positioning and layout for different raid compositions

local GroupLayoutEngine = {}
GroupLayoutEngine.enabled = false
GroupLayoutEngine.db = nil
GroupLayoutEngine.layouts = {}
GroupLayoutEngine.current_layout = "compact"

-- Predefined layouts
GroupLayoutEngine.LAYOUT_TEMPLATES = {
    compact = {
        name = "Compact",
        groups_per_row = 5,
        members_per_group = 8,
        frame_width = 100,
        frame_height = 50,
        group_spacing = 10,
        member_spacing = 5,
    },
    standard = {
        name = "Standard",
        groups_per_row = 2,
        members_per_group = 8,
        frame_width = 150,
        frame_height = 60,
        group_spacing = 15,
        member_spacing = 8,
    },
    spacious = {
        name = "Spacious",
        groups_per_row = 1,
        members_per_group = 8,
        frame_width = 200,
        frame_height = 70,
        group_spacing = 20,
        member_spacing = 10,
    },
    balanced = {
        name = "Balanced",
        groups_per_row = 4,
        members_per_group = 10,
        frame_width = 120,
        frame_height = 55,
        group_spacing = 12,
        member_spacing = 6,
    },
    minimal = {
        name = "Minimal",
        groups_per_row = 10,
        members_per_group = 4,
        frame_width = 80,
        frame_height = 40,
        group_spacing = 5,
        member_spacing = 3,
    },
}

-- Configuration
GroupLayoutEngine.config = {
    enabled = true,
    layout = "standard",
    allow_custom_layouts = true,
    lock_frames = false,
    auto_adjust = true,
    update_on_party_change = true,
}

function GroupLayoutEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.layouts then
        self.db.layouts = {}
    end
    
    self.layouts = self.db.layouts
    self.enabled = true
    
    -- Register for events
    InfinityCore.Events:RegisterListener("raid_joined", function(data)
        self:OnRaidJoined(data)
    end)
    
    InfinityCore.Events:RegisterListener("party_changed", function(data)
        self:OnPartyChanged(data)
    end)
    
    self:Log("Initialized with " .. self:CountLayouts() .. " custom layouts")
end

function GroupLayoutEngine:OnRaidJoined(data)
    if self.config.auto_adjust then
        self:AutoSelectLayout(data.raid_size or 40)
    end
end

function GroupLayoutEngine:OnPartyChanged(data)
    if self.config.update_on_party_change then
        self:RefreshLayout()
    end
end

function GroupLayoutEngine:CalculateLayout(raidSize)
    local layout = self:GetLayout(self.config.layout)
    
    if not layout then
        layout = self.LAYOUT_TEMPLATES.standard
    end
    
    -- Calculate grid dimensions
    local groupsPerRow = layout.groups_per_row
    local groups = math.ceil(raidSize / 8)
    local rows = math.ceil(groups / groupsPerRow)
    
    return {
        layout = self.config.layout,
        raid_size = raidSize,
        groups = groups,
        groups_per_row = groupsPerRow,
        rows = rows,
        frame_width = layout.frame_width,
        frame_height = layout.frame_height,
        group_spacing = layout.group_spacing,
        member_spacing = layout.member_spacing,
    }
end

function GroupLayoutEngine:GetLayout(layoutName)
    -- Check custom layouts first
    if self.layouts[layoutName] then
        return self.layouts[layoutName]
    end
    
    -- Check built-in templates
    return self.LAYOUT_TEMPLATES[layoutName]
end

function GroupLayoutEngine:SetLayout(layoutName)
    local layout = self:GetLayout(layoutName)
    
    if not layout then
        self:Log("Layout not found: " .. layoutName)
        return false
    end
    
    self.config.layout = layoutName
    self.current_layout = layoutName
    
    self:Log("Layout changed to: " .. layoutName)
    
    return true
end

function GroupLayoutEngine:CalculateFramePosition(groupIndex, memberIndex, layout)
    -- Calculate group position
    local groupsPerRow = layout.groups_per_row
    local groupRow = math.floor((groupIndex - 1) / groupsPerRow)
    local groupCol = (groupIndex - 1) % groupsPerRow
    
    -- Group position
    local groupX = groupCol * (layout.frame_width * 8 + layout.group_spacing)
    local groupY = -groupRow * (layout.frame_height + layout.member_spacing + layout.group_spacing)
    
    -- Member position within group
    local memberRow = math.floor((memberIndex - 1) / 8)
    local memberCol = (memberIndex - 1) % 8
    
    local memberX = groupX + (memberCol * (layout.frame_width + layout.member_spacing))
    local memberY = groupY + (memberRow * (layout.frame_height + layout.member_spacing))
    
    return {
        x = memberX,
        y = memberY,
        width = layout.frame_width,
        height = layout.frame_height,
    }
end

function GroupLayoutEngine:AutoSelectLayout(raidSize)
    local recommendedLayout
    
    if raidSize == 0 then
        recommendedLayout = "compact"
    elseif raidSize <= 5 then
        recommendedLayout = "minimal"
    elseif raidSize <= 10 then
        recommendedLayout = "spacious"
    elseif raidSize <= 20 then
        recommendedLayout = "balanced"
    else
        recommendedLayout = "compact"
    end
    
    if recommendedLayout ~= self.current_layout then
        self:SetLayout(recommendedLayout)
    end
end

function GroupLayoutEngine:CreateCustomLayout(name, layoutConfig)
    if not name or not layoutConfig then
        return false
    end
    
    -- Validate layout config
    if not layoutConfig.frame_width or not layoutConfig.frame_height or
       not layoutConfig.groups_per_row or not layoutConfig.member_spacing then
        self:Log("Invalid layout configuration")
        return false
    end
    
    self.layouts[name] = layoutConfig
    
    self:Log("Custom layout created: " .. name)
    
    return true
end

function GroupLayoutEngine:DeleteCustomLayout(name)
    if not name or not self.layouts[name] then
        return false
    end
    
    self.layouts[name] = nil
    
    self:Log("Custom layout deleted: " .. name)
    
    return true
end

function GroupLayoutEngine:RefreshLayout()
    -- Get current raid/party size
    local raidSize = GetNumRaidMembers()
    if raidSize == 0 then
        raidSize = GetNumPartyMembers()
        if raidSize == 0 then
            raidSize = 1  -- Solo
        end
    end
    
    -- Recalculate layout
    local layout = self:CalculateLayout(raidSize)
    
    self:Log("Layout refreshed for " .. raidSize .. " players")
    
    return layout
end

function GroupLayoutEngine:GetLayoutInfo()
    local layout = self:GetLayout(self.config.layout)
    
    if not layout then
        return nil
    end
    
    return {
        name = layout.name or self.config.layout,
        frame_width = layout.frame_width,
        frame_height = layout.frame_height,
        groups_per_row = layout.groups_per_row,
        members_per_group = layout.members_per_group or 8,
        member_spacing = layout.member_spacing,
        group_spacing = layout.group_spacing,
    }
end

function GroupLayoutEngine:ListLayouts()
    local layouts = {}
    
    -- Add built-in layouts
    for name, layout in pairs(self.LAYOUT_TEMPLATES) do
        table.insert(layouts, {
            name = name,
            type = "built-in",
            groups_per_row = layout.groups_per_row,
        })
    end
    
    -- Add custom layouts
    for name, layout in pairs(self.layouts) do
        table.insert(layouts, {
            name = name,
            type = "custom",
            groups_per_row = layout.groups_per_row,
        })
    end
    
    return layouts
end

function GroupLayoutEngine:CountLayouts()
    local count = 0
    for _ in pairs(self.layouts) do
        count = count + 1
    end
    return count
end

function GroupLayoutEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function GroupLayoutEngine:GetStatus()
    local customLayouts = self:CountLayouts()
    local builtInCount = 0
    for _ in pairs(self.LAYOUT_TEMPLATES) do
        builtInCount = builtInCount + 1
    end
    
    return {
        enabled = self.enabled,
        current_layout = self.current_layout,
        custom_layouts = customLayouts,
        builtin_layouts = builtInCount,
        total_layouts = customLayouts + builtInCount,
    }
end

function GroupLayoutEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[GroupLayoutEngine] " .. message)
    else
        print("[GroupLayoutEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GRPLAYOUT1 = "/grplayout"
    SlashCmdList["GRPLAYOUT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local layouts = GroupLayoutEngine:ListLayouts()
            print("Available Layouts (" .. #layouts .. "):")
            for _, layout in ipairs(layouts) do
                print(string.format("  %s (%s): %d groups per row", 
                    layout.name, layout.type, layout.groups_per_row))
            end
        elseif cmd == "set" then
            if args and args ~= "" then
                if GroupLayoutEngine:SetLayout(args) then
                    print("Layout changed to: " .. args)
                else
                    print("Layout not found: " .. args)
                end
            else
                print("Usage: /grplayout set <layout>")
            end
        elseif cmd == "current" then
            local info = GroupLayoutEngine:GetLayoutInfo()
            if info then
                print("Current Layout (" .. GroupLayoutEngine.current_layout .. "):")
                for k, v in pairs(info) do
                    print("  " .. k .. ": " .. tostring(v))
                end
            end
        elseif cmd == "status" then
            local status = GroupLayoutEngine:GetStatus()
            print("Group Layout Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Group Layout Commands:")
            print("  /grplayout list - List all layouts")
            print("  /grplayout set <layout> - Change layout")
            print("  /grplayout current - Show current layout info")
            print("  /grplayout status - Show system status")
        end
    end
end

return GroupLayoutEngine
