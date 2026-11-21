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
	local Roster = InfinityGuildRoster or _G.InfinityGuildRoster
	local DKP = InfinityGuildDKP or _G.InfinityGuildDKP
	local Events = InfinityGuildEvents or _G.InfinityGuildEvents
	local UI = InfinityGuildUI or _G.InfinityGuildUI
	
	-- Initialize modules
	if Roster then pcall(function() Roster:Initialize() end) end
	if DKP then pcall(function() DKP:Initialize() end) end
	if Events then pcall(function() Events:Initialize() end) end
	
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
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityGuild", "1.0.0", {
			description = "Guild management",
			author = "Infinity Suite Team",
			category = "Guild",
			enabled = true,
			settings = {}
		})
	end
	
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




