-- InfinityQuestie Initialization
-- Quest database, tracking, and routing

local addonName = "InfinityQuestie"
local addonVersion = "1.0.0"

if not InfinityCore then
    print("InfinityQuestie: Waiting for InfinityCore...")
    return
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    
    -- Load all modules
    local QuestDB = require("InfinityQuestie.Core.QuestDatabase")
    local Chains = require("InfinityQuestie.Core.QuestChains")
    local Router = require("InfinityQuestie.Modules.Router")
    local Tracker = require("InfinityQuestie.Modules.Tracker")
    local Objectives = require("InfinityQuestie.Modules.Objectives")
    local QuestieDBSync = require("InfinityQuestie.Modules.QuestieDBSync")
    local UI = require("InfinityQuestie.UI.Main")
    
    -- Make modules global
    _G.InfinityQuestDB = QuestDB
    _G.InfinityQuestChains = Chains
    _G.InfinityQuestRouter = Router
    _G.InfinityQuestTracker = Tracker
    _G.InfinityQuestObjectives = Objectives
    _G.InfinityQuestieDBSync = QuestieDBSync
    
    -- Initialize quest database sync from QuestieDB (if available)
    QuestieDBSync:Initialize()
    
    -- Initialize UI
    UI:Initialize()
    
    -- Register with InfinityCore
    InfinityCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Infinity Forever",
        description = "Quest database, chains, and routing (Questie replacement)",
        enabled = true,
    })
    
    -- Command registration
    if InfinityCore.RegisterCommand then
        InfinityCore:RegisterCommand("/questie", "Toggle quest window", function()
            UI:Toggle()
        end)
        
        InfinityCore:RegisterCommand("/questie search", "Search quests", function(args)
            if args and args ~= "" then
                local results = QuestDB:SearchQuests(args)
                print("Found " .. #results .. " quests")
                for _, quest in ipairs(results) do
                    print("  - " .. quest.name .. " (" .. quest.level .. ")")
                end
            end
        end)
        
        InfinityCore:RegisterCommand("/questie route", "Show quest route", function()
            local activeQuests = Tracker:GetActiveQuests()
            local questIDs = {}
            for questID, _ in pairs(activeQuests) do
                table.insert(questIDs, questID)
            end
            
            if #questIDs > 0 then
                local route = Router:CalculateRoute(questIDs)
                print("Quest Route:")
                for i, waypoint in ipairs(route.waypoints) do
                    print(string.format("%d. %s (%s)", i, waypoint.name, waypoint.zone))
                end
            end
        end)
    end
    
    -- Event handling for quest events
    local questFrame = CreateFrame("Frame")
    questFrame:RegisterEvent("QUEST_ACCEPTED")
    questFrame:RegisterEvent("QUEST_COMPLETE")
    questFrame:RegisterEvent("QUEST_FINISHED")
    questFrame:RegisterEvent("QUEST_REMOVED")
    questFrame:RegisterEvent("QUEST_LOG_UPDATE")
    
    questFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "QUEST_ACCEPTED" then
            local questID = ...
            local questTitle = GetQuestLogTitle(questID)
            Tracker:AcceptQuest(questID, questTitle)
        elseif event == "QUEST_COMPLETE" then
            UI:Update()
        elseif event == "QUEST_FINISHED" then
            UI:Update()
        elseif event == "QUEST_REMOVED" then
            UI:Update()
        elseif event == "QUEST_LOG_UPDATE" then
            UI:Update()
        end
    end)
    
    print("InfinityQuestie loaded - Use /questie for quest tracking")
end)
