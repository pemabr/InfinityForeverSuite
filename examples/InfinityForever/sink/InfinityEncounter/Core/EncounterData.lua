-- Encounter Database
-- Boss data, abilities, timers, and phase information for all encounters

local InfinityEncounterDB = {}
_G.InfinityEncounterDB = InfinityEncounterDB

-- Midnight Raids (Primary focus)
InfinityEncounterDB.encounters = {
    -- Example boss data structure
    -- [bossId] = {
    --     name = "Boss Name",
    --     zone = "Zone Name",
    --     encounterID = encounterID,
    --     difficulty = "Mythic" | "Heroic" | "Normal",
    --     phases = {
    --         { name = "Phase 1", healthPercent = 100 },
    --     },
    --     abilities = {
    --         [spellID] = {
    --             name = "Spell Name",
    --             type = "tank" | "group" | "raid" | "phase",
    --             timer = 30,
    --             cooldown = 45,
    --             alertTime = 10,
    --         },
    --     },
    --     mechanics = {
    --         "Mechanic 1",
    --         "Mechanic 2",
    --     },
    -- }
}

function InfinityEncounterDB:RegisterEncounter(bossId, data)
    if not bossId or not data or not data.name then
        return false
    end
    
    self.encounters[bossId] = data
    return true
end

function InfinityEncounterDB:GetEncounter(bossId)
    return self.encounters[bossId]
end

function InfinityEncounterDB:GetEncountersByZone(zone)
    local result = {}
    for bossId, encounter in pairs(self.encounters) do
        if encounter.zone == zone then
            table.insert(result, encounter)
        end
    end
    return result
end

function InfinityEncounterDB:GetAbility(bossId, spellID)
    local encounter = self:GetEncounter(bossId)
    if encounter and encounter.abilities then
        return encounter.abilities[spellID]
    end
    return nil
end

function InfinityEncounterDB:RegisterAbility(bossId, spellID, abilityData)
    local encounter = self:GetEncounter(bossId)
    if encounter then
        if not encounter.abilities then
            encounter.abilities = {}
        end
        encounter.abilities[spellID] = abilityData
        return true
    end
    return false
end

function InfinityEncounterDB:GetPhases(bossId)
    local encounter = self:GetEncounter(bossId)
    if encounter then
        return encounter.phases or {}
    end
    return {}
end

function InfinityEncounterDB:GetMechanics(bossId)
    local encounter = self:GetEncounter(bossId)
    if encounter then
        return encounter.mechanics or {}
    end
    return {}
end

-- Database initialization with common boss patterns
-- This would be populated from actual encounter data
function InfinityEncounterDB:Initialize()
    -- Placeholder for real encounter data
    -- In production, this would load from a data file
    
    -- Example structure
    self.encounters["test_boss"] = {
        name = "Test Boss",
        zone = "Test Zone",
        encounterID = 999,
        difficulty = "Normal",
        phases = {
            { name = "Phase 1", healthPercent = 100 },
            { name = "Phase 2", healthPercent = 50 },
        },
        abilities = {
            -- Spell ID -> ability data
        },
        mechanics = {
            "Tank swap at 5 stacks",
            "Move away from group",
            "Interrupt cast",
        },
    }
end

return InfinityEncounterDB
