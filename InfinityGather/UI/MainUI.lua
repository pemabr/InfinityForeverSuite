-- InfinityGather UI Module
-- Full Gathering Skill Progress, Node Type Filters, and Route Launcher for WoW Forever

InfinityGatherUI = {
	filters = { herbs = true, ore = true, treasure = true, fishing = true },
}
_G.InfinityGatherUI = InfinityGatherUI

local function scanGatheringSkills()
	local found = {}
	local targets = { herbalism = true, mining = true, skinning = true, fishing = true }
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
			if name and not isHeader and targets[name:lower()] then
				table.insert(found, { name = name, rank = rank or 0, maxRank = maxRank or 300 })
			end
		end
	end
	if #found == 0 then
		found = {
			{ name = "Herbalism", rank = 0, maxRank = 300 },
			{ name = "Mining", rank = 0, maxRank = 300 },
			{ name = "Skinning", rank = 0, maxRank = 300 },
		}
	end
	return found
end

function InfinityGatherUI:Toggle()
	if not _G.InfinityGatherWindow then
		_G.InfinityGatherWindow = self:Create()
		_G.InfinityGatherWindow:Show()
		return
	end
	if _G.InfinityGatherWindow:IsVisible() then
		_G.InfinityGatherWindow:Hide()
	else
		self:Refresh(_G.InfinityGatherWindow)
		_G.InfinityGatherWindow:Show()
	end
end

function InfinityGatherUI:Create()
	local frame = InfinityUIFramework:CreateFrame(
		"InfinityGatherWindow",
		UIParent,
		600,
		440,
		"Infinity Gather",
		"Profession Skills, Node Filters & Farming Analytics"
	)
	frame:SetPoint("CENTER")

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetSize(576, 386)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)

	self:Refresh(frame)
	return frame
end

function InfinityGatherUI:Refresh(frame)
	local b = frame.body
	InfinityUIFramework:ClearContainer(b)

	-- Skills card
	local skillCard = InfinityUIFramework:CreateCard(b, 576, 150, "Gathering Profession Progress")
	skillCard:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -4)

	local skills = scanGatheringSkills()
	local y = -34
	for _, sk in ipairs(skills) do
		local pct = (sk.maxRank > 0) and ((sk.rank / sk.maxRank) * 100) or 0
		local bar = InfinityUIFramework:CreateStatusBar(skillCard, 552, 24, 0.18, 0.76, 0.44)
		bar:SetPoint("TOPLEFT", skillCard, "TOPLEFT", 12, y)
		bar:SetBarData(pct, sk.name, string.format("%d / %d", sk.rank, sk.maxRank))
		y = y - 30
	end

	-- Node filters card
	local filterCard = InfinityUIFramework:CreateCard(b, 576, 130, "Minimap & World Map Node Filters")
	filterCard:SetPoint("TOPLEFT", skillCard, "BOTTOMLEFT", 0, -12)

	local cb1 = InfinityUIFramework:CreateCheckbox(filterCard, "Track Herbalism Nodes (Black Lotus, Plaguebloom, Dreamfoil)", self.filters.herbs, function(v)
		self.filters.herbs = v
	end)
	cb1:SetPoint("TOPLEFT", filterCard, "TOPLEFT", 12, -32)

	local cb2 = InfinityUIFramework:CreateCheckbox(filterCard, "Track Mining Veins (Rich Thorium, Dark Iron, Mithril)", self.filters.ore, function(v)
		self.filters.ore = v
	end)
	cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, -4)

	local cb3 = InfinityUIFramework:CreateCheckbox(filterCard, "Track Treasure Chests & Fishing Pools", self.filters.treasure, function(v)
		self.filters.treasure = v
		self.filters.fishing = v
	end)
	cb3:SetPoint("TOPLEFT", cb2, "BOTTOMLEFT", 0, -4)

	-- Action buttons
	local openPathBtn = InfinityUIFramework:CreateButton(b, "Open GatherPath Route Optimizer", 220, 28, function()
		if _G.InfinityGatherPathUI and _G.InfinityGatherPathUI.Toggle then
			_G.InfinityGatherPathUI:Toggle()
		end
	end, true)
	openPathBtn:SetPoint("TOPLEFT", filterCard, "BOTTOMLEFT", 0, -14)

	local rescanBtn = InfinityUIFramework:CreateButton(b, "Rescan Skills", 116, 28, function()
		InfinityGatherUI:Refresh(frame)
		InfinityUIFramework:ShowNotification("Rescanned gathering professions.", 2)
	end)
	rescanBtn:SetPoint("LEFT", openPathBtn, "RIGHT", 10, 0)
end

return InfinityGatherUI
