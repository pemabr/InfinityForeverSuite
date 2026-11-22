local initialized = false

local function Initialize()
	if initialized then return end
	if not InfinityCore or not InfinityCommandRegistry or not InfinityUIFramework
		or not InfinityWorldBossCore or not InfinityWorldBossTimers or not InfinityWorldBossUI then
		error("World boss modules unavailable")
	end
	local core, ui = InfinityWorldBossCore, InfinityWorldBossUI
	core:Initialize()
	InfinityWorldBossTimers:Initialize()
	InfinityCommandRegistry:RegisterCommand("worldboss", function(args)
		local cmd = args and args[1]
		if not cmd then
			ui:Toggle()
		elseif cmd == "show" then
			ui:Show()
		elseif cmd == "hide" then
			ui:Hide()
		elseif cmd == "register" then
			local id, interval = tonumber(args[2]), tonumber(args[3])
			local name = args[4] and table.concat(args, " ", 4)
			local ok, problem = core:RegisterBoss(id, name, interval)
			if not ok then
				print("Usage: /worldboss register <encounter ID> <estimated seconds> <name>. " .. problem)
			else
				print("Boss registered. Times are local estimates, not confirmed spawns.")
				ui:Refresh()
			end
		elseif cmd == "kill" then
			local ok, problem = core:RecordBossKill(tonumber(args[2]), time())
			if not ok then print(problem) else print("Local kill recorded; respawn is only an estimate.") end
			ui:Refresh()
		elseif cmd == "interval" then
			local ok, problem = core:SetInterval(tonumber(args[2]), tonumber(args[3]))
			if not ok then print(problem) else print("Estimated interval updated.") end
			ui:Refresh()
		elseif cmd == "forgetkill" then
			if core:ClearKill(tonumber(args[2])) then print("Local kill record cleared.")
			else print("Encounter ID is not registered.") end
			ui:Refresh()
		elseif cmd == "remove" then
			if core:RemoveBoss(tonumber(args[2])) then print("Local boss removed.")
			else print("Encounter ID is not registered.") end
			ui:Refresh()
		elseif cmd == "status" then
			local list = core:GetAllBosses()
			if #list == 0 then print("No bosses registered.") end
			local now = time()
			for _, entry in ipairs(list) do
				print(string.format("%s [%d]: %s", entry.boss.name, entry.id, core:Describe(entry.boss, now)))
			end
		else
			print("Usage: /worldboss [show|hide|register <ID> <estimated seconds> <name>|kill <ID>|interval <ID> <seconds>|forgetkill <ID>|remove <ID>|status]")
		end
	end)
	local events = CreateFrame("Frame")
	events:RegisterEvent("ENCOUNTER_END")
	events:SetScript("OnEvent", function(_, _, id, _, _, _, success)
		if _G.issecretvalue and (_G.issecretvalue(id) or _G.issecretvalue(success)) then return end
		if success == 1 and type(id) == "number" and core.bosses[id] then
			local timestamp = time()
			local ok, problem = core:RecordBossKill(id, timestamp)
			if not ok then InfinityUtils:Warning(problem, "WorldBoss") end
			if ok and _G.InfinityGuildBossReports then
				InfinityGuildBossReports:ObserveKill(id, core.bosses[id].name, timestamp)
			end
			ui:Refresh()
		end
	end)
	InfinityCore:RegisterAddon("InfinityWorldBoss", {
		version = "1.1.0", author = "Infinity Forever",
		description = "Local manually configured world boss estimates", enabled = true,
	})
	initialized = true
	print("InfinityWorldBoss loaded: local estimates only. Use /worldboss.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, name)
	if name == "InfinityWorldBoss" then Initialize() end
end)
