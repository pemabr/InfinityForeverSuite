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
	InfinityUtils:Info("Registering auction slash commands...", "AuctionUI")
	
	-- /loot auction create --mode open --duration 60 --minbid 10
	SLASH_LOOTAUCTION1 = "/loot"
	SLASH_LOOTAUCTION2 = "/auction"
	
	function SlashCmdList.LOOTAUCTION(msg, editbox)
		InfinityLootAuctionUI:HandleCommand(msg)
	end
	
	InfinityUtils:Info("Slash commands registered", "AuctionUI")
end

function InfinityLootAuctionUI:HandleCommand(msg)
	local args = {strsplit(" ", msg)}
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
		InfinityUtils:Info("Auction " .. auctionId .. " closed", "AuctionUI")
	elseif subcommand == "list" then
		self:ShowAuctionList()
	elseif subcommand == "history" then
		self:ShowAuctionHistory()
	elseif subcommand == "ui" or subcommand == "open" then
		self:CreateAuctionFrame()
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
	local itemLink = select(3, GetCursorInfo())
	
	for i = 3, #args, 2 do
		if args[i] == "--mode" then
			mode = args[i + 1]
		elseif args[i] == "--duration" then
			duration = tonumber(args[i + 1]) or 60
		elseif args[i] == "--minbid" then
			minbid = tonumber(args[i + 1]) or 10
		end
	end
	
	if not InfinityLootAuctions:IsValidBiddingMode(mode) then
		InfinityUtils:Warning("Invalid bidding mode: " .. tostring(mode), "AuctionUI")
		return
	end
	
	if not itemLink then
		InfinityUtils:Warning("Hold an item on your cursor or open /loot auction ui", "AuctionUI")
		return
	end
	
	local auctionId = InfinityLootAuctions:CreateAuction(
		itemLink,
		mode,
		duration,
		{ minimumBid = minbid }
	)
	
	if auctionId then
		InfinityUtils:Info(
			"Auction created: " .. itemLink .. " (" .. mode .. " mode, " .. duration .. "s duration)",
			"AuctionUI"
		)
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
		InfinityUtils:Warning("Usage: /loot bid <auctionId> <amount>", "AuctionUI")
		return
	end
	
	local player = UnitName("player")
	local success = InfinityLootAuctions:PlaceBid(auctionId, player, amount)
	
	if success then
		InfinityUtils:Info(
			"Bid placed: " .. amount .. " pts on auction " .. auctionId,
			"AuctionUI"
		)
		self:UpdateAuctionFrame()
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
	local auctions = InfinityLootAuctions:GetActiveAuctions()
	if not auctions or #auctions == 0 then
		InfinityUtils:Info("No active auctions", "AuctionUI")
		return
	end
	InfinityUtils:Info("Active Auctions:", "AuctionUI")
	for _, auction in ipairs(auctions) do
		local bidCount = auction.bids and #auction.bids or 0
		local timeLeft = math.max(0, math.floor((auction.endTime or 0) - GetTime()))
		InfinityUtils:Info(
			string.format(
				"[%s] %s - Mode: %s, Bids: %d, Time: %ds",
				auction.id,
				auction.itemName or auction.itemLink or "Item",
				auction.biddingMode,
				bidCount,
				timeLeft
			),
			"AuctionUI"
		)
	end
end

function InfinityLootAuctionUI:ShowAuctionHistory()
	local history = InfinityLootAuctions:GetAuctionHistory(10)
	if not history or #history == 0 then
		InfinityUtils:Info("No auction history", "AuctionUI")
		return
	end
	InfinityUtils:Info("Recent Closed Auctions (last 10):", "AuctionUI")
	for _, auction in ipairs(history) do
		InfinityUtils:Info(
			string.format(
				"[%s] %s - Winner: %s (%d pts) - Mode: %s",
				auction.auctionId or "closed",
				auction.itemName or "Unknown Item",
				auction.winner or "No Winner",
				auction.winningBid or 0,
				auction.biddingMode or "open"
			),
			"AuctionUI"
		)
	end
end

function InfinityLootAuctionUI:ShowStats()
	local stats = {
		activeAuctions = #(InfinityLootAuctions:GetActiveAuctions() or {}),
		closedAuctions = #(InfinityLootAuctions:GetAuctionHistory(1000) or {}),
		totalGPAwarded = 0,
		totalEPAwarded = 0,
	}
	if InfinityLootEPGP and InfinityLootEPGP.GetAllPlayers then
		local players = InfinityLootEPGP:GetAllPlayers()
		for _, player in ipairs(players or {}) do
			stats.totalEPAwarded = stats.totalEPAwarded + (InfinityLootEPGP:GetPlayerEP(player) or 0)
			stats.totalGPAwarded = stats.totalGPAwarded + (InfinityLootEPGP:GetPlayerGP(player) or 0)
		end
	end
	InfinityUtils:Info("Loot Stats — Active: " .. stats.activeAuctions .. ", Closed: " .. stats.closedAuctions .. ", Total EP: " .. stats.totalEPAwarded .. ", Total GP: " .. stats.totalGPAwarded, "AuctionUI")
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
	for _, entry in ipairs(log) do
		InfinityUtils:Info(string.format("[%s] %s: %s", entry.action, entry.player, entry.details or ""), "AuctionUI")
	end
end

function InfinityLootAuctionUI:ShowRoleList()
	if not InfinityLootAccessControl:CanDoAction("manage_roles") then
		return
	end
	local admins = InfinityLootAccessControl:GetPlayersWithRole("admin") or {}
	local managers = InfinityLootAccessControl:GetPlayersWithRole("manager") or {}
	local assistants = InfinityLootAccessControl:GetPlayersWithRole("assistant") or {}
	InfinityUtils:Info("Admins: " .. table.concat(admins, ", "), "AuctionUI")
	InfinityUtils:Info("Managers: " .. table.concat(managers, ", "), "AuctionUI")
	InfinityUtils:Info("Assistants: " .. table.concat(assistants, ", "), "AuctionUI")
end

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
	self.db.debug = true
	InfinityUtils:Info("Debug logging enabled", "AuctionUI")
end

function InfinityLootAuctionUI:DisableDebugLogging()
	self.db.debug = false
	InfinityUtils:Info("Debug logging disabled", "AuctionUI")
end

function InfinityLootAuctionUI:ShowHelp()
	print("InfinityLoot Auction Commands:")
	print("  /loot auction ui                - Open interactive Auction Desk window")
	print("  /loot auction create --mode open|closed|vickrey|anonymous|tiered|antisnipe --duration 60 --minbid 50")
	print("  /loot auction list | history | close <id>")
	print("  /loot bid <auctionId> <amount>")
end

function InfinityLootAuctionUI:ShowAuctionHelp()
	self:ShowHelp()
end

-- ============================================================================
-- INTERACTIVE AUCTION DESK FRAME (Replaces old placeholders)
-- ============================================================================

function InfinityLootAuctionUI:CreateAuctionFrame()
	local UI = _G.InfinityUIFramework
	if not UI then return end

	if self.frames.main then
		self.frames.main:Show()
		self:UpdateAuctionFrame()
		return self.frames.main
	end

	local frame = UI:CreateFrame("InfinityLootAuctionDesk", UIParent, 700, 460, "InfinityLoot — Live Auction Desk")
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	-- Quick Create Bar
	local itemBox = UI:CreateInputBox(frame, 190, 24)
	itemBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -48)
	itemBox:SetText("Kiss of the Spider")

	local minBox = UI:CreateInputBox(frame, 70, 24)
	minBox:SetPoint("LEFT", itemBox, "RIGHT", 8, 0)
	minBox:SetText("100")

	local selectedMode = "open"
	local modes = { "open", "vickrey", "tiered", "antisnipe", "anonymous", "closed" }
	local modeIdx = 1
	local modeBtn = UI:CreateButton(frame, "Mode: open", 118, 24, function(selfBtn)
		modeIdx = (modeIdx % #modes) + 1
		selectedMode = modes[modeIdx]
		selfBtn.label:SetText("Mode: " .. selectedMode)
	end)
	modeBtn:SetPoint("LEFT", minBox, "RIGHT", 8, 0)

	local startBtn = UI:CreateButton(frame, "Start Auction", 120, 24, function()
		local rawName = strtrim(itemBox:GetText() or "")
		if rawName == "" then return end
		local link = "|cffa335ee|Hitem:0:0:0:0|h[" .. rawName .. "]|h|r"
		local minBid = tonumber(minBox:GetText()) or 50
		InfinityLootAuctions:CreateAuction(link, selectedMode, 120, { minimumBid = minBid })
		self:UpdateAuctionFrame()
	end, true)
	startBtn:SetPoint("LEFT", modeBtn, "RIGHT", 8, 0)

	local listPanel = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -84)
	listPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
	UI:ApplyBackdrop(listPanel, 0.09, 0.11, 0.16, 0.95, 0.22, 0.28, 0.38, 0.85)
	frame.listPanel = listPanel

	frame:SetScript("OnUpdate", function(_, elapsed)
		self.lastUpdate = self.lastUpdate + elapsed
		if self.lastUpdate >= self.updateRate then
			self.lastUpdate = 0
			self:UpdateAuctionFrame()
		end
	end)

	self.frames.main = frame
	self:UpdateAuctionFrame()
	frame:Show()
	return frame
end

function InfinityLootAuctionUI:ShowAuctionFrame(_)
	self:CreateAuctionFrame()
end

function InfinityLootAuctionUI:UpdateAuctionFrame()
	local frame = self.frames.main
	if not frame or not frame:IsShown() then return end
	local UI = _G.InfinityUIFramework
	UI:ClearContainer(frame.listPanel)

	local auctions = InfinityLootAuctions:GetActiveAuctions() or {}
	if #auctions == 0 then
		local empty = UI:CreateLabel(frame.listPanel, "No active auctions. Enter an item name above and click Start Auction.", 0.65, 0.72, 0.82)
		empty:SetPoint("TOPLEFT", frame.listPanel, "TOPLEFT", 16, -18)
		return
	end

	local y = -16
	for _, auc in ipairs(auctions) do
		local remaining = math.max(0, math.floor((auc.endTime or 0) - GetTime()))
		local topBid = (auc.bids and auc.bids[1]) and auc.bids[1].amount or auc.minimumBid
		local label = UI:CreateLabel(
			frame.listPanel,
			string.format("|cffa335ee%s|r  (%s)  |  Top: %d  |  %ds", auc.itemName or "Item", auc.biddingMode, topBid, remaining)
		)
		label:SetPoint("TOPLEFT", frame.listPanel, "TOPLEFT", 14, y)

		local quickBidBtn = UI:CreateButton(frame.listPanel, "Bid +" .. tostring(topBid + 10), 96, 22, function()
			InfinityLootAuctions:PlaceBid(auc.id, UnitName("player") or "Officer", topBid + 10, "MS")
			self:UpdateAuctionFrame()
		end, true)
		quickBidBtn:SetPoint("TOPRIGHT", frame.listPanel, "TOPRIGHT", -116, y + 3)

		local closeBtn = UI:CreateButton(frame.listPanel, "Close", 92, 22, function()
			InfinityLootAuctions:CloseAuction(auc.id)
			self:UpdateAuctionFrame()
		end)
		closeBtn:SetPoint("TOPRIGHT", frame.listPanel, "TOPRIGHT", -14, y + 3)

		y = y - 34
	end
end

function InfinityLootAuctionUI:Initialize()
	InfinityUtils:Info("Auction UI system initializing...", "AuctionUI")
	self:RegisterCommands()
	InfinityUtils:Info("Auction UI system initialized", "AuctionUI")
end

return InfinityLootAuctionUI
