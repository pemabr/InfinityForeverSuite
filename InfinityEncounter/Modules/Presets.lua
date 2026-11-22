local Presets = {}
_G.InfinityEncounterPresets = Presets

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Text(value, limit)
	value = Public(value)
	return type(value) == "string" and #value <= limit and value:match("%S")
		and not value:find("[%z\1-\31|]")
end

local function SpellID(value)
	value = Public(value)
	return type(value) == "number" and value > 0 and value <= 1000000000
		and value == math.floor(value)
end

local function Valid(name, steps)
	steps = Public(steps)
	if not Text(name, 80) or type(steps) ~= "table" or #steps == 0 or #steps > 200 then return false end
	local seen = {}
	for index = 1, #steps do
		local step = Public(steps[index])
		if type(step) ~= "table" then return false end
		local id = Public(step.questID)
		if not SpellID(id) or seen[id] or not Text(step.description, 60) then return false end
		seen[id] = true
	end
	return true
end

function Presets:Initialize(db)
	if self.initialized then return true end
	db = Public(db)
	if type(db) ~= "table" or (_G.issecretvalue and issecretvalue(db.watchPresets))
		or (db.watchPresets ~= nil and type(db.watchPresets) ~= "table") then
		InfinityUtils:Warning("Invalid boss preset settings.", "Encounter")
		return false
	end
	if db.watchPresets == nil then db.watchPresets = {} end
	self.presets = db.watchPresets
	self.initialized = true
	self:Connect()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:SetScript("OnEvent", function(_, _, name)
		if name == "InfinityGuide" then self:Connect() end
	end)
	self.frame = frame
	return true
end

function Presets:Connect()
	local network = _G.InfinityGuideGuildPresets
	if network and type(network.RegisterType) == "function" then
		return network:RegisterType("E", function(name, steps) return self:Save(name, steps) end,
			function() return self:GetAll() end)
	end
	return false
end

function Presets:GetAll()
	if not self.presets then InfinityUtils:Warning("Boss presets are unavailable.", "Encounter"); return nil end
	local ids, result = {}, {}
	for id, preset in pairs(self.presets) do
		id, preset = Public(id), Public(preset)
		if type(id) ~= "string" or type(preset) ~= "table" or not Valid(preset.name, preset.steps) then
			InfinityUtils:Warning("Invalid boss preset; nothing shared.", "Encounter")
			return nil
		end
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do result[#result + 1] = { id = id, preset = self.presets[id] } end
	return result
end

function Presets:Save(name, steps)
	if not self.presets or not Valid(name, steps) then
		InfinityUtils:Warning("Invalid boss preset. Use 1-200 unique spell IDs and labels of at most 60 bytes without |.", "Encounter")
		return false
	end
	local count = 0
	for _ in pairs(self.presets) do count = count + 1 end
	if count >= 100 then InfinityUtils:Warning("Boss preset limit reached.", "Encounter"); return false end
	local number = 1
	while self.presets["preset_" .. number] do number = number + 1 end
	local id = "preset_" .. number
	local copy = {}
	for index, step in ipairs(steps) do
		copy[index] = { questID = step.questID, description = step.description }
	end
	self.presets[id] = { name = name, steps = copy }
	print("Saved boss preset " .. id .. ": " .. name .. ". Use /encounter preset use " .. id .. " to activate.")
	return id
end

function Presets:Create(name)
	local watches = InfinityEncounterAbilities.watchedSpells
	if not watches then InfinityUtils:Warning("Encounter watch settings are unavailable.", "Encounter"); return false end
	local steps = {}
	for id, label in pairs(watches) do steps[#steps + 1] = { questID = id, description = label } end
	if not Valid(name, steps) then
		InfinityUtils:Warning("Cannot save current watches as a preset: check name, spell IDs and labels.", "Encounter")
		return false
	end
	table.sort(steps, function(a, b) return a.questID < b.questID end)
	return self:Save(name, steps)
end

function Presets:Use(id)
	local watches = InfinityEncounterAbilities.watchedSpells
	if not self.presets or not watches then InfinityUtils:Warning("Boss presets are unavailable.", "Encounter"); return false end
	local preset = id ~= "none" and Public(self.presets[id]) or nil
	if id ~= "none" and (type(preset) ~= "table" or not Valid(preset.name, preset.steps)) then
		InfinityUtils:Warning("Boss preset not found or invalid.", "Encounter")
		return false
	end
	for key in pairs(watches) do watches[key] = nil end
	if preset then
		for _, step in ipairs(preset.steps) do watches[step.questID] = step.description end
	end
	InfinityEncounterAbilities.activeWatchedCasts = {}
	print(preset and ("Boss preset applied: " .. preset.name) or "All boss watches disabled.")
	return true
end

function Presets:Delete(id)
	if not self.presets or not self.presets[id] then InfinityUtils:Warning("Boss preset not found.", "Encounter"); return false end
	self.presets[id] = nil
	print("Deleted boss preset " .. id .. ". Active watches were not changed.")
	return true
end

function Presets:Send(id)
	local preset = self.presets and Public(self.presets[id])
	local network = _G.InfinityGuideGuildPresets
	if not network or not network.available or not self:Connect() then
		InfinityUtils:Warning("Guild preset sharing requires InfinityGuide.", "Encounter")
		return false
	end
	if type(preset) ~= "table" or not Valid(preset.name, preset.steps) then
		InfinityUtils:Warning("Boss preset not found or invalid.", "Encounter")
		return false
	end
	return network:Send(id, false, preset, "E")
end

function Presets:List()
	if not self.presets then InfinityUtils:Warning("Boss presets are unavailable.", "Encounter"); return end
	print("Boss presets (using one replaces current watches):")
	local ids = {}
	local invalid = false
	for id, preset in pairs(self.presets) do
		id, preset = Public(id), Public(preset)
		if type(id) == "string" and type(preset) == "table" and Text(preset.name, 80) then ids[#ids + 1] = id
		else invalid = true end
	end
	if invalid then InfinityUtils:Warning("Some saved boss presets are invalid.", "Encounter") end
	table.sort(ids)
	for _, id in ipairs(ids) do print(id .. " - " .. self.presets[id].name) end
	if #ids == 0 then print("No boss presets.") end
end

return Presets
