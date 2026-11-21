-- InfinityEncounter Initialization
-- Setup and integration with InfinityCore

local addonName = "InfinityEncounter"
local addonVersion = "1.0.0"

-- Wait for InfinityCore to load
if not InfinityCore then
    print("InfinityEncounter: Waiting for InfinityCore...")
    return
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    
    -- Load all modules
    local CD = require("InfinityEncounter.Core.CombatDetection")
    local Timer = require("InfinityEncounter.Core.Timer")
    local EncDB = require("InfinityEncounter.Core.EncounterData")
    local Encounters = require("InfinityEncounter.Modules.Encounters")
    local Abilities = require("InfinityEncounter.Modules.Abilities")
    local Alerts = require("InfinityEncounter.Modules.Alerts")
    local StatusBars = require("InfinityEncounter.Modules.StatusBars")
    local UI = require("InfinityEncounter.UI.Main")
    
    -- Make modules global
    _G.InfinityEncounterCD = CD
    _G.InfinityEncounterTimer = Timer
    _G.InfinityEncounterDB = EncDB
    _G.InfinityEncounterMgr = Encounters
    _G.InfinityEncounterAbilities = Abilities
    _G.InfinityEncounterAlerts = Alerts
    _G.InfinityEncounterStatusBars = StatusBars
    
    -- Initialize
    EncDB:Initialize()
    UI:Initialize()
    
    -- Register with InfinityCore
    InfinityCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Infinity Forever",
        description = "Complete encounter timers and boss ability tracking (DBM replacement)",
        enabled = true,
    })
    
    -- Command registration
    if InfinityCore.RegisterCommand then
        InfinityCore:RegisterCommand("/encounter", "Toggle encounter window", function()
            UI:Toggle()
        end)
        
        InfinityCore:RegisterCommand("/encounter reset", "Reset encounter data", function()
            Encounters:Reset()
            Abilities:Reset()
            Alerts:Clear()
            print("Encounter data reset")
        end)
        
        InfinityCore:RegisterCommand("/encounter test", "Test alert system", function()
            Alerts:SendAlert("Test Critical Alert!", Alerts.LEVEL_CRITICAL)
            Alerts:SendAbilityAlert("Test Ability", 10, "critical")
            print("Alerts tested")
        end)
    end
    
    -- Event handling
    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    combatFrame:RegisterEvent("UNIT_HEALTH")
    combatFrame:RegisterEvent("UNIT_DIED")
    combatFrame:RegisterEvent("ENCOUNTER_START")
    combatFrame:RegisterEvent("ENCOUNTER_END")
    
    combatFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            CD:OnCombatLogEvent(...)
            local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName = ...
            if subevent == "SPELL_CAST_SUCCESS" then
                Abilities:OnAbilityCast(select(12, ...), select(13, ...), 0, 30)
            end
        elseif event == "UNIT_HEALTH" then
            local unit = ...
            if UnitIsRaidBoss(unit) then
                local name = UnitName(unit)
                local health = UnitHealth(unit)
                local maxHealth = UnitHealthMax(unit)
                StatusBars:UpdateBar(name or "Boss", health, maxHealth)
            end
        elseif event == "ENCOUNTER_START" then
            local encounterID, encounterName, difficultyID = ...
            Encounters:StartEncounter(encounterName)
            Alerts:SendAlert("Encounter: " .. encounterName, Alerts.LEVEL_INFO)
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            Encounters:EndEncounter(success == 1)
        end
    end)
    
    -- Timer update loop
    local timerFrame = CreateFrame("Frame")
    timerFrame:SetScript("OnUpdate", function()
        Timer:Update()
        UI:Update()
        CD:UpdateCombatState()
    end)
    
    print("InfinityEncounter loaded - Use /encounter to toggle window")
end)
