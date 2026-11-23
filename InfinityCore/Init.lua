-- InfinityCore Initialization
-- Central bootstrap, addon registry, command routing, and minimap launcher for WoW Forever

local function InitializeInfinityCore()
	if _G.InfinityCore and _G.InfinityCore.initialized then
		return
	end

	_G.InfinityUtils = InfinityUtils

	if InfinityStorageManager and InfinityStorageManager.Initialize then
		pcall(function() InfinityStorageManager:Initialize(InfinityCoreDB) end)
		_G.InfinityStorageManager = InfinityStorageManager
		_G.InfinityCoreDB = InfinityCoreDB
	end

	if InfinityDataManager then _G.InfinityDataManager = InfinityDataManager end
	if InfinityMessaging then _G.InfinityMessaging = InfinityMessaging end
	if InfinityEventRouter then _G.InfinityEventRouter = InfinityEventRouter end
	if InfinityCommandRegistry then _G.InfinityCommandRegistry = InfinityCommandRegistry end
	if InfinityUIFramework then _G.InfinityUIFramework = InfinityUIFramework end
	if InfinityMainFrame then _G.InfinityMainFrame = InfinityMainFrame end
	if InfinitySettingsPanel then _G.InfinitySettingsPanel = InfinitySettingsPanel end
	if InfinityAddonManager then _G.InfinityAddonManager = InfinityAddonManager end
	if InfinityOfficerDashboard then _G.InfinityOfficerDashboard = InfinityOfficerDashboard end

	_G.InfinityCore = {
		name = INFINITY_CORE_NAME or "InfinityCore",
		version = INFINITY_SUITE_VERSION or "1.0.0",
		initialized = true,
		addons = {},
	}

	function _G.InfinityCore:RegisterAddon(name, versionOrConfig, maybeConfig)
		if not name then return false end
		local config
		if type(versionOrConfig) == "table" then
			config = versionOrConfig
		else
			config = type(maybeConfig) == "table" and maybeConfig or {}
			if type(versionOrConfig) == "string" and not config.version then
				config.version = versionOrConfig
			end
		end
		self.addons[name] = config
		if _G.InfinityAddonManager and _G.InfinityAddonManager.RegisterAddon then
			_G.InfinityAddonManager:RegisterAddon(name, config.version or "1.0.0", config)
		end
		return true
	end

	function _G.InfinityCore:RegisterCommand(cmd, descOrFn, fnOrAliases)
		if _G.InfinityCommandRegistry and _G.InfinityCommandRegistry.RegisterCommand then
			return _G.InfinityCommandRegistry:RegisterCommand(cmd, descOrFn, fnOrAliases)
		end
		return false
	end

	function _G.InfinityCore:RegisterSlashCommand(cmd, callback, aliasOrSub)
		if not cmd or type(callback) ~= "function" then
			return false
		end
		if not (_G.InfinityCommandRegistry and _G.InfinityCommandRegistry.RegisterCommand) then
			return false
		end

		local cleanCmd = string.lower((tostring(cmd):gsub("^/", "")):match("^%s*(.-)%s*$") or "")
		if cleanCmd == "" then return false end

		local wrappedCallback = function(argsOrMsg, rawMsg)
			local text = ""
			if type(argsOrMsg) == "string" then
				text = argsOrMsg
			elseif type(rawMsg) == "string" then
				text = rawMsg
			elseif type(argsOrMsg) == "table" then
				text = table.concat(argsOrMsg, " ")
			end
			return callback(text)
		end

		local aliases = {}
		if type(aliasOrSub) == "string" and aliasOrSub ~= "" then
			local cleanAlias = string.lower((aliasOrSub:gsub("^/", "")):match("^%s*(.-)%s*$") or "")
			if cleanAlias ~= "" and cleanAlias ~= cleanCmd then
				table.insert(aliases, cleanAlias)
			end
		elseif type(aliasOrSub) == "table" then
			aliases = aliasOrSub
		end

		_G.InfinityCommandRegistry:RegisterCommand(cleanCmd, wrappedCallback, aliases)
		_G.InfinityCommandRegistry:RegisterCommand("infinity " .. cleanCmd, cleanCmd .. " subcommand", wrappedCallback)
		return true
	end

	function _G.InfinityCore:GetRegisteredAddons()
		return self.addons
	end

	if InfinityEventRouter and InfinityEventRouter.Initialize then
		pcall(function() InfinityEventRouter:Initialize() end)
	end

	if InfinityUIFramework and InfinityUIFramework.Initialize then
		pcall(function() InfinityUIFramework:Initialize() end)
	end

	if InfinitySettingsPanel and InfinitySettingsPanel.Initialize then
		pcall(function() InfinitySettingsPanel:Initialize() end)
	end

	if InfinityAddonManager and InfinityAddonManager.Initialize then
		pcall(function() InfinityAddonManager:Initialize() end)
	end

	if InfinityDataCollector and InfinityDataCollector.Initialize then
		pcall(function() InfinityDataCollector:Initialize() end)
	end

	-- Register core self
	_G.InfinityCore:RegisterAddon("InfinityCore", {
		version = INFINITY_SUITE_VERSION or "1.0.0",
		author = "Infinity Forever",
		description = "Core UI framework, storage, event routing, and suite hub",
		category = "Core",
		enabled = true,
	})

	-- Register primary suite slash commands
	if InfinityCommandRegistry and InfinityCommandRegistry.RegisterCommand then
		InfinityCommandRegistry:RegisterCommand("infinity", function(args)
			local sub = args and args[1] and string.lower(args[1]) or ""
			if sub == "dashboard" or sub == "officer" then
				if _G.InfinityOfficerDashboard and _G.InfinityOfficerDashboard.Toggle then
					_G.InfinityOfficerDashboard:Toggle()
				end
			elseif sub == "addons" then
				if _G.InfinityAddonManager and _G.InfinityAddonManager.Toggle then
					_G.InfinityAddonManager:Toggle()
				end
			elseif sub == "settings" then
				if _G.InfinitySettingsPanel and _G.InfinitySettingsPanel.Toggle then
					_G.InfinitySettingsPanel:Toggle()
				end
			else
				if _G.InfinityMainFrame and _G.InfinityMainFrame.Toggle then
					_G.InfinityMainFrame:Toggle()
				end
			end
		end, { "inf", "suite" })

		InfinityCommandRegistry:RegisterCommand("officer", function()
			if _G.InfinityOfficerDashboard and _G.InfinityOfficerDashboard.Toggle then
				_G.InfinityOfficerDashboard:Toggle()
			end
		end, { "infdash" })
	end

	-- Create minimap launcher button
	if InfinityUIFramework and InfinityUIFramework.CreateMinimapButton then
		pcall(function() InfinityUIFramework:CreateMinimapButton() end)
	end

	pcall(function()
		if _G.InfinityUtils then
			_G.InfinityUtils:Info("Infinity Suite v" .. (INFINITY_SUITE_VERSION or "1.0.0") .. " (1.60.1-fixed) loaded! Use /infinity or click the minimap orb.", "Core")
		end
	end)

	if InfinityMessaging and InfinityMessaging.Publish then
		pcall(function()
			InfinityMessaging:Publish("INFINITY_DATA_LOADED")
		end)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addonName)
	if (event == "ADDON_LOADED" and addonName == (INFINITY_CORE_NAME or "InfinityCore")) or event == "PLAYER_LOGIN" then
		InitializeInfinityCore()
		if event == "ADDON_LOADED" then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end)
