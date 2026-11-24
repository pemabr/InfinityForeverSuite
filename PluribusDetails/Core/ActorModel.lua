-- Actor Model
-- Individual actor tracking (players, pets, bosses)

local PluribusDetailsActor = {}
_G.PluribusDetailsActor = PluribusDetailsActor

-- Actor data structure
local Actor = {}
Actor.__index = Actor

function Actor:new(guid, name, class, isPlayer)
    local a = {
        guid = guid,
        name = name,
        class = class,
        isPlayer = isPlayer,
        damage_total = 0,
        damage_hits = 0,
        damage_crits = 0,
        damage_avg = 0,
        healing_total = 0,
        healing_hits = 0,
        healing_crits = 0,
        healing_overheal = 0,
        threat_total = 0,
        deaths = 0,
        overkill_total = 0,
        first_seen = GetTime(),
        last_seen = GetTime(),
        absorbs = 0,
    }
    setmetatable(a, Actor)
    return a
end

function Actor:RecordDamage(amount, overkill, crit)
    self.damage_total = self.damage_total + amount
    self.damage_hits = self.damage_hits + 1
    if crit then self.damage_crits = self.damage_crits + 1 end
    self.overkill_total = self.overkill_total + (overkill or 0)
    self.damage_avg = self.damage_total / self.damage_hits
    self.last_seen = GetTime()
end

function Actor:RecordHealing(amount, overheal, crit)
    self.healing_total = self.healing_total + amount
    self.healing_hits = self.healing_hits + 1
    if crit then self.healing_crits = self.healing_crits + 1 end
    self.healing_overheal = self.healing_overheal + (overheal or 0)
    self.last_seen = GetTime()
end

function Actor:RecordThreat(amount)
    self.threat_total = self.threat_total + amount
    self.last_seen = GetTime()
end

function Actor:RecordDeath()
    self.deaths = self.deaths + 1
    self.last_seen = GetTime()
end

function Actor:GetDPS(duration)
    if duration <= 0 then return 0 end
    return self.damage_total / duration
end

function Actor:GetHPS(duration)
    if duration <= 0 then return 0 end
    return self.healing_total / duration
end

function Actor:GetTPS(duration)
    if duration <= 0 then return 0 end
    return self.threat_total / duration
end

function Actor:GetCritRate(type)
    type = type or "damage"
    if type == "damage" and self.damage_hits > 0 then
        return (self.damage_crits / self.damage_hits) * 100
    elseif type == "healing" and self.healing_hits > 0 then
        return (self.healing_crits / self.healing_hits) * 100
    end
    return 0
end

function Actor:Export()
    return {
        guid = self.guid,
        name = self.name,
        class = self.class,
        isPlayer = self.isPlayer,
        damage_total = self.damage_total,
        damage_hits = self.damage_hits,
        damage_crits = self.damage_crits,
        damage_avg = self.damage_avg,
        healing_total = self.healing_total,
        healing_hits = self.healing_hits,
        healing_crits = self.healing_crits,
        healing_overheal = self.healing_overheal,
        threat_total = self.threat_total,
        deaths = self.deaths,
    }
end

-- Actor Manager
PluribusDetailsActor.actors = {}
PluribusDetailsActor.callbacks = {}

function PluribusDetailsActor:GetOrCreateActor(guid, name, class, isPlayer)
    if not self.actors[guid] then
        self.actors[guid] = Actor:new(guid, name, class, isPlayer)
        self:TriggerCallback("actor_created", guid, name)
    end
    return self.actors[guid]
end

function PluribusDetailsActor:GetActor(guid)
    return self.actors[guid]
end

function PluribusDetailsActor:GetAllActors()
    return self.actors
end

function PluribusDetailsActor:GetTopDamageDealers(limit)
    limit = limit or 10
    local sorted = {}
    
    for guid, actor in pairs(self.actors) do
        if actor.damage_total > 0 then
            table.insert(sorted, {guid = guid, actor = actor, dps = actor.damage_total})
        end
    end
    
    table.sort(sorted, function(a, b) return a.dps > b.dps end)
    
    local result = {}
    for i = 1, math.min(limit, #sorted) do
        table.insert(result, sorted[i].actor)
    end
    
    return result
end

function PluribusDetailsActor:GetTopHealers(limit)
    limit = limit or 10
    local sorted = {}
    
    for guid, actor in pairs(self.actors) do
        if actor.healing_total > 0 then
            table.insert(sorted, {guid = guid, actor = actor, hps = actor.healing_total})
        end
    end
    
    table.sort(sorted, function(a, b) return a.hps > b.hps end)
    
    local result = {}
    for i = 1, math.min(limit, #sorted) do
        table.insert(result, sorted[i].actor)
    end
    
    return result
end

function PluribusDetailsActor:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusDetailsActor:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusDetailsActor:Clear()
    self.actors = {}
end

return PluribusDetailsActor
