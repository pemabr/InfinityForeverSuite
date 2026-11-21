-- Timer Management System
-- Handles ability timers, cooldowns, and countdown warnings

local InfinityEncounterTimer = {}
_G.InfinityEncounterTimer = InfinityEncounterTimer

InfinityEncounterTimer.timers = {}
InfinityEncounterTimer.active_timers = {}
InfinityEncounterTimer.countdown_warnings = {5, 10, 30, 60}

-- Timer object
local Timer = {}
Timer.__index = Timer

function Timer:new(id, name, duration, callback)
    local t = {
        id = id,
        name = name,
        duration = duration,
        start_time = GetTime(),
        callback = callback,
        warnings = {},
    }
    setmetatable(t, Timer)
    return t
end

function Timer:GetRemaining()
    local elapsed = GetTime() - self.start_time
    return math.max(0, self.duration - elapsed)
end

function Timer:IsExpired()
    return self:GetRemaining() <= 0
end

function Timer:GetProgress()
    return math.min(1, (GetTime() - self.start_time) / self.duration)
end

-- Public Timer Manager API
function InfinityEncounterTimer:CreateTimer(id, name, duration, callback)
    if not id or not duration or duration <= 0 then
        return nil
    end
    
    local timer = Timer:new(id, name, duration, callback)
    self.timers[id] = timer
    table.insert(self.active_timers, timer)
    return timer
end

function InfinityEncounterTimer:RemoveTimer(id)
    if self.timers[id] then
        self.timers[id] = nil
        for i, timer in ipairs(self.active_timers) do
            if timer.id == id then
                table.remove(self.active_timers, i)
                break
            end
        end
    end
end

function InfinityEncounterTimer:GetTimer(id)
    return self.timers[id]
end

function InfinityEncounterTimer:GetActiveTimers()
    return self.active_timers
end

function InfinityEncounterTimer:Update()
    local now = GetTime()
    local expired = {}
    
    for i = #self.active_timers, 1, -1 do
        local timer = self.active_timers[i]
        local remaining = timer:GetRemaining()
        
        -- Check for expiration
        if timer:IsExpired() then
            table.insert(expired, timer.id)
            table.remove(self.active_timers, i)
            if timer.callback then
                pcall(timer.callback, timer)
            end
        else
            -- Check for warnings
            for _, warning_time in ipairs(self.countdown_warnings) do
                if remaining <= warning_time and remaining > (warning_time - 1) then
                    if not timer.warnings[warning_time] then
                        timer.warnings[warning_time] = true
                        -- Trigger warning callback
                        if InfinityCore and InfinityCore.FireEvent then
                            InfinityCore:FireEvent("timer_warning", timer.name, remaining)
                        end
                    end
                end
            end
        end
    end
    
    return expired
end

function InfinityEncounterTimer:ClearAllTimers()
    self.timers = {}
    self.active_timers = {}
end

function InfinityEncounterTimer:GetTimerCount()
    return #self.active_timers
end

return InfinityEncounterTimer
