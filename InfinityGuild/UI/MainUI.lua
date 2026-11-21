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
	title:SetFont("Fonts/FRIZQT__.TTF", 14)
	
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
	-- Clear previous content
	for i = 1, frame.contentArea:GetNumChildren() do
		frame.contentArea:GetChild(i):Hide()
	end
	
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
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Guild Roster" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Guild selector
	local guilds = InfinityGuildRoster.guilds
	for guildName, guild in pairs(guilds) do
		local guildLabel = InfinityUIFramework:CreateLabel(frame.contentArea, 
			INFINITY_COLORS.SECONDARY .. guildName .. INFINITY_COLORS.RESET .. " (Level " .. guild.level .. ")")
		guildLabel:SetPoint("TOPLEFT", 10, y)
		y = y - 20
		
		local stats = InfinityGuildRoster:GetGuildStats(guildName)
		local info = {
			"Members: " .. stats.memberCount .. " (" .. stats.activeMembers .. " active)",
			"Avg Level: " .. string.format("%.1f", stats.averageLevel),
			"Treasury: " .. InfinityUtils:FormatGold(stats.treasury),
		}
		
		for _, text in ipairs(info) do
			local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
			label:SetPoint("TOPLEFT", 20, y)
			y = y - 15
		end
		
		y = y - 10
	end
	
	-- Action buttons
	y = y - 20
	local newGuildBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Register Guild", 120, 25, function()
		local guild = InfinityGuildRoster:RegisterGuild("My Guild", "MG", 1)
		InfinityUtils:Info("Guild registered: My Guild", "InfinityGuild")
	end)
	newGuildBtn:SetPoint("TOPLEFT", 10, y)
	
	local syncBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Sync Roster", 100, 25, function()
		InfinityUtils:Info("Roster synced with server", "InfinityGuild")
	end)
	syncBtn:SetPoint("TOPLEFT", 140, y)
end

function InfinityGuildUI:ShowDKPTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "DKP Management" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- DKP Standings
	local standingsTitle = InfinityUIFramework:CreateLabel(frame.contentArea, "DKP Standings:")
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
		"Pending Changes: " .. syncStatus.pendingChanges,
		"Historical Records: " .. syncStatus.historicalRecords,
	}
	
	for _, text in ipairs(statusInfo) do
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 15
	end
	
	y = y - 20
	
	-- Sync button
	local syncBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Sync DKP", 100, 25, function()
		InfinityGuildDKP:SyncDKPWithGuild()
		InfinityUtils:Info("DKP synced with guild", "InfinityGuild")
	end)
	syncBtn:SetPoint("TOPLEFT", 10, y)
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
		InfinityGuildEvents:CreateEvent("Guild Meeting", "social", InfinityUtils:GetTimeStamp() + 86400)
		InfinityUtils:Info("Event created", "InfinityGuild")
	end)
	newEventBtn:SetPoint("TOPLEFT", 10, y)
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
		InfinityGuildEvents:CreateRaid("Guild Raid", "RAID", "Normal")
		InfinityUtils:Info("Raid created", "InfinityGuild")
	end)
	newRaidBtn:SetPoint("TOPLEFT", 10, y)
end

return InfinityGuildUI

