-- QuestGroupingSortingEngine.lua - Advanced quest grouping and organization
-- Part of PluribusQuestie addon suite
-- Organizes quests into logical groups and categories

local QuestGroupingSortingEngine = {}
QuestGroupingSortingEngine.enabled = false
QuestGroupingSortingEngine.db = nil
QuestGroupingSortingEngine.quest_groups = {}
QuestGroupingSortingEngine.custom_groups = {}
QuestGroupingSortingEngine.group_config = {}

-- Configuration
QuestGroupingSortingEngine.config = {
    enabled = true,
    auto_group = true,
    group_by_zone = true,
    group_by_level = true,
    group_by_type = true,
}

-- Predefined group categories
QuestGroupingSortingEngine.categories = {
    daily = "Daily Quests",
    world = "World Quests",
    dungeon = "Dungeon Quests",
    raid = "Raid Quests",
    pvp = "PvP Quests",
    story = "Story Quests",
    side = "Side Quests",
    tradeskill = "Tradeskill Quests",
    reputation = "Reputation Quests",
}

function QuestGroupingSortingEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.quest_groups then
        self.db.quest_groups = {}
    end
    
    if not self.db.custom_groups then
        self.db.custom_groups = {}
    end
    
    if not self.db.group_config then
        self.db.group_config = {}
    end
    
    self.quest_groups = self.db.quest_groups
    self.custom_groups = self.db.custom_groups
    self.group_config = self.db.group_config
    self.enabled = true
    
    self:Log("Initialized quest grouping/sorting engine")
end

function QuestGroupingSortingEngine:CreateAutoGroup(groupName, questIds)
    if not groupName or not questIds or #questIds == 0 then
        return false
    end
    
    local groupId = "auto_" .. groupName .. "_" .. GetTime()
    
    local group = {
        id = groupId,
        name = groupName,
        type = "auto",
        quest_ids = {},
        created_at = GetTime(),
        display_order = 0,
        collapsed = false,
        icon = nil,
    }
    
    for _, questId in ipairs(questIds) do
        table.insert(group.quest_ids, tonumber(questId))
    end
    
    self.quest_groups[groupId] = group
    self:Log("Created auto group: " .. groupName)
    
    return groupId
end

function QuestGroupingSortingEngine:CreateCustomGroup(groupName, questIds)
    if not groupName or not questIds or #questIds == 0 then
        return false
    end
    
    local groupId = "custom_" .. groupName .. "_" .. GetTime()
    
    local group = {
        id = groupId,
        name = groupName,
        type = "custom",
        quest_ids = {},
        created_at = GetTime(),
        display_order = 0,
        collapsed = false,
        icon = nil,
        notes = "",
    }
    
    for _, questId in ipairs(questIds) do
        table.insert(group.quest_ids, tonumber(questId))
    end
    
    self.custom_groups[groupId] = group
    self:Log("Created custom group: " .. groupName)
    
    return groupId
end

function QuestGroupingSortingEngine:AddQuestToGroup(groupId, questId)
    if not groupId or not questId then
        return false
    end
    
    questId = tonumber(questId)
    
    local group = self.quest_groups[groupId] or self.custom_groups[groupId]
    
    if not group then
        return false
    end
    
    -- Check if quest already in group
    for _, qId in ipairs(group.quest_ids) do
        if qId == questId then
            return false
        end
    end
    
    table.insert(group.quest_ids, questId)
    self:Log("Added quest " .. questId .. " to group " .. groupId)
    
    return true
end

function QuestGroupingSortingEngine:RemoveQuestFromGroup(groupId, questId)
    if not groupId or not questId then
        return false
    end
    
    questId = tonumber(questId)
    
    local group = self.quest_groups[groupId] or self.custom_groups[groupId]
    
    if not group then
        return false
    end
    
    for i, qId in ipairs(group.quest_ids) do
        if qId == questId then
            table.remove(group.quest_ids, i)
            self:Log("Removed quest " .. questId .. " from group " .. groupId)
            return true
        end
    end
    
    return false
end

function QuestGroupingSortingEngine:GroupByZone(quests)
    if not quests or #quests == 0 then
        return {}
    end
    
    local zones = {}
    
    for _, quest in ipairs(quests) do
        local zone = quest.zone or "Unknown"
        
        if not zones[zone] then
            zones[zone] = {}
        end
        
        table.insert(zones[zone], quest)
    end
    
    return zones
end

function QuestGroupingSortingEngine:GroupByLevel(quests)
    if not quests or #quests == 0 then
        return {}
    end
    
    local levels = {}
    
    for _, quest in ipairs(quests) do
        local level = quest.suggested_level or 1
        
        if not levels[level] then
            levels[level] = {}
        end
        
        table.insert(levels[level], quest)
    end
    
    return levels
end

function QuestGroupingSortingEngine:GroupByType(quests)
    if not quests or #quests == 0 then
        return {}
    end
    
    local types = {}
    
    for _, quest in ipairs(quests) do
        local questType = quest.quest_type or "other"
        
        if not types[questType] then
            types[questType] = {}
        end
        
        table.insert(types[questType], quest)
    end
    
    return types
end

function QuestGroupingSortingEngine:GroupByCategory(quests, categoryType)
    if not quests or #quests == 0 then
        return {}
    end
    
    categoryType = categoryType or "type"
    
    if categoryType == "zone" then
        return self:GroupByZone(quests)
    elseif categoryType == "level" then
        return self:GroupByLevel(quests)
    elseif categoryType == "type" then
        return self:GroupByType(quests)
    end
    
    return {}
end

function QuestGroupingSortingEngine:GetGroupedQuests(groupingMethod)
    groupingMethod = groupingMethod or "zone"
    
    local allQuests = {}
    
    for groupId, group in pairs(self.quest_groups) do
        for _, questId in ipairs(group.quest_ids) do
            if not allQuests[questId] then
                allQuests[questId] = { id = questId }
            end
        end
    end
    
    local questList = {}
    for _, quest in pairs(allQuests) do
        table.insert(questList, quest)
    end
    
    return self:GroupByCategory(questList, groupingMethod)
end

function QuestGroupingSortingEngine:SetGroupDisplayOrder(groupId, order)
    if not groupId then
        return false
    end
    
    order = tonumber(order) or 0
    
    local group = self.quest_groups[groupId] or self.custom_groups[groupId]
    
    if not group then
        return false
    end
    
    group.display_order = order
    self:Log("Set group display order: " .. groupId .. " = " .. order)
    
    return true
end

function QuestGroupingSortingEngine:ToggleGroupCollapsed(groupId)
    if not groupId then
        return false
    end
    
    local group = self.quest_groups[groupId] or self.custom_groups[groupId]
    
    if not group then
        return false
    end
    
    group.collapsed = not group.collapsed
    self:Log("Group " .. groupId .. " collapsed: " .. (group.collapsed and "true" or "false"))
    
    return true
end

function QuestGroupingSortingEngine:SetGroupIcon(groupId, iconPath)
    if not groupId then
        return false
    end
    
    local group = self.quest_groups[groupId] or self.custom_groups[groupId]
    
    if not group then
        return false
    end
    
    group.icon = iconPath
    self:Log("Set group icon: " .. groupId .. " -> " .. iconPath)
    
    return true
end

function QuestGroupingSortingEngine:GetGroupStatistics()
    local stats = {
        total_groups = 0,
        auto_groups = 0,
        custom_groups = 0,
        total_quests = 0,
        largest_group = 0,
        group_sizes = {},
    }
    
    for groupId, group in pairs(self.quest_groups) do
        stats.total_groups = stats.total_groups + 1
        stats.auto_groups = stats.auto_groups + 1
        stats.total_quests = stats.total_quests + #group.quest_ids
        
        if #group.quest_ids > stats.largest_group then
            stats.largest_group = #group.quest_ids
        end
        
        stats.group_sizes[groupId] = #group.quest_ids
    end
    
    for groupId, group in pairs(self.custom_groups) do
        stats.total_groups = stats.total_groups + 1
        stats.custom_groups = stats.custom_groups + 1
        stats.total_quests = stats.total_quests + #group.quest_ids
        
        if #group.quest_ids > stats.largest_group then
            stats.largest_group = #group.quest_ids
        end
        
        stats.group_sizes[groupId] = #group.quest_ids
    end
    
    return stats
end

function QuestGroupingSortingEngine:RemoveGroup(groupId)
    if not groupId then
        return false
    end
    
    if self.quest_groups[groupId] then
        self.quest_groups[groupId] = nil
        self:Log("Removed auto group: " .. groupId)
        return true
    elseif self.custom_groups[groupId] then
        self.custom_groups[groupId] = nil
        self:Log("Removed custom group: " .. groupId)
        return true
    end
    
    return false
end

function QuestGroupingSortingEngine:GetStatus()
    local stats = self:GetGroupStatistics()
    
    return {
        enabled = self.enabled,
        total_groups = stats.total_groups,
        auto_groups = stats.auto_groups,
        custom_groups = stats.custom_groups,
        total_quests = stats.total_quests,
        largest_group = stats.largest_group,
    }
end

function QuestGroupingSortingEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestGroupingSortingEngine] " .. message)
    else
        print("[QuestGroupingSortingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTGROUP1 = "/questgroup"
    SlashCmdList["QUESTGROUP"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "create" then
            local groupName = args
            if groupName ~= "" then
                local groupId = QuestGroupingSortingEngine:CreateCustomGroup(groupName, { 1 })
                print("Created group: " .. groupName .. " (" .. groupId .. ")")
            else
                print("Usage: /questgroup create <name>")
            end
        elseif cmd == "remove" then
            if args ~= "" then
                local success = QuestGroupingSortingEngine:RemoveGroup(args)
                print("Remove group: " .. (success and "Success" or "Failed"))
            else
                print("Usage: /questgroup remove <groupId>")
            end
        elseif cmd == "add" then
            local groupId, questId = args:match("^(%S+)%s+(%d+)$")
            if groupId and questId then
                local success = QuestGroupingSortingEngine:AddQuestToGroup(groupId, tonumber(questId))
                print("Add quest: " .. (success and "Success" or "Failed"))
            else
                print("Usage: /questgroup add <groupId> <questId>")
            end
        elseif cmd == "stats" then
            local stats = QuestGroupingSortingEngine:GetGroupStatistics()
            print("Group Statistics:")
            print("  Total Groups: " .. stats.total_groups)
            print("  Auto Groups: " .. stats.auto_groups)
            print("  Custom Groups: " .. stats.custom_groups)
            print("  Total Quests: " .. stats.total_quests)
            print("  Largest Group: " .. stats.largest_group)
        elseif cmd == "status" then
            local status = QuestGroupingSortingEngine:GetStatus()
            print("Quest Grouping & Sorting Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Groups: " .. status.total_groups .. " (" .. status.auto_groups .. " auto, " .. status.custom_groups .. " custom)")
            print("  Total Quests: " .. status.total_quests)
        else
            print("Quest Grouping & Sorting Commands:")
            print("  /questgroup create <name> - Create custom group")
            print("  /questgroup remove <groupId> - Remove group")
            print("  /questgroup add <groupId> <questId> - Add quest to group")
            print("  /questgroup stats - Show group statistics")
            print("  /questgroup status - Show engine status")
        end
    end
end

return QuestGroupingSortingEngine
