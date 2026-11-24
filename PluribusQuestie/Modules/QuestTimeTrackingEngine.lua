-- QuestTimeTrackingEngine.lua - Track time spent on quests
-- Part of PluribusQuestie addon suite
-- Monitors quest completion times and player efficiency

local QuestTimeTrackingEngine = {}
QuestTimeTrackingEngine.enabled = false
QuestTimeTrackingEngine.db = nil
QuestTimeTrackingEngine.quest_times = {}
QuestTimeTrackingEngine.active_quests = {}
QuestTimeTrackingEngine.time_statistics = {}

-- Configuration
QuestTimeTrackingEngine.config = {
    enabled = true,
    track_active = true,
    track_completed = true,
    calculate_efficiency = true,
}

function QuestTimeTrackingEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.quest_times then
        self.db.quest_times = {}
    end
    
    if not self.db.active_quests then
        self.db.active_quests = {}
    end
    
    if not self.db.time_statistics then
        self.db.time_statistics = {}
    end
    
    self.quest_times = self.db.quest_times
    self.active_quests = self.db.active_quests
    self.time_statistics = self.db.time_statistics
    self.enabled = true
    
    self:Log("Initialized time tracking engine")
end

function QuestTimeTrackingEngine:StartTracking(questId)
    if not questId then
        return false
    end
    
    questId = tonumber(questId)
    
    if not self.quest_times[questId] then
        self.quest_times[questId] = {
            quest_id = questId,
            sessions = {},
            total_time = 0,
            last_started = nil,
        }
    end
    
    -- Create new session
    local session = {
        session_id = "session_" .. questId .. "_" .. GetTime(),
        start_time = GetTime(),
        end_time = nil,
        duration = 0,
        completed = false,
    }
    
    table.insert(self.quest_times[questId].sessions, session)
    self.active_quests[questId] = session.session_id
    
    self:Log("Started tracking quest " .. questId)
    
    return session.session_id
end

function QuestTimeTrackingEngine:StopTracking(questId, completed)
    if not questId then
        return false
    end
    
    questId = tonumber(questId)
    
    if not self.quest_times[questId] or not self.active_quests[questId] then
        return false
    end
    
    -- Find the active session
    local questData = self.quest_times[questId]
    local sessionId = self.active_quests[questId]
    local session = nil
    
    for _, sess in ipairs(questData.sessions) do
        if sess.session_id == sessionId then
            session = sess
            break
        end
    end
    
    if not session then
        return false
    end
    
    -- Stop tracking
    session.end_time = GetTime()
    session.duration = session.end_time - session.start_time
    session.completed = completed or false
    
    questData.total_time = questData.total_time + session.duration
    self.active_quests[questId] = nil
    
    self:Log("Stopped tracking quest " .. questId .. " (" .. string.format("%.1f", session.duration) .. "s)")
    
    return true
end

function QuestTimeTrackingEngine:GetQuestTime(questId)
    questId = tonumber(questId)
    
    if not self.quest_times[questId] then
        return nil
    end
    
    return self.quest_times[questId]
end

function QuestTimeTrackingEngine:GetSessionDuration(questId)
    questId = tonumber(questId)
    
    if not self.active_quests[questId] or not self.quest_times[questId] then
        return 0
    end
    
    -- Find active session
    for _, session in ipairs(self.quest_times[questId].sessions) do
        if session.session_id == self.active_quests[questId] then
            if not session.end_time then
                return GetTime() - session.start_time
            else
                return session.duration
            end
        end
    end
    
    return 0
end

function QuestTimeTrackingEngine:GetTotalTime(questId)
    questId = tonumber(questId)
    
    if not self.quest_times[questId] then
        return 0
    end
    
    -- Add current session if active
    local total = self.quest_times[questId].total_time
    
    if self.active_quests[questId] then
        for _, session in ipairs(self.quest_times[questId].sessions) do
            if session.session_id == self.active_quests[questId] and not session.end_time then
                total = total + (GetTime() - session.start_time)
                break
            end
        end
    end
    
    return total
end

function QuestTimeTrackingEngine:GetAverageSessionTime(questId)
    questId = tonumber(questId)
    
    if not self.quest_times[questId] or #self.quest_times[questId].sessions == 0 then
        return 0
    end
    
    local questData = self.quest_times[questId]
    local completedSessions = 0
    local totalTime = 0
    
    for _, session in ipairs(questData.sessions) do
        if session.end_time then
            totalTime = totalTime + session.duration
            completedSessions = completedSessions + 1
        end
    end
    
    if completedSessions == 0 then
        return 0
    end
    
    return totalTime / completedSessions
end

function QuestTimeTrackingEngine:CalculateEfficiency(questId, expectedDuration)
    questId = tonumber(questId)
    
    if not expectedDuration or expectedDuration == 0 then
        return nil
    end
    
    local actualTime = self:GetTotalTime(questId)
    
    if actualTime == 0 then
        return nil
    end
    
    -- Efficiency = expected / actual * 100 (100 = perfect, >100 = very efficient)
    local efficiency = (expectedDuration / actualTime) * 100
    
    return efficiency
end

function QuestTimeTrackingEngine:GetQuestStatistics(questId)
    questId = tonumber(questId)
    
    if not self.quest_times[questId] then
        return nil
    end
    
    local questData = self.quest_times[questId]
    local sessions = questData.sessions
    
    if #sessions == 0 then
        return nil
    end
    
    local stats = {
        quest_id = questId,
        total_sessions = #sessions,
        completed_sessions = 0,
        total_time = self:GetTotalTime(questId),
        average_session = self:GetAverageSessionTime(questId),
        fastest_session = math.huge,
        slowest_session = 0,
        session_times = {},
    }
    
    for _, session in ipairs(sessions) do
        if session.end_time then
            stats.completed_sessions = stats.completed_sessions + 1
            
            if session.duration < stats.fastest_session then
                stats.fastest_session = session.duration
            end
            
            if session.duration > stats.slowest_session then
                stats.slowest_session = session.duration
            end
            
            table.insert(stats.session_times, session.duration)
        end
    end
    
    if stats.fastest_session == math.huge then
        stats.fastest_session = 0
    end
    
    return stats
end

function QuestTimeTrackingEngine:GetCompletionTimes()
    local completions = {}
    
    for questId, questData in pairs(self.quest_times) do
        local completedCount = 0
        local totalTime = 0
        
        for _, session in ipairs(questData.sessions) do
            if session.completed and session.end_time then
                completedCount = completedCount + 1
                totalTime = totalTime + session.duration
            end
        end
        
        if completedCount > 0 then
            table.insert(completions, {
                quest_id = questId,
                completions = completedCount,
                total_time = totalTime,
                average_time = totalTime / completedCount,
            })
        end
    end
    
    -- Sort by total time descending
    table.sort(completions, function(a, b)
        return a.total_time > b.total_time
    end)
    
    return completions
end

function QuestTimeTrackingEngine:GetLongestQuests(limit)
    limit = limit or 10
    local completions = self:GetCompletionTimes()
    
    local result = {}
    for i = 1, math.min(limit, #completions) do
        table.insert(result, completions[i])
    end
    
    return result
end

function QuestTimeTrackingEngine:GetFastestQuests(limit)
    limit = limit or 10
    local completions = self:GetCompletionTimes()
    
    -- Sort by average time ascending
    table.sort(completions, function(a, b)
        return a.average_time < b.average_time
    end)
    
    local result = {}
    for i = 1, math.min(limit, #completions) do
        table.insert(result, completions[i])
    end
    
    return result
end

function QuestTimeTrackingEngine:GetAverageQuestTime()
    local totalTime = 0
    local questCount = 0
    
    for _, questData in pairs(self.quest_times) do
        if #questData.sessions > 0 then
            totalTime = totalTime + questData.total_time
            questCount = questCount + 1
        end
    end
    
    if questCount == 0 then
        return 0
    end
    
    return totalTime / questCount
end

function QuestTimeTrackingEngine:ClearQuestTimes(questId)
    if questId then
        questId = tonumber(questId)
        if self.quest_times[questId] then
            self.quest_times[questId] = nil
            if self.active_quests[questId] then
                self.active_quests[questId] = nil
            end
            self:Log("Cleared times for quest " .. questId)
            return true
        end
    else
        local count = 0
        for questId in pairs(self.quest_times) do
            self.quest_times[questId] = nil
            count = count + 1
        end
        self.active_quests = {}
        self:Log("Cleared all quest times (" .. count .. " quests)")
        return count
    end
    
    return false
end

function QuestTimeTrackingEngine:GetStatus()
    local completions = self:GetCompletionTimes()
    
    return {
        enabled = self.enabled,
        tracked_quests = next(self.quest_times) and 1 or 0,
        active_quests = next(self.active_quests) and 1 or 0,
        completed_quests = #completions,
        average_time = string.format("%.1f", self:GetAverageQuestTime()),
    }
end

function QuestTimeTrackingEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestTimeTrackingEngine] " .. message)
    else
        print("[QuestTimeTrackingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTTIME1 = "/questtime"
    SlashCmdList["QUESTTIME"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "start" then
            local questId = tonumber(args)
            if questId then
                QuestTimeTrackingEngine:StartTracking(questId)
                print("Started tracking quest " .. questId)
            else
                print("Usage: /questtime start <questId>")
            end
        elseif cmd == "stop" then
            local questId = tonumber(args)
            if questId then
                QuestTimeTrackingEngine:StopTracking(questId)
                print("Stopped tracking quest " .. questId)
            else
                print("Usage: /questtime stop <questId>")
            end
        elseif cmd == "complete" then
            local questId = tonumber(args)
            if questId then
                QuestTimeTrackingEngine:StopTracking(questId, true)
                print("Marked quest " .. questId .. " as completed")
            else
                print("Usage: /questtime complete <questId>")
            end
        elseif cmd == "stats" then
            local questId = tonumber(args)
            if questId then
                local stats = QuestTimeTrackingEngine:GetQuestStatistics(questId)
                if stats then
                    print("Quest " .. questId .. " Statistics:")
                    print("  Total Time: " .. string.format("%.1f", stats.total_time) .. "s")
                    print("  Sessions: " .. stats.total_sessions .. " (" .. stats.completed_sessions .. " completed)")
                    print("  Average: " .. string.format("%.1f", stats.average_session) .. "s")
                    print("  Fastest: " .. string.format("%.1f", stats.fastest_session) .. "s")
                    print("  Slowest: " .. string.format("%.1f", stats.slowest_session) .. "s")
                else
                    print("No time data for quest " .. questId)
                end
            else
                print("Usage: /questtime stats <questId>")
            end
        elseif cmd == "longest" then
            local limit = tonumber(args) or 5
            local longest = QuestTimeTrackingEngine:GetLongestQuests(limit)
            print("Longest Quests:")
            for i, quest in ipairs(longest) do
                print(i .. ". Quest " .. quest.quest_id .. ": " .. string.format("%.1f", quest.total_time) .. "s")
            end
        elseif cmd == "fastest" then
            local limit = tonumber(args) or 5
            local fastest = QuestTimeTrackingEngine:GetFastestQuests(limit)
            print("Fastest Quests:")
            for i, quest in ipairs(fastest) do
                print(i .. ". Quest " .. quest.quest_id .. ": " .. string.format("%.1f", quest.average_time) .. "s avg")
            end
        elseif cmd == "avg" then
            local avg = QuestTimeTrackingEngine:GetAverageQuestTime()
            print("Average quest time: " .. string.format("%.1f", avg) .. "s")
        elseif cmd == "status" then
            local status = QuestTimeTrackingEngine:GetStatus()
            print("Quest Time Tracking Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Tracked Quests: " .. status.tracked_quests)
            print("  Active: " .. status.active_quests)
            print("  Completed: " .. status.completed_quests)
            print("  Average Time: " .. status.average_time .. "s")
        else
            print("Quest Time Tracking Commands:")
            print("  /questtime start <questId> - Start tracking")
            print("  /questtime stop <questId> - Stop tracking")
            print("  /questtime complete <questId> - Mark as completed")
            print("  /questtime stats <questId> - Show quest statistics")
            print("  /questtime longest [limit] - Show longest quests")
            print("  /questtime fastest [limit] - Show fastest quests")
            print("  /questtime avg - Show average quest time")
            print("  /questtime status - Show engine status")
        end
    end
end

return QuestTimeTrackingEngine
