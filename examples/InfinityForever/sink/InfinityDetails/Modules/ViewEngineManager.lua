-- ViewEngineManager.lua - Manage different view types (current, overall, segment, encounter)
-- Part of InfinityDetails addon suite
-- Provides view controllers for different data perspectives

local ViewEngineManager = {}
ViewEngineManager.enabled = false
ViewEngineManager.db = nil
ViewEngineManager.views = {}
ViewEngineManager.active_view = nil

-- Configuration
ViewEngineManager.config = {
    enabled = true,
    view_types = {
        "current",      -- Now playing
        "overall",      -- Entire raid session
        "segment",      -- Specific boss fight
        "encounter",    -- Compare all attempts
    },
}

function ViewEngineManager:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.views then
        self.db.views = {}
    end
    
    self.views = self.db.views
    self.enabled = true
    
    self:Log("Initialized view engine manager")
end

function ViewEngineManager:CreateView(viewName, viewType, viewData)
    if not viewName or not viewType then
        return nil
    end
    
    -- Validate view type
    local validType = false
    for _, vtype in ipairs(self.config.view_types) do
        if vtype == viewType then
            validType = true
            break
        end
    end
    
    if not validType then
        self:Log("Invalid view type: " .. viewType)
        return nil
    end
    
    local view = {
        id = "view_" .. GetTime(),
        name = viewName,
        type = viewType,
        created_at = GetTime(),
        data = viewData or {},
        last_updated = GetTime(),
        is_active = false,
    }
    
    table.insert(self.views, view)
    self:Log("Created view: " .. viewName .. " (" .. viewType .. ")")
    
    return view
end

function ViewEngineManager:GetView(viewId)
    for _, view in ipairs(self.views) do
        if view.id == viewId then
            return view
        end
    end
    
    return nil
end

function ViewEngineManager:GetViewsByType(viewType)
    local results = {}
    
    for _, view in ipairs(self.views) do
        if view.type == viewType then
            table.insert(results, view)
        end
    end
    
    return results
end

function ViewEngineManager:ActivateView(viewId)
    -- Deactivate current view
    if self.active_view then
        self.active_view.is_active = false
    end
    
    -- Activate new view
    local view = self:GetView(viewId)
    if view then
        view.is_active = true
        self.active_view = view
        self:Log("Activated view: " .. view.name)
        return true
    end
    
    return false
end

function ViewEngineManager:DeactivateView()
    if self.active_view then
        self.active_view.is_active = false
        self.active_view = nil
        self:Log("Deactivated view")
        return true
    end
    
    return false
end

function ViewEngineManager:UpdateViewData(viewId, newData)
    local view = self:GetView(viewId)
    if not view then
        return false
    end
    
    if type(newData) == "table" then
        for k, v in pairs(newData) do
            view.data[k] = v
        end
    end
    
    view.last_updated = GetTime()
    
    return true
end

-- Current Window View: Real-time combat data
function ViewEngineManager:GetCurrentViewData()
    if not self.active_view or self.active_view.type ~= "current" then
        return nil
    end
    
    return {
        type = "current",
        data = self.active_view.data,
        updated_ago = GetTime() - self.active_view.last_updated,
    }
end

-- Overall View: Entire raid session statistics
function ViewEngineManager:GetOverallViewData()
    if not self.active_view or self.active_view.type ~= "overall" then
        return nil
    end
    
    return {
        type = "overall",
        data = self.active_view.data,
        total_duration = self.active_view.data.duration or 0,
        total_damage = self.active_view.data.total_damage or 0,
        total_healing = self.active_view.data.total_healing or 0,
    }
end

-- Segment View: Specific boss fight data
function ViewEngineManager:GetSegmentViewData(segmentId)
    if not self.active_view or self.active_view.type ~= "segment" then
        return nil
    end
    
    if segmentId and self.active_view.data.segments then
        for _, segment in ipairs(self.active_view.data.segments) do
            if segment.id == segmentId then
                return segment
            end
        end
    end
    
    return self.active_view.data
end

-- Encounter View: Multiple attempt comparison
function ViewEngineManager:GetEncounterViewData(bossName)
    if not self.active_view or self.active_view.type ~= "encounter" then
        return nil
    end
    
    if bossName and self.active_view.data.attempts then
        local attempts = {}
        
        for _, attempt in ipairs(self.active_view.data.attempts) do
            if attempt.boss_name == bossName then
                table.insert(attempts, attempt)
            end
        end
        
        return {
            boss = bossName,
            attempts = attempts,
            total_attempts = #attempts,
        }
    end
    
    return self.active_view.data
end

function ViewEngineManager:DeleteView(viewId)
    for i, view in ipairs(self.views) do
        if view.id == viewId then
            if self.active_view and self.active_view.id == viewId then
                self.active_view = nil
            end
            
            table.remove(self.views, i)
            self:Log("Deleted view: " .. view.name)
            
            return true
        end
    end
    
    return false
end

function ViewEngineManager:ListViews()
    local list = {}
    
    for _, view in ipairs(self.views) do
        table.insert(list, {
            id = view.id,
            name = view.name,
            type = view.type,
            is_active = view.is_active,
            created_at = view.created_at,
        })
    end
    
    return list
end

function ViewEngineManager:GetStatus()
    return {
        enabled = self.enabled,
        total_views = #self.views,
        active_view = self.active_view and self.active_view.name or "None",
        view_types_supported = #self.config.view_types,
    }
end

function ViewEngineManager:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[ViewEngineManager] " .. message)
    else
        print("[ViewEngineManager] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_VIEW1 = "/view"
    SlashCmdList["VIEW"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            local views = ViewEngineManager:ListViews()
            print("Views (" .. #views .. "):")
            for i, view in ipairs(views) do
                print("  [" .. i .. "] " .. view.name .. " (" .. view.type .. ")")
                print("       " .. (view.is_active and "[ACTIVE]" or "[INACTIVE]"))
            end
        elseif cmd == "activate" then
            local index = tonumber(args)
            if index and ViewEngineManager.views[index] then
                local view = ViewEngineManager.views[index]
                ViewEngineManager:ActivateView(view.id)
                print("Activated view: " .. view.name)
            else
                print("Invalid view index")
            end
        elseif cmd == "deactivate" then
            ViewEngineManager:DeactivateView()
            print("View deactivated")
        elseif cmd == "current" then
            local data = ViewEngineManager:GetCurrentViewData()
            if data then
                print("Current View Data:")
                print("  Updated: " .. string.format("%.1f", data.updated_ago) .. "s ago")
            else
                print("No active current view")
            end
        elseif cmd == "overall" then
            local data = ViewEngineManager:GetOverallViewData()
            if data then
                print("Overall View:")
                print("  Duration: " .. string.format("%.1f", data.total_duration) .. "s")
                print("  Total Damage: " .. string.format("%.0f", data.total_damage))
                print("  Total Healing: " .. string.format("%.0f", data.total_healing))
            else
                print("No active overall view")
            end
        elseif cmd == "delete" then
            local index = tonumber(args)
            if index and ViewEngineManager.views[index] then
                local view = ViewEngineManager.views[index]
                ViewEngineManager:DeleteView(view.id)
                print("Deleted view: " .. view.name)
            else
                print("Invalid view index")
            end
        elseif cmd == "status" then
            local status = ViewEngineManager:GetStatus()
            print("View Engine:")
            print("  Total Views: " .. status.total_views)
            print("  Active View: " .. status.active_view)
            print("  Supported Types: " .. status.view_types_supported)
        else
            print("View Commands:")
            print("  /view list - List all views")
            print("  /view activate [index] - Activate view")
            print("  /view deactivate - Deactivate view")
            print("  /view current - Show current view data")
            print("  /view overall - Show overall view data")
            print("  /view delete [index] - Delete view")
            print("  /view status - Show system status")
        end
    end
end

return ViewEngineManager
