-- PluribusGatherPath Initialization
-- Gathering optimization and node database

local addonName = "PluribusGatherPath"
local addonVersion = "1.0.0"

local function InitializeGatherPath()
	if not _G.PluribusCore then
		return
	end
	
	-- Modules are loaded via .toc file, so globals are already created
	local NodeDB = PluribusNodeDB or _G.PluribusNodeDB
	local Routes = PluribusRoutes or _G.PluribusRoutes
	local Optimization = PluribusOptimization or _G.PluribusOptimization
	local NodeMarkers = PluribusNodeMarkers or _G.PluribusNodeMarkers
	local UI = PluribusGatherPathUI or _G.PluribusGatherPathUI
	
	-- Initialize
	if UI and UI.Initialize then
		if UI then pcall(function() UI:Initialize() end) end
	end
	
	-- Register with PluribusCore
	if _G.PluribusCore and _G.PluribusCore.RegisterAddon then
		_G.PluribusCore:RegisterAddon(addonName, {
			version = addonVersion,
			author = "Pluribus",
			description = "Gathering routes, optimization, and node database (GatherPath replacement)",
			enabled = true,
		})
	end
	
	-- Command registration
	if _G.PluribusCore.RegisterCommand then
		_G.PluribusCore:RegisterCommand("/gatherpath", "Toggle GatherPath window", function()
			UI:Toggle()
		end)
		
		_G.PluribusCore:RegisterCommand("/gatherpath record", "Record current node", function()
			local zone = GetRealZoneText and GetRealZoneText() or "Unknown"
			local x, y = PluribusUtils:GetUnitMapPosition("player")
			if x and y and (x > 0 or y > 0) then
				NodeDB:RecordNode("herb", x * 100, y * 100, zone, 300)
				print("|cff4ade80[PluribusGatherPath]|r Node recorded in " .. zone .. string.format(" (%.1f, %.1f)", x * 100, y * 100))
			else
				print("|cfffbbf24[PluribusGatherPath]|r Unable to read map coordinates in current zone.")
			end
		end)
		
		_G.PluribusCore:RegisterCommand("/gatherpath optimize", "Optimize current route", function()
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
		
		_G.PluribusCore:RegisterCommand("/gatherpath nodes", "Show node count", function()
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
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID and not PluribusUtils:IsSecret(spellID) then
			local nodeType = GATHER_SPELLS[spellID]
			if nodeType and NodeDB and NodeDB.RecordNode then
				local x, y = PluribusUtils:GetUnitMapPosition("player")
				local zone = GetRealZoneText and GetRealZoneText() or "Unknown"
				if x and y and (x > 0 or y > 0) then
					NodeDB:RecordNode(nodeType, x * 100, y * 100, zone, 300)
					if UI and UI.Update then UI:Update() end
				end
			end
		end
	end)
	
	PluribusUtils:Info("PluribusGatherPath loaded (Standalone Node Recorder) - /gatherpath", "GatherPath")
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Optimize routes",
			author = "Pluribus Suite Team",
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
		if _G.PluribusCore then
			InitializeGatherPath()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		InitializeGatherPath()
	end
end)

if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeGatherPath()
		end
	end)
end



