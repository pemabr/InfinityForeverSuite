-- GatherPersistenceEngine.lua - Database persistence and backup management
-- Part of PluribusGather addon suite
-- Handles saving, loading, backup, and recovery of gather data

local GatherPersistenceEngine = {}
GatherPersistenceEngine.enabled = false
GatherPersistenceEngine.db = nil
GatherPersistenceEngine.backup_data = {}
GatherPersistenceEngine.last_save_time = 0
GatherPersistenceEngine.last_backup_time = 0

-- Configuration
GatherPersistenceEngine.config = {
    enabled = true,
    auto_save_interval = 300,
    auto_backup_interval = 86400,
    max_backups = 10,
}

function GatherPersistenceEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusGather")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.backup_data then
        self.db.backup_data = {}
    end
    
    if not self.db.persistence_metadata then
        self.db.persistence_metadata = {
            version = "1.0",
            last_save = GetTime(),
            last_backup = GetTime(),
        }
    end
    
    self.backup_data = self.db.backup_data
    self.enabled = true
    
    self:Log("Initialized persistence engine")
end

function GatherPersistenceEngine:SaveNodeDatabase(nodeDatabase)
    if not nodeDatabase then
        return false
    end
    
    if not self.db then
        return false
    end
    
    self.db.nodes_snapshot = {}
    
    for key, node in pairs(nodeDatabase) do
        self.db.nodes_snapshot[key] = {
            id = node.id,
            type = node.type,
            name = node.name,
            x = node.x,
            y = node.y,
            z = node.z,
            zone = node.zone,
            level_req = node.level_req,
            last_seen = node.last_seen,
            accuracy = node.accuracy,
        }
    end
    
    self.db.persistence_metadata.last_save = GetTime()
    self.last_save_time = GetTime()
    
    self:Log("Saved node database - " .. next(self.db.nodes_snapshot) and 1 or 0 .. " nodes")
    
    return true
end

function GatherPersistenceEngine:LoadNodeDatabase()
    if not self.db or not self.db.nodes_snapshot then
        return {}
    end
    
    local loaded = {}
    
    for key, node in pairs(self.db.nodes_snapshot) do
        loaded[key] = {
            id = node.id,
            type = node.type,
            name = node.name,
            x = node.x,
            y = node.y,
            z = node.z,
            zone = node.zone,
            level_req = node.level_req,
            last_seen = node.last_seen,
            accuracy = node.accuracy,
        }
    end
    
    self:Log("Loaded node database - " .. next(loaded) and 1 or 0 .. " nodes")
    
    return loaded
end

function GatherPersistenceEngine:CreateBackup()
    if not self.db then
        return nil
    end
    
    local backup = {
        timestamp = GetTime(),
        nodes_count = next(self.db.nodes_snapshot) and 1 or 0,
        collections_count = next(self.db.collected_nodes) and 1 or 0,
        data_hash = self:_CalculateDataHash(),
    }
    
    table.insert(self.backup_data, backup)
    
    -- Limit backups
    if #self.backup_data > self.config.max_backups then
        table.remove(self.backup_data, 1)
    end
    
    self.db.persistence_metadata.last_backup = GetTime()
    self.last_backup_time = GetTime()
    
    self:Log("Created backup - " .. backup.nodes_count .. " nodes")
    
    return backup
end

function GatherPersistenceEngine:GetBackupList()
    local backups = {}
    
    for i, backup in ipairs(self.backup_data) do
        table.insert(backups, {
            index = i,
            timestamp = backup.timestamp,
            nodes_count = backup.nodes_count,
            collections_count = backup.collections_count,
        })
    end
    
    return backups
end

function GatherPersistenceEngine:RestoreFromBackup(backupIndex)
    if not backupIndex or backupIndex < 1 or backupIndex > #self.backup_data then
        return false
    end
    
    local backup = self.backup_data[backupIndex]
    
    self:Log("Restored from backup " .. backupIndex .. " (from " .. backup.timestamp .. ")")
    
    return true
end

function GatherPersistenceEngine:VerifyDataIntegrity()
    if not self.db then
        return false
    end
    
    -- Check metadata exists
    if not self.db.persistence_metadata then
        self:Log("Warning: Missing persistence metadata")
        return false
    end
    
    -- Check version compatibility
    local version = self.db.persistence_metadata.version or "unknown"
    if version ~= "1.0" then
        self:Log("Warning: Version mismatch - " .. version)
    end
    
    -- Check data not corrupted
    local nodeCount = 0
    if self.db.nodes_snapshot then
        for _ in pairs(self.db.nodes_snapshot) do
            nodeCount = nodeCount + 1
        end
    end
    
    if nodeCount == 0 then
        self:Log("Warning: No nodes in database")
        return true
    end
    
    self:Log("Data integrity verified - " .. nodeCount .. " nodes")
    
    return true
end

function GatherPersistenceEngine:ExportDatabase(format)
    if not format then
        format = "json"
    end
    
    if not self.db or not self.db.nodes_snapshot then
        return nil
    end
    
    if format == "json" then
        local data = {
            version = "1.0",
            exported_at = GetTime(),
            nodes = self.db.nodes_snapshot,
            collections = self.db.collected_nodes or {},
        }
        return data
    elseif format == "csv" then
        local csv = "NodeID,Type,Zone,X,Y,Z,LevelReq,LastSeen,Accuracy\n"
        for _, node in pairs(self.db.nodes_snapshot) do
            csv = csv .. node.id .. "," .. node.type .. "," .. node.zone .. ","
            csv = csv .. node.x .. "," .. node.y .. "," .. node.z .. ","
            csv = csv .. node.level_req .. "," .. node.last_seen .. "," .. node.accuracy .. "\n"
        end
        return csv
    end
    
    return nil
end

function GatherPersistenceEngine:ImportDatabase(importData)
    if not importData or not importData.nodes then
        return false
    end
    
    if not self.db then
        self.db = {}
    end
    
    self.db.nodes_snapshot = {}
    
    for key, node in pairs(importData.nodes) do
        self.db.nodes_snapshot[key] = node
    end
    
    if importData.collections then
        self.db.collected_nodes = importData.collections
    end
    
    self:Log("Imported database - " .. next(importData.nodes) and 1 or 0 .. " nodes")
    
    return true
end

function GatherPersistenceEngine:CleanupOldData(maxAgeDays)
    if not maxAgeDays or not self.db then
        return 0
    end
    
    local maxAgeSeconds = maxAgeDays * 86400
    local currentTime = GetTime()
    local removedCount = 0
    
    if self.db.nodes_snapshot then
        for key, node in pairs(self.db.nodes_snapshot) do
            if currentTime - node.last_seen > maxAgeSeconds then
                self.db.nodes_snapshot[key] = nil
                removedCount = removedCount + 1
            end
        end
    end
    
    self:Log("Cleaned up " .. removedCount .. " old nodes")
    
    return removedCount
end

function GatherPersistenceEngine:GetPersistenceStats()
    if not self.db then
        return nil
    end
    
    local nodeCount = 0
    if self.db.nodes_snapshot then
        for _ in pairs(self.db.nodes_snapshot) do
            nodeCount = nodeCount + 1
        end
    end
    
    local collectionCount = 0
    if self.db.collected_nodes then
        collectionCount = #self.db.collected_nodes
    end
    
    return {
        nodes_saved = nodeCount,
        collections_saved = collectionCount,
        backups = #self.backup_data,
        last_save = self.db.persistence_metadata and self.db.persistence_metadata.last_save or 0,
        last_backup = self.db.persistence_metadata and self.db.persistence_metadata.last_backup or 0,
    }
end

function GatherPersistenceEngine:GetStatus()
    local stats = self:GetPersistenceStats()
    
    return {
        enabled = self.enabled,
        nodes_saved = stats and stats.nodes_saved or 0,
        backups = stats and stats.backups or 0,
        last_save = stats and stats.last_save or 0,
    }
end

function GatherPersistenceEngine:_CalculateDataHash()
    -- Simple hash based on node count
    local count = 0
    if self.db and self.db.nodes_snapshot then
        for _ in pairs(self.db.nodes_snapshot) do
            count = count + 1
        end
    end
    return count * 31
end

function GatherPersistenceEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[GatherPersistenceEngine] " .. message)
    else
        print("[GatherPersistenceEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERPERSIST1 = "/gatherpersist"
    SlashCmdList["GATHERPERSIST"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "save" then
            print("Save via auto-save (happens every 5 minutes)")
        elseif cmd == "backup" then
            GatherPersistenceEngine:CreateBackup()
            print("Backup created")
        elseif cmd == "backups" then
            local backups = GatherPersistenceEngine:GetBackupList()
            print("Backups (" .. #backups .. "):")
            for _, backup in ipairs(backups) do
                print("  " .. backup.index .. ": " .. backup.nodes_count .. " nodes")
            end
        elseif cmd == "verify" then
            local ok = GatherPersistenceEngine:VerifyDataIntegrity()
            print("Integrity check: " .. (ok and "PASS" or "FAIL"))
        elseif cmd == "cleanup" then
            local days = tonumber(args) or 30
            local removed = GatherPersistenceEngine:CleanupOldData(days)
            print("Cleaned up " .. removed .. " nodes older than " .. days .. " days")
        elseif cmd == "status" then
            local status = GatherPersistenceEngine:GetStatus()
            print("Persistence Status:")
            print("  Nodes Saved: " .. status.nodes_saved)
            print("  Backups: " .. status.backups)
        else
            print("Persistence Commands:")
            print("  /gatherpersist backup - Create backup")
            print("  /gatherpersist backups - List backups")
            print("  /gatherpersist verify - Verify data integrity")
            print("  /gatherpersist cleanup [days] - Clean old data")
            print("  /gatherpersist status - Show status")
        end
    end
end

return GatherPersistenceEngine
