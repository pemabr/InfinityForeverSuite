-- InfinityLoot Auction UI System
-- Provides slash commands and UI frames for auction management

InfinityLootAuctionUI = {
	db = {},
	frames = {},
	version = "1.0.0",
	updateRate = 1, -- Update UI 1x per second (not per frame)
	lastUpdate = 0,
}

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

-- Register slash commands
function InfinityLootAuctionUI:RegisterCommands()
	InfinityCommandRegistry:RegisterCommand("auction", function(args)
		InfinityLootAuctionUI:HandleAuctionCommand({ "auction", unpack(args) })
	end)
	InfinityCommandRegistry:RegisterCommand("bid", function(args)
		InfinityLootAuctionUI:HandleBidCommand({ "bid", unpack(args) })
	end)
end

function InfinityLootAuctionUI:HandleCommand(msg)
	local args = InfinityUtils:Split(msg or "", " ")
	local command = args[1] or ""
	
	if command == "auction" then
		self:HandleAuctionCommand(args)
	elseif command == "bid" then
		self:HandleBidCommand(args)
	elseif command == "stats" then
		self:ShowStats()
	elseif command == "list" then
		self:ShowAuctionList()
	elseif command == "audit" then
		self:ShowAuditLog()
	elseif command == "role" then
		self:HandleRoleCommand(args)
	elseif command == "debug" then
		self:HandleDebugCommand(args)
	else
		self:ShowHelp()
	end
end

-- ============================================================================
-- AUCTION COMMANDS
-- ============================================================================

function InfinityLootAuctionUI:HandleAuctionCommand(args)
	local subcommand = args[2] or ""
	
	if subcommand == "create" then
		self:CreateAuctionDialog(args)
	elseif subcommand == "close" then
		local auctionId = args[3]
		if not auctionId then
			InfinityUtils:Warning("Usage: /loot auction close <auctionId>", "AuctionUI")
			return
		end
		if not InfinityLootAccessControl:CanDoAction("close_auctions") then
			return
		end
		InfinityLootAuctions:CloseAuction(auctionId)
	elseif subcommand == "list" then
		self:ShowAuctionList()
	elseif subcommand == "history" then
		self:ShowAuctionHistory()
	else
		self:ShowAuctionHelp()
	end
end

function InfinityLootAuctionUI:CreateAuctionDialog(args)
	-- Check permission
	if not InfinityLootAccessControl:CanDoAction("manage_auctions") then
		return
	end
	
	-- Parse arguments
	local mode = "open"
	local duration = 60
	local minbid = 10
	local cursorType, _, itemLink
	if _G.GetCursorInfo then cursorType, _, itemLink = GetCursorInfo() end
	if (_G.issecretvalue and (issecretvalue(cursorType) or issecretvalue(itemLink)))
		or cursorType ~= "item" then itemLink = nil end
	
	for i = 3, #args, 2 do
		if args[i] == "--mode" then
			mode = args[i + 1]
		elseif args[i] == "--duration" then
			duration = tonumber(args[i + 1])
		elseif args[i] == "--minbid" then
			minbid = tonumber(args[i + 1])
		end
	end
	
	-- Validate mode
	local validModes = {"open", "closed", "vickrey", "anonymous", "tiered", "antisnipe"}
	local modeValid = false
	for _, validMode in ipairs(validModes) do
		if mode == validMode then
			modeValid = true
			break
		end
	end
	
	if not modeValid then
		InfinityUtils:Warning("Invalid bidding mode: " .. mode, "AuctionUI")
		return
	end
	
	-- If no item link, show cursor item
	if type(itemLink) ~= "string" or not duration or not minbid then
		InfinityUtils:Warning("Pick up an item and provide valid duration and minimum bid.", "AuctionUI")
		return
	end
	
	-- Create auction
	local auctionId = InfinityLootAuctions:CreateAuction(
		itemLink,
		mode,
		duration,
		{minimumBid = minbid}
	)
	
	if auctionId then
		print("Local auction " .. auctionId .. " created: " .. itemLink .. " (" .. mode
			.. ", " .. duration .. "s). No network sync or automatic awards.")
		self:ShowAuctionFrame(auctionId)
	else
		InfinityUtils:Warning("Failed to create auction", "AuctionUI")
	end
end

-- ============================================================================
-- BID COMMANDS
-- ============================================================================

function InfinityLootAuctionUI:HandleBidCommand(args)
	local auctionId = args[2]
	local amount = tonumber(args[3])
	
	if not auctionId or not amount then
		InfinityUtils:Warning("Usage: /bid <auctionId> <amount> [tier]", "AuctionUI")
		return
	end
	
	local player = UnitName("player")
	local success = InfinityLootAuctions:PlaceBid(auctionId, player, amount, args[4])
	
	if success then
		print("Local bid placed: " .. amount .. " GP on auction " .. auctionId)
	else
		InfinityUtils:Warning("Failed to place bid", "AuctionUI")
	end
end

-- ============================================================================
-- ROLE COMMANDS
-- ============================================================================

function InfinityLootAuctionUI:HandleRoleCommand(args)
	local subcommand = args[2] or ""
	
	if subcommand == "set" then
		local player = args[3]
		local role = args[4]
		
		if not player or not role then
			InfinityUtils:Warning("Usage: /loot role set <player> <role>", "AuctionUI")
			return
		end
		
		if InfinityLootAccessControl:SetPlayerRole(player, role) then
			InfinityUtils:Info(player .. " assigned role: " .. role, "AuctionUI")
		end
	elseif subcommand == "list" then
		self:ShowRoleList()
	else
		InfinityUtils:Warning("Usage: /loot role set <player> <role> OR /loot role list", "AuctionUI")
	end
end

-- ============================================================================
-- DISPLAY FUNCTIONS
-- ============================================================================

function InfinityLootAuctionUI:ShowAuctionList()
	-- Get all active auctions
	local auctions = InfinityLootAuctions:GetActiveAuctions()
	
	if not auctions or #auctions == 0 then
		print("No active local loot auctions.")
		return
	end
	
	print("Active local loot auctions:")
	
	for _, auction in ipairs(auctions) do
		local bidCount = auction.bids and #auction.bids or 0
		if auction.biddingMode == "tiered" then
			for _, bids in pairs(auction.tierBids) do bidCount = bidCount + #bids end
		end
		local timeLeft = math.max(0, math.floor(auction.endTime - GetTime()))
		
		print(string.format("[%s] %s - Mode: %s, Bids: %d, Time: %ds",
			auction.id, auction.itemLink, auction.biddingMode, bidCount, timeLeft))
	end
end

function InfinityLootAuctionUI:ShowAuctionHistory()
	-- Get closed auctions
	local history = InfinityLootAuctions:GetAuctionHistory(10)
	
	if not history or #history == 0 then
		print("No local loot auction history.")
		return
	end
	
	print("Recent local loot auctions (last 10):")
	
	for _, auction in ipairs(history) do
		local result = auction.winner and (auction.winner .. " (" .. auction.winnerPrice .. " GP)") or "No bids"
		print(string.format("[%s] %s - %s - Mode: %s", auction.id, auction.itemLink, result, auction.biddingMode))
	end
end

function InfinityLootAuctionUI:ShowStats()
	local stats = {
		activeAuctions = #(InfinityLootAuctions:GetActiveAuctions() or {}),
		closedAuctions = #(InfinityLootAuctions:GetAuctionHistory(1000) or {}),
		totalGPAwarded = 0,
		totalEPAwarded = 0,
	}
	
	-- Calculate totals from EPGP
	local players = InfinityLootEPGP:GetAllPlayers()
	for _, player in ipairs(players or {}) do
		stats.totalEPAwarded = stats.totalEPAwarded + (InfinityLootEPGP:GetPlayerEP(player) or 0)
		stats.totalGPAwarded = stats.totalGPAwarded + (InfinityLootEPGP:GetPlayerGP(player) or 0)
	end
	
	InfinityUtils:Info("═══ Loot System Statistics ═══", "AuctionUI")
	InfinityUtils:Info("Active Auctions: " .. stats.activeAuctions, "AuctionUI")
	InfinityUtils:Info("Closed Auctions: " .. stats.closedAuctions, "AuctionUI")
	InfinityUtils:Info("Total EP Awarded: " .. stats.totalEPAwarded, "AuctionUI")
	InfinityUtils:Info("Total GP Awarded: " .. stats.totalGPAwarded, "AuctionUI")
	
	local accessStats = InfinityLootAccessControl:GetStats()
	InfinityUtils:Info("─── Roles ───", "AuctionUI")
	InfinityUtils:Info("Admins: " .. accessStats.totalAdmins, "AuctionUI")
	InfinityUtils:Info("Managers: " .. accessStats.totalManagers, "AuctionUI")
	InfinityUtils:Info("Assistants: " .. accessStats.totalAssistants, "AuctionUI")
	InfinityUtils:Info("Members: " .. accessStats.totalMembers, "AuctionUI")
end

function InfinityLootAuctionUI:ShowAuditLog()
	if not InfinityLootAccessControl:CanDoAction("manage_auctions") then
		return
	end
	
	local log = InfinityLootAccessControl:GetAuditLog(20)
	
	if not log or #log == 0 then
		InfinityUtils:Info("No audit log entries", "AuctionUI")
		return
	end
	
	InfinityUtils:Info("═══ Audit Log (Last 20 Entries) ═══", "AuctionUI")
	
	for _, entry in ipairs(log) do
		InfinityUtils:Info(
			string.format(
				"[%s] %s: %s",
				entry.action,
				entry.player,
				entry.details or ""
			),
			"AuctionUI"
		)
	end
end

function InfinityLootAuctionUI:ShowRoleList()
	if not InfinityLootAccessControl:CanDoAction("manage_roles") then
		return
	end
	
	local roles = InfinityLootAccessControl:GetAllRoles()
	
	InfinityUtils:Info("═══ Guild Roles ═══", "AuctionUI")
	
	local admins = InfinityLootAccessControl:GetPlayersWithRole("admin")
	InfinityUtils:Info("Admins: " .. table.concat(admins, ", "), "AuctionUI")
	
	local managers = InfinityLootAccessControl:GetPlayersWithRole("manager")
	InfinityUtils:Info("Managers: " .. (table.concat(managers, ", ") or "None"), "AuctionUI")
	
	local assistants = InfinityLootAccessControl:GetPlayersWithRole("assistant")
	InfinityUtils:Info("Assistants: " .. (table.concat(assistants, ", ") or "None"), "AuctionUI")
end

-- ============================================================================
-- DEBUG COMMANDS
-- ============================================================================

function InfinityLootAuctionUI:HandleDebugCommand(args)
	local subcommand = args[2] or ""
	
	if subcommand == "on" then
		self:EnableDebugLogging()
	elseif subcommand == "off" then
		self:DisableDebugLogging()
	else
		InfinityUtils:Warning("Usage: /loot debug on|off", "AuctionUI")
	end
end

function InfinityLootAuctionUI:EnableDebugLogging()
	InfinityUtils:Info("Debug logging enabled", "AuctionUI")
	-- Would enable detailed logging
end

function InfinityLootAuctionUI:DisableDebugLogging()
	InfinityUtils:Info("Debug logging disabled", "AuctionUI")
	-- Would disable detailed logging
end

-- ============================================================================
-- HELP TEXT
-- ============================================================================

function InfinityLootAuctionUI:ShowHelp()
	print("\n" .. "═══════════════════════════════════════════")
	print("         InfinityLoot Auction System")
	print("═══════════════════════════════════════════\n")
	print("AUCTION COMMANDS:")
	print("  /loot auction create --mode open|closed|vickrey|anonymous|tiered|antisnipe")
	print("                       --duration <seconds> --minbid <amount>")
	print("  /loot auction list              - Show active auctions")
	print("  /loot auction history           - Show closed auctions")
	print("  /loot auction close <id>        - Close auction (admin only)")
	print("\nBIDDING:")
	print("  /bid <auctionId> <amount> [tier] - Place local bid")
	print("  Auctions are local; item and point awards are manual.")
	print("\nMANAGEMENT:")
	print("  /loot stats                     - Show loot statistics")
	print("  /loot audit                     - Show action audit log (admin)")
	print("  /loot role set <player> <role> - Assign role (admin)")
	print("  /loot role list                 - Show all roles")
	print("\nDEBUG:")
	print("  /loot debug on|off              - Enable/disable debug logging")
	print("\n" .. "═══════════════════════════════════════════\n")
end

function InfinityLootAuctionUI:ShowAuctionHelp()
	print("\n" .. "Auction Commands:")
	print("  /loot auction create --mode <mode> --duration <sec> --minbid <amount>")
	print("  /loot auction list")
	print("  /loot auction history")
	print("  /loot auction close <id>")
	print("\nBidding modes: open, closed, vickrey, anonymous, tiered, antisnipe\n")
end

-- ============================================================================
-- FRAME FUNCTIONS (For future UI expansion)
-- ============================================================================

function InfinityLootAuctionUI:ShowAuctionFrame(auctionId)
	if not self.frames.main then
		self:CreateAuctionFrame()
	end
	self.selectedAuctionId = auctionId
	self.frames.main:Show()
	self:UpdateAuctionFrame()
end

function InfinityLootAuctionUI:CreateAuctionFrame()
	if self.frames.main then
		return self.frames.main
	end

	local frame = CreateFrame("Frame", "InfinityAuctionFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(520, 380)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.SetTitle then
		frame:SetTitle("Infinity Loot Auctions")
	elseif frame.TitleText then
		frame.TitleText:SetText("Infinity Loot Auctions")
	end

	local listFrame = CreateFrame("Frame", nil, frame)
	listFrame:SetSize(490, 290)
	listFrame:SetPoint("TOPLEFT", 15, -35)
	frame.listFrame = listFrame

	local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	refreshBtn:SetSize(90, 22)
	refreshBtn:SetPoint("BOTTOMLEFT", 15, 12)
	refreshBtn:SetText("Refresh")
	refreshBtn:SetScript("OnClick", function()
		InfinityLootAuctionUI:UpdateAuctionFrame()
	end)
	local create = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	create:SetSize(105, 22)
	create:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)
	create:SetText("Create")
	create:SetScript("OnClick", function() self:ShowCreateEditor() end)
	local bid = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	bid:SetSize(105, 22)
	bid:SetPoint("LEFT", create, "RIGHT", 8, 0)
	bid:SetText("Custom bid")
	bid:SetScript("OnClick", function() self:ShowBidEditor() end)

	frame:SetScript("OnUpdate", function(_, elapsed)
		InfinityLootAuctionUI.lastUpdate = InfinityLootAuctionUI.lastUpdate + (elapsed or 0)
		if InfinityLootAuctionUI.lastUpdate >= InfinityLootAuctionUI.updateRate then
			InfinityLootAuctionUI.lastUpdate = 0
			InfinityLootAuctionUI:UpdateAuctionFrame()
		end
	end)

	frame:Hide()
	self.frames.main = frame
	return frame
end

local function AuctionInput(frame, labelText, x, offset, width, max)
	local label = InfinityUIFramework:CreateLabel(frame, labelText)
	label:SetPoint("TOPLEFT", x, -43)
	local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	input:SetSize(width, 20)
	input:SetPoint("TOPLEFT", x + offset, -38)
	input:SetAutoFocus(false)
	input:SetMaxLetters(max)
	return input
end

local function PublicInput(input)
	local value = input:GetText()
	if _G.issecretvalue and issecretvalue(value) then return nil end
	return type(value) == "string" and value:match("^%s*(.-)%s*$") or nil
end

function InfinityLootAuctionUI:ShowCreateEditor()
	if not self.createFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootAuctionCreateWindow", "Create Local Auction", 650, 400)
		self.createDuration = AuctionInput(frame, "Seconds", 15, 60, 75, 8)
		self.createMinimum = AuctionInput(frame, "Minimum", 185, 65, 75, 10)
		self.createDuration:SetText("60")
		self.createMinimum:SetText("10")
		local rows = {}
		for _, mode in ipairs({ "open", "closed", "vickrey", "anonymous", "tiered", "antisnipe" }) do
			local selectedMode = mode
			rows[#rows + 1] = { text = "Create " .. mode .. " auction with cursor item", onClick = function()
				local duration, minimum = PublicInput(self.createDuration), PublicInput(self.createMinimum)
				local seconds, amount = tonumber(duration or ""), tonumber(minimum or "")
				local cursorType, _, link
				if _G.GetCursorInfo then cursorType, _, link = GetCursorInfo() end
				if _G.issecretvalue and (issecretvalue(cursorType) or issecretvalue(link)) then cursorType, link = nil, nil end
				if cursorType ~= "item" or type(link) ~= "string" or #link > 1024 or not link:match("|Hitem:%d+")
					or not seconds or seconds ~= seconds or seconds < 1 or seconds > 86400 or seconds ~= math.floor(seconds)
					or not amount or amount ~= amount or amount < 1 or amount > 1000000000 or amount ~= math.floor(amount) then
					self.confirmCreate = nil
					InfinityUtils:Warning("Pick up an item and enter valid duration and minimum bid.", "AuctionUI")
					return
				end
				local pending = self.confirmCreate
				if not pending or pending.link ~= link or pending.mode ~= selectedMode
					or pending.seconds ~= seconds or pending.amount ~= amount then
					self.confirmCreate = { link = link, mode = selectedMode, seconds = seconds, amount = amount }
					frame.status:SetText("Create " .. selectedMode .. " auction for " .. link .. "? Click again.")
					return
				end
				self.confirmCreate = nil
				self:CreateAuctionDialog({ "auction", "create", "--mode", selectedMode,
					"--duration", tostring(seconds), "--minbid", tostring(amount) })
			end }
		end
		frame:SetItems(rows)
		frame.status:SetText("Pick up an item. Local only; awards and points are manual.")
		self.createFrame = frame
	end
	self.confirmCreate = nil
	self.createFrame:Show()
end

function InfinityLootAuctionUI:ShowBidEditor()
	if not self.bidFrame then
		local frame = InfinityUIFramework:CreateListWindow("InfinityLootAuctionBidWindow", "Local Auction Bid", 650, 300)
		self.bidID = AuctionInput(frame, "Auction ID", 15, 70, 95, 40)
		self.bidAmount = AuctionInput(frame, "GP", 195, 25, 85, 10)
		self.bidTier = AuctionInput(frame, "Tier", 325, 35, 100, 30)
		frame:SetItems({ { text = "Place local bid | tier required for tiered auctions", onClick = function()
			local id, amount, tier = PublicInput(self.bidID), PublicInput(self.bidAmount), PublicInput(self.bidTier)
			if not id or not amount or not tier then InfinityUtils:Warning("Bid input unavailable or protected.", "AuctionUI"); return end
			local value = tonumber(amount)
			if id == "" or not value or value ~= value or value < 1 or value > 1000000000 or value ~= math.floor(value) then
				InfinityUtils:Warning("Enter a valid auction ID and positive integer bid.", "AuctionUI")
				return
			end
			if InfinityLootAuctions:PlaceBid(id, UnitName("player"), value, tier ~= "" and tier or nil) then
				frame.status:SetText("Local bid placed.")
				self:UpdateAuctionFrame()
			else
				InfinityUtils:Warning("Could not place local bid.", "AuctionUI")
			end
		end } })
		frame.status:SetText("Local auction only; tier examples: MS, OS, Offspec, Bank.")
		self.bidFrame = frame
	end
	self.bidFrame:Show()
end

function InfinityLootAuctionUI:UpdateAuctionFrame()
	local frame = self.frames.main
	if not frame or not frame:IsShown() then
		return
	end

	local list = frame.listFrame
	list.rows = list.rows or {}
	if not list.emptyText then
		list.emptyText = list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		list.emptyText:SetPoint("TOPLEFT", 5, -5)
		list.emptyText:SetText("No active local auctions.")
	end
	local auctions = InfinityLootAuctions:GetActiveAuctions()
	for index, auction in ipairs(auctions) do
		local row = list.rows[index]
		if not row then
			row = CreateFrame("Frame", nil, list)
			row:SetSize(490, 24)
			row:SetPoint("TOPLEFT", 0, -5 - (index - 1) * 26)
			row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.label:SetPoint("LEFT", 5, 0)
			row.label:SetWidth(320)
			row.label:SetJustifyH("LEFT")
			row.bid = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
			row.bid:SetSize(70, 20)
			row.bid:SetPoint("RIGHT", -80, 0)
			row.bid:SetScript("OnClick", function()
				local current = InfinityLootAuctions:GetAuction(row.id)
				if current then
					local amount = current.bids[1] and current.bids[1].amount + current.bidIncrement or current.minimumBid
					InfinityLootAuctions:PlaceBid(current.id, UnitName("player"), amount)
					self:UpdateAuctionFrame()
				end
			end)
			row.close = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
			row.close:SetSize(65, 20)
			row.close:SetPoint("RIGHT", -8, 0)
			row.close:SetText("Close")
			row.close:SetScript("OnClick", function()
				if _G.InfinityLootAccessControl and InfinityLootAccessControl:CanDoAction("close_auctions") then
					InfinityLootAuctions:CloseAuction(row.id)
					self:UpdateAuctionFrame()
				end
			end)
			list.rows[index] = row
		end
		row.id = auction.id
		local open = auction.biddingMode == "open" or auction.biddingMode == "antisnipe"
		local bid = open and (auction.bids[1] and tostring(auction.bids[1].amount) or "none") or "hidden"
		row.label:SetText(string.format("[%s] %s (%s) - %s (%ds)", auction.id, auction.itemName,
			auction.biddingMode, bid, math.max(0, math.floor(auction.endTime - GetTime()))))
		row.bid:SetText("Bid +" .. auction.bidIncrement)
		row.bid:SetShown(open)
		row:Show()
	end
	for index = #auctions + 1, #list.rows do list.rows[index]:Hide() end
	list.emptyText:SetShown(#auctions == 0)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function InfinityLootAuctionUI:Initialize()
	InfinityUtils:Info("Auction UI system initializing...", "AuctionUI")
	
	self:RegisterCommands()
	
	InfinityUtils:Info("Auction UI system initialized", "AuctionUI")
end

return InfinityLootAuctionUI
