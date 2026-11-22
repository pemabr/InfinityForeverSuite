-- InfinityCore Initialization
-- Main addon entry point - simplified for stability

local function InitializeInfinityCore()
	-- Initialize utilities first
	_G.InfinityUtils = InfinityUtils
	
	-- Initialize storage (safely, always bind to _G.InfinityCoreDB)
	if type(_G.InfinityCoreDB) ~= "table" then
		_G.InfinityCoreDB = {}
	end
	if InfinityStorageManager and InfinityStorageManager.Initialize then
		local ok, err = pcall(InfinityStorageManager.Initialize, InfinityStorageManager, _G.InfinityCoreDB)
		if not ok then
			InfinityUtils:Error("Storage initialization failed: " .. tostring(err), "Core")
			return
		end
		_G.InfinityStorageManager = InfinityStorageManager
	end
	
	-- Initialize core managers (safely)
	if InfinityDataManager then _G.InfinityDataManager = InfinityDataManager end
	if InfinityMessaging then _G.InfinityMessaging = InfinityMessaging end
	if InfinityEventRouter then _G.InfinityEventRouter = InfinityEventRouter end
	if InfinityCommandRegistry then _G.InfinityCommandRegistry = InfinityCommandRegistry end
	if InfinityUIFramework then _G.InfinityUIFramework = InfinityUIFramework end
	if InfinityMainFrame then _G.InfinityMainFrame = InfinityMainFrame end
	if InfinityCharacterManager then _G.InfinityCharacterManager = InfinityCharacterManager end
	
	-- Register InfinityCore itself as a global for dependency checks and shared addon helpers
	local commandRoutes = {}
	_G.InfinityCore = {
		name = INFINITY_CORE_NAME,
		version = INFINITY_SUITE_VERSION,
		initialized = true,
		Events = {
			Subscribe = function(_, eventName, callback)
				if _G.InfinityMessaging then
					return _G.InfinityMessaging:Subscribe(eventName, callback)
				end
			end,
			Register = function(_, eventName, callback)
				if _G.InfinityMessaging then
					return _G.InfinityMessaging:Subscribe(eventName, callback)
				end
			end,
			Fire = function(_, eventName, ...)
				if _G.InfinityMessaging then
					return _G.InfinityMessaging:Publish(eventName, ...)
				end
			end,
			Publish = function(_, eventName, ...)
				if _G.InfinityMessaging then
					return _G.InfinityMessaging:Publish(eventName, ...)
				end
			end,
		},
		Log = function(message)
			if _G.InfinityUtils then
				_G.InfinityUtils:Info(tostring(message), "Core")
			else
				print(tostring(message))
			end
		end,
		GetDatabase = function(_, addonName)
			if _G.InfinityStorageManager and _G.InfinityStorageManager.GetFeatureSettings then
				return _G.InfinityStorageManager:GetFeatureSettings(addonName)
			end
			InfinityUtils:Error("Storage unavailable for " .. tostring(addonName), "Core")
			return nil
		end,
		RegisterAddon = function(_, name, versionOrConfig, maybeConfig)
			if not _G.InfinityAddonManager or not _G.InfinityAddonManager.RegisterAddon then
				return
			end
			local version = "1.0.0"
			local config = {}
			if type(versionOrConfig) == "table" then
				config = versionOrConfig
				version = config.version or version
			else
				version = tostring(versionOrConfig or version)
				config = maybeConfig or {}
			end
			_G.InfinityAddonManager:RegisterAddon(name, version, config)
			return true
		end,
		RegisterSlashCommand = function(_, command, callback, aliases)
			if not _G.InfinityCommandRegistry or not _G.InfinityCommandRegistry.RegisterCommand then
				return false
			end
			if type(callback) ~= "function" then
				InfinityUtils:Warning("Invalid slash command callback: " .. tostring(command), "Core")
				return false
			end
			local aliasList = aliases
			if type(aliases) == "string" then
				aliasList = { aliases }
			end
			return _G.InfinityCommandRegistry:RegisterCommand(command, function(_, message)
				return callback(message)
			end, aliasList)
		end,
		RegisterCommand = function(_, command, descOrCallback, maybeCallbackOrAliases)
			if not _G.InfinityCommandRegistry or not _G.InfinityCommandRegistry.RegisterCommand then
				return false
			end
			if type(descOrCallback) == "function" then
				local cmd = string.gsub(string.lower(tostring(command)), "^/", "")
				return _G.InfinityCommandRegistry:RegisterCommand(cmd, descOrCallback, maybeCallbackOrAliases)
			end
			if type(maybeCallbackOrAliases) ~= "function" then
				return false
			end
			local callback = maybeCallbackOrAliases
			local clean = string.gsub(string.lower(tostring(command)), "^/", "")
			local baseCmd, subCmd = clean:match("^(%S+)%s+(.+)$")
			if not baseCmd then
				baseCmd = clean
				subCmd = ""
			end
			if not commandRoutes[baseCmd] then
				commandRoutes[baseCmd] = { default = nil, subs = {} }
				_G.InfinityCommandRegistry:RegisterCommand(baseCmd, function(args, msg)
					local routes = commandRoutes[baseCmd]
					local trimmed = tostring(msg or ""):match("^%s*(.-)%s*$")
					if trimmed ~= "" then
						local lowerMsg = string.lower(trimmed)
						local bestSub, bestLen = nil, -1
						for sub, _ in pairs(routes.subs) do
							if lowerMsg == sub or lowerMsg:sub(1, #sub + 1) == (sub .. " ") then
								if #sub > bestLen then
									bestSub = sub
									bestLen = #sub
								end
							end
						end
						if bestSub then
							local rest = trimmed:sub(#bestSub + 1):match("^%s*(.-)%s*$")
							return routes.subs[bestSub](rest)
						end
					end
					if routes.default then
						return routes.default(trimmed)
					end
				end)
			end
			if subCmd == "" then
				commandRoutes[baseCmd].default = callback
			else
				commandRoutes[baseCmd].subs[subCmd] = callback
			end
			return true
		end,
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

	-- Initialize the shared UI integration after all UI components are registered.
	if InfinityUIIntegration and InfinityUIIntegration.Initialize then
		local ok, err = pcall(function() InfinityUIIntegration:Initialize() end)
		if not ok then
			InfinityUtils:Error("UI integration failed: " .. tostring(err), "Core")
		end
	end

	-- Create the main window up front so every tab is available to the command toggle.
	if InfinityMainFrame and InfinityMainFrame.Create then
		local ok, err = pcall(function() InfinityMainFrame:Create() end)
		if not ok then
			InfinityUtils:Error("Main window creation failed: " .. tostring(err), "Core")
		end
	end
	
	-- Initialize data collection (safely)
	if InfinityCoreDataCollector and InfinityCoreDataCollector.Initialize then
		local ok, err = pcall(function() InfinityCoreDataCollector:Initialize() end)
		if not ok then InfinityUtils:Error("Data collector initialization failed: " .. tostring(err), "Core") end
	end
	
	-- Register /infinity command and default keybind for opening UI
	if InfinityCommandRegistry and InfinityCommandRegistry.RegisterCommand then
		pcall(function()
			InfinityCommandRegistry:RegisterCommand("infinity", function(args, msg)
				if _G.InfinityMainFrame and _G.InfinityMainFrame.Toggle then
					_G.InfinityMainFrame:Toggle()
				end
			end, {"inf", "suite"})
			InfinityCommandRegistry:RegisterKeybind("TOGGLE_INFINITY_SUITE", "Toggle Infinity Suite Window", function()
				if _G.InfinityMainFrame and _G.InfinityMainFrame.Toggle then
					_G.InfinityMainFrame:Toggle()
				end
			end, "CTRL-I")
		end)
	end
	
	-- Register Settings panel in Blizzard Game Settings -> AddOns
	if _G.InfinitySettingsPanel and _G.InfinitySettingsPanel.RegisterBlizzardSettings then
		pcall(function() _G.InfinitySettingsPanel:RegisterBlizzardSettings() end)
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
		self:RegisterEvent("PLAYER_LOGIN")
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		if InfinityCharacterManager and InfinityCharacterManager.Initialize then
			local ok, err = pcall(function() InfinityCharacterManager:Initialize() end)
			if not ok then
				InfinityUtils:Error("Character manager initialization failed: " .. tostring(err), "Core")
			end
		end
		if InfinityCommandRegistry and InfinityCommandRegistry.ApplyAllKeybinds then
			pcall(function() InfinityCommandRegistry:ApplyAllKeybinds() end)
		end
		if InfinityMainFrame and InfinityMainFrame.RefreshIfVisible then
			pcall(function() InfinityMainFrame:RefreshIfVisible() end)
		end
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)
