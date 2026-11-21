-- QuestListDisplayEngine.lua - Quest list rendering and display
-- Part of InfinityQuestie addon suite
-- Handles detailed quest list UI with pagination, search, and filtering

local QuestListDisplayEngine = {}
QuestListDisplayEngine.enabled = false
QuestListDisplayEngine.db = nil
QuestListDisplayEngine.quest_list = {}
QuestListDisplayEngine.display_config = {}
QuestListDisplayEngine.pagination_state = {}

-- Configuration
QuestListDisplayEngine.config = {
    enabled = true,
    items_per_page = 20,
    show_difficulty = true,
    show_rewards = true,
    show_progress = true,
    sort_method = "level",
}

function QuestListDisplayEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.quest_list then
        self.db.quest_list = {}
    end
    
    if not self.db.display_config then
        self.db.display_config = {}
    end
    
    if not self.db.pagination_state then
        self.db.pagination_state = {}
    end
    
    self.quest_list = self.db.quest_list
    self.display_config = self.db.display_config
    self.pagination_state = self.db.pagination_state
    self.enabled = true
    
    self:Log("Initialized quest list display engine")
end

function QuestListDisplayEngine:AddQuestToDisplay(questId, questData)
    if not questId or not questData then
        return false
    end
    
    questId = tonumber(questId)
    
    local questEntry = {
        quest_id = questId,
        name = questData.name or "Unknown Quest",
        level = questData.level or 1,
        difficulty = questData.difficulty or "normal",
        progress = questData.progress or 0,
        progress_max = questData.progress_max or 100,
        reward_gold = questData.reward_gold or 0,
        reward_xp = questData.reward_xp or 0,
        added_at = GetTime(),
    }
    
    self.quest_list[questId] = questEntry
    self:Log("Added quest to display: " .. questId .. " (" .. questEntry.name .. ")")
    
    return true
end

function QuestListDisplayEngine:RemoveQuestFromDisplay(questId)
    questId = tonumber(questId)
    
    if not self.quest_list[questId] then
        return false
    end
    
    self.quest_list[questId] = nil
    self:Log("Removed quest from display: " .. questId)
    
    return true
end

function QuestListDisplayEngine:GetPaginatedQuests(pageNumber)
    pageNumber = tonumber(pageNumber) or 1
    
    if pageNumber < 1 then
        pageNumber = 1
    end
    
    local quests = {}
    for _, quest in pairs(self.quest_list) do
        table.insert(quests, quest)
    end
    
    -- Sort by specified method
    self:SortQuests(quests)
    
    local startIndex = (pageNumber - 1) * self.config.items_per_page + 1
    local endIndex = startIndex + self.config.items_per_page - 1
    
    local pageQuests = {}
    for i = startIndex, math.min(endIndex, #quests) do
        table.insert(pageQuests, quests[i])
    end
    
    local totalPages = math.ceil(#quests / self.config.items_per_page)
    
    return {
        quests = pageQuests,
        current_page = pageNumber,
        total_pages = totalPages,
        total_quests = #quests,
        items_per_page = self.config.items_per_page,
    }
end

function QuestListDisplayEngine:SortQuests(questList)
    if self.config.sort_method == "level" then
        table.sort(questList, function(a, b) return a.level < b.level end)
    elseif self.config.sort_method == "name" then
        table.sort(questList, function(a, b) return a.name < b.name end)
    elseif self.config.sort_method == "difficulty" then
        local diffOrder = { trivial = 1, easy = 2, normal = 3, hard = 4, impossible = 5 }
        table.sort(questList, function(a, b)
            return (diffOrder[a.difficulty] or 3) < (diffOrder[b.difficulty] or 3)
        end)
    elseif self.config.sort_method == "reward" then
        table.sort(questList, function(a, b) return a.reward_gold > b.reward_gold end)
    end
end

function QuestListDisplayEngine:SearchQuests(searchTerm)
    if not searchTerm or searchTerm == "" then
        return {}
    end
    
    searchTerm = searchTerm:lower()
    local results = {}
    
    for questId, quest in pairs(self.quest_list) do
        if quest.name:lower():find(searchTerm, 1, true) then
            table.insert(results, quest)
        end
    end
    
    return results
end

function QuestListDisplayEngine:FilterByLevel(minLevel, maxLevel)
    local filtered = {}
    
    for questId, quest in pairs(self.quest_list) do
        if quest.level >= minLevel and quest.level <= maxLevel then
            table.insert(filtered, quest)
        end
    end
    
    return filtered
end

function QuestListDisplayEngine:FilterByDifficulty(difficulty)
    local filtered = {}
    
    for questId, quest in pairs(self.quest_list) do
        if quest.difficulty == difficulty then
            table.insert(filtered, quest)
        end
    end
    
    return filtered
end

function QuestListDisplayEngine:GetQuestDetails(questId)
    questId = tonumber(questId)
    return self.quest_list[questId]
end

function QuestListDisplayEngine:UpdateQuestProgress(questId, progress, maxProgress)
    questId = tonumber(questId)
    
    if not self.quest_list[questId] then
        return false
    end
    
    self.quest_list[questId].progress = tonumber(progress) or 0
    self.quest_list[questId].progress_max = tonumber(maxProgress) or 100
    self.quest_list[questId].updated_at = GetTime()
    
    return true
end

function QuestListDisplayEngine:SetSortMethod(sortMethod)
    if not sortMethod then
        return false
    end
    
    if sortMethod == "level" or sortMethod == "name" or 
       sortMethod == "difficulty" or sortMethod == "reward" then
        self.config.sort_method = sortMethod
        self:Log("Sort method set to: " .. sortMethod)
        return true
    end
    
    return false
end

function QuestListDisplayEngine:SetItemsPerPage(itemsPerPage)
    itemsPerPage = tonumber(itemsPerPage) or 20
    
    if itemsPerPage > 0 and itemsPerPage <= 100 then
        self.config.items_per_page = itemsPerPage
        self:Log("Items per page set to: " .. itemsPerPage)
        return true
    end
    
    return false
end

function QuestListDisplayEngine:GetDisplayStatistics()
    local stats = {
        total_quests = 0,
        by_difficulty = {},
        by_level = {},
        total_pages = 0,
        average_progress = 0,
    }
    
    local totalProgress = 0
    
    for _, quest in pairs(self.quest_list) do
        stats.total_quests = stats.total_quests + 1
        
        if not stats.by_difficulty[quest.difficulty] then
            stats.by_difficulty[quest.difficulty] = 0
        end
        stats.by_difficulty[quest.difficulty] = stats.by_difficulty[quest.difficulty] + 1
        
        if not stats.by_level[quest.level] then
            stats.by_level[quest.level] = 0
        end
        stats.by_level[quest.level] = stats.by_level[quest.level] + 1
        
        totalProgress = totalProgress + (quest.progress / quest.progress_max)
    end
    
    stats.total_pages = math.ceil(stats.total_quests / self.config.items_per_page)
    
    if stats.total_quests > 0 then
        stats.average_progress = totalProgress / stats.total_quests
    end
    
    return stats
end

function QuestListDisplayEngine:GetStatus()
    local stats = self:GetDisplayStatistics()
    
    return {
        enabled = self.enabled,
        total_quests = stats.total_quests,
        total_pages = stats.total_pages,
        items_per_page = self.config.items_per_page,
        sort_method = self.config.sort_method,
        average_progress = string.format("%.1f%%", stats.average_progress * 100),
    }
end

function QuestListDisplayEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestListDisplayEngine] " .. message)
    else
        print("[QuestListDisplayEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTLIST1 = "/questlist"
    SlashCmdList["QUESTLIST"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "add" then
            local questId = tonumber(args)
            if questId then
                QuestListDisplayEngine:AddQuestToDisplay(questId, {
                    name = "Quest " .. questId,
                    level = 60,
                })
                print("Added quest to display list")
            else
                print("Usage: /questlist add <questId>")
            end
        elseif cmd == "page" then
            local pageNum = tonumber(args) or 1
            local page = QuestListDisplayEngine:GetPaginatedQuests(pageNum)
            print("Quest List - Page " .. page.current_page .. "/" .. page.total_pages)
            print("Showing " .. #page.quests .. " of " .. page.total_quests .. " quests")
            for i, quest in ipairs(page.quests) do
                print(i .. ". [" .. quest.level .. "] " .. quest.name)
            end
        elseif cmd == "search" then
            local results = QuestListDisplayEngine:SearchQuests(args)
            print("Search Results (" .. #results .. "):")
            for i = 1, math.min(5, #results) do
                print(i .. ". " .. results[i].name)
            end
        elseif cmd == "sort" then
            local success = QuestListDisplayEngine:SetSortMethod(args)
            print("Sort set to: " .. (success and args or "unknown"))
        elseif cmd == "stats" then
            local stats = QuestListDisplayEngine:GetDisplayStatistics()
            print("Quest List Statistics:")
            print("  Total: " .. stats.total_quests)
            print("  Pages: " .. stats.total_pages)
            print("  Avg Progress: " .. string.format("%.1f%%", stats.average_progress * 100))
        elseif cmd == "status" then
            local status = QuestListDisplayEngine:GetStatus()
            print("Quest List Display Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Quests: " .. status.total_quests)
            print("  Pages: " .. status.total_pages)
            print("  Sort: " .. status.sort_method)
        else
            print("Quest List Display Commands:")
            print("  /questlist add <questId> - Add quest to list")
            print("  /questlist page [num] - Show page of quests")
            print("  /questlist search <term> - Search quests")
            print("  /questlist sort [level/name/difficulty/reward] - Set sort")
            print("  /questlist stats - Show statistics")
            print("  /questlist status - Show engine status")
        end
    end
end

return QuestListDisplayEngine
