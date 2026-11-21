-- QuestDataVersionEngine.lua - Handle data versioning and migration
-- Part of InfinityQuestie addon suite
-- Manages quest data format upgrades, compatibility, and backward compatibility

local QuestDataVersionEngine = {}
QuestDataVersionEngine.enabled = false
QuestDataVersionEngine.db = nil
QuestDataVersionEngine.current_version = "1.0.0"
QuestDataVersionEngine.saved_version = nil
QuestDataVersionEngine.migrations = {}
QuestDataVersionEngine.version_history = {}

-- Configuration
QuestDataVersionEngine.config = {
    enabled = true,
    auto_migrate = true,
    keep_history = true,
}

-- Define migration steps
QuestDataVersionEngine.version_steps = {
    "0.1.0",  -- Initial version
    "0.5.0",  -- Quest name support
    "0.8.0",  -- Objective tracking added
    "1.0.0",  -- Full feature set
}

function QuestDataVersionEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.data_version then
        self.db.data_version = self.current_version
    end
    
    if not self.db.version_history then
        self.db.version_history = {}
    end
    
    self.saved_version = self.db.data_version
    self.version_history = self.db.version_history
    self.enabled = true
    
    self:Log("Initialized version engine (saved: " .. self.saved_version .. ", current: " .. self.current_version .. ")")
    
    -- Auto-migrate if versions don't match
    if self.saved_version ~= self.current_version and self.config.auto_migrate then
        self:MigrateData(self.saved_version, self.current_version)
    end
end

function QuestDataVersionEngine:ParseVersion(versionString)
    if not versionString then
        return nil
    end
    
    local major, minor, patch = versionString:match("^(%d+)%.(%d+)%.(%d+)$")
    
    if major and minor and patch then
        return {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            string = versionString,
        }
    end
    
    return nil
end

function QuestDataVersionEngine:CompareVersions(version1, version2)
    local v1 = self:ParseVersion(version1)
    local v2 = self:ParseVersion(version2)
    
    if not v1 or not v2 then
        return 0
    end
    
    if v1.major ~= v2.major then
        return v1.major < v2.major and -1 or 1
    end
    
    if v1.minor ~= v2.minor then
        return v1.minor < v2.minor and -1 or 1
    end
    
    if v1.patch ~= v2.patch then
        return v1.patch < v2.patch and -1 or 1
    end
    
    return 0
end

function QuestDataVersionEngine:IsVersionCompatible(version)
    if not version then
        return false
    end
    
    local comparison = self:CompareVersions(version, self.current_version)
    return comparison <= 0  -- Version must be <= current
end

function QuestDataVersionEngine:RegisterMigration(fromVersion, toVersion, migrationFunction)
    if not fromVersion or not toVersion or not migrationFunction then
        return false
    end
    
    local key = fromVersion .. " -> " .. toVersion
    self.migrations[key] = {
        from = fromVersion,
        to = toVersion,
        func = migrationFunction,
    }
    
    self:Log("Registered migration: " .. key)
    return true
end

function QuestDataVersionEngine:GetMigration(fromVersion, toVersion)
    local key = fromVersion .. " -> " .. toVersion
    return self.migrations[key]
end

function QuestDataVersionEngine:MigrateData(fromVersion, toVersion)
    if not fromVersion or not toVersion then
        return false
    end
    
    if self:CompareVersions(fromVersion, toVersion) >= 0 then
        self:Log("No migration needed: " .. fromVersion .. " >= " .. toVersion)
        return true
    end
    
    self:Log("Starting migration from " .. fromVersion .. " to " .. toVersion)
    
    -- Record migration in history
    table.insert(self.version_history, {
        from = fromVersion,
        to = toVersion,
        timestamp = GetTime(),
    })
    
    -- Apply migration steps
    local currentVersion = fromVersion
    local migrations_applied = 0
    
    while self:CompareVersions(currentVersion, toVersion) < 0 do
        local nextVersion = self:FindNextVersion(currentVersion)
        
        if not nextVersion then
            self:Log("No migration path found from " .. currentVersion)
            return false
        end
        
        local migration = self:GetMigration(currentVersion, nextVersion)
        
        if migration and migration.func then
            local success, result = pcall(migration.func, self.db)
            
            if success then
                currentVersion = nextVersion
                migrations_applied = migrations_applied + 1
                self:Log("Applied migration step: " .. currentVersion)
            else
                self:Log("Migration failed at step " .. nextVersion .. ": " .. tostring(result))
                return false
            end
        else
            self:Log("No migration function for " .. currentVersion .. " -> " .. nextVersion)
            return false
        end
    end
    
    self.saved_version = currentVersion
    self.db.data_version = currentVersion
    
    self:Log("Migration complete: applied " .. migrations_applied .. " steps")
    return true
end

function QuestDataVersionEngine:FindNextVersion(currentVersion)
    local current_index = nil
    
    for i, version in ipairs(self.version_steps) do
        if version == currentVersion then
            current_index = i
            break
        end
    end
    
    if current_index and current_index < #self.version_steps then
        return self.version_steps[current_index + 1]
    end
    
    return nil
end

function QuestDataVersionEngine:ValidateDataFormat(questData)
    if not questData or type(questData) ~= "table" then
        return false
    end
    
    -- Check required fields based on version
    if self.saved_version == "0.1.0" then
        return questData.id ~= nil
    elseif self.saved_version == "0.5.0" or self.saved_version == "0.8.0" then
        return questData.id ~= nil and questData.name ~= nil
    elseif self.saved_version == "1.0.0" then
        return questData.id ~= nil and questData.name ~= nil and questData.objectives ~= nil
    end
    
    return true
end

function QuestDataVersionEngine:UpgradeQuestItem(questItem)
    if not questItem then
        return nil
    end
    
    -- Upgrade to current format
    local upgraded = {
        id = questItem.id,
        name = questItem.name or "Quest " .. questItem.id,
        description = questItem.description or questItem.desc or "",
        objectives = questItem.objectives or {},
        level = questItem.level,
        difficulty = questItem.difficulty,
        rewards = questItem.rewards or {},
        prerequisites = questItem.prerequisites or {},
    }
    
    return upgraded
end

function QuestDataVersionEngine:DowngradeQuestItem(questItem, targetVersion)
    if not questItem or not targetVersion then
        return nil
    end
    
    if targetVersion == "0.1.0" then
        return {
            id = questItem.id,
        }
    elseif targetVersion == "0.5.0" then
        return {
            id = questItem.id,
            name = questItem.name,
        }
    elseif targetVersion == "0.8.0" then
        return {
            id = questItem.id,
            name = questItem.name,
            objectives = questItem.objectives,
        }
    end
    
    return questItem
end

function QuestDataVersionEngine:GetSavedVersion()
    return self.saved_version
end

function QuestDataVersionEngine:GetCurrentVersion()
    return self.current_version
end

function QuestDataVersionEngine:SetCurrentVersion(newVersion)
    if not self:IsVersionCompatible(newVersion) then
        self:Log("Invalid version: " .. newVersion)
        return false
    end
    
    self.current_version = newVersion
    self:Log("Current version set to: " .. newVersion)
    return true
end

function QuestDataVersionEngine:GetVersionHistory()
    return self.version_history
end

function QuestDataVersionEngine:GetSupportedVersions()
    return self.version_steps
end

function QuestDataVersionEngine:IsVersionSupported(version)
    if not version then
        return false
    end
    
    for _, v in ipairs(self.version_steps) do
        if v == version then
            return true
        end
    end
    
    return false
end

function QuestDataVersionEngine:GetStatus()
    local history_count = table.getn(self.version_history)
    
    return {
        enabled = self.enabled,
        saved_version = self.saved_version,
        current_version = self.current_version,
        needs_migration = self.saved_version ~= self.current_version,
        migrations_performed = history_count,
        is_compatible = self:IsVersionCompatible(self.saved_version),
    }
end

function QuestDataVersionEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestDataVersionEngine] " .. message)
    else
        print("[QuestDataVersionEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTVER1 = "/questver"
    SlashCmdList["QUESTVER"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "current" then
            print("Current version: " .. QuestDataVersionEngine:GetCurrentVersion())
            print("Saved version: " .. QuestDataVersionEngine:GetSavedVersion())
        elseif cmd == "migrate" then
            local fromVer = args:match("^(%S+)")
            if fromVer then
                QuestDataVersionEngine:MigrateData(fromVer, QuestDataVersionEngine:GetCurrentVersion())
                print("Migration started from: " .. fromVer)
            else
                local from = QuestDataVersionEngine:GetSavedVersion()
                local to = QuestDataVersionEngine:GetCurrentVersion()
                if QuestDataVersionEngine:MigrateData(from, to) then
                    print("Migration successful")
                else
                    print("Migration failed")
                end
            end
        elseif cmd == "supported" then
            local versions = QuestDataVersionEngine:GetSupportedVersions()
            print("Supported versions:")
            for i, version in ipairs(versions) do
                print("  [" .. i .. "] " .. version)
            end
        elseif cmd == "history" then
            local history = QuestDataVersionEngine:GetVersionHistory()
            if #history > 0 then
                print("Migration history:")
                for i, entry in ipairs(history) do
                    print("  [" .. i .. "] " .. entry.from .. " -> " .. entry.to .. 
                          " (at " .. date("%H:%M:%S", entry.timestamp) .. ")")
                end
            else
                print("No migrations performed")
            end
        elseif cmd == "validate" then
            local status = QuestDataVersionEngine:GetStatus()
            print("Version Status:")
            print("  Saved: " .. status.saved_version)
            print("  Current: " .. status.current_version)
            print("  Compatible: " .. (status.is_compatible and "Yes" or "No"))
            print("  Needs Migration: " .. (status.needs_migration and "Yes" or "No"))
        elseif cmd == "status" then
            local status = QuestDataVersionEngine:GetStatus()
            print("Quest Version Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Saved Version: " .. status.saved_version)
            print("  Current Version: " .. status.current_version)
            print("  Migrations Performed: " .. status.migrations_performed)
        else
            print("Quest Version Commands:")
            print("  /questver current - Show current and saved versions")
            print("  /questver migrate [fromVersion] - Run migration")
            print("  /questver supported - List supported versions")
            print("  /questver history - Show migration history")
            print("  /questver validate - Validate version compatibility")
            print("  /questver status - Show engine status")
        end
    end
end

return QuestDataVersionEngine
