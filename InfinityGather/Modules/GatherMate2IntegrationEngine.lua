local Source = {}
_G.InfinityGatherMateSource = Source

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

function Source:Available()
	local provider = Public(_G.GatherMate2)
	return type(provider) == "table" and type(Public(provider.GetNodesForZone)) == "function"
		and type(Public(provider.DecodeLoc)) == "function"
end

function Source:Initialize()
	if self.initialized then return end
	local choice = Public(InfinityStorageManager:GetFeatureSetting("InfinityGather", "gatherMateSource", "ask"))
	if choice ~= "ask" and choice ~= "on" and choice ~= "off" then
		InfinityUtils:Warning("Invalid GatherMate2 source setting; use /gather source on or off.", "Gather")
		choice = "off"
	end
	self.choice, self.initialized = choice, true
	if _G.StaticPopupDialogs and _G.StaticPopup_Show then
		StaticPopupDialogs.INFINITY_GATHER_GATHERMATE = {
			text = "GatherMate2 found. Show its herb and ore positions as a live source? No positions are imported or shared.",
			button1 = "Allow", button2 = "No",
			OnAccept = function() Source:SetEnabled(true) end,
			OnCancel = function() Source:SetEnabled(false) end,
			timeout = 0, whileDead = true, hideOnEscape = false,
		}
	end
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event, addon)
		if event == "PLAYER_LOGIN" then self.loggedIn = true end
		if self.loggedIn and (event ~= "ADDON_LOADED" or addon == "GatherMate2") then self:Detect() end
	end)
	self.frame = frame
	if _G.IsLoggedIn and Public(IsLoggedIn()) then self.loggedIn = true; self:Detect() end
end

function Source:Detect()
	if not self:Available() then return end
	if self.choice == "on" then
		self.warnedUnavailable = nil
		if _G.InfinityGatherUI then InfinityGatherUI:Refresh() end
		return
	end
	local combat = _G.InCombatLockdown and Public(InCombatLockdown())
	if _G.InCombatLockdown and combat == nil then return end
	if combat or self.choice ~= "ask" or self.offered then return end
	self.offered = true
	if _G.StaticPopupDialogs and _G.StaticPopup_Show then
		if not StaticPopup_Show("INFINITY_GATHER_GATHERMATE") then self.offered = false end
	else
		print("GatherMate2 found. Enable its live positions with /gather source on.")
	end
end

function Source:SetEnabled(enabled)
	if not self.initialized then return false end
	self.choice = enabled and "on" or "off"
	InfinityStorageManager:SetFeatureSetting("InfinityGather", "gatherMateSource", self.choice)
	self.warnedUnavailable, self.warnedFailure, self.warnedInvalid = nil, nil, nil
	if enabled and not self:Available() then
		self.warnedUnavailable = true
		InfinityUtils:Warning("GatherMate2 live source is enabled but unavailable.", "Gather")
	end
	if _G.InfinityGatherUI then
		InfinityGatherUI.routeOrder, InfinityGatherUI.routeMapID = nil, nil
		if InfinityGatherUI.routeFrame then InfinityGatherUI.routeFrame:Hide() end
		InfinityGatherUI:Refresh()
	end
	print(enabled and "GatherMate2 live source enabled." or "GatherMate2 live source disabled.")
	return true
end

function Source:GetNodes(mapID, limit)
	local result = {}
	if self.choice ~= "on" then return result, false end
	if not self:Available() then
		if not self.warnedUnavailable then
			self.warnedUnavailable = true
			InfinityUtils:Warning("GatherMate2 live source is enabled but unavailable.", "Gather")
		end
		return result, false
	end
	local provider = _G.GatherMate2
	local truncated, invalid = false, false
	local ok, err = pcall(function()
		local scanned = 0
		for _, category in ipairs({ { "Herb Gathering", "Herb" }, { "Mining", "Ore" } }) do
			for coordinate, nodeID in provider:GetNodesForZone(mapID, category[1]) do
				scanned = scanned + 1
				if scanned > 5000 then truncated = true; return end
				coordinate, nodeID = Public(coordinate), Public(nodeID)
				if type(coordinate) == "number" and coordinate == coordinate and coordinate >= 0
					and coordinate < 10000000000 and coordinate == math.floor(coordinate)
					and type(nodeID) == "number" and nodeID == nodeID and nodeID > 0
					and nodeID < math.huge then
					local x, y = provider:DecodeLoc(coordinate)
					x, y = Public(x), Public(y)
					if type(x) == "number" and x == x and x >= 0 and x <= 1
						and type(y) == "number" and y == y and y >= 0 and y <= 1
						and (x ~= 0 or y ~= 0) then
						if #result >= limit then truncated = true; return end
						local name
						if type(Public(provider.GetNameForNode)) == "function" then
							name = Public(provider:GetNameForNode(category[1], nodeID))
						end
						if type(name) ~= "string" or #name > 100 or name:find("[%z\1-\31]") then name = nil end
						result[#result + 1] = {
							mapID = mapID, kind = category[2], x = x, y = y, name = name,
							sourceKey = category[2] .. ":" .. tostring(coordinate),
						}
					else invalid = true end
				else invalid = true end
			end
		end
	end)
	if not ok then
		if not self.warnedFailure then
			self.warnedFailure = true
			InfinityUtils:Warning("GatherMate2 source failed: " .. tostring(Public(err) or "protected error"), "Gather")
		end
		return {}, false
	end
	self.warnedFailure = nil
	if invalid and not self.warnedInvalid then
		self.warnedInvalid = true
		InfinityUtils:Warning("Some GatherMate2 positions were invalid or protected and were skipped.", "Gather")
	end
	return result, truncated
end

return Source
