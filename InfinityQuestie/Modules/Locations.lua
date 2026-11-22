local Locations = { maxResults = 200, maxEntities = 300 }
_G.InfinityQuestLocations = Locations

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function PositiveInteger(value)
	return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end

local function ReadMapping(source)
	if type(source) == "table" then return source end
	if type(source) ~= "string" then return nil end
	local result, opened, closed = {}, false, false
	for line in (source .. "\n"):gmatch("(.-)\n") do
		line = line:gsub("%-%-.*$", ""):match("^%s*(.-)%s*$")
		if line ~= "" then
			if not opened and line == "return {" then
				opened = true
			elseif opened and not closed and line == "}" then
				closed = true
			elseif opened and not closed then
				local area, map = line:match("^%[(%d+)%]%s*=%s*(%d+),?%s*$")
				if not area then return nil end
				result[tonumber(area)] = tonumber(map)
			else
				return nil
			end
		end
	end
	return opened and closed and result or nil
end

function Locations:Prepare()
	local lib = _G.LibQuestieDB
	if type(lib) ~= "table" then return nil, "QuestieDB is not loaded." end
	if self.source == lib then return lib end
	if type(lib.RequireContract) ~= "function" or type(lib.Quest) ~= "table"
		or type(lib.Quest.objectives) ~= "function" or type(lib.Quest.finishedBy) ~= "function"
		or type(lib.Npc) ~= "table" or type(lib.Npc.spawns) ~= "function"
		or type(lib.Object) ~= "table" or type(lib.Object.spawns) ~= "function"
		or type(lib.Item) ~= "table" or type(lib.Item.npcDrops) ~= "function"
		or type(lib.Item.objectDrops) ~= "function" or type(lib.Item.itemDrops) ~= "function"
		or type(lib.Support) ~= "table" or type(lib.Support.Get) ~= "function" then
		return nil, "QuestieDB does not provide the required location API."
	end
	local compatible, reason = lib.RequireContract(2)
	if not compatible then return nil, "QuestieDB contract mismatch: " .. tostring(reason) end
	local addons = _G.C_AddOns
	if not addons or type(addons.GetAddOnMetadata) ~= "function"
		or Public(addons.GetAddOnMetadata("QuestieDB", "X-Flavor")) ~= "Forever" then
		return nil, "Quest locations require the Forever version of QuestieDB."
	end
	local zone = lib.Support.Get("ZoneDB")
	local private = type(zone) == "table" and zone.private
	if type(private) ~= "table" or type(zone.instanceIdToAreaId) ~= "table"
		or type(private.dungeons) ~= "table" then
		return nil, "QuestieDB zone and instance data are unavailable."
	end
	local maps = ReadMapping(private.areaIdToUiMapId)
	local overrides = ReadMapping(private.areaIdToUiMapIdOverride)
	if not maps or not overrides then return nil, "QuestieDB zone mapping is unsupported." end
	local excluded = {}
	for area, dungeon in pairs(private.dungeons) do
		if PositiveInteger(area) then
			excluded[area] = true
			if type(dungeon) == "table" and type(dungeon[2]) == "table" then
				for _, alias in ipairs(dungeon[2]) do excluded[alias] = true end
			end
		end
	end
	for _, area in pairs(zone.instanceIdToAreaId) do
		if PositiveInteger(area) then excluded[area] = true end
	end
	self.source, self.maps, self.overrides, self.excluded = lib, maps, overrides, excluded
	return lib
end

function Locations:Collect(lib, questID)
	local results, seen, entities = {}, {}, {}
	local count, truncated = 0, false
	local function addEntity(kind, id, role)
		if not PositiveInteger(id) then return end
		local key = kind .. ":" .. id .. ":" .. role
		if entities[key] then return end
		entities[key] = true
		count = count + 1
		if count > self.maxEntities then truncated = true; return end
		local reader = lib[kind]
		local name = type(reader.name) == "function" and Public(reader.name(id))
		if type(name) ~= "string" or name == "" then name = kind .. " " .. id end
		local spawns = reader.spawns(id)
		if type(spawns) ~= "table" then return end
		local areas = {}
		for area in pairs(spawns) do
			if PositiveInteger(area) then areas[#areas + 1] = area end
		end
		table.sort(areas)
		for _, area in ipairs(areas) do
			local map = self.maps[area]
			if not self.excluded[area] and self.overrides[area] == nil and PositiveInteger(map)
				and type(spawns[area]) == "table" then
				for _, point in ipairs(spawns[area]) do
					if type(point) == "table" then
						local x, y, phase = Public(point[1]), Public(point[2]), Public(point[3])
						if not PositiveInteger(phase) then phase = nil end
						if type(x) == "number" and type(y) == "number" and x == x and y == y
							and x >= 0 and x <= 100 and y >= 0 and y <= 100 and (x ~= 0 or y ~= 0) then
							local positionKey = key .. ":" .. map .. ":" .. x .. ":" .. y .. ":" .. tostring(phase)
							if not seen[positionKey] then
								seen[positionKey] = true
								if #results >= self.maxResults then truncated = true; return end
								results[#results + 1] = {
									mapID = map, x = x / 100, y = y / 100,
									name = name, role = role, phase = phase,
								}
							end
						end
					end
				end
			end
		end
	end
	local items = {}
	local function addItem(id, depth)
		if not PositiveInteger(id) or items[id] then return end
		items[id] = true
		count = count + 1
		if count > self.maxEntities then truncated = true; return end
		if depth > 3 then truncated = true; return end
		for _, npc in ipairs(lib.Item.npcDrops(id) or {}) do addEntity("Npc", npc, "Objective") end
		for _, object in ipairs(lib.Item.objectDrops(id) or {}) do addEntity("Object", object, "Objective") end
		for _, container in ipairs(lib.Item.itemDrops(id) or {}) do addItem(container, depth + 1) end
	end
	local finish = lib.Quest.finishedBy(questID)
	if type(finish) == "table" then
		for _, id in ipairs(finish[1] or {}) do addEntity("Npc", id, "Turn-in") end
		for _, id in ipairs(finish[2] or {}) do addEntity("Object", id, "Turn-in") end
	end
	local objectives = lib.Quest.objectives(questID)
	if type(objectives) == "table" then
		for _, row in ipairs(objectives[1] or {}) do addEntity("Npc", row[1], "Objective") end
		for _, row in ipairs(objectives[2] or {}) do addEntity("Object", row[1], "Objective") end
		for _, row in ipairs(objectives[3] or {}) do addItem(row[1], 1) end
		for _, row in ipairs(objectives[5] or {}) do
			for _, npc in ipairs(row[1] or {}) do addEntity("Npc", npc, "Objective") end
			addEntity("Npc", row[2], "Objective")
		end
		for _, row in ipairs(objectives[6] or {}) do addItem(row[3], 1) end
	end
	table.sort(results, function(a, b)
		if a.role ~= b.role then return a.role < b.role end
		if a.name ~= b.name then return a.name < b.name end
		if a.mapID ~= b.mapID then return a.mapID < b.mapID end
		if a.x ~= b.x then return a.x < b.x end
		return a.y < b.y
	end)
	return results, truncated
end

function Locations:Lookup(questID)
	questID = Public(questID)
	if not PositiveInteger(questID) then return nil, "Invalid quest ID." end
	local ok, lib, reason = pcall(self.Prepare, self)
	if not ok then return nil, "QuestieDB setup failed: " .. tostring(lib) end
	if not lib then return nil, reason end
	local success, results, truncated = pcall(self.Collect, self, lib, questID)
	if not success then return nil, "QuestieDB location lookup failed: " .. tostring(results) end
	return results, nil, truncated
end

return Locations
