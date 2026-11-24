-- Threat Module
-- Threat tracking and tank monitoring

local PluribusDetailsThreat = {}
_G.PluribusDetailsThreat = PluribusDetailsThreat

PluribusDetailsThreat.threat_table = {}
PluribusDetailsThreat.callbacks = {}

function PluribusDetailsThreat:UpdateThreat(guid, name, threat, isTank)
    self.threat_table[guid] = {
        name = name,
        threat = threat or 0,
        isTank = isTank or false,
        last_update = GetTime(),
    }
end

function PluribusDetailsThreat:GetThreatTable()
    return self.threat_table
end

function PluribusDetailsThreat:GetTankThreat()
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

function PluribusDetailsThreat:GetHighestThreat()
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

function PluribusDetailsThreat:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusDetailsThreat:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusDetailsThreat:Clear()
    self.threat_table = {}
end

return PluribusDetailsThreat
