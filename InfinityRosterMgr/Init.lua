-- InfinityRosterMgr Initialization

local ADDON_NAME = "InfinityRosterMgr"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so InfinityRosterManager global is already created

local function InitializeRosterManager()
	-- Wait for InfinityCore to be fully loaded
	if not _G.InfinityCore or not _G.InfinityUtils or not _G.InfinityCommandRegistry then
		if _G.InfinityUtils then
			InfinityUtils:Warning("InfinityCore not fully loaded, deferring initialization", ADDON_NAME)
		end
		C_Timer.After(0.5, InitializeRosterManager)
		return
	end
	
	-- Initialize roster manager
	if InfinityRosterManager and InfinityRosterManager.Initialize then
		if InfinityRosterManager then pcall(function() InfinityRosterManager:Initialize() end) end
	end
	
	-- Register addon with AddonManager

	
	 if _G.InfinityAddonManager then

	
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {

	
			description = "Guild roster management and member tracking",

	
			author = "Infinity Suite Team",

	
			category = "Guild",

	
			enabled = true,

	
			settings = {}

	
		})

	
	 end

	
	
	
	-- Register commands
	InfinityCommandRegistry:RegisterCommand("roster", function(args)
		if not IsInGuild() then
			InfinityUtils:Warning("You are not in a guild", ADDON_NAME)
			return
		end
		
		if not args or #args == 0 then
			local info = InfinityRosterManager:GetGuildInfo()
			InfinityUtils:Info("=== " .. info.name .. " ===", ADDON_NAME)
			InfinityUtils:Info("Members: " .. info.totalMembers, ADDON_NAME)
		else
			local subcommand = string.lower(args[1] or "")
			if subcommand == "scan" then
				InfinityRosterManager:ScanGuild()
				InfinityUtils:Info("Guild roster scanned", ADDON_NAME)
			elseif subcommand == "stats" then
				local stats = InfinityRosterManager:GetRosterStats()
				InfinityUtils:Info("Guild Statistics:", ADDON_NAME)
				InfinityUtils:Info("  Total Members: " .. stats.totalMembers, ADDON_NAME)
				InfinityUtils:Info("  Online: " .. stats.onlineMembers, ADDON_NAME)
				InfinityUtils:Info("  Average Level: " .. stats.averageLevel, ADDON_NAME)
			elseif subcommand == "online" then
				local online = InfinityRosterManager:GetOnlineMembers()
				InfinityUtils:Info("Online Members (" .. #online .. "):", ADDON_NAME)
				for _, member in ipairs(online) do
					InfinityUtils:Info("  " .. member.name .. " (" .. member.level .. " " .. member.class .. ")", ADDON_NAME)
				end
			elseif subcommand == "class" then
				if args[2] then
					local classMembers = InfinityRosterManager:GetMembersByClass(args[2])
					InfinityUtils:Info("Members of " .. args[2] .. " (" .. #classMembers .. "):", ADDON_NAME)
					for _, member in ipairs(classMembers) do
						InfinityUtils:Info("  " .. member.name .. " (Level " .. member.level .. ")", ADDON_NAME)
					end
				end
			elseif subcommand == "zone" then
				if args[2] then
					local zoneMembers = InfinityRosterManager:FindMembersByZone(args[2])
					InfinityUtils:Info("Members in " .. args[2] .. " (" .. #zoneMembers .. "):", ADDON_NAME)
					for _, member in ipairs(zoneMembers) do
						InfinityUtils:Info("  " .. member.name, ADDON_NAME)
					end
				end
			end
		end
	end, {"members", "guild"})
	
	-- Register keybind
	InfinityCommandRegistry:RegisterKeybind("SHOW_ROSTER", "Show Guild Roster", function()
		local info = InfinityRosterManager:GetGuildInfo()
		InfinityUtils:Info("Guild: " .. info.name .. " (" .. info.totalMembers .. " members)", ADDON_NAME)
	end)
	
	-- Hook into guild events
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
	eventFrame:SetScript("OnEvent", function(self, event)
		if event == "GUILD_ROSTER_UPDATE" then
			InfinityRosterManager:ScanGuild()
		end
	end)
	
	InfinityUtils:Info("Roster Manager addon loaded v" .. ADDON_VERSION, ADDON_NAME)
	InfinityUtils:Info("Use |cff00ccff/roster|r for guild commands", ADDON_NAME)
end

-- Hook into addon loaded and InfinityCore ready events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == ADDON_NAME then
		addonLoaded = true
		-- If InfinityCore is already loaded, initialize immediately
		if _G.InfinityCore and _G.InfinityUtils and _G.InfinityCommandRegistry then
			InitializeRosterManager()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		-- Initialize when InfinityCore broadcasts it's ready
		InitializeRosterManager()
	end
end)

-- Also subscribe to the messaging event from InfinityCore
if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeRosterManager()
		end
	end)
end


