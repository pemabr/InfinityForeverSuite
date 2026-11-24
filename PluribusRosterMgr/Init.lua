-- PluribusRosterMgr Initialization

local ADDON_NAME = "PluribusRosterMgr"
local ADDON_VERSION = "1.0.0"

-- Modules are loaded via .toc file, so PluribusRosterManager global is already created

local function InitializeRosterManager()
	-- Wait for PluribusCore to be fully loaded
	if not _G.PluribusCore or not _G.PluribusUtils or not _G.PluribusCommandRegistry then
		if _G.PluribusUtils then
			PluribusUtils:Warning("PluribusCore not fully loaded, deferring initialization", ADDON_NAME)
		end
		C_Timer.After(0.5, InitializeRosterManager)
		return
	end
	
	-- Initialize roster manager
	if PluribusRosterManager and PluribusRosterManager.Initialize then
		if PluribusRosterManager then pcall(function() PluribusRosterManager:Initialize() end) end
	end
	
	-- Register addon with AddonManager

	
	 if _G.PluribusAddonManager then

	
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {

	
			description = "Guild roster management and member tracking",

	
			author = "Pluribus Suite Team",

	
			category = "Guild",

	
			enabled = true,

	
			settings = {}

	
		})

	
	 end

	
	
	
	-- Register commands
	PluribusCommandRegistry:RegisterCommand("roster", function(args)
		if not IsInGuild() then
			PluribusUtils:Warning("You are not in a guild", ADDON_NAME)
			return
		end
		
		if not args or #args == 0 then
			local info = PluribusRosterManager:GetGuildInfo()
			PluribusUtils:Info("=== " .. info.name .. " ===", ADDON_NAME)
			PluribusUtils:Info("Members: " .. info.totalMembers, ADDON_NAME)
		else
			local subcommand = string.lower(args[1] or "")
			if subcommand == "scan" then
				PluribusRosterManager:ScanGuild()
				PluribusUtils:Info("Guild roster scanned", ADDON_NAME)
			elseif subcommand == "stats" then
				local stats = PluribusRosterManager:GetRosterStats()
				PluribusUtils:Info("Guild Statistics:", ADDON_NAME)
				PluribusUtils:Info("  Total Members: " .. stats.totalMembers, ADDON_NAME)
				PluribusUtils:Info("  Online: " .. stats.onlineMembers, ADDON_NAME)
				PluribusUtils:Info("  Average Level: " .. stats.averageLevel, ADDON_NAME)
			elseif subcommand == "online" then
				local online = PluribusRosterManager:GetOnlineMembers()
				PluribusUtils:Info("Online Members (" .. #online .. "):", ADDON_NAME)
				for _, member in ipairs(online) do
					PluribusUtils:Info("  " .. member.name .. " (" .. member.level .. " " .. member.class .. ")", ADDON_NAME)
				end
			elseif subcommand == "class" then
				if args[2] then
					local classMembers = PluribusRosterManager:GetMembersByClass(args[2])
					PluribusUtils:Info("Members of " .. args[2] .. " (" .. #classMembers .. "):", ADDON_NAME)
					for _, member in ipairs(classMembers) do
						PluribusUtils:Info("  " .. member.name .. " (Level " .. member.level .. ")", ADDON_NAME)
					end
				end
			elseif subcommand == "zone" then
				if args[2] then
					local zoneMembers = PluribusRosterManager:FindMembersByZone(args[2])
					PluribusUtils:Info("Members in " .. args[2] .. " (" .. #zoneMembers .. "):", ADDON_NAME)
					for _, member in ipairs(zoneMembers) do
						PluribusUtils:Info("  " .. member.name, ADDON_NAME)
					end
				end
			end
		end
	end, {"members", "guild"})
	
	-- Register keybind
	PluribusCommandRegistry:RegisterKeybind("SHOW_ROSTER", "Show Guild Roster", function()
		local info = PluribusRosterManager:GetGuildInfo()
		PluribusUtils:Info("Guild: " .. info.name .. " (" .. info.totalMembers .. " members)", ADDON_NAME)
	end)
	
	-- Hook into guild events
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
	eventFrame:SetScript("OnEvent", function(self, event)
		if event == "GUILD_ROSTER_UPDATE" then
			PluribusRosterManager:ScanGuild()
		end
	end)
	
	PluribusUtils:Info("Roster Manager addon loaded v" .. ADDON_VERSION, ADDON_NAME)
	PluribusUtils:Info("Use |cff00ccff/roster|r for guild commands", ADDON_NAME)
end

-- Hook into addon loaded and PluribusCore ready events
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == ADDON_NAME then
		addonLoaded = true
		-- If PluribusCore is already loaded, initialize immediately
		if _G.PluribusCore and _G.PluribusUtils and _G.PluribusCommandRegistry then
			InitializeRosterManager()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		-- Initialize when PluribusCore broadcasts it's ready
		InitializeRosterManager()
	end
end)

-- Also subscribe to the messaging event from PluribusCore
if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeRosterManager()
		end
	end)
end


