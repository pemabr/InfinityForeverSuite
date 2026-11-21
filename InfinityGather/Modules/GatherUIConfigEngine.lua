-- GatherUIConfigEngine.lua - UI Configuration and Display Settings
-- Part of InfinityGather addon suite
-- Manages display settings, toggles, and UI configuration for gathering nodes

local GatherUIConfigEngine = {}
GatherUIConfigEngine.enabled = false
GatherUIConfigEngine.db = nil
GatherUIConfigEngine.ui_settings = {}

-- Configuration
GatherUIConfigEngine.config = {
    enabled = true,
}

-- Default UI settings
GatherUIConfigEngine.DEFAULT_SETTINGS = {
    display_enabled = true,
    show_world_map = true,
    show_minimap = true,
    show_node_icons = true,
    show_node_names = true,
    show_node_distance = true,
    
    distance_threshold = 2000,
    minimap_range = 1000,
    icon_size = 1.0,
    
    herb_enabled = true,
    ore_enabled = true,
    fishing_enabled = true,
    treasure_enabled = true,
    skinning_enabled = true,
    disenchant_enabled = true,
    
    route_visualization_enabled = true,
    route_waypoint_enabled = true,
    route_line_enabled = true,
    
    filter_presets_enabled = true,
}

function GatherUIConfigEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityGather")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.ui_config then
        self.db.ui_config = {}
        for key, value in pairs(self.DEFAULT_SETTINGS) do
            self.db.ui_config[key] = value
        end
    end
    
    self.ui_settings = self.db.ui_config
    self.enabled = true
    
    self:Log("Initialized UI config engine with " .. self:_CountSettings() .. " settings")
end

function GatherUIConfigEngine:SetDisplayEnabled(enabled)
    self.ui_settings.display_enabled = enabled
    self:Log("Display " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:IsDisplayEnabled()
    return self.ui_settings.display_enabled
end

function GatherUIConfigEngine:SetWorldMapDisplay(enabled)
    self.ui_settings.show_world_map = enabled
    self:Log("World map display " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:IsWorldMapDisplayEnabled()
    return self.ui_settings.show_world_map
end

function GatherUIConfigEngine:SetMinimapDisplay(enabled)
    self.ui_settings.show_minimap = enabled
    self:Log("Minimap display " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:IsMinimapDisplayEnabled()
    return self.ui_settings.show_minimap
end

function GatherUIConfigEngine:SetNodeIconDisplay(enabled)
    self.ui_settings.show_node_icons = enabled
    self:Log("Node icons " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:SetNodeNameDisplay(enabled)
    self.ui_settings.show_node_names = enabled
    self:Log("Node names " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:SetNodeDistanceDisplay(enabled)
    self.ui_settings.show_node_distance = enabled
    self:Log("Node distance " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:SetDistanceThreshold(distance)
    if not distance or distance < 0 then
        return false
    end
    
    self.ui_settings.distance_threshold = distance
    self:Log("Distance threshold set to " .. distance)
    return true
end

function GatherUIConfigEngine:GetDistanceThreshold()
    return self.ui_settings.distance_threshold
end

function GatherUIConfigEngine:SetMinimapRange(range)
    if not range or range < 0 then
        return false
    end
    
    self.ui_settings.minimap_range = range
    self:Log("Minimap range set to " .. range)
    return true
end

function GatherUIConfigEngine:GetMinimapRange()
    return self.ui_settings.minimap_range
end

function GatherUIConfigEngine:SetIconSize(size)
    if not size or size < 0.5 or size > 2.0 then
        return false
    end
    
    self.ui_settings.icon_size = size
    self:Log("Icon size set to " .. size .. "x")
    return true
end

function GatherUIConfigEngine:GetIconSize()
    return self.ui_settings.icon_size
end

function GatherUIConfigEngine:SetNodeTypeVisibility(nodeType, enabled)
    local typeKey = nodeType .. "_enabled"
    if not self.ui_settings[typeKey] then
        return false
    end
    
    self.ui_settings[typeKey] = enabled
    self:Log(nodeType .. " visibility " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:IsNodeTypeVisible(nodeType)
    local typeKey = nodeType .. "_enabled"
    if not self.ui_settings[typeKey] then
        return true
    end
    
    return self.ui_settings[typeKey]
end

function GatherUIConfigEngine:SetRouteVisualization(enabled)
    self.ui_settings.route_visualization_enabled = enabled
    self:Log("Route visualization " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:IsRouteVisualizationEnabled()
    return self.ui_settings.route_visualization_enabled
end

function GatherUIConfigEngine:SetRouteWaypoints(enabled)
    self.ui_settings.route_waypoint_enabled = enabled
    self:Log("Route waypoints " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:IsRouteWaypointsEnabled()
    return self.ui_settings.route_waypoint_enabled
end

function GatherUIConfigEngine:SetRouteLines(enabled)
    self.ui_settings.route_line_enabled = enabled
    self:Log("Route lines " .. (enabled and "enabled" or "disabled"))
    return true
end

function GatherUIConfigEngine:IsRouteLinesEnabled()
    return self.ui_settings.route_line_enabled
end

function GatherUIConfigEngine:SaveFilterPreset(presetName, filterConfig)
    if not presetName or not filterConfig then
        return false
    end
    
    if not self.db.filter_presets then
        self.db.filter_presets = {}
    end
    
    self.db.filter_presets[presetName] = filterConfig
    self:Log("Preset '" .. presetName .. "' saved")
    return true
end

function GatherUIConfigEngine:LoadFilterPreset(presetName)
    if not self.db.filter_presets or not self.db.filter_presets[presetName] then
        return nil
    end
    
    self:Log("Preset '" .. presetName .. "' loaded")
    return self.db.filter_presets[presetName]
end

function GatherUIConfigEngine:DeleteFilterPreset(presetName)
    if not self.db.filter_presets or not self.db.filter_presets[presetName] then
        return false
    end
    
    self.db.filter_presets[presetName] = nil
    self:Log("Preset '" .. presetName .. "' deleted")
    return true
end

function GatherUIConfigEngine:ListFilterPresets()
    if not self.db.filter_presets then
        return {}
    end
    
    local presets = {}
    for name, _ in pairs(self.db.filter_presets) do
        table.insert(presets, name)
    end
    
    return presets
end

function GatherUIConfigEngine:ResetToDefaults()
    for key, value in pairs(self.DEFAULT_SETTINGS) do
        self.ui_settings[key] = value
    end
    
    self:Log("UI settings reset to defaults")
    return true
end

function GatherUIConfigEngine:GetAllSettings()
    return self.ui_settings
end

function GatherUIConfigEngine:ExportSettings(format)
    if not format then
        format = "json"
    end
    
    if format == "json" then
        return self.ui_settings
    elseif format == "lua" then
        local lua = "local settings = {\n"
        for key, value in pairs(self.ui_settings) do
            if type(value) == "boolean" then
                lua = lua .. "  " .. key .. " = " .. (value and "true" or "false") .. ",\n"
            elseif type(value) == "number" then
                lua = lua .. "  " .. key .. " = " .. value .. ",\n"
            elseif type(value) == "string" then
                lua = lua .. "  " .. key .. " = '" .. value .. "',\n"
            end
        end
        lua = lua .. "}\nreturn settings"
        return lua
    end
    
    return nil
end

function GatherUIConfigEngine:_CountSettings()
    local count = 0
    for _ in pairs(self.ui_settings) do
        count = count + 1
    end
    return count
end

function GatherUIConfigEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_settings = self:_CountSettings(),
        display_enabled = self.ui_settings.display_enabled,
        world_map_enabled = self.ui_settings.show_world_map,
        minimap_enabled = self.ui_settings.show_minimap,
    }
end

function GatherUIConfigEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[GatherUIConfigEngine] " .. message)
    else
        print("[GatherUIConfigEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERUI1 = "/gatherui"
    SlashCmdList["GATHERUI"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "toggle" then
            GatherUIConfigEngine:SetDisplayEnabled(not GatherUIConfigEngine:IsDisplayEnabled())
        elseif cmd == "distance" then
            local dist = tonumber(args)
            if dist then
                GatherUIConfigEngine:SetDistanceThreshold(dist)
            end
        elseif cmd == "range" then
            local range = tonumber(args)
            if range then
                GatherUIConfigEngine:SetMinimapRange(range)
            end
        elseif cmd == "preset" then
            local op, name = args:match("(%S+)%s+(%S+)")
            if op == "save" and name then
                GatherUIConfigEngine:SaveFilterPreset(name, {})
                print("Preset '" .. name .. "' saved")
            elseif op == "load" and name then
                GatherUIConfigEngine:LoadFilterPreset(name)
                print("Preset '" .. name .. "' loaded")
            elseif op == "delete" and name then
                GatherUIConfigEngine:DeleteFilterPreset(name)
                print("Preset '" .. name .. "' deleted")
            elseif op == "list" then
                local presets = GatherUIConfigEngine:ListFilterPresets()
                print("Presets: " .. table.concat(presets, ", "))
            end
        elseif cmd == "status" then
            local status = GatherUIConfigEngine:GetStatus()
            print("UI Config Status:")
            print("  Total settings: " .. status.total_settings)
            print("  Display: " .. (status.display_enabled and "ON" or "OFF"))
            print("  World map: " .. (status.world_map_enabled and "ON" or "OFF"))
            print("  Minimap: " .. (status.minimap_enabled and "ON" or "OFF"))
        elseif cmd == "reset" then
            GatherUIConfigEngine:ResetToDefaults()
            print("UI settings reset to defaults")
        else
            print("UI Config Commands:")
            print("  /gatherui toggle - Toggle display on/off")
            print("  /gatherui distance [yards] - Set distance threshold")
            print("  /gatherui range [yards] - Set minimap range")
            print("  /gatherui preset [save/load/delete/list] [name]")
            print("  /gatherui status - Show settings")
            print("  /gatherui reset - Reset to defaults")
        end
    end
end

return GatherUIConfigEngine
