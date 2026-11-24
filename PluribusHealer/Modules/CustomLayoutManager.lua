-- CustomLayoutManager.lua - Save and load custom frame arrangements
-- Part of PluribusHealer addon suite
-- Allows players to create and save personalized layouts

local CustomLayoutManager = {}
CustomLayoutManager.enabled = false
CustomLayoutManager.db = nil
CustomLayoutManager.custom_layouts = {}
CustomLayoutManager.saved_positions = {}

-- Configuration
CustomLayoutManager.config = {
    enabled = true,
    max_custom_layouts = 20,
    auto_save = true,
    save_interval = 30,  -- seconds
}

function CustomLayoutManager:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.custom_layouts then
        self.db.custom_layouts = {}
    end
    
    if not self.db.saved_positions then
        self.db.saved_positions = {}
    end
    
    self.custom_layouts = self.db.custom_layouts
    self.saved_positions = self.db.saved_positions
    self.enabled = true
    
    self:Log("Initialized with " .. self:GetCustomLayoutCount() .. " custom layouts")
end

function CustomLayoutManager:SaveCurrentLayout(layoutName, description)
    if not layoutName or layoutName == "" then
        return false
    end
    
    if self:GetCustomLayoutCount() >= self.config.max_custom_layouts then
        self:Log("Maximum custom layouts reached: " .. self.config.max_custom_layouts)
        return false
    end
    
    if self.custom_layouts[layoutName] then
        self:Log("Layout already exists: " .. layoutName)
        return false
    end
    
    -- Capture current frame positions
    local positions = {}
    for i = 1, 40 do
        local unitID = "raid" .. i
        if UnitExists(unitID) then
            positions[i] = {
                unit = unitID,
                group = GetRaidTargetIndex(unitID),
            }
        end
    end
    
    self.custom_layouts[layoutName] = {
        name = layoutName,
        description = description or "Custom layout",
        created_at = GetTime(),
        modified_at = GetTime(),
        positions = positions,
        raid_size = GetNumGroupMembers(),
    }
    
    self:Log("Layout saved: " .. layoutName)
    return true
end

function CustomLayoutManager:LoadLayout(layoutName)
    if not layoutName then
        return false
    end
    
    if not self.custom_layouts[layoutName] then
        self:Log("Layout not found: " .. layoutName)
        return false
    end
    
    local layout = self.custom_layouts[layoutName]
    self.saved_positions = layout.positions or {}
    
    self:Log("Layout loaded: " .. layoutName)
    return true
end

function CustomLayoutManager:DeleteLayout(layoutName)
    if not layoutName then
        return false
    end
    
    if not self.custom_layouts[layoutName] then
        self:Log("Layout not found: " .. layoutName)
        return false
    end
    
    self.custom_layouts[layoutName] = nil
    self:Log("Layout deleted: " .. layoutName)
    return true
end

function CustomLayoutManager:RenameLayout(oldName, newName)
    if not oldName or not newName or oldName == "" or newName == "" then
        return false
    end
    
    if not self.custom_layouts[oldName] then
        self:Log("Layout not found: " .. oldName)
        return false
    end
    
    if self.custom_layouts[newName] then
        self:Log("Layout already exists: " .. newName)
        return false
    end
    
    self.custom_layouts[newName] = self.custom_layouts[oldName]
    self.custom_layouts[newName].name = newName
    self.custom_layouts[newName].modified_at = GetTime()
    self.custom_layouts[oldName] = nil
    
    self:Log("Layout renamed: " .. oldName .. " -> " .. newName)
    return true
end

function CustomLayoutManager:DuplicateLayout(sourceName, targetName)
    if not sourceName or not targetName then
        return false
    end
    
    if not self.custom_layouts[sourceName] then
        self:Log("Source layout not found: " .. sourceName)
        return false
    end
    
    if self.custom_layouts[targetName] then
        self:Log("Target layout already exists: " .. targetName)
        return false
    end
    
    if self:GetCustomLayoutCount() >= self.config.max_custom_layouts then
        self:Log("Maximum custom layouts reached: " .. self.config.max_custom_layouts)
        return false
    end
    
    -- Deep copy the layout
    local source = self.custom_layouts[sourceName]
    local newPositions = {}
    
    if source.positions then
        for k, v in pairs(source.positions) do
            newPositions[k] = {}
            for pk, pv in pairs(v) do
                newPositions[k][pk] = pv
            end
        end
    end
    
    self.custom_layouts[targetName] = {
        name = targetName,
        description = source.description .. " (copy)",
        created_at = GetTime(),
        modified_at = GetTime(),
        positions = newPositions,
        raid_size = source.raid_size,
    }
    
    self:Log("Layout duplicated: " .. sourceName .. " -> " .. targetName)
    return true
end

function CustomLayoutManager:ListCustomLayouts()
    local layouts = {}
    
    for layoutName, layout in pairs(self.custom_layouts) do
        table.insert(layouts, {
            name = layoutName,
            description = layout.description or "",
            created_at = layout.created_at or 0,
            modified_at = layout.modified_at or 0,
            raid_size = layout.raid_size or 0,
        })
    end
    
    -- Sort by modification time (newest first)
    table.sort(layouts, function(a, b)
        return a.modified_at > b.modified_at
    end)
    
    return layouts
end

function CustomLayoutManager:GetLayoutInfo(layoutName)
    if not layoutName then
        return nil
    end
    
    if not self.custom_layouts[layoutName] then
        return nil
    end
    
    local layout = self.custom_layouts[layoutName]
    
    return {
        name = layout.name,
        description = layout.description or "",
        created_at = layout.created_at,
        modified_at = layout.modified_at,
        raid_size = layout.raid_size,
        position_count = layout.positions and table.getn(layout.positions) or 0,
    }
end

function CustomLayoutManager:ExportLayout(layoutName)
    if not layoutName then
        return nil
    end
    
    if not self.custom_layouts[layoutName] then
        return nil
    end
    
    local layout = self.custom_layouts[layoutName]
    
    -- Serialize to string format
    local exported = {
        name = layout.name,
        description = layout.description,
        raid_size = layout.raid_size,
        positions = layout.positions,
    }
    
    return exported
end

function CustomLayoutManager:ImportLayout(layoutName, layoutData)
    if not layoutName or not layoutData then
        return false
    end
    
    if self.custom_layouts[layoutName] then
        self:Log("Layout already exists: " .. layoutName)
        return false
    end
    
    if self:GetCustomLayoutCount() >= self.config.max_custom_layouts then
        self:Log("Maximum custom layouts reached: " .. self.config.max_custom_layouts)
        return false
    end
    
    self.custom_layouts[layoutName] = {
        name = layoutName,
        description = layoutData.description or "Imported layout",
        created_at = GetTime(),
        modified_at = GetTime(),
        positions = layoutData.positions or {},
        raid_size = layoutData.raid_size or 0,
    }
    
    self:Log("Layout imported: " .. layoutName)
    return true
end

function CustomLayoutManager:GetCustomLayoutCount()
    local count = 0
    for _ in pairs(self.custom_layouts) do
        count = count + 1
    end
    return count
end

function CustomLayoutManager:GetStatus()
    return {
        enabled = self.enabled,
        custom_layouts = self:GetCustomLayoutCount(),
        max_layouts = self.config.max_custom_layouts,
        auto_save = self.config.auto_save,
    }
end

function CustomLayoutManager:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[CustomLayoutManager] " .. message)
    else
        print("[CustomLayoutManager] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_CUSTOMLAYOUT1 = "/customlayout"
    SlashCmdList["CUSTOMLAYOUT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "save" then
            if args and args ~= "" then
                if CustomLayoutManager:SaveCurrentLayout(args) then
                    print("Layout saved: " .. args)
                else
                    print("Failed to save layout: " .. args)
                end
            else
                print("Usage: /customlayout save <layout_name>")
            end
        elseif cmd == "load" then
            if args and args ~= "" then
                if CustomLayoutManager:LoadLayout(args) then
                    print("Layout loaded: " .. args)
                else
                    print("Layout not found: " .. args)
                end
            else
                print("Usage: /customlayout load <layout_name>")
            end
        elseif cmd == "delete" then
            if args and args ~= "" then
                if CustomLayoutManager:DeleteLayout(args) then
                    print("Layout deleted: " .. args)
                else
                    print("Failed to delete: " .. args)
                end
            else
                print("Usage: /customlayout delete <layout_name>")
            end
        elseif cmd == "list" then
            local layouts = CustomLayoutManager:ListCustomLayouts()
            if #layouts == 0 then
                print("No custom layouts saved")
            else
                print("Custom layouts (" .. #layouts .. "/" .. CustomLayoutManager.config.max_custom_layouts .. "):")
                for _, layout in ipairs(layouts) do
                    print("  " .. layout.name .. " - " .. layout.description)
                end
            end
        elseif cmd == "info" then
            if args and args ~= "" then
                local info = CustomLayoutManager:GetLayoutInfo(args)
                if info then
                    print("Layout Info: " .. info.name)
                    print("  Description: " .. info.description)
                    print("  Raid Size: " .. info.raid_size)
                    print("  Positions: " .. info.position_count)
                else
                    print("Layout not found: " .. args)
                end
            else
                print("Usage: /customlayout info <layout_name>")
            end
        elseif cmd == "status" then
            local status = CustomLayoutManager:GetStatus()
            print("Custom Layout Manager:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Custom Layout Commands:")
            print("  /customlayout save <name> - Save current layout")
            print("  /customlayout load <name> - Load custom layout")
            print("  /customlayout delete <name> - Delete layout")
            print("  /customlayout list - List all layouts")
            print("  /customlayout info <name> - Show layout info")
            print("  /customlayout status - Show system status")
        end
    end
end

return CustomLayoutManager
