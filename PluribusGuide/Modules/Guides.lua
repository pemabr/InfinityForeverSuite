-- PluribusGuideGuides Module
-- Manages in-game guides and tutorials

PluribusGuideGuides = {}
PluribusGuideGuides.guides = {}
PluribusGuideGuides.tutorials = {}

function PluribusGuideGuides:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusGuide", "guides", {})
	self.guides = storageData.guides or {}
	self.tutorials = storageData.tutorials or {}
	PluribusUtils:Info("GuideGuides module initialized", "PluribusGuide")
end

function PluribusGuideGuides:CreateGuide(guideName, guideType, content)
	local guideId = "guide_" .. PluribusUtils:GetTimeStamp()
	
	local guide = {
		id = guideId,
		name = guideName,
		type = guideType or "general",
		content = content or "",
		created = PluribusUtils:GetTimeStamp(),
		views = 0,
		rating = 0,
		steps = {},
	}
	
	self.guides[guideId] = guide
	self:SaveGuides()
	
	return guide
end

function PluribusGuideGuides:AddGuideStep(guideId, stepNumber, description)
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

function PluribusGuideGuides:GetGuidesByType(guideType)
	local result = {}
	for guideId, guide in pairs(self.guides) do
		if guide.type == guideType then
			table.insert(result, guide)
		end
	end
	return result
end

function PluribusGuideGuides:ViewGuide(guideId)
	if not self.guides[guideId] then return nil end
	self.guides[guideId].views = (self.guides[guideId].views or 0) + 1
	return self.guides[guideId]
end

function PluribusGuideGuides:SaveGuides()
	PluribusStorageManager:SetFeatureSetting("PluribusGuide", "guides", {
		guides = self.guides,
		tutorials = self.tutorials,
	})
	PluribusDataManager:UpdateSourceData("PluribusGuide", "guides", {
		guides = self.guides,
		tutorials = self.tutorials,
	})
end

return PluribusGuideGuides
