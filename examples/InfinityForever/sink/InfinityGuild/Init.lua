-- InfinityGuild Initialization
-- Main entry point for the Guild management addon

local function InitializeGuild()
	-- Wait for InfinityCore to be ready
	if not _G.InfinityDataManager or not _G.InfinityStorageManager then
		InfinityUtils:Warn("InfinityCore not loaded yet, deferring", "InfinityGuild")
		return
	end
	
	InfinityUtils:Info("InfinityGuild initializing...", "InfinityGuild")
	
	-- Load modules
	local Roster = require("InfinityGuild.Modules.Roster")
	local DKP = require("InfinityGuild.Modules.DKP")
	local Events = require("InfinityGuild.Modules.Events")
	local UI = require("InfinityGuild.UI.MainUI")
	
	-- Initialize modules
	Roster:Initialize()
	DKP:Initialize()
	Events:Initialize()
	
	-- Expose modules globally
	_G.InfinityGuildRoster = Roster
	_G.InfinityGuildDKP = DKP
	_G.InfinityGuildEvents = Events
	_G.InfinityGuildUI = UI
	
	-- Register data sources
	InfinityDataManager:RegisterSource("InfinityGuild", { roster = {}, dkp = {}, events = {} })
	
	-- Register slash commands
	InfinityCommandRegistry:RegisterCommand({
		name = "guild",
		aliases = { "g", "gm" },
		description = "Open guild manager",
		func = function()
			InfinityGuildUI:Toggle()
		end,
	})
	
	InfinityCommandRegistry:RegisterCommand({
		name = "guildroster",
		aliases = { "gr" },
		description = "Open guild roster",
		func = function()
			InfinityGuildUI:Toggle()
			-- TODO: Focus on roster tab
		end,
	})
	
	-- Register keybinds
	InfinityCommandRegistry:RegisterKeybind({
		name = "INFINITY_GUILD_TOGGLE",
		description = "Toggle Guild Manager",
		defaultKey = "ALT-G",
		action = function()
			InfinityGuildUI:Toggle()
		end,
	})
	
	InfinityUtils:Info("InfinityGuild initialized successfully", "InfinityGuild")
	InfinityMessaging:Publish("guild_addon_loaded", { addon = "InfinityGuild" })
end

-- Hook into InfinityCore's initialization
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityCore" then
		InitializeGuild()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "InfinityGuild" then
		-- Check if core is ready
		if _G.InfinityDataManager then
			InitializeGuild()
		end
	end
end)


