-- GroupFramingOptionsEngine.lua - Configure frame grouping and layout options
-- Part of InfinityHealer addon suite
-- Handles frame grouping by role, class, or custom criteria

local GroupFramingOptionsEngine = {}
GroupFramingOptionsEngine.enabled = false
GroupFramingOptionsEngine.db = nil
GroupFramingOptionsEngine.groups = {}

-- Configuration
GroupFramingOptionsEngine.config = {
    enabled = true,
    grouping_method = "ROLE",  -- ROLE, CLASS, CUSTOM, OFF
    group_order = {"TANK", "HEALER", "DAMAGER", "UNASSIGNED"},
    sort_by = "GROUP",  -- GROUP, NAME, CLASS, ROLE, HEALTH
    custom_groups = {},
    group_spacing = 5,
    group_max_width = 300,
}

-- Predefined group configurations
GroupFramingOptionsEngine.predefined_groups = {
    ROLE = {
        TANK = {color = {0.78, 0.61, 0.43}},
        HEALER = {color = {0.0, 1.0, 0.59}},
        DAMAGER = {color = {1.0, 0.82, 0.0}},
        UNASSIGNED = {color = {0.5, 0.5, 0.5}},
    },
    CLASS = {
        WARRIOR = {color = {0.78, 0.61, 0.43}},
        PALADIN = {color = {0.96, 0.55, 0.73}},
        HUNTER = {color = {0.67, 0.83, 0.45}},
        ROGUE = {color = {1.0, 0.96, 0.41}},
        PRIEST = {color = {1.0, 1.0, 1.0}},
        DEATHKNIGHT = {color = {0.77, 0.12, 0.23}},
        SHAMAN = {color = {0.0, 0.44, 0.87}},
        MAGE = {color = {0.41, 0.8, 0.94}},
        WARLOCK = {color = {0.58, 0.51, 0.79}},
        DRUID = {color = {1.0, 0.49, 0.04}},
        MONK = {color = {0.0, 1.0, 0.59}},
        DEMONHUNTER = {color = {0.64, 0.19, 0.79}},
    },
}

function GroupFramingOptionsEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.group_options then
        self.db.group_options = {}
    end
    
    if not self.db.custom_groups then
        self.db.custom_groups = {}
    end
    
    self.groups = self.db.group_options
    self.config.custom_groups = self.db.custom_groups
    self.enabled = true
    
    self:Log("Initialized with grouping method: " .. self.config.grouping_method)
end

function GroupFramingOptionsEngine:GroupPlayersByRole(members)
    if not members or #members == 0 then
        return {}
    end
    
    local groups = {
        TANK = {},
        HEALER = {},
        DAMAGER = {},
        UNASSIGNED = {},
    }
    
    for _, memberName in ipairs(members) do
        local role = UnitGroupRolesAssigned(memberName)
        
        if role and groups[role] then
            table.insert(groups[role], memberName)
        else
            table.insert(groups["UNASSIGNED"], memberName)
        end
    end
    
    return groups
end

function GroupFramingOptionsEngine:GroupPlayersByClass(members)
    if not members or #members == 0 then
        return {}
    end
    
    local groups = {}
    
    for _, memberName in ipairs(members) do
        local class = select(2, UnitClass(memberName))
        
        if not groups[class] then
            groups[class] = {}
        end
        
        table.insert(groups[class], memberName)
    end
    
    return groups
end

function GroupFramingOptionsEngine:GroupPlayersByCustom(members)
    if not members or #members == 0 then
        return {}
    end
    
    local groups = {}
    
    -- Apply custom grouping rules
    for groupName, groupConfig in pairs(self.config.custom_groups) do
        if groupConfig.criteria then
            groups[groupName] = {}
        end
    end
    
    -- Fallback to unassigned
    if not groups["OTHER"] then
        groups["OTHER"] = {}
    end
    
    for _, memberName in ipairs(members) do
        local assigned = false
        
        for groupName, groupConfig in pairs(self.config.custom_groups) do
            if groupConfig.criteria then
                -- Custom criteria matching (would need specific implementation)
                assigned = true
                break
            end
        end
        
        if not assigned then
            table.insert(groups["OTHER"], memberName)
        end
    end
    
    return groups
end

function GroupFramingOptionsEngine:GetGroupedMembers(members)
    if self.config.grouping_method == "ROLE" then
        return self:GroupPlayersByRole(members)
    elseif self.config.grouping_method == "CLASS" then
        return self:GroupPlayersByClass(members)
    elseif self.config.grouping_method == "CUSTOM" then
        return self:GroupPlayersByCustom(members)
    else
        -- Ungrouped - return all members in one group
        return {ALL = members}
    end
end

function GroupFramingOptionsEngine:GetGroupColor(groupMethod, groupName)
    if self.predefined_groups[groupMethod] and self.predefined_groups[groupMethod][groupName] then
        return self.predefined_groups[groupMethod][groupName].color
    end
    
    return {1.0, 1.0, 1.0}  -- Default white
end

function GroupFramingOptionsEngine:SetGroupingMethod(method)
    if method == "ROLE" or method == "CLASS" or method == "CUSTOM" or method == "OFF" then
        self.config.grouping_method = method
        self:Log("Grouping method set to: " .. method)
        return true
    end
    return false
end

function GroupFramingOptionsEngine:AddCustomGroup(groupName, criteria, color)
    if not groupName or not criteria then
        return false
    end
    
    self.config.custom_groups[groupName] = {
        name = groupName,
        criteria = criteria,
        color = color or {0.5, 0.5, 0.5},
    }
    
    self:Log("Custom group created: " .. groupName)
    return true
end

function GroupFramingOptionsEngine:RemoveCustomGroup(groupName)
    if self.config.custom_groups[groupName] then
        self.config.custom_groups[groupName] = nil
        self:Log("Custom group removed: " .. groupName)
        return true
    end
    return false
end

function GroupFramingOptionsEngine:SetGroupSpacing(spacing)
    if spacing and spacing > 0 then
        self.config.group_spacing = spacing
        self:Log("Group spacing set to: " .. spacing)
        return true
    end
    return false
end

function GroupFramingOptionsEngine:SetGroupMaxWidth(width)
    if width and width > 100 then
        self.config.group_max_width = width
        self:Log("Group max width set to: " .. width)
        return true
    end
    return false
end

function GroupFramingOptionsEngine:SetSortOrder(sortBy)
    if sortBy == "GROUP" or sortBy == "NAME" or sortBy == "CLASS" or sortBy == "ROLE" or sortBy == "HEALTH" then
        self.config.sort_by = sortBy
        self:Log("Sort order set to: " .. sortBy)
        return true
    end
    return false
end

function GroupFramingOptionsEngine:GetStatus()
    local customGroupCount = 0
    
    for _ in pairs(self.config.custom_groups) do
        customGroupCount = customGroupCount + 1
    end
    
    return {
        enabled = self.enabled,
        grouping_method = self.config.grouping_method,
        sort_by = self.config.sort_by,
        group_spacing = self.config.group_spacing,
        group_max_width = self.config.group_max_width,
        custom_groups = customGroupCount,
    }
end

function GroupFramingOptionsEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[GroupFramingOptionsEngine] " .. message)
    else
        print("[GroupFramingOptionsEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GROUPFRAME1 = "/groupframe"
    SlashCmdList["GROUPFRAME"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "method" then
            if args and (args == "ROLE" or args == "CLASS" or args == "CUSTOM" or args == "OFF") then
                GroupFramingOptionsEngine:SetGroupingMethod(args)
                print("Grouping method: " .. args)
            else
                print("Usage: /groupframe method <ROLE|CLASS|CUSTOM|OFF>")
            end
        elseif cmd == "sort" then
            if args and (args == "GROUP" or args == "NAME" or args == "CLASS" or args == "ROLE" or args == "HEALTH") then
                GroupFramingOptionsEngine:SetSortOrder(args)
                print("Sort order: " .. args)
            else
                print("Usage: /groupframe sort <GROUP|NAME|CLASS|ROLE|HEALTH>")
            end
        elseif cmd == "spacing" then
            if args and tonumber(args) then
                GroupFramingOptionsEngine:SetGroupSpacing(tonumber(args))
                print("Group spacing: " .. args)
            else
                print("Usage: /groupframe spacing <pixels>")
            end
        elseif cmd == "width" then
            if args and tonumber(args) then
                GroupFramingOptionsEngine:SetGroupMaxWidth(tonumber(args))
                print("Max width: " .. args)
            else
                print("Usage: /groupframe width <pixels>")
            end
        elseif cmd == "custom" then
            local groupName, criteria = args:match("^(%S+)%s+(.*)$")
            if groupName and criteria then
                GroupFramingOptionsEngine:AddCustomGroup(groupName, criteria)
                print("Custom group added: " .. groupName)
            else
                print("Usage: /groupframe custom <name> <criteria>")
            end
        elseif cmd == "removecustom" then
            if args and args ~= "" then
                GroupFramingOptionsEngine:RemoveCustomGroup(args)
                print("Custom group removed: " .. args)
            else
                print("Usage: /groupframe removecustom <name>")
            end
        elseif cmd == "status" then
            local status = GroupFramingOptionsEngine:GetStatus()
            print("Group Framing Options Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Group Framing Commands:")
            print("  /groupframe method <ROLE|CLASS|CUSTOM|OFF> - Set grouping method")
            print("  /groupframe sort <GROUP|NAME|CLASS|ROLE|HEALTH> - Set sort order")
            print("  /groupframe spacing <pixels> - Set spacing between groups")
            print("  /groupframe width <pixels> - Set max group width")
            print("  /groupframe custom <name> <criteria> - Add custom group")
            print("  /groupframe removecustom <name> - Remove custom group")
            print("  /groupframe status - Show system status")
        end
    end
end

return GroupFramingOptionsEngine
