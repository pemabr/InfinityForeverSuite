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
			local zone = GetRealZoneText and GetRealZoneText() or "Unknown"
			local x, y = InfinityUtils:GetUnitMapPosition("player")
			if x and y and (x > 0 or y > 0) then
				NodeDB:RecordNode("herb", x * 100, y * 100, zone, 300)
				print("|cff4ade80[InfinityGatherPath]|r Node recorded in " .. zone .. string.format(" (%.1f, %.1f)", x * 100, y * 100))
			else
				print("|cfffbbf24[InfinityGatherPath]|r Unable to read map coordinates in current zone.")
			end
		end)
		
		_G.InfinityCore:RegisterCommand("/gatherpath optimize", "Optimize current route", function()
			local zone = GetRealZoneText and GetRealZoneText()
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
	
	-- Standalone event handling for automatic gathering node recording (no GathererDB required)
	local gatherFrame = CreateFrame("Frame")
	pcall(gatherFrame.RegisterEvent, gatherFrame, "PLAYER_REGEN_ENABLED")
	pcall(gatherFrame.RegisterEvent, gatherFrame, "PLAYER_REGEN_DISABLED")
	pcall(gatherFrame.RegisterEvent, gatherFrame, "UNIT_SPELLCAST_SUCCEEDED")
	
	local GATHER_SPELLS = { [2366] = "herb", [2575] = "mining", [8613] = "skinning", [7620] = "fishing" }
	gatherFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
		if event == "PLAYER_REGEN_ENABLED" then
			if UI and UI.Update then UI:Update() end
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID and not InfinityUtils:IsSecret(spellID) then
			local nodeType = GATHER_SPELLS[spellID]
			if nodeType and NodeDB and NodeDB.RecordNode then
				local x, y = InfinityUtils:GetUnitMapPosition("player")
				local zone = GetRealZoneText and GetRealZoneText() or "Unknown"
				if x and y and (x > 0 or y > 0) then
					NodeDB:RecordNode(nodeType, x * 100, y * 100, zone, 300)
					if UI and UI.Update then UI:Update() end
				end
			end
		end
	end)
	
	InfinityUtils:Info("InfinityGatherPath loaded (Standalone Node Recorder) - /gatherpath", "GatherPath")
end


local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Optimize routes",
			author = "Infinity Suite Team",
			category = "Gathering",
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



