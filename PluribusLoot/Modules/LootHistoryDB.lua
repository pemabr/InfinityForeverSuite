-- Loot History Database
-- Track every loot award with full details for analysis and auditing

local MODULE_NAME = "LootHistoryDB"
local PluribusLoot = PluribusLoot or {}
local PluribusCore = PluribusCore or {}

PluribusLoot.HistoryDB = {
    enabled = false,
    
    config = {
        max_history_entries = 100000,  -- Keep last 100k loot records
        compress_old_data = true,
        compression_threshold = 50000,  -- Compress when exceeding this
        enable_indexing = true,
        index_by_player = true,
        index_by_item = true,
        index_by_date = true
    },
    
    loot_history = {},
    
    -- Indexes for fast lookups
    player_index = {},      -- player -> list of history IDs
    item_index = {},        -- item -> list of history IDs
    date_index = {}         -- date -> list of history IDs
}

local HistoryDB = PluribusLoot.HistoryDB

function HistoryDB:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if not PluribusLoot.db then
        PluribusLoot.db = {}
    end
    if not PluribusLoot.db.loot_history then
        PluribusLoot.db.loot_history = {}
    end
    
    self.loot_history = PluribusLoot.db.loot_history
    
    -- Rebuild indexes if needed
    if self.config.enable_indexing then
        self:RebuildIndexes()
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Register("loot_awarded", function(player, item, award_type, gp)
            HistoryDB:RecordLoot(player, item, award_type, gp)
        end)
    end
end

function HistoryDB:RecordLoot(player, item, award_type, gp_cost)
    if not player or not item then
        return
    end
    
    -- Create history entry
    local history_entry = {
        id = #self.loot_history + 1,
        timestamp = time(),
        player = player,
        item = item,
        award_type = award_type or "Unknown",
        gp_cost = gp_cost or 0,
        gp_earned = 0,  -- Will be calculated
        item_level = 0,  -- Will be populated from item data
        item_quality = 0  -- Will be populated from item data
    }
    
    table.insert(self.loot_history, history_entry)
    
    -- Maintain size limit
    if #self.loot_history > self.config.max_history_entries then
        table.remove(self.loot_history, 1)
    end
    
    -- Update indexes
    if self.config.enable_indexing then
        self:UpdateIndexes(history_entry)
    end
    
    if PluribusLoot.db then
        PluribusLoot.db.loot_history = self.loot_history
    end
end

function HistoryDB:UpdateIndexes(history_entry)
    if self.config.index_by_player then
        if not self.player_index[history_entry.player] then
            self.player_index[history_entry.player] = {}
        end
        table.insert(self.player_index[history_entry.player], history_entry.id)
    end
    
    if self.config.index_by_item then
        if not self.item_index[history_entry.item] then
            self.item_index[history_entry.item] = {}
        end
        table.insert(self.item_index[history_entry.item], history_entry.id)
    end
    
    if self.config.index_by_date then
        local date_key = date("%Y-%m-%d", history_entry.timestamp)
        if not self.date_index[date_key] then
            self.date_index[date_key] = {}
        end
        table.insert(self.date_index[date_key], history_entry.id)
    end
end

function HistoryDB:RebuildIndexes()
    self.player_index = {}
    self.item_index = {}
    self.date_index = {}
    
    for _, entry in ipairs(self.loot_history) do
        self:UpdateIndexes(entry)
    end
end

function HistoryDB:GetLootByPlayer(player_name)
    if not self.config.index_by_player or not self.player_index[player_name] then
        return {}
    end
    
    local results = {}
    for _, id in ipairs(self.player_index[player_name]) do
        if self.loot_history[id] then
            table.insert(results, self.loot_history[id])
        end
    end
    
    return results
end

function HistoryDB:GetLootByItem(item_name)
    if not self.config.index_by_item or not self.item_index[item_name] then
        return {}
    end
    
    local results = {}
    for _, id in ipairs(self.item_index[item_name]) do
        if self.loot_history[id] then
            table.insert(results, self.loot_history[id])
        end
    end
    
    return results
end

function HistoryDB:GetLootByDate(date_key)
    if not self.config.index_by_date or not self.date_index[date_key] then
        return {}
    end
    
    local results = {}
    for _, id in ipairs(self.date_index[date_key]) do
        if self.loot_history[id] then
            table.insert(results, self.loot_history[id])
        end
    end
    
    return results
end

function HistoryDB:GetLootInDateRange(start_date, end_date)
    local results = {}
    
    for _, entry in ipairs(self.loot_history) do
        local entry_date = date("%Y-%m-%d", entry.timestamp)
        if entry_date >= start_date and entry_date <= end_date then
            table.insert(results, entry)
        end
    end
    
    return results
end

function HistoryDB:GetPlayerLootValue(player_name)
    local loot = self:GetLootByPlayer(player_name)
    
    local total_gp = 0
    local total_items = 0
    
    for _, entry in ipairs(loot) do
        total_gp = total_gp + (entry.gp_cost or 0)
        total_items = total_items + 1
    end
    
    return {
        total_gp = total_gp,
        total_items = total_items,
        average_gp = total_items > 0 and (total_gp / total_items) or 0
    }
end

function HistoryDB:GetItemAcquisitionCount(item_name)
    local loot = self:GetLootByItem(item_name)
    
    local by_player = {}
    
    for _, entry in ipairs(loot) do
        if not by_player[entry.player] then
            by_player[entry.player] = 0
        end
        by_player[entry.player] = by_player[entry.player] + 1
    end
    
    return {
        total_awards = #loot,
        by_player = by_player
    }
end

function HistoryDB:QueryLoot(filters)
    local results = {}
    
    for _, entry in ipairs(self.loot_history) do
        local matches = true
        
        if filters.player and entry.player ~= filters.player then
            matches = false
        end
        
        if filters.item and entry.item ~= filters.item then
            matches = false
        end
        
        if filters.award_type and entry.award_type ~= filters.award_type then
            matches = false
        end
        
        if filters.start_date then
            local entry_date = date("%Y-%m-%d", entry.timestamp)
            if entry_date < filters.start_date then
                matches = false
            end
        end
        
        if filters.end_date then
            local entry_date = date("%Y-%m-%d", entry.timestamp)
            if entry_date > filters.end_date then
                matches = false
            end
        end
        
        if matches then
            table.insert(results, entry)
        end
    end
    
    return results
end

function HistoryDB:GetMostAwardedItems(limit)
    limit = limit or 20
    
    local item_counts = {}
    
    for _, entry in ipairs(self.loot_history) do
        if not item_counts[entry.item] then
            item_counts[entry.item] = 0
        end
        item_counts[entry.item] = item_counts[entry.item] + 1
    end
    
    -- Sort by count
    local sorted = {}
    for item, count in pairs(item_counts) do
        table.insert(sorted, {item = item, count = count})
    end
    
    table.sort(sorted, function(a, b) return a.count > b.count end)
    
    local results = {}
    for i = 1, math.min(limit, #sorted) do
        table.insert(results, sorted[i])
    end
    
    return results
end

function HistoryDB:PrintPlayerLootHistory(player_name, limit)
    limit = limit or 20
    
    local loot = self:GetLootByPlayer(player_name)
    
    if #loot == 0 then
        print("|cffff9900No loot history for player: " .. player_name .. "|r")
        return
    end
    
    print(string.format("|cff00ccffLoot History for %s (%d items):|r", player_name, #loot))
    print("")
    
    for i = #loot, math.max(1, #loot - limit + 1), -1 do
        local entry = loot[i]
        local date_str = date("%m-%d %H:%M", entry.timestamp)
        
        print(string.format("[%s] %s (%s) - %d GP",
            date_str,
            entry.item,
            entry.award_type,
            entry.gp_cost or 0
        ))
    end
    
    print("")
end

function HistoryDB:PrintMostAwardedItems(limit)
    limit = limit or 10
    
    local items = self:GetMostAwardedItems(limit)
    
    print("|cff00ccffMost Awarded Items:|r")
    print("")
    
    for _, item_info in ipairs(items) do
        print(string.format("  %s - %d awards", item_info.item, item_info.count))
    end
    
    print("")
end

function HistoryDB:PrintStatus()
    print("|cff00ccffLoot History Database Status:|r")
    print(string.format("  Enabled: %s", self.enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Total Entries: %d", #self.loot_history))
    print(string.format("  Indexing: %s", self.config.enable_indexing and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Player Index Entries: %d", self:CountKeys(self.player_index)))
    print(string.format("  Item Index Entries: %d", self:CountKeys(self.item_index)))
    print(string.format("  Date Index Entries: %d", self:CountKeys(self.date_index)))
    print("")
end

function HistoryDB:CountKeys(table_)
    local count = 0
    for _ in pairs(table_) do
        count = count + 1
    end
    return count
end

function HistoryDB:GetTotalEntries()
    return #self.loot_history
end

function HistoryDB:ClearOldEntries(days_to_keep)
    local cutoff_time = time() - (days_to_keep * 86400)
    
    local removed_count = 0
    local i = 1
    
    while i <= #self.loot_history do
        if self.loot_history[i].timestamp < cutoff_time then
            table.remove(self.loot_history, i)
            removed_count = removed_count + 1
        else
            i = i + 1
        end
    end
    
    if self.config.enable_indexing then
        self:RebuildIndexes()
    end
    
    if PluribusLoot.db then
        PluribusLoot.db.loot_history = self.loot_history
    end
    
    print(string.format("|cff00ccffRemoved %d old entries|r", removed_count))
    return removed_count
end

return PluribusLoot.HistoryDB
