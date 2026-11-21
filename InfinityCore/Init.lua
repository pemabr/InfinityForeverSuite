-- InfinityCore Initialization
-- Main addon entry point - simplified for stability

local function InitializeInfinityCore()
	-- Initialize utilities first
	_G.InfinityUtils = InfinityUtils
	
	-- Initialize storage (safely)
	if InfinityStorageManager and InfinityStorageManager.Initialize then
		pcall(function() InfinityStorageManager:Initialize(InfinityCoreDB) end)
		_G.InfinityStorageManager = InfinityStorageManager
		_G.InfinityCoreDB = InfinityCoreDB
	end
	
	-- Initialize core managers (safely)
	if InfinityDataManager then _G.InfinityDataManager = InfinityDataManager end
	if InfinityMessaging then _G.InfinityMessaging = InfinityMessaging end
	if InfinityEventRouter then _G.InfinityEventRouter = InfinityEventRouter end
	if InfinityCommandRegistry then _G.InfinityCommandRegistry = InfinityCommandRegistry end
	if InfinityUIFramework then _G.InfinityUIFramework = InfinityUIFramework end
	if InfinityMainFrame then _G.InfinityMainFrame = InfinityMainFrame end
	
	-- Register InfinityCore itself as a global for dependency checks
	_G.InfinityCore = {
		name = INFINITY_CORE_NAME,
		version = INFINITY_SUITE_VERSION,
		initialized = true,
	}
	
	-- Initialize event router (safely)
	if InfinityEventRouter and InfinityEventRouter.Initialize then
		pcall(function() InfinityEventRouter:Initialize() end)
	end
	
	-- Initialize UI framework (safely)
	if InfinityUIFramework and InfinityUIFramework.Initialize then
		pcall(function() InfinityUIFramework:Initialize() end)
	end
	
	-- Register global managers if they exist
	if InfinitySettingsPanel then
		_G.InfinitySettingsPanel = InfinitySettingsPanel
	end
	
	if InfinityAddonManager then
		_G.InfinityAddonManager = InfinityAddonManager
	end
	
	-- Initialize data collection (safely)
	if InfinityDataCollector and InfinityDataCollector.Initialize then
		pcall(function() InfinityDataCollector:Initialize() end)
	end
	
	-- Register /infinity command for opening UI
	if InfinityCommandRegistry and InfinityCommandRegistry.RegisterCommand then
		pcall(function()
			InfinityCommandRegistry:RegisterCommand("infinity", function(args, msg)
				if _G.InfinityMainFrame and _G.InfinityMainFrame.Toggle then
					_G.InfinityMainFrame:Toggle()
				end
			end, {"inf", "suite"})
		end)
	end
	
	-- Send startup message
	pcall(function()
		if _G.InfinityUtils then
			_G.InfinityUtils:Info("Infinity Suite v" .. INFINITY_SUITE_VERSION .. " loaded! Use /infinity to open.", "Core")
		end
	end)
	
	-- Trigger data loaded event (safely)
	if InfinityMessaging and InfinityMessaging.Publish then
		pcall(function()
			InfinityMessaging:Publish("INFINITY_DATA_LOADED")
		end)
	end
end

-- Hook into addon loaded event
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == INFINITY_CORE_NAME then
		InitializeInfinityCore()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
