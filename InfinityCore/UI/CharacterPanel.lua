-- InfinityCore Character Management UI
-- Display character tracking and main/twink linking

InfinityCharacterUI = {}

function InfinityCharacterUI:CreatePanel(parentFrame)
	local panel = CreateFrame("Frame", nil, parentFrame)
	panel:SetSize(600, 350)
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(panel, 
		INFINITY_COLORS.PRIMARY .. "Character Management" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	local y = -35
	
	-- Current character info
	local currentChar = InfinityCharacterManager and InfinityCharacterManager:GetCurrentCharacter()
	if not currentChar then
		local waitLabel = InfinityUIFramework:CreateLabel(panel, "Waiting for character data...")
		waitLabel:SetPoint("TOPLEFT", 10, y)
		return panel
	end
	local currentInfo = InfinityUIFramework:CreateLabel(panel,
		INFINITY_COLORS.SECONDARY .. currentChar.name .. INFINITY_COLORS.RESET .. 
		" - Level " .. currentChar.level .. " " .. tostring(currentChar.class))
	currentInfo:SetPoint("TOPLEFT", 10, y)
	if not currentChar.isMain then
		local makeMainBtn = InfinityUIFramework:CreateButton(panel, "Set as Main", 100, 20, function()
			InfinityCharacterManager:MarkAsMain(InfinityCharacterManager:GetCharacterKey(currentChar.name, currentChar.realm))
		end)
		makeMainBtn:SetPoint("TOPRIGHT", -20, y)
	end
	y = y - 20
	
	local charType = currentChar.isMain and "MAIN" or "TWINK"
	local typeColor = currentChar.isMain and INFINITY_COLORS.SUCCESS or INFINITY_COLORS.WARNING
	local typeLabel = InfinityUIFramework:CreateLabel(panel,
		"Type: " .. typeColor .. charType .. INFINITY_COLORS.RESET)
	typeLabel:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	if currentChar.linkedTo then
		local linkedLabel = InfinityUIFramework:CreateLabel(panel,
			"Linked to: " .. INFINITY_COLORS.INFO .. currentChar.linkedTo .. INFINITY_COLORS.RESET)
		linkedLabel:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
	
	y = y - 10
	
	-- All characters
	local allTitle = InfinityUIFramework:CreateLabel(panel, "Your Characters:")
	allTitle:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	local characters = InfinityCharacterManager:GetAllCharacters()
	for i, char in ipairs(characters) do
		if i > 10 then break end
		
		local charStr = char.name .. " - Level " .. char.level .. " " .. char.class
		if char.isMain then
			charStr = charStr .. " " .. INFINITY_COLORS.SUCCESS .. "[MAIN]" .. INFINITY_COLORS.RESET
		elseif char.linkedTo then
			charStr = charStr .. " " .. INFINITY_COLORS.WARNING .. "[" .. char.linkedTo .. "]" .. INFINITY_COLORS.RESET
		end
		
		local charLabel = InfinityUIFramework:CreateLabel(panel, charStr)
		charLabel:SetPoint("TOPLEFT", 20, y)
		y = y - 15
	end
	
	-- Character stats
	y = y - 20
	local stats = InfinityCharacterManager:GetCharacterStats()
	local statsLabel = InfinityUIFramework:CreateLabel(panel,
		"Total: " .. stats.totalCharacters .. " characters | " ..
		stats.mains .. " mains | " ..
		stats.twinks .. " twinks")
	statsLabel:SetPoint("TOPLEFT", 10, y)
	
	return panel
end

return InfinityCharacterUI
