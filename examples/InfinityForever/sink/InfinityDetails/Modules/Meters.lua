-- Meters Module
-- DPS, HPS, and threat meters

local InfinityDetailsMeers = {}
_G.InfinityDetailsMeters = InfinityDetailsMeers

InfinityDetailsMeters.duration = 0
InfinityDetailsMeters.start_time = nil
InfinityDetailsMeters.callbacks = {}

function InfinityDetailsMeters:Start()
    self.start_time = GetTime()
    self.duration = 0
end

function InfinityDetailsMeters:Stop()
    self.duration = GetTime() - (self.start_time or GetTime())
end

function InfinityDetailsMeters:Update()
    if self.start_time then
        self.duration = GetTime() - self.start_time
    end
end

function InfinityDetailsMeters:GetDuration()
    return self.duration
end

function InfinityDetailsMeters:GetDPSMeter(limit)
    limit = limit or 20
    if not InfinityDetailsActor then return {} end
    
    local meters = {}
    local topDamagers = InfinityDetailsActor:GetTopDamageDealers(limit)
    
    for i, actor in ipairs(topDamagers) do
        table.insert(meters, {
            rank = i,
            name = actor.name,
            class = actor.class,
            dps = actor:GetDPS(self.duration),
            damage = actor.damage_total,
            hits = actor.damage_hits,
            crits = actor:GetCritRate("damage"),
            avg = actor.damage_avg,
        })
    end
    
    return meters
end

function InfinityDetailsMeters:GetHPSMeter(limit)
    limit = limit or 20
    if not InfinityDetailsActor then return {} end
    
    local meters = {}
    local topHealers = InfinityDetailsActor:GetTopHealers(limit)
    
    for i, actor in ipairs(topHealers) do
        table.insert(meters, {
            rank = i,
            name = actor.name,
            class = actor.class,
            hps = actor:GetHPS(self.duration),
            healing = actor.healing_total,
            overheal = actor.healing_overheal,
            hits = actor.healing_hits,
            crits = actor:GetCritRate("healing"),
        })
    end
    
    return meters
end

function InfinityDetailsMeters:GetThreatMeter(limit)
    limit = limit or 20
    if not InfinityDetailsActor then return {} end
    
    local meters = {}
    local actors = {}
    
    for guid, actor in pairs(InfinityDetailsActor:GetAllActors()) do
        if actor.threat_total > 0 then
            table.insert(actors, {guid = guid, actor = actor})
        end
    end
    
    table.sort(actors, function(a, b) return a.actor.threat_total > b.actor.threat_total end)
    
    for i = 1, math.min(limit, #actors) do
        local actor = actors[i].actor
        table.insert(meters, {
            rank = i,
            name = actor.name,
            class = actor.class,
            threat = actor.threat_total,
            tps = actor:GetTPS(self.duration),
        })
    end
    
    return meters
end

function InfinityDetailsMeters:ExportMeter(type, limit)
    type = type or "dps"
    limit = limit or 20
    
    local meter = nil
    if type == "dps" then
        meter = self:GetDPSMeter(limit)
    elseif type == "hps" then
        meter = self:GetHPSMeter(limit)
    elseif type == "threat" then
        meter = self:GetThreatMeter(limit)
    end
    
    if not meter then return "" end
    
    local export = string.format("=== %s Meter ===\n", type:upper())
    export = export .. string.format("Duration: %.1f seconds\n\n", self.duration)
    
    for _, entry in ipairs(meter) do
        export = export .. string.format("%d. %s: %.1f\n", entry.rank, entry.name, 
            entry.dps or entry.hps or entry.threat or 0)
    end
    
    return export
end

function InfinityDetailsMeters:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityDetailsMeters:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return InfinityDetailsMeters
