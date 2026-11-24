-- LayoutTemplateEngine.lua - Pre-built raid frame layout templates
-- Part of PluribusHealer addon suite
-- Manages different layout arrangements (compact, standard, spacious, etc.)

local LayoutTemplateEngine = {}
LayoutTemplateEngine.enabled = false
LayoutTemplateEngine.db = nil
LayoutTemplateEngine.current_layout = "auto"
LayoutTemplateEngine.layouts = {}

-- Define built-in layout templates
LayoutTemplateEngine.layout_definitions = {
    compact = {
        name = "Compact",
        description = "5 groups per row (40-man raids)",
        groups_per_row = 5,
        frame_width = 50,
        frame_height = 25,
        group_spacing = 5,
        row_spacing = 5,
        optimal_raid_size = 40,
        scale = 0.8,
    },
    standard = {
        name = "Standard",
        description = "2 groups per row (balanced spacing)",
        groups_per_row = 2,
        frame_width = 100,
        frame_height = 30,
        group_spacing = 10,
        row_spacing = 10,
        optimal_raid_size = 25,
        scale = 1.0,
    },
    spacious = {
        name = "Spacious",
        description = "1 group per row (maximum visibility)",
        groups_per_row = 1,
        frame_width = 150,
        frame_height = 35,
        group_spacing = 15,
        row_spacing = 15,
        optimal_raid_size = 10,
        scale = 1.2,
    },
    balanced = {
        name = "Balanced",
        description = "4 groups per row (raid variety)",
        groups_per_row = 4,
        frame_width = 75,
        frame_height = 28,
        group_spacing = 8,
        row_spacing = 8,
        optimal_raid_size = 20,
        scale = 0.9,
    },
    minimal = {
        name = "Minimal",
        description = "10 groups per row (ultra-compact)",
        groups_per_row = 10,
        frame_width = 40,
        frame_height = 20,
        group_spacing = 2,
        row_spacing = 2,
        optimal_raid_size = 50,
        scale = 0.6,
    },
}

function LayoutTemplateEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.layouts then
        self.db.layouts = {}
    end
    
    if not self.db.current_layout then
        self.db.current_layout = "auto"
    end
    
    self.layouts = self.db.layouts
    self.current_layout = self.db.current_layout or "auto"
    self.enabled = true
    
    self:Log("Initialized with layout: " .. self.current_layout)
end

function LayoutTemplateEngine:GetLayout(layoutName)
    if not layoutName or layoutName == "auto" then
        -- Auto-select based on raid size
        return self:GetAutoLayout()
    end
    
    -- Check custom layouts first
    if self.layouts[layoutName] then
        return self.layouts[layoutName]
    end
    
    -- Fall back to built-in layouts
    if self.layout_definitions[layoutName] then
        return self.layout_definitions[layoutName]
    end
    
    -- Default fallback
    return self.layout_definitions["standard"]
end

function LayoutTemplateEngine:GetAutoLayout()
    local raidSize = GetNumGroupMembers()
    
    if raidSize >= 40 then
        return self.layout_definitions["compact"]
    elseif raidSize >= 20 then
        return self.layout_definitions["balanced"]
    elseif raidSize >= 10 then
        return self.layout_definitions["spacious"]
    elseif raidSize >= 5 then
        return self.layout_definitions["standard"]
    else
        return self.layout_definitions["compact"]
    end
end

function LayoutTemplateEngine:GetRaidSizeForLayout(layoutName)
    local layout = self:GetLayout(layoutName)
    if not layout then
        return 0
    end
    
    return layout.optimal_raid_size
end

function LayoutTemplateEngine:SetLayout(layoutName)
    if not layoutName then
        return false
    end
    
    if layoutName == "auto" then
        self.current_layout = "auto"
        self.db.current_layout = "auto"
        self:Log("Layout set to: auto")
        return true
    end
    
    if not self:GetLayout(layoutName) then
        self:Log("Layout not found: " .. layoutName)
        return false
    end
    
    self.current_layout = layoutName
    self.db.current_layout = layoutName
    
    self:Log("Layout changed to: " .. layoutName)
    return true
end

function LayoutTemplateEngine:CalculateFramePosition(groupIndex, frameIndex, layout)
    if not layout then
        layout = self:GetLayout()
    end
    
    if not layout then
        return nil
    end
    
    local groupsPerRow = layout.groups_per_row
    local frameWidth = layout.frame_width
    local frameHeight = layout.frame_height
    local groupSpacing = layout.group_spacing
    local rowSpacing = layout.row_spacing
    
    -- Calculate row and column
    local row = math.floor((groupIndex - 1) / groupsPerRow)
    local col = (groupIndex - 1) % groupsPerRow
    
    -- Calculate position
    local x = col * (frameWidth + groupSpacing)
    local y = row * (frameHeight + rowSpacing)
    
    return {
        x = x,
        y = y,
        width = frameWidth,
        height = frameHeight,
    }
end

function LayoutTemplateEngine:GetGroupLayout(groupIndex, layoutName)
    local layout = self:GetLayout(layoutName)
    if not layout then
        return nil
    end
    
    return self:CalculateFramePosition(groupIndex, 1, layout)
end

function LayoutTemplateEngine:CreateCustomLayout(layoutName, definition)
    if not layoutName or not definition then
        return false
    end
    
    if self.layouts[layoutName] then
        self:Log("Layout already exists: " .. layoutName)
        return false
    end
    
    self.layouts[layoutName] = definition
    self:Log("Custom layout created: " .. layoutName)
    return true
end

function LayoutTemplateEngine:DeleteCustomLayout(layoutName)
    if not layoutName then
        return false
    end
    
    if self.layout_definitions[layoutName] then
        self:Log("Cannot delete built-in layout: " .. layoutName)
        return false
    end
    
    if self.layouts[layoutName] then
        self.layouts[layoutName] = nil
        self:Log("Custom layout deleted: " .. layoutName)
        return true
    end
    
    return false
end

function LayoutTemplateEngine:ListLayouts()
    local layouts = {}
    
    -- Add auto layout
    table.insert(layouts, {
        name = "auto",
        display = "Auto (by raid size)",
        type = "built-in",
        description = "Automatically select layout based on raid size",
    })
    
    -- Add built-in layouts
    for layoutName, layout in pairs(self.layout_definitions) do
        table.insert(layouts, {
            name = layoutName,
            display = layout.name,
            type = "built-in",
            description = layout.description,
        })
    end
    
    -- Add custom layouts
    for layoutName, layout in pairs(self.layouts) do
        table.insert(layouts, {
            name = layoutName,
            display = layout.name or layoutName,
            type = "custom",
            description = layout.description or "Custom layout",
        })
    end
    
    return layouts
end

function LayoutTemplateEngine:GetLayoutInfo(layoutName)
    local layout = self:GetLayout(layoutName)
    if not layout then
        return nil
    end
    
    return {
        name = layout.name or layoutName,
        description = layout.description or "",
        groups_per_row = layout.groups_per_row,
        frame_width = layout.frame_width,
        frame_height = layout.frame_height,
        optimal_raid_size = layout.optimal_raid_size,
        scale = layout.scale,
    }
end

function LayoutTemplateEngine:GetStatus()
    local customCount = 0
    for _ in pairs(self.layouts) do
        customCount = customCount + 1
    end
    
    return {
        enabled = self.enabled,
        current_layout = self.current_layout,
        built_in_layouts = 5,
        custom_layouts = customCount,
        raid_size = GetNumGroupMembers(),
    }
end

function LayoutTemplateEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[LayoutTemplateEngine] " .. message)
    else
        print("[LayoutTemplateEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_LAYOUTTEMPLATE1 = "/layout"
    SlashCmdList["LAYOUTTEMPLATE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            if args and args ~= "" then
                if LayoutTemplateEngine:SetLayout(args) then
                    print("Layout set to: " .. args)
                else
                    print("Layout not found: " .. args)
                end
            else
                print("Usage: /layout set <layout_name>")
            end
        elseif cmd == "list" then
            local layouts = LayoutTemplateEngine:ListLayouts()
            print("Available layouts:")
            for _, layout in ipairs(layouts) do
                local typeStr = layout.type == "built-in" and "[BUILTIN]" or "[CUSTOM]"
                print("  " .. layout.display .. " " .. typeStr)
                if layout.description and layout.description ~= "" then
                    print("    " .. layout.description)
                end
            end
        elseif cmd == "current" then
            print("Current layout: " .. LayoutTemplateEngine.current_layout)
            local raidSize = GetNumGroupMembers()
            print("Raid size: " .. raidSize)
        elseif cmd == "info" then
            if args and args ~= "" then
                local info = LayoutTemplateEngine:GetLayoutInfo(args)
                if info then
                    print("Layout Info: " .. info.name)
                    print("  Description: " .. info.description)
                    print("  Groups per row: " .. info.groups_per_row)
                    print("  Frame size: " .. info.frame_width .. "x" .. info.frame_height)
                    print("  Optimal raid size: " .. info.optimal_raid_size)
                else
                    print("Layout not found: " .. args)
                end
            else
                print("Usage: /layout info <layout_name>")
            end
        elseif cmd == "status" then
            local status = LayoutTemplateEngine:GetStatus()
            print("Layout Template Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Layout Commands:")
            print("  /layout set <name> - Set active layout")
            print("  /layout list - List all available layouts")
            print("  /layout current - Show current layout")
            print("  /layout info <name> - Show layout details")
            print("  /layout status - Show system status")
        end
    end
end

return LayoutTemplateEngine
