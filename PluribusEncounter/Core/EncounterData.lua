-- Encounter Database
-- Boss data, abilities, timers, and phase information for all encounters

local PluribusEncounterDB = {}
_G.PluribusEncounterDB = PluribusEncounterDB

-- Midnight Raids (Primary focus)
PluribusEncounterDB.encounters = {
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

function PluribusEncounterDB:RegisterEncounter(bossId, data)
    if not bossId or not data or not data.name then
        return false
    end
    
    self.encounters[bossId] = data
    return true
end

function PluribusEncounterDB:GetEncounter(bossId)
    return self.encounters[bossId]
end

function PluribusEncounterDB:GetEncountersByZone(zone)
    local result = {}
    for bossId, encounter in pairs(self.encounters) do
        if encounter.zone == zone then
            table.insert(result, encounter)
        end
    end
    return result
end

function PluribusEncounterDB:GetAbility(bossId, spellID)
    local encounter = self:GetEncounter(bossId)
    if encounter and encounter.abilities then
        return encounter.abilities[spellID]
    end
    return nil
end

function PluribusEncounterDB:RegisterAbility(bossId, spellID, abilityData)
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

function PluribusEncounterDB:GetPhases(bossId)
    local encounter = self:GetEncounter(bossId)
    if encounter then
        return encounter.phases or {}
    end
    return {}
end

function PluribusEncounterDB:GetMechanics(bossId)
    local encounter = self:GetEncounter(bossId)
    if encounter then
        return encounter.mechanics or {}
    end
    return {}
end

-- Database initialization with common boss patterns
-- This would be populated from actual encounter data
function PluribusEncounterDB:Initialize()
    local classicEncounters = {
        anubrekhan = {
            name = "Anub'Rekhan",
            zone = "Naxxramas",
            encounterID = 1107,
            difficulty = "40-Man",
            phases = { { name = "Normal", healthPercent = 100 }, { name = "Locust Swarm", healthPercent = 75 } },
            abilities = {
                [28785] = { name = "Locust Swarm", type = "raid", timer = 90, cooldown = 90, alertTime = 10 },
                [28783] = { name = "Impale", type = "group", timer = 15, cooldown = 15, alertTime = 5 },
            },
            mechanics = { "Kite boss clockwise during Locust Swarm", "Off-tank Crypt Guards immediately", "Spread to minimize Impale targets" },
        },
        patchwerk = {
            name = "Patchwerk",
            zone = "Naxxramas",
            encounterID = 1118,
            difficulty = "40-Man",
            phases = { { name = "Hateful Strike", healthPercent = 100 }, { name = "Frenzy", healthPercent = 5 } },
            abilities = {
                [28308] = { name = "Hateful Strike", type = "tank", timer = 1.2, cooldown = 1.2, alertTime = 0 },
                [28131] = { name = "Frenzy", type = "phase", timer = 420, cooldown = 420, alertTime = 30 },
            },
            mechanics = { "Keep 3 hateful off-tanks topped at 100% HP", "7-minute hard enrage timer", "Burn cooldowns at 5% Frenzy" },
        },
        loatheb = {
            name = "Loatheb",
            zone = "Naxxramas",
            encounterID = 1115,
            difficulty = "40-Man",
            phases = { { name = "Corrupted Mind", healthPercent = 100 } },
            abilities = {
                [29204] = { name = "Inevitable Doom", type = "raid", timer = 120, cooldown = 30, alertTime = 8 },
                [29234] = { name = "Summon Spore", type = "group", timer = 13, cooldown = 13, alertTime = 4 },
            },
            mechanics = { "Follow strict 5-second healer rotation", "Rotate DPS groups into Fungal Creep spores", "Use Greater Shadow Protection Potions for Doom" },
        },
        sapphiron = {
            name = "Sapphiron",
            zone = "Naxxramas",
            encounterID = 1119,
            difficulty = "40-Man",
            phases = { { name = "Ground Phase", healthPercent = 100 }, { name = "Air Phase", healthPercent = 80 } },
            abilities = {
                [28542] = { name = "Life Drain", type = "raid", timer = 24, cooldown = 24, alertTime = 5 },
                [28524] = { name = "Frost Breath", type = "phase", timer = 45, cooldown = 65, alertTime = 8 },
            },
            mechanics = { "Decurse Life Drain immediately", "Hide behind Ice Blocks during Air Phase Frost Breath", "Wear Frost Resistance gear" },
        },
        kelthuzad = {
            name = "Kel'Thuzad",
            zone = "Naxxramas",
            encounterID = 1114,
            difficulty = "40-Man",
            phases = { { name = "Phase 1: Adds", healthPercent = 100 }, { name = "Phase 2: Kel'Thuzad", healthPercent = 100 }, { name = "Phase 3: Guardians", healthPercent = 40 } },
            abilities = {
                [28478] = { name = "Frostbolt", type = "tank", timer = 10, cooldown = 12, alertTime = 3 },
                [27808] = { name = "Frost Blast", type = "raid", timer = 30, cooldown = 35, alertTime = 6 },
                [27812] = { name = "Shadow Fissure", type = "group", timer = 15, cooldown = 15, alertTime = 3 },
                [28410] = { name = "Chains of Kel'Thuzad", type = "raid", timer = 60, cooldown = 60, alertTime = 8 },
            },
            mechanics = { "Kick single-target Frostbolt", "Move out of red Shadow Fissure within 3s", "Spread 10 yards for Frost Blast", "CC mind-controlled raiders" },
        },
        ragnaros = {
            name = "Ragnaros",
            zone = "Molten Core",
            encounterID = 672,
            difficulty = "40-Man",
            phases = { { name = "Emergence", healthPercent = 100 }, { name = "Sons of Flame", healthPercent = 50 } },
            abilities = {
                [20566] = { name = "Wrath of Ragnaros", type = "tank", timer = 25, cooldown = 28, alertTime = 5 },
                [21158] = { name = "Submerge", type = "phase", timer = 180, cooldown = 180, alertTime = 15 },
            },
            mechanics = { "Melee out before Wrath of Ragnaros knockback", "Banish and kill Sons of Flame on Submerge" },
        },
        nefarian = {
            name = "Nefarian",
            zone = "Blackwing Lair",
            encounterID = 617,
            difficulty = "40-Man",
            phases = { { name = "Phase 1: Drakonids", healthPercent = 100 }, { name = "Phase 2: Nefarian", healthPercent = 100 }, { name = "Phase 3: Constructs", healthPercent = 20 } },
            abilities = {
                [22539] = { name = "Shadow Flame", type = "tank", timer = 18, cooldown = 18, alertTime = 5 },
                [22686] = { name = "Bellowing Roar", type = "raid", timer = 30, cooldown = 30, alertTime = 6 },
            },
            mechanics = { "Equip Onyxia Scale Cloak", "Fear Ward tank before Bellowing Roar", "Handle Class Calls cleanly" },
        },
        cthun = {
            name = "C'Thun",
            zone = "Ahn'Qiraj",
            encounterID = 717,
            difficulty = "40-Man",
            phases = { { name = "Phase 1: Eye of C'Thun", healthPercent = 100 }, { name = "Phase 2: C'Thun", healthPercent = 100 } },
            abilities = {
                [26029] = { name = "Dark Glare", type = "raid", timer = 45, cooldown = 85, alertTime = 8 },
                [26134] = { name = "Eye Beam", type = "group", timer = 3, cooldown = 3, alertTime = 1 },
            },
            mechanics = { "Spread 10 yards to prevent Eye Beam chaining", "Rotate clockwise during Dark Glare", "Kill Flesh Tentacles inside stomach" },
        },
    }
    for id, data in pairs(classicEncounters) do
        self.encounters[id] = data
    end
end

return PluribusEncounterDB
