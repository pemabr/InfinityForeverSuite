-- PluribusCore Initialization
-- Central bootstrap, addon registry, command routing, and minimap launcher for WoW Forever

local function InitializePluribusCore()
	if _G.PluribusCore and _G.PluribusCore.initialized then
		return
	end

	_G.PluribusUtils = PluribusUtils

	if PluribusStorageManager and PluribusStorageManager.Initialize then
		pcall(function() PluribusStorageManager:Initialize(PluribusCoreDB) end)
		_G.PluribusStorageManager = PluribusStorageManager
		_G.PluribusCoreDB = PluribusCoreDB
	end

	if PluribusDataManager then _G.PluribusDataManager = PluribusDataManager end
	if PluribusMessaging then _G.PluribusMessaging = PluribusMessaging end
	if PluribusEventRouter then _G.PluribusEventRouter = PluribusEventRouter end
	if PluribusCommandRegistry then _G.PluribusCommandRegistry = PluribusCommandRegistry end
	if PluribusUIFramework then _G.PluribusUIFramework = PluribusUIFramework end
	if PluribusMainFrame then _G.PluribusMainFrame = PluribusMainFrame end
	if PluribusSettingsPanel then _G.PluribusSettingsPanel = PluribusSettingsPanel end
	if PluribusAddonManager then _G.PluribusAddonManager = PluribusAddonManager end
	if PluribusOfficerDashboard then _G.PluribusOfficerDashboard = PluribusOfficerDashboard end

	_G.PluribusCore = {
		name = PLURIBUS_CORE_NAME or "PluribusCore",
		version = PLURIBUS_SUITE_VERSION or "2.0.0",
		initialized = true,
		addons = {},
		OfficerDashboard = _G.PluribusOfficerDashboard,
		Hive = _G.PluribusHive,
	}

	function _G.PluribusCore:RegisterAddon(name, versionOrConfig, maybeConfig)
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
		if _G.PluribusAddonManager and _G.PluribusAddonManager.RegisterAddon then
			_G.PluribusAddonManager:RegisterAddon(name, config.version or "1.0.0", config)
		end
		return true
	end

	function _G.PluribusCore:RegisterCommand(cmd, descOrFn, fnOrAliases)
		if _G.PluribusCommandRegistry and _G.PluribusCommandRegistry.RegisterCommand then
			return _G.PluribusCommandRegistry:RegisterCommand(cmd, descOrFn, fnOrAliases)
		end
		return false
	end

	function _G.PluribusCore:RegisterSlashCommand(cmd, callback, aliasOrSub)
		if not cmd or type(callback) ~= "function" then
			return false
		end
		if not (_G.PluribusCommandRegistry and _G.PluribusCommandRegistry.RegisterCommand) then
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

		_G.PluribusCommandRegistry:RegisterCommand(cleanCmd, wrappedCallback, aliases)
		_G.PluribusCommandRegistry:RegisterCommand("pluribus " .. cleanCmd, cleanCmd .. " subcommand", wrappedCallback)
		return true
	end

	function _G.PluribusCore:GetRegisteredAddons()
		return self.addons
	end

	if PluribusEventRouter and PluribusEventRouter.Initialize then
		pcall(function() PluribusEventRouter:Initialize() end)
	end

	if PluribusUIFramework and PluribusUIFramework.Initialize then
		pcall(function() PluribusUIFramework:Initialize() end)
	end

	if PluribusSettingsPanel and PluribusSettingsPanel.Initialize then
		pcall(function() PluribusSettingsPanel:Initialize() end)
	end

	if PluribusAddonManager and PluribusAddonManager.Initialize then
		pcall(function() PluribusAddonManager:Initialize() end)
	end

	if PluribusDataCollector and PluribusDataCollector.Initialize then
		pcall(function() PluribusDataCollector:Initialize() end)
	end

	-- Initialize the unified Guild Hive-Mind Engine
	if _G.PluribusHive and _G.PluribusHive.Initialize then
		pcall(function() _G.PluribusHive:Initialize() end)
	end

	-- Register core self
	_G.PluribusCore:RegisterAddon("PluribusCore", {
		version = PLURIBUS_SUITE_VERSION or "2.0.0",
		author = "Pluribus",
		description = "Guild Hive-Mind Hub, unified UI framework, storage, and comms",
		category = "Core",
		enabled = true,
	})

	-- Register primary suite & Hive slash commands
	if PluribusCommandRegistry and PluribusCommandRegistry.RegisterCommand then
		PluribusCommandRegistry:RegisterCommand("pluribus", function(args)
			local sub = args and args[1] and string.lower(args[1]) or ""
			if sub == "dashboard" or sub == "officer" then
				if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.Toggle then
					_G.PluribusOfficerDashboard:Toggle()
				end
			elseif sub == "addons" or sub == "modules" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("Modules")
				end
			elseif sub == "settings" or sub == "options" or sub == "config" or sub == "privacy" then
				if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
					_G.PluribusSettingsPanel:Open(sub == "privacy" and "HiveMind Sharing" or nil)
				end
			elseif sub == "bags" or sub == "bank" then
				if _G.PluribusHiveUI and _G.PluribusHiveUI.ToggleInventoryViewer then
					_G.PluribusHiveUI:ToggleInventoryViewer()
				end
			elseif sub == "profs" or sub == "professions" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("Professions")
				end
			elseif sub == "cd" or sub == "cooldowns" then
				if _G.PluribusHiveUI and _G.PluribusHiveUI.ToggleCooldownOverlay then
					_G.PluribusHiveUI:ToggleCooldownOverlay()
				end
			else
				if _G.PluribusMainFrame and _G.PluribusMainFrame.Toggle then
					_G.PluribusMainFrame:Toggle()
				end
			end
		end, { "plb", "plur", "suite" })

		PluribusCommandRegistry:RegisterCommand("hive", function(args)
			local sub = args and args[1] and string.lower(args[1]) or ""
			if sub == "bags" or sub == "bank" then
				if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleInventoryViewer() end
			elseif sub == "cd" or sub == "cooldowns" then
				if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleCooldownOverlay() end
			elseif sub == "sos" then
				if _G.PluribusHiveDistress then _G.PluribusHiveDistress:BroadcastSOS(true) end
			elseif sub == "sync" then
				if _G.PluribusHive then _G.PluribusHive:RequestFullGuildSync() end
				if _G.PluribusHiveNetworkDB then _G.PluribusHiveNetworkDB:CheckForNetworkUpdates() end
				if _G.PluribusUtils then _G.PluribusUtils:Info("Requested full Guild Hive sync + DB update check.", "Hive") end
			elseif sub == "profs" or sub == "professions" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Professions") end
			elseif sub == "market" or sub == "db" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Market & DB") end
			elseif sub == "lfg" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Hive Live") end
			elseif sub == "settings" or sub == "options" or sub == "privacy" then
				if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Open then
					_G.PluribusSettingsPanel:Open(sub == "privacy" and "HiveMind Sharing" or nil)
				end
			else
				if _G.PluribusMainFrame then _G.PluribusMainFrame:Toggle() end
			end
		end)

		PluribusCommandRegistry:RegisterCommand("sos", function()
			if _G.PluribusHiveDistress then
				local ok = _G.PluribusHiveDistress:BroadcastSOS(true)
				if not ok and _G.PluribusUtils then
					_G.PluribusUtils:Warning("SOS is only active in the open world (disabled inside instances & raids).", "Hive")
				end
			end
		end)

		PluribusCommandRegistry:RegisterCommand("bags", function()
			if _G.PluribusHiveUI and _G.PluribusHiveUI.ToggleInventoryViewer then
				_G.PluribusHiveUI:ToggleInventoryViewer()
			end
		end, { "hivebags", "altbags" })

		PluribusCommandRegistry:RegisterCommand("officer", function()
			if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.Toggle then
				_G.PluribusOfficerDashboard:Toggle()
			end
		end, { "plbdash" })
	end

	-- Create minimap launcher button
	if PluribusUIFramework and PluribusUIFramework.CreateMinimapButton then
		pcall(function() PluribusUIFramework:CreateMinimapButton() end)
	end

	pcall(function()
		if _G.PluribusUtils then
			_G.PluribusUtils:Info("Pluribus Suite v2.0 (1.60.1) active! Use /pluribus, /plb settings, /bags, or ESC -> Options -> AddOns -> Pluribus Suite.", "Core")
		end
	end)

	if PluribusMessaging and PluribusMessaging.Publish then
		pcall(function()
			PluribusMessaging:Publish("PLURIBUS_DATA_LOADED")
		end)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addonName)
	if (event == "ADDON_LOADED" and addonName == (PLURIBUS_CORE_NAME or "PluribusCore")) or event == "PLAYER_LOGIN" then
		InitializePluribusCore()
		if event == "ADDON_LOADED" then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end)
