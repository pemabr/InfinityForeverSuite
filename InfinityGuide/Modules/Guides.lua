InfinityGuideGuides = {}
InfinityGuideGuides.guides = {}
InfinityGuideGuides.tutorials = {}

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function ValidText(value, limit)
	value = Public(value)
	return type(value) == "string" and value:match("%S") and #value <= limit
		and not value:find("[%z\1-\31]")
end

function InfinityGuideGuides:Initialize()
	self.initialized = false
	local data = InfinityStorageManager:GetFeatureSetting("InfinityGuide", "guides", {})
	if type(data) ~= "table" or (data.guides ~= nil and type(data.guides) ~= "table")
		or (data.tutorials ~= nil and type(data.tutorials) ~= "table") then
		InfinityUtils:Warning("Invalid saved guide data; guides were not loaded.", "Guide")
		return false
	end
	self.guides = data.guides or {}
	self.tutorials = data.tutorials or {}
	self.activeGuide = type(data.activeGuide) == "string" and data.activeGuide or nil
	self.nextId = type(data.nextId) == "number" and data.nextId > 0 and data.nextId < 1000000000
		and data.nextId == math.floor(data.nextId) and data.nextId or 1
	self.initialized = true
	return true
end

function InfinityGuideGuides:SaveGuides()
	local data = { guides = self.guides, tutorials = self.tutorials, activeGuide = self.activeGuide, nextId = self.nextId }
	InfinityStorageManager:SetFeatureSetting("InfinityGuide", "guides", data)
	InfinityDataManager:UpdateSourceData("InfinityGuide", "guides", data)
end

function InfinityGuideGuides:CreateFromSteps(name, guideType, steps)
	if not self.initialized then InfinityUtils:Warning("Guides are unavailable.", "Guide"); return nil end
	steps = Public(steps)
	if not ValidText(name, 80) or not ValidText(guideType, 40) or type(steps) ~= "table" or #steps > 200 then
		InfinityUtils:Warning("Invalid guide preset.", "Guide")
		return nil
	end
	local copied = {}
	for index, step in ipairs(steps) do
		step = Public(step)
		local questID = type(step) == "table" and Public(step.questID)
		if type(step) ~= "table" or (_G.issecretvalue and issecretvalue(step.questID))
			or not ValidText(step.description, 60)
			or (questID ~= nil and (type(questID) ~= "number" or questID <= 0 or questID > 1000000000
				or questID ~= math.floor(questID))) then
			InfinityUtils:Warning("Invalid guide preset step.", "Guide")
			return nil
		end
		copied[index] = { number = index, description = Public(step.description), questID = questID, images = {}, done = false }
	end
	local count = 0
	for _ in pairs(self.guides) do count = count + 1 end
	if count >= 100 then InfinityUtils:Warning("Guide limit reached.", "Guide"); return nil end
	local id = self.nextId
	while self.guides["guide_" .. id] do id = id + 1 end
	local guide = { id = "guide_" .. id, name = name, type = guideType, content = "",
		created = InfinityUtils:GetTimeStamp(), views = 0, rating = 0, steps = copied }
	self.guides[guide.id] = guide
	self.nextId = id + 1
	self:SaveGuides()
	return guide
end

function InfinityGuideGuides:CreateGuide(name, guideType, content)
	if content ~= nil and (type(content) ~= "string" or #content > 2000) then
		InfinityUtils:Warning("Invalid guide content.", "Guide")
		return nil
	end
	local guide = self:CreateFromSteps(name, guideType or "general", {})
	if guide then
		guide.content = content or ""
		self.activeGuide = guide.id
		self:SaveGuides()
	end
	return guide
end
function InfinityGuideGuides:RemoveGuideStep(guideId, number)
	local guide = self.guides[guideId]
	if type(guide) ~= "table" or type(guide.steps) ~= "table" or type(number) ~= "number"
		or number ~= math.floor(number) or number < 1 or number > #guide.steps then
		InfinityUtils:Warning("Guide step not found.", "Guide")
		return false
	end
	table.remove(guide.steps, number)
	for index = number, #guide.steps do guide.steps[index].number = index end
	self:SaveGuides()
	return true
end

function InfinityGuideGuides:AddGuideStep(guideId, stepNumber, description, questID)
	local guide = self.guides[guideId]
	if type(guide) ~= "table" or type(guide.steps) ~= "table" or type(stepNumber) ~= "number"
		or stepNumber ~= #guide.steps + 1 or stepNumber > 200 or not ValidText(description, 60)
		or (questID ~= nil and (type(questID) ~= "number" or questID <= 0 or questID > 1000000000
			or questID ~= math.floor(questID))) then
		InfinityUtils:Warning("Invalid guide step or no active guide.", "Guide")
		return nil
	end
	local step = { number = stepNumber, description = description, images = {}, done = false, questID = questID }
	guide.steps[stepNumber] = step
	self:SaveGuides()
	return step
end

function InfinityGuideGuides:OnQuestTurnedIn(questID)
	if _G.issecretvalue and _G.issecretvalue(questID) then return end
	if type(questID) ~= "number" then return end
	local guide = self.activeGuide and self.guides[self.activeGuide]
	if type(guide) ~= "table" or type(guide.steps) ~= "table" then return end
	for _, step in ipairs(guide.steps) do
		if type(step) == "table" and step.questID == questID and not step.done then
			step.done = true
			self:SaveGuides()
			return
		end
	end
end

function InfinityGuideGuides:SetStepDone(guideId, number, done)
	local guide = self.guides[guideId]
	local step = type(guide) == "table" and type(guide.steps) == "table" and guide.steps[number]
	if type(step) ~= "table" then
		InfinityUtils:Warning("Guide step not found.", "Guide")
		return false
	end
	step.done = not not done
	self:SaveGuides()
	return true
end

function InfinityGuideGuides:GetGuidesByType(guideType)
	local result = {}
	for _, guide in pairs(self.guides) do
		if type(guide) == "table" and guide.type == guideType then result[#result + 1] = guide end
	end
	return result
end

function InfinityGuideGuides:ViewGuide(guideId)
	local guide = self.guides[guideId]
	if type(guide) ~= "table" or type(guide.steps) ~= "table" then
		InfinityUtils:Warning("Guide not found.", "Guide")
		return nil
	end
	self.activeGuide = guideId
	guide.views = (type(guide.views) == "number" and guide.views or 0) + 1
	self:SaveGuides()
	return guide
end

function InfinityGuideGuides:ClearSelection()
	if not self.initialized then InfinityUtils:Warning("Guides are unavailable.", "Guide"); return false end
	self.activeGuide = nil
	self:SaveGuides()
	return true
end

function InfinityGuideGuides:DeleteGuide(guideId)
	if not self.guides[guideId] then InfinityUtils:Warning("Guide not found.", "Guide"); return false end
	self.guides[guideId] = nil
	if self.activeGuide == guideId then self.activeGuide = nil end
	self:SaveGuides()
	return true
end

return InfinityGuideGuides
