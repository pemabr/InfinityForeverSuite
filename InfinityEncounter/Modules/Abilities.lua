-- Abilities Module
-- Track boss abilities, cooldowns, and special mechanics

local InfinityEncounterAbilities = {}
_G.InfinityEncounterAbilities = InfinityEncounterAbilities

InfinityEncounterAbilities.tracked_abilities = {}
InfinityEncounterAbilities.ability_history = {}
InfinityEncounterAbilities.callbacks = {}

local function Public(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

local function ValidSpellID(value)
    value = Public(value)
    return type(value) == "number" and value > 0 and value <= 1000000000 and value == math.floor(value)
end

function InfinityEncounterAbilities:InitializeWatches(db)
    if type(db) ~= "table" then
        InfinityUtils:Warning("Encounter watch settings are unavailable.", "Encounter")
        return false
    end
    if db.watchedSpells == nil then db.watchedSpells = {} end
    if type(db.watchedSpells) ~= "table" then
        InfinityUtils:Warning("Invalid saved encounter watch settings.", "Encounter")
        return false
    end
    self.watchedSpells, self.activeWatchedCasts = db.watchedSpells, {}
    return true
end

function InfinityEncounterAbilities:SetWatch(spellID, label)
    spellID, label = Public(spellID), Public(label)
    if not self.watchedSpells then
        InfinityUtils:Warning("Encounter watch settings are unavailable.", "Encounter")
        return false
    end
    if not ValidSpellID(spellID) or type(label) ~= "string" or label == ""
        or #label > 80 or label:find("[%z\1-\31]") then
        InfinityUtils:Warning("Invalid spell ID or alert label.", "Encounter")
        return false
    end
    self.watchedSpells[spellID] = label
    return true
end

function InfinityEncounterAbilities:RemoveWatch(spellID)
    spellID = Public(spellID)
    if not self.watchedSpells or not ValidSpellID(spellID) or not self.watchedSpells[spellID] then
        InfinityUtils:Warning("Watched spell not found.", "Encounter")
        return false
    end
    self.watchedSpells[spellID] = nil
    return true
end

function InfinityEncounterAbilities:OnWatchedCast(event, unit, spellID)
    unit, spellID = Public(unit), Public(spellID)
    if not self.watchedSpells or type(unit) ~= "string" then return end
    if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        self.activeWatchedCasts[unit] = nil
        return
    end
    if not ValidSpellID(spellID) then return end
    local label = Public(self.watchedSpells[spellID])
    if type(label) ~= "string" or label == "" then return end
    local previous = self.activeWatchedCasts[unit]
    if event == "UNIT_SPELLCAST_START" then
        self.activeWatchedCasts[unit] = { spellID = spellID, time = GetTime() }
        InfinityEncounterAlerts:SendAlert("Casting: " .. label, InfinityEncounterAlerts.LEVEL_WARNING)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        self.activeWatchedCasts[unit] = nil
        if not previous or previous.spellID ~= spellID or GetTime() - previous.time > 30 then
            InfinityEncounterAlerts:SendAlert("Cast: " .. label, InfinityEncounterAlerts.LEVEL_WARNING)
        end
    end
end

-- Track ability usage
function InfinityEncounterAbilities:RegisterAbility(spellID, spellName, timer, options)
    options = options or {}
    
    self.tracked_abilities[spellID] = {
        id = spellID,
        name = spellName,
        timer = timer,
        cooldown = options.cooldown,
        alertTime = options.alertTime or 10,
        priority = options.priority or "normal",
        last_cast = nil,
        next_cast = nil,
        cast_count = 0,
    }
end

function InfinityEncounterAbilities:OnAbilityCast(spellID, spellName, castTime, duration)
    local ability = self.tracked_abilities[spellID]
    
    if not ability then
        ability = {
            id = spellID,
            name = spellName,
            timer = duration,
            cooldown = nil,
            alertTime = 10,
            priority = "normal",
            last_cast = nil,
            next_cast = nil,
            cast_count = 0,
        }
        self.tracked_abilities[spellID] = ability
    end
    
    ability.last_cast = GetTime()
    ability.next_cast = type(ability.cooldown) == "number" and ability.cooldown > 0
        and (ability.last_cast + ability.cooldown) or nil
    ability.cast_count = (ability.cast_count or 0) + 1
    
    table.insert(self.ability_history, {
        spellID = spellID,
        name = spellName,
        time = GetTime(),
        duration = duration or 0,
    })
    
    self:TriggerCallback("ability_cast", spellID, spellName, castTime)
end

function InfinityEncounterAbilities:GetAbility(spellID)
    return self.tracked_abilities[spellID]
end

function InfinityEncounterAbilities:GetAbilityStatus(spellID)
    local ability = self.tracked_abilities[spellID]
    if not ability or not ability.last_cast then
        return "unknown"
    end
    
    local elapsed = GetTime() - ability.last_cast
    if type(ability.timer) == "number" and elapsed < ability.timer then
        return "active"
    elseif type(ability.cooldown) == "number" and elapsed < ability.cooldown then
        return "cooldown"
    elseif type(ability.cooldown) == "number" then
        return "ready"
    end
    return "unknown"
end

function InfinityEncounterAbilities:GetUpcomingAbilities(lookAhead)
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

function InfinityEncounterAbilities:GetAbilityHistory(spellID, limit)
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

function InfinityEncounterAbilities:GetAbilityStats(spellID)
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

function InfinityEncounterAbilities:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityEncounterAbilities:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityEncounterAbilities:Reset()
    self.tracked_abilities = {}
    self.ability_history = {}
    self.activeWatchedCasts = {}
end

return InfinityEncounterAbilities
