-- Encounters Module
-- Manage active encounters and boss tracking

local InfinityEncounterMgr = {}
_G.InfinityEncounterMgr = InfinityEncounterMgr

InfinityEncounterMgr.active_encounters = {}
InfinityEncounterMgr.encounter_history = {}
InfinityEncounterMgr.current_boss = nil
InfinityEncounterMgr.callbacks = {}

function InfinityEncounterMgr:GetCurrentBoss()
    -- Scan for boss units
    for _, unitID in ipairs({"boss1", "boss2", "boss3", "boss4", "target", "focus"}) do
        local exists = UnitExists(unitID)
        if _G.issecretvalue and _G.issecretvalue(exists) then exists = nil end
        local isBoss = exists and InfinityUtils:IsRaidBoss(unitID)
        if _G.issecretvalue and _G.issecretvalue(isBoss) then isBoss = nil end
        if exists and isBoss then
            local name = UnitName(unitID)
            local health = UnitHealth(unitID)
            local maxHealth = UnitHealthMax(unitID)
            local isSec = _G.issecretvalue
            if isSec and isSec(name) then name = "Boss" end
            local healthPercent
            if isSec and (isSec(health) or isSec(maxHealth)) then
                health = nil
                maxHealth = nil
            elseif type(health) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
                healthPercent = (health / maxHealth) * 100
            end
            local isAlive
            if type(health) == "number" then isAlive = health > 0 end
            
            return {
                unitID = unitID,
                name = name,
                health = health,
                maxHealth = maxHealth,
                healthPercent = healthPercent,
                isAlive = isAlive,
            }
        end
    end
    return nil
end

function InfinityEncounterMgr:StartEncounter(bossName)
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

function InfinityEncounterMgr:EndEncounter(victory)
    if #self.active_encounters == 0 then return end
    
    local encounter = self.active_encounters[#self.active_encounters]
    encounter.duration = GetTime() - encounter.startTime
    
    if victory == true then
        encounter.victories = (encounter.victories or 0) + 1
        self:TriggerCallback("encounter_victory", encounter.name, encounter.duration)
    elseif victory == false then
        encounter.wipes = (encounter.wipes or 0) + 1
        self:TriggerCallback("encounter_wipe", encounter.name, encounter.duration)
    else
        self:TriggerCallback("encounter_ended", encounter.name, encounter.duration)
    end
    
    table.insert(self.encounter_history, encounter)
    table.remove(self.active_encounters)
end

function InfinityEncounterMgr:GetEncounterStats()
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

function InfinityEncounterMgr:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityEncounterMgr:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityEncounterMgr:Reset()
    self.active_encounters = {}
    self.encounter_history = {}
    self.current_boss = nil
end

return InfinityEncounterMgr
