-- PluribusGather UI Module
-- Full Gathering Skill Progress, Node Type Filters, and Route Launcher for WoW Forever

PluribusGatherUI = {
	filters = { herbs = true, ore = true, treasure = true, fishing = true },
}
_G.PluribusGatherUI = PluribusGatherUI

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

function PluribusGatherUI:Toggle()
	if not _G.PluribusGatherWindow then
		_G.PluribusGatherWindow = self:Create()
		_G.PluribusGatherWindow:Show()
		return
	end
	if _G.PluribusGatherWindow:IsVisible() then
		_G.PluribusGatherWindow:Hide()
	else
		self:Refresh(_G.PluribusGatherWindow)
		_G.PluribusGatherWindow:Show()
	end
end

function PluribusGatherUI:Create()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusGatherWindow",
		UIParent,
		600,
		440,
		"Pluribus Gather",
		"Profession Skills, Node Filters & Farming Analytics"
	)
	frame:SetPoint("CENTER")

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetSize(576, 386)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)

	self:Refresh(frame)
	return frame
end

function PluribusGatherUI:Refresh(frame)
	local b = frame.body
	PluribusUIFramework:ClearContainer(b)

	-- Skills card
	local skillCard = PluribusUIFramework:CreateCard(b, 576, 150, "Gathering Profession Progress")
	skillCard:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -4)

	local skills = scanGatheringSkills()
	local y = -34
	for _, sk in ipairs(skills) do
		local pct = (sk.maxRank > 0) and ((sk.rank / sk.maxRank) * 100) or 0
		local bar = PluribusUIFramework:CreateStatusBar(skillCard, 552, 24, 0.18, 0.76, 0.44)
		bar:SetPoint("TOPLEFT", skillCard, "TOPLEFT", 12, y)
		bar:SetBarData(pct, sk.name, string.format("%d / %d", sk.rank, sk.maxRank))
		y = y - 30
	end

	-- Node filters card
	local filterCard = PluribusUIFramework:CreateCard(b, 576, 130, "Minimap & World Map Node Filters")
	filterCard:SetPoint("TOPLEFT", skillCard, "BOTTOMLEFT", 0, -12)

	local cb1 = PluribusUIFramework:CreateCheckbox(filterCard, "Track Herbalism Nodes (Black Lotus, Plaguebloom, Dreamfoil)", self.filters.herbs, function(v)
		self.filters.herbs = v
	end)
	cb1:SetPoint("TOPLEFT", filterCard, "TOPLEFT", 12, -32)

	local cb2 = PluribusUIFramework:CreateCheckbox(filterCard, "Track Mining Veins (Rich Thorium, Dark Iron, Mithril)", self.filters.ore, function(v)
		self.filters.ore = v
	end)
	cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, -4)

	local cb3 = PluribusUIFramework:CreateCheckbox(filterCard, "Track Treasure Chests & Fishing Pools", self.filters.treasure, function(v)
		self.filters.treasure = v
		self.filters.fishing = v
	end)
	cb3:SetPoint("TOPLEFT", cb2, "BOTTOMLEFT", 0, -4)

	-- Action buttons
	local openPathBtn = PluribusUIFramework:CreateButton(b, "Open GatherPath Route Optimizer", 220, 28, function()
		if _G.PluribusGatherPathUI and _G.PluribusGatherPathUI.Toggle then
			_G.PluribusGatherPathUI:Toggle()
		end
	end, true)
	openPathBtn:SetPoint("TOPLEFT", filterCard, "BOTTOMLEFT", 0, -14)

	local rescanBtn = PluribusUIFramework:CreateButton(b, "Rescan Skills", 116, 28, function()
		PluribusGatherUI:Refresh(frame)
		PluribusUIFramework:ShowNotification("Rescanned gathering professions.", 2)
	end)
	rescanBtn:SetPoint("LEFT", openPathBtn, "RIGHT", 10, 0)
end

return PluribusGatherUI
