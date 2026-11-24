-- DKP Decay System
-- Automatically decay DKP points on a schedule (weekly, bi-weekly, etc.)

local MODULE_NAME = "DKPDecay"
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusDKP.Decay = {
    enabled = false,
    
    -- Configuration
    config = {
        decay_enabled = true,
        decay_rate = 0.10,              -- 10% weekly decay
        decay_interval = 7 * 86400,     -- 7 days in seconds
        decay_day = 1,                  -- 1 = Monday, 0 = Sunday
        decay_time = 20,                -- Hour (20:00 / 8 PM)
        minimum_dkp = 100,              -- Don't decay below this
        apply_minimum = true            -- Whether to apply minimum threshold
    },
    
    last_decay_time = 0,
    decay_timer = nil
}

local Decay = PluribusDKP.Decay

function Decay:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if not PluribusDKP.db then
        PluribusDKP.db = {}
    end
    if not PluribusDKP.db.decay_log then
        PluribusDKP.db.decay_log = {}
    end
    
    -- Merge config
    for key, value in pairs(self.config) do
        if PluribusDKP.db["decay_" .. key] == nil then
            PluribusDKP.db["decay_" .. key] = value
        end
    end
    
    self:ScheduleNextDecay()
end

function Decay:IsTimeForDecay()
    local now = GetTime()
    local last = self.last_decay_time or 0
    
    -- Check if interval has passed
    if now - last < self.config.decay_interval then
        return false
    end
    
    -- Check if it's the right day/time
    local date_table = date("*t", time())
    
    -- Check day of week (1=Sunday, 2=Monday, etc. in Lua)
    local current_day = date_table.wday - 1  -- Convert to 0=Sunday, 1=Monday
    local decay_day = self.config.decay_day
    
    if current_day ~= decay_day then
        return false
    end
    
    -- Check if past the target hour
    if date_table.hour < self.config.decay_time then
        return false
    end
    
    return true
end

function Decay:ScheduleNextDecay()
    if self.decay_timer then
        self.decay_timer:Cancel()
    end
    
    -- Check every hour if it's time to decay
    self.decay_timer = C_Timer.NewLoopingTimer(3600, function()
        if Decay:IsTimeForDecay() then
            Decay:ApplyDecay()
        end
    end)
end

function Decay:ApplyDecay()
    if not self.config.decay_enabled then
        return
    end
    
    if not PluribusDKP.db or not PluribusDKP.db.players then
        return
    end
    
    local decay_rate = self.config.decay_rate
    local minimum_dkp = self.config.minimum_dkp
    local apply_min = self.config.apply_minimum
    
    local decayed_count = 0
    local total_lost = 0
    
    for player_name, player_data in pairs(PluribusDKP.db.players) do
        local old_balance = player_data.balance or 0
        local decay_amount = math.floor(old_balance * decay_rate)
        local new_balance = old_balance - decay_amount
        
        -- Apply minimum threshold
        if apply_min and new_balance < minimum_dkp then
            new_balance = minimum_dkp
            decay_amount = old_balance - minimum_dkp
        end
        
        if decay_amount > 0 then
            player_data.balance = new_balance
            
            -- Log the decay transaction
            if PluribusDKP.db.transactions then
                table.insert(PluribusDKP.db.transactions, {
                    timestamp = time(),
                    player = player_name,
                    amount = -decay_amount,
                    reason = "Weekly Decay",
                    balance_after = new_balance,
                    source = "system",
                    type = "decay"
                })
            end
            
            decayed_count = decayed_count + 1
            total_lost = total_lost + decay_amount
        end
    end
    
    -- Log decay event
    table.insert(PluribusDKP.db.decay_log, {
        timestamp = time(),
        decay_rate = decay_rate,
        players_affected = decayed_count,
        total_points_lost = total_lost,
        minimum_applied = apply_min
    })
    
    self.last_decay_time = GetTime()
    
    -- Notify in chat
    print(string.format("|cff00ccffDKP Decay Applied:|r %d players affected, %d points removed",
        decayed_count, total_lost))
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("dkp_decay_applied", decayed_count, total_lost)
    end
end

function Decay:SetDecayRate(rate)
    if rate < 0 or rate > 1 then
        print("|cffff0000Invalid decay rate. Must be 0-1 (0%-100%)|r")
        return false
    end
    
    self.config.decay_rate = rate
    if PluribusDKP.db then
        PluribusDKP.db.decay_decay_rate = rate
    end
    
    print(string.format("|cff00ccffDecay rate set to %.1f%%|r", rate * 100))
    return true
end

function Decay:SetDecayInterval(days)
    if days < 1 or days > 365 then
        print("|cffff0000Invalid interval. Must be 1-365 days|r")
        return false
    end
    
    self.config.decay_interval = days * 86400
    if PluribusDKP.db then
        PluribusDKP.db.decay_decay_interval = self.config.decay_interval
    end
    
    print(string.format("|cff00ccffDecay interval set to %d days|r", days))
    return true
end

function Decay:SetMinimumDKP(minimum)
    if minimum < 0 then
        print("|cffff0000Minimum DKP cannot be negative|r")
        return false
    end
    
    self.config.minimum_dkp = minimum
    if PluribusDKP.db then
        PluribusDKP.db.decay_minimum_dkp = minimum
    end
    
    print(string.format("|cff00ccffMinimum DKP set to %d|r", minimum))
    return true
end

function Decay:EnableDecay(enable)
    self.config.decay_enabled = enable
    if PluribusDKP.db then
        PluribusDKP.db.decay_decay_enabled = enable
    end
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffDKP decay %s|r", status))
    return true
end

function Decay:PrintDecayStatus()
    print("|cff00ccffDKP Decay Status:|r")
    print(string.format("  Enabled: %s", self.config.decay_enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Rate: %.1f%%", self.config.decay_rate * 100))
    print(string.format("  Interval: %d days", self.config.decay_interval / 86400))
    print(string.format("  Day: %s", self:GetDayName(self.config.decay_day)))
    print(string.format("  Time: %02d:00", self.config.decay_time))
    print(string.format("  Minimum DKP: %d", self.config.minimum_dkp))
    print("")
end

function Decay:GetDayName(day)
    local days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
    return days[day + 1] or "Unknown"
end

function Decay:GetDecayHistory(limit)
    limit = limit or 10
    
    if not PluribusDKP.db or not PluribusDKP.db.decay_log then
        return {}
    end
    
    local history = {}
    for i = #PluribusDKP.db.decay_log, math.max(1, #PluribusDKP.db.decay_log - limit + 1), -1 do
        table.insert(history, PluribusDKP.db.decay_log[i])
    end
    
    return history
end

function Decay:PrintDecayHistory()
    local history = self:GetDecayHistory(10)
    
    print("|cff00ccffRecent Decay Events:|r")
    print("")
    
    for _, event in ipairs(history) do
        local date_str = date("%Y-%m-%d %H:%M:%S", event.timestamp)
        print(string.format("[%s] %d players, %d DKP removed (%.0f%%)",
            date_str,
            event.players_affected,
            event.total_points_lost,
            event.decay_rate * 100
        ))
    end
end

return PluribusDKP.Decay
