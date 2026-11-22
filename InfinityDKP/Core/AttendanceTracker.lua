-- Attendance Tracker
-- Track raid attendance for compensation/DKP purposes

local InfinityAttendanceTracker = {}
_G.InfinityAttendanceTracker = InfinityAttendanceTracker

InfinityAttendanceTracker.raids = {}
InfinityAttendanceTracker.attendance_log = {}
InfinityAttendanceTracker.callbacks = {}

function InfinityAttendanceTracker:StartRaid(raidName, difficulty)
    local raid = {
        name = raidName,
        difficulty = difficulty or "Normal",
        start_time = GetTime(),
        end_time = nil,
        duration = 0,
        members = {},
        boss_kills = 0,
        wipes = 0,
    }
    
    table.insert(self.raids, raid)
    self:TriggerCallback("raid_started", raidName, difficulty)
    
    return raid
end

function InfinityAttendanceTracker:EndRaid()
    if #self.raids == 0 then return end
    
    local raid = self.raids[#self.raids]
    raid.end_time = GetTime()
    raid.duration = raid.end_time - raid.start_time
    
    self:TriggerCallback("raid_ended", raid.name, raid.duration)
    return raid
end

function InfinityAttendanceTracker:MarkAttendance(playerName, present)
    if #self.raids == 0 then
        self:StartRaid("Active Raid")
    end
    
    local raid = self.raids[#self.raids]
    raid.members[playerName] = {
        name = playerName,
        present = present,
        join_time = GetTime(),
        class = select(2, UnitClass(playerName)),
    }
    
    table.insert(self.attendance_log, {
        raid = raid.name,
        player = playerName,
        present = present,
        time = GetTime(),
    })
    
    self:TriggerCallback("attendance_marked", playerName, present)
    return true
end

function InfinityAttendanceTracker:GetRaidAttendance(raidIndex)
    raidIndex = raidIndex or #self.raids
    if not self.raids[raidIndex] then return {} end
    
    return self.raids[raidIndex].members
end

function InfinityAttendanceTracker:GetPlayerAttendance(playerName, limit)
    limit = limit or 10
    local attendance = {}
    
    for i = #self.raids, math.max(1, #self.raids - limit + 1), -1 do
        local raid = self.raids[i]
        if raid.members[playerName] then
            table.insert(attendance, 1, {
                raid = raid.name,
                present = raid.members[playerName].present,
                date = raid.start_time,
            })
        end
    end
    
    return attendance
end

function InfinityAttendanceTracker:GetAttendanceStats(playerName)
    local attendance = self:GetPlayerAttendance(playerName, 999)
    local attended = 0
    local total = 0
    
    for _, record in ipairs(attendance) do
        total = total + 1
        if record.present then
            attended = attended + 1
        end
    end
    
    return {
        attended = attended,
        total = total,
        percentage = total > 0 and (attended / total * 100) or 0,
    }
end

function InfinityAttendanceTracker:RecordBossKill(bossName)
    if #self.raids > 0 then
        self.raids[#self.raids].boss_kills = (self.raids[#self.raids].boss_kills or 0) + 1
        self:TriggerCallback("boss_killed", bossName)
    end
end

function InfinityAttendanceTracker:RecordWipe()
    if #self.raids > 0 then
        self.raids[#self.raids].wipes = (self.raids[#self.raids].wipes or 0) + 1
        self:TriggerCallback("raid_wipe")
    end
end

function InfinityAttendanceTracker:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityAttendanceTracker:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityAttendanceTracker:GetRaids()
    return self.raids
end

return InfinityAttendanceTracker
