-- PluribusGuild Initialization
-- Main entry point for the Guild management addon

local function InitializeGuild()
	-- Wait for PluribusCore to be ready
	if not _G.PluribusDataManager or not _G.PluribusStorageManager then
		PluribusUtils:Warn("PluribusCore not loaded yet, deferring", "PluribusGuild")
		return
	end
	
	PluribusUtils:Info("PluribusGuild initializing...", "PluribusGuild")
	
	-- Load modules
	local Roster = PluribusGuildRoster or _G.PluribusGuildRoster
	local DKP = PluribusGuildDKP or _G.PluribusGuildDKP
	local Events = PluribusGuildEvents or _G.PluribusGuildEvents
	local UI = PluribusGuildUI or _G.PluribusGuildUI
	
	-- Initialize modules
	if Roster then pcall(function() Roster:Initialize() end) end
	if DKP then pcall(function() DKP:Initialize() end) end
	if Events then pcall(function() Events:Initialize() end) end
	
	-- Expose modules globally
	_G.PluribusGuildRoster = Roster
	_G.PluribusGuildDKP = DKP
	_G.PluribusGuildEvents = Events
	_G.PluribusGuildUI = UI
	
	-- Register data sources
	PluribusDataManager:RegisterSource("PluribusGuild", { roster = {}, dkp = {}, events = {} })
	
	-- Register slash commands (never shadow WoW's /g or /guild chat commands)
	PluribusCommandRegistry:RegisterCommand({
		name = "plbguild",
		aliases = { "pguild" },
		description = "Open guild manager",
		func = function()
			PluribusGuildUI:Toggle()
		end,
	})
	
	PluribusCommandRegistry:RegisterCommand({
		name = "guildroster",
		aliases = { "plbroster" },
		description = "Open guild roster",
		func = function()
			PluribusGuildUI:FocusTab("roster")
		end,
	})
	
	-- Register keybinds
	PluribusCommandRegistry:RegisterKeybind({
		name = "PLURIBUS_GUILD_TOGGLE",
		description = "Toggle Guild Manager",
		defaultKey = "ALT-G",
		action = function()
			PluribusGuildUI:Toggle()
		end,
	})
	
	PluribusUtils:Info("PluribusGuild initialized successfully", "PluribusGuild")
	PluribusMessaging:Publish("guild_addon_loaded", { addon = "PluribusGuild" })
end

-- Hook into PluribusCore's initialization

local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Guild management",
			author = "Pluribus Suite Team",
			category = "Guild",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusCore" then
		InitializeGuild()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "PluribusGuild" then
		-- Check if core is ready
		if _G.PluribusDataManager then
			InitializeGuild()
		end
	end
end)




