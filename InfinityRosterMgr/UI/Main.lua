local UI = {}
_G.InfinityRosterMgrUI = UI

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

function UI:Refresh(scan)
	if not self.frame then return end
	local roster = _G.InfinityRosterManager
	if not roster then InfinityUtils:Warning("Roster manager unavailable.", "Roster"); return end
	if scan and not roster:ScanGuild() then
		self.frame:SetItems({})
		self.frame.status:SetText(roster.scanError or "Roster unavailable.")
		return
	end
	if roster.scanError then
		self.frame:SetItems({})
		self.frame.status:SetText(roster.scanError)
		return
	end
	local filter = Public(self.filter:GetText())
	if type(filter) ~= "string" then InfinityUtils:Warning("Roster filter unavailable.", "Roster"); return end
	filter = filter:lower():match("^%s*(.-)%s*$")
	local rows, count, online = {}, 0, 0
	for _, member in pairs(roster.members) do
		local name, rank, class, zone = Public(member.name), Public(member.rank), Public(member.classFileName), Public(member.zone)
		if type(name) == "string" and type(rank) == "string" and type(class) == "string" and type(zone) == "string" then
			count = count + 1
			if member.isOnline then online = online + 1 end
			local search = (name .. " " .. rank .. " " .. class .. " " .. zone):lower()
			if (not self.onlineOnly or member.isOnline) and search:find(filter, 1, true) then
				rows[#rows + 1] = { text = name .. " | " .. rank .. " | " .. class .. " | " .. zone
					.. (member.isOnline and " | online" or " | offline") }
			end
		end
	end
	table.sort(rows, function(a, b) return a.text < b.text end)
	if #rows == 0 then rows[1] = { text = "No matching roster entries." } end
	self.frame:SetItems(rows)
	self.frame.status:SetText(roster.guildName .. ": " .. count .. " members, " .. online .. " online.")
end

function UI:Toggle()
	if not self.frame then
		self.frame = InfinityUIFramework:CreateListWindow("InfinityRosterMgrWindow", "Guild Roster Manager", 700, 500)
		local label = InfinityUIFramework:CreateLabel(self.frame, "Filter")
		label:SetPoint("TOPLEFT", 15, -43)
		self.filter = CreateFrame("EditBox", nil, self.frame, "InputBoxTemplate")
		self.filter:SetSize(170, 20)
		self.filter:SetPoint("TOPLEFT", 65, -38)
		self.filter:SetAutoFocus(false)
		self.filter:SetMaxLetters(80)
		local search = InfinityUIFramework:CreateButton(self.frame, "Search", 80, 22, function() self:Refresh() end)
		search:SetPoint("LEFT", self.filter, "RIGHT", 10, 0)
		local online = InfinityUIFramework:CreateButton(self.frame, "Online only", 100, 22, function()
			self.onlineOnly = not self.onlineOnly
			self:Refresh()
		end)
		online:SetPoint("LEFT", search, "RIGHT", 5, 0)
		local scan = InfinityUIFramework:CreateButton(self.frame, "Rescan", 80, 22, function() self:Refresh(true) end)
		scan:SetPoint("LEFT", online, "RIGHT", 5, 0)
	end
	if self.frame:IsShown() then self.frame:Hide() else self:Refresh(true); self.frame:Show() end
end

return UI
