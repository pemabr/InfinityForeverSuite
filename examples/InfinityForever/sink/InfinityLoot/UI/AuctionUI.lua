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
		InformationUtils:Info("Auction " .. auctionId .. " closed", "AuctionUI")
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
	local itemLink = GetCursorInfo()
	
	for i = 3, #args, 2 do
		if args[i] == "--mode" then
			mode = args[i + 1]
		elseif args[i] == "--duration" then
			duration = tonumber(args[i + 1]) or 60
		elseif args[i] == "--minbid" then
			minbid = tonumber(args[i + 1]) or 10
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
	if not itemLink then
		local cursorItemLink = select(3, GetCursorInfo())
		if cursorItemLink then
			itemLink = cursorItemLink
		else
			InfinityUtils:Warning("Hold an item or provide item link", "AuctionUI")
			return
		end
	end
	
	-- Create auction
	local auctionId = InfinityLootAuctions:CreateAuction(
		itemLink,
		mode,
		duration,
		{minimumBid = minbid}
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
		InfinityUtils:Warning("Usage: /bid <auctionId> <amount>", "AuctionUI")
		return
	end
	
	local player = UnitName("player")
	local success = InfinityLootAuctions:PlaceBid(auctionId, player, amount)
	
	if success then
		InfinityUtils:Info(
			"Bid placed: " .. amount .. " GP on auction " .. auctionId,
			"AuctionUI"
		)
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
		InfinityUtils:Info("No active auctions", "AuctionUI")
		return
	end
	
	InfinityUtils:Info("Active Auctions:", "AuctionUI")
	
	for _, auction in ipairs(auctions) do
		local bidCount = auction.bids and #auction.bids or 0
		local timeLeft = math.max(0, auction.duration - (GetTime() - auction.startTime))
		
		InfinityUtils:Info(
			string.format(
				"[%s] %s - Mode: %s, Bids: %d, Time: %ds",
				auction.id,
				auction.itemLink,
				auction.biddingMode,
				bidCount,
				timeLeft
			),
			"AuctionUI"
		)
	end
end

function InfinityLootAuctionUI:ShowAuctionHistory()
	-- Get closed auctions
	local history = InfinityLootAuctions:GetAuctionHistory(10)
	
	if not history or #history == 0 then
		InfinityUtils:Info("No auction history", "AuctionUI")
		return
	end
	
	InfinityUtils:Info("Recent Closed Auctions (last 10):", "AuctionUI")
	
	for _, auction in ipairs(history) do
		InfinityUtils:Info(
			string.format(
				"[%s] %s - Winner: %s (%.0f GP) - Mode: %s",
				auction.id,
				auction.itemLink,
				auction.winner or "Unknown",
				auction.winnerPrice or 0,
				auction.biddingMode
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
	print("  /bid <auctionId> <amount>       - Place bid on auction")
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
	-- Placeholder for frame implementation
	-- Would create a UI frame showing the auction details
	InfinityUtils:Info("Auction frame would appear here: " .. auctionId, "AuctionUI")
end

function InfinityLootAuctionUI:CreateAuctionFrame()
	-- Placeholder for frame creation
	-- Would create main auction display frame
end

function InfinityLootAuctionUI:UpdateAuctionFrame()
	-- Placeholder for frame updates
	-- Would update active auctions every 1 second
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
