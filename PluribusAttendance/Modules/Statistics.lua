-- Statistics Module
-- Attendance statistics and analysis

local PluribusAttendanceStats = {}
_G.PluribusAttendanceStats = PluribusAttendanceStats

function PluribusAttendanceStats:GetPlayerAttendance(playerName)
    if not PluribusAttendanceTracker then return 0 end
    
    local attended = 0
    local total = 0
    
    for _, raid in ipairs(PluribusAttendanceTracker.raids) do
        total = total + 1
        if raid.members[playerName] then
            attended = attended + 1
        end
    end
    
    return attended, total, (total > 0 and (attended / total * 100) or 0)
end

function PluribusAttendanceStats:GetTopAttendees(limit)
    limit = limit or 20
    if not PluribusAttendanceTracker then return {} end
    
    local players = {}
    local player_counts = {}
    
    for _, raid in ipairs(PluribusAttendanceTracker.raids) do
        for playerName, member in pairs(raid.members) do
            if not player_counts[playerName] then
                player_counts[playerName] = 0
            end
            player_counts[playerName] = player_counts[playerName] + 1
        end
    end
    
    for playerName, count in pairs(player_counts) do
        table.insert(players, {
            name = playerName,
            raids = count,
            percentage = (count / #PluribusAttendanceTracker.raids * 100),
        })
    end
    
    table.sort(players, function(a, b) return a.raids > b.raids end)
    
    local result = {}
    for i = 1, math.min(limit, #players) do
        table.insert(result, players[i])
    end
    
    return result
end

function PluribusAttendanceStats:GetRaidStats(raidIndex)
    if not PluribusAttendanceTracker then return nil end
    
    raidIndex = raidIndex or #PluribusAttendanceTracker.raids
    local raid = PluribusAttendanceTracker.raids[raidIndex]
    if not raid then return nil end
    
    return {
        name = raid.name,
        date = raid.start_time,
        duration = raid.duration or 0,
        members = #raid.members,
        boss_kills = raid.boss_kills or 0,
    }
end

function PluribusAttendanceStats:GetAttendanceReport()
    if not PluribusAttendanceTracker then return "" end
    
    local report = "=== Attendance Report ===\n"
    local topAttendees = self:GetTopAttendees(15)
    
    report = report .. string.format("%-25s %-10s %-15s\n", "Player", "Raids", "Percentage")
    report = report .. string.rep("-", 50) .. "\n"
    
    for _, player in ipairs(topAttendees) do
        report = report .. string.format("%-25s %-10d %-15.1f%%\n",
            player.name, player.raids, player.percentage)
    end
    
    return report
end

return PluribusAttendanceStats
