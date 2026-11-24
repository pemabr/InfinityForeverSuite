-- QuestExpansionDataEngine.lua - Manage expansion-specific quest data
-- Part of PluribusQuestie addon suite
-- Handles expansion detection, data filtering, and cross-expansion compatibility

local QuestExpansionDataEngine = {}
QuestExpansionDataEngine.enabled = false
QuestExpansionDataEngine.db = nil
QuestExpansionDataEngine.expansions = {}
QuestExpansionDataEngine.current_expansion = 0
QuestExpansionDataEngine.expansion_data = {}

-- Configuration
QuestExpansionDataEngine.config = {
    enabled = true,
    auto_detect = true,
}

-- Expansion reference data
QuestExpansionDataEngine.expansion_info = {
    {id = 0, name = "Classic", min_level = 1, max_level = 60},
    {id = 1, name = "The Burning Crusade", min_level = 58, max_level = 70},
    {id = 2, name = "Wrath of the Lich King", min_level = 68, max_level = 80},
    {id = 3, name = "Cataclysm", min_level = 78, max_level = 85},
    {id = 4, name = "Mists of Pandaria", min_level = 85, max_level = 90},
    {id = 5, name = "Warlords of Draenor", min_level = 90, max_level = 100},
    {id = 6, name = "Legion", min_level = 98, max_level = 110},
    {id = 7, name = "Battle for Azeroth", min_level = 110, max_level = 120},
    {id = 8, name = "Shadowlands", min_level = 48, max_level = 60},
    {id = 9, name = "Dragonflight", min_level = 58, max_level = 70},
}

function QuestExpansionDataEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.expansion_data then
        self.db.expansion_data = {}
    end
    
    self.expansion_data = self.db.expansion_data
    self.current_expansion = self:DetectCurrentExpansion()
    self.enabled = true
    
    self:Log("Initialized expansion data engine (current expansion: " .. self.current_expansion .. ")")
end

function QuestExpansionDataEngine:DetectCurrentExpansion()
    local expansion = GetExpansionLevel() or 0
    return expansion
end

function QuestExpansionDataEngine:GetExpansionName(expansionId)
    if not expansionId then
        return nil
    end
    
    for _, expansion in ipairs(self.expansion_info) do
        if expansion.id == expansionId then
            return expansion.name
        end
    end
    
    return "Unknown Expansion"
end

function QuestExpansionDataEngine:GetExpansionInfo(expansionId)
    if not expansionId then
        expansionId = self.current_expansion
    end
    
    for _, expansion in ipairs(self.expansion_info) do
        if expansion.id == expansionId then
            return {
                id = expansion.id,
                name = expansion.name,
                min_level = expansion.min_level,
                max_level = expansion.max_level,
            }
        end
    end
    
    return nil
end

function QuestExpansionDataEngine:GetCurrentExpansion()
    return self.current_expansion
end

function QuestExpansionDataEngine:GetCurrentExpansionName()
    return self:GetExpansionName(self.current_expansion)
end

function QuestExpansionDataEngine:RegisterExpansionData(expansionId, questData)
    if not expansionId or not questData then
        return false
    end
    
    if not self.expansion_data[expansionId] then
        self.expansion_data[expansionId] = {}
    end
    
    if type(questData) == "table" and questData.id then
        self.expansion_data[expansionId][questData.id] = questData
        return true
    elseif type(questData) == "table" then
        for _, quest in ipairs(questData) do
            if quest.id then
                self.expansion_data[expansionId][quest.id] = quest
            end
        end
        return true
    end
    
    return false
end

function QuestExpansionDataEngine:GetExpansionQuestData(expansionId)
    if not expansionId then
        expansionId = self.current_expansion
    end
    
    if self.expansion_data[expansionId] then
        return self.expansion_data[expansionId]
    end
    
    return {}
end

function QuestExpansionDataEngine:GetQuestInExpansion(questId, expansionId)
    if not questId then
        return nil
    end
    
    if not expansionId then
        expansionId = self.current_expansion
    end
    
    local quest_data = self:GetExpansionQuestData(expansionId)
    
    if quest_data and quest_data[questId] then
        return quest_data[questId]
    end
    
    return nil
end

function QuestExpansionDataEngine:FilterQuestsByExpansion(questList, expansionId)
    if not questList then
        return {}
    end
    
    if not expansionId then
        expansionId = self.current_expansion
    end
    
    local filtered = {}
    
    for _, quest in ipairs(questList) do
        if quest.expansion and quest.expansion <= expansionId then
            table.insert(filtered, quest)
        elseif not quest.expansion then
            table.insert(filtered, quest)
        end
    end
    
    return filtered
end

function QuestExpansionDataEngine:GetQuestsForCurrentExpansion(questList)
    return self:FilterQuestsByExpansion(questList, self.current_expansion)
end

function QuestExpansionDataEngine:LoadExpansionData(expansionId)
    if not expansionId then
        expansionId = self.current_expansion
    end
    
    self:Log("Loading data for expansion: " .. self:GetExpansionName(expansionId))
    
    -- Placeholder for loading expansion-specific data
    -- This would typically load from a data source
    if not self.expansion_data[expansionId] then
        self.expansion_data[expansionId] = {}
    end
    
    return true
end

function QuestExpansionDataEngine:UnloadExpansionData(expansionId)
    if not expansionId then
        return false
    end
    
    if self.expansion_data[expansionId] then
        self.expansion_data[expansionId] = nil
        self:Log("Unloaded data for expansion: " .. self:GetExpansionName(expansionId))
        return true
    end
    
    return false
end

function QuestExpansionDataEngine:ClearExpansionData(expansionId)
    if not expansionId then
        return false
    end
    
    if self.expansion_data[expansionId] then
        self.expansion_data[expansionId] = {}
        self:Log("Cleared data for expansion: " .. self:GetExpansionName(expansionId))
        return true
    end
    
    return false
end

function QuestExpansionDataEngine:GetAvailableExpansions()
    local available = {}
    
    for _, expansion in ipairs(self.expansion_info) do
        table.insert(available, {
            id = expansion.id,
            name = expansion.name,
            loaded = self.expansion_data[expansion.id] ~= nil,
            quest_count = self.expansion_data[expansion.id] and table.getn(self.expansion_data[expansion.id]) or 0,
        })
    end
    
    return available
end

function QuestExpansionDataEngine:GetExpansionLoadStatus()
    local status = {}
    
    for _, expansion in ipairs(self.expansion_info) do
        status[expansion.id] = {
            name = expansion.name,
            loaded = self.expansion_data[expansion.id] ~= nil,
            quest_count = self.expansion_data[expansion.id] and table.getn(self.expansion_data[expansion.id]) or 0,
        }
    end
    
    return status
end

function QuestExpansionDataEngine:GetCompatibilityMode()
    -- Check if running on a classic/legacy expansion server
    local expansion = self:GetCurrentExpansion()
    local info = self:GetExpansionInfo(expansion)
    
    return {
        expansion_id = expansion,
        expansion_name = info and info.name or "Unknown",
        min_level = info and info.min_level or 1,
        max_level = info and info.max_level or 60,
    }
end

function QuestExpansionDataEngine:IsQuestCompatible(quest, expansionId)
    if not quest then
        return false
    end
    
    if not expansionId then
        expansionId = self.current_expansion
    end
    
    -- Quest is compatible if:
    -- 1. It has no expansion restriction
    -- 2. Its expansion ID is <= current expansion
    -- 3. Its level range overlaps with expansion level range
    
    if not quest.expansion or quest.expansion <= expansionId then
        return true
    end
    
    return false
end

function QuestExpansionDataEngine:GetQuestExpansion(questId)
    -- Search all loaded expansions for the quest
    for expId, questData in pairs(self.expansion_data) do
        if questData[questId] then
            return expId
        end
    end
    
    return nil
end

function QuestExpansionDataEngine:MigrateDataBetweenExpansions(sourceExpansion, targetExpansion)
    if not sourceExpansion or not targetExpansion then
        return 0
    end
    
    if sourceExpansion == targetExpansion then
        return 0
    end
    
    local sourceData = self:GetExpansionQuestData(sourceExpansion)
    local migratedCount = 0
    
    for questId, questData in pairs(sourceData) do
        if self:RegisterExpansionData(targetExpansion, questData) then
            migratedCount = migratedCount + 1
        end
    end
    
    self:Log("Migrated " .. migratedCount .. " quests from expansion " .. sourceExpansion .. 
             " to " .. targetExpansion)
    
    return migratedCount
end

function QuestExpansionDataEngine:GetStatus()
    local loadedExpansions = 0
    
    for _, expansion in ipairs(self.expansion_info) do
        if self.expansion_data[expansion.id] and table.getn(self.expansion_data[expansion.id]) > 0 then
            loadedExpansions = loadedExpansions + 1
        end
    end
    
    return {
        enabled = self.enabled,
        current_expansion = self.current_expansion,
        current_expansion_name = self:GetCurrentExpansionName(),
        total_expansions = #self.expansion_info,
        loaded_expansions = loadedExpansions,
    }
end

function QuestExpansionDataEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestExpansionDataEngine] " .. message)
    else
        print("[QuestExpansionDataEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTEXP1 = "/questexp"
    SlashCmdList["QUESTEXP"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "current" then
            local name = QuestExpansionDataEngine:GetCurrentExpansionName()
            print("Current expansion: " .. name .. " (ID: " .. QuestExpansionDataEngine:GetCurrentExpansion() .. ")")
        elseif cmd == "load" then
            local expId = tonumber(args)
            if expId then
                QuestExpansionDataEngine:LoadExpansionData(expId)
                print("Loading data for expansion: " .. expId)
            else
                print("Usage: /questexp load <expansionId>")
            end
        elseif cmd == "unload" then
            local expId = tonumber(args)
            if expId then
                QuestExpansionDataEngine:UnloadExpansionData(expId)
                print("Unloaded expansion data: " .. expId)
            else
                print("Usage: /questexp unload <expansionId>")
            end
        elseif cmd == "clear" then
            local expId = tonumber(args)
            if expId then
                QuestExpansionDataEngine:ClearExpansionData(expId)
                print("Cleared expansion data: " .. expId)
            else
                print("Usage: /questexp clear <expansionId>")
            end
        elseif cmd == "list" then
            local expansions = QuestExpansionDataEngine:GetAvailableExpansions()
            print("Available Expansions:")
            for i, exp in ipairs(expansions) do
                print("  [" .. exp.id .. "] " .. exp.name .. " - " .. 
                      (exp.loaded and "Loaded" or "Not Loaded") .. " (" .. exp.quest_count .. " quests)")
            end
        elseif cmd == "status" then
            local status = QuestExpansionDataEngine:GetStatus()
            print("Expansion Status:")
            print("  Current: " .. status.current_expansion_name .. " (ID: " .. status.current_expansion .. ")")
            print("  Loaded Expansions: " .. status.loaded_expansions .. "/" .. status.total_expansions)
        else
            print("Quest Expansion Commands:")
            print("  /questexp current - Show current expansion")
            print("  /questexp load <id> - Load expansion data")
            print("  /questexp unload <id> - Unload expansion data")
            print("  /questexp clear <id> - Clear expansion data")
            print("  /questexp list - List all expansions")
            print("  /questexp status - Show expansion status")
        end
    end
end

return QuestExpansionDataEngine
