-- InfinityCore Character Manager
-- Automatically tracks characters, identifies mains vs twinks, and links them to accounts

InfinityCharacterManager = {}
InfinityCharacterManager.characters = {}
InfinityCharacterManager.currentChar = nil

-- Compatibility layer for WoW APIs across expansions
local function GetPlayerLevel()
	if C_Unit and C_Unit.GetLevel then
		return C_Unit.GetLevel("player") or 1
	end
	return UnitLevel("player") or 1
end

local function GetPlayerClass()
	if C_PlayerInfo and C_PlayerInfo.GetClass then
		local classInfo = C_PlayerInfo.GetClass("player")
		return classInfo and classInfo.classID or select(2, UnitClass("player"))
	end
	return select(2, UnitClass("player"))
end

local function GetPlayerRace()
	if C_PlayerInfo and C_PlayerInfo.GetRace then
		local raceInfo = C_PlayerInfo.GetRace("player")
		return raceInfo and raceInfo.raceID or select(2, UnitRace("player"))
	end
	return select(2, UnitRace("player"))
end

function InfinityCharacterManager:Initialize()
	local storageData = InfinityStorageManager:GetGlobal("characters", {})
	self.characters = storageData or {}
	
	-- Get current character info using compatibility layer
	self.currentChar = {
		name = UnitName("player"),
		realm = GetRealmName(),
		class = GetPlayerClass(),
		race = GetPlayerRace(),
		level = GetPlayerLevel(),
		isMain = false,
		linkedTo = nil,
		firstSeen = InfinityUtils:GetTimeStamp(),
	}
	
	-- Check if this character already exists
	local charKey = self.currentChar.name .. "-" .. self.currentChar.realm
	
	if self.characters[charKey] then
		-- Character exists, update info
		self.characters[charKey].level = self.currentChar.level
		self.characters[charKey].lastSeen = InfinityUtils:GetTimeStamp()
	else
		-- New character detected
		self.characters[charKey] = self.currentChar
		self:IdentifyCharacterType()
	end
	
	self:SaveCharacters()
	InfinityUtils:Info("Character Manager initialized for " .. self.currentChar.name, "CharacterManager")
end

function InfinityCharacterManager:IdentifyCharacterType()
	-- Auto-identify mains and twinks based on level and progression
	local charKey = self.currentChar.name .. "-" .. self.currentChar.realm
	local char = self.characters[charKey]
	
	if not char then return end
	
	-- Check if this is a high-level character (main indicator)
	if char.level >= 60 then
		-- Check if we already have a main
		local hasMain = false
		for _, existingChar in pairs(self.characters) do
			if existingChar.isMain and existingChar.name ~= char.name then
				hasMain = true
				break
			end
		end
		
		-- If no main exists yet, or this is higher level, mark as main
		if not hasMain or (char.level > 60) then
			char.isMain = true
			InfinityMessaging:Publish("character_marked_main", { character = char.name })
		else
			-- Link to main as twink
			for key, existingChar in pairs(self.characters) do
				if existingChar.isMain then
					char.linkedTo = existingChar.name
					InfinityMessaging:Publish("character_marked_twink", { 
						character = char.name,
						linkedTo = existingChar.name 
					})
					break
				end
			end
		end
	else
		-- Lower level = likely a twink, link to any main
		for key, existingChar in pairs(self.characters) do
			if existingChar.isMain then
				char.linkedTo = existingChar.name
				InfinityMessaging:Publish("character_marked_twink", { 
					character = char.name,
					linkedTo = existingChar.name 
				})
				break
			end
		end
	end
end

function InfinityCharacterManager:GetCurrentCharacter()
	return self.currentChar
end

function InfinityCharacterManager:GetCharacterKey(charName, realmName)
	return charName .. "-" .. (realmName or GetRealmName())
end

function InfinityCharacterManager:GetAllCharacters()
	local result = {}
	for key, char in pairs(self.characters) do
		table.insert(result, char)
	end
	return result
end

function InfinityCharacterManager:GetMains()
	local mains = {}
	for key, char in pairs(self.characters) do
		if char.isMain then
			table.insert(mains, char)
		end
	end
	return mains
end

function InfinityCharacterManager:GetTwinks(mainName)
	local twinks = {}
	for key, char in pairs(self.characters) do
		if char.linkedTo == mainName then
			table.insert(twinks, char)
		end
	end
	return twinks
end

function InfinityCharacterManager:GetCharacterFamily(mainName)
	local family = {}
	
	-- Add the main
	for key, char in pairs(self.characters) do
		if char.name == mainName and char.isMain then
			table.insert(family, {
				name = char.name,
				level = char.level,
				class = char.class,
				type = "main",
				realm = char.realm,
			})
		end
	end
	
	-- Add all twinks of this main
	for key, char in pairs(self.characters) do
		if char.linkedTo == mainName then
			table.insert(family, {
				name = char.name,
				level = char.level,
				class = char.class,
				type = "twink",
				linkedTo = mainName,
				realm = char.realm,
			})
		end
	end
	
	return family
end

function InfinityCharacterManager:MarkAsMain(charName)
	local charKey = self.GetCharacterKey(self, charName)
	
	if not self.characters[charKey] then return nil end
	
	-- Unmark any existing main on this account
	for key, char in pairs(self.characters) do
		if char.isMain then
			char.isMain = false
			char.linkedTo = charName -- Link old main as twink to new main
		end
	end
	
	-- Mark as main
	self.characters[charKey].isMain = true
	self.characters[charKey].linkedTo = nil
	
	self:SaveCharacters()
	InfinityMessaging:Publish("character_marked_main", { character = charName })
	
	return self.characters[charKey]
end

function InfinityCharacterManager:LinkCharacterToMain(charName, mainName)
	local charKey = self:GetCharacterKey(charName)
	
	if not self.characters[charKey] then return nil end
	
	self.characters[charKey].isMain = false
	self.characters[charKey].linkedTo = mainName
	
	self:SaveCharacters()
	InfinityMessaging:Publish("character_linked", { 
		character = charName,
		linkedTo = mainName 
	})
	
	return self.characters[charKey]
end

function InfinityCharacterManager:GetCharacterStats()
	local totalChars = 0
	local mains = 0
	local twinks = 0
	local totalLevel = 0
	local classes = {}
	
	for key, char in pairs(self.characters) do
		totalChars = totalChars + 1
		totalLevel = totalLevel + (char.level or 1)
		
		if char.isMain then
			mains = mains + 1
		else
			twinks = twinks + 1
		end
		
		if not classes[char.class] then
			classes[char.class] = 0
		end
		classes[char.class] = classes[char.class] + 1
	end
	
	return {
		totalCharacters = totalChars,
		mains = mains,
		twinks = twinks,
		averageLevel = totalChars > 0 and (totalLevel / totalChars) or 0,
		classesCounted = classes,
	}
end

function InfinityCharacterManager:ExportCharacterData()
	-- Export all character data for sharing/syncing
	local exported = {}
	
	for key, char in pairs(self.characters) do
		table.insert(exported, {
			name = char.name,
			realm = char.realm,
			level = char.level,
			class = char.class,
			race = char.race,
			isMain = char.isMain,
			linkedTo = char.linkedTo,
			firstSeen = char.firstSeen,
			lastSeen = char.lastSeen,
		})
	end
	
	return exported
end

function InfinityCharacterManager:SaveCharacters()
	InfinityStorageManager:SetGlobal("characters", self.characters)
	InfinityDataManager:UpdateSourceData("InfinityCore", "characters", self.characters)
end

return InfinityCharacterManager
