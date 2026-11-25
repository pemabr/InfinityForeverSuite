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
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("Bags & Bank")
				end
			elseif sub == "profs" or sub == "professions" or sub == "shop" or sub == "todo" or sub == "einkaufsliste" or sub == "shopping" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					if sub == "shop" or sub == "todo" or sub == "einkaufsliste" or sub == "shopping" then
						_G.PluribusMainFrame.profSubTab = "wishlist"
					end
					_G.PluribusMainFrame:OpenToTab("Professions")
				end
			elseif sub == "tax" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("Guild Tax")
				end
			elseif sub == "mail" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("Guild Mail")
				end
			elseif sub == "nav" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("Navigation")
				end
			elseif sub == "guides" or sub == "compute" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("Guides")
				end
			elseif sub == "gear" or sub == "gearadvisor" or sub == "advisor" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("GearAdvisor")
				end
			elseif sub == "cd" or sub == "cooldowns" then
				if _G.PluribusHiveUI and _G.PluribusHiveUI.ToggleCooldownOverlay then
					_G.PluribusHiveUI:ToggleCooldownOverlay()
				end
			elseif sub == "heal" or sub == "healer" or sub == "healbot" or sub == "hb" or sub == "decursive" or sub == "dcr" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					if sub == "decursive" or sub == "dcr" then
						_G.PluribusMainFrame.healSubTab = "decursive"
					end
					_G.PluribusMainFrame:OpenToTab("HealBot")
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
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Bags & Bank") end
			elseif sub == "cd" or sub == "cooldowns" then
				if _G.PluribusHiveUI then _G.PluribusHiveUI:ToggleCooldownOverlay() end
			elseif sub == "sos" then
				if _G.PluribusHiveDistress then _G.PluribusHiveDistress:BroadcastSOS(true) end
			elseif sub == "sync" then
				if _G.PluribusHive then _G.PluribusHive:RequestFullGuildSync() end
				if _G.PluribusHiveNetworkDB then _G.PluribusHiveNetworkDB:CheckForNetworkUpdates() end
				if _G.PluribusUtils then _G.PluribusUtils:Info("Requested full Guild Hive sync + DB update check.", "Hive") end
			elseif sub == "profs" or sub == "professions" or sub == "shop" or sub == "todo" or sub == "einkaufsliste" or sub == "shopping" then
				if _G.PluribusMainFrame then
					if sub == "shop" or sub == "todo" or sub == "einkaufsliste" or sub == "shopping" then
						_G.PluribusMainFrame.profSubTab = "wishlist"
					end
					_G.PluribusMainFrame:OpenToTab("Professions")
				end
			elseif sub == "tax" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Guild Tax") end
			elseif sub == "mail" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Guild Mail") end
			elseif sub == "nav" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Navigation") end
			elseif sub == "guides" or sub == "compute" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Guides") end
			elseif sub == "gear" or sub == "gearadvisor" or sub == "advisor" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("GearAdvisor") end
			elseif sub == "market" or sub == "db" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Market & DB") end
			elseif sub == "lfg" then
				if _G.PluribusMainFrame then _G.PluribusMainFrame:OpenToTab("Guild Hub") end
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

		PluribusCommandRegistry:RegisterCommand("tax", function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Guild Tax")
			end
		end, { "guildtax" })

		PluribusCommandRegistry:RegisterCommand("mail", function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Guild Mail")
			end
		end, { "guildmail" })

		PluribusCommandRegistry:RegisterCommand("guides", function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Guides")
			end
		end, { "hiveguides", "farmguide" })

		PluribusCommandRegistry:RegisterCommand("todo", function(args)
			local first = (type(args) == "table" and args[1]) or (type(args) == "string" and args) or ""
			first = tostring(first):lower()
			if first == "popout" or first == "pop" or first == "float" then
				if _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.ToggleTodoPopout then
					_G.PluribusHiveProfessions:ToggleTodoPopout()
				end
				return
			end
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame.profSubTab = "wishlist"
				_G.PluribusMainFrame:OpenToTab("Professions")
			end
		end, { "einkaufsliste", "shopping", "wishlist" })

		PluribusCommandRegistry:RegisterCommand("todopop", function()
			if _G.PluribusHiveProfessions and _G.PluribusHiveProfessions.ToggleTodoPopout then
				_G.PluribusHiveProfessions:ToggleTodoPopout()
			end
		end, { "todopopout" })

		PluribusCommandRegistry:RegisterCommand("mitglieder", function()
			if _G.PluribusHive and _G.PluribusHive.RequestVersionCheck then
				_G.PluribusHive:RequestVersionCheck()
			end
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Roster")
			end
		end, { "plbroster", "addoncheck" })

		PluribusCommandRegistry:RegisterCommand("gearadvisor", function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("GearAdvisor")
			end
		end, { "plbgear", "advisor" })

		PluribusCommandRegistry:RegisterCommand("xpbar", function()
			local ga = _G.PluribusGearAdvisor or _G.PluribusHiveGearJudge
			if ga and ga.ToggleXPBar then
				ga:ToggleXPBar()
			end
		end, { "lootbar" })

		PluribusCommandRegistry:RegisterCommand("plbofficer", function()
			if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.Toggle then
				_G.PluribusOfficerDashboard:Toggle()
			end
		end, { "plbdash", "offizier" })

		PluribusCommandRegistry:RegisterCommand("audit", function(args)
			if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.OpenTransactionHistory then
				local filter = type(args) == "string" and args or ""
				_G.PluribusOfficerDashboard:OpenTransactionHistory(filter, "ALL")
			end
		end, { "txlog", "officerlog" })

		PluribusCommandRegistry:RegisterCommand("markerbar", function()
			if _G.PluribusHiveRaidTools and _G.PluribusHiveRaidTools.ToggleMarkerBar then
				_G.PluribusHiveRaidTools:ToggleMarkerBar()
			end
		end, { "raidbar", "markbar" })

		PluribusCommandRegistry:RegisterCommand("pull", function(args)
			if _G.PluribusHiveRaidTools and _G.PluribusHiveRaidTools.StartPullTimer then
				local raw = type(args) == "table" and args[1] or args
				local sec = tonumber(raw)
				if raw and tostring(raw):lower() == "cancel" then
					_G.PluribusHiveRaidTools:StartPullTimer(0)
				else
					_G.PluribusHiveRaidTools:StartPullTimer(sec)
				end
			end
		end, { "pulltimer" })

		PluribusCommandRegistry:RegisterCommand("readycheck", function()
			if _G.PluribusHiveRaidTools and _G.PluribusHiveRaidTools.OpenReadyCheckWindow then
				_G.PluribusHiveRaidTools:OpenReadyCheckWindow(true)
			end
		end, { "rc", "bcheck" })

		PluribusCommandRegistry:RegisterCommand("cdconfig", function()
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("CooldownConfig")
			end
		end, { "cdmenu", "raidcds" })

		-- Built-in HealBot + Decursive commands (always available inside PluribusCore!)
		PluribusCommandRegistry:RegisterCommand("healbot", function(args)
			local sub = args and args[1] and string.lower(args[1]) or ""
			local eng = _G.PluribusHealDecursive
			if sub == "frames" or sub == "grid" or sub == "toggle" then
				if eng then eng:ToggleGrid() end
			elseif sub == "show" or sub == "on" or sub == "solo" then
				if eng then
					eng.config.enabled = true
					eng.config.showSolo = true
					eng:SaveConfig()
					eng:RequestRebuild()
				end
			elseif sub == "hide" or sub == "off" then
				if eng then
					eng.config.enabled = false
					eng:SaveConfig()
					eng:RequestRebuild()
				end
			elseif sub == "muf" or sub == "decursive" then
				if eng then eng:ToggleCompactMUF() end
			elseif _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("HealBot")
			elseif _G.PluribusHealerUI and _G.PluribusHealerUI.Toggle then
				_G.PluribusHealerUI:Toggle()
			end
		end, { "hb", "healer", "heal" })

		PluribusCommandRegistry:RegisterCommand("decursive", function(args)
			local sub = args and args[1] and string.lower(args[1]) or ""
			if sub == "config" or sub == "cfg" then
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame.healSubTab = "decursive"
					_G.PluribusMainFrame:OpenToTab("HealBot")
				end
			elseif _G.PluribusHealDecursive then
				_G.PluribusHealDecursive:ToggleCompactMUF()
			elseif _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame.healSubTab = "decursive"
				_G.PluribusMainFrame:OpenToTab("HealBot")
			end
		end, { "dcr", "decurse" })
	end

	-- Attach Officer Dashboard DKP/Loot/Audit hooks immediately on login so nothing is missed
	if _G.PluribusOfficerDashboard and _G.PluribusOfficerDashboard.AttachAuditHooks then
		pcall(function() _G.PluribusOfficerDashboard:AttachAuditHooks() end)
	end

	-- Create minimap launcher button
	if PluribusUIFramework and PluribusUIFramework.CreateMinimapButton then
		pcall(function() PluribusUIFramework:CreateMinimapButton() end)
	end

	pcall(function()
		if _G.PluribusUtils then
			_G.PluribusUtils:Info("Pluribus Suite v2.2 (1.60.1) active! Use /pluribus, /todo, /bags, /guides, /gearadvisor, /xpbar, /tax, /mail, /audit, or @Name in /g.", "Core")
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
