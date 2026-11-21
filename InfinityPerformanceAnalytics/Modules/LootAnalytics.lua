-- Loot Analytics Module
-- Comparison reports, distribution analysis, and historical trends

local MODULE_NAME = "LootAnalytics"
local InfinityPerformanceAnalytics = InfinityPerformanceAnalytics or {}
local InfinityLoot = InfinityLoot or {}
local InfinityDKP = InfinityDKP or {}
local InfinityCore = InfinityCore or {}

InfinityPerformanceAnalytics.LootAnalytics = {
    enabled = false,
    
    cache = {
        player_loot_counts = {},
        player_gp_spent = {},
        item_distribution = {},
        rarity_distribution = {},
        last_updated = 0
    }
}

local Analytics = InfinityPerformanceAnalytics.LootAnalytics

local function TableFind(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

function Analytics:CachePlayerStats()
    self.cache.player_loot_counts = {}
    self.cache.player_gp_spent = {}
    self.cache.rarity_distribution = {}
    
    if not InfinityLoot.db or not InfinityLoot.db.loot_history then
        return
    end
    
    for _, entry in ipairs(InfinityLoot.db.loot_history) do
        local winner = entry.winner or "Unknown"
        local gp = entry.gp_cost or 0
        local rarity = entry.rarity or "Common"
        
        -- Count by player
        self.cache.player_loot_counts[winner] = (self.cache.player_loot_counts[winner] or 0) + 1
        self.cache.player_gp_spent[winner] = (self.cache.player_gp_spent[winner] or 0) + gp
        
        -- Count by rarity
        self.cache.rarity_distribution[rarity] = (self.cache.rarity_distribution[rarity] or 0) + 1
    end
    
    self.cache.last_updated = GetTime()
end

function Analytics:GetPlayerLootComparison(player1, player2)
    if GetTime() - self.cache.last_updated > 60 then
        self:CachePlayerStats()
    end
    
    local stats1 = {
        name = player1,
        items_won = self.cache.player_loot_counts[player1] or 0,
        gp_spent = self.cache.player_gp_spent[player1] or 0,
        gp_per_item = 0,
        dkp_balance = 0
    }
    
    local stats2 = {
        name = player2,
        items_won = self.cache.player_loot_counts[player2] or 0,
        gp_spent = self.cache.player_gp_spent[player2] or 0,
        gp_per_item = 0,
        dkp_balance = 0
    }
    
    -- Calculate averages
    if stats1.items_won > 0 then
        stats1.gp_per_item = math.floor(stats1.gp_spent / stats1.items_won)
    end
    if stats2.items_won > 0 then
        stats2.gp_per_item = math.floor(stats2.gp_spent / stats2.items_won)
    end
    
    -- Get DKP balances
    if InfinityDKP.db and InfinityDKP.db.players then
        stats1.dkp_balance = (InfinityDKP.db.players[player1] or {}).balance or 0
        stats2.dkp_balance = (InfinityDKP.db.players[player2] or {}).balance or 0
    end
    
    return stats1, stats2
end

function Analytics:PrintPlayerComparison(player1, player2)
    local s1, s2 = self:GetPlayerLootComparison(player1, player2)
    
    print("|cff00ccffLoot Comparison Report|r")
    print(string.rep("=", 60))
    
    -- Header
    print(string.format(
        "%-20s | %-20s | %-20s",
        "Metric",
        s1.name,
        s2.name
    ))
    print(string.rep("-", 60))
    
    -- Items won
    print(string.format(
        "%-20s | %-20d | %-20d",
        "Items Won",
        s1.items_won,
        s2.items_won
    ))
    
    -- GP Spent
    print(string.format(
        "%-20s | %-20d | %-20d",
        "Total GP",
        s1.gp_spent,
        s2.gp_spent
    ))
    
    -- GP per item
    print(string.format(
        "%-20s | %-20d | %-20d",
        "Avg GP/Item",
        s1.gp_per_item,
        s2.gp_per_item
    ))
    
    -- DKP Balance
    print(string.format(
        "%-20s | %-20d | %-20d",
        "DKP Balance",
        s1.dkp_balance,
        s2.dkp_balance
    ))
    
    print(string.rep("=", 60))
end

function Analytics:GetRarityDistribution()
    if GetTime() - self.cache.last_updated > 60 then
        self:CachePlayerStats()
    end
    
    return self.cache.rarity_distribution
end

function Analytics:PrintRarityDistribution()
    local dist = self:GetRarityDistribution()
    
    print("|cff00ccffLoot Rarity Distribution|r")
    print(string.rep("=", 40))
    
    local total = 0
    for _, count in pairs(dist) do
        total = total + count
    end
    
    -- Sort by count descending
    local sorted = {}
    for rarity, count in pairs(dist) do
        table.insert(sorted, {rarity, count})
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    
    for _, entry in ipairs(sorted) do
        local rarity = entry[1]
        local count = entry[2]
        local percent = total > 0 and math.floor((count / total) * 100) or 0
        
        -- Color by rarity
        local color = "|cffffffff"
        if rarity == "Rare" then color = "|cff0070dd"
        elseif rarity == "Epic" then color = "|cffa335ee"
        elseif rarity == "Legendary" then color = "|cffff8000"
        elseif rarity == "Uncommon" then color = "|cff1eff00"
        end
        
        print(string.format(
            "%s%-15s|r %-4d (%3d%%)",
            color,
            rarity,
            count,
            percent
        ))
    end
    
    print(string.rep("=", 40))
    print(string.format("Total items: %d", total))
end

function Analytics:GetPlayerFairness()
    if GetTime() - self.cache.last_updated > 60 then
        self:CachePlayerStats()
    end
    
    if not InfinityDKP.db or not InfinityDKP.db.players then
        return {}
    end
    
    local fairness = {}
    
    for player_name, player_data in pairs(InfinityDKP.db.players) do
        local items_won = self.cache.player_loot_counts[player_name] or 0
        local gp_spent = self.cache.player_gp_spent[player_name] or 0
        
        fairness[player_name] = {
            balance = player_data.balance or 0,
            items_won = items_won,
            gp_spent = gp_spent,
            fairness_index = 0
        }
        
        -- Fairness index: higher balance + fewer items + less GP = more "lucky"
        -- Lower balance + more items + more GP = less "lucky" (working off debt)
        if items_won > 0 then
            fairness[player_name].fairness_index = 
                (player_data.balance or 0) - (items_won * 100) + math.floor((gp_spent - 500) / 100)
        end
    end
    
    return fairness
end

function Analytics:PrintFairnessReport()
    local fairness = self:GetPlayerFairness()
    
    print("|cff00ccffLoot Fairness Report|r")
    print(string.rep("=", 70))
    
    -- Sort by fairness index
    local sorted = {}
    for player, data in pairs(fairness) do
        table.insert(sorted, {player, data})
    end
    table.sort(sorted, function(a, b) return a[2].fairness_index > b[2].fairness_index end)
    
    print(string.format(
        "%-20s | %-10s | %-10s | %-10s | %-10s",
        "Player",
        "Balance",
        "Items",
        "GP Spent",
        "Fairness"
    ))
    print(string.rep("-", 70))
    
    for i, entry in ipairs(sorted) do
        local player = entry[1]
        local data = entry[2]
        
        -- Color code fairness
        local color = "|cffff0000"  -- Red = unfair (high balance, few items)
        if data.fairness_index < -50 then
            color = "|cff00ff00"    -- Green = fair (low balance, many items)
        elseif data.fairness_index < 0 then
            color = "|cffffff00"    -- Yellow = medium
        end
        
        print(string.format(
            "%-20s | %10d | %10d | %10d | %s%10d|r",
            player,
            data.balance,
            data.items_won,
            data.gp_spent,
            color,
            data.fairness_index
        ))
        
        if i >= 10 then break end
    end
    
    print(string.rep("=", 70))
end

function Analytics:GetItemAcquisitionTrend(item_name, days)
    days = days or 30
    local cutoff_time = GetTime() - (days * 86400)
    
    if not InfinityLoot.db or not InfinityLoot.db.loot_history then
        return {}
    end
    
    local trend = {}
    
    for _, entry in ipairs(InfinityLoot.db.loot_history) do
        if (entry.timestamp or 0) > cutoff_time then
            if entry.item_name and entry.item_name:match(item_name) then
                local date_key = date("%Y-%m-%d", entry.timestamp or 0)
                trend[date_key] = (trend[date_key] or 0) + 1
            end
        end
    end
    
    return trend
end

function Analytics:GetGPTrendByRarity(days)
    days = days or 30
    local cutoff_time = GetTime() - (days * 86400)
    
    if not InfinityLoot.db or not InfinityLoot.db.loot_history then
        return {}
    end
    
    local trend = {
        Common = {},
        Uncommon = {},
        Rare = {},
        Epic = {},
        Legendary = {}
    }
    
    for _, entry in ipairs(InfinityLoot.db.loot_history) do
        if (entry.timestamp or 0) > cutoff_time then
            local date_key = date("%Y-%m-%d", entry.timestamp or 0)
            local rarity = entry.rarity or "Common"
            
            if trend[rarity] then
                trend[rarity][date_key] = (trend[rarity][date_key] or 0) + (entry.gp_cost or 0)
            end
        end
    end
    
    return trend
end

function Analytics:PrintGPTrend()
    local trend = self:GetGPTrendByRarity(14)
    
    print("|cff00ccffGP Spending Trend (Last 14 Days)|r")
    print(string.rep("=", 60))
    
    local dates = {}
    for _, rarity_data in pairs(trend) do
        for date, _ in pairs(rarity_data) do
            if not TableFind(dates, date) then
                table.insert(dates, date)
            end
        end
    end
    table.sort(dates)
    
    -- Print header
    print(string.format("%-12s | %-12s | %-12s | %-12s",
        "Date",
        "Common/Un",
        "Rare",
        "Epic/Leg"
    ))
    print(string.rep("-", 60))
    
    for _, date in ipairs(dates) do
        local common_gp = (trend.Common[date] or 0) + (trend.Uncommon[date] or 0)
        local rare_gp = trend.Rare[date] or 0
        local epic_gp = (trend.Epic[date] or 0) + (trend.Legendary[date] or 0)
        
        print(string.format("%-12s | %12d | %12d | %12d",
            date,
            common_gp,
            rare_gp,
            epic_gp
        ))
    end
    
    print(string.rep("=", 60))
end

-- Register slash commands
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("lootanalytics", function(args)
        if args == "" or args == "help" then
            print("|cff00ccffLoot Analytics Commands|r")
            print("/analytics compare <player1> <player2> - Compare two players")
            print("/analytics rarity - Show rarity distribution")
            print("/analytics fairness - Show fairness report")
            print("/analytics trend - Show GP spending trend")
            return
        end
        
        local cmd, rest = string.match(args, "(%w+)%s*(.*)")
        
        if cmd == "compare" then
            local p1, p2 = string.match(rest, "(%w+)%s+(%w+)")
            if p1 and p2 then
                Analytics:PrintPlayerComparison(p1, p2)
            else
                print("|cffff0000Usage: /analytics compare <player1> <player2>|r")
            end
        elseif cmd == "rarity" then
            Analytics:PrintRarityDistribution()
        elseif cmd == "fairness" then
            Analytics:PrintFairnessReport()
        elseif cmd == "trend" then
            Analytics:PrintGPTrend()
        else
            print("|cffff0000Unknown command. Use /analytics help|r")
        end
    end, "Loot analysis and reporting")
end

return InfinityPerformanceAnalytics.LootAnalytics

