-- WindowManagementEngine.lua - Manage multiple independent analysis windows
-- Part of InfinityDetails addon suite
-- Provides window positioning, sizing, profiles, and persistence

local WindowManagementEngine = {}
WindowManagementEngine.enabled = false
WindowManagementEngine.db = nil
WindowManagementEngine.windows = {}
WindowManagementEngine.profiles = {}

-- Configuration
WindowManagementEngine.config = {
    enabled = true,
    max_windows = 10,
    default_width = 400,
    default_height = 300,
}

function WindowManagementEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.windows then
        self.db.windows = {}
    end
    
    if not self.db.profiles then
        self.db.profiles = {}
    end
    
    self.windows = self.db.windows
    self.profiles = self.db.profiles
    self.enabled = true
    
    self:Log("Initialized window management engine")
end

function WindowManagementEngine:CreateWindow(windowName, windowType)
    if not windowName or not windowType then
        return nil
    end
    
    if #self.windows >= self.config.max_windows then
        self:Log("Max windows reached (" .. self.config.max_windows .. ")")
        return nil
    end
    
    local window = {
        id = "win_" .. GetTime(),
        name = windowName,
        type = windowType,
        created_at = GetTime(),
        x = 100,
        y = 100,
        width = self.config.default_width,
        height = self.config.default_height,
        visible = true,
        locked = false,
        profile = "default",
        config = {},
    }
    
    table.insert(self.windows, window)
    self:Log("Created window: " .. windowName .. " (" .. windowType .. ")")
    
    return window
end

function WindowManagementEngine:GetWindow(windowId)
    for _, window in ipairs(self.windows) do
        if window.id == windowId then
            return window
        end
    end
    
    return nil
end

function WindowManagementEngine:GetWindowsByType(windowType)
    local results = {}
    
    for _, window in ipairs(self.windows) do
        if window.type == windowType then
            table.insert(results, window)
        end
    end
    
    return results
end

function WindowManagementEngine:SetWindowPosition(windowId, x, y)
    local window = self:GetWindow(windowId)
    if not window then
        return false
    end
    
    window.x = x
    window.y = y
    
    return true
end

function WindowManagementEngine:SetWindowSize(windowId, width, height)
    local window = self:GetWindow(windowId)
    if not window then
        return false
    end
    
    window.width = math.max(200, width)  -- Min width 200
    window.height = math.max(150, height)  -- Min height 150
    
    return true
end

function WindowManagementEngine:SetWindowVisibility(windowId, visible)
    local window = self:GetWindow(windowId)
    if not window then
        return false
    end
    
    window.visible = visible
    
    return true
end

function WindowManagementEngine:LockWindow(windowId, locked)
    local window = self:GetWindow(windowId)
    if not window then
        return false
    end
    
    window.locked = locked
    
    return true
end

function WindowManagementEngine:SetWindowConfig(windowId, configKey, configValue)
    local window = self:GetWindow(windowId)
    if not window then
        return false
    end
    
    if not window.config then
        window.config = {}
    end
    
    window.config[configKey] = configValue
    
    return true
end

function WindowManagementEngine:GetWindowConfig(windowId, configKey)
    local window = self:GetWindow(windowId)
    if not window or not window.config then
        return nil
    end
    
    return window.config[configKey]
end

function WindowManagementEngine:DeleteWindow(windowId)
    for i, window in ipairs(self.windows) do
        if window.id == windowId then
            table.remove(self.windows, i)
            self:Log("Deleted window: " .. window.name)
            return true
        end
    end
    
    return false
end

function WindowManagementEngine:CreateProfile(profileName)
    if not profileName or self.profiles[profileName] then
        return false
    end
    
    self.profiles[profileName] = {
        name = profileName,
        created_at = GetTime(),
        windows = {},
    }
    
    self:Log("Created profile: " .. profileName)
    
    return true
end

function WindowManagementEngine:SaveProfileFromCurrentLayout(profileName)
    if not profileName then
        return false
    end
    
    if not self.profiles[profileName] then
        self:CreateProfile(profileName)
    end
    
    local profile = self.profiles[profileName]
    profile.windows = {}
    
    for _, window in ipairs(self.windows) do
        table.insert(profile.windows, {
            name = window.name,
            type = window.type,
            x = window.x,
            y = window.y,
            width = window.width,
            height = window.height,
            visible = window.visible,
            config = window.config,
        })
    end
    
    self:Log("Saved profile: " .. profileName)
    
    return true
end

function WindowManagementEngine:LoadProfile(profileName)
    local profile = self.profiles[profileName]
    if not profile then
        return false
    end
    
    -- Clear current windows
    self.windows = {}
    
    -- Recreate windows from profile
    for _, windowData in ipairs(profile.windows) do
        local window = {
            id = "win_" .. GetTime(),
            name = windowData.name,
            type = windowData.type,
            created_at = GetTime(),
            x = windowData.x,
            y = windowData.y,
            width = windowData.width,
            height = windowData.height,
            visible = windowData.visible,
            locked = false,
            profile = profileName,
            config = windowData.config or {},
        }
        
        table.insert(self.windows, window)
    end
    
    self:Log("Loaded profile: " .. profileName)
    
    return true
end

function WindowManagementEngine:DeleteProfile(profileName)
    if not self.profiles[profileName] then
        return false
    end
    
    self.profiles[profileName] = nil
    self:Log("Deleted profile: " .. profileName)
    
    return true
end

function WindowManagementEngine:ListProfiles()
    local list = {}
    
    for profileName, profile in pairs(self.profiles) do
        table.insert(list, {
            name = profileName,
            created_at = profile.created_at,
            window_count = #profile.windows,
        })
    end
    
    return list
end

function WindowManagementEngine:TileWindowsVertically()
    local screenWidth = 1920  -- Default assumption
    local screenHeight = 1080
    local cols = math.ceil(math.sqrt(#self.windows))
    local rows = math.ceil(#self.windows / cols)
    
    local winWidth = math.floor(screenWidth / cols)
    local winHeight = math.floor(screenHeight / rows)
    
    for i, window in ipairs(self.windows) do
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        
        window.x = col * winWidth
        window.y = row * winHeight
        window.width = winWidth - 10
        window.height = winHeight - 10
    end
    
    self:Log("Tiled " .. #self.windows .. " windows")
end

function WindowManagementEngine:CascadeWindows()
    local offset = 25
    
    for i, window in ipairs(self.windows) do
        window.x = 100 + (i - 1) * offset
        window.y = 100 + (i - 1) * offset
    end
    
    self:Log("Cascaded " .. #self.windows .. " windows")
end

function WindowManagementEngine:ResetAllWindowPositions()
    for i, window in ipairs(self.windows) do
        window.x = 100 + (i - 1) * 50
        window.y = 100 + (i - 1) * 50
        window.width = self.config.default_width
        window.height = self.config.default_height
    end
    
    self:Log("Reset all window positions")
end

function WindowManagementEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_windows = #self.windows,
        max_windows = self.config.max_windows,
        total_profiles = table.getn(self.profiles),
    }
end

function WindowManagementEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[WindowManagementEngine] " .. message)
    else
        print("[WindowManagementEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_WINDOW1 = "/window"
    SlashCmdList["WINDOW"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            local name = args or "Analysis Window"
            local window = WindowManagementEngine:CreateWindow(name, "metrics")
            if window then
                print("Created window: " .. window.name .. " (ID: " .. window.id .. ")")
            else
                print("Failed to create window")
            end
        elseif cmd == "list" then
            local windows = WindowManagementEngine.windows
            print("Windows (" .. #windows .. "/" .. WindowManagementEngine.config.max_windows .. "):")
            for i, window in ipairs(windows) do
                print("  [" .. i .. "] " .. window.name .. " (" .. window.type .. ") " ..
                      (window.visible and "[VISIBLE]" or "[HIDDEN]"))
            end
        elseif cmd == "tile" then
            WindowManagementEngine:TileWindowsVertically()
            print("Windows tiled")
        elseif cmd == "cascade" then
            WindowManagementEngine:CascadeWindows()
            print("Windows cascaded")
        elseif cmd == "reset" then
            WindowManagementEngine:ResetAllWindowPositions()
            print("Window positions reset")
        elseif cmd == "profile" then
            local subCmd, profileName = args:match("^(%S*)%s*(.*)$")
            
            if subCmd == "save" then
                WindowManagementEngine:SaveProfileFromCurrentLayout(profileName or "default")
                print("Profile saved: " .. (profileName or "default"))
            elseif subCmd == "load" then
                WindowManagementEngine:LoadProfile(profileName or "default")
                print("Profile loaded: " .. (profileName or "default"))
            elseif subCmd == "list" then
                local profiles = WindowManagementEngine:ListProfiles()
                print("Profiles (" .. #profiles .. "):")
                for _, profile in ipairs(profiles) do
                    print("  " .. profile.name .. " (" .. profile.window_count .. " windows)")
                end
            elseif subCmd == "delete" then
                WindowManagementEngine:DeleteProfile(profileName)
                print("Profile deleted: " .. profileName)
            end
        elseif cmd == "status" then
            local status = WindowManagementEngine:GetStatus()
            print("Window Management:")
            print("  Windows: " .. status.total_windows .. "/" .. status.max_windows)
            print("  Profiles: " .. status.total_profiles)
        else
            print("Window Commands:")
            print("  /window create [name] - Create new window")
            print("  /window list - List all windows")
            print("  /window tile - Tile windows")
            print("  /window cascade - Cascade windows")
            print("  /window reset - Reset positions")
            print("  /window profile save [name] - Save layout")
            print("  /window profile load [name] - Load layout")
            print("  /window profile list - List layouts")
        end
    end
end

return WindowManagementEngine
