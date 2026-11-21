-- QuestTypeFilterEngine.lua - Quest type classification and filtering
-- Part of InfinityQuestie addon suite
-- Handles quest type detection, categorization, and type-based filtering

local QuestTypeFilterEngine = {}
QuestTypeFilterEngine.enabled = false
QuestTypeFilterEngine.db = nil
QuestTypeFilterEngine.quest_types = {}
QuestTypeFilterEngine.type_colors = {}

-- Configuration
QuestTypeFilterEngine.config = {
    enabled = true,
    auto_classify = true,
}

-- Quest type definitions
QuestTypeFilterEngine.quest_type_list = {
    "Escort",
    "Event",
    "Dungeon",
    "Raid",
    "PvP",
    "Scenario",
    "Repeatable",
    "Daily",
    "Weekly",
    "Normal",
}

-- Type color mapping (for UI display)
QuestTypeFilterEngine.type_color_map = {
    Escort = "FFD100",      -- Gold
    Event = "FF8000",       -- Orange
    Dungeon = "0070DD",     -- Blue
    Raid = "FF0000",        -- Red
    PvP = "9900FF",         -- Purple
    Scenario = "1EFF00",    -- Green
    Repeatable = "FFFF00",  -- Yellow
    Daily = "00FFFF",       -- Cyan
    Weekly = "00FF7F",      -- Spring Green
    Normal = "FFFFFF",      -- White
}

function QuestTypeFilterEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.quest_types then
        self.db.quest_types = {}
    end
    
    if not self.db.type_colors then
        self.db.type_colors = {}
    end
    
    self.quest_types = self.db.quest_types
    self.type_colors = self.db.type_colors
    self.enabled = true
    
    self:Log("Initialized quest type filter engine")
end

function QuestTypeFilterEngine:ClassifyQuestType(questData)
    if not questData then
        return "Normal"
    end
    
    local types = {}
    
    -- Check quest flags and properties
    if questData.is_escort then
        table.insert(types, "Escort")
    end
    
    if questData.is_event then
        table.insert(types, "Event")
    end
    
    if questData.is_dungeon then
        table.insert(types, "Dungeon")
    end
    
    if questData.is_raid then
        table.insert(types, "Raid")
    end
    
    if questData.is_pvp then
        table.insert(types, "PvP")
    end
    
    if questData.is_scenario then
        table.insert(types, "Scenario")
    end
    
    if questData.is_repeatable then
        table.insert(types, "Repeatable")
    end
    
    if questData.is_daily then
        table.insert(types, "Daily")
    end
    
    if questData.is_weekly then
        table.insert(types, "Weekly")
    end
    
    -- If no types found, default to Normal
    if #types == 0 then
        types = {"Normal"}
    end
    
    return types
end

function QuestTypeFilterEngine:RegisterQuestType(questId, questTypes)
    if not questId or not questTypes then
        return false
    end
    
    -- Allow single type or table of types
    if type(questTypes) == "string" then
        questTypes = {questTypes}
    end
    
    if type(questTypes) ~= "table" then
        return false
    end
    
    -- Validate types
    for _, qtype in ipairs(questTypes) do
        local valid = false
        for _, validType in ipairs(self.quest_type_list) do
            if qtype == validType then
                valid = true
                break
            end
        end
        if not valid then
            self:Log("Invalid quest type: " .. qtype)
            return false
        end
    end
    
    self.quest_types[questId] = questTypes
    return true
end

function QuestTypeFilterEngine:GetQuestType(questId)
    if not questId then
        return nil
    end
    
    return self.quest_types[questId]
end

function QuestTypeFilterEngine:HasQuestType(questId, questType)
    if not questId or not questType then
        return false
    end
    
    local types = self:GetQuestType(questId)
    if not types then
        return false
    end
    
    for _, qtype in ipairs(types) do
        if qtype == questType then
            return true
        end
    end
    
    return false
end

function QuestTypeFilterEngine:FilterQuestsByType(questList, questType)
    if not questList or not questType then
        return {}
    end
    
    local filtered = {}
    
    for _, quest in ipairs(questList) do
        if self:HasQuestType(quest.id, questType) then
            table.insert(filtered, quest)
        end
    end
    
    return filtered
end

function QuestTypeFilterEngine:FilterQuestsByMultipleTypes(questList, questTypes, matchMode)
    if not questList or not questTypes then
        return {}
    end
    
    if type(questTypes) == "string" then
        questTypes = {questTypes}
    end
    
    matchMode = matchMode or "any"  -- any or all
    
    local filtered = {}
    
    for _, quest in ipairs(questList) do
        local questQuestTypes = self:GetQuestType(quest.id)
        
        if questQuestTypes then
            local matches = 0
            
            for _, questType in ipairs(questQuestTypes) do
                for _, filterType in ipairs(questTypes) do
                    if questType == filterType then
                        matches = matches + 1
                        break
                    end
                end
            end
            
            if matchMode == "any" and matches > 0 then
                table.insert(filtered, quest)
            elseif matchMode == "all" and matches == #questTypes then
                table.insert(filtered, quest)
            end
        end
    end
    
    return filtered
end

function QuestTypeFilterEngine:GetQuestTypeColor(questType)
    if not questType then
        return "FFFFFF"
    end
    
    if self.type_color_map[questType] then
        return self.type_color_map[questType]
    end
    
    if self.type_colors[questType] then
        return self.type_colors[questType]
    end
    
    return "FFFFFF"  -- Default white
end

function QuestTypeFilterEngine:SetQuestTypeColor(questType, colorCode)
    if not questType or not colorCode then
        return false
    end
    
    self.type_colors[questType] = colorCode
    return true
end

function QuestTypeFilterEngine:GetTypeDistribution(questList)
    if not questList then
        return {}
    end
    
    local distribution = {}
    
    for _, questType in ipairs(self.quest_type_list) do
        distribution[questType] = 0
    end
    
    for _, quest in ipairs(questList) do
        local types = self:GetQuestType(quest.id)
        if types then
            for _, qtype in ipairs(types) do
                if distribution[qtype] then
                    distribution[qtype] = distribution[qtype] + 1
                end
            end
        end
    end
    
    return distribution
end

function QuestTypeFilterEngine:GetEscortQuests(questList)
    return self:FilterQuestsByType(questList, "Escort")
end

function QuestTypeFilterEngine:GetDungeonQuests(questList)
    return self:FilterQuestsByType(questList, "Dungeon")
end

function QuestTypeFilterEngine:GetRaidQuests(questList)
    return self:FilterQuestsByType(questList, "Raid")
end

function QuestTypeFilterEngine:GetPvPQuests(questList)
    return self:FilterQuestsByType(questList, "PvP")
end

function QuestTypeFilterEngine:GetDailyQuests(questList)
    return self:FilterQuestsByType(questList, "Daily")
end

function QuestTypeFilterEngine:GetWeeklyQuests(questList)
    return self:FilterQuestsByType(questList, "Weekly")
end

function QuestTypeFilterEngine:GetRepeatableQuests(questList)
    return self:FilterQuestsByType(questList, "Repeatable")
end

function QuestTypeFilterEngine:GetEventQuests(questList)
    return self:FilterQuestsByType(questList, "Event")
end

function QuestTypeFilterEngine:GetSupportedTypes()
    return self.quest_type_list
end

function QuestTypeFilterEngine:GetStatus()
    local typeCount = table.getn(self.quest_types)
    
    return {
        enabled = self.enabled,
        total_types = #self.quest_type_list,
        cached_quest_types = typeCount,
        supported_types = self.quest_type_list,
    }
end

function QuestTypeFilterEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestTypeFilterEngine] " .. message)
    else
        print("[QuestTypeFilterEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTTYPE1 = "/questtype"
    SlashCmdList["QUESTTYPE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            local questId, typeStr = args:match("^(%d+)%s+(.+)$")
            if questId and typeStr then
                questId = tonumber(questId)
                local types = {}
                for typeVal in typeStr:gmatch("%S+") do
                    table.insert(types, typeVal)
                end
                if QuestTypeFilterEngine:RegisterQuestType(questId, types) then
                    print("Set types for quest " .. questId .. ": " .. typeStr)
                else
                    print("Failed to set types")
                end
            else
                print("Usage: /questtype set <questId> <type1> [type2] ...")
            end
        elseif cmd == "get" then
            local questId = tonumber(args)
            if questId then
                local types = QuestTypeFilterEngine:GetQuestType(questId)
                if types then
                    print("Quest " .. questId .. " types: " .. table.concat(types, ", "))
                else
                    print("No types found for quest: " .. questId)
                end
            else
                print("Usage: /questtype get <questId>")
            end
        elseif cmd == "types" then
            local types = QuestTypeFilterEngine:GetSupportedTypes()
            print("Supported Quest Types:")
            for i, qtype in ipairs(types) do
                print("  [" .. i .. "] " .. qtype)
            end
        elseif cmd == "color" then
            local qtype, color = args:match("^(%S+)%s+(.+)$")
            if qtype and color then
                QuestTypeFilterEngine:SetQuestTypeColor(qtype, color)
                print("Set color for type " .. qtype .. ": " .. color)
            else
                print("Usage: /questtype color <type> <colorCode>")
            end
        elseif cmd == "status" then
            local status = QuestTypeFilterEngine:GetStatus()
            print("Quest Type Filter Engine Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total Types: " .. status.total_types)
            print("  Cached Quest Types: " .. status.cached_quest_types)
        else
            print("Quest Type Commands:")
            print("  /questtype set <questId> <type...> - Set quest types")
            print("  /questtype get <questId> - Get quest types")
            print("  /questtype types - List supported types")
            print("  /questtype color <type> <color> - Set type color")
            print("  /questtype status - Show engine status")
        end
    end
end

return QuestTypeFilterEngine
