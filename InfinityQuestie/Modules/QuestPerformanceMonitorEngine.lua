-- QuestPerformanceMonitorEngine.lua - Performance monitoring and optimization
-- Part of InfinityQuestie addon suite
-- Tracks addon performance, memory usage, and execution times

local QuestPerformanceMonitorEngine = {}
QuestPerformanceMonitorEngine.enabled = false
QuestPerformanceMonitorEngine.db = nil
QuestPerformanceMonitorEngine.performance_data = {}
QuestPerformanceMonitorEngine.operation_timings = {}
QuestPerformanceMonitorEngine.memory_snapshots = {}

-- Configuration
QuestPerformanceMonitorEngine.config = {
    enabled = true,
    track_timings = true,
    track_memory = true,
    max_snapshots = 50,
}

function QuestPerformanceMonitorEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.performance_data then
        self.db.performance_data = {}
    end
    
    if not self.db.operation_timings then
        self.db.operation_timings = {}
    end
    
    if not self.db.memory_snapshots then
        self.db.memory_snapshots = {}
    end
    
    self.performance_data = self.db.performance_data
    self.operation_timings = self.db.operation_timings
    self.memory_snapshots = self.db.memory_snapshots
    self.enabled = true
    
    self:Log("Initialized performance monitor engine")
end

function QuestPerformanceMonitorEngine:StartTimer(operationName)
    if not operationName then
        return false
    end
    
    if not self.operation_timings[operationName] then
        self.operation_timings[operationName] = {}
    end
    
    -- Create a unique timer ID for this operation
    local timerId = operationName .. "_" .. GetTime()
    
    self.operation_timings[operationName].current_timer = {
        id = timerId,
        start_time = GetTime(),
    }
    
    return timerId
end

function QuestPerformanceMonitorEngine:StopTimer(operationName)
    if not operationName then
        return nil
    end
    
    if not self.operation_timings[operationName] then
        return nil
    end
    
    local timer = self.operation_timings[operationName].current_timer
    if not timer then
        return nil
    end
    
    local elapsed = GetTime() - timer.start_time
    
    if not self.operation_timings[operationName].timings then
        self.operation_timings[operationName].timings = {}
    end
    
    table.insert(self.operation_timings[operationName].timings, {
        duration = elapsed,
        completed_at = GetTime(),
    })
    
    self.operation_timings[operationName].current_timer = nil
    
    return elapsed
end

function QuestPerformanceMonitorEngine:RecordTiming(operationName, duration)
    if not operationName or not duration then
        return false
    end
    
    if not self.operation_timings[operationName] then
        self.operation_timings[operationName] = {}
    end
    
    if not self.operation_timings[operationName].timings then
        self.operation_timings[operationName].timings = {}
    end
    
    table.insert(self.operation_timings[operationName].timings, {
        duration = duration,
        recorded_at = GetTime(),
    })
    
    return true
end

function QuestPerformanceMonitorEngine:GetOperationTiming(operationName)
    if not operationName then
        return nil
    end
    
    if not self.operation_timings[operationName] then
        return nil
    end
    
    local timings = self.operation_timings[operationName].timings or {}
    if #timings == 0 then
        return nil
    end
    
    local totalTime = 0
    local minTime = math.huge
    local maxTime = 0
    
    for _, timing in ipairs(timings) do
        totalTime = totalTime + timing.duration
        minTime = math.min(minTime, timing.duration)
        maxTime = math.max(maxTime, timing.duration)
    end
    
    local avgTime = totalTime / #timings
    
    return {
        operation = operationName,
        call_count = #timings,
        total_time = totalTime,
        average_time = avgTime,
        min_time = minTime,
        max_time = maxTime,
        last_time = timings[#timings].duration,
    }
end

function QuestPerformanceMonitorEngine:GetAllTimings()
    local results = {}
    
    for operationName, _ in pairs(self.operation_timings) do
        local timing = self:GetOperationTiming(operationName)
        if timing then
            table.insert(results, timing)
        end
    end
    
    -- Sort by average time (slowest first)
    table.sort(results, function(a, b)
        return a.average_time > b.average_time
    end)
    
    return results
end

function QuestPerformanceMonitorEngine:ClearTimings(operationName)
    if not operationName then
        return false
    end
    
    if self.operation_timings[operationName] then
        self.operation_timings[operationName].timings = {}
        self:Log("Cleared timings for: " .. operationName)
        return true
    end
    
    return false
end

function QuestPerformanceMonitorEngine:TakeMemorySnapshot(label)
    label = label or "snapshot_" .. GetTime()
    
    local snapshot = {
        label = label,
        timestamp = GetTime(),
        memory_usage = collectgarbage("count"),  -- Returns memory in KB
    }
    
    table.insert(self.memory_snapshots, snapshot)
    
    -- Limit snapshot history
    while #self.memory_snapshots > self.config.max_snapshots do
        table.remove(self.memory_snapshots, 1)
    end
    
    self:Log("Memory snapshot taken: " .. label .. " (" .. snapshot.memory_usage .. " KB)")
    
    return snapshot
end

function QuestPerformanceMonitorEngine:GetMemoryUsage()
    return collectgarbage("count")  -- Returns KB
end

function QuestPerformanceMonitorEngine:GetMemorySnapshots()
    return self.memory_snapshots
end

function QuestPerformanceMonitorEngine:GetMemoryTrend()
    if #self.memory_snapshots < 2 then
        return 0
    end
    
    local firstSnapshot = self.memory_snapshots[1]
    local lastSnapshot = self.memory_snapshots[#self.memory_snapshots]
    
    return lastSnapshot.memory_usage - firstSnapshot.memory_usage
end

function QuestPerformanceMonitorEngine:ResetMemorySnapshots()
    self.memory_snapshots = {}
    self:Log("Memory snapshots reset")
    return true
end

function QuestPerformanceMonitorEngine:GetPerformanceReport()
    local report = {
        timestamp = GetTime(),
        current_memory_mb = self:GetMemoryUsage() / 1024,
        operation_count = table.getn(self.operation_timings),
        snapshot_count = #self.memory_snapshots,
        slowest_operations = {},
    }
    
    local timings = self:GetAllTimings()
    
    for i = 1, math.min(5, #timings) do
        table.insert(report.slowest_operations, {
            name = timings[i].operation,
            avg_time = timings[i].average_time,
            call_count = timings[i].call_count,
        })
    end
    
    if #self.memory_snapshots > 0 then
        report.memory_trend_kb = self:GetMemoryTrend()
        report.first_snapshot_mb = self.memory_snapshots[1].memory_usage / 1024
        report.last_snapshot_mb = self.memory_snapshots[#self.memory_snapshots].memory_usage / 1024
    end
    
    return report
end

function QuestPerformanceMonitorEngine:ExportReport(format)
    format = format or "text"
    
    local report = self:GetPerformanceReport()
    
    if format == "text" then
        local text = "=== Performance Report ===\n"
        text = text .. "Current Memory: " .. string.format("%.2f MB", report.current_memory_mb) .. "\n"
        text = text .. "Operations Tracked: " .. report.operation_count .. "\n"
        text = text .. "Memory Snapshots: " .. report.snapshot_count .. "\n"
        
        if report.slowest_operations and #report.slowest_operations > 0 then
            text = text .. "\nSlowest Operations:\n"
            for i, op in ipairs(report.slowest_operations) do
                text = text .. "  " .. i .. ". " .. op.name .. " - " ..
                       string.format("%.4f", op.avg_time) .. "ms (called " .. 
                       op.call_count .. "x)\n"
            end
        end
        
        return text
    end
    
    return nil
end

function QuestPerformanceMonitorEngine:GetStatus()
    local memUsage = self:GetMemoryUsage()
    
    return {
        enabled = self.enabled,
        track_timings = self.config.track_timings,
        track_memory = self.config.track_memory,
        memory_usage_mb = memUsage / 1024,
        operations_tracked = table.getn(self.operation_timings),
        memory_snapshots = #self.memory_snapshots,
    }
end

function QuestPerformanceMonitorEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestPerformanceMonitorEngine] " .. message)
    else
        print("[QuestPerformanceMonitorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTPERF1 = "/questperf"
    SlashCmdList["QUESTPERF"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "snapshot" then
            local label = args ~= "" and args or nil
            QuestPerformanceMonitorEngine:TakeMemorySnapshot(label)
            print("Memory snapshot taken")
        elseif cmd == "memory" then
            local usage = QuestPerformanceMonitorEngine:GetMemoryUsage()
            print("Current memory usage: " .. string.format("%.2f MB", usage / 1024))
        elseif cmd == "timings" then
            local timings = QuestPerformanceMonitorEngine:GetAllTimings()
            print("Operation Timings (slowest first):")
            for i, timing in ipairs(timings) do
                if i > 10 then break end
                print("  [" .. i .. "] " .. timing.operation .. 
                      " - Avg: " .. string.format("%.4f", timing.average_time) .. "ms" ..
                      " (called " .. timing.call_count .. "x)")
            end
        elseif cmd == "clear" then
            local what = args ~= "" and args or "all"
            if what == "timings" then
                for op, _ in pairs(QuestPerformanceMonitorEngine.operation_timings) do
                    QuestPerformanceMonitorEngine:ClearTimings(op)
                end
                print("All timings cleared")
            elseif what == "memory" then
                QuestPerformanceMonitorEngine:ResetMemorySnapshots()
                print("Memory snapshots cleared")
            else
                for op, _ in pairs(QuestPerformanceMonitorEngine.operation_timings) do
                    QuestPerformanceMonitorEngine:ClearTimings(op)
                end
                QuestPerformanceMonitorEngine:ResetMemorySnapshots()
                print("All performance data cleared")
            end
        elseif cmd == "report" then
            local report = QuestPerformanceMonitorEngine:ExportReport("text")
            print(report)
        elseif cmd == "status" then
            local status = QuestPerformanceMonitorEngine:GetStatus()
            print("Performance Monitor Status:")
            print("  Memory: " .. string.format("%.2f MB", status.memory_usage_mb))
            print("  Operations Tracked: " .. status.operations_tracked)
            print("  Memory Snapshots: " .. status.memory_snapshots)
        else
            print("Performance Monitor Commands:")
            print("  /questperf snapshot [label] - Take memory snapshot")
            print("  /questperf memory - Show current memory usage")
            print("  /questperf timings - Show operation timings")
            print("  /questperf clear [timings/memory/all] - Clear data")
            print("  /questperf report - Show performance report")
            print("  /questperf status - Show monitor status")
        end
    end
end

return QuestPerformanceMonitorEngine
