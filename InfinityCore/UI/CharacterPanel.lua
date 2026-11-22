-- InfinityCore Character Management UI
-- Character profile card, main/alt linking, and account roster table

InfinityCharacterUI = {}

function InfinityCharacterUI:CreatePanel(parentFrame)
	local panel = CreateFrame("Frame", nil, parentFrame)
	panel:SetSize(640, 360)

	local currentChar = InfinityCharacterManager and InfinityCharacterManager:GetCurrentCharacter() or {
		name = UnitName and UnitName("player") or "Player",
		level = UnitLevel and UnitLevel("player") or 60,
		class = select and select(2, UnitClass("player")) or "WARRIOR",
		isMain = true,
	}

	local _, _, _, classHex = InfinityUIFramework:GetClassColor(currentChar.class)
	local headerCard = InfinityUIFramework:CreateCard(panel, 624, 90, "Active Character Profile")
	headerCard:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)

	local charInfo = InfinityUIFramework:CreateLabel(
		headerCard,
		string.format("%s%s|r  —  Level %d %s", classHex, currentChar.name, currentChar.level or 60, tostring(currentChar.class)),
		nil, nil, nil, "GameFontNormalLarge"
	)
	charInfo:SetPoint("TOPLEFT", headerCard, "TOPLEFT", 12, -30)

	local roleBadge = currentChar.isMain and "|cff4ade80[MAIN CHARACTER]|r" or ("|cfffbbf24[ALT -> " .. tostring(currentChar.linkedTo or "Unlinked") .. "]|r")
	local roleLabel = InfinityUIFramework:CreateLabel(headerCard, roleBadge)
	roleLabel:SetPoint("TOPLEFT", charInfo, "BOTTOMLEFT", 0, -6)

	-- Quick Set Main / Link Alt controls
	local linkInput = InfinityUIFramework:CreateInputBox(headerCard, 130, 22)
	linkInput:SetPoint("TOPRIGHT", headerCard, "TOPRIGHT", -196, -34)
	linkInput:SetText(currentChar.linkedTo or "")

	local linkBtn = InfinityUIFramework:CreateButton(headerCard, "Link to Main", 92, 22, function()
		local mainName = linkInput:GetText()
		if mainName and mainName ~= "" and InfinityCharacterManager and InfinityCharacterManager.LinkTwinkToMain then
			InfinityCharacterManager:LinkTwinkToMain(currentChar.name, mainName)
			InfinityUIFramework:ShowNotification("Linked " .. currentChar.name .. " -> " .. mainName, 2.5)
		end
	end)
	linkBtn:SetPoint("LEFT", linkInput, "RIGHT", 6, 0)

	local setMainBtn = InfinityUIFramework:CreateButton(headerCard, "Set Main", 80, 22, function()
		if InfinityCharacterManager and InfinityCharacterManager.SetCharacterAsMain then
			InfinityCharacterManager:SetCharacterAsMain(currentChar.name)
			InfinityUIFramework:ShowNotification(currentChar.name .. " set as Main.", 2.5)
		end
	end, true)
	setMainBtn:SetPoint("LEFT", linkBtn, "RIGHT", 6, 0)

	-- Account characters list card
	local listCard = InfinityUIFramework:CreateCard(panel, 624, 244, "Tracked Account Characters")
	listCard:SetPoint("TOPLEFT", headerCard, "BOTTOMLEFT", 0, -10)

	local characters = InfinityCharacterManager and InfinityCharacterManager:GetAllCharacters() or {}
	local y = -32
	for i, char in ipairs(characters) do
		if i > 7 then break end
		local row = InfinityUIFramework:CreateListRow(listCard, 600, 24, i)
		row:SetPoint("TOPLEFT", listCard, "TOPLEFT", 12, y)

		local _, _, _, cHex = InfinityUIFramework:GetClassColor(char.class)
		local left = InfinityUIFramework:CreateLabel(row, string.format("%s%s|r  (Lv %d %s)", cHex, char.name, char.level or 60, tostring(char.class)))
		left:SetPoint("LEFT", row, "LEFT", 8, 0)

		local tag = char.isMain and "|cff4ade80MAIN|r" or (char.linkedTo and ("|cfffbbf24ALT -> " .. char.linkedTo .. "|r") or "|cff94a3b8ALT|r")
		local right = InfinityUIFramework:CreateLabel(row, tag)
		right:SetPoint("RIGHT", row, "RIGHT", -8, 0)

		y = y - 26
	end

	local stats = InfinityCharacterManager and InfinityCharacterManager:GetCharacterStats() or { totalCharacters = #characters, mains = 1, twinks = 0 }
	local statsLabel = InfinityUIFramework:CreateLabel(
		listCard,
		string.format("|cff94a3b8Total: %d characters  |  %d Mains  |  %d Alts|r", stats.totalCharacters or 0, stats.mains or 0, stats.twinks or 0)
	)
	statsLabel:SetPoint("BOTTOMLEFT", listCard, "BOTTOMLEFT", 12, 8)

	return panel
end

_G.InfinityCharacterUI = InfinityCharacterUI
return InfinityCharacterUI
