-- Reports Module
-- Generate DKP reports and statistics

local InfinityDKPReports = {}
_G.InfinityDKPReports = InfinityDKPReports

function InfinityDKPReports:GenerateSummary()
    local summary = "=== Infinity DKP Report ===\n"
    summary = summary .. "Generated: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"
    
    if InfinityDKPEngine then
        local stats = InfinityDKPEngine:GetStats()
        summary = summary .. string.format("Total Players: %d\n", stats.total_players)
        summary = summary .. string.format("Total EP: %d\n", stats.total_ep)
        summary = summary .. string.format("Total GP: %d\n", stats.total_gp)
        summary = summary .. string.format("Average EP: %.2f\n", stats.avg_ep)
        summary = summary .. string.format("Average GP: %.2f\n", stats.avg_gp)
        summary = summary .. "\n"
    end
    
    return summary
end

function InfinityDKPReports:GeneratePriorityList()
    local system = InfinityDKPEngine and InfinityDKPEngine.system_type or "unknown"
    local report = "=== Priority List (" .. system:upper() .. ") ===\n"
    report = report .. string.format("%-25s %-10s %-10s %-10s\n", "Player", "EP", "GP", "Priority")
    report = report .. string.rep("-", 55) .. "\n"
    
    if InfinityDKPEngine then
        local ranked = InfinityDKPEngine:GetRankedPlayers()
        for _, player in ipairs(ranked) do
            report = report .. string.format("%-25s %-10d %-10d %-10.2f\n",
                player.name, player.ep, player.gp, player.priority)
        end
    end
    
    return report
end

function InfinityDKPReports:GenerateAttendanceReport()
    local report = "=== Local Encounter Attendance (any presence) ===\n"
    report = report .. string.format("%-20s %-15s\n", "Player", "Attendance %")
    report = report .. string.rep("-", 35) .. "\n"
    
    if InfinityDKPEngine then
        for playerName, player in pairs(InfinityDKPEngine:GetAllPlayers()) do
            if InfinityDKPAttendanceTracker then
                local stats = InfinityDKPAttendanceTracker:GetAttendanceStats(playerName)
                report = report .. string.format("%-20s %-15.1f%%\n", playerName, stats.percentage)
            end
        end
    end
    
    return report
end

function InfinityDKPReports:GenerateLootReport(days)
    days = days or 7
    local report = string.format("=== Loot Report (Last %d days) ===\n", days)
    report = report .. string.format("%-25s %-40s %-10s %-15s\n", "Player", "Item", "Points", "Date")
    report = report .. string.rep("-", 90) .. "\n"
    
    if InfinityDKPHistory then
        local history = InfinityDKPHistory:GetRecentAwards(days)
        for _, award in ipairs(history) do
            report = report .. string.format("%-25s %-40s %-10d %s | %s%s\n",
                award.player, award.item, award.points, award.timestamp, tostring(award.type or "unknown"),
                award.refund and " | refunded" or "")
        end
    end
    
    return report
end

function InfinityDKPReports:GenerateFullReport(days)
    days = days or 7
    local report = ""
    
    report = report .. self:GenerateSummary()
    report = report .. "\n"
    report = report .. self:GeneratePriorityList()
    report = report .. "\n"
    report = report .. self:GenerateAttendanceReport()
    report = report .. "\n"
    report = report .. self:GenerateLootReport(days)
    
    return report
end

return InfinityDKPReports
