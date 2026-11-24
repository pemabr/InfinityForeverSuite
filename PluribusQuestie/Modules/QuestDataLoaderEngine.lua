-- QuestDataLoaderEngine.lua - Load and manage quest data from various sources
-- Part of PluribusQuestie addon suite
-- Handles Questie DB integration, versioning, and localization

local QuestDataLoaderEngine = {}
QuestDataLoaderEngine.enabled = false
QuestDataLoaderEngine.db = nil
QuestDataLoaderEngine.data_sources = {}
QuestDataLoaderEngine.loaded_data = {}
QuestDataLoaderEngine.version = "1.0.0"

-- Configuration
QuestDataLoaderEngine.config = {
    enabled = true,
    auto_load = true,
    cache_data = true,
    max_retries = 3,
}

function QuestDataLoaderEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.data_sources then
        self.db.data_sources = {}
    end
    
    if not self.db.loaded_data then
        self.db.loaded_data = {}
    end
    
    self.data_sources = self.db.data_sources
    self.loaded_data = self.db.loaded_data
    self.enabled = true
    
    self:Log("Initialized quest data loader engine (v" .. self.version .. ")")
end

function QuestDataLoaderEngine:RegisterDataSource(sourceName, sourceType, loadFunction)
    if not sourceName or not sourceType or not loadFunction then
        return false
    end
    
    local source = {
        name = sourceName,
        type = sourceType,  -- questiedb, blizzard, custom
        load_function = loadFunction,
        loaded = false,
        error = nil,
        loaded_at = nil,
        item_count = 0,
    }
    
    table.insert(self.data_sources, source)
    self:Log("Registered data source: " .. sourceName .. " (" .. sourceType .. ")")
    
    return true
end

function QuestDataLoaderEngine:LoadFromSource(sourceName)
    if not sourceName then
        return false
    end
    
    local source = nil
    for _, s in ipairs(self.data_sources) do
        if s.name == sourceName then
            source = s
            break
        end
    end
    
    if not source then
        self:Log("Data source not found: " .. sourceName)
        return false
    end
    
    local success, result = pcall(source.load_function)
    
    if success and result then
        self.loaded_data[sourceName] = result
        source.loaded = true
        source.error = nil
        source.loaded_at = GetTime()
        source.item_count = type(result) == "table" and table.getn(result) or 0
        
        self:Log("Loaded data from " .. sourceName .. ": " .. source.item_count .. " items")
        return true
    else
        source.error = tostring(result)
        self:Log("Error loading from " .. sourceName .. ": " .. source.error)
        return false
    end
end

function QuestDataLoaderEngine:LoadAllSources()
    local successCount = 0
    local failureCount = 0
    
    for _, source in ipairs(self.data_sources) do
        if self:LoadFromSource(source.name) then
            successCount = successCount + 1
        else
            failureCount = failureCount + 1
        end
    end
    
    self:Log("Loaded all sources: " .. successCount .. " success, " .. failureCount .. " failures")
    return successCount, failureCount
end

function QuestDataLoaderEngine:UnloadSource(sourceName)
    if not sourceName then
        return false
    end
    
    if self.loaded_data[sourceName] then
        self.loaded_data[sourceName] = nil
        
        for _, source in ipairs(self.data_sources) do
            if source.name == sourceName then
                source.loaded = false
                break
            end
        end
        
        self:Log("Unloaded data source: " .. sourceName)
        return true
    end
    
    return false
end

function QuestDataLoaderEngine:GetLoadedData(sourceName)
    if not sourceName then
        return nil
    end
    
    return self.loaded_data[sourceName]
end

function QuestDataLoaderEngine:GetDataSourceStatus(sourceName)
    for _, source in ipairs(self.data_sources) do
        if source.name == sourceName then
            return {
                name = source.name,
                type = source.type,
                loaded = source.loaded,
                item_count = source.item_count,
                loaded_at = source.loaded_at,
                error = source.error,
            }
        end
    end
    
    return nil
end

function QuestDataLoaderEngine:GetAllSourceStatus()
    local statuses = {}
    
    for _, source in ipairs(self.data_sources) do
        table.insert(statuses, {
            name = source.name,
            type = source.type,
            loaded = source.loaded,
            item_count = source.item_count,
        })
    end
    
    return statuses
end

function QuestDataLoaderEngine:HandleExpansion(expansionId)
    if not expansionId then
        expansionId = GetExpansionLevel() or 0
    end
    
    self:Log("Handling expansion: " .. expansionId)
    
    -- Filter loaded data by expansion
    local expansion_data = {}
    
    for sourceName, data in pairs(self.loaded_data) do
        if type(data) == "table" then
            expansion_data[sourceName] = {}
            
            for _, item in ipairs(data) do
                if not item.expansion or item.expansion <= expansionId then
                    table.insert(expansion_data[sourceName], item)
                end
            end
        end
    end
    
    return expansion_data
end

function QuestDataLoaderEngine:MigrateData(oldVersion, newVersion)
    if not oldVersion or not newVersion then
        return false
    end
    
    self:Log("Migrating data from v" .. oldVersion .. " to v" .. newVersion)
    
    -- Placeholder for data migration logic
    local migrated = 0
    
    for sourceName, data in pairs(self.loaded_data) do
        if type(data) == "table" then
            for _, item in ipairs(data) do
                -- Apply version-specific migrations here
                migrated = migrated + 1
            end
        end
    end
    
    self:Log("Migrated " .. migrated .. " items")
    return true
end

function QuestDataLoaderEngine:ValidateData(sourceName)
    local data = self:GetLoadedData(sourceName)
    if not data then
        return false
    end
    
    if type(data) ~= "table" then
        self:Log("Invalid data type for source: " .. sourceName)
        return false
    end
    
    local valid = 0
    local invalid = 0
    
    for _, item in ipairs(data) do
        if self:IsValidQuestItem(item) then
            valid = valid + 1
        else
            invalid = invalid + 1
        end
    end
    
    self:Log("Validated " .. sourceName .. ": " .. valid .. " valid, " .. invalid .. " invalid")
    return invalid == 0
end

function QuestDataLoaderEngine:IsValidQuestItem(item)
    if not item or type(item) ~= "table" then
        return false
    end
    
    -- Check for required fields
    return item.id ~= nil and item.name ~= nil
end

function QuestDataLoaderEngine:ExportData(sourceName, format)
    format = format or "lua"  -- lua, json
    
    local data = self:GetLoadedData(sourceName)
    if not data then
        return nil
    end
    
    if format == "lua" then
        return self:ExportAsLua(sourceName, data)
    elseif format == "json" then
        return self:ExportAsJSON(sourceName, data)
    end
    
    return nil
end

function QuestDataLoaderEngine:ExportAsLua(sourceName, data)
    local lua = "-- Exported from " .. sourceName .. " at " .. date("%Y-%m-%d %H:%M:%S") .. "\n"
    lua = lua .. "local " .. sourceName .. "_data = {\n"
    
    if type(data) == "table" then
        for i, item in ipairs(data) do
            if i > 100 then break end  -- Limit export
            lua = lua .. "  {\n"
            lua = lua .. "    id = " .. (item.id or 0) .. ",\n"
            lua = lua .. "    name = '" .. (item.name or "") .. "',\n"
            lua = lua .. "  },\n"
        end
    end
    
    lua = lua .. "}\nreturn " .. sourceName .. "_data"
    return lua
end

function QuestDataLoaderEngine:ExportAsJSON(sourceName, data)
    -- Simple JSON export (would need proper JSON library for production)
    local json = "[]\n"
    return json
end

function QuestDataLoaderEngine:GetStatus()
    local loadedCount = 0
    
    for _, source in ipairs(self.data_sources) do
        if source.loaded then
            loadedCount = loadedCount + 1
        end
    end
    
    return {
        enabled = self.enabled,
        version = self.version,
        total_sources = #self.data_sources,
        loaded_sources = loadedCount,
        cached_items = table.getn(self.loaded_data),
    }
end

function QuestDataLoaderEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestDataLoaderEngine] " .. message)
    else
        print("[QuestDataLoaderEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTDATA1 = "/questdata"
    SlashCmdList["QUESTDATA"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "load" then
            local sourceName = args
            if sourceName ~= "" then
                if QuestDataLoaderEngine:LoadFromSource(sourceName) then
                    print("Loaded data source: " .. sourceName)
                else
                    print("Failed to load: " .. sourceName)
                end
            else
                print("Usage: /questdata load <sourceName>")
            end
        elseif cmd == "unload" then
            local sourceName = args
            if sourceName ~= "" then
                QuestDataLoaderEngine:UnloadSource(sourceName)
                print("Unloaded data source: " .. sourceName)
            else
                print("Usage: /questdata unload <sourceName>")
            end
        elseif cmd == "loadall" then
            local success, failure = QuestDataLoaderEngine:LoadAllSources()
            print("Loaded all sources: " .. success .. " success, " .. failure .. " failures")
        elseif cmd == "validate" then
            local sourceName = args
            if sourceName ~= "" then
                local valid = QuestDataLoaderEngine:ValidateData(sourceName)
                print("Validation for " .. sourceName .. ": " .. (valid and "PASS" or "FAIL"))
            else
                print("Usage: /questdata validate <sourceName>")
            end
        elseif cmd == "status" then
            local statuses = QuestDataLoaderEngine:GetAllSourceStatus()
            print("Data Sources:")
            for i, status in ipairs(statuses) do
                print("  [" .. i .. "] " .. status.name .. " (" .. status.type .. ") - " ..
                      (status.loaded and "Loaded" or "Not Loaded") .. " - " .. status.item_count .. " items")
            end
        else
            print("Quest Data Loader Commands:")
            print("  /questdata load <sourceName> - Load specific source")
            print("  /questdata unload <sourceName> - Unload source")
            print("  /questdata loadall - Load all sources")
            print("  /questdata validate <sourceName> - Validate source data")
            print("  /questdata status - Show source status")
        end
    end
end

return QuestDataLoaderEngine
