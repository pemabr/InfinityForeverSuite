-- InfinityQuestie Initialization
-- Quest database, tracking, and routing

local addonName = "InfinityQuestie"
local addonVersion = "1.0.0"

local function InitializeQuestie()
	if not _G.InfinityCore then
		return
	end
	
	-- Modules are loaded via .toc file, so globals are already created
	local QuestDB = InfinityQuestDB or _G.InfinityQuestDB
	local Chains = InfinityQuestChains or _G.InfinityQuestChains
	local Router = InfinityQuestRouter or _G.InfinityQuestRouter
	local Tracker = InfinityQuestTracker or _G.InfinityQuestTracker
	local Objectives = InfinityQuestObjectives or _G.InfinityQuestObjectives
	local QuestieDBSync = InfinityQuestieDBSync or _G.InfinityQuestieDBSync
	local UI = InfinityQuestieUI or _G.InfinityQuestieUI
	
	-- Initialize quest database sync from QuestieDB (if available)
	if QuestieDBSync and QuestieDBSync.Initialize then
		if QuestieDBSync then pcall(function() QuestieDBSync:Initialize() end) end
	end
	
	-- Initialize UI
	if UI and UI.Initialize then
		if UI then pcall(function() UI:Initialize() end) end
	end
	
	-- Register with InfinityCore
	_G.InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "Quest database, chains, and routing (Questie replacement)",
		enabled = true,
	})
	
	-- Command registration
	if _G.InfinityCore.RegisterCommand then
		_G.InfinityCore:RegisterCommand("/questie", "Toggle quest window", function()
			UI:Toggle()
		end)
		
		_G.InfinityCore:RegisterCommand("/questie search", "Search quests", function(args)
			if args and args ~= "" then
				local results = QuestDB:SearchQuests(args)
				print("Found " .. #results .. " quests")
				for _, quest in ipairs(results) do
					print("  - " .. quest.name .. " (" .. quest.level .. ")")
				end
			end
		end)
		
		_G.InfinityCore:RegisterCommand("/questie route", "Show quest route", function()
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
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		if _G.InfinityCore then
			InitializeQuestie()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		InitializeQuestie()
	end
end)

if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeQuestie()
		end
	end)
end



