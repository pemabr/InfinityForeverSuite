-- InfinityDetails Breakdown Window
-- Individual player combat breakdown with crit rate, average hit, and bar visualization

local InfinityDetailsBreakdown = {
	selectedActor = nil,
}
_G.InfinityDetailsBreakdown = InfinityDetailsBreakdown

function InfinityDetailsBreakdown:Initialize()
	if self.initialized and self.frame then return end

	local frame = InfinityUIFramework:CreateFrame(
		"InfinityDetailsBreakdownFrame",
		UIParent,
		500,
		390,
		"Infinity Details — Breakdown",
		"Actor Performance Inspector"
	)
	frame:SetPoint("CENTER", UIParent, "CENTER", -160, 0)

	frame.content = CreateFrame("Frame", nil, frame)
	frame.content:SetSize(476, 336)
	frame.content:SetPoint("TOP", frame, "TOP", 0, -44)

	frame:Hide()
	self.frame = frame
	self.initialized = true
end

function InfinityDetailsBreakdown:ShowActor(actorEntry)
	if not self.initialized then self:Initialize() end
	self.selectedActor = actorEntry
	self.frame:Show()
	self:Update()
end

function InfinityDetailsBreakdown:Toggle()
	if not self.initialized then self:Initialize() end
	self.frame:SetShown(not self.frame:IsShown())
	if self.frame:IsShown() then self:Update() end
end

function InfinityDetailsBreakdown:Show()
	if not self.initialized then self:Initialize() end
	self.frame:Show()
	self:Update()
end

function InfinityDetailsBreakdown:Update()
	if not self.initialized or not self.frame or not self.frame:IsShown() then return end
	local c = self.frame.content
	InfinityUIFramework:ClearContainer(c)

	if self.selectedActor then
		local a = self.selectedActor
		local cr, cg, cb, cHex = InfinityUIFramework:GetClassColor(a.class)
		local hdr = InfinityUIFramework:CreateLabel(c, cHex .. tostring(a.name or "Player") .. "|r  |cff94a3b8(" .. tostring(a.class or "Unknown") .. ")|r", nil, nil, nil, "GameFontNormalLarge")
		hdr:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -6)

		local m1 = InfinityUIFramework:CreateMetricTile(c, 150, 58, "Total Output", math.floor(a.damage or a.healing or a.threat or 0), "|cff38bdf8")
		m1:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -12)
		local m2 = InfinityUIFramework:CreateMetricTile(c, 150, 58, "Per Second", string.format("%.1f/s", a.dps or a.hps or a.tps or 0), "|cff4ade80")
		m2:SetPoint("LEFT", m1, "RIGHT", 10, 0)
		local m3 = InfinityUIFramework:CreateMetricTile(c, 150, 58, "Crit Rate", string.format("%.1f%%", a.crits or 0), "|cfffbbf24")
		m3:SetPoint("LEFT", m2, "RIGHT", 10, 0)

		local statsCard = InfinityUIFramework:CreateCard(c, 470, 175, "Hit Distribution & Efficiency")
		statsCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -14)

		local b1 = InfinityUIFramework:CreateStatusBar(statsCard, 446, 24, cr, cg, cb)
		b1:SetPoint("TOPLEFT", statsCard, "TOPLEFT", 12, -34)
		b1:SetBarData(100, "Total Hits", tostring(a.hits or 0) .. " hits")

		local b2 = InfinityUIFramework:CreateStatusBar(statsCard, 446, 24, 0.92, 0.72, 0.22)
		b2:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -8)
		b2:SetBarData(math.min(100, a.crits or 0), "Critical Strike %", string.format("%.1f%%", a.crits or 0))

		local b3 = InfinityUIFramework:CreateStatusBar(statsCard, 446, 24, 0.18, 0.76, 0.44)
		b3:SetPoint("TOPLEFT", b2, "BOTTOMLEFT", 0, -8)
		b3:SetBarData(75, "Average Hit", string.format("%.0f", a.avg or 0))

		return
	end

	-- Default view: top 8 damage dealers
	local card = InfinityUIFramework:CreateCard(c, 476, 326, "Top Combatants (Click any bar in Details to inspect)")
	card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

	local top = (_G.InfinityDetailsActor and _G.InfinityDetailsActor.GetTopDamageDealers) and _G.InfinityDetailsActor:GetTopDamageDealers(8) or {}
	if #top == 0 then
		local empty = InfinityUIFramework:CreateLabel(card, "|cff94a3b8No actor combat data recorded yet.|r")
		empty:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -36)
		return
	end

	local maxDmg = math.max(1, top[1].damage_total or 1)
	local y = -34
	for i, actor in ipairs(top) do
		local cr, cg, cb, cHex = InfinityUIFramework:GetClassColor(actor.class)
		local bar = InfinityUIFramework:CreateStatusBar(card, 452, 24, cr, cg, cb)
		bar:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
		bar:SetBarData(((actor.damage_total or 0) / maxDmg) * 100, string.format("%d. %s%s|r", i, cHex, tostring(actor.name)), string.format("%d dmg (%d hits)", actor.damage_total or 0, actor.damage_hits or 0))
		y = y - 28
	end
end

return InfinityDetailsBreakdown
