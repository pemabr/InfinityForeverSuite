-- Encounters Module
-- Manage active encounters and boss tracking

local PluribusEncounterMgr = {}
_G.PluribusEncounterMgr = PluribusEncounterMgr

PluribusEncounterMgr.active_encounters = {}
PluribusEncounterMgr.encounter_history = {}
PluribusEncounterMgr.current_boss = nil
PluribusEncounterMgr.callbacks = {}

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

function PluribusEncounterMgr:GetCurrentBoss()
    -- Scan for boss units
    for _, unitID in ipairs({"boss1", "boss2", "boss3", "boss4", "target", "focus"}) do
        if IsRaidBossUnit(unitID) then
            local name = UnitName(unitID)
            local health = UnitHealth(unitID)
            local maxHealth = UnitHealthMax(unitID)
            local safeName = (name and not IsSecret(name)) and name or "Boss"
            local safeHealth = (health and not IsSecret(health)) and health or 0
            local safeMax = (maxHealth and not IsSecret(maxHealth)) and maxHealth or 0
            local healthPercent = safeMax > 0 and ((safeHealth / safeMax) * 100) or 0
            
            return {
                unitID = unitID,
                name = safeName,
                health = safeHealth,
                maxHealth = safeMax,
                healthPercent = healthPercent,
                isAlive = safeMax == 0 or safeHealth > 0,
            }
        end
    end
    return nil
end

function PluribusEncounterMgr:StartEncounter(bossName)
    if not bossName then
        bossName = UnitName("target") or "Unknown Boss"
    end
    
    local encounter = {
        name = bossName,
        startTime = GetTime(),
        pulls = 1,
        wipes = 0,
        victories = 0,
        duration = 0,
        hp_timeline = {},
    }
    
    table.insert(self.active_encounters, encounter)
    self:TriggerCallback("encounter_started", bossName)
    
    return encounter
end

function PluribusEncounterMgr:EndEncounter(victory)
    if #self.active_encounters == 0 then return end
    
    local encounter = self.active_encounters[#self.active_encounters]
    encounter.duration = GetTime() - encounter.startTime
    
    if victory then
        encounter.victories = (encounter.victories or 0) + 1
        self:TriggerCallback("encounter_victory", encounter.name, encounter.duration)
    else
        encounter.wipes = (encounter.wipes or 0) + 1
        self:TriggerCallback("encounter_wipe", encounter.name, encounter.duration)
    end
    
    table.insert(self.encounter_history, encounter)
    table.remove(self.active_encounters)
end

function PluribusEncounterMgr:GetEncounterStats()
    local total_pulls = 0
    local total_wipes = 0
    local total_victories = 0
    local total_time = 0
    
    for _, encounter in ipairs(self.encounter_history) do
        total_pulls = total_pulls + (encounter.pulls or 1)
        total_wipes = total_wipes + (encounter.wipes or 0)
        total_victories = total_victories + (encounter.victories or 0)
        total_time = total_time + (encounter.duration or 0)
    end
    
    return {
        pulls = total_pulls,
        wipes = total_wipes,
        victories = total_victories,
        total_time = total_time,
        success_rate = total_pulls > 0 and (total_victories / total_pulls * 100) or 0,
    }
end

function PluribusEncounterMgr:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusEncounterMgr:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusEncounterMgr:Reset()
    self.active_encounters = {}
    self.encounter_history = {}
    self.current_boss = nil
end

return PluribusEncounterMgr
