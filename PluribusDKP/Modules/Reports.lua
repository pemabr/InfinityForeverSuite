-- Reports Module
-- Generate DKP reports and statistics

local PluribusDKPReports = {}
_G.PluribusDKPReports = PluribusDKPReports

function PluribusDKPReports:GenerateSummary()
    local summary = "=== Pluribus DKP Report ===\n"
    summary = summary .. "Generated: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"
    
    if PluribusDKPEngine then
        local stats = PluribusDKPEngine:GetStats()
        summary = summary .. string.format("Total Players: %d\n", stats.total_players)
        summary = summary .. string.format("Total EP: %d\n", stats.total_ep)
        summary = summary .. string.format("Total GP: %d\n", stats.total_gp)
        summary = summary .. string.format("Average EP: %.2f\n", stats.avg_ep)
        summary = summary .. string.format("Average GP: %.2f\n", stats.avg_gp)
        summary = summary .. "\n"
    end
    
    return summary
end

function PluribusDKPReports:GeneratePriorityList()
    local report = "=== Priority List (EPGP) ===\n"
    report = report .. string.format("%-25s %-10s %-10s %-10s\n", "Player", "EP", "GP", "Priority")
    report = report .. string.rep("-", 55) .. "\n"
    
    if PluribusDKPEngine then
        local ranked = PluribusDKPEngine:GetRankedPlayers()
        for i, player in ipairs(ranked) do
            if i > 20 then break end
            report = report .. string.format("%-25s %-10d %-10d %-10.2f\n",
                player.name, player.ep, player.gp, player.priority)
        end
    end
    
    return report
end

function PluribusDKPReports:GenerateAttendanceReport()
    local report = "=== Attendance Report ===\n"
    report = report .. string.format("%-20s %-15s\n", "Player", "Attendance %")
    report = report .. string.rep("-", 35) .. "\n"
    
    if PluribusDKPEngine then
        for playerName, player in pairs(PluribusDKPEngine:GetAllPlayers()) do
            if PluribusAttendanceTracker then
                local stats = PluribusAttendanceTracker:GetAttendanceStats(playerName)
                report = report .. string.format("%-20s %-15.1f%%\n", playerName, stats.percentage)
            end
        end
    end
    
    return report
end

function PluribusDKPReports:GenerateLootReport(days)
    days = days or 7
    local report = string.format("=== Loot Report (Last %d days) ===\n", days)
    report = report .. string.format("%-25s %-40s %-10s %-15s\n", "Player", "Item", "GP Cost", "Date")
    report = report .. string.rep("-", 90) .. "\n"
    
    if PluribusDKPHistory then
        local history = PluribusDKPHistory:GetRecentAwards(days)
        for _, award in ipairs(history) do
            report = report .. string.format("%-25s %-40s %-10d %s\n",
                award.player, award.item, award.points, award.timestamp)
        end
    end
    
    return report
end

function PluribusDKPReports:GenerateFullReport(days)
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

return PluribusDKPReports
