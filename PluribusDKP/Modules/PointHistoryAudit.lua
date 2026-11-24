-- PointHistoryAudit.lua - Complete audit trail for DKP/EP/GP changes
-- Part of PluribusDKP addon suite
-- Traces every point change with full details for transparency and dispute resolution

local PointHistoryAudit = {}
PointHistoryAudit.enabled = false
PointHistoryAudit.db = nil
PointHistoryAudit.cache = {}

-- Configuration
PointHistoryAudit.config = {
    enabled = true,
    max_history_entries = 100000,  -- Keep full history for 100k events
    index_by_player = true,         -- Build player index for fast queries
    index_by_date = true,           -- Build date index
    index_by_action = true,         -- Build action index
    compression_threshold = 50000,   -- Compress when exceeding this
    retention_days = 365,           -- Archive entries older than 1 year
    track_all_changes = true,       -- Log every single point change
}

function PointHistoryAudit:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDKP")
    if not self.db then
        self:Log("No DKP database found")
        return
    end
    
    -- Initialize audit data structures
    if not self.db.point_history then
        self.db.point_history = {
            entries = {},           -- Full chronological history
            player_index = {},      -- Quick lookup: player -> entry indices
            date_index = {},        -- Quick lookup: date -> entry indices
            action_index = {},      -- Quick lookup: action_type -> entry indices
            stats = {
                total_entries = 0,
                last_updated = time(),
                total_dkp_distributed = 0,
                total_gp_distributed = 0,
            }
        }
    end
    
    self.enabled = true
    
    -- Build indexes if missing
    self:RebuildIndexes()
    
    -- Register for all DKP-related events
    PluribusCore.Events:RegisterListener("dkp_awarded", function(player, amount, reason)
        self:LogPointChange(player, "dkp_awarded", amount, reason)
    end)
    
    PluribusCore.Events:RegisterListener("gp_awarded", function(player, amount, reason)
        self:LogPointChange(player, "gp_awarded", amount, reason)
    end)
    
    PluribusCore.Events:RegisterListener("ep_awarded", function(player, amount, reason)
        self:LogPointChange(player, "ep_awarded", amount, reason)
    end)
    
    PluribusCore.Events:RegisterListener("dkp_decayed", function(player, old_dkp, new_dkp)
        self:LogPointChange(player, "dkp_decayed", new_dkp - old_dkp, "Weekly decay: " .. old_dkp .. " -> " .. new_dkp)
    end)
    
    PluribusCore.Events:RegisterListener("dkp_traded", function(from_player, to_player, amount)
        self:LogPointChange(from_player, "dkp_traded_sent", -amount, "Traded to " .. to_player)
        self:LogPointChange(to_player, "dkp_traded_received", amount, "Traded from " .. from_player)
    end)
    
    PluribusCore.Events:RegisterListener("loot_awarded", function(player, item, gp)
        self:LogPointChange(player, "gp_loot_awarded", gp, "Loot: " .. (item.name or "Unknown"))
    end)
    
    PluribusCore.Events:RegisterListener("raid_completion_awarded", function(data)
        for _, player in ipairs(data.members or {}) do
            self:LogPointChange(player, "raid_completion_bonus", self.config.raid_clear_bonus_ep, data.raid)
        end
    end)
    
    self:Log("Initialized with " .. #self.db.point_history.entries .. " historical entries")
end

function PointHistoryAudit:LogPointChange(playerName, action, amount, reason)
    if not self.enabled or not self.db then
        return
    end
    
    local entry = {
        timestamp = time(),
        player = playerName,
        action = action,
        amount = amount,
        reason = reason or "No reason provided",
        actor = UnitName("player") or "System",
        changed_by_addon = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("PluribusDKP", "Title"))
            or (GetAddOnMetadata and GetAddOnMetadata("PluribusDKP", "Title"))
            or "PluribusDKP",
    }
    
    -- Store entry
    table.insert(self.db.point_history.entries, entry)
    local entry_index = #self.db.point_history.entries
    
    -- Update stats
    if action:find("ep_") or action:find("dkp_") then
        self.db.point_history.stats.total_dkp_distributed = 
            (self.db.point_history.stats.total_dkp_distributed or 0) + math.max(0, amount)
    end
    if action:find("gp_") then
        self.db.point_history.stats.total_gp_distributed = 
            (self.db.point_history.stats.total_gp_distributed or 0) + math.max(0, amount)
    end
    self.db.point_history.stats.total_entries = entry_index
    self.db.point_history.stats.last_updated = time()
    
    -- Update indexes
    self:UpdateIndexes(entry, entry_index)
    
    -- Check if compression needed
    if entry_index > self.config.compression_threshold then
        self:CompressOldEntries()
    end
end

function PointHistoryAudit:UpdateIndexes(entry, entry_index)
    local history = self.db.point_history
    
    -- Update player index
    if self.config.index_by_player then
        if not history.player_index[entry.player] then
            history.player_index[entry.player] = {}
        end
        table.insert(history.player_index[entry.player], entry_index)
    end
    
    -- Update date index (by day)
    if self.config.index_by_date then
        local day = date("%Y-%m-%d", entry.timestamp)
        if not history.date_index[day] then
            history.date_index[day] = {}
        end
        table.insert(history.date_index[day], entry_index)
    end
    
    -- Update action index
    if self.config.index_by_action then
        if not history.action_index[entry.action] then
            history.action_index[entry.action] = {}
        end
        table.insert(history.action_index[entry.action], entry_index)
    end
end

function PointHistoryAudit:RebuildIndexes()
    if not self.db or not self.db.point_history then
        return
    end
    
    local history = self.db.point_history
    
    -- Clear existing indexes
    history.player_index = {}
    history.date_index = {}
    history.action_index = {}
    
    -- Rebuild from entries
    for i, entry in ipairs(history.entries or {}) do
        self:UpdateIndexes(entry, i)
    end
    
    self:Log("Rebuilt indexes for " .. #history.entries .. " entries")
end

function PointHistoryAudit:QueryByPlayer(playerName, maxResults)
    if not self.db or not self.db.point_history then
        return {}
    end
    
    maxResults = maxResults or 100
    local indices = self.db.point_history.player_index[playerName] or {}
    local results = {}
    
    -- Return last N entries (most recent first)
    local startIdx = math.max(1, #indices - maxResults + 1)
    for i = #indices, startIdx, -1 do
        table.insert(results, self.db.point_history.entries[indices[i]])
        if #results >= maxResults then
            break
        end
    end
    
    return results
end

function PointHistoryAudit:QueryByDate(startDate, endDate, maxResults)
    if not self.db or not self.db.point_history then
        return {}
    end
    
    maxResults = maxResults or 1000
    local results = {}
    
    -- Iterate through date range
    local startTime = time({year=startDate.year, month=startDate.month, day=startDate.day, hour=0, min=0, sec=0})
    local endTime = time({year=endDate.year, month=endDate.month, day=endDate.day, hour=23, min=59, sec=59})
    
    for i, entry in ipairs(self.db.point_history.entries or {}) do
        if entry.timestamp >= startTime and entry.timestamp <= endTime then
            table.insert(results, entry)
            if #results >= maxResults then
                break
            end
        end
    end
    
    return results
end

function PointHistoryAudit:QueryByAction(action, maxResults)
    if not self.db or not self.db.point_history then
        return {}
    end
    
    maxResults = maxResults or 100
    local indices = self.db.point_history.action_index[action] or {}
    local results = {}
    
    -- Return last N entries
    local startIdx = math.max(1, #indices - maxResults + 1)
    for i = #indices, startIdx, -1 do
        table.insert(results, self.db.point_history.entries[indices[i]])
        if #results >= maxResults then
            break
        end
    end
    
    return results
end

function PointHistoryAudit:GetPlayerHistory(playerName, days)
    days = days or 30
    local results = self:QueryByPlayer(playerName, 1000)
    
    if days then
        local cutoffTime = time() - (days * 24 * 60 * 60)
        local filtered = {}
        for _, entry in ipairs(results) do
            if entry.timestamp >= cutoffTime then
                table.insert(filtered, entry)
            end
        end
        return filtered
    end
    
    return results
end

function PointHistoryAudit:CalculatePlayerStats(playerName, daysBack)
    daysBack = daysBack or 30
    local history = self:GetPlayerHistory(playerName, daysBack)
    
    local stats = {
        player = playerName,
        period_days = daysBack,
        total_dkp_earned = 0,
        total_gp_earned = 0,
        ep_awards = 0,
        gp_awards = 0,
        loot_awards = 0,
        decay_applied = 0,
        trades_sent = 0,
        trades_received = 0,
        last_activity = nil,
    }
    
    for _, entry in ipairs(history) do
        if entry.action == "dkp_awarded" or entry.action == "ep_awarded" then
            stats.total_dkp_earned = stats.total_dkp_earned + math.max(0, entry.amount)
            stats.ep_awards = stats.ep_awards + 1
        elseif entry.action == "gp_awarded" or entry.action == "gp_loot_awarded" then
            stats.total_gp_earned = stats.total_gp_earned + entry.amount
            stats.gp_awards = stats.gp_awards + 1
        elseif entry.action == "dkp_loot_awarded" then
            stats.loot_awards = stats.loot_awards + 1
        elseif entry.action == "dkp_decayed" then
            stats.decay_applied = stats.decay_applied + 1
        elseif entry.action == "dkp_traded_sent" then
            stats.trades_sent = stats.trades_sent + 1
        elseif entry.action == "dkp_traded_received" then
            stats.trades_received = stats.trades_received + 1
        end
        
        if not stats.last_activity or entry.timestamp > stats.last_activity then
            stats.last_activity = entry.timestamp
        end
    end
    
    -- Calculate efficiency (DKP earned vs GP spent)
    if stats.total_gp_earned > 0 then
        stats.efficiency_ratio = stats.total_dkp_earned / stats.total_gp_earned
    else
        stats.efficiency_ratio = 0
    end
    
    return stats
end

function PointHistoryAudit:CompressOldEntries()
    if not self.db or not self.db.point_history then
        return
    end
    
    local cutoffTime = time() - (self.config.retention_days * 24 * 60 * 60)
    local newEntries = {}
    local compressedCount = 0
    
    for i, entry in ipairs(self.db.point_history.entries or {}) do
        if entry.timestamp >= cutoffTime then
            table.insert(newEntries, entry)
        else
            compressedCount = compressedCount + 1
        end
    end
    
    if compressedCount > 0 then
        self.db.point_history.entries = newEntries
        self:RebuildIndexes()
        self:Log("Compressed " .. compressedCount .. " old entries")
    end
end

function PointHistoryAudit:ExportHistory(playerName)
    local history = self:GetPlayerHistory(playerName, nil)
    local output = ""
    
    output = output .. "=== Point History for " .. playerName .. " ===\n"
    output = output .. "Total entries: " .. #history .. "\n\n"
    
    for _, entry in ipairs(history) do
        local dateStr = date("%Y-%m-%d %H:%M:%S", entry.timestamp)
        output = output .. dateStr .. " | " .. entry.action .. " | " .. tostring(entry.amount)
        output = output .. " | " .. entry.reason .. "\n"
    end
    
    return output
end

function PointHistoryAudit:GetStatus()
    if not self.db or not self.db.point_history then
        return {}
    end
    
    local stats = self.db.point_history.stats or {}
    return {
        enabled = self.enabled,
        total_entries = stats.total_entries or 0,
        total_dkp_distributed = stats.total_dkp_distributed or 0,
        total_gp_distributed = stats.total_gp_distributed or 0,
        player_index_entries = self:CountIndexEntries(self.db.point_history.player_index),
        last_updated = date("%Y-%m-%d %H:%M:%S", stats.last_updated or 0),
    }
end

function PointHistoryAudit:CountIndexEntries(index)
    local count = 0
    for _ in pairs(index or {}) do
        count = count + 1
    end
    return count
end

function PointHistoryAudit:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[PointHistoryAudit] " .. message)
    else
        print("[PointHistoryAudit] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_POINTHISTORY1 = "/pointhistory"
    SlashCmdList["POINTHISTORY"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "player" then
            if args and args ~= "" then
                local history = PointHistoryAudit:GetPlayerHistory(args, 30)
                print("Point history for " .. args .. " (last 30 days):")
                for _, entry in ipairs(history) do
                    local dateStr = date("%Y-%m-%d %H:%M", entry.timestamp)
                    print("  " .. dateStr .. " | " .. entry.action .. " | " .. tostring(entry.amount))
                end
            else
                print("Usage: /pointhistory player <name>")
            end
        elseif cmd == "stats" then
            if args and args ~= "" then
                local stats = PointHistoryAudit:CalculatePlayerStats(args, 30)
                print("Stats for " .. args .. ":")
                for k, v in pairs(stats) do
                    if k ~= "player" then
                        print("  " .. k .. ": " .. tostring(v))
                    end
                end
            else
                print("Usage: /pointhistory stats <name>")
            end
        elseif cmd == "status" then
            local status = PointHistoryAudit:GetStatus()
            print("Point History Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Point History Audit Commands:")
            print("  /pointhistory player <name> - Show player's point history")
            print("  /pointhistory stats <name> - Show player's statistics")
            print("  /pointhistory status - Show system status")
        end
    end
end

return PointHistoryAudit
