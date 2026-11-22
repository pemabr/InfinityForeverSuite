local Sources = {}
_G.InfinityGuideSources = Sources

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value)
	value = Public(value)
	return type(value) == "number" and value > 0 and value <= 1000000000 and value == math.floor(value)
end

function Sources:Available()
	local lib = _G.LibQuestieDB
	if type(lib) ~= "table" or type(lib.RequireContract) ~= "function" or type(lib.Quest) ~= "table"
		or type(lib.Quest.Exists) ~= "function" or type(lib.Quest.nextQuestInChain) ~= "function" then return false end
	local ok, compatible = pcall(lib.RequireContract, 1)
	return ok and Public(compatible) == true
end

function Sources:Initialize()
	if self.initialized then return end
	local settings = InfinityStorageManager:GetFeatureSetting("InfinityGuide", "sourceDecisions", {})
	if type(settings) ~= "table" or (settings.QuestieDB ~= nil and type(settings.QuestieDB) ~= "boolean") then
		InfinityUtils:Warning("Invalid guide import settings.", "Guide")
		return
	end
	self.settings = settings
	self.initialized = true
	if _G.StaticPopupDialogs and _G.StaticPopup_Show then
		StaticPopupDialogs.INFINITY_GUIDE_QUESTIEDB = {
			text = "QuestieDB found. Allow creating optional quest-chain guides from its quest IDs?",
			button1 = "Allow",
			button2 = "No",
			OnAccept = function() Sources:SetAllowed(true) end,
			OnCancel = function() Sources:SetAllowed(false) end,
			timeout = 0, whileDead = true, hideOnEscape = false,
		}
	end
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGIN" then self.loggedIn = true end
		if self.loggedIn then self:Offer() end
	end)
	self.frame = frame
	if _G.IsLoggedIn and Public(IsLoggedIn()) then self.loggedIn = true; self:Offer() end
end

function Sources:SetAllowed(allowed)
	if not self.settings then return false end
	self.settings.QuestieDB = not not allowed
	InfinityStorageManager:SetFeatureSetting("InfinityGuide", "sourceDecisions", self.settings)
	if allowed then
		print("QuestieDB enabled: /infguide import questie <first quest ID>.")
	else
		print("QuestieDB guide import disabled. Enable with /infguide source allow.")
	end
	return true
end

function Sources:Offer()
	if not self.settings or self.settings.QuestieDB ~= nil or self.offered or not self:Available() then return end
	local combat = _G.InCombatLockdown and InCombatLockdown()
	if _G.issecretvalue and issecretvalue(combat) then return end
	if combat then return end
	self.offered = true
	if _G.StaticPopupDialogs and _G.StaticPopup_Show then
		if not StaticPopup_Show("INFINITY_GUIDE_QUESTIEDB") then self.offered = false end
	else
		print("QuestieDB found. Allow optional quest-chain imports with /infguide source allow.")
	end
end

function Sources:ImportChain(firstID)
	firstID = Public(firstID)
	if not self.settings or not self.settings.QuestieDB then
		InfinityUtils:Warning("Allow QuestieDB guide imports first: /infguide source allow.", "Guide")
		return false
	end
	if not self:Available() or not Integer(firstID) then
		InfinityUtils:Warning("QuestieDB or the requested quest ID is unavailable.", "Guide")
		return false
	end
	local lib, current, seen, steps = _G.LibQuestieDB, firstID, {}, {}
	while current and #steps < 200 do
		if not Integer(current) or seen[current] then
			InfinityUtils:Warning("Invalid or cyclic QuestieDB quest chain; nothing imported.", "Guide")
			return false
		end
		seen[current] = true
		local ok, exists = pcall(lib.Quest.Exists, current)
		exists = Public(exists)
		if not ok or exists ~= true then
			InfinityUtils:Warning("QuestieDB chain contains an unavailable quest; nothing imported.", "Guide")
			return false
		end
		steps[#steps + 1] = { description = "Quest " .. current, questID = current }
		local nextOK, nextID = pcall(lib.Quest.nextQuestInChain, current)
		if not nextOK or (_G.issecretvalue and issecretvalue(nextID)) then
			InfinityUtils:Warning("QuestieDB chain lookup failed; nothing imported.", "Guide")
			return false
		end
		nextID = Public(nextID)
		if nextID == nil or nextID == 0 then current = nil
		elseif Integer(nextID) then current = nextID
		else
			InfinityUtils:Warning("Invalid QuestieDB chain link; nothing imported.", "Guide")
			return false
		end
	end
	if current then
		InfinityUtils:Warning("QuestieDB chain exceeds 200 quests; nothing imported.", "Guide")
		return false
	end
	local guide = InfinityGuideGuides:CreateFromSteps("QuestieDB chain " .. firstID, "QuestieDB", steps)
	if not guide then return false end
	print("Imported " .. #steps .. " quest IDs as " .. guide.id .. ". Select it in My Guides.")
	return true
end

return Sources
