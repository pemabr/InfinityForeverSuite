-- Deaths Module
-- Death tracking and analysis

local PluribusDetailsDeaths = {}
_G.PluribusDetailsDeaths = PluribusDetailsDeaths

PluribusDetailsDeaths.deaths = {}
PluribusDetailsDeaths.callbacks = {}

function PluribusDetailsDeaths:RecordDeath(playerName, killedBy, time)
    local death = {
        player = playerName,
        killedBy = killedBy or "Unknown",
        time = time or GetTime(),
        timestamp = date("%H:%M:%S"),
    }
    
    table.insert(self.deaths, death)
    self:TriggerCallback("player_death", playerName, killedBy)
    
    return death
end

function PluribusDetailsDeaths:GetDeaths()
    return self.deaths
end

function PluribusDetailsDeaths:GetDeathsByPlayer(playerName)
    local deaths = {}
    
    for _, death in ipairs(self.deaths) do
        if death.player == playerName then
            table.insert(deaths, death)
        end
    end
    
    return deaths
end

function PluribusDetailsDeaths:GetDeathCount()
    return #self.deaths
end

function PluribusDetailsDeaths:GetDeathList()
    local list = ""
    
    for _, death in ipairs(self.deaths) do
        list = list .. string.format("%s: %s killed by %s\n",
            death.timestamp, death.player, death.killedBy)
    end
    
    return list
end

function PluribusDetailsDeaths:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusDetailsDeaths:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusDetailsDeaths:Clear()
    self.deaths = {}
end

return PluribusDetailsDeaths
