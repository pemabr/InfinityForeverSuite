-- InfinityGatherPath Initialization
-- Gathering optimization and node database

local addonName = "InfinityGatherPath"
local addonVersion = "1.0.0"
local initialized = false

local function InitializeGatherPath()
	if initialized or not _G.InfinityCore then
		return
	end
	
	-- Modules are loaded via .toc file, so globals are already created
	local NodeDB = InfinityNodeDB or _G.InfinityNodeDB
	local Routes = InfinityRoutes or _G.InfinityRoutes
	local Optimization = InfinityOptimization or _G.InfinityOptimization
	local NodeMarkers = InfinityNodeMarkers or _G.InfinityNodeMarkers
	local UI = InfinityGatherPathUI or _G.InfinityGatherPathUI
	
	-- Initialize
	if not NodeDB or not Routes or not Optimization or not UI or not UI.Initialize then
		InfinityUtils:Error("GatherPath modules unavailable.", addonName)
		return
	end
	UI:Initialize()
	
	-- Register with InfinityCore
	if _G.InfinityCore and _G.InfinityCore.RegisterAddon then
		_G.InfinityCore:RegisterAddon(addonName, {
			version = addonVersion,
			author = "Infinity Forever",
			description = "Gathering routes, optimization, and node database (GatherPath replacement)",
			enabled = true,
		})
	end
	
	-- Command registration
	if _G.InfinityCore.RegisterCommand then
		_G.InfinityCore:RegisterCommand("/gatherpath", "Toggle GatherPath window", function()
			UI:Toggle()
		end)
		
		_G.InfinityCore:RegisterCommand("/gatherpath record", "Record current node", function()
			UI:RecordCurrentNode()
		end)
		
		_G.InfinityCore:RegisterCommand("/gatherpath optimize", "Optimize current route", function()
			UI:OptimizeCurrentZone()
		end)
		
		_G.InfinityCore:RegisterCommand("/gatherpath nodes", "Show node count", function()
			print("Total nodes recorded: " .. NodeDB:GetNodeCount())
		end)
	end
	
	-- Event handling for gathering
	local gatherFrame = CreateFrame("Frame")
	gatherFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	gatherFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	
	gatherFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "PLAYER_REGEN_ENABLED" then
			-- Out of combat - safe to record nodes
			UI:Update()
		end
	end)
	
	initialized = true
	print("InfinityGatherPath loaded - Use /gatherpath for route management")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		if _G.InfinityCore then
			InitializeGatherPath()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		InitializeGatherPath()
	end
end)

if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeGatherPath()
		end
	end)
end



