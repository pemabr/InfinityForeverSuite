-- InfinityGuideGuides Module
-- Manages in-game guides and tutorials

InfinityGuideGuides = {}
InfinityGuideGuides.guides = {}
InfinityGuideGuides.tutorials = {}

function InfinityGuideGuides:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityGuide", "guides", {})
	self.guides = storageData.guides or {}
	self.tutorials = storageData.tutorials or {}
	InfinityUtils:Info("GuideGuides module initialized", "InfinityGuide")
end

function InfinityGuideGuides:CreateGuide(guideName, guideType, content)
	local guideId = "guide_" .. InfinityUtils:GetTimeStamp()
	
	local guide = {
		id = guideId,
		name = guideName,
		type = guideType or "general",
		content = content or "",
		created = InfinityUtils:GetTimeStamp(),
		views = 0,
		rating = 0,
		steps = {},
	}
	
	self.guides[guideId] = guide
	self:SaveGuides()
	
	return guide
end

function InfinityGuideGuides:AddGuideStep(guideId, stepNumber, description)
	if not self.guides[guideId] then return nil end
	
	local step = {
		number = stepNumber,
		description = description,
		images = {},
	}
	
	self.guides[guideId].steps[stepNumber] = step
	self:SaveGuides()
	
	return step
end

function InfinityGuideGuides:GetGuidesByType(guideType)
	local result = {}
	for guideId, guide in pairs(self.guides) do
		if guide.type == guideType then
			table.insert(result, guide)
		end
	end
	return result
end

function InfinityGuideGuides:ViewGuide(guideId)
	if not self.guides[guideId] then return nil end
	self.guides[guideId].views = (self.guides[guideId].views or 0) + 1
	return self.guides[guideId]
end

function InfinityGuideGuides:SaveGuides()
	InfinityStorageManager:SetFeatureSetting("InfinityGuide", "guides", {
		guides = self.guides,
		tutorials = self.tutorials,
	})
	InfinityDataManager:UpdateSourceData("InfinityGuide", "guides", {
		guides = self.guides,
		tutorials = self.tutorials,
	})
end

return InfinityGuideGuides
