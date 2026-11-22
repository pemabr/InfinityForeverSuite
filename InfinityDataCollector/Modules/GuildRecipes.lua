local Knowledge = _G.InfinityGuildKnowledge
local Recipes = {
	prefix = "InfinityRec1",
	storageKey = "guildRecipes",
	sequence = 0,
	queue = {},
	maxRecords = 10000,
}
for key, value in pairs(Knowledge) do
	if type(value) == "function" then Recipes[key] = value end
end
_G.InfinityGuildRecipes = Recipes

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum)
	value = Public(value)
	return type(value) == "number" and value == value and value > 0
		and value <= maximum and value == math.floor(value)
end

local function Field(value)
	value = Public(value)
	return type(value) == "string" and #value <= 75 and value:match("%S")
		and not value:find("[%z\1-\31~|]")
end

local function FullName(value)
	value = Public(value)
	if type(value) ~= "string" or value == "" then return nil end
	local name, realm = value:match("^([^%-]+)%-(.+)$")
	if not name then
		name = value
		realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
		if not realm and _G.GetRealmName then realm = Public(GetRealmName()) end
	end
	if type(realm) ~= "string" or realm == "" then return nil end
	return name:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

function Recipes:Valid(record)
	record = Public(record)
	return type(record) == "table" and Public(record.kind) == "T"
		and Field(record.owner) and FullName(record.owner) ~= nil
		and Integer(record.id, 1000000000) and Integer(record.profession, 1000000000)
		and Integer(record.observed, 100000000000) and Field(record.name)
end

function Recipes:Key(record)
	return "T:" .. FullName(record.owner) .. ":" .. record.profession .. ":" .. record.id
end

function Recipes:Payload(prefix, record)
	return table.concat({ prefix, record.id, record.profession, record.observed, record.owner, record.name }, "~")
end

function Recipes:Parse(kind, body)
	if kind ~= "T" then return nil end
	local id, profession, observed, owner, name = body:match("^(%d+)~(%d+)~(%d+)~([^~]+)~([^~]+)$")
	local record = { kind = kind, id = tonumber(id), profession = tonumber(profession),
		observed = tonumber(observed), owner = owner, name = name }
	if self:Valid(record) then return record end
end

function Recipes:Copy(record, revision)
	return { kind = "T", id = record.id, profession = record.profession, observed = record.observed,
		owner = record.owner, name = record.name, revision = revision }
end

function Recipes:Merge(previous, record)
	if record.observed > previous.observed then return record end
end

function Recipes:Apply()
	if self.window and self.window:IsShown() then self:ScheduleRefresh() end
end

function Recipes:ScheduleRefresh()
	if self.refreshPending then return end
	self.refreshPending = true
	C_Timer.After(0.5, function()
		self.refreshPending = false
		if self.window and self.window:IsShown() then self:Refresh() end
	end)
end

function Recipes:Initialize()
	if self.initialized then return end
	Knowledge.Initialize(self)
	if not self.available then return end
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("TRADE_SKILL_SHOW")
	frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
	frame:SetScript("OnEvent", function()
		if not self.db.enabled or self.scanPending then return end
		local pending = {}
		self.scanPending = pending
		C_Timer.After(1, function()
			if self.scanPending ~= pending then return end
			self.scanPending = nil
			if self.db.enabled then self:ScanOpen(false) end
		end)
	end)
	self.professionEvents = frame
end

function Recipes:PublishCurrent()
	self:ScanOpen(true)
end

function Recipes:SetEnabled(enabled)
	local result = Knowledge.SetEnabled(self, enabled)
	if not enabled then self.scanPending = nil end
	if self.window and self.window:IsShown() then self:Refresh() end
	return result
end

function Recipes:WarnIncomplete()
	if self.warnedRecipe then return end
	self.warnedRecipe = true
	InfinityUtils:Warning("Some recipe details are unavailable and were not shared.", "Knowledge")
end

function Recipes:ScanOpen(notify)
	if not self.available or not self.db.enabled then return false end
	local api = _G.C_TradeSkillUI
	if not api or not api.GetBaseProfessionInfo or not api.GetAllRecipeIDs or not api.GetRecipeInfo
		or not api.IsTradeSkillLinked or not api.IsTradeSkillGuild then
		if not self.warnedAPI then
			self.warnedAPI = true
			InfinityUtils:Warning("Profession inspection API unavailable; recipes were not shared.", "Knowledge")
		end
		return false
	end
	self.warnedAPI = nil
	local linked, guild = api.IsTradeSkillLinked(), api.IsTradeSkillGuild()
	if (_G.issecretvalue and (issecretvalue(linked) or issecretvalue(guild))) or linked or guild then
		if notify then InfinityUtils:Warning("Open your own profession to share recipes.", "Knowledge") end
		return false
	end
	local info = Public(api.GetBaseProfessionInfo())
	local profession = type(info) == "table" and Public(info.professionID)
	local ids = Public(api.GetAllRecipeIDs())
	if not Integer(profession, 1000000000) or type(ids) ~= "table" or #ids == 0 or #ids > 10000 then
		if notify then InfinityUtils:Warning("Open your own profession to share recipes.", "Knowledge") end
		return false
	end
	local owner = _G.UnitName and Public(UnitName("player"))
	local realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
	if (type(realm) ~= "string" or realm == "") and _G.GetRealmName then realm = Public(GetRealmName()) end
	if type(owner) ~= "string" or type(realm) ~= "string" or realm == "" then
		InfinityUtils:Warning("Character identity unavailable; recipes were not shared.", "Knowledge")
		return false
	end
	if not owner:find("-", 1, true) then owner = owner .. "-" .. realm:gsub("%s+", "") end
	local observed = Public(time())
	if not Integer(observed, 100000000000) then
		InfinityUtils:Warning("Clock unavailable; recipes were not shared.", "Knowledge")
		return false
	end
	local state = self:State()
	if not state then return false end
	for _, raw in ipairs(ids) do
		local id = Public(raw)
		if Integer(id, 1000000000) then
			local recipe = Public(api.GetRecipeInfo(id))
			if type(recipe) == "table" then
				local learned, name = Public(recipe.learned), Public(recipe.name)
				if learned == true then
					local record = { kind = "T", id = id, profession = profession,
						observed = observed, owner = owner, name = name }
					if self:Valid(record) then
						local previous = state.records[self:Key(record)]
						if not previous or previous.name ~= name or observed - previous.observed >= 3600 then
							self:Add(record, true)
						end
					else self:WarnIncomplete() end
				elseif type(learned) ~= "boolean" then
					self:WarnIncomplete()
				end
			else self:WarnIncomplete() end
		else self:WarnIncomplete() end
	end
	return true
end

function Recipes:Search(query)
	query = Public(query)
	if type(query) ~= "string" then return nil, "Enter a recipe ID or name." end
	query = query:match("^%s*(.-)%s*$")
	if query == "" or #query > 75 then return nil, "Enter a recipe ID or name." end
	local state = self:State()
	if not state then return nil, "Enable guild recipes while in a guild." end
	local members = self:GetRoster()
	if not members or not next(members) then return nil, "Guild roster unavailable; try again after it loads." end
	local id, text = tonumber(query), query:lower()
	local found = {}
	for _, record in pairs(state.records) do
		if self:Valid(record) and members[FullName(record.owner)]
			and ((id and record.id == id) or (not id and record.name:lower():find(text, 1, true))) then
			found[#found + 1] = record
		end
	end
	table.sort(found, function(a, b)
		if a.name ~= b.name then return a.name < b.name end
		if a.owner ~= b.owner then return a.owner < b.owner end
		return a.id < b.id
	end)
	return found
end

function Recipes:Refresh()
	if not self.window then return end
	local records, problem = self:Search(self.input:GetText())
	local rows = {}
	if records then
		for index = 1, math.min(#records, 200) do
			local record = records[index]
			local ok, observed = false, nil
			if _G.date then ok, observed = pcall(date, "%Y-%m-%d", record.observed) end
			if not ok or type(observed) ~= "string" then observed = "timestamp " .. record.observed end
			rows[#rows + 1] = { text = record.name .. " (#" .. record.id .. ") - " .. record.owner
				.. " | last observed: " .. observed }
		end
		if #rows == 0 then rows[1] = { text = "No matching reports." } end
	end
	local status = "Reports may be outdated; confirm with the crafter."
	if records and #records > 200 then
		status = "First 200 of " .. #records .. "; refine search. Reports may be outdated."
	end
	self.window.status:SetText(problem or status)
	self.window:SetItems(rows)
end

function Recipes:EnsureWindow()
	if not _G.InfinityUIFramework then
		InfinityUtils:Warning("Recipe directory UI unavailable.", "Knowledge")
		return false
	end
	if not self.window then
		local window = InfinityUIFramework:CreateListWindow("InfinityGuildRecipesWindow", "Guild Recipe Reports", 650, 500)
		self.input = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
		self.input:SetSize(260, 20)
		self.input:SetPoint("TOPLEFT", window, "TOPLEFT", 20, -40)
		self.input:SetAutoFocus(false)
		self.input:SetMaxLetters(75)
		local search = InfinityUIFramework:CreateButton(window, "Search", 90, 22, function() self:Refresh() end)
		search:SetPoint("LEFT", self.input, "RIGHT", 12, 0)
		self.input:SetScript("OnEnterPressed", function(input) input:ClearFocus(); self:Refresh() end)
		self.window = window
	end
	return true
end

function Recipes:Toggle()
	if not self:EnsureWindow() then return end
	if self.window:IsShown() then self.window:Hide()
	else self:Refresh(); self.window:Show() end
end

function Recipes:OpenForProfession()
	if not self:EnsureWindow() then return end
	local recipeID, problem = InfinityUIFramework:GetSelectedProfessionRecipeID()
	if problem then InfinityUtils:Warning(problem, "Knowledge") end
	if recipeID then self.input:SetText(tostring(recipeID)) end
	self:Refresh()
	self.window:Show()
end

return Recipes
