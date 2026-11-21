local ForeverCoreHostChunk = function(...) ---@class SPFNamespace
local ns = select(2, ...)

-- English phrases are the keys, so a phrase with no translation reads as English.
---@type table<string, string>
local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L = L

L["stop guiding"] = "stop guiding"
L["guide this journey"] = "guide this journey"
L["show it on the map"] = "show it on the map"
L["That guide has no step to follow."] = "That guide has no step to follow."

end local _, ForeverCoreHostNs = ... if type(ForeverCoreHostNs) == "table" and type(ForeverCoreHostNs.ForeverCoreHostChunks) == "table" then local chunks = ForeverCoreHostNs.ForeverCoreHostChunks chunks[#chunks + 1] = ForeverCoreHostChunk else return ForeverCoreHostChunk(...) end
