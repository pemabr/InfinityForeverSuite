local initialized, addonLoaded, waiting = false, false, false

local function InitializeInfinityHealer()
	if initialized then return true end
	if not InfinityCore or not InfinityCommandRegistry or not InfinityUIFramework
		or not InfinityHealer or not InfinityClickCast or not InfinityHealerUI or not InfinityGroupStatus then
		error("InfinityHealer required modules unavailable")
	end
	if not InfinityHealer:Initialize() then
		if not waiting then
			InfinityUtils:Warning("Waiting for player identity before loading healer frames.", "Healer")
			waiting = true
		end
		return false
	end
	InfinityGroupStatus:Initialize(InfinityHealer.settings)
	InfinityHealerUI:Initialize()
	InfinityCommandRegistry:RegisterCommand("healer", function(args)
		if not args or #args == 0 then
			InfinityHealerUI:Toggle()
		elseif args[1] == "frames" then
			InfinityHealer:ToggleFrames()
			InfinityHealerUI:Refresh()
		elseif args[1] == "scale" then
			InfinityHealer:SetFrameScale(tonumber(args[2]))
			InfinityHealerUI:Refresh()
		elseif args[1] == "group" then
			if not args[2] then InfinityGroupStatus:Toggle()
			elseif args[2] == "on" and not args[3] then
				if InfinityGroupStatus:SetEnabled(true) then print("Group status sharing enabled.") end
				InfinityHealerUI:Refresh()
			elseif args[2] == "off" and not args[3] then
				InfinityGroupStatus:SetEnabled(false)
				print("Group status sharing disabled.")
				InfinityHealerUI:Refresh()
			elseif args[2] == "sync" and not args[3] then InfinityGroupStatus:RequestSync()
			else print("Usage: /healer group [on|off|sync]") end
		elseif args[1] == "watch" or args[1] == "unwatch" then
			if not args[2] or args[3] then print("Usage: /healer watch|unwatch <spell ID>")
			elseif InfinityGroupStatus:Watch(tonumber(args[2]), args[1] == "watch") then
				print((args[1] == "watch" and "Watching" or "Unwatched") .. " spell " .. args[2])
			end
		elseif args[1] == "bind" then
			local button = args[2] and args[2]:lower()
			local raw = args[3]
			if not button or not raw or args[4] then
				print("Usage: /healer bind <right|shift-right|ctrl-right|alt-right> <spell ID|clear>")
			elseif raw:lower() == "clear" then
				InfinityClickCast:SetBinding(button, nil)
			else
				local spellID = tonumber(raw)
				if not spellID then
					print("Usage: /healer bind <right|shift-right|ctrl-right|alt-right> <spell ID|clear>")
				else
					InfinityClickCast:SetBinding(button, spellID)
				end
			end
			InfinityHealerUI:Refresh()
		else
			print("Usage: /healer [frames|scale <0.5-2>|bind <button> <spell ID|clear>|group|watch|unwatch]")
		end
	end, { "heal" })
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityHealer", "1.4.0", {
			description = "Secure group frames and click bindings",
			author = "Infinity Suite Team",
			category = "Combat",
			enabled = true,
			settings = {},
		})
	end
	initialized = true
	InfinityMessaging:Publish(INFINITY_EVENTS.FEATURE_ENABLED, "healer", true)
	return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, addonName)
	if event == "ADDON_LOADED" and addonName == "InfinityHealer" then addonLoaded = true end
	if addonLoaded and InitializeInfinityHealer() then
		self:UnregisterEvent("ADDON_LOADED")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
end)
