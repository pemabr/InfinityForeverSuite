local ForeverCoreHostChunk = function(...) ---@type string, TFNamespace
local _, ns = ...

if ns.broken then
	return
end

ns.Feature({
	key = "reloadCommand",
	category = "Interface",
	section = "Small things",
	name = "Type /rl to reload the UI",
	tooltip = "A shorter /reload. Switching this on or off takes effect after the next reload.",
	default = true,
	conflicts = { { addon = "Leatrix_Plus" } },
})

-- Slash commands cannot be unregistered, so the setting is read once.
ns.Init(function()
	if ns.Active("reloadCommand") then
		SLASH_TWEAKSFOREVER_RELOAD1 = "/rl"
		SlashCmdList.TWEAKSFOREVER_RELOAD = function()
			C_UI.Reload()
		end
	end
end)

end local _, ForeverCoreHostNs = ... if type(ForeverCoreHostNs) == "table" and type(ForeverCoreHostNs.ForeverCoreHostChunks) == "table" then local chunks = ForeverCoreHostNs.ForeverCoreHostChunks chunks[#chunks + 1] = ForeverCoreHostChunk else return ForeverCoreHostChunk(...) end
