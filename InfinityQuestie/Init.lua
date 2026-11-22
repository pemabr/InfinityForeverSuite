local addonName = "InfinityQuestie"
local initialized, addonLoaded = false, false

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function QuestID(value)
	value = Public(value)
	return type(value) == "number" and value == value and value > 0
		and value <= 1000000000 and value == math.floor(value)
end

local function InitializeQuestie()
	if initialized or not _G.InfinityCore then return end
	local tracker, ui = InfinityQuestTracker, InfinityQuestieUI
	InfinityQuestieDBSync:Initialize()
	ui:Initialize()
	tracker:SyncQuestLog(InfinityUIFramework:GetQuestLogSnapshot())
	InfinityCore:RegisterAddon(addonName, {
		version = "1.0.0",
		author = "Infinity Forever",
		description = "Quest log and optional QuestieDB search",
		enabled = true,
	})

	local function SearchQuests(args)
		args = Public(args)
		if type(args) ~= "string" or args == "" then
			InfinityUtils:Warning("Enter a quest name or ID.", "Questie")
			return nil
		end
		tracker:SyncQuestLog(InfinityUIFramework:GetQuestLogSnapshot())
		local results, seen = {}, {}
		local function Add(id, name)
			id, name = Public(id), Public(name)
			if QuestID(id) and type(name) == "string" and name ~= "" and not seen[id] then
				results[#results + 1] = { id = id, name = name }
				seen[id] = true
			end
		end
		for _, quest in ipairs(InfinityQuestDB:SearchQuests(args)) do
			Add(quest.id, quest.name)
		end
		local queryID = args:match("^%s*%d+%s*$") and tonumber(args)
		local indexed = QuestID(queryID) and InfinityQuestDB:GetQuest(queryID)
		if indexed then Add(queryID, indexed.name) end
		local needle = args:lower()
		for rawID, rawQuest in pairs(tracker:GetActiveQuests()) do
			local id, quest = Public(rawID), Public(rawQuest)
			local name = type(quest) == "table" and Public(quest.name)
			if QuestID(id) and type(name) == "string" and (id == queryID or name:lower():find(needle, 1, true)) then
				Add(id, name)
			end
		end
		local collector = Public(_G.InfinityDataCollectorCore)
		local data = type(collector) == "table" and Public(collector.gatheredData)
		local collected = type(data) == "table" and Public(data.quests)
		if type(collected) == "table" then
			local incomplete = false
			for rawID, rawQuest in pairs(collected) do
				local id, quest = Public(rawID), Public(rawQuest)
				local name = type(quest) == "table" and Public(quest.name)
				if not QuestID(id) or type(name) ~= "string" or name == "" then incomplete = true
				elseif id == queryID or name:lower():find(needle, 1, true) then Add(id, name) end
			end
			if incomplete then InfinityUtils:Warning("Some collector quests are unavailable.", "Questie") end
		elseif data ~= nil then
			InfinityUtils:Warning("Collector quest data is unavailable.", "Questie")
		end
		table.sort(results, function(a, b) return a.id < b.id end)
		return results
	end
	ui.SearchQuests = SearchQuests
	InfinityCore:RegisterCommand("/questie", "Toggle quest window", function() ui:Toggle() end)
	InfinityCore:RegisterCommand("/questie search", "Search quests", function(args)
		local results = SearchQuests(args)
		if not results then return end
		if InfinityQuestieDBSync.syncInProgress then print("QuestieDB indexing is still in progress; results may be incomplete.") end
		print("QuestieDB, collector and visible quest log matches: " .. #results)
		for i = 1, math.min(#results, 30) do
			print("  " .. results[i].name .. " (" .. results[i].id .. ")")
		end
		if #results > 30 then print("Showing the first 30 matches.") end
	end)
	InfinityCore:RegisterCommand("/questie route", "Show quest route", function()
		ui:ShowRoute()
	end)
	InfinityCore:RegisterCommand("/questie waypoint", "Set a quest waypoint", function(args)
		local id = type(args) == "string" and args:match("^%s*(%d+)%s*$")
		if not id or tonumber(id) <= 0 then
			print("Usage: /questie waypoint <quest ID>")
			return
		end
		InfinityQuestRouter:ShowWaypoint(tonumber(id))
	end)
	InfinityCore:RegisterCommand("/questie locations", "Show possible quest locations", function(args)
		local id = type(args) == "string" and args:match("^%s*(%d+)%s*$")
		if not id or tonumber(id) <= 0 then
			print("Usage: /questie locations <quest ID>")
			return
		end
		ui:ShowLocations(tonumber(id))
	end)
	InfinityCore:RegisterCommand("/questcompass", "Show quest waypoint compass", function(args)
		InfinityQuestCompass:HandleCommand(args)
	end)

	local events = CreateFrame("Frame")
	events:RegisterEvent("QUEST_LOG_UPDATE")
	events:RegisterEvent("QUEST_TURNED_IN")
	local ok, err = pcall(events.RegisterEvent, events, "QUEST_WATCH_LIST_CHANGED")
	if not ok then InfinityUtils:Warning("Quest watch updates unavailable: " .. tostring(err), "Questie") end
	events:SetScript("OnEvent", function(_, event, questID)
		if event == "QUEST_TURNED_IN" and not (_G.issecretvalue and _G.issecretvalue(questID))
			and type(questID) == "number" then
			tracker:CompleteQuest(questID)
		end
		if ui.frame and ui.frame:IsShown() then
			ui:Update()
		else
			tracker:SyncQuestLog(InfinityUIFramework:GetQuestLogSnapshot())
		end
		if ui.routeFrame and ui.routeFrame:IsShown() then ui:ShowRoute(true) end
	end)
	initialized = true
	print("InfinityQuestie loaded - Use /questie for the quest log")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, name)
	if name == addonName then
		addonLoaded = true
		InitializeQuestie()
	elseif name == "QuestieDB" and initialized then
		InfinityQuestieDBSync:Initialize()
	end
end)

if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then InitializeQuestie() end
	end)
end
