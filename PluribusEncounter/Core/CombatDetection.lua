-- Combat Detection System
-- Detects raid encounters and tracks combat state

local PluribusEncounterCD = {}
_G.PluribusEncounterCD = PluribusEncounterCD

-- Combat state tracking
PluribusEncounterCD.state = "idle" -- idle, in_combat, between, victory, wipe
PluribusEncounterCD.current_encounter = nil
PluribusEncounterCD.boss_units = {}
PluribusEncounterCD.combat_start_time = nil
PluribusEncounterCD.boss_deaths = {}
PluribusEncounterCD.callbacks = {}

local function IsSecret(val)
    return issecretvalue ~= nil and issecretvalue(val) or false
end

local function IsRaidBossUnit(unit)
    if not unit or type(unit) ~= "string" or not UnitExists(unit) then
        return false
    end
    if unit:match("^boss%d+$") then
        return true
    end
    local classification = UnitClassification and UnitClassification(unit)
    if not IsSecret(classification) and classification == "worldboss" then
        return true
    end
    local level = UnitLevel and UnitLevel(unit)
    return (not IsSecret(level)) and level == -1
end

local function IsRaidBossGUID(guid)
    if not guid or IsSecret(guid) or type(guid) ~= "string" or not UnitGUID then
        return false
    end
    for _, unitID in ipairs({"boss1", "boss2", "boss3", "boss4", "boss5", "target", "focus"}) do
        if IsRaidBossUnit(unitID) then
            local ug = UnitGUID(unitID)
            if ug and not IsSecret(ug) and ug == guid then
                return true
            end
        end
    end
    return false
end

function PluribusEncounterCD:IsInCombat()
    return self.state == "in_combat"
end

function PluribusEncounterCD:GetCurrentEncounter()
    return self.current_encounter
end

function PluribusEncounterCD:GetCombatDuration()
    if not self.combat_start_time then return 0 end
    return GetTime() - self.combat_start_time
end

function PluribusEncounterCD:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusEncounterCD:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusEncounterCD:DetectBoss()
    for _, unitID in ipairs({"boss1", "boss2", "boss3", "boss4", "target", "focus"}) do
        if IsRaidBossUnit(unitID) then
            self.boss_units[unitID] = true
            return true
        end
    end
    return false
end

function PluribusEncounterCD:UpdateCombatState()
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

function PluribusEncounterCD:Reset()
    self.state = "idle"
    self.current_encounter = nil
    self.boss_units = {}
    self.combat_start_time = nil
    self.boss_deaths = {}
end

-- Event handlers
function PluribusEncounterCD:OnCombatLogEvent(...)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, 
          destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool = ...
    
    -- Detect boss death
    if subevent == "UNIT_DIED" then
        local isMarked = destFlags and COMBATLOG_OBJECT_RAIDTARGET and bit and bit.band(destFlags, COMBATLOG_OBJECT_RAIDTARGET) ~= 0
        if isMarked or IsRaidBossGUID(destGUID) or IsRaidBossUnit("target") then
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
        if IsRaidBossGUID(sourceGUID) then
            self:TriggerCallback("ability_cast", sourceName, spellName, spellID)
        end
    end
end

return PluribusEncounterCD
