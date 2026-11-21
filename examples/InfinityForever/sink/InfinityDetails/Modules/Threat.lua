-- Threat Module
-- Threat tracking and tank monitoring

local InfinityDetailsThreat = {}
_G.InfinityDetailsThreat = InfinityDetailsThreat

InfinityDetailsThreat.threat_table = {}
InfinityDetailsThreat.callbacks = {}

function InfinityDetailsThreat:UpdateThreat(guid, name, threat, isTank)
    self.threat_table[guid] = {
        name = name,
        threat = threat or 0,
        isTank = isTank or false,
        last_update = GetTime(),
    }
end

function InfinityDetailsThreat:GetThreatTable()
    return self.threat_table
end

function InfinityDetailsThreat:GetTankThreat()
    local tanks = {}
    
    for guid, data in pairs(self.threat_table) do
        if data.isTank then
            table.insert(tanks, {
                guid = guid,
                name = data.name,
                threat = data.threat,
            })
        end
    end
    
    table.sort(tanks, function(a, b) return a.threat > b.threat end)
    return tanks
end

function InfinityDetailsThreat:GetHighestThreat()
    local highest = nil
    local maxThreat = 0
    
    for guid, data in pairs(self.threat_table) do
        if data.threat > maxThreat then
            maxThreat = data.threat
            highest = data
        end
    end
    
    return highest
end

function InfinityDetailsThreat:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityDetailsThreat:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityDetailsThreat:Clear()
    self.threat_table = {}
end

return InfinityDetailsThreat
