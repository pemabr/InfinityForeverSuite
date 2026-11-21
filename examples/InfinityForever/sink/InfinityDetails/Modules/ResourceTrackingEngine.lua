-- ResourceTrackingEngine.lua - Track resource usage (mana, energy, rage, focus)
-- Part of InfinityDetails addon suite
-- Provides resource consumption and resource event tracking

local ResourceTrackingEngine = {}
ResourceTrackingEngine.enabled = false
ResourceTrackingEngine.db = nil
ResourceTrackingEngine.resource_data = {}

-- Configuration
ResourceTrackingEngine.config = {
    enabled = true,
    max_snapshots = 1000,
}

-- Resource types
ResourceTrackingEngine.resource_types = {
    MANA = { type = 0, name = "Mana", unit = "points" },
    RAGE = { type = 1, name = "Rage", unit = "points" },
    FOCUS = { type = 2, name = "Focus", unit = "points" },
    ENERGY = { type = 3, name = "Energy", unit = "points" },
    RUNIC_POWER = { type = 4, name = "Runic Power", unit = "points" },
    RUNE = { type = 5, name = "Rune", unit = "charges" },
}

function ResourceTrackingEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.resource_tracking then
        self.db.resource_tracking = {
            actors = {},
        }
    end
    
    self.resource_data = self.db.resource_tracking
    self.enabled = true
    
    self:Log("Initialized resource tracker")
end

function ResourceTrackingEngine:RecordResourceEvent(actorGUID, actorName, resourceType, amount, maxAmount, event)
    if not actorGUID or not resourceType or not amount then
        return false
    end
    
    -- Create actor entry if not exists
    if not self.resource_data.actors[actorGUID] then
        self.resource_data.actors[actorGUID] = {
            name = actorName,
            guid = actorGUID,
            resources = {},
        }
    end
    
    local actorData = self.resource_data.actors[actorGUID]
    
    -- Create resource entry if not exists
    if not actorData.resources[resourceType] then
        actorData.resources[resourceType] = {
            type = resourceType,
            current = 0,
            max = maxAmount or 0,
            history = {},
            events = {},
            total_gained = 0,
            total_spent = 0,
        }
    end
    
    local resourceData = actorData.resources[resourceType]
    local previousAmount = resourceData.current
    
    -- Update current amount
    resourceData.current = amount
    if maxAmount then
        resourceData.max = maxAmount
    end
    
    -- Calculate change
    local change = amount - previousAmount
    
    -- Track in history
    local entry = {
        timestamp = GetTime(),
        amount = amount,
        max = maxAmount,
        change = change,
        event = event,
    }
    
    table.insert(resourceData.history, entry)
    
    -- Trim if too many
    if #resourceData.history > self.config.max_snapshots then
        table.remove(resourceData.history, 1)
    end
    
    -- Track gain/spend
    if change > 0 then
        resourceData.total_gained = resourceData.total_gained + change
    elseif change < 0 then
        resourceData.total_spent = resourceData.total_spent + math.abs(change)
    end
    
    return true
end

function ResourceTrackingEngine:GetActorResources(actorGUID)
    if not actorGUID or not self.resource_data.actors[actorGUID] then
        return nil
    end
    
    local actorData = self.resource_data.actors[actorGUID]
    local resources = {}
    
    for resourceType, resourceData in pairs(actorData.resources) do
        table.insert(resources, {
            type = resourceType,
            current = resourceData.current,
            max = resourceData.max,
            percent = resourceData.max > 0 and (resourceData.current / resourceData.max * 100) or 0,
            total_gained = resourceData.total_gained,
            total_spent = resourceData.total_spent,
        })
    end
    
    return resources
end

function ResourceTrackingEngine:GetResourceAmount(actorGUID, resourceType)
    if not actorGUID or not resourceType or not self.resource_data.actors[actorGUID] then
        return nil
    end
    
    local actorData = self.resource_data.actors[actorGUID]
    local resourceData = actorData.resources[resourceType]
    
    if not resourceData then
        return nil
    end
    
    return {
        type = resourceType,
        current = resourceData.current,
        max = resourceData.max,
        percent = resourceData.max > 0 and (resourceData.current / resourceData.max * 100) or 0,
    }
end

function ResourceTrackingEngine:GetResourceHistory(actorGUID, resourceType, maxCount)
    if not actorGUID or not resourceType or not self.resource_data.actors[actorGUID] then
        return {}
    end
    
    if not maxCount then
        maxCount = 50
    end
    
    local actorData = self.resource_data.actors[actorGUID]
    local resourceData = actorData.resources[resourceType]
    
    if not resourceData then
        return {}
    end
    
    local history = resourceData.history
    local startIdx = math.max(1, #history - maxCount + 1)
    
    local timeline = {}
    for i = startIdx, #history do
        table.insert(timeline, history[i])
    end
    
    return timeline
end

function ResourceTrackingEngine:GetResourceStats(actorGUID, resourceType)
    if not actorGUID or not resourceType or not self.resource_data.actors[actorGUID] then
        return nil
    end
    
    local actorData = self.resource_data.actors[actorGUID]
    local resourceData = actorData.resources[resourceType]
    
    if not resourceData then
        return nil
    end
    
    local events = #resourceData.history
    local avgAmount = 0
    
    for _, event in ipairs(resourceData.history) do
        avgAmount = avgAmount + event.amount
    end
    
    if events > 0 then
        avgAmount = avgAmount / events
    end
    
    return {
        type = resourceType,
        current = resourceData.current,
        max = resourceData.max,
        average = avgAmount,
        total_gained = resourceData.total_gained,
        total_spent = resourceData.total_spent,
        avg_per_event = events > 0 and ((resourceData.total_gained - resourceData.total_spent) / events) or 0,
        event_count = events,
    }
end

function ResourceTrackingEngine:GetAllActorResources()
    local all = {}
    
    for guid, actorData in pairs(self.resource_data.actors) do
        local resources = self:GetActorResources(guid)
        if resources then
            table.insert(all, {
                name = actorData.name,
                guid = guid,
                resources = resources,
            })
        end
    end
    
    return all
end

function ResourceTrackingEngine:GetActorCount()
    local count = 0
    
    for _ in pairs(self.resource_data.actors) do
        count = count + 1
    end
    
    return count
end

function ResourceTrackingEngine:ClearData()
    self.resource_data.actors = {}
    self:Log("All resource data cleared")
end

function ResourceTrackingEngine:GetStatus()
    return {
        enabled = self.enabled,
        actor_count = self:GetActorCount(),
        max_snapshots = self.config.max_snapshots,
    }
end

function ResourceTrackingEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[ResourceTrackingEngine] " .. message)
    else
        print("[ResourceTrackingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_RESOURCE1 = "/resource"
    SlashCmdList["RESOURCE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "types" then
            print("Resource Types:")
            for resourceType, typeData in pairs(ResourceTrackingEngine.resource_types) do
                print("  " .. typeData.name .. " (" .. typeData.unit .. ")")
            end
        elseif cmd == "clear" then
            ResourceTrackingEngine:ClearData()
            print("Resource data cleared")
        elseif cmd == "status" then
            local status = ResourceTrackingEngine:GetStatus()
            print("Resource Tracker:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Resource Tracker Commands:")
            print("  /resource types - Show available resource types")
            print("  /resource status - Show system status")
            print("  /resource clear - Clear all data")
        end
    end
end

return ResourceTrackingEngine
