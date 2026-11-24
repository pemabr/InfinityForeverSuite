-- PluribusGuide UI Module
-- Classic / WoW Forever Leveling Brackets & Raid Attunement Checklists (MC, Onyxia, BWL, Naxxramas)

PluribusGuideUI = {
	currentTab = "attunements",
}
_G.PluribusGuideUI = PluribusGuideUI

local ATTUNEMENTS = {
	{ raid = "Molten Core", questId = 7848, quest = "Attunement to the Core", tip = "Loot Core Fragment inside Blackrock Depths near the MC portal and return to Lothos Riftwaker." },
	{ raid = "Blackwing Lair", questId = 7761, quest = "Blackhand's Command", tip = "Loot letter from Scarshield Quartermaster outside UBRS, then click Orb of Command behind General Drakkisath." },
	{ raid = "Onyxia's Lair (Alliance)", questId = 6502, quest = "Dragonfire Amulet", tip = "Complete Marshal Windsor chain in BRD/Stormwind and slay General Drakkisath in UBRS." },
	{ raid = "Onyxia's Lair (Horde)", questId = 6602, quest = "Blood of the Black Dragon Champion", tip = "Complete Warlord's Command in LBRS, Rexxar in Desolace, and slay General Drakkisath in UBRS." },
	{ raid = "Naxxramas", questId = 9121, quest = "The Dread Citadel — Naxxramas", tip = "Argent Dawn Reputation: Honored (Arcane Crystals + Nexus Crystals + Gold), Revered (discounted), Exalted (Free!)." },
}

local LEVELING_ROUTES = {
	{ range = "1 - 20", zones = "Elwynn -> Westfall -> Redridge  /  Durotar -> The Barrens -> Silverpine", dungeons = "Deadmines, Wailing Caverns, Ragefire Chasm" },
	{ range = "20 - 35", zones = "Duskwood -> Wetlands -> Hillsbrad -> Thousand Needles -> Stranglethorn", dungeons = "Shadowfang Keep, Stockades, Gnomeregan, Scarlet Monastery" },
	{ range = "35 - 48", zones = "Stranglethorn Vale -> Badlands -> Tanaris -> Feralas -> Hinterlands", dungeons = "Scarlet Monastery Cath, Razorfen Downs, Uldaman, Zul'Farrak" },
	{ range = "48 - 60", zones = "Searing Gorge -> Un'Goro -> Felwood -> Western & Eastern Plaguelands -> Winterspring", dungeons = "Maraudon, Sunken Temple, BRD, LBRS/UBRS, Dire Maul, Stratholme, Scholomance" },
}

local function isQuestDone(questID)
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
		if ok then return done == true end
	elseif IsQuestFlaggedCompleted then
		local ok, done = pcall(IsQuestFlaggedCompleted, questID)
		if ok then return done == true end
	end
	return false
end

function PluribusGuideUI:Toggle()
	if not _G.PluribusGuideWindow then
		_G.PluribusGuideWindow = self:Create()
		_G.PluribusGuideWindow:Show()
		return
	end
	if _G.PluribusGuideWindow:IsVisible() then
		_G.PluribusGuideWindow:Hide()
	else
		self:ShowTab(_G.PluribusGuideWindow, self.currentTab)
		_G.PluribusGuideWindow:Show()
	end
end

function PluribusGuideUI:Create()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusGuideWindow",
		UIParent,
		680,
		470,
		"Pluribus Guide",
		"Attunement Tracker & Azeroth Leveling Routes"
	)
	frame:SetPoint("CENTER")

	local tabs = {
		{ name = "Raid Attunements", key = "attunements" },
		{ name = "1-60 Leveling Route", key = "leveling" },
	}
	local tabBar = PluribusUIFramework:CreateTabBar(frame, tabs, function(k)
		PluribusGuideUI.currentTab = k
		PluribusGuideUI:ShowTab(frame, k)
	end, 656)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)

	frame.content = CreateFrame("Frame", nil, frame)
	frame.content:SetSize(656, 378)
	frame.content:SetPoint("TOP", tabBar, "BOTTOM", 0, -8)

	tabBar:SelectTab("attunements")
	return frame
end

function PluribusGuideUI:ShowTab(frame, tabKey)
	local c = frame.content
	PluribusUIFramework:ClearContainer(c)

	if tabKey == "attunements" then
		local y = -4
		for _, att in ipairs(ATTUNEMENTS) do
			local done = isQuestDone(att.questId)
			local card = PluribusUIFramework:CreateCard(c, 656, 66, att.raid .. " — " .. att.quest)
			card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)

			local badge = PluribusUIFramework:CreateLabel(card, done and "|cff4ade80COMPLETED|r" or "|cfffbbf24IN PROGRESS|r")
			badge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -8)

			local tip = PluribusUIFramework:CreateLabel(card, "|cff94a3b8" .. att.tip .. "|r")
			tip:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -28)
			tip:SetWidth(632)
			tip:SetWordWrap(true)

			y = y - 72
		end
	else
		local y = -4
		for _, r in ipairs(LEVELING_ROUTES) do
			local card = PluribusUIFramework:CreateCard(c, 656, 82, "Levels " .. r.range)
			card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)

			local zLbl = PluribusUIFramework:CreateLabel(card, "|cff38bdf8Zones:|r " .. r.zones)
			zLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -28)
			zLbl:SetWidth(632)

			local dLbl = PluribusUIFramework:CreateLabel(card, "|cfffbbf24Key Dungeons:|r " .. r.dungeons)
			dLbl:SetPoint("TOPLEFT", zLbl, "BOTTOMLEFT", 0, -6)
			dLbl:SetWidth(632)

			y = y - 90
		end
	end
end

return PluribusGuideUI
