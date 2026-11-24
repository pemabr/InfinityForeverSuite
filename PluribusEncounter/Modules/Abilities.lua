-- Abilities Module
-- Track boss abilities, cooldowns, and special mechanics

local PluribusEncounterAbilities = {}
_G.PluribusEncounterAbilities = PluribusEncounterAbilities

PluribusEncounterAbilities.tracked_abilities = {}
PluribusEncounterAbilities.ability_history = {}
PluribusEncounterAbilities.callbacks = {}

-- Track ability usage
function PluribusEncounterAbilities:RegisterAbility(spellID, spellName, timer, options)
    options = options or {}
    
    self.tracked_abilities[spellID] = {
        id = spellID,
        name = spellName,
        timer = timer or 30,
        cooldown = options.cooldown or 60,
        alertTime = options.alertTime or 10,
        priority = options.priority or "normal",
        last_cast = nil,
        next_cast = nil,
        cast_count = 0,
    }
end

function PluribusEncounterAbilities:OnAbilityCast(spellID, spellName, castTime, duration)
    local ability = self.tracked_abilities[spellID]
    
    if not ability then
        ability = {
            id = spellID,
            name = spellName,
            timer = duration or 30,
            cooldown = 60,
            alertTime = 10,
            priority = "normal",
            last_cast = nil,
            next_cast = nil,
            cast_count = 0,
        }
        self.tracked_abilities[spellID] = ability
    end
    
    ability.last_cast = GetTime()
    ability.next_cast = GetTime() + (ability.cooldown or 60)
    ability.cast_count = (ability.cast_count or 0) + 1
    
    table.insert(self.ability_history, {
        spellID = spellID,
        name = spellName,
        time = GetTime(),
        duration = duration or 0,
    })
    
    self:TriggerCallback("ability_cast", spellID, spellName, castTime)
end

function PluribusEncounterAbilities:GetAbility(spellID)
    return self.tracked_abilities[spellID]
end

function PluribusEncounterAbilities:GetAbilityStatus(spellID)
    local ability = self.tracked_abilities[spellID]
    if not ability or not ability.last_cast then
        return "unknown"
    end
    
    local elapsed = GetTime() - ability.last_cast
    if elapsed < (ability.timer or 30) then
        return "active"
    elseif elapsed < (ability.cooldown or 60) then
        return "cooldown"
    else
        return "ready"
    end
end

function PluribusEncounterAbilities:GetUpcomingAbilities(lookAhead)
    lookAhead = lookAhead or 60
    local now = GetTime()
    local upcoming = {}
    
    for spellID, ability in pairs(self.tracked_abilities) do
        if ability.next_cast and ability.next_cast > now and ability.next_cast <= (now + lookAhead) then
            table.insert(upcoming, {
                spellID = spellID,
                name = ability.name,
                time = ability.next_cast,
                in_seconds = ability.next_cast - now,
                priority = ability.priority,
            })
        end
    end
    
    -- Sort by time
    table.sort(upcoming, function(a, b) return a.time < b.time end)
    return upcoming
end

function PluribusEncounterAbilities:GetAbilityHistory(spellID, limit)
    limit = limit or 10
    local result = {}
    
    for i = #self.ability_history, math.max(1, #self.ability_history - limit + 1), -1 do
        local entry = self.ability_history[i]
        if not spellID or entry.spellID == spellID then
            table.insert(result, 1, entry)
        end
    end
    
    return result
end

function PluribusEncounterAbilities:GetAbilityStats(spellID)
    local ability = self.tracked_abilities[spellID]
    if not ability then return nil end
    
    return {
        name = ability.name,
        cast_count = ability.cast_count,
        last_cast = ability.last_cast,
        next_cast = ability.next_cast,
        status = self:GetAbilityStatus(spellID),
    }
end

function PluribusEncounterAbilities:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusEncounterAbilities:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusEncounterAbilities:Reset()
    self.tracked_abilities = {}
    self.ability_history = {}
end

return PluribusEncounterAbilities
