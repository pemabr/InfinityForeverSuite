-- InfinityQuestie Initialization
-- Quest database, tracking, and routing

local addonName = "InfinityQuestie"
local addonVersion = "1.0.0"

local initialized = false

local function InitializeQuestie()
	if initialized or not _G.InfinityCore then
		return
	end
	initialized = true
	
	-- Modules are loaded via .toc file, so globals are already created
	local QuestDB = InfinityQuestDB or _G.InfinityQuestDB
	local Chains = InfinityQuestChains or _G.InfinityQuestChains
	local Router = InfinityQuestRouter or _G.InfinityQuestRouter
	local Tracker = InfinityQuestTracker or _G.InfinityQuestTracker
	local Objectives = InfinityQuestObjectives or _G.InfinityQuestObjectives
	local QuestieDBSync = InfinityQuestieDBSync or _G.InfinityQuestieDBSync
	local UI = InfinityQuestieUI or _G.InfinityQuestieUI
	
	-- Initialize standalone native quest log sync (+ optional QuestieDB bonus if installed)
	if QuestieDBSync and QuestieDBSync.Initialize then
		pcall(function() QuestieDBSync:Initialize() end)
	end
	
	-- Initialize UI
	if UI and UI.Initialize then
		pcall(function() UI:Initialize() end)
	end
	
	-- Register with InfinityCore
	_G.InfinityCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Infinity Forever",
		description = "Standalone quest tracking, chains, and routing (QuestieDB optional)",
		enabled = true,
	})
	
	-- Command registration
	if _G.InfinityCore.RegisterCommand then
		_G.InfinityCore:RegisterCommand("/questie", "Toggle quest window", function()
			UI:Toggle()
		end)
		
		_G.InfinityCore:RegisterCommand("/questie search", "Search quests", function(args)
			if args and args ~= "" and QuestDB and QuestDB.SearchQuests then
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
			
			if #questIDs > 0 and Router and Router.CalculateRoute then
				local route = Router:CalculateRoute(questIDs)
				print("Quest Route:")
				for i, waypoint in ipairs(route.waypoints) do
					print(string.format("%d. %s (%s)", i, waypoint.name, waypoint.zone))
				end
			end
		end)
	end
	
	-- Event handling for quest events (100% standalone C_QuestLog)
	local questFrame = CreateFrame("Frame")
	for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_REMOVED", "QUEST_LOG_UPDATE" }) do
		pcall(questFrame.RegisterEvent, questFrame, ev)
	end
	
	questFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "QUEST_ACCEPTED" then
			local arg1, arg2 = ...
			local questID = type(arg1) == "number" and arg1 or arg2
			local questTitle = InfinityUtils:GetQuestTitleByID(questID) or ("Quest #" .. tostring(questID or "?"))
			if Tracker and Tracker.AcceptQuest and questID then
				Tracker:AcceptQuest(questID, questTitle)
			end
			if UI then UI:Update() end
		elseif event == "QUEST_COMPLETE" or event == "QUEST_FINISHED" or event == "QUEST_REMOVED" or event == "QUEST_LOG_UPDATE" then
			if QuestieDBSync and QuestieDBSync.SyncFromNativeQuestLog then
				pcall(function() QuestieDBSync:SyncFromNativeQuestLog() end)
			end
			if UI then UI:Update() end
		end
	end)
	
	InfinityUtils:Info("InfinityQuestie loaded (Standalone Native Mode) - /questie", "Questie")
end


local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Quest management",
			author = "Infinity Suite Team",
			category = "Quest",
			enabled = true,
			settings = {{}}
		})
	end
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



