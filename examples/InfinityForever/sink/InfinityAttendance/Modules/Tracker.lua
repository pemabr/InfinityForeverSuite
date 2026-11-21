-- Attendance Tracker Module
-- Auto-track raid attendance

local InfinityAttendanceTracker = {}
_G.InfinityAttendanceTracker = InfinityAttendanceTracker

InfinityAttendanceTracker.raids = {}
InfinityAttendanceTracker.callbacks = {}
InfinityAttendanceTracker.auto_tracking = true

function InfinityAttendanceTracker:StartTracking(raidName)
    local raid = {
        name = raidName or GetRealZoneText(),
        start_time = GetTime(),
        members = {},
        boss_kills = 0,
    }
    
    table.insert(self.raids, raid)
    self:ScanRaid(raid)
    self:TriggerCallback("raid_started", raid.name)
    
    return raid
end

function InfinityAttendanceTracker:ScanRaid(raid)
    raid = raid or self.raids[#self.raids]
    if not raid then return end
    
    local maxMembers = GetNumGroupMembers()
    for i = 1, maxMembers do
        local name = select(1, GetRaidRosterInfo(i))
        if name then
            raid.members[name] = {
                name = name,
                class = select(3, GetRaidRosterInfo(i)),
                level = select(4, GetRaidRosterInfo(i)),
                join_time = GetTime(),
                is_online = select(5, GetRaidRosterInfo(i)),
            }
        end
    end
    
    return raid
end

function InfinityAttendanceTracker:EndTracking()
    if #self.raids == 0 then return end
    
    local raid = self.raids[#self.raids]
    raid.end_time = GetTime()
    raid.duration = raid.end_time - raid.start_time
    
    self:TriggerCallback("raid_ended", raid.name, raid.duration)
    return raid
end

function InfinityAttendanceTracker:GetCurrentRaid()
    if #self.raids == 0 then return nil end
    return self.raids[#self.raids]
end

function InfinityAttendanceTracker:GetRaidMembers(raidIndex)
    raidIndex = raidIndex or #self.raids
    if not self.raids[raidIndex] then return {} end
    return self.raids[raidIndex].members
end

function InfinityAttendanceTracker:GetPlayerRaids(playerName, limit)
    limit = limit or 10
    local raids = {}
    
    for i = #self.raids, math.max(1, #self.raids - limit + 1), -1 do
        local raid = self.raids[i]
        if raid.members[playerName] then
            table.insert(raids, 1, raid)
        end
    end
    
    return raids
end

function InfinityAttendanceTracker:SetAutoTracking(enabled)
    self.auto_tracking = enabled
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

return InfinityAttendanceTracker
