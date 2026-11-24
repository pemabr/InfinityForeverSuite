-- ResourceBreakdownEngine.lua - Analyze resource usage across raid
-- Part of PluribusDetails addon suite
-- Tracks mana, energy, rage, focus, runic power by player

local ResourceBreakdownEngine = {}
ResourceBreakdownEngine.enabled = false
ResourceBreakdownEngine.db = nil
ResourceBreakdownEngine.resource_data = {}

-- Configuration
ResourceBreakdownEngine.config = {
    enabled = true,
    track_types = {
        "MANA",
        "RAGE",
        "FOCUS",
        "ENERGY",
        "RUNIC_POWER",
        "RUNE",
    },
}

function ResourceBreakdownEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.resource_data then
        self.db.resource_data = {}
    end
    
    self.resource_data = self.db.resource_data
    self.enabled = true
    
    self:Log("Initialized resource breakdown engine")
end

function ResourceBreakdownEngine:RecordResourceEvent(playerName, resourceType, amount, maxAmount, timestamp)
    if not playerName or not resourceType or not amount then
        return false
    end
    
    if not self.resource_data[playerName] then
        self.resource_data[playerName] = {
            name = playerName,
            resources = {},
        }
    end
    
    if not self.resource_data[playerName].resources[resourceType] then
        self.resource_data[playerName].resources[resourceType] = {
            type = resourceType,
            events = {},
            total_capacity = maxAmount or 0,
            current = amount or 0,
        }
    end
    
    local resourceTrack = self.resource_data[playerName].resources[resourceType]
    
    local event = {
        time = timestamp or GetTime(),
        amount = amount,
        max_amount = maxAmount or 0,
        percent = maxAmount and maxAmount > 0 and (amount / maxAmount) * 100 or 0,
    }
    
    table.insert(resourceTrack.events, event)
    
    -- Keep only recent events (last 1000)
    if #resourceTrack.events > 1000 then
        table.remove(resourceTrack.events, 1)
    end
    
    resourceTrack.current = amount
    
    return true
end

function ResourceBreakdownEngine:GetPlayerResourceUsage(playerName, resourceType)
    if not playerName or not self.resource_data[playerName] then
        return nil
    end
    
    if resourceType then
        return self.resource_data[playerName].resources[resourceType]
    else
        return self.resource_data[playerName].resources
    end
end

function ResourceBreakdownEngine:GetResourceAverageByPlayer(playerName, resourceType)
    local resources = self:GetPlayerResourceUsage(playerName, resourceType)
    
    if not resources or not resources.events or #resources.events == 0 then
        return 0
    end
    
    local sum = 0
    
    for _, event in ipairs(resources.events) do
        sum = sum + event.amount
    end
    
    return sum / #resources.events
end

function ResourceBreakdownEngine:GetResourceMinByPlayer(playerName, resourceType)
    local resources = self:GetPlayerResourceUsage(playerName, resourceType)
    
    if not resources or not resources.events or #resources.events == 0 then
        return 0
    end
    
    local min = math.huge
    
    for _, event in ipairs(resources.events) do
        if event.amount < min then
            min = event.amount
        end
    end
    
    return min == math.huge and 0 or min
end

function ResourceBreakdownEngine:GetResourceMaxByPlayer(playerName, resourceType)
    local resources = self:GetPlayerResourceUsage(playerName, resourceType)
    
    if not resources or not resources.events or #resources.events == 0 then
        return 0
    end
    
    local max = 0
    
    for _, event in ipairs(resources.events) do
        if event.amount > max then
            max = event.amount
        end
    end
    
    return max
end

function ResourceBreakdownEngine:GetDepletion(playerName, resourceType)
    local resources = self:GetPlayerResourceUsage(playerName, resourceType)
    
    if not resources or not resources.events or #resources.events < 2 then
        return 0
    end
    
    local depletionCount = 0
    
    for i = 2, #resources.events do
        if resources.events[i].percent < 10 then
            depletionCount = depletionCount + 1
        end
    end
    
    return depletionCount
end

function ResourceBreakdownEngine:GetResourceStats(playerName, resourceType)
    return {
        type = resourceType,
        average = self:GetResourceAverageByPlayer(playerName, resourceType),
        min = self:GetResourceMinByPlayer(playerName, resourceType),
        max = self:GetResourceMaxByPlayer(playerName, resourceType),
        depletions = self:GetDepletion(playerName, resourceType),
    }
end

function ResourceBreakdownEngine:GetTopResourceUsers(resourceType, limit)
    limit = limit or 5
    
    local players = {}
    
    for playerName, playerData in pairs(self.resource_data) do
        local resourceUsage = playerData.resources[resourceType]
        
        if resourceUsage then
            table.insert(players, {
                name = playerName,
                average = self:GetResourceAverageByPlayer(playerName, resourceType),
                current = resourceUsage.current,
            })
        end
    end
    
    table.sort(players, function(a, b)
        return a.average > b.average
    end)
    
    local results = {}
    for i = 1, math.min(limit, #players) do
        table.insert(results, players[i])
    end
    
    return results
end

function ResourceBreakdownEngine:GetResourceDistribution(resourceType)
    local distribution = {}
    
    for playerName, playerData in pairs(self.resource_data) do
        local resourceUsage = playerData.resources[resourceType]
        
        if resourceUsage then
            table.insert(distribution, {
                player = playerName,
                current = resourceUsage.current,
                average = self:GetResourceAverageByPlayer(playerName, resourceType),
                max = self:GetResourceMaxByPlayer(playerName, resourceType),
            })
        end
    end
    
    return distribution
end

function ResourceBreakdownEngine:GetPlayerList()
    local players = {}
    
    for playerName, _ in pairs(self.resource_data) do
        table.insert(players, playerName)
    end
    
    table.sort(players)
    
    return players
end

function ResourceBreakdownEngine:ClearOldData(hoursOld)
    hoursOld = hoursOld or 1
    local cutoffTime = GetTime() - (hoursOld * 3600)
    
    for playerName, playerData in pairs(self.resource_data) do
        for resourceType, resourceTrack in pairs(playerData.resources) do
            local newEvents = {}
            
            for _, event in ipairs(resourceTrack.events) do
                if event.time > cutoffTime then
                    table.insert(newEvents, event)
                end
            end
            
            resourceTrack.events = newEvents
        end
    end
    
    self:Log("Cleared resource data older than " .. hoursOld .. " hours")
end

function ResourceBreakdownEngine:GetStatus()
    local playerCount = 0
    
    for _ in pairs(self.resource_data) do
        playerCount = playerCount + 1
    end
    
    return {
        enabled = self.enabled,
        players_tracked = playerCount,
        resource_types = #self.config.track_types,
    }
end

function ResourceBreakdownEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[ResourceBreakdownEngine] " .. message)
    else
        print("[ResourceBreakdownEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_RESOURCE1 = "/resource"
    SlashCmdList["RESOURCE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "mana" then
            local topUsers = ResourceBreakdownEngine:GetTopResourceUsers("MANA", 5)
            print("Top Mana Users:")
            for i, player in ipairs(topUsers) do
                print("  [" .. i .. "] " .. player.name .. ": " .. 
                      string.format("%.0f", player.average) .. " avg")
            end
        elseif cmd == "energy" then
            local topUsers = ResourceBreakdownEngine:GetTopResourceUsers("ENERGY", 5)
            print("Top Energy Users:")
            for i, player in ipairs(topUsers) do
                print("  [" .. i .. "] " .. player.name .. ": " .. 
                      string.format("%.0f", player.average) .. " avg")
            end
        elseif cmd == "rage" then
            local topUsers = ResourceBreakdownEngine:GetTopResourceUsers("RAGE", 5)
            print("Top Rage Users:")
            for i, player in ipairs(topUsers) do
                print("  [" .. i .. "] " .. player.name .. ": " .. 
                      string.format("%.0f", player.average) .. " avg")
            end
        elseif cmd == "player" then
            local playerName = args
            if playerName then
                local stats = {}
                
                for _, resourceType in ipairs(ResourceBreakdownEngine.config.track_types) do
                    local resourceStats = ResourceBreakdownEngine:GetResourceStats(playerName, resourceType)
                    if resourceStats.average > 0 then
                        table.insert(stats, {
                            type = resourceType,
                            stats = resourceStats,
                        })
                    end
                end
                
                print("Resource Stats for " .. playerName .. ":")
                for _, resourceData in ipairs(stats) do
                    print("  " .. resourceData.type .. ":")
                    print("    Avg: " .. string.format("%.0f", resourceData.stats.average))
                    print("    Min: " .. string.format("%.0f", resourceData.stats.min))
                    print("    Max: " .. string.format("%.0f", resourceData.stats.max))
                end
            else
                print("Usage: /resource player <name>")
            end
        elseif cmd == "clear" then
            ResourceBreakdownEngine.resource_data = {}
            ResourceBreakdownEngine.db.resource_data = {}
            print("All resource data cleared")
        elseif cmd == "status" then
            local status = ResourceBreakdownEngine:GetStatus()
            print("Resource Breakdown:")
            print("  Players Tracked: " .. status.players_tracked)
            print("  Resource Types: " .. status.resource_types)
        else
            print("Resource Commands:")
            print("  /resource mana - Top mana users")
            print("  /resource energy - Top energy users")
            print("  /resource rage - Top rage users")
            print("  /resource player <name> - Player resource stats")
            print("  /resource status - Show system status")
            print("  /resource clear - Clear all data")
        end
    end
end

return ResourceBreakdownEngine
