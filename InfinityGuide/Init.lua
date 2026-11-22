-- InfinityGuide Initialization
-- Quest tracking and in-game guide addon

local function InitializeGuide()
	if not _G.InfinityDataManager or not _G.InfinityStorageManager then
		InfinityUtils:Warn("InfinityCore not loaded yet, deferring", "InfinityGuide")
		return
	end
	
	InfinityUtils:Info("InfinityGuide initializing...", "InfinityGuide")
	
	local Quests = InfinityGuideQuests or _G.InfinityGuideQuests
	local Guides = InfinityGuideGuides or _G.InfinityGuideGuides
	local UI = InfinityGuideUI or _G.InfinityGuideUI
	
	if Quests then pcall(function() Quests:Initialize() end) end
	if Guides then
		local ok, err = pcall(function() Guides:Initialize() end)
		if not ok then InfinityUtils:Warning("Guide initialization failed: " .. tostring(err), "Guide") end
	end
	if _G.InfinityGuideSources then InfinityGuideSources:Initialize() end
	if _G.InfinityGuideGuildPresets then InfinityGuideGuildPresets:Initialize() end
	if UI and UI.Initialize then UI:Initialize() end
	
	_G.InfinityGuideQuests = Quests
	_G.InfinityGuideGuides = Guides
	_G.InfinityGuideUI = UI
	
	InfinityDataManager:RegisterSource("InfinityGuide", { quests = {}, guides = {} })
	
	InfinityCommandRegistry:RegisterCommand({
		name = "infguide",
		aliases = {},
		description = "Open quest guide",
		func = function(args, message)
			local input = type(message) == "string" and message or (type(args) == "string" and args or "")
			input = input:match("^%s*(.-)%s*$")
			if input == "" then InfinityGuideUI:Toggle(); return end
			local action, rest = input:match("^(%S+)%s*(.-)$")
			action = action:lower()
			local manager = _G.InfinityGuideGuides
			if action == "help" then
				print("/infguide guides | create <name> | select <id> | step <text> | quest <id> <text> | unstep <number> | delete <id>")
				print("/infguide source allow|disable | import questie <quest ID> | guild send <guide ID>|sendall|sync|published|unpublish <G:id|E:id|S:id|all>|accept|discard")
				print("Quest steps complete on turn-in while their guide is selected. No guide data is bundled.")
			elseif action == "guides" then
				InfinityGuideUI.showGuide = nil
				InfinityGuideUI:ShowGuides()
			elseif action == "source" then
				local sources = _G.InfinityGuideSources
				if sources and rest == "allow" then sources:SetAllowed(true)
				elseif sources and rest == "disable" then sources:SetAllowed(false)
				else print("Usage: /infguide source allow|disable") end
			elseif action == "import" then
				local rawID = rest:match("^questie%s+(%d+)$")
				if not rawID then print("Usage: /infguide import questie <first quest ID>"); return end
				if _G.InfinityGuideSources and InfinityGuideSources:ImportChain(tonumber(rawID)) then
					InfinityGuideUI.showGuide = nil
					InfinityGuideUI:ShowGuides()
				end
			elseif action == "guild" then
				local operation, id = rest:match("^(%S+)%s*(.-)$")
				local network = _G.InfinityGuideGuildPresets
				if not network then InfinityUtils:Warning("Guild guide sharing is unavailable.", "Guide")
				elseif operation == "send" and id ~= "" then network:Send(id)
				elseif operation == "sendall" and id == "" then network:Send(nil, true)
				elseif operation == "sync" and id == "" then network:Request()
				elseif operation == "published" and id == "" then network:Published()
				elseif operation == "unpublish" and id ~= "" then network:Unpublish(id)
				elseif operation == "accept" and id == "" then network:Accept()
				elseif operation == "discard" and id == "" then network:Discard()
				else print("Usage: /infguide guild send <guide ID>|sendall|sync|published|unpublish <G:id|E:id|S:id|all>|accept|discard") end
			elseif action == "create" then
				local guide = manager:CreateGuide(rest)
				if guide then
					print("Created guide " .. guide.id .. ": " .. guide.name)
					InfinityGuideUI.showGuide = guide.id
					InfinityGuideUI:ShowGuides()
				end
			elseif action == "select" then
				if rest == "none" then
					if manager:ClearSelection() then
						print("No guide selected.")
						InfinityGuideUI:RefreshGuides()
					end
				elseif manager:ViewGuide(rest) then
					InfinityGuideUI.showGuide = rest
					InfinityGuideUI:ShowGuides()
				end
			elseif action == "step" or action == "quest" then
				local id = manager.activeGuide
				local guide = id and manager.guides[id]
				local number = guide and type(guide.steps) == "table" and #guide.steps + 1 or 1
				local questID
				if action == "quest" then
					local rawID, text = rest:match("^(%d+)%s+(.+)$")
					if not rawID then print("Usage: /infguide quest <quest ID> <text>"); return end
					questID, rest = tonumber(rawID), text
				end
				if manager:AddGuideStep(id, number, rest, questID) then
					InfinityGuideUI.showGuide = id
					InfinityGuideUI:ShowGuides()
				end
			elseif action == "delete" then
				if manager:DeleteGuide(rest) then
					print("Deleted guide " .. rest)
					if InfinityGuideUI.showGuide == rest then InfinityGuideUI.showGuide = nil end
					InfinityGuideUI:RefreshGuides()
				end
			elseif action == "unstep" then
				local number = rest:match("^%d+$") and tonumber(rest)
				if not number then print("Usage: /infguide unstep <step number>"); return end
				if manager:RemoveGuideStep(manager.activeGuide, number) then
					InfinityGuideUI.showGuide = manager.activeGuide
					InfinityGuideUI:RefreshGuides()
				end
			else
				print("Unknown guide command. Use /infguide help.")
			end
		end,
	})
	
	InfinityCommandRegistry:RegisterKeybind({
		name = "INFINITY_GUIDE_TOGGLE",
		description = "Toggle Guide",
		defaultKey = "ALT-Q",
		action = function() InfinityGuideUI:Toggle() end,
	})
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityGuide", "1.0.0", {
			description = "In-game guides",
			author = "Infinity Suite Team",
			category = "Guide",
			enabled = true,
			settings = {}
		})
	end
	
	InfinityUtils:Info("InfinityGuide initialized successfully", "InfinityGuide")
	InfinityMessaging:Publish("guide_addon_loaded", { addon = "InfinityGuide" })
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityCore" then
		InitializeGuide()
		self:UnregisterEvent("ADDON_LOADED")
	elseif addonName == "InfinityGuide" then
		if _G.InfinityDataManager then
			InitializeGuide()
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end)




