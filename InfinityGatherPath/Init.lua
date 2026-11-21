-- InfinityGatherPath Initialization
-- Gathering optimization and node database

local addonName = "InfinityGatherPath"
local addonVersion = "1.0.0"

local function InitializeGatherPath()
	if not _G.InfinityCore then
		return
	end
	
	-- Modules are loaded via .toc file, so globals are already created
	local NodeDB = InfinityNodeDB or _G.InfinityNodeDB
	local Routes = InfinityRoutes or _G.InfinityRoutes
	local Optimization = InfinityOptimization or _G.InfinityOptimization
	local NodeMarkers = InfinityNodeMarkers or _G.InfinityNodeMarkers
	local UI = InfinityGatherPathUI or _G.InfinityGatherPathUI
	
	-- Initialize
	if UI and UI.Initialize then
		if UI then pcall(function() UI:Initialize() end) end
	end
	
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
			local zone = GetRealZoneText()
			if zone then
				local x, y = GetPlayerMapPosition("player")
				if x and y then
					NodeDB:RecordNode("herb", x * 100, y * 100, zone, 300)
					print("Node recorded in " .. zone)
				end
			end
		end)
		
		_G.InfinityCore:RegisterCommand("/gatherpath optimize", "Optimize current route", function()
			local zone = GetRealZoneText()
			if zone then
				local nodes = NodeDB:GetNodesByZone(zone)
				if #nodes > 0 then
					local optimized = Optimization:OptimizeRoute(nodes)
					local distance = Optimization:CalculateTotalDistance(optimized)
					print(string.format("Route optimized: %d nodes, %.0f yards", #optimized, distance))
				end
			end
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



