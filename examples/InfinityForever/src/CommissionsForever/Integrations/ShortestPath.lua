local ForeverCoreHostChunk = function(...) local _, ns = ...

if ns.broken then
	return
end

local ShortestPath = {}
ns.ShortestPath = ShortestPath

---@return table?
local function API()
	local api = ShortestPathForever and ShortestPathForever.API
	return type(api) == "table" and type(api.NavigateRoute) == "function" and api or nil
end

-- Whether a Shortest Path Forever that can take a route is loaded.
---@return boolean
function ShortestPath.Installed()
	return API() ~= nil
end

---@param owner string
---@param stops table[]
---@return boolean
function ShortestPath.Navigate(owner, stops)
	local api = API()
	if not api then
		return false
	end
	local ok, started = pcall(api.NavigateRoute, owner, stops)
	return ok and started == true
end

return ShortestPath

end local _, ForeverCoreHostNs = ... if type(ForeverCoreHostNs) == "table" and type(ForeverCoreHostNs.ForeverCoreHostChunks) == "table" then local chunks = ForeverCoreHostNs.ForeverCoreHostChunks chunks[#chunks + 1] = ForeverCoreHostChunk else return ForeverCoreHostChunk(...) end
