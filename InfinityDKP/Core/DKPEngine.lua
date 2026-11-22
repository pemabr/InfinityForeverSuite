-- DKP Engine
-- Core point management system (DKP, EPGP, SK, Zero-Sum)

local InfinityDKPEngine = {}
_G.InfinityDKPEngine = InfinityDKPEngine

-- System types
InfinityDKPEngine.SYSTEM_DKP = "dkp"
InfinityDKPEngine.SYSTEM_EPGP = "epgp"
InfinityDKPEngine.SYSTEM_SK = "sk"
InfinityDKPEngine.SYSTEM_ZERO = "zero"

-- Player data
InfinityDKPEngine.players = {}
InfinityDKPEngine.system_type = InfinityDKPEngine.SYSTEM_EPGP
InfinityDKPEngine.callbacks = {}

function InfinityDKPEngine:Initialize()
    local db = InfinityCore:GetDatabase("InfinityDKP")
    if type(db) ~= "table" then
        error("InfinityDKP database unavailable")
    end
    if db.players == nil then db.players = {} end
    if type(db.players) ~= "table" then
        error("Invalid saved DKP player data")
    end
    local systemType = db.system_type or self.SYSTEM_EPGP
    if systemType ~= self.SYSTEM_DKP and systemType ~= self.SYSTEM_EPGP
        and systemType ~= self.SYSTEM_SK and systemType ~= self.SYSTEM_ZERO then
        error("Invalid saved DKP system type")
    end
    self.db, self.players, self.system_type = db, db.players, systemType
end

-- Initialize player in system
function InfinityDKPEngine:AddPlayer(playerName, class, rank)
    if type(playerName) ~= "string" or playerName == "" or self.players[playerName] then return false end
    
    self.players[playerName] = {
        name = playerName,
        class = class or "UNKNOWN",
        rank = rank or 1,
        ep = 0,
        gp = 0,
        dkp = 0,
        sk_position = 999,
        join_date = time(),
        last_seen = time(),
        notes = "",
    }
    
    self:TriggerCallback("player_added", playerName)
    return true
end

function InfinityDKPEngine:RemovePlayer(playerName)
    if self.players[playerName] then
        self.players[playerName] = nil
        self:TriggerCallback("player_removed", playerName)
        return true
    end
    return false
end

function InfinityDKPEngine:GetPlayer(playerName)
    return self.players[playerName]
end

function InfinityDKPEngine:GetAllPlayers()
    return self.players
end

-- Award points
function InfinityDKPEngine:AwardEP(playerName, amount, reason)
    local player = self.players[playerName]
    if not player then return false end
    
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    
    player.ep = (player.ep or 0) + amount
    player.last_seen = time()
    
    self:TriggerCallback("ep_awarded", playerName, amount, reason)
    return true
end

function InfinityDKPEngine:AwardGP(playerName, amount, itemName, reason)
    local player = self.players[playerName]
    if not player then return false end
    
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    
    player.gp = (player.gp or 0) + amount
    player.last_seen = time()
    
    self:TriggerCallback("gp_awarded", playerName, amount, itemName, reason)
    return true
end

function InfinityDKPEngine:AdjustDKP(playerName, amount, reason)
    if _G.issecretvalue and (_G.issecretvalue(playerName) or _G.issecretvalue(amount)) then return false end
    if type(playerName) ~= "string" or playerName == "" then return false end
    local player = self.players[playerName]
    if _G.issecretvalue and _G.issecretvalue(player) then return false end
    if type(player) ~= "table" or type(amount) ~= "number" or amount ~= amount or amount == 0
        or math.abs(amount) > 1000000000 or amount ~= math.floor(amount) then return false end
    local previous = player.dkp
    if _G.issecretvalue and _G.issecretvalue(previous) then return false end
    if previous == nil then previous = 0 end
    if type(previous) ~= "number" or previous ~= previous or math.abs(previous) > 1000000000 then return false end
    local updated = previous + amount
    if math.abs(updated) > 1000000000 then return false end
    player.dkp = updated
    player.last_seen = time()
    self:TriggerCallback("dkp_adjusted", playerName, amount, reason)
    return true
end

function InfinityDKPEngine:RefundGP(playerName, amount, reason)
    if _G.issecretvalue and (_G.issecretvalue(playerName) or _G.issecretvalue(amount)) then return false end
    if type(playerName) ~= "string" or playerName == "" or type(amount) ~= "number"
        or amount ~= amount or amount <= 0 or amount > 1000000000 or amount ~= math.floor(amount) then return false end
    local player = self.players[playerName]
    if _G.issecretvalue and _G.issecretvalue(player) then return false end
    if type(player) ~= "table" then return false end
    local gp = player.gp
    if _G.issecretvalue and _G.issecretvalue(gp) then return false end
    if type(gp) ~= "number" or gp ~= gp or gp < amount or gp > 1000000000 then return false end
    player.gp = gp - amount
    player.last_seen = time()
    self:TriggerCallback("gp_refunded", playerName, amount, reason)
    return true
end

function InfinityDKPEngine:TransferDKP(fromName, toName, amount)
    if _G.issecretvalue and (_G.issecretvalue(fromName) or _G.issecretvalue(toName) or _G.issecretvalue(amount)) then return false end
    if type(fromName) ~= "string" or type(toName) ~= "string" or fromName == toName
        or type(amount) ~= "number" or amount ~= amount or amount <= 0
        or amount > 1000000000 or amount ~= math.floor(amount) then return false end
    local from, to = self.players[fromName], self.players[toName]
    if type(from) ~= "table" or type(to) ~= "table" then return false end
    local fromBalance, toBalance = from.dkp, to.dkp
    if _G.issecretvalue and (_G.issecretvalue(fromBalance) or _G.issecretvalue(toBalance)) then return false end
    if fromBalance == nil then fromBalance = 0 end
    if toBalance == nil then toBalance = 0 end
    if type(fromBalance) ~= "number" or fromBalance ~= fromBalance or fromBalance < amount
        or fromBalance > 1000000000 or type(toBalance) ~= "number" or toBalance ~= toBalance
        or math.abs(toBalance) > 1000000000 or toBalance + amount > 1000000000 then return false end
    local now = time()
    from.dkp, to.dkp = fromBalance - amount, toBalance + amount
    from.last_seen, to.last_seen = now, now
    return true
end

-- Calculate priority
function InfinityDKPEngine:CalculatePriority(playerName)
    local player = self.players[playerName]
    if not player then return 0 end
    
    if self.system_type == self.SYSTEM_EPGP then
        local gp = math.max(1, player.gp or 0)
        return (player.ep or 0) / gp
    elseif self.system_type == self.SYSTEM_DKP then
        return player.dkp or 0
    elseif self.system_type == self.SYSTEM_SK then
        return player.sk_position or 999
    end
    
    return 0
end

-- Get ranked list
function InfinityDKPEngine:GetRankedPlayers()
    local ranked = {}
    
    for name, player in pairs(self.players) do
        table.insert(ranked, {
            name = player.name or name,
            ep = player.ep or 0,
            gp = player.gp or 0,
            dkp = player.dkp or 0,
            priority = self:CalculatePriority(name),
            class = player.class,
        })
    end
    
    -- Sort by priority (descending)
    table.sort(ranked, function(a, b)
        if self.system_type == self.SYSTEM_SK then return a.priority < b.priority end
        return a.priority > b.priority
    end)
    
    return ranked
end

-- Apply EP decay
function InfinityDKPEngine:ApplyEPDecay(decayPercent)
    decayPercent = tonumber(decayPercent) or 10
    local factor = (100 - decayPercent) / 100
    
    for name, player in pairs(self.players) do
        player.ep = math.floor(player.ep * factor)
    end
    
    self:TriggerCallback("decay_applied", decayPercent)
end

function InfinityDKPEngine:SetSystemType(systemType)
    if systemType ~= self.SYSTEM_DKP and systemType ~= self.SYSTEM_EPGP
        and systemType ~= self.SYSTEM_SK and systemType ~= self.SYSTEM_ZERO then
        return false
    end
    self.system_type = systemType
    self.db.system_type = systemType
    self:TriggerCallback("system_changed", systemType)
    return true
end

function InfinityDKPEngine:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityDKPEngine:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityDKPEngine:GetStats()
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

return InfinityDKPEngine
