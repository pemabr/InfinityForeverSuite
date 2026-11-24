-- DKP Engine
-- Core point management system (DKP, EPGP, SK, Zero-Sum)

local PluribusDKPEngine = {}
_G.PluribusDKPEngine = PluribusDKPEngine

-- System types
PluribusDKPEngine.SYSTEM_DKP = "dkp"
PluribusDKPEngine.SYSTEM_EPGP = "epgp"
PluribusDKPEngine.SYSTEM_SK = "sk"
PluribusDKPEngine.SYSTEM_ZERO = "zero"

-- Player data
PluribusDKPEngine.players = {}
PluribusDKPEngine.system_type = PluribusDKPEngine.SYSTEM_EPGP
PluribusDKPEngine.callbacks = {}

-- Initialize player in system
function PluribusDKPEngine:AddPlayer(playerName, class, rank)
    if not playerName then return false end
    
    self.players[playerName] = {
        name = playerName,
        class = class or "UNKNOWN",
        rank = rank or 1,
        ep = 0,
        gp = 0,
        dkp = 0,
        sk_position = 999,
        join_date = GetTime(),
        last_seen = GetTime(),
        notes = "",
    }
    
    self:TriggerCallback("player_added", playerName)
    return true
end

function PluribusDKPEngine:RemovePlayer(playerName)
    if self.players[playerName] then
        self.players[playerName] = nil
        self:TriggerCallback("player_removed", playerName)
        return true
    end
    return false
end

function PluribusDKPEngine:GetPlayer(playerName)
    return self.players[playerName]
end

function PluribusDKPEngine:GetAllPlayers()
    return self.players
end

-- Award points
function PluribusDKPEngine:AwardEP(playerName, amount, reason)
    local player = self.players[playerName]
    if not player then return false end
    
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    
    player.ep = (player.ep or 0) + amount
    player.last_seen = GetTime()
    
    self:TriggerCallback("ep_awarded", playerName, amount, reason)
    return true
end

function PluribusDKPEngine:AwardGP(playerName, amount, itemName, reason)
    local player = self.players[playerName]
    if not player then return false end
    
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    
    player.gp = (player.gp or 0) + amount
    player.last_seen = GetTime()
    
    self:TriggerCallback("gp_awarded", playerName, amount, itemName, reason)
    return true
end

-- Calculate priority
function PluribusDKPEngine:CalculatePriority(playerName)
    local player = self.players[playerName]
    if not player then return 0 end
    
    if self.system_type == self.SYSTEM_EPGP then
        local gp = math.max(1, player.gp)
        return player.ep / gp
    elseif self.system_type == self.SYSTEM_DKP then
        return player.dkp
    elseif self.system_type == self.SYSTEM_SK then
        return player.sk_position
    end
    
    return 0
end

-- Get ranked list
function PluribusDKPEngine:GetRankedPlayers()
    local ranked = {}
    
    for name, player in pairs(self.players) do
        table.insert(ranked, {
            name = name,
            ep = player.ep,
            gp = player.gp,
            dkp = player.dkp,
            priority = self:CalculatePriority(name),
            class = player.class,
        })
    end
    
    -- Sort by priority (descending)
    table.sort(ranked, function(a, b)
        return a.priority > b.priority
    end)
    
    return ranked
end

-- Apply EP decay
function PluribusDKPEngine:ApplyEPDecay(decayPercent)
    decayPercent = tonumber(decayPercent) or 10
    local factor = (100 - decayPercent) / 100
    
    for name, player in pairs(self.players) do
        player.ep = math.floor(player.ep * factor)
    end
    
    self:TriggerCallback("decay_applied", decayPercent)
end

function PluribusDKPEngine:SetSystemType(systemType)
    self.system_type = systemType
    self:TriggerCallback("system_changed", systemType)
end

function PluribusDKPEngine:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusDKPEngine:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusDKPEngine:GetStats()
    local total_players = 0
    local total_ep = 0
    local total_gp = 0
    
    for _, player in pairs(self.players) do
        total_players = total_players + 1
        total_ep = total_ep + (player.ep or 0)
        total_gp = total_gp + (player.gp or 0)
    end
    
    return {
        total_players = total_players,
        total_ep = total_ep,
        total_gp = total_gp,
        avg_ep = total_players > 0 and (total_ep / total_players) or 0,
        avg_gp = total_players > 0 and (total_gp / total_players) or 0,
    }
end

return PluribusDKPEngine
