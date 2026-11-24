-- PluribusQuestie Initialization
-- Quest database, tracking, and routing

local addonName = "PluribusQuestie"
local addonVersion = "1.0.0"

local initialized = false

local function InitializeQuestie()
	if initialized or not _G.PluribusCore then
		return
	end
	initialized = true
	
	-- Modules are loaded via .toc file, so globals are already created
	local QuestDB = PluribusQuestDB or _G.PluribusQuestDB
	local Chains = PluribusQuestChains or _G.PluribusQuestChains
	local Router = PluribusQuestRouter or _G.PluribusQuestRouter
	local Tracker = PluribusQuestTracker or _G.PluribusQuestTracker
	local Objectives = PluribusQuestObjectives or _G.PluribusQuestObjectives
	local QuestieDBSync = PluribusQuestieDBSync or _G.PluribusQuestieDBSync
	local UI = PluribusQuestieUI or _G.PluribusQuestieUI
	
	-- Initialize standalone native quest log sync (+ optional QuestieDB bonus if installed)
	if QuestieDBSync and QuestieDBSync.Initialize then
		pcall(function() QuestieDBSync:Initialize() end)
	end
	
	-- Initialize UI
	if UI and UI.Initialize then
		pcall(function() UI:Initialize() end)
	end
	
	-- Register with PluribusCore
	_G.PluribusCore:RegisterAddon(addonName, {
		version = addonVersion,
		author = "Pluribus",
		description = "Standalone quest tracking, chains, and routing (QuestieDB optional)",
		enabled = true,
	})
	
	-- Command registration
	if _G.PluribusCore.RegisterCommand then
		_G.PluribusCore:RegisterCommand("/questie", "Toggle quest window", function()
			UI:Toggle()
		end)
		
		_G.PluribusCore:RegisterCommand("/questie search", "Search quests", function(args)
			if args and args ~= "" and QuestDB and QuestDB.SearchQuests then
				local results = QuestDB:SearchQuests(args)
				print("Found " .. #results .. " quests")
				for _, quest in ipairs(results) do
					print("  - " .. quest.name .. " (" .. quest.level .. ")")
				end
			end
		end)
		
		_G.PluribusCore:RegisterCommand("/questie route", "Show quest route", function()
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
			local questTitle = PluribusUtils:GetQuestTitleByID(questID) or ("Quest #" .. tostring(questID or "?"))
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
	
	PluribusUtils:Info("PluribusQuestie loaded (Standalone Native Mode) - /questie", "Questie")
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Quest management",
			author = "Pluribus Suite Team",
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
		if _G.PluribusCore then
			InitializeQuestie()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		InitializeQuestie()
	end
end)

if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeQuestie()
		end
	end)
end



