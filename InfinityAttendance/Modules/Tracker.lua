-- Attendance Tracker Module
-- Auto-track raid attendance

local InfinityAttendanceTracker = {}
_G.InfinityAttendanceTracker = InfinityAttendanceTracker

InfinityAttendanceTracker.raids = {}
InfinityAttendanceTracker.callbacks = {}
InfinityAttendanceTracker.auto_tracking = true

local function Public(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

function InfinityAttendanceTracker:StartTracking(raidName)
    raidName = Public(raidName)
    local zone = _G.GetRealZoneText and Public(GetRealZoneText())
    local started = _G.GetTime and Public(GetTime())
    if type(started) ~= "number" or started ~= started or started < 0 or started >= math.huge then
        InfinityUtils:Warning("Attendance tracking cannot start: time unavailable.", "Attendance")
        return nil
    end
    local raid = {
        name = type(raidName) == "string" and raidName ~= "" and raidName
            or type(zone) == "string" and zone ~= "" and zone or "Unknown",
        start_time = started,
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
    
    local maxMembers = _G.GetNumGroupMembers and Public(GetNumGroupMembers())
    local now = _G.GetTime and Public(GetTime())
    if type(maxMembers) ~= "number" or maxMembers ~= maxMembers or maxMembers < 0 or maxMembers > 40
        or maxMembers ~= math.floor(maxMembers) or type(now) ~= "number" or now ~= now or now < 0 or now >= math.huge
        or (maxMembers > 0 and not _G.GetRaidRosterInfo) then
        InfinityUtils:Warning("Attendance roster unavailable.", "Attendance")
        return false
    end
    local scanned = {}
    for i = 1, maxMembers do
        local name, _, _, level, class, _, _, online = GetRaidRosterInfo(i)
        name, level, class, online = Public(name), Public(level), Public(class), Public(online)
        if type(name) ~= "string" or name == "" then
            InfinityUtils:Warning("Attendance roster is incomplete or protected.", "Attendance")
            return false
        end
        scanned[name] = {
            name = name,
            class = type(class) == "string" and class or nil,
            level = type(level) == "number" and level or nil,
            join_time = now,
            is_online = online == true or online == 1,
        }
    end
    for name, member in pairs(scanned) do raid.members[name] = member end
    
    return raid
end

function InfinityAttendanceTracker:EndTracking()
    if #self.raids == 0 then return end
    
    local raid = self.raids[#self.raids]
    local now = _G.GetTime and Public(GetTime())
    if type(now) ~= "number" or now ~= now or now < raid.start_time or now >= math.huge then
        InfinityUtils:Warning("Attendance tracking cannot end: time unavailable.", "Attendance")
        return nil
    end
    raid.end_time = now
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
