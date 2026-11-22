InfinityRaidUI = { encounter = nil }

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Text(value, fallback)
	value = Public(value)
	if type(value) == "string" or type(value) == "number" then return tostring(value) end
	return fallback
end

function InfinityRaidUI:Initialize()
	if self.eventFrame then return end
	local events = CreateFrame("Frame")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:RegisterEvent("ENCOUNTER_START")
	events:RegisterEvent("ENCOUNTER_END")
	events:SetScript("OnEvent", function(_, event, _, name, _, _, success)
		if event == "ENCOUNTER_START" then
			InfinityRaidUI.encounter = { name = Text(name, "Encounter"), result = "In progress" }
		elseif event == "ENCOUNTER_END" then
			local result = Public(success)
			InfinityRaidUI.encounter = {
				name = Text(name, "Encounter"),
				result = result == 1 and "Defeated" or (result == 0 and "Ended without a kill" or "Ended"),
			}
		end
		if InfinityRaidUI.frame and InfinityRaidUI.frame:IsShown() then
			InfinityRaidUI:Refresh()
		end
	end)
	self.eventFrame = events
end

function InfinityRaidUI:Refresh()
	if not self.frame then return end
	local items = {}
	if self.encounter then
		items[#items + 1] = { text = self.encounter.name .. ": " .. self.encounter.result }
	else
		items[#items + 1] = { text = "No encounter event received this session." }
	end
	items[#items + 1] = { text = "Group roster:" }
	if not IsInRaid or not GetNumGroupMembers then
		self.frame.status:SetText("Group roster API unavailable.")
		self.frame:SetItems(items)
		return
	end
	local count = Public(GetNumGroupMembers())
	if type(count) ~= "number" then count = 0 end
	local raid = Public(IsInRaid())
	if raid == nil then
		self.frame.status:SetText("Group state unavailable.")
		self.frame:SetItems(items)
		return
	elseif raid and GetRaidRosterInfo then
		for i = 1, count do
			local name, _, group, level, _, class, _, online = GetRaidRosterInfo(i)
			name, group, level, class, online = Public(name), Public(group), Public(level), Public(class), Public(online)
			if type(name) == "string" then
				items[#items + 1] = { text = string.format("Group %s | %s | %s %s | %s",
					Text(group, "?"), name, Text(level, "?"), Text(class, "?"),
					online == nil and "Unknown" or (online and "Online" or "Offline")) }
			end
		end
	elseif not raid then
		local units = { "player" }
		for i = 1, math.max(0, count - 1) do units[#units + 1] = "party" .. i end
		for _, unit in ipairs(units) do
			local name = UnitName and Public(UnitName(unit))
			if type(name) == "string" then
				local role = UnitGroupRolesAssigned and Text(UnitGroupRolesAssigned(unit), "NONE") or "NONE"
				items[#items + 1] = { text = name .. " | " .. role }
			end
		end
	else
		self.frame.status:SetText("Raid roster API unavailable.")
		self.frame:SetItems(items)
		return
	end
	self.frame.status:SetText("Live roster and encounter events; no boss timers.")
	self.frame:SetItems(items)
end

function InfinityRaidUI:Toggle()
	if not self.frame then
		self.frame = InfinityUIFramework:CreateListWindow("InfinityRaidWindow", "Raid Overview", 600, 500)
	end
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Refresh()
		self.frame:Show()
	end
end
