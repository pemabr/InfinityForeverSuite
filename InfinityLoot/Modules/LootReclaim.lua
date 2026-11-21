-- Loot Reclaim System
-- Allows officers to reclaim items and reverse DKP transactions

local MODULE_NAME = "LootReclaim"
local InfinityLoot = InfinityLoot or {}
local InfinityCore = InfinityCore or {}

InfinityLoot.LootReclaim = {
    enabled = false,
    history = {},
    
    config = {
        require_reason = true,
        log_reclaims = true,
        notify_player = true,
    }
}

local LootReclaim = InfinityLoot.LootReclaim

function LootReclaim:Initialize()
    -- Subscribe to loot award events
    if InfinityCore.Events then
        InfinityCore.Events:Subscribe("LOOT_AWARDED", function(item_id, winner, dkp_cost)
            LootReclaim:LogAward(item_id, winner, dkp_cost)
        end)
    end
end

function LootReclaim:LogAward(item_id, winner, dkp_cost)
    local award = {
        item_id = item_id,
        item_link = GetItemLink(item_id) or "Unknown",
        winner = winner,
        dkp_cost = dkp_cost,
        timestamp = GetServerTime(),
        awarded_by = UnitName("player"),
        guild = GetGuildInfo("player")
    }
    
    table.insert(self.history, award)
    
    -- Keep last 1000 awards
    if #self.history > 1000 then
        table.remove(self.history, 1)
    end
end

function LootReclaim:CanReclaim()
    if _G.IsGuildLeader and _G.IsGuildLeader() then
        return true
    end
    -- Rank 0 = guild master, rank 1 = officer
    local _, _, rank_index = GetGuildInfo("player")
    return rank_index ~= nil and rank_index <= 1
end

function LootReclaim:RecoverLoot(award_index, reason)
    if not self:CanReclaim() then
        print("|cffff0000You don't have permission to reclaim loot.|r")
        return false
    end
    
    if not award_index or award_index < 1 or award_index > #self.history then
        print("|cffff0000Invalid award index.|r")
        return false
    end
    
    if self.config.require_reason and (not reason or reason == "") then
        print("|cffff0000You must provide a reason for reclaiming loot.|r")
        return false
    end
    
    local award = self.history[award_index]
    local player = award.winner
    local dkp_refund = award.dkp_cost
    
    -- Reverse the DKP transaction
    if InfinityDKP and InfinityDKP.Engine then
        local refund_reason = "Loot Reclaim: " .. (reason or "No reason provided")
        InfinityDKP.Engine:AwardPoints(player, dkp_refund, refund_reason)
    end
    
    -- Log the reclaim
    if self.config.log_reclaims and InfinityDKP then
        local reclaim_log = {
            item_id = award.item_id,
            item_link = award.item_link,
            player = player,
            dkp_refunded = dkp_refund,
            reason = reason,
            reclaimed_by = UnitName("player"),
            timestamp = GetServerTime(),
            original_award_time = award.timestamp
        }
        
        if not InfinityDKP.db.reclaims then
            InfinityDKP.db.reclaims = {}
        end
        
        table.insert(InfinityDKP.db.reclaims, reclaim_log)
    end
    
    -- Notify player
    if self.config.notify_player then
        self:NotifyReclaimToPlayer(player, award.item_link, dkp_refund, reason)
    end
    
    print("|cff00ff00✓ Loot reclaimed from " .. player .. "|r")
    print("|cff00ff00✓ Refunded " .. tostring(dkp_refund) .. " DKP|r")
    
    return true
end

function LootReclaim:NotifyReclaimToPlayer(player, item_link, dkp_amount, reason)
    local msg = string.format(
        "Your loot award for %s has been reclaimed. You have been refunded %d DKP.",
        item_link or "an item",
        dkp_amount
    )
    
    if reason and reason ~= "" then
        msg = msg .. " Reason: " .. reason
    end
    
    -- Send via messaging system
    if InfinityCore.Events then
        InfinityCore.Events:Publish("WHISPER_SEND", player, msg)
    end
end

function LootReclaim:ViewHistory(player_name, limit)
    limit = limit or 10
    
    print("|cff00ccffRecent Loot Awards|r")
    print(string.rep("-", 60))
    
    local count = 0
    
    for i = #self.history, 1, -1 do
        if count >= limit then
            break
        end
        
        local award = self.history[i]
        
        if not player_name or award.winner == player_name then
            local time_ago = GetServerTime() - award.timestamp
            local time_str = self:FormatTimeAgo(time_ago)
            
            print(string.format(
                "[%d] %s - %s to %s (%d DKP) - %s",
                i,
                award.item_link or "Unknown",
                award.awarded_by or "Unknown",
                award.winner,
                award.dkp_cost or 0,
                time_str
            ))
            
            count = count + 1
        end
    end
    
    if count == 0 then
        print("No recent awards found.")
    end
end

function LootReclaim:FormatTimeAgo(seconds)
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        return string.format("%d min ago", math.floor(seconds / 60))
    elseif seconds < 86400 then
        return string.format("%d hours ago", math.floor(seconds / 3600))
    else
        return string.format("%d days ago", math.floor(seconds / 86400))
    end
end

function LootReclaim:ViewReclaimLog()
    if not InfinityDKP or not InfinityDKP.db or not InfinityDKP.db.reclaims then
        print("No reclaim history.")
        return
    end
    
    print("|cff00ccffLoot Reclaim History|r")
    print(string.rep("-", 60))
    
    for idx, reclaim in ipairs(InfinityDKP.db.reclaims) do
        print(string.format(
            "[%d] %s reclaimed from %s (%d DKP refunded) - Reason: %s",
            idx,
            reclaim.item_link or "Unknown",
            reclaim.player,
            reclaim.dkp_refunded or 0,
            reclaim.reason or "No reason"
        ))
    end
end

function LootReclaim:ExportReclaimLog()
    if not InfinityDKP or not InfinityDKP.db or not InfinityDKP.db.reclaims then
        return nil
    end
    
    local log = "LOOT RECLAIM LOG\n"
    log = log .. string.rep("=", 60) .. "\n"
    log = log .. string.format("Generated: %s\n", date("%Y-%m-%d %H:%M:%S"))
    log = log .. string.rep("=", 60) .. "\n\n"
    
    for _, reclaim in ipairs(InfinityDKP.db.reclaims) do
        log = log .. string.format("Item: %s\n", reclaim.item_link or "Unknown")
        log = log .. string.format("Player: %s\n", reclaim.player)
        log = log .. string.format("DKP Refunded: %d\n", reclaim.dkp_refunded or 0)
        log = log .. string.format("Reason: %s\n", reclaim.reason or "No reason")
        log = log .. string.format("Reclaimed By: %s\n", reclaim.reclaimed_by or "Unknown")
        log = log .. string.format("Timestamp: %s\n", date("%Y-%m-%d %H:%M:%S", reclaim.timestamp or 0))
        log = log .. "\n"
    end
    
    return log
end

-- Register slash commands
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("reclaim", function(args)
        if not LootReclaim:CanReclaim() then
            print("|cffff0000You don't have permission to reclaim loot.|r")
            return
        end
        
        if args == "list" then
            LootReclaim:ViewHistory(nil, 20)
        elseif string.find(args, "recover") then
            local idx, reason = string.match(args, "recover (%d+) (.*)")
            if idx then
                LootReclaim:RecoverLoot(tonumber(idx), reason)
            else
                print("|cffff9900Usage:|r /reclaim recover <index> [reason]")
            end
        elseif args == "log" then
            LootReclaim:ViewReclaimLog()
        elseif args == "help" then
            print("|cff00ccffLoot Reclaim Commands:|r")
            print("|cffff9900/reclaim list|r - View recent loot awards")
            print("|cffff9900/reclaim recover <idx> [reason]|r - Reclaim loot and refund DKP")
            print("|cffff9900/reclaim log|r - View reclaim history")
        else
            LootReclaim:ViewHistory(nil, 10)
        end
    end, "Reclaim loot and reverse transactions (Officer only)")
end

return InfinityLoot.LootReclaim
