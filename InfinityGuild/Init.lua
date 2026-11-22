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
	
	-- Register before modules can publish their initial data.
	InfinityDataManager:RegisterSource("InfinityGuild", { roster = {}, dkp = {}, events = {} })

	for _, module in ipairs({ Roster, DKP, Events }) do
		local ok, err = pcall(module.Initialize, module)
		if not ok then
			InfinityUtils:Error("Guild module initialization failed: " .. tostring(err), "InfinityGuild")
		end
	end
	
	-- Expose modules globally
	_G.InfinityGuildRoster = Roster
	_G.InfinityGuildDKP = DKP
	_G.InfinityGuildEvents = Events
	_G.InfinityGuildUI = UI
	
	-- Register slash commands
	InfinityCommandRegistry:RegisterCommand({
		name = "infguild",
		aliases = {},
		description = "Open guild manager",
		func = function()
			InfinityGuildUI:Toggle()
		end,
	})
	
	InfinityCommandRegistry:RegisterCommand({
		name = "infguildroster",
		aliases = {},
		description = "Open guild roster",
		func = function()
			if _G.InfinityGuildRoster and _G.InfinityGuildRoster.ScanGuildRoster then
				_G.InfinityGuildRoster:ScanGuildRoster()
			end
			if not _G.InfinityGuildWindow then
				InfinityGuildUI:Toggle()
			else
				_G.InfinityGuildWindow:Show()
				InfinityGuildUI:ShowTab(_G.InfinityGuildWindow, "roster")
			end
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
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end)




