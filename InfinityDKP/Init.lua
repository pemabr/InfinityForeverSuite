-- InfinityDKP Initialization
-- Setup and integration with InfinityCore

local addonName = "InfinityDKP"
local addonVersion = "1.1.0"
local initialized = false

local function InitializeDKP()
	-- Wait for InfinityCore to load
	if not _G.InfinityCore then
		return  -- Will retry when INFINITY_DATA_LOADED fires
	end
	if initialized then return end

	-- Modules are loaded via .toc file, so globals are already created
	-- Use the globals that were set up by the module files
	local Engine = InfinityDKPEngine or _G.InfinityDKPEngine
	local Attendance = InfinityDKPAttendanceTracker
	local Points = InfinityDKPPoints or _G.InfinityDKPPoints
	local Auctions = InfinityDKPAuctions or _G.InfinityDKPAuctions
	local History = InfinityDKPHistory or _G.InfinityDKPHistory
	local Reports = InfinityDKPReports or _G.InfinityDKPReports
	local GuildSync = InfinityDKPGuildSync or _G.InfinityDKPGuildSync
	local GuildAuctions = InfinityDKPGuildAuctions or _G.InfinityDKPGuildAuctions
	local UnifiedAuctions = InfinityDKPUnifiedAuctions or _G.InfinityDKPUnifiedAuctions
	local TaxSystem = InfinityDKPTaxSystem or _G.InfinityDKPTaxSystem
	local GuildBankDonations = InfinityDKPGuildBankDonations or _G.InfinityDKPGuildBankDonations
	local PlayerTrading = InfinityDKPPlayerTrading or _G.InfinityDKPPlayerTrading
	local BossAwards = _G.InfinityBossKillAwards
	local UI = InfinityDKPUI or _G.InfinityDKPUI
    
    -- Initialize
    Engine:Initialize()
    Attendance:Initialize(Engine.db)
    Points:Initialize(Engine.db)
    History:Initialize(Engine.db)
    if TaxSystem and type(TaxSystem.Initialize) == "function" then TaxSystem:Initialize(Engine.db) end
    if GuildBankDonations and type(GuildBankDonations.Initialize) == "function" then GuildBankDonations:Initialize(Engine.db) end
    if BossAwards and type(BossAwards.InitializeLocal) == "function" then BossAwards:InitializeLocal(Engine.db) end
    GuildSync:Initialize()
    GuildAuctions:Initialize()
    PlayerTrading:Initialize(Engine.db)
    if UI and UI.Initialize then
        UI:Initialize()
    end
    if _G.InfinityDKPTooltipPriceInfo and _G.InfinityDKPTooltipPriceInfo.Initialize then
        pcall(function() _G.InfinityDKPTooltipPriceInfo:Initialize() end)
    end
    
    -- Register with InfinityCore
    InfinityCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Infinity Forever",
        description = "Local points, encounter attendance, and loot history",
        enabled = true,
    })
    
    -- Command registration
    if InfinityCore.RegisterCommand then
        InfinityCore:RegisterCommand("/dkp", "Toggle DKP window", function()
            UI:Toggle()
        end)

        InfinityCore:RegisterCommand("/dkp add", "Add a local player", function(args)
            local name = type(args) == "string" and args:match("^%s*(%S+)%s*$")
            if not name then
                print("Usage: /dkp add <player>")
            elseif Engine:AddPlayer(name) then
                print("Added local DKP player: " .. name)
                UI:Update()
            else
                print("Player already exists: " .. name)
            end
        end)

        local function AwardPoints(kind, name, rawAmount, reason)
            local amount = tonumber(rawAmount)
            if not name or not amount or amount ~= amount or amount >= math.huge
                or amount <= 0 or amount ~= math.floor(amount) then
                print("Usage: /dkp " .. kind .. " <player> <positive integer> [reason]")
                return false
            end
            if not Engine:GetPlayer(name) then
                print("Unknown local player: " .. name .. ". Add them with /dkp add.")
                return false
            end
            if reason == "" then reason = "Manual adjustment" end
            local awarded
            if kind == "ep" then
                awarded = Engine:AwardEP(name, amount, reason)
            else
                awarded = Engine:AwardGP(name, amount, nil, reason)
            end
            if not awarded then
                print("Could not award local " .. kind:upper() .. " to " .. name)
                return false
            end
            Points:LogTransaction(name, kind, amount, reason)
            print("Local " .. kind:upper() .. ": " .. name .. " +" .. amount)
            UI:Update()
            return true
        end
        local function ManualPoints(kind, args)
            local name, amount, reason
            if type(args) == "string" then
                name, amount, reason = args:match("^%s*(%S+)%s+(%S+)%s*(.-)%s*$")
            end
            AwardPoints(kind, name, amount, reason)
        end
        InfinityCore:RegisterCommand("/dkp ep", "Award local EP", function(args) ManualPoints("ep", args) end)
        InfinityCore:RegisterCommand("/dkp gp", "Award local GP", function(args) ManualPoints("gp", args) end)
        local function AdjustDKP(name, amount, reason)
            if not name or type(amount) ~= "number" or amount ~= amount or amount == 0
                or math.abs(amount) > 1000000000 or amount ~= math.floor(amount) then
                print("Usage: /dkp points <player> <nonzero signed integer> [reason]")
                return false
            end
            if not Engine:GetPlayer(name) then
                print("Unknown local player: " .. name .. ". Add them with /dkp add.")
                return false
            end
            if reason == "" then reason = "Manual adjustment" end
            if not Engine:AdjustDKP(name, amount, reason) then
                print("Could not adjust local DKP; check the saved balance and +/-1 billion limit.")
                return false
            end
            Points:LogTransaction(name, "dkp", amount, reason)
            print(string.format("Local DKP: %s %+d", name, amount))
            UI:Update()
            return true
        end
        InfinityCore:RegisterCommand("/dkp points", "Adjust local DKP", function(args)
            local name, amount, reason
            if type(args) == "string" then name, amount, reason = args:match("^%s*(%S+)%s+(%S+)%s*(.-)%s*$") end
            AdjustDKP(name, tonumber(amount), reason)
        end)
        InfinityCore:RegisterCommand("/dkp system", "Select local points system", function(args)
            local system = type(args) == "string" and args:match("^%s*(%a+)%s*$")
            system = system and system:lower()
            if system ~= "dkp" and system ~= "epgp" then
                print("Current system: " .. Engine.system_type .. ". Usage: /dkp system dkp|epgp")
                return
            end
            Engine:SetSystemType(system)
            print("Local points system: " .. system)
            UI:Update()
        end)
        InfinityCore:RegisterCommand("/dkp award", "Record a local loot award", function(args)
            local name, amount, item
            if type(args) == "string" then
                name, amount, item = args:match("^%s*(%S+)%s+(%S+)%s+(.+)%s*$")
            end
            if not name or not item or item:match("^%s*$") then
                print("Usage: /dkp award <player> <GP> <item link or name>")
                return
            end
            if AwardPoints("gp", name, amount, "Loot: " .. item) then
                History:RecordAward(name, item, tonumber(item:match("item:(%d+)")), "manual", tonumber(amount), "Loot award")
                UI:Update()
            end
        end)
        InfinityCore:RegisterCommand("/dkp spend", "Record a DKP loot award", function(args)
            local name, rawAmount, item
            if type(args) == "string" then name, rawAmount, item = args:match("^%s*(%S+)%s+(%S+)%s+(.+)%s*$") end
            local amount = tonumber(rawAmount)
            if not name or not item or item:match("^%s*$") or not amount or amount <= 0
                or amount ~= amount or amount > 1000000000 or amount ~= math.floor(amount) then
                print("Usage: /dkp spend <player> <positive DKP> <item link or name>")
                return
            end
            if AdjustDKP(name, -amount, "Loot: " .. item) then
                History:RecordAward(name, item, tonumber(item:match("item:(%d+)")), "dkp", amount, "Loot award")
                UI:Update()
            end
        end)
        InfinityCore:RegisterCommand("/dkp sync", "Guild DKP snapshot help", function()
            print("Guild-master snapshots: /dkp sync send|apply|discard|undo")
            print("Apply replaces local player points; loot and attendance history remain local.")
        end)
        InfinityCore:RegisterCommand("/dkp sync send", "Send guild DKP snapshot", function() GuildSync:Send() end)
        InfinityCore:RegisterCommand("/dkp sync apply", "Apply guild DKP snapshot", function() GuildSync:Apply() end)
        InfinityCore:RegisterCommand("/dkp sync discard", "Discard guild DKP snapshot", function() GuildSync:Discard() end)
        InfinityCore:RegisterCommand("/dkp sync undo", "Restore points before last sync", function() GuildSync:Undo() end)

        InfinityCore:RegisterCommand("/dkp guildauction", "Guild auction help", function()
            print("Guild master: /dkp guildauction create <start> <seconds> <item link> | close | cancel")
            print("Members: /dkp guildauction bid <amount> | sync")
            print("Online guild members only; points and items are awarded manually.")
        end)
        InfinityCore:RegisterCommand("/dkp guildauction create", "Start a guild auction", function(args)
            local bid, duration, item
            if type(args) == "string" then bid, duration, item = args:match("^%s*(%d+)%s+(%d+)%s+(.+)%s*$") end
            if not item then
                print("Usage: /dkp guildauction create <start> <seconds> <item link>")
                return
            end
            GuildAuctions:Create(item, tonumber(bid), tonumber(duration))
        end)
        InfinityCore:RegisterCommand("/dkp guildauction bid", "Bid in the guild auction", function(args)
            local bid = type(args) == "string" and args:match("^%s*(%d+)%s*$")
            if not bid then print("Usage: /dkp guildauction bid <amount>"); return end
            GuildAuctions:Bid(tonumber(bid))
        end)
        InfinityCore:RegisterCommand("/dkp guildauction close", "Close the guild auction", function() GuildAuctions:Close() end)
        InfinityCore:RegisterCommand("/dkp guildauction cancel", "Cancel the guild auction", function() GuildAuctions:Close(true) end)
        InfinityCore:RegisterCommand("/dkp guildauction sync", "Request the current guild auction", function() GuildAuctions:Request() end)
        
        InfinityCore:RegisterCommand("/dkp report", "Generate DKP report", function()
            local report = Reports:GenerateFullReport()
            print(report)
        end)
        
        InfinityCore:RegisterCommand("/dkp priority", "Show priority list", function()
            local report = Reports:GeneratePriorityList()
            print(report)
        end)
        
        InfinityCore:RegisterCommand("/dkp attendance", "Show attendance report", function()
            local report = Reports:GenerateAttendanceReport()
            print(report)
        end)
        
        InfinityCore:RegisterCommand("/dkp loot", "Show loot history", function()
            local report = Reports:GenerateLootReport(7)
            print(report)
        end)
        
        local function ActiveAuction(id)
            local auction = UnifiedAuctions:GetAuctionDetails(id)
            return auction and auction.status == "active" and auction or nil
        end
        local function FinishAuction(auction)
            local winner = UnifiedAuctions:CloseAuction(auction.id)
            if winner then
                local instruction = Engine.system_type == Engine.SYSTEM_DKP and "/dkp spend"
                    or Engine.system_type == Engine.SYSTEM_EPGP and "/dkp award" or nil
                local suffix = instruction and (" Record points manually with " .. instruction .. ".")
                    or " No points were changed."
                print(string.format("Local auction %d: %s won %s for %d.%s",
                    auction.id, winner, auction.itemName, auction.winningBid, suffix))
            else
                print("Local auction " .. auction.id .. " closed without bids.")
            end
            UI:Update()
        end
        local function ScheduleAuction(auction)
            if not (_G.C_Timer and _G.C_Timer.After) then
                print("Auction timer unavailable; close it manually with /dkp auction close.")
                return
            end
            local function Check()
                if ActiveAuction(auction.id) ~= auction then return end
                local remaining = auction.endTime - GetTime()
                if remaining > 0 then
                    _G.C_Timer.After(remaining, Check)
                else
                    FinishAuction(auction)
                end
            end
            _G.C_Timer.After(auction.endTime - GetTime(), Check)
        end
        InfinityCore:RegisterCommand("/dkp auction create", "Create a local auction", function(args)
            local input = type(args) == "string" and args:match("^%s*(.-)%s*$")
            if not input or input == "" then
                print("Usage: /dkp auction create [starting bid] [seconds] <item>")
                return
            end
            local first = input:match("^(%S+)")
            local bid, duration, item
            if tonumber(first) then
                bid, duration, item = input:match("^(%S+)%s+(%S+)%s+(.+)$")
                if not item then
                    print("Usage: /dkp auction create [starting bid] [seconds] <item>")
                    return
                end
            else
                item, bid, duration = input, 1, 300
            end
            local id = UnifiedAuctions:CreateAuction(item, bid, duration)
            if id then
                local auction = ActiveAuction(id)
                print("Session-only auction " .. id .. " started. Bids and point awards are manual.")
                ScheduleAuction(auction)
                UI:Update()
            end
        end)
        InfinityCore:RegisterCommand("/dkp auction bid", "Enter a local bid", function(args)
            local id, player, amount
            if type(args) == "string" then id, player, amount = args:match("^%s*(%d+)%s+(%S+)%s+(%S+)%s*$") end
            id = tonumber(id)
            if not id or not player or not amount then
                print("Usage: /dkp auction bid <id> <local player> <amount>")
            elseif not Engine:GetPlayer(player) then
                print("Unknown local player: " .. player .. ". Add them with /dkp add.")
            elseif UnifiedAuctions:PlaceBid(id, player, amount) then
                print("Local bid: " .. player .. " on auction " .. id .. " for " .. amount)
                UI:Update()
            end
        end)
        InfinityCore:RegisterCommand("/dkp auction close", "Close a local auction", function(args)
            local id = type(args) == "string" and args:match("^%s*(%d+)%s*$")
            local auction = id and ActiveAuction(tonumber(id))
            if not auction then
                print("Active auction not found. Usage: /dkp auction close <id>")
                return
            end
            FinishAuction(auction)
        end)
        InfinityCore:RegisterCommand("/dkp auction cancel", "Cancel a local auction", function(args)
            local id = type(args) == "string" and args:match("^%s*(%d+)%s*$")
            local auction = id and ActiveAuction(tonumber(id))
            if not auction then
                print("Active auction not found. Usage: /dkp auction cancel <id>")
                return
            end
            UnifiedAuctions:CancelAuction(auction.id)
            print("Local auction " .. auction.id .. " cancelled; no winner or points awarded.")
            UI:Update()
        end)
        InfinityCore:RegisterCommand("/dkp auction list", "List local auctions", function()
            local auctions = UnifiedAuctions:GetActiveAuctions()
            print("Session-only auctions; points are not awarded automatically:")
            for _, auction in ipairs(auctions) do
                print(string.format("[%d] %s - %d (highest: %s; %.0fs left)",
                    auction.id, auction.itemName, auction.currentHighBid, auction.highestBidder or "None",
                    math.max(0, auction.endTime - GetTime())))
            end
        end)
        
        -- Tax commands
        InfinityCore:RegisterCommand("/dkp tax stats", "Show tax statistics", function()
            local stats = TaxSystem:GetGuildTaxStats()
            print("=== GUILD TAX STATS ===")
            print("Total Collected: " .. stats.totalCollected .. " gold")
            print("Players Taxed: " .. stats.playerCount)
            print("Tax Rate: " .. stats.taxRate)
        end)
        
        -- Tax filtering commands
        InfinityCore:RegisterCommand("/dkp tax whitelist mode", "Toggle tax whitelist mode", function(args)
            local enabled = (args == "on" or args == "true" or args == "1")
            TaxSystem:SetWhitelistMode(enabled)
        end)
        
        InfinityCore:RegisterCommand("/dkp tax whitelist add", "Add item to tax whitelist", function(args)
            if not args or args == "" then
                print("Usage: /dkp tax whitelist add [itemid]")
            else
                TaxSystem:WhitelistItem(args)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp tax whitelist remove", "Remove item from tax whitelist", function(args)
            if not args or args == "" then
                print("Usage: /dkp tax whitelist remove [itemid]")
            else
                TaxSystem:UnwhitelistItem(args)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp tax whitelist clear", "Clear entire tax whitelist", function()
            TaxSystem:ClearWhitelist()
        end)
        
        InfinityCore:RegisterCommand("/dkp tax whitelist list", "Show tax whitelist", function()
            local whitelist = TaxSystem:GetWhitelist()
            print("=== TAX WHITELIST ===")
            if not next(whitelist) then
                print("(empty)")
            else
                for itemId, _ in pairs(whitelist) do
                    print("- Item ID: " .. itemId)
                end
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp tax blacklist add", "Add item to tax blacklist", function(args)
            if not args or args == "" then
                print("Usage: /dkp tax blacklist add [itemid]")
            else
                TaxSystem:BlacklistItem(args)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp tax blacklist remove", "Remove item from tax blacklist", function(args)
            if not args or args == "" then
                print("Usage: /dkp tax blacklist remove [itemid]")
            else
                TaxSystem:UnblacklistItem(args)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp tax blacklist clear", "Clear entire tax blacklist", function()
            TaxSystem:ClearBlacklist()
        end)
        
        InfinityCore:RegisterCommand("/dkp tax blacklist list", "Show tax blacklist", function()
            local blacklist = TaxSystem:GetBlacklist()
            print("=== TAX BLACKLIST ===")
            if not next(blacklist) then
                print("(empty)")
            else
                for itemId, _ in pairs(blacklist) do
                    print("- Item ID: " .. itemId)
                end
            end
        end)
        
        -- Guild bank donation commands
        InfinityCore:RegisterCommand("/dkp donations", "Show donation statistics", function()
            local stats = GuildBankDonations:GetGuildDonationStats()
            print("=== GUILD BANK DONATIONS ===")
            print("Total Gold: " .. stats.totalGoldDonated .. " copper")
            print("Total Items Value: " .. stats.totalItemValueDonated .. " copper")
            print("DKP Awarded: " .. stats.totalDKPAwarded)
        end)
        
        -- Donation filtering commands
        InfinityCore:RegisterCommand("/dkp donations whitelist mode", "Toggle donation whitelist mode", function(args)
            local enabled = (args == "on" or args == "true" or args == "1")
            GuildBankDonations:SetWhitelistMode(enabled)
        end)
        
        InfinityCore:RegisterCommand("/dkp donations whitelist add", "Add item to donation whitelist", function(args)
            if not args or args == "" then
                print("Usage: /dkp donations whitelist add [itemid]")
            else
                GuildBankDonations:WhitelistItem(args)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp donations whitelist remove", "Remove item from donation whitelist", function(args)
            if not args or args == "" then
                print("Usage: /dkp donations whitelist remove [itemid]")
            else
                GuildBankDonations:UnwhitelistItem(args)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp donations whitelist clear", "Clear entire donation whitelist", function()
            GuildBankDonations:ClearWhitelist()
        end)
        
        InfinityCore:RegisterCommand("/dkp donations whitelist list", "Show donation whitelist", function()
            local whitelist = GuildBankDonations:GetWhitelist()
            print("=== DONATION WHITELIST ===")
            if not next(whitelist) then
                print("(empty)")
            else
                for itemId, _ in pairs(whitelist) do
                    print("- Item ID: " .. itemId)
                end
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp donations blacklist add", "Add item to donation blacklist", function(args)
            if not args or args == "" then
                print("Usage: /dkp donations blacklist add [itemid]")
            else
                GuildBankDonations:BlacklistItem(args)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp donations blacklist remove", "Remove item from donation blacklist", function(args)
            if not args or args == "" then
                print("Usage: /dkp donations blacklist remove [itemid]")
            else
                GuildBankDonations:UnblacklistItem(args)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp donations blacklist clear", "Clear entire donation blacklist", function()
            GuildBankDonations:ClearBlacklist()
        end)
        
        InfinityCore:RegisterCommand("/dkp donations blacklist list", "Show donation blacklist", function()
            local blacklist = GuildBankDonations:GetBlacklist()
            print("=== DONATION BLACKLIST ===")
            if not next(blacklist) then
                print("(empty)")
            else
                for itemId, _ in pairs(blacklist) do
                    print("- Item ID: " .. itemId)
                end
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp trade", "DKP trade help", function()
            print("Trade: /dkp trade offer <player> <amount> | accept <sender> <id> | cancel <sender> <id>")
            print("Guild master: /dkp trade finalize <sender> <id>; /dkp trade list | resend <id>")
            print("Requires online recipient and guild master. After finalization, send and apply a guild snapshot.")
        end)
        InfinityCore:RegisterCommand("/dkp trade offer", "Offer DKP to a guild member", function(args)
            local recipient, amount
            if type(args) == "string" then recipient, amount = args:match("^%s*(%S+)%s+(%S+)%s*$") end
            PlayerTrading:Offer(recipient, tonumber(amount))
        end)
        local function TradeAction(args, action)
            local from, token
            if type(args) == "string" then from, token = args:match("^%s*(%S+)%s+(%S+)%s*$") end
            if not from or not token then
                print("Usage: /dkp trade " .. action .. " <sender> <id>")
                return
            end
            if action == "accept" then PlayerTrading:Accept(from, token)
            elseif action == "cancel" then PlayerTrading:Cancel(from, token)
            else PlayerTrading:Finalize(from, token) end
        end
        InfinityCore:RegisterCommand("/dkp trade accept", "Accept a DKP offer", function(args) TradeAction(args, "accept") end)
        InfinityCore:RegisterCommand("/dkp trade cancel", "Cancel a DKP offer", function(args) TradeAction(args, "cancel") end)
        InfinityCore:RegisterCommand("/dkp trade finalize", "Finalize an accepted DKP offer", function(args) TradeAction(args, "finalize") end)
        InfinityCore:RegisterCommand("/dkp trade list", "List session DKP trades", function() PlayerTrading:List() end)
        InfinityCore:RegisterCommand("/dkp trade resend", "Resend a DKP offer", function(args)
            local token = type(args) == "string" and args:match("^%s*(%S+)%s*$")
            if token then PlayerTrading:Resend(token) else print("Usage: /dkp trade resend <id>") end
        end)
    end
    
    initialized = true

    -- Event handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
    eventFrame:RegisterEvent("GUILDBANKFRAME_CLOSED")
    eventFrame:RegisterEvent("GUILDBANKLOG_UPDATE")

    local function CaptureAttendance()
        local raid = Attendance.raids[#Attendance.raids]
        if not raid or raid.end_time then return end
        local function Incomplete()
            if not raid.attendanceIncomplete then
                raid.attendanceIncomplete = true
                InfinityUtils:Warning("Encounter attendance is incomplete; automatic boss awards will be skipped.", addonName)
            end
        end
        if not GetNumGroupMembers or not IsInRaid or not UnitName then
            Incomplete()
            return
        end
        local count = GetNumGroupMembers()
        local inRaid = IsInRaid()
        if (_G.issecretvalue and (_G.issecretvalue(count) or _G.issecretvalue(inRaid)))
            or type(count) ~= "number" or count ~= count or count < 0 or count > 40 or count ~= math.floor(count)
            or (inRaid ~= nil and type(inRaid) ~= "boolean") or (inRaid and count == 0) then Incomplete(); return end
        local function Mark(name)
            if (_G.issecretvalue and _G.issecretvalue(name)) or type(name) ~= "string" or name == "" then
                Incomplete(); return
            end
            if not raid.members[name] then Attendance:MarkAttendance(name, true) end
        end
        if inRaid and GetRaidRosterInfo then
            for i = 1, count do Mark(GetRaidRosterInfo(i)) end
        elseif not inRaid then
            Mark(UnitName("player"))
            for i = 1, math.max(0, count - 1) do Mark(UnitName("party" .. i)) end
        else
            Incomplete()
        end
    end

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKFRAME_CLOSED" or event == "GUILDBANKLOG_UPDATE" then
            if UI and type(UI.OnGuildBankEvent) == "function" then UI:OnGuildBankEvent(event) end
        elseif event == "ENCOUNTER_START" then
            local encounterID, name, difficulty = ...
            if _G.issecretvalue and _G.issecretvalue(encounterID) then encounterID = nil end
            if _G.issecretvalue and _G.issecretvalue(name) then name = nil end
            if _G.issecretvalue and _G.issecretvalue(difficulty) then difficulty = nil end
            if type(name) ~= "string" or name == "" then name = nil end
            local raid = Attendance:StartRaid(name or "Encounter", difficulty)
            if type(encounterID) == "number" and encounterID > 0 and encounterID < math.huge
                and encounterID == math.floor(encounterID) then raid.encounterID = encounterID end
            CaptureAttendance()
            Points:LogTransaction("Guild", "encounter_start", 0, "Raid started")
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            local activeRaid = Attendance.raids[#Attendance.raids]
            if not activeRaid or activeRaid.end_time then return end
            if _G.issecretvalue and _G.issecretvalue(encounterID) then encounterID = nil end
            if _G.issecretvalue and _G.issecretvalue(success) then success = nil end
            if _G.issecretvalue and _G.issecretvalue(encounterName) then encounterName = nil end
            if type(encounterName) ~= "string" or encounterName == "" then encounterName = nil end
            if success == 1 then
                Attendance:RecordBossKill(encounterName or "Encounter")
                Points:LogTransaction("Guild", "encounter_complete", 0, "Boss: " .. (encounterName or "Encounter"))
                if BossAwards and type(BossAwards.AwardLocalRaid) == "function" then
                    if type(BossAwards.HasValidLocalConfig) ~= "function" or not BossAwards:HasValidLocalConfig() then
                        InfinityUtils:Warning("Boss award skipped: invalid configuration.", addonName)
                    elseif BossAwards.localConfig.enabled then
                        if type(encounterID) == "number"
                            and not (_G.issecretvalue and issecretvalue(activeRaid.encounterID))
                            and activeRaid.encounterID == encounterID then
                            BossAwards:AwardLocalRaid(activeRaid, Engine, Points, GuildSync)
                        else
                            InfinityUtils:Warning("Boss award skipped: encounter ID unavailable or changed.", addonName)
                        end
                    end
                end
            elseif success == 0 then
                Attendance:RecordWipe()
            else
                InfinityUtils:Warning("Encounter result unavailable; automatic boss award skipped.", addonName)
            end
            Attendance:EndRaid()
        elseif event == "GROUP_ROSTER_UPDATE" then
            CaptureAttendance()
        end
    end)
    
    print("InfinityDKP loaded - Use /dkp to open management window")
    print("Points: /dkp add, /dkp ep, /dkp gp, /dkp points, /dkp spend; manual snapshots: /dkp sync")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		-- If InfinityCore is already loaded, initialize immediately
		if _G.InfinityCore then
			InitializeDKP()
		end
	elseif event == "INFINITY_DATA_LOADED" and addonLoaded then
		-- Initialize when InfinityCore broadcasts it's ready
		InitializeDKP()
	end
end)

-- Also subscribe to the messaging event from InfinityCore
if _G.InfinityMessaging then
	_G.InfinityMessaging:Subscribe("INFINITY_DATA_LOADED", function()
		if addonLoaded then
			InitializeDKP()
		end
	end)
end
