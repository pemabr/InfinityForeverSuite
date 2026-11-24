-- Loot Value Analysis System
-- Analyze loot value distribution and fairness

local MODULE_NAME = "LootValueAnalysis"
local PluribusLoot = PluribusLoot or {}
local PluribusCore = PluribusCore or {}

PluribusLoot.ValueAnalysis = {
    enabled = false,
    
    config = {
        calculate_fairness = true,
        fairness_method = "ep_gp",  -- "ep_gp" or "simple"
        compare_to_attendance = true,
        flag_outliers = true,
        outlier_threshold = 2.0  -- Standard deviations
    },
    
    player_stats = {}
}

local ValueAnalysis = PluribusLoot.ValueAnalysis

function ValueAnalysis:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if PluribusCore.Events then
        PluribusCore.Events:Register("loot_awarded", function(player, item, award_type, gp)
            ValueAnalysis:UpdatePlayerStats(player, gp)
        end)
    end
end

function ValueAnalysis:UpdatePlayerStats(player, gp_cost)
    if not player or not gp_cost then return end
    
    if not self.player_stats[player] then
        self.player_stats[player] = {
            loot_count = 0,
            total_gp = 0,
            avg_gp_per_item = 0,
            min_gp = gp_cost,
            max_gp = gp_cost,
            gp_distribution = {}
        }
    end
    
    local stats = self.player_stats[player]
    stats.loot_count = stats.loot_count + 1
    stats.total_gp = stats.total_gp + gp_cost
    stats.avg_gp_per_item = stats.total_gp / stats.loot_count
    
    if gp_cost < stats.min_gp then
        stats.min_gp = gp_cost
    end
    if gp_cost > stats.max_gp then
        stats.max_gp = gp_cost
    end
end

function ValueAnalysis:GetPlayerFairnessIndex(player)
    if not self.player_stats[player] then
        return 0
    end
    
    local stats = self.player_stats[player]
    
    if self.config.fairness_method == "ep_gp" then
        -- Higher EP/GP ratio = more loot for less cost = "lucky"
        -- Calculate from PluribusDKP if available
        if PluribusDKP and PluribusDKP.db and PluribusDKP.db.players then
            local player_data = PluribusDKP.db.players[player]
            if player_data then
                local ep = player_data.ep or 0
                local gp = player_data.gp or stats.total_gp
                
                if gp == 0 then return 0 end
                return (ep / gp) * 100  -- Higher = more points per GP spent
            end
        end
    end
    
    -- Simple method: compare avg cost to overall average
    local all_avg = self:GetAverageGPAcrossPlayers()
    if all_avg == 0 then return 0 end
    
    return (all_avg / stats.avg_gp_per_item) * 100  -- >100 = got cheaper items
end

function ValueAnalysis:GetAverageGPAcrossPlayers()
    local total_gp = 0
    local total_items = 0
    
    for _, stats in pairs(self.player_stats) do
        total_gp = total_gp + stats.total_gp
        total_items = total_items + stats.loot_count
    end
    
    if total_items == 0 then return 0 end
    return total_gp / total_items
end

function ValueAnalysis:GetStandardDeviation()
    local avg = self:GetAverageGPAcrossPlayers()
    local sum_sq_diff = 0
    local count = 0
    
    for _, stats in pairs(self.player_stats) do
        sum_sq_diff = sum_sq_diff + ((stats.avg_gp_per_item - avg) ^ 2)
        count = count + 1
    end
    
    if count <= 1 then return 0 end
    
    return math.sqrt(sum_sq_diff / (count - 1))
end

function ValueAnalysis:GetOutliers()
    local outliers = {}
    local avg = self:GetAverageGPAcrossPlayers()
    local std_dev = self:GetStandardDeviation()
    
    if std_dev == 0 then return outliers end
    
    local threshold = self.config.outlier_threshold
    
    for player, stats in pairs(self.player_stats) do
        local z_score = (stats.avg_gp_per_item - avg) / std_dev
        
        if math.abs(z_score) > threshold then
            table.insert(outliers, {
                player = player,
                avg_gp = stats.avg_gp_per_item,
                z_score = z_score,
                loot_count = stats.loot_count,
                direction = z_score > 0 and "High" or "Low"
            })
        end
    end
    
    return outliers
end

function ValueAnalysis:ComparePlayerLoot(player1, player2)
    if not self.player_stats[player1] or not self.player_stats[player2] then
        return nil
    end
    
    local stats1 = self.player_stats[player1]
    local stats2 = self.player_stats[player2]
    
    return {
        player1 = {
            name = player1,
            items = stats1.loot_count,
            total_gp = stats1.total_gp,
            avg_gp = stats1.avg_gp_per_item
        },
        player2 = {
            name = player2,
            items = stats2.loot_count,
            total_gp = stats2.total_gp,
            avg_gp = stats2.avg_gp_per_item
        },
        difference = {
            item_diff = stats1.loot_count - stats2.loot_count,
            gp_diff = stats1.total_gp - stats2.total_gp,
            avg_gp_diff = stats1.avg_gp_per_item - stats2.avg_gp_per_item
        }
    }
end

function ValueAnalysis:GetPlayerTierComparison()
    local tiers = {
        lucky = {},
        normal = {},
        unlucky = {}
    }
    
    local avg = self:GetAverageGPAcrossPlayers()
    if avg == 0 then return tiers end
    
    for player, stats in pairs(self.player_stats) do
        local ratio = stats.avg_gp_per_item / avg
        
        if ratio < 0.8 then
            table.insert(tiers.lucky, player)
        elseif ratio > 1.2 then
            table.insert(tiers.unlucky, player)
        else
            table.insert(tiers.normal, player)
        end
    end
    
    return tiers
end

function ValueAnalysis:PrintPlayerComparison(player1, player2)
    local comparison = self:ComparePlayerLoot(player1, player2)
    
    if not comparison then
        print("|cffff0000One or both players have no loot history|r")
        return
    end
    
    print("|cff00ccffLoot Value Comparison:|r")
    print("")
    print(string.format("%-15s | Items | Total GP | Avg GP", "Player"))
    print("------------ | ------ | -------- | -------")
    
    print(string.format("%-15s | %5d | %8d | %6.0f",
        comparison.player1.name,
        comparison.player1.items,
        comparison.player1.total_gp,
        comparison.player1.avg_gp
    ))
    
    print(string.format("%-15s | %5d | %8d | %6.0f",
        comparison.player2.name,
        comparison.player2.items,
        comparison.player2.total_gp,
        comparison.player2.avg_gp
    ))
    
    print("")
    print("Difference:")
    print(string.format("  Items: %+d", comparison.difference.item_diff))
    print(string.format("  Total GP: %+d", comparison.difference.gp_diff))
    print(string.format("  Avg GP: %+.0f", comparison.difference.avg_gp_diff))
    print("")
end

function ValueAnalysis:PrintFairnessReport()
    local avg = self:GetAverageGPAcrossPlayers()
    local std_dev = self:GetStandardDeviation()
    
    print("|cff00ccffLoot Fairness Report:|r")
    print("")
    print(string.format("Average GP per Item: %.1f", avg))
    print(string.format("Standard Deviation: %.1f", std_dev))
    print(string.format("Fairness Index Method: %s", self.config.fairness_method))
    print("")
    
    print("Player Fairness Scores (100 = average):")
    local sorted_players = {}
    for player, stats in pairs(self.player_stats) do
        local fairness = self:GetPlayerFairnessIndex(player)
        table.insert(sorted_players, {player = player, fairness = fairness, avg_gp = stats.avg_gp_per_item})
    end
    
    table.sort(sorted_players, function(a, b) return a.fairness > b.fairness end)
    
    for _, entry in ipairs(sorted_players) do
        local color = entry.fairness > 110 and "|cff00ff00" or (entry.fairness < 90 and "|cffff0000" or "|cffff9900")
        print(string.format("  %s%-15s|r - %.1f (Avg: %.0f GP)",
            color,
            entry.player,
            entry.fairness,
            entry.avg_gp
        ))
    end
    
    print("")
end

function ValueAnalysis:PrintTierComparison()
    local tiers = self:GetPlayerTierComparison()
    
    print("|cff00ccffPlayer Distribution by Loot Value:|r")
    print("")
    
    print("|cff00ff00Lucky (Low GP cost)|r")
    for _, player in ipairs(tiers.lucky) do
        local stats = self.player_stats[player]
        print(string.format("  %s - %.0f GP avg", player, stats.avg_gp_per_item))
    end
    
    print("")
    print("|cffff9900Normal|r")
    for _, player in ipairs(tiers.normal) do
        local stats = self.player_stats[player]
        print(string.format("  %s - %.0f GP avg", player, stats.avg_gp_per_item))
    end
    
    print("")
    print("|cffff0000Unlucky (High GP cost)|r")
    for _, player in ipairs(tiers.unlucky) do
        local stats = self.player_stats[player]
        print(string.format("  %s - %.0f GP avg", player, stats.avg_gp_per_item))
    end
    
    print("")
end

function ValueAnalysis:PrintOutliers()
    local outliers = self:GetOutliers()
    
    if #outliers == 0 then
        print("|cffff9900No statistical outliers detected|r")
        return
    end
    
    print("|cff00ccffLoot Distribution Outliers:|r")
    print("")
    
    for _, outlier in ipairs(outliers) do
        local color = outlier.direction == "High" and "|cffff0000" or "|cff00ff00"
        print(string.format("%s%s|r - %s luck (Z-score: %.2f, Avg: %.0f GP, %d items)",
            color,
            outlier.player,
            outlier.direction,
            outlier.z_score,
            outlier.avg_gp,
            outlier.loot_count
        ))
    end
    
    print("")
end

function ValueAnalysis:PrintStatus()
    print("|cff00ccffLoot Value Analysis Status:|r")
    print(string.format("  Enabled: %s", self.enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Players Tracked: %d", self:CountPlayers()))
    print(string.format("  Fairness Method: %s", self.config.fairness_method))
    print(string.format("  Avg GP per Item: %.1f", self:GetAverageGPAcrossPlayers()))
    print(string.format("  Std Dev: %.1f", self:GetStandardDeviation()))
    print("")
end

function ValueAnalysis:CountPlayers()
    local count = 0
    for _ in pairs(self.player_stats) do
        count = count + 1
    end
    return count
end

return PluribusLoot.ValueAnalysis
