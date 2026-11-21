-- InfinityDKP Initialization
-- Setup and integration with InfinityCore

local addonName = "InfinityDKP"
local addonVersion = "1.1.0"

-- Wait for InfinityCore to load
if not InfinityCore then
    print("InfinityDKP: Waiting for InfinityCore...")
    return
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    
    -- Load all modules
    local Engine = require("InfinityDKP.Core.DKPEngine")
    local Attendance = require("InfinityDKP.Core.AttendanceTracker")
    local Points = require("InfinityDKP.Modules.Points")
    local Auctions = require("InfinityDKP.Modules.Auctions")
    local History = require("InfinityDKP.Modules.History")
    local Reports = require("InfinityDKP.Modules.Reports")
    local UnifiedAuctions = require("InfinityDKP.Modules.UnifiedAuctions")
    local TaxSystem = require("InfinityDKP.Modules.TaxSystem")
    local GuildBankDonations = require("InfinityDKP.Modules.GuildBankDonations")
    local PlayerTrading = require("InfinityDKP.Modules.PlayerTrading")
    local UI = require("InfinityDKP.UI.Main")
    
    -- Make modules global
    _G.InfinityDKPEngine = Engine
    _G.InfinityAttendanceTracker = Attendance
    _G.InfinityDKPPoints = Points
    _G.InfinityDKPAuctions = Auctions
    _G.InfinityDKPHistory = History
    _G.InfinityDKPReports = Reports
    _G.InfinityDKPUnifiedAuctions = UnifiedAuctions
    _G.InfinityDKPTaxSystem = TaxSystem
    _G.InfinityDKPGuildBankDonations = GuildBankDonations
    _G.InfinityDKPPlayerTrading = PlayerTrading
    
    -- Initialize
    UI:Initialize()
    
    -- Register with InfinityCore
    InfinityCore:RegisterAddon(addonName, {
        version = addonVersion,
        author = "Infinity Forever",
        description = "Full DKP system with unified auctions, taxation, guild bank donations, and player trading",
        enabled = true,
    })
    
    -- Command registration
    if InfinityCore.RegisterCommand then
        InfinityCore:RegisterCommand("/dkp", "Toggle DKP window", function()
            UI:Toggle()
        end)
        
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
        
        -- New auction commands
        InfinityCore:RegisterCommand("/dkp auction create", "Create unified auction", function(args)
            -- Parse args: itemlink startingbid duration
            if not args or args == "" then
                print("Usage: /dkp auction create [itemlink] [startingbid] [duration]")
            else
                -- Create auction with parsed args
                local itemlink = args
                UnifiedAuctions:CreateAuction(itemlink, 1, 300)
            end
        end)
        
        InfinityCore:RegisterCommand("/dkp auction list", "List active auctions", function()
            local auctions = UnifiedAuctions:GetActiveAuctions()
            print("=== ACTIVE AUCTIONS ===")
            for _, auction in ipairs(auctions) do
                print(string.format("[%d] %s - Current: %d DKP (Highest: %s)", 
                    auction.id, auction.itemName, auction.currentHighBid, auction.highestBidder or "None"))
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
        
        -- Trading commands
        InfinityCore:RegisterCommand("/dkp trade", "Create DKP trade offer", function(args)
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
    
    print("InfinityDKP loaded - Use /dkp to open management window")
    print("Commands: /dkp report, /dkp priority, /dkp attendance, /dkp loot")
    print("New Features: /dkp auction create, /dkp auction list, /dkp tax stats, /dkp donations, /dkp trade")
end)
