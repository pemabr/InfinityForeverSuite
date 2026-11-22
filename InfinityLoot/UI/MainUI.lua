-- InfinityLoot UI Module
-- Main interface for loot management features

InfinityLootUI = {}

function InfinityLootUI:Toggle()
	if not _G.InfinityLootWindow then
		self:Create()
	else
		if _G.InfinityLootWindow:IsVisible() then
			_G.InfinityLootWindow:Hide()
		else
			_G.InfinityLootWindow:Show()
		end
	end
end

function InfinityLootUI:Create()
	local frame = InfinityUIFramework:CreateFrame("InfinityLootWindow", UIParent, 600, 400)
	frame:SetPoint("CENTER", 200, 0)
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame, 
		INFINITY_COLORS.PRIMARY .. "Loot Manager" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOP", 0, -10)
	title:SetFont("Fonts/FRIZQT__.TTF", 14, "")
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)
	
	-- Tab buttons for DKP, Tracking, Economy, Commissions
	local tabs = {
		{ name = "DKP Manager", key = "dkp" },
		{ name = "Loot Tracker", key = "tracking" },
		{ name = "Economy", key = "economy" },
		{ name = "Commissions", key = "commissions" },
	}
	
	local currentTab = "dkp"
	
	for i, tab in ipairs(tabs) do
		local tabBtn = InfinityUIFramework:CreateButton(frame, tab.name, 100, 20, function()
			currentTab = tab.key
			self:ShowTab(frame, tab.key)
		end)
		tabBtn:SetPoint("TOPLEFT", 10 + (i-1) * 110, -35)
	end
	
	-- Content area
	frame.contentArea = CreateFrame("Frame", nil, frame)
	frame.contentArea:SetSize(580, 320)
	frame.contentArea:SetPoint("TOP", 0, -60)
	
	-- Show default tab
	self:ShowTab(frame, "dkp")
	
	return frame
end

function InfinityLootUI:ShowTab(frame, tabName)
	frame.currentTab = tabName
	-- Clear previous content
	InfinityUtils:ClearContainer(frame.contentArea)
	
	if tabName == "dkp" then
		self:ShowDKPTab(frame)
	elseif tabName == "tracking" then
		self:ShowTrackingTab(frame)
	elseif tabName == "economy" then
		self:ShowEconomyTab(frame)
	elseif tabName == "commissions" then
		self:ShowCommissionsTab(frame)
	end
end

function InfinityLootUI:ShowDKPTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "DKP Management" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Stats
	local stats = InfinityLootManager:GetStatistics()
	local info = {
		"Active Raids: " .. stats.totalRaids,
		"Members: " .. stats.totalMembers,
		"Loot Awarded: " .. stats.totalLootAwarded,
		"Total DKP Spent: " .. stats.totalDkpSpent,
	}
	
	for _, text in ipairs(info) do
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
	
	-- Action buttons
	y = y - 20
	local newRaidBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Raid manager", 100, 25, function()
		self:ShowRaidManager()
	end)
	newRaidBtn:SetPoint("TOPLEFT", 10, y)
	local decay = InfinityUIFramework:CreateButton(frame.contentArea, "Decay / awards", 130, 25, function()
		self:ShowDecay()
	end)
	decay:SetPoint("LEFT", newRaidBtn, "RIGHT", 8, 0)
	local auctions = InfinityUIFramework:CreateButton(frame.contentArea, "Loot auctions", 110, 25, function()
		if not _G.InfinityLootAuctionUI then InfinityUtils:Warning("Loot auctions unavailable.", "InfinityLoot"); return end
		InfinityLootAuctionUI:ShowAuctionFrame()
	end)
	auctions:SetPoint("LEFT", decay, "RIGHT", 8, 0)
	local standings = InfinityUIFramework:CreateButton(frame.contentArea, "Loot standings", 120, 25, function()
		if not _G.InfinityLootDKPUI then InfinityUtils:Warning("Loot standings unavailable.", "InfinityLoot"); return end
		InfinityLootDKPUI:ToggleWindow()
	end)
	standings:SetPoint("LEFT", auctions, "RIGHT", 8, 0)
	local audit = InfinityUIFramework:CreateButton(frame.contentArea, "Point audit", 110, 25, function()
		self:ShowPointAudit()
	end)
	audit:SetPoint("TOPLEFT", newRaidBtn, "BOTTOMLEFT", 0, -8)
	local history = InfinityUIFramework:CreateButton(frame.contentArea, "Loot history", 110, 25, function()
		self:ShowAwardHistory()
	end)
	history:SetPoint("LEFT", audit, "RIGHT", 8, 0)
	local tax = InfinityUIFramework:CreateButton(frame.contentArea, "Tax settings", 110, 25, function()
		self:ShowTaxSettings()
	end)
	tax:SetPoint("LEFT", history, "RIGHT", 8, 0)
	local trade = InfinityUIFramework:CreateButton(frame.contentArea, "Guild DKP trade", 125, 25, function()
		local dkp = _G.InfinityDKPUI
		if not dkp or type(dkp.Initialize) ~= "function" then
			InfinityUtils:Warning("InfinityDKP trade controls unavailable.", "InfinityLoot"); return
		end
		dkp:Initialize()
		if type(dkp.ShowActions) ~= "function" then InfinityUtils:Warning("InfinityDKP trade controls unavailable.", "InfinityLoot"); return end
		dkp:ShowActions()
	end)
	trade:SetPoint("LEFT", tax, "RIGHT", 8, 0)
end

function InfinityLootUI:ShowRaidManager()
	local manager = _G.InfinityLootManager
	if not manager or type(manager.db.raids) ~= "table" then
		InfinityUtils:Warning("Local loot raid manager unavailable.", "InfinityLoot"); return
	end
	if not self.raidManagerFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootRaidManager", "Local Loot Raids", 800, 520)
		local function Input(title, x, offset, width)
			local label = InfinityUIFramework:CreateLabel(frame, title)
			label:SetPoint("TOPLEFT", x, -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(width, 20)
			box:SetPoint("TOPLEFT", x + offset, -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(160)
			return box
		end
		self.raidName = Input("Raid / item", 10, 78, 155)
		self.raidPlayer = Input("Player", 255, 50, 105)
		self.raidAmount = Input("DKP", 425, 35, 75)
		self.raidRole = Input("Role", 555, 35, 110)
		self.raidManagerFrame = frame
	end
	self.confirmLootRaid = nil
	self:RefreshRaidManager()
	self.raidManagerFrame:Show()
end

function InfinityLootUI:RefreshRaidManager()
	local frame, manager = self.raidManagerFrame, InfinityLootManager
	local function Input(box)
		local value = box:GetText()
		if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
		if type(value) ~= "string" then InfinityUtils:Warning("Raid input unavailable or protected.", "InfinityLoot"); return nil end
		value = value:match("^%s*(.-)%s*$")
		if value:find("[%c]") then InfinityUtils:Warning("Raid input contains control characters.", "InfinityLoot"); return nil end
		return value
	end
	local function Selected()
		local raid = self.selectedLootRaid and manager.db.raids[self.selectedLootRaid]
		if not raid then InfinityUtils:Warning("Select a local loot raid below.", "InfinityLoot") end
		return raid
	end
	local function Confirm(label, signature, raid, member, callback)
		local pending = self.confirmLootRaid
		if not pending or pending.label ~= label or pending.signature ~= signature or pending.raid ~= raid
			or pending.member ~= member or (member and pending.dkp ~= member.dkp)
			or (raid and pending.lootCount ~= #raid.lootAwarded) then
			self.confirmLootRaid = { label = label, signature = signature, raid = raid,
				member = member, dkp = member and member.dkp, lootCount = raid and #raid.lootAwarded }
			frame.status:SetText(label .. "? Click again to confirm.")
			return
		end
		self.confirmLootRaid = nil
		if not callback() then InfinityUtils:Warning("Local loot raid action failed.", "InfinityLoot") end
		self:RefreshRaidManager()
		local main = _G.InfinityLootWindow
		if main and main.currentTab == "dkp" then self:ShowTab(main, "dkp") end
	end
	local rows = {
		{ text = "Create local raid | Raid / item = raid name", onClick = function()
			local name = Input(self.raidName)
			if not name then self.confirmLootRaid = nil; return end
			if name == "" then self.confirmLootRaid = nil; InfinityUtils:Warning("Enter a raid name.", "InfinityLoot"); return end
			Confirm("Create " .. name, name, nil, nil, function()
				local id = manager:CreateRaid(name, InfinityUtils:GetTimeStamp())
				self.selectedLootRaid = id
				return id
			end)
		end },
		{ text = "Add member | Player, DKP = starting points, optional Role", onClick = function()
			local raid, player, raw, role = Selected(), Input(self.raidPlayer), Input(self.raidAmount), Input(self.raidRole)
			if not raid or not player or not raw or not role then self.confirmLootRaid = nil; return end
			local amount = tonumber(raw)
			if player == "" or not amount or amount ~= amount or math.abs(amount) >= math.huge then
				self.confirmLootRaid = nil
				InfinityUtils:Warning("Enter player and finite starting DKP.", "InfinityLoot"); return
			end
			if raid.members[player] then self.confirmLootRaid = nil; InfinityUtils:Warning("Raid member already exists.", "InfinityLoot"); return end
			Confirm("Add " .. player .. " to " .. raid.name, player .. "\001" .. raw .. "\001" .. role, raid, nil, function()
				if raid.members[player] then return false end
				return manager:AddRaidMember(raid.id, player, amount, role ~= "" and role or "DPS")
			end)
		end },
		{ text = "Record award | Player, Raid / item = item, DKP = cost", onClick = function()
			local raid, player, item, raw = Selected(), Input(self.raidPlayer), Input(self.raidName), Input(self.raidAmount)
			if not raid or not player or not item or not raw then self.confirmLootRaid = nil; return end
			local cost = tonumber(raw)
			local member = raid.members[player]
			if not member or item == "" or not cost or cost ~= cost or cost < 0 or cost >= math.huge then
				self.confirmLootRaid = nil
				InfinityUtils:Warning("Enter an existing member, item and non-negative finite cost.", "InfinityLoot"); return
			end
			Confirm("Record award for " .. player .. " in " .. raid.name, player .. "\001" .. item .. "\001" .. raw, raid, member, function()
				if raid.members[player] ~= member then return false end
				return manager:AwardLoot(raid.id, player, item, cost)
			end)
		end },
	}
	local raids = {}
	for _, raid in pairs(manager.db.raids) do raids[#raids + 1] = raid end
	table.sort(raids, function(a, b) return a.id < b.id end)
	for _, entry in ipairs(raids) do
		local raid = entry
		rows[#rows + 1] = { text = (self.selectedLootRaid == raid.id and "[Selected] " or "") .. raid.id .. " | " .. raid.name,
			onClick = function() self.selectedLootRaid = raid.id; self.confirmLootRaid = nil; self:RefreshRaidManager() end }
	end
	local selected = self.selectedLootRaid and manager.db.raids[self.selectedLootRaid]
	if selected then
		for _, member in ipairs(manager:GetRaidStandings(selected.id)) do
			rows[#rows + 1] = { text = "Member: " .. member.name .. " | " .. member.role .. " | DKP " .. member.dkp }
		end
		for _, award in ipairs(manager:GetLootHistory(selected.id, 100)) do
			rows[#rows + 1] = { text = "Award: " .. award.memberId .. " | " .. award.itemLink .. " | cost " .. award.dkpCost }
		end
	end
	frame:SetItems(rows)
	frame.status:SetText("Local raid-only balances; separate from Loot EP/GP and InfinityDKP. No item is awarded.")
end

function InfinityLootUI:ShowTaxSettings()
	local tax = _G.InfinityDKPTaxation
	if not tax then InfinityUtils:Warning("Loot tax settings unavailable.", "InfinityLoot"); return end
	if not self.taxFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootTaxSettingsWindow", "Local Loot Tax Settings", 700, 500)
		local label = InfinityUIFramework:CreateLabel(frame, "Rate / item")
		label:SetPoint("TOPLEFT", 15, -43)
		local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		input:SetSize(250, 20)
		input:SetPoint("TOPLEFT", 95, -38)
		input:SetAutoFocus(false)
		input:SetMaxLetters(100)
		self.taxFrame, self.taxInput = frame, input
		local playerLabel = InfinityUIFramework:CreateLabel(frame, "Player")
		playerLabel:SetPoint("TOPLEFT", 360, -43)
		local player = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		player:SetSize(110, 20)
		player:SetPoint("TOPLEFT", 410, -38)
		player:SetAutoFocus(false)
		player:SetMaxLetters(80)
		local goldLabel = InfinityUIFramework:CreateLabel(frame, "Gold")
		goldLabel:SetPoint("TOPLEFT", 550, -43)
		local gold = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		gold:SetSize(80, 20)
		gold:SetPoint("TOPLEFT", 590, -38)
		gold:SetAutoFocus(false)
		gold:SetMaxLetters(16)
		self.taxPlayer, self.taxGold = player, gold
	end
	self.confirmTax = nil
	self:RefreshTaxSettings()
	self.taxFrame:Show()
end

function InfinityLootUI:RefreshTaxSettings()
	local frame, tax = self.taxFrame, _G.InfinityDKPTaxation
	local function Input()
		local value = self.taxInput:GetText()
		if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
		if type(value) ~= "string" then InfinityUtils:Warning("Tax input unavailable or protected.", "InfinityLoot"); return nil end
		value = value:match("^%s*(.-)%s*$")
		if value == "" or value:find("[%c]") then InfinityUtils:Warning("Enter a valid rate or item.", "InfinityLoot"); return nil end
		return value
	end
	local function Confirm(label, value, old, callback)
		local pending = self.confirmTax
		if not pending or pending.label ~= label or pending.value ~= value or pending.old ~= old then
			self.confirmTax = { label = label, value = value, old = old }
			frame.status:SetText(label .. ": " .. tostring(value) .. "? Click again.")
			return
		end
		self.confirmTax = nil
		if not callback() then InfinityUtils:Warning("Tax setting unchanged.", "InfinityLoot") end
		self:RefreshTaxSettings()
	end
	local rows = {}
	for _, spec in ipairs({
		{ "Set tax rate per gold", "taxRatePerGold", "SetTaxRate" },
		{ "Set donation rate per gold", "donationRatePerGold", "SetDonationRate" },
	}) do
		local label, key, method = spec[1], spec[2], spec[3]
		rows[#rows + 1] = { text = label .. " | current: " .. tostring(tax.config[key]), onClick = function()
			local raw = Input()
			local value = raw and tonumber(raw)
			if not value or value ~= value or value < 0 or value >= math.huge then
				self.confirmTax = nil
				InfinityUtils:Warning("Enter a non-negative finite rate.", "InfinityLoot"); return
			end
			Confirm(label, value, tax.config[key], function() return tax[method](tax, value) end)
		end }
	end
	for _, spec in ipairs({
		{ "Add whitelist item", "whitelistedItems", "Whitelist" },
		{ "Remove whitelist item", "whitelistedItems", "RemoveWhitelist" },
		{ "Add blacklist item", "blacklistedItems", "Blacklist" },
		{ "Remove blacklist item", "blacklistedItems", "RemoveBlacklist" },
	}) do
		local label, key, method = spec[1], spec[2], spec[3]
		rows[#rows + 1] = { text = label .. " | Rate / item", onClick = function()
			local item = Input()
			if not item then self.confirmTax = nil; return end
			Confirm(label, item, tax[key][item], function() return tax[method](tax, item) end)
		end }
	end
	for _, spec in ipairs({ { "Whitelist", "enableWhitelist" }, { "Blacklist", "enableBlacklist" } }) do
		local label, key = spec[1], spec[2]
		rows[#rows + 1] = { text = label .. " filtering: " .. (tax.config[key] and "on" or "off"), onClick = function()
			local old = tax.config[key]
			Confirm("Toggle " .. label, not old, old, function()
				tax.config[key] = not old
				tax:_SaveSettings()
				return true
			end)
		end }
	end
	for _, spec in ipairs({ { "Award tax DKP", "tax" }, { "Award donation DKP", "donation" } }) do
		local label, kind = spec[1], spec[2]
		rows[#rows + 1] = { text = label .. " | Player, Gold" .. (kind == "donation" and ", Rate / item = item" or "")
			.. " | local InfinityDKP; confirm twice", onClick = function()
			local player, raw = self.taxPlayer:GetText(), self.taxGold:GetText()
			local item = kind == "donation" and Input() or nil
			if _G.issecretvalue and (issecretvalue(player) or issecretvalue(raw)) then player, raw = nil, nil end
			if type(player) ~= "string" or type(raw) ~= "string" or (kind == "donation" and not item) then
				self.confirmTax = nil
				InfinityUtils:Warning("Tax award input unavailable or protected.", "InfinityLoot"); return
			end
			player = player:match("^%s*(.-)%s*$")
			local gold = tonumber(raw)
			local engine = _G.InfinityDKPEngine
			if player == "" or player:find("[%c]") or not gold or gold ~= gold or gold <= 0 or gold >= math.huge
				or not engine or type(engine.db) ~= "table" or type(engine.players) ~= "table"
				or type(engine.SYSTEM_DKP) ~= "string" or engine.system_type ~= engine.SYSTEM_DKP then
				self.confirmTax = nil
				InfinityUtils:Warning("Enter player and positive gold; initialized InfinityDKP must use DKP mode.", "InfinityLoot"); return
			end
			local target = engine.players[player]
			if _G.issecretvalue and _G.issecretvalue(target) then target = nil end
			if type(target) ~= "table" then self.confirmTax = nil; InfinityUtils:Warning("Add the local DKP player first.", "InfinityLoot"); return end
			local rate = kind == "tax" and tax.config.taxRatePerGold or tax.config.donationRatePerGold
			if _G.issecretvalue and (issecretvalue(rate) or issecretvalue(target.dkp)) then
				self.confirmTax = nil; InfinityUtils:Warning("Tax rate or balance is protected.", "InfinityLoot"); return
			end
			if type(rate) ~= "number" or rate ~= rate or rate < 0 or rate >= math.huge
				or type(target.dkp) ~= "number" then
				self.confirmTax = nil; InfinityUtils:Warning("Tax rate or balance unavailable.", "InfinityLoot"); return
			end
			local award = gold * rate
			if award ~= award or award >= math.huge or award < 1 or award > 1000000000 then
				self.confirmTax = nil; InfinityUtils:Warning("Calculated DKP must be between 1 and 1000000000.", "InfinityLoot"); return
			end
			award = math.floor(award)
			local signature = table.concat({ player, raw, item or "", tostring(rate),
				tostring(tax.config.enableTaxation), tostring(tax.config.enableDonations),
				tostring(tax.config.enableWhitelist), tostring(tax.config.enableBlacklist),
				tostring(item and tax.whitelistedItems[item]), tostring(item and tax.blacklistedItems[item]) }, "\001")
			local pending = self.confirmTax
			if not pending or pending.label ~= label or pending.value ~= signature or pending.engine ~= engine or pending.target ~= target
				or pending.dkp ~= target.dkp or pending.count ~= #tax.taxHistory then
				self.confirmTax = { label = label, value = signature, engine = engine, target = target,
					dkp = target.dkp, count = #tax.taxHistory }
				frame.status:SetText(label .. ": " .. player .. " +" .. award .. " DKP? Click again; no gold is transferred.")
				return
			end
			self.confirmTax = nil
			local ok
			if kind == "tax" then ok = tax:AwardForTax(player, gold)
			else ok = tax:AwardForDonation(player, gold, item) end
			self:RefreshTaxSettings()
			frame.status:SetText(ok and ("Awarded " .. award .. " local DKP; sync separately.")
				or "Award failed; see warning.")
		end }
	end
	local function AddItems(label, items)
		local names = {}
		for name in pairs(items) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do rows[#rows + 1] = { text = label .. ": " .. name } end
	end
	AddItems("Whitelist", tax.whitelistedItems)
	AddItems("Blacklist", tax.blacklistedItems)
	for index = #tax.taxHistory, math.max(1, #tax.taxHistory - 99), -1 do
		local entry = tax.taxHistory[index]
		rows[#rows + 1] = { text = "History: " .. tostring(entry.player) .. " | " .. tostring(entry.type)
			.. " | " .. tostring(entry.gold) .. " gold | " .. tostring(entry.dkp) .. " DKP | " .. tostring(entry.reason or "") }
	end
	frame:SetItems(rows)
	frame.status:SetText("Manual local InfinityDKP awards only; no gold or items transferred or guild sync.")
end

function InfinityLootUI:ShowAwardHistory()
	local history = _G.InfinityLootHistory
	if not history or type(history.GetLootAnalysis) ~= "function" then
		InfinityUtils:Warning("Loot award history unavailable.", "InfinityLoot")
		return
	end
	if not self.awardHistoryFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootAwardHistoryWindow", "Local Loot Award History", 700, 500)
		local label = InfinityUIFramework:CreateLabel(frame, "Player")
		label:SetPoint("TOPLEFT", 15, -43)
		local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		input:SetSize(130, 20)
		input:SetPoint("TOPLEFT", 65, -38)
		input:SetAutoFocus(false)
		input:SetMaxLetters(80)
		self.awardHistoryFrame, self.awardHistoryPlayer = frame, input
		local itemLabel = InfinityUIFramework:CreateLabel(frame, "Item")
		itemLabel:SetPoint("TOPLEFT", 205, -43)
		local item = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		item:SetSize(180, 20)
		item:SetPoint("TOPLEFT", 245, -38)
		item:SetAutoFocus(false)
		item:SetMaxLetters(200)
		local valueLabel = InfinityUIFramework:CreateLabel(frame, "Value")
		valueLabel:SetPoint("TOPLEFT", 450, -43)
		local value = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		value:SetSize(80, 20)
		value:SetPoint("TOPLEFT", 495, -38)
		value:SetAutoFocus(false)
		value:SetMaxLetters(16)
		self.awardHistoryItem, self.awardHistoryValue = item, value
	end
	self.confirmAwardRecord = nil
	local frame = self.awardHistoryFrame
	local function Show(title, rows)
		if not self.awardHistoryResults then
			self.awardHistoryResults = InfinityUIFramework:CreateListWindow("InfinityLootAwardHistoryResults", "Loot Award Results", 700, 500)
		end
		if #rows == 0 then rows[1] = { text = "No matching records." } end
		self.awardHistoryResults:SetItems(rows)
		self.awardHistoryResults.status:SetText(title .. " | Session only; independent of InfinityDKP and Loot Log.")
		self.awardHistoryResults:Show()
	end
	local function Records(entries)
		local rows = {}
		for _, entry in ipairs(entries) do
			rows[#rows + 1] = { text = tostring(entry.timestamp) .. " | " .. entry.playerName .. " | "
				.. entry.itemName .. " | " .. entry.value .. " | " .. entry.reason,
				link = entry.itemLink }
		end
		return rows
	end
	frame:SetItems({
		{ text = "Award statistics", onClick = function()
			local stats = history:GetLootAnalysis()
			Show("Award statistics", {
				{ text = "Awards: " .. stats.totalAwards },
				{ text = "Total value: " .. stats.totalValue },
				{ text = "Average value: " .. stats.averageValue },
				{ text = "Highest award: " .. stats.highestAward },
			})
		end },
		{ text = "Recent awards (up to 200)", onClick = function()
			local entries = {}
			for index = #history.lootLog, math.max(1, #history.lootLog - 199), -1 do
				entries[#entries + 1] = history.lootLog[index]
			end
			Show("Recent awards", Records(entries))
		end },
		{ text = "Player awards | Player", onClick = function()
			local player = self.awardHistoryPlayer:GetText()
			if _G.issecretvalue and _G.issecretvalue(player) then player = nil end
			if type(player) ~= "string" then InfinityUtils:Warning("Player input unavailable or protected.", "InfinityLoot"); return end
			player = player:match("^%s*(.-)%s*$")
			if player == "" or player:find("[%c]") then InfinityUtils:Warning("Enter a valid player name.", "InfinityLoot"); return end
			Show("Awards for " .. player, Records(history:GetPlayerLootHistory(player, 200)))
		end },
		{ text = "Top recipients (up to 50)", onClick = function()
			local rows = {}
			for _, player in ipairs(history:GetTopLootRecipients(50, "value")) do
				rows[#rows + 1] = { text = player.name .. " | " .. player.totalAwards .. " awards | total "
					.. player.totalValue .. " | average " .. player.averageValue }
			end
			Show("Top recipients", rows)
		end },
		{ text = "Most awarded items (up to 50)", onClick = function()
			local rows = {}
			for _, item in ipairs(history:GetMostAwardedItems(50)) do
				rows[#rows + 1] = { text = item.itemId .. " | " .. item.awardCount .. " awards | total " .. item.totalValue }
			end
			Show("Most awarded items", rows)
		end },
		{ text = "Record local award | Player, Item, Value (integer); confirm twice", onClick = function()
			local player, item, raw = self.awardHistoryPlayer:GetText(), self.awardHistoryItem:GetText(), self.awardHistoryValue:GetText()
			if _G.issecretvalue and (issecretvalue(player) or issecretvalue(item) or issecretvalue(raw)) then
				self.confirmAwardRecord = nil
				InfinityUtils:Warning("Award input is protected.", "InfinityLoot"); return
			end
			if type(player) ~= "string" or type(item) ~= "string" or type(raw) ~= "string" then
				self.confirmAwardRecord = nil
				InfinityUtils:Warning("Award input unavailable.", "InfinityLoot"); return
			end
			player, item = player:match("^%s*(.-)%s*$"), item:match("^%s*(.-)%s*$")
			local value = tonumber(raw)
			if player == "" or item == "" or player:find("[%c]") or item:find("[%c]")
				or not value or value ~= value or value < 0 or value >= math.huge or value ~= math.floor(value) then
				self.confirmAwardRecord = nil
				InfinityUtils:Warning("Enter a player, item and non-negative integer value.", "InfinityLoot"); return
			end
			local pending = self.confirmAwardRecord
			if not pending or pending.player ~= player or pending.item ~= item or pending.value ~= value
				or pending.count ~= #history.lootLog or pending.latest ~= history.lootLog[#history.lootLog] then
				self.confirmAwardRecord = { player = player, item = item, value = value,
					count = #history.lootLog, latest = history.lootLog[#history.lootLog] }
				frame.status:SetText("Record " .. item .. " for " .. player .. " at " .. value .. "? Click again.")
				return
			end
			self.confirmAwardRecord = nil
			if not history:LogLootAward({ playerName = player, itemName = item, value = value, source = "manual" }) then
				InfinityUtils:Warning("Could not record loot award.", "InfinityLoot"); return
			end
			frame.status:SetText("Recorded locally; no item or points were awarded.")
		end },
	})
	frame.status:SetText("Manual, session-only records; no item or points awarded.")
	frame:Show()
end

local function DecaySnapshot(decay, players)
	local snapshot = { config = {}, players = {} }
	for key, value in pairs(decay.config) do snapshot.config[key] = value end
	for name, player in pairs(players) do
		snapshot.players[name] = { player = player, ep = player.ep, gp = player.gp,
			lastDecay = decay.lastDecayTime[name], lastAward = decay.lastAwardTime[name],
			weekly = decay.weeklyEPGained[name] }
	end
	return snapshot
end

local function SameDecaySnapshot(a, b)
	for key, value in pairs(a.config) do if b.config[key] ~= value then return false end end
	for key, value in pairs(b.config) do if a.config[key] ~= value then return false end end
	for name, player in pairs(a.players) do
		local other = b.players[name]
		if not other or player.player ~= other.player or player.ep ~= other.ep or player.gp ~= other.gp
			or player.lastDecay ~= other.lastDecay or player.lastAward ~= other.lastAward or player.weekly ~= other.weekly then
			return false
		end
	end
	for name in pairs(b.players) do if not a.players[name] then return false end end
	return true
end

function InfinityLootUI:ShowDecay()
	if not self.decayFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootDecayWindow", "Local Loot EP/GP Decay", 700, 500)
		local label = InfinityUIFramework:CreateLabel(frame, "Value")
		label:SetPoint("TOPLEFT", 20, -43)
		local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		input:SetSize(150, 20)
		input:SetPoint("TOPLEFT", 70, -38)
		input:SetAutoFocus(false)
		input:SetMaxLetters(20)
		local playerLabel = InfinityUIFramework:CreateLabel(frame, "Player")
		playerLabel:SetPoint("TOPLEFT", 250, -43)
		local player = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
		player:SetSize(180, 20)
		player:SetPoint("TOPLEFT", 305, -38)
		player:SetAutoFocus(false)
		player:SetMaxLetters(80)
		self.decayFrame, self.decayInput, self.decayPlayer = frame, input, player
	end
	self.confirmDecay = nil
	self:RefreshDecay()
	self.decayFrame:Show()
end

function InfinityLootUI:RefreshDecay()
	local frame, decay, epgp = self.decayFrame, _G.InfinityLootDecay, _G.InfinityLootEPGP
	if not decay or not epgp or type(epgp.players) ~= "table" then
		frame:SetItems({})
		frame.status:SetText("Loot EP/GP decay unavailable.")
		InfinityUtils:Warning("Loot EP/GP decay unavailable.", "InfinityLoot")
		return
	end
	local function Confirm(label, value, action)
		if decay.config.adminOnly and (not InfinityLootAccessControl or not InfinityLootAccessControl.HasPermission) then
			InfinityUtils:Warning("Decay permission check unavailable.", "InfinityLoot")
			return
		end
		if not decay:IsAdminOnly() then InfinityUtils:Warning("Decay permission denied.", "InfinityLoot"); return end
		local snapshot = DecaySnapshot(decay, epgp.players)
		local pending = self.confirmDecay
		if not pending or pending.label ~= label or pending.value ~= value or not SameDecaySnapshot(pending.snapshot, snapshot) then
			self.confirmDecay = { label = label, value = value, snapshot = snapshot }
			frame.status:SetText(label .. (value ~= nil and (" = " .. tostring(value)) or "") .. "? Click again to confirm.")
			return
		end
		self.confirmDecay = nil
		if not action(value) then InfinityUtils:Warning("Decay action failed or is disabled.", "InfinityLoot") end
		self:RefreshDecay()
	end
	local actions = {
		{ "Set decay percent (0-100)", "decayPercent", 0, 100, "SetDecayPercent" },
		{ "Set decay interval (seconds; minimum 3600)", "decayInterval", 3600, nil, "SetDecayInterval" },
		{ "Set weekly EP cap (0 = unlimited)", "weeklyEPCap", 0, nil, "SetWeeklyEPCap" },
		{ "Set minimum GP threshold", "minGPThreshold", 0, nil, "SetMinGPThreshold" },
		{ "Set attendance EP amount", "attendanceAwardPerInterval", 0, nil, "SetAttendanceAwardAmount" },
		{ "Set attendance interval (seconds; minimum 60)", "attendanceCheckInterval", 60, nil, "SetAttendanceCheckInterval" },
	}
	local rows = {}
	for _, entry in ipairs(actions) do
		local spec = entry
		rows[#rows + 1] = { text = spec[1] .. " | current: " .. tostring(decay.config[spec[2]]), onClick = function()
			local raw = self.decayInput:GetText()
			if _G.issecretvalue and _G.issecretvalue(raw) then raw = nil end
			local value = type(raw) == "string" and tonumber(raw) or nil
			if not value or value ~= value or value == math.huge or value < spec[3] or (spec[4] and value > spec[4]) then
				self.confirmDecay = nil
				InfinityUtils:Warning("Invalid value for " .. spec[1] .. ".", "InfinityLoot")
				return
			end
			Confirm(spec[1], value, function(v) return decay[spec[5]](decay, v) end)
		end }
	end
	local function Add(label, method, value)
		rows[#rows + 1] = { text = label, onClick = function()
			Confirm(label, value, function(v) return decay[method](decay, v) end)
		end }
	end
	Add("Enable decay", "SetDecayEnabled", true)
	Add("Disable decay", "SetDecayEnabled", false)
	Add("Apply decay to eligible local Loot EP/GP players", "ApplyDecayToAll")
	Add("Award attendance EP to all eligible local Loot EP/GP players", "AwardAllAttendanceEP")
	Add("Reset local weekly EP counters", "ResetWeeklyEPCounters")
	rows[#rows + 1] = { text = "Show local decay history", onClick = function() self:ShowDecayHistory() end }
	rows[#rows + 1] = { text = "Add local Loot EP/GP player | Player", onClick = function()
		local name = self.decayPlayer:GetText()
		if _G.issecretvalue and _G.issecretvalue(name) then name = nil end
		name = type(name) == "string" and name:match("^%s*(.-)%s*$") or nil
		if not name or name == "" or name:find("[%c]") then
			InfinityUtils:Warning("Enter a valid player name.", "InfinityLoot")
			return
		end
		if epgp.players[name] then InfinityUtils:Warning("Player already exists.", "InfinityLoot"); return end
		Confirm("Add local Loot EP/GP player", name, function(v) return epgp:AddPlayer(v, 0, 0) end)
	end }
	for _, spec in ipairs({ { "EP", "AwardEP" }, { "GP (counts as loot)", "AwardGP" } }) do
		local kind, method = spec[1], spec[2]
		rows[#rows + 1] = { text = "Award local Loot " .. kind .. " | Player and Value", onClick = function()
			local name, raw = self.decayPlayer:GetText(), self.decayInput:GetText()
			if _G.issecretvalue and (issecretvalue(name) or issecretvalue(raw)) then name, raw = nil, nil end
			name = type(name) == "string" and name:match("^%s*(.-)%s*$") or nil
			local value = type(raw) == "string" and tonumber(raw) or nil
			if not name or not epgp.players[name] or not value or value ~= value or value <= 0 or value >= math.huge then
				InfinityUtils:Warning("Enter an existing player and positive finite amount.", "InfinityLoot")
				return
			end
			Confirm("Award local Loot " .. kind .. " to " .. name, value, function(v)
				if method == "AwardGP" then return epgp:AwardGP(name, "Manual adjustment", v, "Manual adjustment") end
				return epgp:AwardEP(name, v, "Manual adjustment")
			end)
		end }
	end
	rows[#rows + 1] = { text = "Show local Loot EP/GP players", onClick = function()
		if not self.lootPlayersFrame then
			self.lootPlayersFrame = InfinityUIFramework:CreateListWindow("InfinityLootEPGPPlayersWindow", "Local Loot EP/GP Players", 650, 400)
		end
		local players = {}
		for name, player in pairs(epgp.players) do
			players[#players + 1] = { text = name .. " | EP " .. player.ep .. " | GP " .. player.gp }
		end
		table.sort(players, function(a, b) return a.text < b.text end)
		if #players == 0 then players[1] = { text = "No local Loot EP/GP players." } end
		self.lootPlayersFrame:SetItems(players)
		self.lootPlayersFrame.status:SetText("Session only; independent of InfinityDKP.")
		self.lootPlayersFrame:Show()
	end }
	frame:SetItems(rows)
	frame.status:SetText("Separate local Loot EP/GP data; changes are session-only. Actions require confirmation.")
end

function InfinityLootUI:ShowPointAudit()
	if not self.auditFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootPointAuditWindow", "Local Loot Point Audit", 700, 450)
		local function Input(title, x, offset, width)
			local label = InfinityUIFramework:CreateLabel(frame, title)
			label:SetPoint("TOPLEFT", x, -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(width, 20)
			box:SetPoint("TOPLEFT", x + offset, -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(80)
			return box
		end
		self.auditPlayer = Input("Player", 15, 55, 180)
		self.auditValue = Input("Type / days", 280, 80, 150)
		self.auditFrame = frame
	end
	local epgp, audit = _G.InfinityLootEPGP, _G.InfinityPointAuditing
	if not epgp or not audit then InfinityUtils:Warning("Point audit unavailable.", "InfinityLoot"); return end
	local function Input(box)
		local value = box:GetText()
		if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
		if type(value) ~= "string" then InfinityUtils:Warning("Audit input unavailable or protected.", "InfinityLoot"); return nil end
		return value:match("^%s*(.-)%s*$")
	end
	local function Show(title, rows)
		if not self.auditResults then
			self.auditResults = InfinityUIFramework:CreateListWindow("InfinityLootPointAuditResults", "Point Audit Results", 700, 500)
		end
		if #rows == 0 then rows[1] = { text = "No matching records." } end
		self.auditResults:SetItems(rows)
		self.auditResults.status:SetText(title .. " | Session only; independent of InfinityDKP.")
		self.auditResults:Show()
	end
	local function Player()
		local name = Input(self.auditPlayer)
		if name == "" then InfinityUtils:Warning("Enter a player name.", "InfinityLoot"); return nil end
		return name
	end
	local function Transactions(records)
		local rows = {}
		for _, record in ipairs(records) do
			rows[#rows + 1] = { text = tostring(record.timestamp) .. " | " .. tostring(record.playerName)
				.. " | " .. tostring(record.type) .. " | " .. tostring(record.amount or 0)
				.. " | " .. tostring(record.reason or "") }
		end
		return rows
	end
	local actions = {
		{ text = "Transaction statistics", onClick = function()
			local stats = epgp:GetTransactionStats()
			Show("Transaction statistics", {
				{ text = "Transactions: " .. stats.totalTransactions },
				{ text = "EP awards: " .. stats.epAwardedTransactions .. " | Total: " .. stats.totalEPAwarded },
				{ text = "GP awards: " .. stats.gpAwardedTransactions .. " | Total: " .. stats.totalGPAwarded },
				{ text = "Decay transactions: " .. stats.decayTransactions .. " | Resets: " .. stats.resetTransactions },
			})
		end },
		{ text = "Player transactions | Player", onClick = function()
			local player = Player()
			if player then Show("Player transactions", Transactions(epgp:GetPlayerTransactionHistory(player, 200))) end
		end },
		{ text = "Transactions by type | Type / days", onClick = function()
			local kind = Input(self.auditValue)
			if not kind then return end
			if kind == "" then InfinityUtils:Warning("Enter a transaction type.", "InfinityLoot"); return end
			Show("Transactions by type", Transactions(epgp:GetTransactionsByType(kind, 200)))
		end },
		{ text = "EP sources | Player", onClick = function()
			local player = Player()
			if not player then return end
			local rows = {}
			for _, entry in ipairs(audit:GetPlayerEPSources(player, 200)) do
				rows[#rows + 1] = { text = entry.reason .. " | EP " .. entry.amount .. " | Awards " .. entry.count }
			end
			Show("EP sources", rows)
		end },
		{ text = "GP items | Player", onClick = function()
			local player = Player()
			if not player then return end
			local rows = {}
			for _, entry in ipairs(audit:GetPlayerGPItems(player, 200)) do
				rows[#rows + 1] = { text = entry.itemName .. " | GP " .. entry.gp .. " | Awards " .. entry.count }
			end
			Show("GP items", rows)
		end },
		{ text = "Possible anomalies | Player", onClick = function()
			local player = Player()
			if not player then return end
			local rows = {}
			for _, entry in ipairs(audit:DetectAnomalies(player)) do
				rows[#rows + 1] = { text = entry.severity .. " | " .. entry.type .. " | " .. entry.detail }
			end
			Show("Possible anomalies; review manually", rows)
		end },
		{ text = "Player audit report | Player, Type / days = days", onClick = function()
			local player, raw = Player(), Input(self.auditValue)
			if not player or not raw then return end
			local days = tonumber(raw)
			if not days or days ~= days or days < 1 or days > 3650 or days ~= math.floor(days) then
				InfinityUtils:Warning("Enter days between 1 and 3650.", "InfinityLoot")
				return
			end
			local report = audit:GeneratePlayerAuditReport(player, days)
			Show("Player audit: " .. player .. " | " .. days .. " days", {
				{ text = "EP gained: " .. report.epGained },
				{ text = "GP spent: " .. report.gpSpent },
				{ text = "EP minus GP: " .. report.netPoints },
			})
		end },
	}
	self.auditFrame:SetItems(actions)
	self.auditFrame.status:SetText("Select a report. Type values include ep_awarded and gp_awarded.")
	self.auditFrame:Show()
end

function InfinityLootUI:ShowDecayHistory()
	if not self.decayHistoryFrame then
		self.decayHistoryFrame = InfinityUIFramework:CreateListWindow("InfinityLootDecayHistoryWindow", "Decay History", 700, 450)
	end
	local rows = {}
	for _, entry in ipairs(InfinityLootDecay:GetDecayHistory(200)) do
		rows[#rows + 1] = { text = string.format("%s | EP %s -> %s | GP %s -> %s | %s%%",
			entry.playerName, entry.epBefore, entry.epAfter, entry.gpBefore, entry.gpAfter, entry.decayPercent) }
	end
	if #rows == 0 then rows[1] = { text = "No local decay records." } end
	self.decayHistoryFrame:SetItems(rows)
	self.decayHistoryFrame.status:SetText("Most recent 200 records; session only.")
	self.decayHistoryFrame:Show()
end

function InfinityLootUI:ShowTrackingTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Loot Tracking" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Session stats
	local sessionStats = InfinityLootTracking:GetSessionStats()
	if sessionStats then
		local info = {
			"Status: " .. (sessionStats.ended and "Ended" or (sessionStats.running and "Running" or "Paused"))
				.. " (manual records only)",
			"Session Value: " .. InfinityUtils:FormatGold(sessionStats.totalValue),
			"Gold/Hour: " .. InfinityUtils:FormatGold(sessionStats.goldPerHour),
			"Items Looted: " .. sessionStats.totalItems,
			"Kills: " .. sessionStats.kills,
			"Loot Per Hour: " .. sessionStats.lootPerHour,
			"Time: " .. InfinityUtils:FormatTime(sessionStats.elapsedSeconds),
		}
		
		for _, text in ipairs(info) do
			local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
			label:SetPoint("TOPLEFT", 10, y)
			y = y - 20
		end
	end
	
	-- Control buttons
	y = y - 20
	local pauseBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Pause", 70, 25, function()
		if not InfinityLootTracking:PauseSession() then InfinityUtils:Warning("Tracking is not running.", "InfinityLoot") end
		self:ShowTab(frame, "tracking")
	end)
	pauseBtn:SetPoint("TOPLEFT", 10, y)
	
	local resumeBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Resume", 70, 25, function()
		if not InfinityLootTracking:ResumeSession() then InfinityUtils:Warning("Tracking is already running or unavailable.", "InfinityLoot") end
		self:ShowTab(frame, "tracking")
	end)
	resumeBtn:SetPoint("TOPLEFT", 90, y)
	
	local newBtn = InfinityUIFramework:CreateButton(frame.contentArea, "New Session", 100, 25, function()
		InfinityLootTracking:StartNewSession()
		self:ShowTab(frame, "tracking")
	end)
	newBtn:SetPoint("TOPLEFT", 170, y)
	local recordBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Record", 100, 25, function()
		self:ShowTrackingRecords()
	end)
	recordBtn:SetPoint("TOPLEFT", 280, y)
	local endBtn = InfinityUIFramework:CreateButton(frame.contentArea, "End", 70, 25, function()
		if not InfinityLootTracking:EndSession() then InfinityUtils:Warning("Tracking session already ended or unavailable.", "InfinityLoot") end
		self:ShowTab(frame, "tracking")
	end)
	endBtn:SetPoint("TOPLEFT", 390, y)
	local sessionsBtn = InfinityUIFramework:CreateButton(frame.contentArea, "Sessions", 90, 25, function()
		self:ShowTrackingSessions()
	end)
	sessionsBtn:SetPoint("TOPLEFT", 470, y)
end

function InfinityLootUI:ShowTrackingSessions()
	local tracker = _G.InfinityLootTracking
	if not tracker or type(tracker.db.sessions) ~= "table" then
		InfinityUtils:Warning("Tracking sessions unavailable.", "InfinityLoot"); return
	end
	if not self.trackingSessions then
		self.trackingSessions = InfinityUIFramework:CreateListWindow("InfinityLootTrackingSessions", "Loot Tracking Sessions", 700, 500)
	end
	local ids = {}
	for id in pairs(tracker.db.sessions) do ids[#ids + 1] = id end
	table.sort(ids)
	local rows = {}
	for index = #ids, math.max(1, #ids - 199), -1 do
		local stats = tracker:GetSessionStats(ids[index])
		if stats then
			local orphaned = stats.running and stats.id ~= tracker.currentSession
			local state = orphaned and "Previously running; duration unavailable"
				or (stats.ended and "Ended" or (stats.running and "Running" or "Paused"))
			local duration = orphaned and "?" or InfinityUtils:FormatTime(stats.elapsedSeconds)
			rows[#rows + 1] = { text = stats.id .. " | " .. state .. " | " .. stats.totalItems .. " items | "
				.. stats.totalValue .. " copper | " .. duration .. " | click for items",
				onClick = function() self:ShowTrackingSessionItems(stats.id) end }
		end
	end
	if #rows == 0 then rows[1] = { text = "No tracking sessions." } end
	self.trackingSessions:SetItems(rows)
	self.trackingSessions.status:SetText("Local saved sessions; up to 200 IDs shown. Records are manual.")
	self.trackingSessions:Show()
end

function InfinityLootUI:ShowTrackingSessionItems(id)
	local tracker = _G.InfinityLootTracking
	if not tracker or not tracker.db.sessions[id] then
		InfinityUtils:Warning("Tracking session unavailable.", "InfinityLoot"); return
	end
	if not self.trackingSessionItems then
		self.trackingSessionItems = InfinityUIFramework:CreateListWindow("InfinityLootTrackingSessionItems", "Session Items", 700, 500)
	end
	local rows = {}
	for _, entry in ipairs(tracker:GetLootHistory(id, 200)) do
		rows[#rows + 1] = { text = entry.itemLink .. " | " .. entry.category .. " | " .. entry.value .. " copper",
			link = entry.itemLink:find("|Hitem:", 1, true) and entry.itemLink or nil }
	end
	if #rows == 0 then rows[1] = { text = "No recorded items." } end
	self.trackingSessionItems:SetItems(rows)
	self.trackingSessionItems.status:SetText(id .. " | up to 200 most recent items.")
	self.trackingSessionItems:Show()
end

function InfinityLootUI:ShowTrackingRecords()
	if not self.trackingRecords then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootTrackingRecordsWindow", "Manual Loot Tracking", 700, 430)
		local function Input(title, x, offset, width)
			local label = InfinityUIFramework:CreateLabel(frame, title)
			label:SetPoint("TOPLEFT", x, -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(width, 20)
			box:SetPoint("TOPLEFT", x + offset, -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(200)
			return box
		end
		self.trackingName = Input("Item / mob", 15, 75, 190)
		self.trackingValue = Input("Copper", 295, 55, 85)
		self.trackingCategory = Input("Category", 455, 65, 110)
		self.trackingRecords = frame
	end
	local frame, tracker = self.trackingRecords, _G.InfinityLootTracking
	local function Input(box)
		local value = box:GetText()
		if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
		if type(value) ~= "string" then InfinityUtils:Warning("Tracking input unavailable or protected.", "InfinityLoot"); return nil end
		value = value:match("^%s*(.-)%s*$")
		if value:find("[%c]") then InfinityUtils:Warning("Tracking input contains control characters.", "InfinityLoot"); return nil end
		return value
	end
	local function Amount()
		local raw = Input(self.trackingValue)
		if not raw then return nil end
		local value = tonumber(raw)
		if not value or value ~= value or value < 0 or value >= math.huge or value ~= math.floor(value) then
			InfinityUtils:Warning("Enter a non-negative whole number of copper.", "InfinityLoot")
			return nil
		end
		return value
	end
	local function Record(method, ...)
		if not tracker[method](tracker, ...) then
			InfinityUtils:Warning("No running tracking session; resume first.", "InfinityLoot")
			return
		end
		self:ShowTrackingRecords()
		frame.status:SetText("Recorded locally. Tracking entries are manual.")
		local main = _G.InfinityLootWindow
		if main and main.currentTab == "tracking" then self:ShowTab(main, "tracking") end
	end
	local rows = {
		{ text = "Record item | Item, Copper, Category: MATS / GEAR / JUNK / OTHER", onClick = function()
			local item, category, amount = Input(self.trackingName), Input(self.trackingCategory), Amount()
			if not item or not category or amount == nil then return end
			category = category:upper()
			if item == "" or not ({ MATS = true, GEAR = true, JUNK = true, OTHER = true })[category] then
				InfinityUtils:Warning("Enter an item and a listed category.", "InfinityLoot"); return
			end
			Record("RecordLoot", item, category, amount)
		end },
		{ text = "Record money | Copper", onClick = function() local value = Amount(); if value then Record("RecordMoney", value) end end },
		{ text = "Record cost | Copper; optional Item / mob = reason", onClick = function()
			local value, reason = Amount(), Input(self.trackingName)
			if value and reason then Record("RecordCost", value, reason ~= "" and reason or "Manual") end
		end },
		{ text = "Record kill | optional Item / mob", onClick = function()
			local name = Input(self.trackingName); if name then Record("RecordKill", name) end
		end },
		{ text = "Record looted mob | optional Item / mob", onClick = function()
			local name = Input(self.trackingName); if name then Record("RecordLootedMob", name) end
		end },
	}
	for _, entry in ipairs(tracker:GetLootHistory(nil, 100)) do
		rows[#rows + 1] = { text = entry.itemLink .. " | " .. entry.category .. " | " .. entry.value .. " copper",
			link = entry.itemLink:find("|Hitem:", 1, true) and entry.itemLink or nil }
	end
	frame:SetItems(rows)
	frame.status:SetText("Manual records only. Currency values are in copper.")
	frame:Show()
end

function InfinityLootUI:ShowEconomyTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Economy" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Summary
	local summary = InfinityLootEconomy:GetSummary()
	local balance = summary.balance < 0 and ("-" .. InfinityUtils:FormatGold(-summary.balance))
		or InfinityUtils:FormatGold(summary.balance)
	local info = {
		"Last 7 days, manual records only",
		"Total Earned: " .. InfinityUtils:FormatGold(summary.totalEarned),
		"Total Spent: " .. InfinityUtils:FormatGold(summary.totalSpent),
		"Balance: " .. balance,
		"Transactions: " .. summary.transactions,
	}
	
	for _, text in ipairs(info) do
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
	
	-- Top merchants
	y = y - 20
	local merchantLabel = InfinityUIFramework:CreateLabel(frame.contentArea, "Top Merchants (all recorded time):")
	merchantLabel:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	local merchants = InfinityLootEconomy:GetTopMerchants(5)
	for _, merchant in ipairs(merchants) do
		local text = merchant.name .. ": " .. InfinityUtils:FormatGold(merchant.amount)
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 20, y)
		y = y - 15
	end
	local prices = InfinityUIFramework:CreateButton(frame.contentArea, "Item prices", 110, 22, function()
		self:ShowItemPrices()
	end)
	prices:SetPoint("BOTTOMLEFT", 10, 10)
	local records = InfinityUIFramework:CreateButton(frame.contentArea, "Transactions", 110, 22, function()
		self:ShowEconomyRecords()
	end)
	records:SetPoint("LEFT", prices, "RIGHT", 8, 0)
end

function InfinityLootUI:ShowEconomyRecords()
	local economy = _G.InfinityLootEconomy
	if not economy or type(economy.db.goldTracking) ~= "table" then
		InfinityUtils:Warning("Loot economy unavailable.", "InfinityLoot"); return
	end
	if not self.economyRecords then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootEconomyRecords", "Manual Economy Records", 750, 500)
		local function Input(title, x, offset, width)
			local label = InfinityUIFramework:CreateLabel(frame, title)
			label:SetPoint("TOPLEFT", x, -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(width, 20)
			box:SetPoint("TOPLEFT", x + offset, -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(120)
			return box
		end
		self.economyAmount = Input("Copper", 15, 55, 85)
		self.economySource = Input("Source / merchant", 170, 115, 150)
		self.economyDetail = Input("Detail", 450, 50, 180)
		self.economyRecords = frame
	end
	self.confirmEconomy = nil
	self:RefreshEconomyRecords()
	self.economyRecords:Show()
end

function InfinityLootUI:RefreshEconomyRecords()
	local frame, economy = self.economyRecords, InfinityLootEconomy
	local function Input(box)
		local value = box:GetText()
		if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
		if type(value) ~= "string" then InfinityUtils:Warning("Economy input unavailable or protected.", "InfinityLoot"); return nil end
		value = value:match("^%s*(.-)%s*$")
		if value:find("[%c]") then InfinityUtils:Warning("Economy input contains control characters.", "InfinityLoot"); return nil end
		return value
	end
	local rows = {}
	for _, kind in ipairs({ "earning", "spending" }) do
		local action = kind
		rows[#rows + 1] = { text = "Record " .. action .. " | Copper, Source / merchant; optional Detail", onClick = function()
			local raw, source, detail = Input(self.economyAmount), Input(self.economySource), Input(self.economyDetail)
			if not raw or not source or not detail then self.confirmEconomy = nil; return end
			local amount = tonumber(raw)
			if source == "" or not amount or amount ~= amount or amount <= 0 or amount >= math.huge
				or amount ~= math.floor(amount) then
				self.confirmEconomy = nil
				InfinityUtils:Warning("Enter a source and positive whole copper amount.", "InfinityLoot"); return
			end
			local list = action == "earning" and economy.db.goldTracking.earned or economy.db.goldTracking.spent
			local pending = self.confirmEconomy
			local signature = action .. "\001" .. raw .. "\001" .. source .. "\001" .. detail
			if not pending or pending.signature ~= signature or pending.list ~= list or pending.count ~= #list
				or pending.latest ~= list[#list] then
				self.confirmEconomy = { signature = signature, list = list, count = #list, latest = list[#list] }
				frame.status:SetText("Record " .. action .. " of " .. amount .. " copper? Click again; no money is moved.")
				return
			end
			self.confirmEconomy = nil
			local ok
			if action == "earning" then ok = economy:RecordEarnings(amount, source, detail)
			else ok = economy:RecordSpending(amount, source, detail) end
			if not ok then InfinityUtils:Warning("Economy record failed.", "InfinityLoot") end
			self:RefreshEconomyRecords()
			frame.status:SetText(ok and "Recorded locally; no money was moved." or "Recording failed; see warning.")
			local main = _G.InfinityLootWindow
			if main and main.currentTab == "economy" then self:ShowTab(main, "economy") end
		end }
	end
	local entries = {}
	for _, entry in ipairs(economy.db.goldTracking.earned) do entries[#entries + 1] = { kind = "Earned", data = entry } end
	for _, entry in ipairs(economy.db.goldTracking.spent) do entries[#entries + 1] = { kind = "Spent", data = entry } end
	table.sort(entries, function(a, b) return a.data.timestamp > b.data.timestamp end)
	for index = 1, math.min(200, #entries) do
		local kind, entry = entries[index].kind, entries[index].data
		rows[#rows + 1] = { text = kind .. " | " .. entry.amount .. " copper | "
			.. (entry.source or entry.merchant or "") .. " | " .. (entry.description or entry.item or "") }
	end
	frame:SetItems(rows)
	frame.status:SetText("Manual local records; first 200 most recent shown. No real money is moved.")
end

function InfinityLootUI:ShowItemPrices()
	if not self.priceFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootPricesWindow", "Local Item Prices", 600, 400)
		local function Input(title, x, offset, width)
			local label = InfinityUIFramework:CreateLabel(frame, title)
			label:SetPoint("TOPLEFT", x, -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(width, 20)
			box:SetPoint("TOPLEFT", x + offset, -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(20)
			return box
		end
		self.priceItem = Input("Item ID", 15, 55, 100)
		self.priceValue = Input("GP", 190, 30, 100)
		self.priceFrame = frame
	end
	self.confirmPrice = nil
	self:RefreshItemPrices()
	self.priceFrame:Show()
end

function InfinityLootUI:RefreshItemPrices()
	local frame, economy = self.priceFrame, _G.InfinityLootAdvancedEconomy
	if not economy or not economy.initialized then
		frame.status:SetText("Local prices unavailable: economy initialization failed.")
		frame:SetItems({})
		InfinityUtils:Warning("Local loot prices unavailable.", "InfinityLoot")
		return
	end
	frame:SetItems({ { text = "Set local tooltip price | click twice to confirm", onClick = function()
		local item, value = self.priceItem:GetText(), self.priceValue:GetText()
		if _G.issecretvalue and (_G.issecretvalue(item) or _G.issecretvalue(value)) then
			InfinityUtils:Warning("Protected input cannot be used.", "InfinityLoot")
			self.confirmPrice = nil
			return
		end
		item, value = type(item) == "string" and tonumber(item), type(value) == "string" and tonumber(value)
		if not item or item ~= item or item <= 0 or item >= math.huge or item ~= math.floor(item)
			or not value or value ~= value or value < 0 or value >= math.huge then
			InfinityUtils:Warning("Enter a valid item ID and non-negative GP.", "InfinityLoot")
			self.confirmPrice = nil
			return
		end
		local old = economy.itemPrices[item]
		if not self.confirmPrice or self.confirmPrice.item ~= item or self.confirmPrice.value ~= value
			or self.confirmPrice.old ~= old then
			self.confirmPrice = { item = item, value = value, old = old }
			frame.status:SetText("Set item " .. item .. " to " .. value .. " GP locally? Click again.")
		elseif economy:SetItemPrice(item, value) then
			self.confirmPrice = nil
			frame.status:SetText("Local price saved; not guild-synchronized.")
		end
	end } })
	frame.status:SetText("Enter item ID and GP. Prices are local, not guild-synchronized.")
end

function InfinityLootUI:ShowCommissionsTab(frame)
	local y = -10
	
	-- Title
	local title = InfinityUIFramework:CreateLabel(frame.contentArea, 
		INFINITY_COLORS.PRIMARY .. "Daily Commissions" .. INFINITY_COLORS.RESET)
	title:SetPoint("TOPLEFT", 10, y)
	y = y - 25
	
	-- Stats
	local stats = InfinityLootCommissions:GetStatistics()
	local info = {
		"Registered Quests: " .. stats.totalQuestRegistered,
		"Total Completions: " .. stats.totalCompletions,
		"Completed Today: " .. stats.todayCompleted,
	}
	
	for _, text in ipairs(info) do
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 10, y)
		y = y - 20
	end
	
	-- Available quests
	y = y - 20
	local availLabel = InfinityUIFramework:CreateLabel(frame.contentArea, "Available Today:")
	availLabel:SetPoint("TOPLEFT", 10, y)
	y = y - 20
	
	local available = InfinityLootCommissions:GetAvailableCommissions()
	for i, quest in ipairs(available) do
		if i > 5 then break end
		local text = quest.name .. " (" .. quest.questGiver .. ")"
		local label = InfinityUIFramework:CreateLabel(frame.contentArea, text)
		label:SetPoint("TOPLEFT", 20, y)
		y = y - 15
	end
	local manage = InfinityUIFramework:CreateButton(frame.contentArea, "Manage", 110, 25, function()
		self:ShowCommissionsManager()
	end)
	manage:SetPoint("TOPRIGHT", -10, -10)
end

function InfinityLootUI:ShowCommissionsManager()
	local commissions = _G.InfinityLootCommissions
	if not commissions or type(commissions.db.commissions) ~= "table" then
		InfinityUtils:Warning("Commissions unavailable.", "InfinityLoot"); return
	end
	if not self.commissionsFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootCommissionsManager", "Manual Commissions", 750, 500)
		local function Input(title, x, offset, width)
			local label = InfinityUIFramework:CreateLabel(frame, title)
			label:SetPoint("TOPLEFT", x, -43)
			local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
			box:SetSize(width, 20)
			box:SetPoint("TOPLEFT", x + offset, -38)
			box:SetAutoFocus(false)
			box:SetMaxLetters(100)
			return box
		end
		self.commissionID = Input("ID", 15, 25, 80)
		self.commissionName = Input("Name", 140, 50, 180)
		self.commissionNPC = Input("NPC", 400, 40, 180)
		self.commissionsFrame = frame
	end
	self.confirmCommission = nil
	self:RefreshCommissionsManager()
	self.commissionsFrame:Show()
end

function InfinityLootUI:RefreshCommissionsManager()
	local frame, commissions = self.commissionsFrame, InfinityLootCommissions
	local function Input(box)
		local value = box:GetText()
		if _G.issecretvalue and _G.issecretvalue(value) then value = nil end
		if type(value) ~= "string" then InfinityUtils:Warning("Commission input unavailable or protected.", "InfinityLoot"); return nil end
		value = value:match("^%s*(.-)%s*$")
		if value:find("[%c]") then InfinityUtils:Warning("Commission input contains control characters.", "InfinityLoot"); return nil end
		return value
	end
	local function Confirm(label, signature, quest, callback)
		local pending = self.confirmCommission
		local completed = quest and commissions:IsCompletedToday(quest.id)
		if not pending or pending.label ~= label or pending.signature ~= signature
			or pending.quest ~= quest or pending.completed ~= completed
			or (quest and pending.count ~= quest.timesCompleted) then
			self.confirmCommission = { label = label, signature = signature, quest = quest,
				completed = completed, count = quest and quest.timesCompleted }
			frame.status:SetText(label .. "? Click again to confirm.")
			return
		end
		self.confirmCommission = nil
		if not callback() then InfinityUtils:Warning("Commission action failed.", "InfinityLoot") end
		self:RefreshCommissionsManager()
		local main = _G.InfinityLootWindow
		if main and main.currentTab == "commissions" then self:ShowTab(main, "commissions") end
	end
	local rows = {
		{ text = "Register commission | ID, Name, NPC; confirm twice", onClick = function()
			local raw, name, npc = Input(self.commissionID), Input(self.commissionName), Input(self.commissionNPC)
			if not raw or not name or not npc then self.confirmCommission = nil; return end
			local id = tonumber(raw)
			if not id or id ~= id or id <= 0 or id >= math.huge or id ~= math.floor(id) or name == "" or npc == "" then
				self.confirmCommission = nil
				InfinityUtils:Warning("Enter a positive quest ID, name and NPC.", "InfinityLoot"); return
			end
			if commissions.db.commissions[id] then InfinityUtils:Warning("Commission already exists.", "InfinityLoot"); return end
			Confirm("Register " .. name, raw .. "\001" .. name .. "\001" .. npc, nil, function()
				return commissions:RegisterQuest(id, name, npc, npc)
			end)
		end },
		{ text = "Delete commission and its completion history | ID; confirm twice", onClick = function()
			local raw = Input(self.commissionID)
			if not raw then self.confirmCommission = nil; return end
			local id = tonumber(raw)
			local quest = id and commissions.db.commissions[id]
			if not id or id ~= id or id <= 0 or id >= math.huge or id ~= math.floor(id) or not quest then
				self.confirmCommission = nil
				InfinityUtils:Warning("Enter an existing quest ID.", "InfinityLoot"); return
			end
			Confirm("Delete " .. quest.name .. " and its history", raw, quest, function()
				if commissions.db.commissions[id] ~= quest then return false end
				return commissions:RemoveQuest(id)
			end)
		end },
	}
	local quests = {}
	for _, quest in pairs(commissions.db.commissions) do quests[#quests + 1] = quest end
	table.sort(quests, function(a, b) return a.id < b.id end)
	for _, entry in ipairs(quests) do
		local quest = entry
		rows[#rows + 1] = { text = quest.name .. " | ID " .. quest.id .. " | " .. (quest.questGiver or "Unknown NPC")
			.. " | total " .. quest.timesCompleted .. (commissions:IsCompletedToday(quest.id) and " | done today" or " | click to complete"), onClick = function()
			if commissions.db.commissions[quest.id] ~= quest then
				self.confirmCommission = nil; self:RefreshCommissionsManager()
				InfinityUtils:Warning("Commission changed; review the list.", "InfinityLoot"); return
			end
			if commissions:IsCompletedToday(quest.id) then InfinityUtils:Warning("Already completed today.", "InfinityLoot"); return end
			Confirm("Complete " .. quest.name, tostring(quest.id), quest, function() return commissions:CompleteQuest(quest.id) end)
		end }
	end
	frame:SetItems(rows)
	frame.status:SetText("Manual local records. The daily boundary uses the client's calendar date, not the server reset.")
end

return InfinityLootUI
