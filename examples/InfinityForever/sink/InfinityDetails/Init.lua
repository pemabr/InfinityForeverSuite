-- InfinityDetails Initialization
-- Combat parsing and performance metrics

local addonName = "InfinityDetails"
local addonVersion = "1.0.0"

if not InfinityCore then
    print("InfinityDetails: Waiting for InfinityCore...")
    return
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    
    -- Load all modules
    local Parser = require("InfinityDetails.Core.CombatParser")
    local Actor = require("InfinityDetails.Core.ActorModel")
    local Meters = require("InfinityDetails.Modules.Meters")
    local Segments = require("InfinityDetails.Modules.Segments")
    local Threat = require("InfinityDetails.Modules.Threat")
    local Deaths = require("InfinityDetails.Modules.Deaths")
    local Reports = require("InfinityDetails.Modules.Reports")
    local UI = require("InfinityDetails.UI.Main")
    local Breakdown = require("InfinityDetails.UI.Breakdown")
    
    -- Make modules global
    _G.InfinityDetailsCombatParser = Parser
    _G.InfinityDetailsActor = Actor
    _G.InfinityDetailsMeters = Meters
    _G.InfinityDetailsSegments = Segments
    _G.InfinityDetailsThreat = Threat
    _G.InfinityDetailsDeaths = Deaths
    _G.InfinityDetailsReports = Reports
    
    -- Initialize
    UI:Initialize()
    Breakdown:Initialize()
    
    -- Register with InfinityCore
    InfinityCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Infinity Forever",
        description = "Real-time combat metrics - DPS/HPS/Threat analysis",
        enabled = true,
    })
    
    -- Command registration
    if InfinityCore.RegisterCommand then
        InfinityCore:RegisterCommand("/details", "Toggle Details window", function()
            UI:Toggle()
        end)
        
        InfinityCore:RegisterCommand("/details breakdown", "Show actor breakdown", function()
            Breakdown:Toggle()
        end)
        
        InfinityCore:RegisterCommand("/details report", "Generate full report", function()
            local report = Reports:GenerateFullReport()
            print(report)
        end)
        
        InfinityCore:RegisterCommand("/details dps", "Show DPS report", function()
            local report = Reports:GenerateDPSReport()
            print(report)
        end)
        
        InfinityCore:RegisterCommand("/details hps", "Show HPS report", function()
            local report = Reports:GenerateHPSReport()
            print(report)
        end)
        
        InfinityCore:RegisterCommand("/details threat", "Show threat report", function()
            local report = Reports:GenerateThreatReport()
            print(report)
        end)
        
        InfinityCore:RegisterCommand("/details deaths", "Show death report", function()
            local report = Reports:GenerateDeathReport()
            print(report)
        end)
    end
    
    -- Event handling
    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    combatFrame:RegisterEvent("ENCOUNTER_START")
    combatFrame:RegisterEvent("ENCOUNTER_END")
    
    combatFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            -- Parse combat events
            if Parser:IsParsing() then
                Parser:OnCombatLogEvent(...)
                
                local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
                      destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool,
                      amount, overkill = ...
                
                -- Update actor model based on event type
                if subevent:find("DAMAGE") then
                    local sourceActor = Actor:GetOrCreateActor(sourceGUID, sourceName, nil, true)
                    local isCrit = subevent:find("CRIT") ~= nil
                    sourceActor:RecordDamage(amount or 0, overkill, isCrit)
                elseif subevent:find("HEAL") then
                    local sourceActor = Actor:GetOrCreateActor(sourceGUID, sourceName, nil, true)
                    local isCrit = subevent:find("CRIT") ~= nil
                    sourceActor:RecordHealing(amount or 0, 0, isCrit)
                elseif subevent == "UNIT_DIED" then
                    Deaths:RecordDeath(destName)
                end
            end
        elseif event == "ENCOUNTER_START" then
            Parser:StartParsing()
            Meters:Start()
            Segments:StartSegment(select(2, ...), select(2, ...))
        elseif event == "ENCOUNTER_END" then
            Parser:StopParsing()
            Meters:Stop()
            Segments:EndSegment()
        end
    end)
    
    -- Update loop
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function()
        Meters:Update()
        UI:Update()
        Breakdown:Update()
    end)
    
    print("InfinityDetails loaded - Use /details for metrics")
end)
