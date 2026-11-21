-- Combat Detection System
-- Detects raid encounters and tracks combat state

local InfinityEncounterCD = {}
_G.InfinityEncounterCD = InfinityEncounterCD

-- Combat state tracking
InfinityEncounterCD.state = "idle" -- idle, in_combat, between, victory, wipe
InfinityEncounterCD.current_encounter = nil
InfinityEncounterCD.boss_units = {}
InfinityEncounterCD.combat_start_time = nil
InfinityEncounterCD.boss_deaths = {}
InfinityEncounterCD.callbacks = {}

function InfinityEncounterCD:IsInCombat()
    return self.state == "in_combat"
end

function InfinityEncounterCD:GetCurrentEncounter()
    return self.current_encounter
end

function InfinityEncounterCD:GetCombatDuration()
    if not self.combat_start_time then return 0 end
    return GetTime() - self.combat_start_time
end

function InfinityEncounterCD:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityEncounterCD:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityEncounterCD:DetectBoss()
    -- Check bosses in target/focus/boss frames
    for _, unitID in ipairs({"boss1", "boss2", "boss3", "boss4", "target", "focus"}) do
        if UnitExists(unitID) and InfinityUtils:IsRaidBoss(unitID) then
            self.boss_units[unitID] = true
            return true
        end
    end
    
    return false
end

function InfinityEncounterCD:UpdateCombatState()
    local inCombat = UnitAffectingCombat("player")
    local detectBoss = self:DetectBoss()
    
    if not inCombat and not detectBoss then
        if self.state == "in_combat" then
            self.state = "between"
            self:TriggerCallback("combat_ended", self:GetCombatDuration())
        end
        return
    end
    
    if inCombat and detectBoss then
        if self.state ~= "in_combat" then
            self.state = "in_combat"
            self.combat_start_time = GetTime()
            self:TriggerCallback("combat_started", self.current_encounter)
        end
    end
end

function InfinityEncounterCD:Reset()
    self.state = "idle"
    self.current_encounter = nil
    self.boss_units = {}
    self.combat_start_time = nil
    self.boss_deaths = {}
end

-- Event handlers
function InfinityEncounterCD:OnCombatLogEvent(...)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, 
          destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool = ...
    
    -- Detect boss death
    if subevent == "UNIT_DIED" then
        if bit.band(destFlags or 0, COMBATLOG_OBJECT_RAIDTARGET) ~= 0 or InfinityUtils:IsRaidBoss("target") then
            table.insert(self.boss_deaths, {
                name = destName,
                time = GetTime(),
                duration = self:GetCombatDuration()
            })
            self:TriggerCallback("boss_died", destName, self:GetCombatDuration())
        end
    end
    
    -- Detect phase change patterns (ability usage)
    if subevent == "SPELL_CAST_SUCCESS" then
        local isBoss = false
        for _, unitID in ipairs({"boss1", "boss2", "boss3", "boss4", "target", "focus"}) do
            if UnitExists(unitID) and UnitGUID(unitID) == sourceGUID and InfinityUtils:IsRaidBoss(unitID) then
                isBoss = true
                break
            end
        end
        if isBoss then
            self:TriggerCallback("ability_cast", sourceName, spellName, spellID)
        end
    end
end

return InfinityEncounterCD
