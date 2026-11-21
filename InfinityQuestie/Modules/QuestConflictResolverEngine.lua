-- QuestConflictResolverEngine.lua - Detect and resolve quest conflicts
-- Part of InfinityQuestie addon suite
-- Identifies and manages conflicting quest requirements and objectives

local QuestConflictResolverEngine = {}
QuestConflictResolverEngine.enabled = false
QuestConflictResolverEngine.db = nil
QuestConflictResolverEngine.conflicts = {}
QuestConflictResolverEngine.resolution_history = {}
QuestConflictResolverEngine.conflict_cache = {}

-- Configuration
QuestConflictResolverEngine.config = {
    enabled = true,
    detect_conflicts = true,
    track_resolution = true,
    cache_results = true,
}

-- Conflict types
QuestConflictResolverEngine.conflict_types = {
    RESOURCE = "resource_conflict",
    LOCATION = "location_conflict",
    TIMING = "timing_conflict",
    REQUIREMENTS = "requirement_conflict",
    FACTION = "faction_conflict",
}

function QuestConflictResolverEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.conflicts then
        self.db.conflicts = {}
    end
    
    if not self.db.resolution_history then
        self.db.resolution_history = {}
    end
    
    if not self.db.conflict_cache then
        self.db.conflict_cache = {}
    end
    
    self.conflicts = self.db.conflicts
    self.resolution_history = self.db.resolution_history
    self.conflict_cache = self.db.conflict_cache
    self.enabled = true
    
    self:Log("Initialized conflict resolver engine")
end

function QuestConflictResolverEngine:DetectConflict(questId1, questId2, conflictType)
    if not questId1 or not questId2 or not conflictType then
        return nil
    end
    
    questId1 = tonumber(questId1)
    questId2 = tonumber(questId2)
    
    -- Check cache first
    local cacheKey = "conflict_" .. questId1 .. "_" .. questId2
    if self.conflict_cache[cacheKey] then
        return self.conflict_cache[cacheKey]
    end
    
    local conflict = {
        id = "conflict_" .. questId1 .. "_" .. questId2 .. "_" .. GetTime(),
        quest_1 = questId1,
        quest_2 = questId2,
        conflict_type = conflictType,
        severity = self:CalculateSeverity(questId1, questId2, conflictType),
        detected_at = GetTime(),
        resolved = false,
        resolution = nil,
    }
    
    table.insert(self.conflicts, conflict)
    
    -- Cache result
    self.conflict_cache[cacheKey] = conflict
    
    self:Log("Detected conflict: " .. conflictType .. " between quests " .. questId1 .. " and " .. questId2)
    
    return conflict
end

function QuestConflictResolverEngine:CalculateSeverity(questId1, questId2, conflictType)
    if conflictType == self.conflict_types.RESOURCE then
        return 7
    elseif conflictType == self.conflict_types.LOCATION then
        return 5
    elseif conflictType == self.conflict_types.TIMING then
        return 6
    elseif conflictType == self.conflict_types.REQUIREMENTS then
        return 8
    elseif conflictType == self.conflict_types.FACTION then
        return 9
    end
    
    return 5
end

function QuestConflictResolverEngine:DetectResourceConflict(questId1, questId2, resource)
    if not questId1 or not questId2 or not resource then
        return false
    end
    
    -- Simulate checking if both quests require the same limited resource
    local conflict = self:DetectConflict(questId1, questId2, self.conflict_types.RESOURCE)
    
    if conflict then
        conflict.resource = resource
        conflict.description = "Both quests require: " .. resource
        return conflict
    end
    
    return false
end

function QuestConflictResolverEngine:DetectLocationConflict(questId1, questId2, location)
    if not questId1 or not questId2 or not location then
        return false
    end
    
    -- Simulate checking if quests are in conflicting locations
    local conflict = self:DetectConflict(questId1, questId2, self.conflict_types.LOCATION)
    
    if conflict then
        conflict.location = location
        conflict.description = "Conflicting locations: " .. location
        return conflict
    end
    
    return false
end

function QuestConflictResolverEngine:DetectFactionConflict(questId1, questId2, faction1, faction2)
    if not questId1 or not questId2 or not faction1 or not faction2 then
        return false
    end
    
    -- Simulate checking if quests are for opposing factions
    if faction1 ~= faction2 then
        local conflict = self:DetectConflict(questId1, questId2, self.conflict_types.FACTION)
        
        if conflict then
            conflict.faction_1 = faction1
            conflict.faction_2 = faction2
            conflict.description = "Faction conflict: " .. faction1 .. " vs " .. faction2
            return conflict
        end
    end
    
    return false
end

function QuestConflictResolverEngine:ResolveConflict(conflictId, resolution)
    if not conflictId or not resolution then
        return false
    end
    
    -- Find the conflict
    local conflict = nil
    for _, conf in ipairs(self.conflicts) do
        if conf.id == conflictId then
            conflict = conf
            break
        end
    end
    
    if not conflict then
        return false
    end
    
    -- Mark as resolved
    conflict.resolved = true
    conflict.resolution = resolution
    conflict.resolved_at = GetTime()
    
    -- Record in history
    table.insert(self.resolution_history, {
        conflict_id = conflictId,
        resolution = resolution,
        timestamp = GetTime(),
        quest_1 = conflict.quest_1,
        quest_2 = conflict.quest_2,
    })
    
    self:Log("Resolved conflict: " .. conflictId .. " - " .. resolution)
    
    return true
end

function QuestConflictResolverEngine:GetConflict(conflictId)
    for _, conflict in ipairs(self.conflicts) do
        if conflict.id == conflictId then
            return conflict
        end
    end
    
    return nil
end

function QuestConflictResolverEngine:GetUnresolvedConflicts()
    local unresolved = {}
    
    for _, conflict in ipairs(self.conflicts) do
        if not conflict.resolved then
            table.insert(unresolved, conflict)
        end
    end
    
    -- Sort by severity descending
    table.sort(unresolved, function(a, b)
        return a.severity > b.severity
    end)
    
    return unresolved
end

function QuestConflictResolverEngine:GetConflictsBySeverity()
    local byType = {}
    
    for severity = 1, 10 do
        byType[severity] = {}
    end
    
    for _, conflict in ipairs(self.conflicts) do
        if not conflict.resolved then
            table.insert(byType[conflict.severity], conflict)
        end
    end
    
    return byType
end

function QuestConflictResolverEngine:GetConflictsForQuest(questId)
    questId = tonumber(questId)
    local conflicts = {}
    
    for _, conflict in ipairs(self.conflicts) do
        if conflict.quest_1 == questId or conflict.quest_2 == questId then
            table.insert(conflicts, conflict)
        end
    end
    
    return conflicts
end

function QuestConflictResolverEngine:CanDoQuestsSimultaneously(questId1, questId2)
    local conflicts = self:GetConflictsForQuest(questId1)
    questId2 = tonumber(questId2)
    
    for _, conflict in ipairs(conflicts) do
        if (conflict.quest_1 == questId2 or conflict.quest_2 == questId2) and not conflict.resolved then
            return false
        end
    end
    
    return true
end

function QuestConflictResolverEngine:GetResolutionSuggestions(conflictId)
    local conflict = self:GetConflict(conflictId)
    
    if not conflict then
        return {}
    end
    
    local suggestions = {}
    
    if conflict.conflict_type == self.conflict_types.RESOURCE then
        table.insert(suggestions, "Prioritize quest with better reward")
        table.insert(suggestions, "Find alternative resource source")
        table.insert(suggestions, "Delay one quest")
    elseif conflict.conflict_type == self.conflict_types.TIMING then
        table.insert(suggestions, "Complete quests in order")
        table.insert(suggestions, "Skip one quest")
        table.insert(suggestions, "Wait for time reset")
    elseif conflict.conflict_type == self.conflict_types.FACTION then
        table.insert(suggestions, "Choose one faction")
        table.insert(suggestions, "Use different character")
        table.insert(suggestions, "Skip conflicting quest")
    end
    
    return suggestions
end

function QuestConflictResolverEngine:GetConflictStatistics()
    local stats = {
        total_conflicts = #self.conflicts,
        unresolved = 0,
        resolved = 0,
        by_type = {},
        average_severity = 0,
        total_severity = 0,
    }
    
    for _, conflict in ipairs(self.conflicts) do
        if conflict.resolved then
            stats.resolved = stats.resolved + 1
        else
            stats.unresolved = stats.unresolved + 1
        end
        
        if not stats.by_type[conflict.conflict_type] then
            stats.by_type[conflict.conflict_type] = 0
        end
        stats.by_type[conflict.conflict_type] = stats.by_type[conflict.conflict_type] + 1
        
        stats.total_severity = stats.total_severity + conflict.severity
    end
    
    if #self.conflicts > 0 then
        stats.average_severity = stats.total_severity / #self.conflicts
    end
    
    return stats
end

function QuestConflictResolverEngine:ClearConflicts()
    local count = #self.conflicts
    self.conflicts = {}
    self.db.conflicts = {}
    
    self:Log("Cleared " .. count .. " conflicts")
    
    return count
end

function QuestConflictResolverEngine:GetStatus()
    local stats = self:GetConflictStatistics()
    
    return {
        enabled = self.enabled,
        total_conflicts = stats.total_conflicts,
        unresolved = stats.unresolved,
        resolved = stats.resolved,
        average_severity = string.format("%.1f", stats.average_severity),
    }
end

function QuestConflictResolverEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestConflictResolverEngine] " .. message)
    else
        print("[QuestConflictResolverEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTCONFLICT1 = "/questconflict"
    SlashCmdList["QUESTCONFLICT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "detect" then
            local q1, q2, ctype = args:match("^(%d+)%s+(%d+)%s+(%w+)$")
            if q1 and q2 and ctype then
                local conflict = QuestConflictResolverEngine:DetectConflict(tonumber(q1), tonumber(q2), ctype)
                if conflict then
                    print("Detected " .. ctype .. " conflict (Severity: " .. conflict.severity .. ")")
                end
            else
                print("Usage: /questconflict detect <quest1> <quest2> <type>")
            end
        elseif cmd == "can" then
            local q1, q2 = args:match("^(%d+)%s+(%d+)$")
            if q1 and q2 then
                local can = QuestConflictResolverEngine:CanDoQuestsSimultaneously(tonumber(q1), tonumber(q2))
                print("Quests " .. (can and "CAN" or "CANNOT") .. " be done simultaneously")
            else
                print("Usage: /questconflict can <quest1> <quest2>")
            end
        elseif cmd == "unresolved" then
            local conflicts = QuestConflictResolverEngine:GetUnresolvedConflicts()
            print("Unresolved Conflicts (" .. #conflicts .. "):")
            for i = 1, math.min(5, #conflicts) do
                local conf = conflicts[i]
                print(i .. ". " .. conf.quest_1 .. " vs " .. conf.quest_2 .. " (Severity: " .. conf.severity .. ")")
            end
        elseif cmd == "stats" then
            local stats = QuestConflictResolverEngine:GetConflictStatistics()
            print("Conflict Statistics:")
            print("  Total: " .. stats.total_conflicts)
            print("  Unresolved: " .. stats.unresolved)
            print("  Resolved: " .. stats.resolved)
            print("  Average Severity: " .. string.format("%.1f", stats.average_severity))
        elseif cmd == "status" then
            local status = QuestConflictResolverEngine:GetStatus()
            print("Quest Conflict Resolver Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total Conflicts: " .. status.total_conflicts)
            print("  Unresolved: " .. status.unresolved)
            print("  Average Severity: " .. status.average_severity)
        else
            print("Quest Conflict Resolver Commands:")
            print("  /questconflict detect <q1> <q2> <type> - Detect conflict")
            print("  /questconflict can <q1> <q2> - Check if quests compatible")
            print("  /questconflict unresolved - Show unresolved conflicts")
            print("  /questconflict stats - Show conflict statistics")
            print("  /questconflict status - Show engine status")
        end
    end
end

return QuestConflictResolverEngine
