-- GatherAnalyticsEngine.lua - Gathering analytics and statistics tracking
-- Part of PluribusGather addon suite
-- Tracks gathering statistics, trends, and performance metrics

local GatherAnalyticsEngine = {}
GatherAnalyticsEngine.enabled = false
GatherAnalyticsEngine.db = nil
GatherAnalyticsEngine.session_data = {}

-- Configuration
GatherAnalyticsEngine.config = {
    enabled = true,
    track_node_distribution = true,
    track_gathering_trends = true,
    track_efficiency = true,
}

function GatherAnalyticsEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusGather")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.analytics_data then
        self.db.analytics_data = {
            gathering_sessions = {},
            node_statistics = {},
            efficiency_metrics = {},
            trends = {},
        }
    end
    
    self.session_data = self.db.analytics_data
    self.enabled = true
    
    self:Log("Initialized analytics engine")
end

function GatherAnalyticsEngine:StartGatheringSession()
    local session = {
        id = "session_" .. GetTime(),
        start_time = GetTime(),
        end_time = nil,
        nodes_found = 0,
        nodes_gathered = 0,
        nodes_failed = 0,
        total_distance = 0,
        average_efficiency = 0,
        events = {},
    }
    
    table.insert(self.session_data.gathering_sessions, session)
    
    self:Log("Started gathering session " .. session.id)
    
    return session.id
end

function GatherAnalyticsEngine:EndGatheringSession(sessionID)
    for _, session in ipairs(self.session_data.gathering_sessions) do
        if session.id == sessionID then
            session.end_time = GetTime()
            session.duration = session.end_time - session.start_time
            
            if session.nodes_gathered > 0 then
                session.average_efficiency = (session.nodes_gathered / (session.nodes_found + 1)) * 100
            end
            
            self:Log("Ended gathering session " .. sessionID .. " - " .. session.nodes_gathered .. " nodes gathered")
            return true
        end
    end
    
    return false
end

function GatherAnalyticsEngine:LogGatheringEvent(sessionID, nodeType, success, distance)
    for _, session in ipairs(self.session_data.gathering_sessions) do
        if session.id == sessionID then
            local event = {
                timestamp = GetTime(),
                node_type = nodeType,
                success = success,
                distance = distance or 0,
            }
            
            table.insert(session.events, event)
            session.nodes_found = session.nodes_found + 1
            if success then
                session.nodes_gathered = session.nodes_gathered + 1
            else
                session.nodes_failed = session.nodes_failed + 1
            end
            session.total_distance = session.total_distance + (distance or 0)
            
            return true
        end
    end
    
    return false
end

function GatherAnalyticsEngine:GetNodeStatistics()
    local stats = {}
    
    for _, session in ipairs(self.session_data.gathering_sessions) do
        for _, event in ipairs(session.events) do
            if not stats[event.node_type] then
                stats[event.node_type] = {
                    type = event.node_type,
                    found = 0,
                    gathered = 0,
                    failed = 0,
                    success_rate = 0,
                    total_distance = 0,
                }
            end
            
            stats[event.node_type].found = stats[event.node_type].found + 1
            if event.success then
                stats[event.node_type].gathered = stats[event.node_type].gathered + 1
            else
                stats[event.node_type].failed = stats[event.node_type].failed + 1
            end
            stats[event.node_type].total_distance = stats[event.node_type].total_distance + (event.distance or 0)
        end
    end
    
    -- Calculate success rates
    for _, stat in pairs(stats) do
        if stat.found > 0 then
            stat.success_rate = (stat.gathered / stat.found) * 100
        end
    end
    
    return stats
end

function GatherAnalyticsEngine:GetSessionStatistics()
    local stats = {
        total_sessions = #self.session_data.gathering_sessions,
        total_nodes_found = 0,
        total_nodes_gathered = 0,
        total_distance = 0,
        average_session_efficiency = 0,
    }
    
    local completed_sessions = 0
    
    for _, session in ipairs(self.session_data.gathering_sessions) do
        stats.total_nodes_found = stats.total_nodes_found + session.nodes_found
        stats.total_nodes_gathered = stats.total_nodes_gathered + session.nodes_gathered
        stats.total_distance = stats.total_distance + session.total_distance
        
        if session.end_time then
            completed_sessions = completed_sessions + 1
            stats.average_session_efficiency = stats.average_session_efficiency + session.average_efficiency
        end
    end
    
    if completed_sessions > 0 then
        stats.average_session_efficiency = stats.average_session_efficiency / completed_sessions
    end
    
    return stats
end

function GatherAnalyticsEngine:GetTrendData(nodeType, timeWindowDays)
    if not timeWindowDays then
        timeWindowDays = 7
    end
    
    local cutoffTime = GetTime() - (timeWindowDays * 86400)
    local trends = {
        node_type = nodeType,
        time_window_days = timeWindowDays,
        daily_totals = {},
        success_rate_trend = {},
        distance_trend = {},
    }
    
    for i = 0, timeWindowDays - 1 do
        local dayStart = cutoffTime + (i * 86400)
        local dayEnd = dayStart + 86400
        
        local dayTotal = 0
        local daySuccesses = 0
        local dayDistance = 0
        
        for _, session in ipairs(self.session_data.gathering_sessions) do
            if session.start_time >= dayStart and session.start_time < dayEnd then
                for _, event in ipairs(session.events) do
                    if event.node_type == nodeType then
                        dayTotal = dayTotal + 1
                        if event.success then
                            daySuccesses = daySuccesses + 1
                        end
                        dayDistance = dayDistance + (event.distance or 0)
                    end
                end
            end
        end
        
        trends.daily_totals[i + 1] = dayTotal
        if dayTotal > 0 then
            trends.success_rate_trend[i + 1] = (daySuccesses / dayTotal) * 100
            trends.distance_trend[i + 1] = dayDistance / dayTotal
        else
            trends.success_rate_trend[i + 1] = 0
            trends.distance_trend[i + 1] = 0
        end
    end
    
    return trends
end

function GatherAnalyticsEngine:GetEfficiencyMetrics()
    local stats = self:GetSessionStatistics()
    
    return {
        nodes_per_session = stats.total_sessions > 0 and stats.total_nodes_gathered / stats.total_sessions or 0,
        distance_per_node = stats.total_nodes_gathered > 0 and stats.total_distance / stats.total_nodes_gathered or 0,
        overall_success_rate = stats.total_nodes_found > 0 and (stats.total_nodes_gathered / stats.total_nodes_found) * 100 or 0,
        average_session_efficiency = stats.average_session_efficiency,
    }
end

function GatherAnalyticsEngine:ExportAnalyticsData(format)
    if not format then
        format = "json"
    end
    
    if format == "json" then
        return {
            sessions = self.session_data.gathering_sessions,
            node_stats = self:GetNodeStatistics(),
            efficiency = self:GetEfficiencyMetrics(),
        }
    elseif format == "csv" then
        local csv = "SessionID,StartTime,EndTime,NodesFound,NodesGathered,NodesFailed,TotalDistance,Efficiency\n"
        
        for _, session in ipairs(self.session_data.gathering_sessions) do
            csv = csv .. session.id .. "," .. session.start_time .. "," .. (session.end_time or 0) .. ","
            csv = csv .. session.nodes_found .. "," .. session.nodes_gathered .. "," .. session.nodes_failed .. ","
            csv = csv .. math.floor(session.total_distance) .. "," .. math.floor(session.average_efficiency * 100) / 100 .. "\n"
        end
        
        return csv
    end
    
    return nil
end

function GatherAnalyticsEngine:GetStatus()
    local stats = self:GetSessionStatistics()
    
    return {
        enabled = self.enabled,
        total_sessions = stats.total_sessions,
        total_gathered = stats.total_nodes_gathered,
        average_efficiency = stats.average_session_efficiency,
    }
end

function GatherAnalyticsEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[GatherAnalyticsEngine] " .. message)
    else
        print("[GatherAnalyticsEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERANALYTICS1 = "/gatheranalytics"
    SlashCmdList["GATHERANALYTICS"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "start" then
            local sessionID = GatherAnalyticsEngine:StartGatheringSession()
            print("Session started: " .. sessionID)
        elseif cmd == "end" then
            local sessions = GatherAnalyticsEngine.session_data.gathering_sessions
            if #sessions > 0 then
                local lastSession = sessions[#sessions]
                GatherAnalyticsEngine:EndGatheringSession(lastSession.id)
                print("Session ended")
            end
        elseif cmd == "stats" then
            local stats = GatherAnalyticsEngine:GetSessionStatistics()
            print("Gathering Statistics:")
            print("  Sessions: " .. stats.total_sessions)
            print("  Total gathered: " .. stats.total_nodes_gathered)
            print("  Total found: " .. stats.total_nodes_found)
            print("  Average efficiency: " .. math.floor(stats.average_session_efficiency * 100) / 100 .. "%")
        elseif cmd == "efficiency" then
            local metrics = GatherAnalyticsEngine:GetEfficiencyMetrics()
            print("Efficiency Metrics:")
            print("  Nodes/session: " .. math.floor(metrics.nodes_per_session * 100) / 100)
            print("  Distance/node: " .. math.floor(metrics.distance_per_node) .. " yards")
            print("  Success rate: " .. math.floor(metrics.overall_success_rate * 100) / 100 .. "%")
        elseif cmd == "status" then
            local status = GatherAnalyticsEngine:GetStatus()
            print("Analytics Status:")
            print("  Sessions: " .. status.total_sessions)
            print("  Total gathered: " .. status.total_gathered)
            print("  Efficiency: " .. math.floor(status.average_efficiency * 100) / 100 .. "%")
        else
            print("Analytics Commands:")
            print("  /gatheranalytics start - Start new session")
            print("  /gatheranalytics end - End current session")
            print("  /gatheranalytics stats - Show session statistics")
            print("  /gatheranalytics efficiency - Show efficiency metrics")
            print("  /gatheranalytics status - Show status")
        end
    end
end

return GatherAnalyticsEngine
