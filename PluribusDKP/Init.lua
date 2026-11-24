-- PluribusDKP Initialization
-- Setup and integration with PluribusCore

local addonName = "PluribusDKP"
local addonVersion = "1.1.0"

local function InitializeDKP()
	-- Wait for PluribusCore to load
	if not _G.PluribusCore then
		return  -- Will retry when PLURIBUS_DATA_LOADED fires
	end

	-- Modules are loaded via .toc file, so globals are already created
	-- Use the globals that were set up by the module files
	local Engine = PluribusDKPEngine or _G.PluribusDKPEngine
	local Attendance = PluribusAttendanceTracker or _G.PluribusAttendanceTracker
	local Points = PluribusDKPPoints or _G.PluribusDKPPoints
	local Auctions = PluribusDKPAuctions or _G.PluribusDKPAuctions
	local History = PluribusDKPHistory or _G.PluribusDKPHistory
	local Reports = PluribusDKPReports or _G.PluribusDKPReports
	local UnifiedAuctions = PluribusDKPUnifiedAuctions or _G.PluribusDKPUnifiedAuctions
	local TaxSystem = PluribusDKPTaxSystem or _G.PluribusDKPTaxSystem
	local GuildBankDonations = PluribusDKPGuildBankDonations or _G.PluribusDKPGuildBankDonations
	local PlayerTrading = PluribusDKPPlayerTrading or _G.PluribusDKPPlayerTrading
	local UI = PluribusDKPUI or _G.PluribusDKPUI
    
    -- Initialize
    if UI and UI.Initialize then
        UI:Initialize()
    end
    
    -- Register with PluribusCore
    PluribusCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Pluribus",
        description = "Full DKP system with unified auctions, taxation, guild bank donations, and player trading",
        enabled = true,
    })
    
    -- Command registration
    if PluribusCore.RegisterCommand then
        PluribusCore:RegisterCommand("/dkp", "Toggle DKP window", function()
            UI:Toggle()
        end)
        
        PluribusCore:RegisterCommand("/dkp report", "Generate DKP report", function()
            local report = Reports:GenerateFullReport()
            print(report)
        end)
        
        PluribusCore:RegisterCommand("/dkp priority", "Show priority list", function()
            local report = Reports:GeneratePriorityList()
            print(report)
        end)
        
        PluribusCore:RegisterCommand("/dkp attendance", "Show attendance report", function()
            local report = Reports:GenerateAttendanceReport()
            print(report)
        end)
        
        PluribusCore:RegisterCommand("/dkp loot", "Show loot history", function()
            local report = Reports:GenerateLootReport(7)
            print(report)
        end)
        
        -- New auction commands
        PluribusCore:RegisterCommand("/dkp auction create", "Create unified auction", function(args)
            -- Parse args: itemlink startingbid duration
            if not args or args == "" then
                print("Usage: /dkp auction create [itemlink] [startingbid] [duration]")
            else
                -- Create auction with parsed args
                local itemlink = args
                UnifiedAuctions:CreateAuction(itemlink, 1, 300)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp auction list", "List active auctions", function()
            local auctions = UnifiedAuctions:GetActiveAuctions()
            print("=== ACTIVE AUCTIONS ===")
            for _, auction in ipairs(auctions) do
                print(string.format("[%d] %s - Current: %d DKP (Highest: %s)", 
                    auction.id, auction.itemName, auction.currentHighBid, auction.highestBidder or "None"))
            end
        end)
        
        -- Tax commands
        PluribusCore:RegisterCommand("/dkp tax stats", "Show tax statistics", function()
            local stats = TaxSystem:GetGuildTaxStats()
            print("=== GUILD TAX STATS ===")
            print("Total Collected: " .. stats.totalCollected .. " gold")
            print("Players Taxed: " .. stats.playerCount)
            print("Tax Rate: " .. stats.taxRate)
        end)
        
        -- Tax filtering commands
        PluribusCore:RegisterCommand("/dkp tax whitelist mode", "Toggle tax whitelist mode", function(args)
            local enabled = (args == "on" or args == "true" or args == "1")
            TaxSystem:SetWhitelistMode(enabled)
        end)
        
        PluribusCore:RegisterCommand("/dkp tax whitelist add", "Add item to tax whitelist", function(args)
            if not args or args == "" then
                print("Usage: /dkp tax whitelist add [itemid]")
            else
                TaxSystem:WhitelistItem(args)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp tax whitelist remove", "Remove item from tax whitelist", function(args)
            if not args or args == "" then
                print("Usage: /dkp tax whitelist remove [itemid]")
            else
                TaxSystem:UnwhitelistItem(args)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp tax whitelist clear", "Clear entire tax whitelist", function()
            TaxSystem:ClearWhitelist()
        end)
        
        PluribusCore:RegisterCommand("/dkp tax whitelist list", "Show tax whitelist", function()
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
        
        PluribusCore:RegisterCommand("/dkp tax blacklist add", "Add item to tax blacklist", function(args)
            if not args or args == "" then
                print("Usage: /dkp tax blacklist add [itemid]")
            else
                TaxSystem:BlacklistItem(args)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp tax blacklist remove", "Remove item from tax blacklist", function(args)
            if not args or args == "" then
                print("Usage: /dkp tax blacklist remove [itemid]")
            else
                TaxSystem:UnblacklistItem(args)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp tax blacklist clear", "Clear entire tax blacklist", function()
            TaxSystem:ClearBlacklist()
        end)
        
        PluribusCore:RegisterCommand("/dkp tax blacklist list", "Show tax blacklist", function()
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
        PluribusCore:RegisterCommand("/dkp donations", "Show donation statistics", function()
            local stats = GuildBankDonations:GetGuildDonationStats()
            print("=== GUILD BANK DONATIONS ===")
            print("Total Gold: " .. stats.totalGoldDonated .. " copper")
            print("Total Items Value: " .. stats.totalItemValueDonated .. " copper")
            print("DKP Awarded: " .. stats.totalDKPAwarded)
        end)
        
        -- Donation filtering commands
        PluribusCore:RegisterCommand("/dkp donations whitelist mode", "Toggle donation whitelist mode", function(args)
            local enabled = (args == "on" or args == "true" or args == "1")
            GuildBankDonations:SetWhitelistMode(enabled)
        end)
        
        PluribusCore:RegisterCommand("/dkp donations whitelist add", "Add item to donation whitelist", function(args)
            if not args or args == "" then
                print("Usage: /dkp donations whitelist add [itemid]")
            else
                GuildBankDonations:WhitelistItem(args)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp donations whitelist remove", "Remove item from donation whitelist", function(args)
            if not args or args == "" then
                print("Usage: /dkp donations whitelist remove [itemid]")
            else
                GuildBankDonations:UnwhitelistItem(args)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp donations whitelist clear", "Clear entire donation whitelist", function()
            GuildBankDonations:ClearWhitelist()
        end)
        
        PluribusCore:RegisterCommand("/dkp donations whitelist list", "Show donation whitelist", function()
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
        
        PluribusCore:RegisterCommand("/dkp donations blacklist add", "Add item to donation blacklist", function(args)
            if not args or args == "" then
                print("Usage: /dkp donations blacklist add [itemid]")
            else
                GuildBankDonations:BlacklistItem(args)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp donations blacklist remove", "Remove item from donation blacklist", function(args)
            if not args or args == "" then
                print("Usage: /dkp donations blacklist remove [itemid]")
            else
                GuildBankDonations:UnblacklistItem(args)
            end
        end)
        
        PluribusCore:RegisterCommand("/dkp donations blacklist clear", "Clear entire donation blacklist", function()
            GuildBankDonations:ClearBlacklist()
        end)
        
        PluribusCore:RegisterCommand("/dkp donations blacklist list", "Show donation blacklist", function()
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
        
        -- Trading commands
        PluribusCore:RegisterCommand("/dkp trade", "Create DKP trade offer", function(args)
            if not args or args == "" then
                print("Usage: /dkp trade [playername] [amount] [reason]")
            else
                -- Parse and create trade offer
            end
        end)
    end
    
    -- Event handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ENCOUNTER_START" then
            Attendance:StartRaid(select(2, ...), select(3, ...))
            Points:LogTransaction("Guild", "encounter_start", 0, "Raid started")
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            if success then
                local raid = Attendance:EndRaid()
                if raid then
                    Points:LogTransaction("Guild", "encounter_complete", 0, "Boss: " .. encounterName)
                end
            else
                Attendance:RecordWipe()
            end
        elseif event == "GROUP_ROSTER_UPDATE" then
            -- Update attendance for visible players
            for i = 1, GetNumGroupMembers() do
                local name = select(1, GetRaidRosterInfo(i))
                if name then
                    Attendance:MarkAttendance(name, true)
                end
            end
        end
    end)
    
    print("PluribusDKP loaded - Use /dkp to open management window")
    print("Commands: /dkp report, /dkp priority, /dkp attendance, /dkp loot")
    print("New Features: /dkp auction create, /dkp auction list, /dkp tax stats, /dkp donations, /dkp trade")
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Manage DKP for loot",
			author = "Pluribus Suite Team",
			category = "Loot",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

-- Flag to track if our addon has loaded
local addonLoaded = false

frame:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		addonLoaded = true
		-- If PluribusCore is already loaded, initialize immediately
		if _G.PluribusCore then
			InitializeDKP()
		end
	elseif event == "PLURIBUS_DATA_LOADED" and addonLoaded then
		-- Initialize when PluribusCore broadcasts it's ready
		InitializeDKP()
	end
end)

-- Also subscribe to the messaging event from PluribusCore
if _G.PluribusMessaging then
	_G.PluribusMessaging:Subscribe("PLURIBUS_DATA_LOADED", function()
		if addonLoaded then
			InitializeDKP()
		end
	end)
end
