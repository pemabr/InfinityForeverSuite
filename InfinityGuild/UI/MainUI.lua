-- InfinityGuild UI Module
-- Main interface for guild management features

InfinityGuildUI = {}

function InfinityGuildUI:Toggle()
	if not _G.InfinityGuildWindow then
		self:Create()
	else
		if _G.InfinityGuildWindow:IsVisible() then
			_G.InfinityGuildWindow:Hide()
		else
			_G.InfinityGuildWindow:Show()
		end
	end
end

function InfinityGuildUI:Create()
	local frame = InfinityUIFramework:CreateFrame("InfinityGuildWindow", UIParent, 700, 450)
	frame:SetPoint("CENTER", -200, 0)
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame, 
		INFINITY_COLORS.PRIMARY .. "Guild Manager" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOP", 0, -10)
	title:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)
	
	-- Tab buttons
	local tabs = {
		{ name = "Roster", key = "roster" },
		{ name = "DKP", key = "dkp" },
		{ name = "Events", key = "events" },
		{ name = "Raiding", key = "raiding" },
	}
	
	local currentTab = "roster"
	
	for i, tab in ipairs(tabs) do
		local tabBtn = InfinityUIFramework:CreateButton(frame, tab.name, 100, 20, function()
			currentTab = tab.key
			self:ShowTab(frame, tab.key)
		end)
		tabBtn:SetPoint("TOPLEFT", 10 + (i-1) * 110, -35)
	end
	
	-- Content area
	frame.contentArea = CreateFrame("Frame", nil, frame)
	frame.contentArea:SetSize(680, 370)
	frame.contentArea:SetPoint("TOP", 0, -60)
	
	-- Show default tab
	self:ShowTab(frame, "roster")
	
	return frame
end

function InfinityGuildUI:ShowTab(frame, tabName)
	frame.currentTab = tabName
	-- Clear previous content
	InfinityUtils:ClearContainer(frame.contentArea)
	
	if tabName == "roster" then
		self:ShowRosterTab(frame)
	elseif tabName == "dkp" then
		self:ShowDKPTab(frame)
	elseif tabName == "events" then
		self:ShowEventsTab(frame)
	elseif tabName == "raiding" then
		self:ShowRaidingTab(frame)
	end
end

function InfinityGuildUI:ShowRosterTab(frame)
	local view = frame.rosterView
	if not view then
		view = CreateFrame("Frame", nil, frame.contentArea)
		view:SetAllPoints()
		view.title = InfinityUIFramework:CreateLabel(view, "Guild Roster")
		view.title:SetPoint("TOPLEFT", 10, -10)
		view.summary = InfinityUIFramework:CreateLabel(view, "")
		view.summary:SetPoint("TOPLEFT", 10, -32)
		local refresh = InfinityUIFramework:CreateButton(view, "Refresh Roster", 120, 22, function()
			InfinityGuildRoster:RequestRoster()
			InfinityGuildRoster:ScanGuildRoster()
			self:RefreshRoster(frame)
		end)
		refresh:SetPoint("TOPRIGHT", -10, -8)
		local searchLabel = InfinityUIFramework:CreateLabel(view, "Search")
		searchLabel:SetPoint("TOPLEFT", 10, -62)
		view.search = CreateFrame("EditBox", nil, view, "InputBoxTemplate")
		view.search:SetSize(235, 20)
		view.search:SetPoint("TOPLEFT", 70, -57)
		view.search:SetAutoFocus(false)
		view.search:SetScript("OnTextChanged", function() self:RefreshRoster(frame) end)
		local headings = InfinityUIFramework:CreateLabel(view, "Name                         Rank                         Class / Level")
		headings:SetPoint("TOPLEFT", 12, -89)
		view.scroll = InfinityUIFramework:CreateScrollFrame(view, nil, 410, 245)
		view.scroll:SetPoint("TOPLEFT", 10, -110)
		view.scroll.content:SetWidth(390)
		view.empty = InfinityUIFramework:CreateLabel(view, "No roster entries to display.")
		view.empty:SetPoint("TOPLEFT", 15, -115)
		view.rows = {}
		view.detail = InfinityUIFramework:CreateLabel(view, "Select a guild member.")
		view.detail:SetPoint("TOPLEFT", 448, -65)
		view.detail:SetWidth(215)
		view.detail:SetJustifyH("LEFT")
		view.detail:SetWordWrap(true)
		local bags = InfinityUIFramework:CreateButton(view, "Open shared bags", 165, 24, function()
			if not view.selected then
				InfinityUtils:Warning("Select a guild member first.", "InfinityGuild"); return
			end
			local inventory = _G.InfinityInventoryUI
			if not inventory or type(inventory.OpenGuildMember) ~= "function" then
				InfinityUtils:Warning("Guild inventories require Infinity Inventory.", "InfinityGuild"); return
			end
			inventory:OpenGuildMember(view.selected.fullName or view.selected.name)
		end)
		bags:SetPoint("TOPLEFT", 448, -155)
		bags:SetScript("OnEnter", function(button)
			if not _G.GameTooltip then return end
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText("Shared guild bags")
			GameTooltip:AddLine("Only voluntarily shared item counts are shown; they may be outdated.", 1, 1, 1, true)
			GameTooltip:Show()
		end)
		bags:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
		view.bags = bags
		frame.rosterView = view
	end
	view:Show()
	self:RefreshRoster(frame)
end

local function RosterValue(value)
	if _G.issecretvalue and issecretvalue(value) then return nil end
	return value
end

function InfinityGuildUI:RefreshRoster(frame)
	local view = frame.rosterView
	if not view then return end
	local guildName = RosterValue(GetGuildInfo("player"))
	local guild = type(guildName) == "string" and InfinityGuildRoster.guilds[guildName]
	local members = guild and InfinityGuildRoster:GetGuildMembers(guildName) or {}
	local query = RosterValue(view.search:GetText())
	query = type(query) == "string" and query:lower():match("^%s*(.-)%s*$") or ""
	local valid, online, selected = {}, 0, nil
	for _, member in ipairs(members) do
		local name = RosterValue(member.name)
		if type(name) == "string" and name ~= "" then
			local rank, class, fullName = RosterValue(member.rank), RosterValue(member.class), RosterValue(member.fullName)
			local level, active = RosterValue(member.level), RosterValue(member.active)
			local item = {
				name = name, fullName = type(fullName) == "string" and fullName or nil,
				rank = type(rank) == "string" and rank or "",
				class = type(class) == "string" and class or "",
				level = type(level) == "number" and level or nil, active = active == true,
			}
			if item.active then online = online + 1 end
			if view.selected and (item.fullName or item.name) == (view.selected.fullName or view.selected.name) then
				selected = item
			end
			if (item.name .. " " .. item.rank .. " " .. item.class):lower():find(query, 1, true) then
				valid[#valid + 1] = item
			end
		end
	end
	table.sort(valid, function(a, b) return a.name:lower() < b.name:lower() end)
	view.selected = selected
	if guild then
		view.summary:SetText(guildName .. " | " .. #members .. " members | " .. online .. " online")
	elseif type(guildName) == "string" then
		view.summary:SetText("Roster not loaded yet. Click Refresh.")
	else
		view.summary:SetText("You are not in a guild.")
	end
	view.detail:SetText(selected and (selected.name .. "\n" .. selected.rank .. "\n"
		.. selected.class .. " " .. tostring(selected.level or "?") .. "\n"
		.. (selected.active and "Online" or "Offline")) or "Select a guild member.")
	for i, member in ipairs(valid) do
		local row = view.rows[i]
		if not row then
			row = CreateFrame("Button", nil, view.scroll.content)
			row:SetSize(390, 24)
			row:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
			row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			row.name = InfinityUIFramework:CreateLabel(row, "")
			row.name:SetPoint("LEFT", 4, 0)
			row.name:SetWidth(120)
			row.name:SetJustifyH("LEFT")
			row.rank = InfinityUIFramework:CreateLabel(row, "")
			row.rank:SetPoint("LEFT", 125, 0)
			row.rank:SetWidth(120)
			row.rank:SetJustifyH("LEFT")
			row.class = InfinityUIFramework:CreateLabel(row, "")
			row.class:SetPoint("LEFT", 250, 0)
			row:SetScript("OnClick", function(button)
				view.selected = button.member
				self:RefreshRoster(frame)
			end)
			row:SetScript("OnEnter", function(button)
				if not _G.GameTooltip or not button.member then return end
				GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
				GameTooltip:SetText(button.member.fullName or button.member.name)
				GameTooltip:AddLine("Click to select this member.", 1, 1, 1, true)
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
			view.rows[i] = row
		end
		row.member = member
		row.name:SetText((member.active and "|cff33ff33" or "|cff999999") .. member.name .. "|r")
		row.rank:SetText(member.rank)
		row.class:SetText(member.class .. " " .. tostring(member.level or "?"))
		row:Show()
	end
	for i = #valid + 1, #view.rows do view.rows[i]:Hide() end
	if #valid == 0 then view.empty:Show() else view.empty:Hide() end
	view.scroll.content:SetHeight(math.max(1, #valid * 24))
	view.scroll:UpdateScrollChildRect()
end

function InfinityGuildUI:ShowDKPTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "DKP Management" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	local manage = InfinityUIFramework:CreateButton(frame.contentArea, "Manage local guild DKP", 180, 22, function()
		self:ShowLocalDKP()
	end)
	manage:SetPoint("TOPLEFT", 280, y)
	local separate = InfinityUIFramework:CreateButton(frame.contentArea, "InfinityDKP", 110, 22, function()
		local ui = _G.InfinityDKPUI
		if not ui or type(ui.Initialize) ~= "function" then
			InfinityUtils:Warning("InfinityDKP is unavailable.", "InfinityGuild"); return
		end
		ui:Initialize()
		if type(ui.ShowActions) == "function" then ui:ShowActions()
		else InfinityUtils:Warning("InfinityDKP actions are unavailable.", "InfinityGuild") end
	end)
	separate:SetPoint("TOPLEFT", 470, y)
	y = y - 25
	
	-- DKP Standings
	local standingsTitle = InfinityUIFramework:CreateLabel(frame.contentArea, "Local DKP standings (not synchronized):")
	standingsTitle:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	-- Get standings for first guild (if any)
	local standings = {}
	for guildName, _ in pairs(InfinityGuildRoster.guilds) do
		standings = InfinityGuildDKP:GetDKPStandings(guildName)
		break
	end
	
	for i, member in ipairs(standings) do
		if i > 10 then break end
		local text = member.name .. " (" .. member.class .. ") - " .. member.dkp .. " DKP"
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 20, y)
		y = y - 15
	end
	
	y = y - 20
	
	-- Sync status
	local syncStatus = InfinityGuildDKP:GetSyncStatus()
	local statusInfo = {
		"Local changes not synchronized: " .. syncStatus.pendingChanges,
		"Historical Records: " .. syncStatus.historicalRecords,
	}
	
	for _, text in ipairs(statusInfo) do
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 15
	end
	
	y = y - 20
	
end

function InfinityGuildUI:ShowLocalDKP()
	if not _G.InfinityUIFramework or not _G.InfinityGuildDKP or not _G.InfinityGuildRoster then
		InfinityUtils:Warning("Local guild DKP is unavailable.", "InfinityGuild"); return
	end
	if not self.localDKPWindow then
		local frame = InfinityUIFramework:CreateListWindow("InfinityGuildLocalDKP", "Local Guild DKP", 800, 500)
		local function Input(labelText, x, offset, width)
			local label = InfinityUIFramework:CreateLabel(frame, labelText)
			label:SetPoint("TOPLEFT", x, -43)
			local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			input:SetSize(width, 20)
			input:SetPoint("TOPLEFT", x + offset, -38)
			input:SetAutoFocus(false)
			input:SetMaxLetters(80)
			input:SetText("")
			return input
		end
		self.localDKPPlayer = Input("Player", 15, 50, 140)
		self.localDKPAmount = Input("Points", 225, 50, 80)
		self.localDKPReason = Input("Reason", 375, 55, 190)
		self.localDKPWindow = frame
	end
	self.confirmLocalDKP = nil
	self.localDKPOffset = 0
	self:RefreshLocalDKP()
	self.localDKPWindow:Show()
end

function InfinityGuildUI:RefreshLocalDKP()
	local frame, dkp, roster = self.localDKPWindow, _G.InfinityGuildDKP, _G.InfinityGuildRoster
	if not frame or not dkp or not roster then
		InfinityUtils:Warning("Local guild DKP is unavailable.", "InfinityGuild"); return
	end
	local rows = {}
	for _, spec in ipairs({ { "Award", "AwardDKP" }, { "Spend", "SpendDKP" }, { "Reset balance to", "ResetMemberDKP" } }) do
		local label, method = spec[1], spec[2]
		rows[#rows + 1] = { text = label .. " | Player, Points, optional Reason | confirm twice", onClick = function()
			local player, raw, reason = self.localDKPPlayer:GetText(), self.localDKPAmount:GetText(), self.localDKPReason:GetText()
			if _G.issecretvalue and (issecretvalue(player) or issecretvalue(raw) or issecretvalue(reason)) then
				self.confirmLocalDKP = nil
				InfinityUtils:Warning("Protected local DKP input.", "InfinityGuild"); return
			end
			if type(player) ~= "string" or type(raw) ~= "string" or type(reason) ~= "string" then
				self.confirmLocalDKP = nil
				InfinityUtils:Warning("Local DKP input unavailable.", "InfinityGuild"); return
			end
			player, reason = player:match("^%s*(.-)%s*$"), reason:match("^%s*(.-)%s*$")
			local amount = tonumber(raw)
			if player == "" or type(amount) ~= "number" or amount ~= amount or amount > 1000000000
				or amount < (method == "ResetMemberDKP" and 0 or 1) or amount ~= math.floor(amount) then
				self.confirmLocalDKP = nil
				InfinityUtils:Warning("Enter a player and a valid whole DKP amount.", "InfinityGuild"); return
			end
			local member = roster:GetMember(player)
			if _G.issecretvalue and issecretvalue(member) then member = nil end
			local balance = type(member) == "table" and member.dkpBalance
			if _G.issecretvalue and issecretvalue(balance) then balance = nil; member = nil end
			if type(member) ~= "table" or (balance ~= nil and
				(type(balance) ~= "number" or balance ~= balance or math.abs(balance) > 1000000000)) then
				self.confirmLocalDKP = nil
				InfinityUtils:Warning("Local guild member or balance unavailable.", "InfinityGuild"); return
			end
			local pending = self.confirmLocalDKP
			if not pending or pending.method ~= method or pending.name ~= player or pending.amount ~= amount
				or pending.reason ~= reason or pending.member ~= member or pending.balance ~= balance then
				self.confirmLocalDKP = { method = method, name = player, amount = amount, reason = reason,
					member = member, balance = balance }
				frame.status:SetText("Confirm " .. label .. " " .. amount .. " for " .. player .. ". Click again.")
				return
			end
			self.confirmLocalDKP = nil
			local result = dkp[method](dkp, player, amount, reason ~= "" and reason or nil)
			if result then self.localDKPOffset = 0 end
			self:RefreshLocalDKP()
			frame.status:SetText(result and "Local guild DKP saved; not synchronized." or "Not changed; see warning.")
			local main = _G.InfinityGuildWindow
			if main and main:IsShown() and main.currentTab == "dkp" then self:ShowTab(main, "dkp") end
		end }
	end
	rows[#rows + 1] = { text = "These balances are separate from InfinityDKP and cannot be synced." }
	rows[#rows + 1] = { text = "Show newer history", onClick = function()
		self.confirmLocalDKP = nil
		self.localDKPOffset = math.max(0, self.localDKPOffset - 200)
		self:RefreshLocalDKP()
	end }
	rows[#rows + 1] = { text = "Show older history", onClick = function()
		self.confirmLocalDKP = nil
		if self.localDKPOffset + 200 < #dkp.syncHistory then self.localDKPOffset = self.localDKPOffset + 200 end
		self:RefreshLocalDKP()
	end }
	local start = math.max(1, #dkp.syncHistory - self.localDKPOffset)
	local unreadable = 0
	for i = start, math.max(1, start - 199), -1 do
		local record = dkp.syncHistory[i]
		if not (_G.issecretvalue and issecretvalue(record)) and type(record) == "table" then
			local name, amount, reason = record.member, record.amount, record.reason
			if not (_G.issecretvalue and (issecretvalue(name) or issecretvalue(amount) or issecretvalue(reason)))
				and type(name) == "string" and type(amount) == "number" and amount == amount
				and math.abs(amount) < math.huge and type(reason) == "string" then
				rows[#rows + 1] = { text = name .. " | " .. amount .. " DKP | " .. reason }
			else
				unreadable = unreadable + 1
			end
		elseif (_G.issecretvalue and issecretvalue(record)) or record ~= nil then
			unreadable = unreadable + 1
		end
	end
	frame:SetItems(rows)
	frame.status:SetText("Local history page " .. (self.localDKPOffset / 200 + 1) .. "; no guild sync or item transfer."
		.. (unreadable > 0 and (" Unreadable: " .. unreadable) or ""))
end

function InfinityGuildUI:ShowEventsTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Guild Events" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Upcoming events
	local upcomingTitle = InfinityUIFramework:CreateLabel(frame.contentArea, "Upcoming Events:")
	upcomingTitle:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	local events = InfinityGuildEvents:GetUpcomingEvents(7)
	
	if #events == 0 then
		local noEventsLabel = InfinityUIFramework:CreateLabel(frame.contentArea, "No upcoming events")
		noEventsLabel:SetPoint("TOPLEFT", 20, y)
		y = y - 20
	else
		for i, event in ipairs(events) do
			if i > 8 then break end
			local text = event.name .. " (" .. event.type .. ")"
			local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
			label:SetPoint("TOPLEFT", 20, y)
			y = y - 15
		end
	end
	
	y = y - 20
	
	-- Action buttons
	local newEventBtn = InfinityUIFramework:CreateButton(frame.contentArea, "New Event", 100, 25, function()
		self:ShowEventManager()
	end)
	newEventBtn:SetPoint("TOPRIGHT", -10, -10)
end

function InfinityGuildUI:ShowRaidingTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Raid Management" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Active raids
	local activeRaids = InfinityGuildEvents:GetActiveRaids()
	
	if #activeRaids == 0 then
		local noRaidsLabel = InfinityUIFramework:CreateLabel(frame.contentArea, "No active raids")
		noRaidsLabel:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	else
		for i, raid in ipairs(activeRaids) do
			if i > 5 then break end
			local raidLabel = InfinityUIFramework:CreateLabel(frame.contentArea, 
				INFINITY_COLORS.SECONDARY .. raid.name .. INFINITY_COLORS.RESET .. " (" .. raid.type .. ")")
			raidLabel:SetPoint("TOPLEFT", 10, y)
			y = y - 20
			
			local stats = InfinityGuildEvents:GetRaidStats(raid.id)
			local info = {
				"Participants: " .. stats.participantCount,
				"Bosses: " .. stats.bossesFelled,
				"Loot: " .. stats.lootCount,
			}
			
			for _, text in ipairs(info) do
				local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
				label:SetPoint("TOPLEFT", 20, y)
				y = y - 15
			end
			
			y = y - 10
		end
	end
	
	y = y - 20
	
	-- Create raid button
	local newRaidBtn = InfinityUIFramework:CreateButton(frame.contentArea, "New Raid", 100, 25, function()
		self:ShowEventManager()
	end)
	newRaidBtn:SetPoint("TOPRIGHT", -10, -10)
end

function InfinityGuildUI:ShowEventManager()
	if not self.eventManager then
		local frame = InfinityUIFramework:CreateListWindow("InfinityGuildEventManager", "Local Guild Events and Raids", 850, 520)
		local fields = {
			{ "name", "Name", 10, 40, 145 },
			{ "value", "Minutes / DKP", 205, 100, 75 },
			{ "kind", "Type / role", 395, 75, 90 },
			{ "player", "Player", 575, 50, 105 },
			{ "detail", "Detail", 690, 45, 100 },
		}
		self.eventFields = {}
		for _, field in ipairs(fields) do
			local label = InfinityUIFramework:CreateLabel(frame, field[2])
			label:SetPoint("TOPLEFT", field[3], -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(field[5], 20)
			box:SetPoint("TOPLEFT", field[3] + field[4], -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(100)
			self.eventFields[field[1]] = box
		end
		self.eventManager = frame
	end
	self.confirmGuildAction = nil
	self:RefreshEventManager()
	self.eventManager:Show()
end

function InfinityGuildUI:RefreshEventManager()
	local frame, events = self.eventManager, _G.InfinityGuildEvents
	if not frame or not events then InfinityUtils:Warning("Guild event manager unavailable.", "InfinityGuild"); return end
	local function Input(key)
		local value = self.eventFields[key]:GetText()
		if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
		if type(value) ~= "string" then InfinityUtils:Warning("Event input unavailable or protected.", "InfinityGuild"); return nil end
		value = value:match("^%s*(.-)%s*$")
		if value:find("[%c]") then InfinityUtils:Warning("Event input contains control characters.", "InfinityGuild"); return nil end
		return value
	end
	local function Confirm(label, fields, raid, callback)
		local signature = table.concat(fields, "\001")
		local pending = self.confirmGuildAction
		local participantsMatch = true
		if raid and pending and pending.participants then
			for name, participant in pairs(raid.participants) do
				local previous = pending.participants[name]
				if not previous or previous.entry ~= participant or previous.role ~= participant.role
					or previous.active ~= participant.active then participantsMatch = false; break end
			end
			for name in pairs(pending.participants) do
				if not raid.participants[name] then participantsMatch = false; break end
			end
		end
		if not pending or pending.label ~= label or pending.signature ~= signature
			or pending.raid ~= raid or (raid and (pending.status ~= raid.status
				or pending.bosses ~= #raid.bosses or pending.loot ~= #raid.lootDistributed or not participantsMatch)) then
			self.confirmGuildAction = { label = label, signature = signature, raid = raid,
				status = raid and raid.status, bosses = raid and #raid.bosses, loot = raid and #raid.lootDistributed }
			if raid then
				self.confirmGuildAction.participants = {}
				for name, participant in pairs(raid.participants) do
					self.confirmGuildAction.participants[name] = { entry = participant, role = participant.role, active = participant.active }
				end
			end
			frame.status:SetText(label .. "? Click again to confirm.")
			return
		end
		self.confirmGuildAction = nil
		if not callback() then InfinityUtils:Warning("Local guild action failed.", "InfinityGuild") end
		self:RefreshEventManager()
		local main = _G.InfinityGuildWindow
		if main and (main.currentTab == "events" or main.currentTab == "raiding") then
			self:ShowTab(main, main.currentTab)
		end
	end
	local function Selected()
		local raid = self.selectedGuildRaid and events:GetRaid(self.selectedGuildRaid)
		if not raid then InfinityUtils:Warning("Select a local raid below.", "InfinityGuild") end
		return raid
	end
	local rows = {
		{ text = "Create local event | Name, Minutes from now, Type; optional Detail", onClick = function()
			local name, raw, kind, detail = Input("name"), Input("value"), Input("kind"), Input("detail")
			if not name or not raw or not kind or not detail then return end
			local minutes = tonumber(raw)
			if name == "" or kind == "" or not minutes or minutes ~= minutes or minutes < 1 or minutes > 5256000 then
				InfinityUtils:Warning("Enter event name, type and 1-5256000 minutes.", "InfinityGuild"); return
			end
			Confirm("Create local event", { name, raw, kind, detail }, nil, function()
				return events:CreateEvent(name, kind, InfinityUtils:GetTimeStamp() + minutes * 60, detail)
			end)
		end },
		{ text = "Create local planned raid | Name, Type; optional Detail = difficulty", onClick = function()
			local name, kind, detail = Input("name"), Input("kind"), Input("detail")
			if not name or not kind or not detail then return end
			if name == "" or kind == "" then InfinityUtils:Warning("Enter raid name and type.", "InfinityGuild"); return end
			Confirm("Create local raid", { name, kind, detail }, nil, function()
				local raid = events:CreateRaid(name, kind, detail ~= "" and detail or "Normal")
				if raid then self.selectedGuildRaid = raid.id end
				return raid
			end)
		end },
		{ text = "Start selected planned raid", onClick = function()
			local raid = Selected()
			if not raid then return end
			if raid.status ~= "planned" then InfinityUtils:Warning("Raid is not planned.", "InfinityGuild"); return end
			Confirm("Start " .. raid.name, {}, raid, function() return events:StartRaid(raid.id) end)
		end },
		{ text = "Complete selected active raid", onClick = function()
			local raid = Selected()
			if not raid then return end
			if raid.status ~= "active" then InfinityUtils:Warning("Raid is not active.", "InfinityGuild"); return end
			Confirm("Complete " .. raid.name, {}, raid, function() return events:CompleteRaid(raid.id) end)
		end },
		{ text = "Add participant | selected raid, Player, optional Type / role", onClick = function()
			local raid, player, role = Selected(), Input("player"), Input("kind")
			if not raid or not player or not role then return end
			if player == "" or raid.participants[player] then InfinityUtils:Warning("Enter a new participant.", "InfinityGuild"); return end
			Confirm("Add participant to " .. raid.name, { player, role }, raid, function()
				if raid.participants[player] then return false end
				return events:AddRaidParticipant(raid.id, player, role ~= "" and role or "DPS")
			end)
		end },
		{ text = "Record boss kill | selected raid, Name", onClick = function()
			local raid, name = Selected(), Input("name")
			if not raid or not name then return end
			if name == "" or raid.status ~= "active" then InfinityUtils:Warning("Select an active raid and enter a boss name.", "InfinityGuild"); return end
			Confirm("Record boss kill for " .. raid.name, { name }, raid, function() return events:RecordBossKill(raid.id, name) end)
		end },
		{ text = "Record loot | selected raid, Name=item, Player, Detail=boss, Minutes / DKP", onClick = function()
			local raid, name, player, boss, raw = Selected(), Input("name"), Input("player"), Input("detail"), Input("value")
			if not raid or not name or not player or not boss or not raw then return end
			local amount = tonumber(raw)
			if raid.status ~= "active" or name == "" or player == "" or boss == ""
				or not amount or amount ~= amount or amount < 0 or amount >= math.huge then
				InfinityUtils:Warning("Enter an active raid, item, winner, boss and non-negative DKP.", "InfinityGuild"); return
			end
			Confirm("Record loot for " .. raid.name, { name, player, boss, raw }, raid, function()
				return events:RecordLootDrop(raid.id, name, boss, player, amount)
			end)
		end },
	}
	local raids = {}
	for _, raid in pairs(events.raids) do raids[#raids + 1] = raid end
	table.sort(raids, function(a, b) return a.id < b.id end)
	for _, entry in ipairs(raids) do
		local raid = entry
		rows[#rows + 1] = { text = (self.selectedGuildRaid == raid.id and "[Selected] " or "")
			.. raid.id .. " | " .. raid.name .. " | " .. raid.status, onClick = function()
				self.confirmGuildAction = nil
				self.selectedGuildRaid = raid.id
				self:RefreshEventManager()
			end }
	end
	local selected = self.selectedGuildRaid and events:GetRaid(self.selectedGuildRaid)
	if selected then
		rows[#rows + 1] = { text = "Selected raid: " .. selected.name .. " | " .. selected.type
			.. " | " .. selected.difficulty .. " | " .. selected.status }
		local participants = {}
		for name, participant in pairs(selected.participants) do
			participants[#participants + 1] = name .. " | " .. participant.role
		end
		table.sort(participants)
		for _, participant in ipairs(participants) do rows[#rows + 1] = { text = "Participant: " .. participant } end
		for _, boss in ipairs(selected.bosses) do rows[#rows + 1] = { text = "Boss: " .. boss.boss } end
		for _, loot in ipairs(selected.lootDistributed) do
			rows[#rows + 1] = { text = "Loot: " .. loot.item .. " | " .. loot.winner .. " | "
				.. loot.boss .. " | " .. tostring(loot.dkpSpent) .. " DKP" }
		end
	end
	local upcoming = events:GetUpcomingEvents(3650)
	for index = 1, math.min(200, #upcoming) do
		local event = upcoming[index]
		rows[#rows + 1] = { text = "Event " .. event.id .. " | " .. event.name .. " | "
			.. event.type .. " | " .. date("%Y-%m-%d %H:%M", event.scheduledDate)
			.. (event.description ~= "" and " | " .. event.description or "") }
	end
	if #upcoming > 200 then rows[#rows + 1] = { text = "Only the first 200 upcoming events are shown." } end
	frame:SetItems(rows)
	frame.status:SetText("Local records only; not shared or added to Blizzard Calendar. Select a raid below.")
end

return InfinityGuildUI

