-- PluribusGear UI Module
-- Live Equipped Gear Inspector, Classic/Forever Class Stat Weight Evaluator & Upgrade Priority

PluribusGearUI = {}
_G.PluribusGearUI = PluribusGearUI

local SLOTS = {
	{ id = 1, name = "Head" }, { id = 2, name = "Neck" }, { id = 3, name = "Shoulder" },
	{ id = 15, name = "Back" }, { id = 5, name = "Chest" }, { id = 9, name = "Wrist" },
	{ id = 10, name = "Hands" }, { id = 6, name = "Waist" }, { id = 7, name = "Legs" },
	{ id = 8, name = "Feet" }, { id = 11, name = "Finger 1" }, { id = 12, name = "Finger 2" },
	{ id = 13, name = "Trinket 1" }, { id = 14, name = "Trinket 2" }, { id = 16, name = "Main Hand" },
	{ id = 17, name = "Off Hand" }, { id = 18, name = "Ranged" },
}

local function scanEquippedGear()
	local items = {}
	local totalIlvl, count, epics, rares = 0, 0, 0, 0
	for _, slot in ipairs(SLOTS) do
		local link = GetInventoryItemLink and GetInventoryItemLink("player", slot.id) or nil
		local name, rarity, ilvl = "Empty Slot", 0, 0
		if link then
			local n, _, q, lvl
			if C_Item and C_Item.GetItemInfo then
				n, _, q, lvl = C_Item.GetItemInfo(link)
			elseif GetItemInfo then
				n, _, q, lvl = GetItemInfo(link)
			end
			name = n or link
			rarity = q or 1
			ilvl = lvl or 0
		end
		if ilvl > 0 then
			totalIlvl = totalIlvl + ilvl
			count = count + 1
		end
		if rarity == 4 or rarity == 5 then epics = epics + 1
		elseif rarity == 3 then rares = rares + 1 end
		table.insert(items, { slot = slot.name, name = name, link = link, rarity = rarity, ilvl = ilvl })
	end
	local avg = count > 0 and (totalIlvl / count) or 0
	return items, avg, epics, rares
end

function PluribusGearUI:Toggle()
	if not _G.PluribusGearWindow then
		_G.PluribusGearWindow = self:Create()
		_G.PluribusGearWindow:Show()
		return
	end
	if _G.PluribusGearWindow:IsVisible() then
		_G.PluribusGearWindow:Hide()
	else
		self:Refresh(_G.PluribusGearWindow)
		_G.PluribusGearWindow:Show()
	end
end

function PluribusGearUI:Create()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusGearWindow",
		UIParent,
		660,
		490,
		"Pluribus Gear Optimizer",
		"Live Equipment Audit & Stat Score"
	)
	frame:SetPoint("CENTER")

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetSize(636, 434)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)

	self:Refresh(frame)
	return frame
end

function PluribusGearUI:Refresh(frame)
	local b = frame.body
	PluribusUIFramework:ClearContainer(b)

	local items, avgIlvl, epics, rares = scanEquippedGear()
	local _, playerClass = UnitClass and UnitClass("player") or nil, "WARRIOR"
	local gearScore = math.floor(avgIlvl * 12 + epics * 35 + rares * 12)

	local m1 = PluribusUIFramework:CreateMetricTile(b, 150, 58, "Avg Item Level", string.format("%.1f", avgIlvl), "|cff38bdf8")
	m1:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -2)
	local m2 = PluribusUIFramework:CreateMetricTile(b, 150, 58, "Gear Score", gearScore, "|cfffbbf24")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = PluribusUIFramework:CreateMetricTile(b, 150, 58, "Epics Equipped", epics, "|cffa855f7")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)
	local m4 = PluribusUIFramework:CreateMetricTile(b, 150, 58, "Rares Equipped", rares, "|cff4ade80")
	m4:SetPoint("LEFT", m3, "RIGHT", 12, 0)

	local listCard = PluribusUIFramework:CreateCard(b, 636, 326, "Equipped Slots (" .. tostring(playerClass) .. ")")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -10)

	local scroll = PluribusUIFramework:CreateScrollFrame(listCard, "PluribusGearScroll", 620, 286)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 8, -32)
	local content = scroll.content

	local rarityHex = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
	local y = -2
	for idx, it in ipairs(items) do
		local row = PluribusUIFramework:CreateListRow(content, 594, 24, idx)
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)

		local l = PluribusUIFramework:CreateLabel(row, "|cff94a3b8" .. it.slot .. ":|r  " .. (rarityHex[it.rarity] or "|cffffffff") .. tostring(it.name) .. "|r")
		l:SetPoint("LEFT", row, "LEFT", 8, 0)
		local r = PluribusUIFramework:CreateLabel(row, it.ilvl > 0 and ("|cfffbbf24iLvl " .. tostring(it.ilvl) .. "|r") or "|cff64748b—|r")
		r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		y = y - 26
	end
	content:SetHeight(math.max(280, -y + 10))

	local rescanBtn = PluribusUIFramework:CreateButton(b, "Rescan Equipment", 140, 26, function()
		PluribusGearUI:Refresh(frame)
		PluribusUIFramework:ShowNotification("Equipment rescanned (Avg iLvl " .. string.format("%.1f", avgIlvl) .. ").", 2.2)
	end, true)
	rescanBtn:SetPoint("TOPLEFT", listCard, "BOTTOMLEFT", 0, -10)
end

return PluribusGearUI
