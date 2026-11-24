-- FrameLayoutConfigUIEngine.lua - Configure raid frame layout visually
-- Part of PluribusHealer addon suite
-- Provides UI for adjusting frame sizes, positions, and grouping

local FrameLayoutConfigUIEngine = {}
FrameLayoutConfigUIEngine.enabled = false
FrameLayoutConfigUIEngine.db = nil
FrameLayoutConfigUIEngine.ui_state = {}

-- Configuration
FrameLayoutConfigUIEngine.config = {
    enabled = true,
    edit_mode = false,
    show_grid = false,
    snap_to_grid = true,
    grid_size = 10,
    lock_positions = false,
    show_frame_names = true,
}

function FrameLayoutConfigUIEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.ui_config then
        self.db.ui_config = {}
    end
    
    if not self.db.frame_positions then
        self.db.frame_positions = {}
    end
    
    self.ui_state = self.db.ui_config
    self.enabled = true
    
    self:Log("Initialized UI configuration system")
end

function FrameLayoutConfigUIEngine:EnableEditMode()
    self.config.edit_mode = true
    self.config.lock_positions = false
    self:Log("Edit mode enabled - frames are now movable")
    return true
end

function FrameLayoutConfigUIEngine:DisableEditMode()
    self.config.edit_mode = false
    self.config.lock_positions = true
    self:Log("Edit mode disabled - frames are now locked")
    return true
end

function FrameLayoutConfigUIEngine:SetFramePosition(frameName, x, y)
    if not frameName then
        return false
    end
    
    if not self.db.frame_positions then
        self.db.frame_positions = {}
    end
    
    local snapX = x
    local snapY = y
    
    -- Apply grid snapping if enabled
    if self.config.snap_to_grid then
        snapX = math.floor(x / self.config.grid_size) * self.config.grid_size
        snapY = math.floor(y / self.config.grid_size) * self.config.grid_size
    end
    
    self.db.frame_positions[frameName] = {
        x = snapX,
        y = snapY,
        saved_at = GetTime(),
    }
    
    return true
end

function FrameLayoutConfigUIEngine:GetFramePosition(frameName)
    if not frameName or not self.db.frame_positions then
        return nil
    end
    
    return self.db.frame_positions[frameName]
end

function FrameLayoutConfigUIEngine:SetFrameSize(frameName, width, height)
    if not frameName or not width or not height then
        return false
    end
    
    if not self.db.frame_positions then
        self.db.frame_positions = {}
    end
    
    if not self.db.frame_positions[frameName] then
        self.db.frame_positions[frameName] = {}
    end
    
    self.db.frame_positions[frameName].width = width
    self.db.frame_positions[frameName].height = height
    
    return true
end

function FrameLayoutConfigUIEngine:GetFrameSize(frameName)
    if not frameName or not self.db.frame_positions or not self.db.frame_positions[frameName] then
        return nil
    end
    
    local pos = self.db.frame_positions[frameName]
    if pos.width and pos.height then
        return {width = pos.width, height = pos.height}
    end
    
    return nil
end

function FrameLayoutConfigUIEngine:SetGridSize(size)
    if size and size > 1 and size <= 50 then
        self.config.grid_size = size
        self:Log("Grid size set to: " .. size)
        return true
    end
    return false
end

function FrameLayoutConfigUIEngine:ToggleGridDisplay()
    self.config.show_grid = not self.config.show_grid
    self:Log("Grid display: " .. (self.config.show_grid and "ON" or "OFF"))
    return true
end

function FrameLayoutConfigUIEngine:ToggleGridSnap()
    self.config.snap_to_grid = not self.config.snap_to_grid
    self:Log("Grid snap: " .. (self.config.snap_to_grid and "ON" or "OFF"))
    return true
end

function FrameLayoutConfigUIEngine:ToggleFrameNames()
    self.config.show_frame_names = not self.config.show_frame_names
    self:Log("Frame names: " .. (self.config.show_frame_names and "ON" or "OFF"))
    return true
end

function FrameLayoutConfigUIEngine:ResetAllPositions()
    self.db.frame_positions = {}
    self:Log("All frame positions reset to defaults")
    return true
end

function FrameLayoutConfigUIEngine:ExportLayout()
    local export = {
        positions = self.db.frame_positions or {},
        config = {
            grid_size = self.config.grid_size,
        },
        exported_at = GetTime(),
        exporter_version = "1.0",
    }
    
    return export
end

function FrameLayoutConfigUIEngine:ImportLayout(layoutData)
    if not layoutData or not layoutData.positions then
        return false
    end
    
    if not self.db.frame_positions then
        self.db.frame_positions = {}
    end
    
    -- Merge positions (don't overwrite if position already exists)
    for frameName, position in pairs(layoutData.positions) do
        if not self.db.frame_positions[frameName] then
            self.db.frame_positions[frameName] = position
        end
    end
    
    if layoutData.config and layoutData.config.grid_size then
        self.config.grid_size = layoutData.config.grid_size
    end
    
    self:Log("Layout imported successfully")
    return true
end

function FrameLayoutConfigUIEngine:GetFrameCount()
    if not self.db.frame_positions then
        return 0
    end
    
    local count = 0
    for _ in pairs(self.db.frame_positions) do
        count = count + 1
    end
    
    return count
end

function FrameLayoutConfigUIEngine:ListFrames()
    if not self.db.frame_positions then
        return {}
    end
    
    local frames = {}
    
    for frameName, position in pairs(self.db.frame_positions) do
        table.insert(frames, {
            name = frameName,
            x = position.x or 0,
            y = position.y or 0,
            width = position.width or "default",
            height = position.height or "default",
        })
    end
    
    table.sort(frames, function(a, b) return a.name < b.name end)
    return frames
end

function FrameLayoutConfigUIEngine:GetStatus()
    return {
        enabled = self.enabled,
        edit_mode = self.config.edit_mode,
        grid_snap = self.config.snap_to_grid,
        grid_size = self.config.grid_size,
        show_grid = self.config.show_grid,
        show_names = self.config.show_frame_names,
        frame_count = self:GetFrameCount(),
    }
end

function FrameLayoutConfigUIEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[FrameLayoutConfigUIEngine] " .. message)
    else
        print("[FrameLayoutConfigUIEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_FRAMELAYOUT1 = "/framelayout"
    SlashCmdList["FRAMELAYOUT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "edit" then
            if args == "on" then
                FrameLayoutConfigUIEngine:EnableEditMode()
                print("Edit mode ON - frames are movable")
            elseif args == "off" then
                FrameLayoutConfigUIEngine:DisableEditMode()
                print("Edit mode OFF - frames are locked")
            else
                print("Usage: /framelayout edit <on|off>")
            end
        elseif cmd == "grid" then
            if args == "show" then
                FrameLayoutConfigUIEngine:ToggleGridDisplay()
                print("Grid display: " .. (FrameLayoutConfigUIEngine.config.show_grid and "ON" or "OFF"))
            elseif args == "snap" then
                FrameLayoutConfigUIEngine:ToggleGridSnap()
                print("Grid snap: " .. (FrameLayoutConfigUIEngine.config.snap_to_grid and "ON" or "OFF"))
            else
                print("Usage: /framelayout grid <show|snap>")
            end
        elseif cmd == "gridsize" then
            if args and tonumber(args) then
                FrameLayoutConfigUIEngine:SetGridSize(tonumber(args))
                print("Grid size: " .. args)
            else
                print("Usage: /framelayout gridsize <pixels>")
            end
        elseif cmd == "names" then
            FrameLayoutConfigUIEngine:ToggleFrameNames()
            print("Frame names: " .. (FrameLayoutConfigUIEngine.config.show_frame_names and "ON" or "OFF"))
        elseif cmd == "list" then
            local frames = FrameLayoutConfigUIEngine:ListFrames()
            print("Configured Frames (" .. #frames .. "):")
            for _, frame in ipairs(frames) do
                print("  " .. frame.name .. " at (" .. frame.x .. ", " .. frame.y .. ")")
            end
        elseif cmd == "reset" then
            if args == "confirm" then
                FrameLayoutConfigUIEngine:ResetAllPositions()
                print("All positions reset")
            else
                print("Usage: /framelayout reset confirm")
            end
        elseif cmd == "status" then
            local status = FrameLayoutConfigUIEngine:GetStatus()
            print("Frame Layout Configuration:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Frame Layout Commands:")
            print("  /framelayout edit <on|off> - Toggle edit mode")
            print("  /framelayout grid <show|snap> - Toggle grid display/snapping")
            print("  /framelayout gridsize <pixels> - Set grid size")
            print("  /framelayout names - Toggle frame name display")
            print("  /framelayout list - List all configured frames")
            print("  /framelayout reset confirm - Reset to defaults")
            print("  /framelayout status - Show system status")
        end
    end
end

return FrameLayoutConfigUIEngine
