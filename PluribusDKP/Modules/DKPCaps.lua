-- Weekly and Hard DKP Cap System
-- Enforce maximum DKP that can be earned per week and lifetime

local MODULE_NAME = "DKPCaps"
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusDKP.Caps = {
    enabled = false,
    
    config = {
        weekly_cap_enabled = true,
        weekly_cap_amount = 500,        -- Max 500 EP per week
        hard_cap_enabled = true,
        hard_cap_amount = 2000,         -- Lifetime max 2000 EP
        cap_reset_day = 1,              -- 1 = Monday
        cap_reset_time = 0,             -- 00:00 (midnight)
        ignore_boss_kills = false,      -- Boss kills don't count toward cap
        log_violations = true
    },
    
    player_weekly_earned = {},          -- Track per-player per-week earnings
    player_lifetime_earned = {},        -- Track lifetime earnings
    weekly_reset_time = 0,
    cap_violations = {}
}

local Caps = PluribusDKP.Caps

function Caps:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if not PluribusDKP.db then
        PluribusDKP.db = {}
    end
    if not PluribusDKP.db.cap_violations then
        PluribusDKP.db.cap_violations = {}
    end
    if not PluribusDKP.db.weekly_cap_reset_time then
        PluribusDKP.db.weekly_cap_reset_time = 0
    end
    
    self:CalculateNextWeeklyReset()
    self:ScheduleWeeklyReset()
    
    if PluribusCore.Events then
        PluribusCore.Events:Register("points_awarded", function(player, amount, reason)
            Caps:OnPointsAwarded(player, amount, reason)
        end)
        
        PluribusCore.Events:Register("loot_awarded", function(player, item, gp_cost)
            Caps:OnLootAwarded(player, gp_cost)
        end)
    end
end

function Caps:OnPointsAwarded(player, amount, reason)
    if not self.config.weekly_cap_enabled and not self.config.hard_cap_enabled then
        return
    end
    
    if not player or not amount or amount <= 0 then
        return
    end
    
    -- Skip boss kills if configured to ignore them for cap
    if self.config.ignore_boss_kills and reason and reason:find("Boss Kill") then
        return
    end
    
    -- Check weekly cap
    if self.config.weekly_cap_enabled then
        local weekly_earned = self.player_weekly_earned[player] or 0
        
        if weekly_earned + amount > self.config.weekly_cap_amount then
            self:LogCapViolation(player, amount, "weekly", self.config.weekly_cap_amount, weekly_earned)
            
            if DEFAULT_CHAT_FRAME then
                local remaining = self.config.weekly_cap_amount - weekly_earned
                DEFAULT_CHAT_FRAME:AddMessage(
                    string.format("|cffff0000Weekly cap exceeded for %s! Only %d allowed, tried to add %d|r",
                        player,
                        self.config.weekly_cap_amount,
                        amount
                    )
                )
            end
            
            return false, "Weekly cap exceeded"
        end
        
        self.player_weekly_earned[player] = weekly_earned + amount
    end
    
    -- Check hard cap
    if self.config.hard_cap_enabled then
        local lifetime_earned = self.player_lifetime_earned[player] or 0
        
        if lifetime_earned + amount > self.config.hard_cap_amount then
            self:LogCapViolation(player, amount, "hard", self.config.hard_cap_amount, lifetime_earned)
            
            if DEFAULT_CHAT_FRAME then
                local remaining = self.config.hard_cap_amount - lifetime_earned
                DEFAULT_CHAT_FRAME:AddMessage(
                    string.format("|cffff0000Hard cap reached for %s! Lifetime max is %d|r",
                        player,
                        self.config.hard_cap_amount
                    )
                )
            end
            
            return false, "Hard cap exceeded"
        end
        
        self.player_lifetime_earned[player] = lifetime_earned + amount
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("dkp_cap_checked", player, amount, true)
    end
    
    return true, nil
end

function Caps:OnLootAwarded(player, gp_cost)
    -- GP costs don't count toward caps typically
    -- Override this if your system wants GP to count
    return true
end

function Caps:LogCapViolation(player, amount, cap_type, cap_limit, current_earned)
    if not self.config.log_violations then return end
    
    local violation = {
        timestamp = time(),
        player = player,
        amount_attempted = amount,
        cap_type = cap_type,
        cap_limit = cap_limit,
        current_earned = current_earned,
        overage = (current_earned + amount) - cap_limit
    }
    
    table.insert(self.cap_violations, violation)
    
    if PluribusDKP.db then
        PluribusDKP.db.cap_violations = self.cap_violations
    end
end

function Caps:CalculateNextWeeklyReset()
    local now_time = time()
    local date_table = date("*t", now_time)
    
    -- Get current day of week (1=Sunday, 2=Monday, etc.)
    local current_day = date_table.wday
    local target_day = self.config.cap_reset_day + 1  -- Convert to Lua wday format
    
    -- Calculate seconds until next reset day
    local days_until_reset = (target_day - current_day) % 7
    if days_until_reset == 0 then
        days_until_reset = 7
    end
    
    -- If it's the reset day but hasn't hit the reset time yet
    if days_until_reset == 7 or (days_until_reset == 0 and date_table.hour >= self.config.cap_reset_time) then
        days_until_reset = 7
    end
    
    local reset_seconds = (days_until_reset * 86400) - 
                         (date_table.hour * 3600) - 
                         (date_table.min * 60) - 
                         date_table.sec +
                         (self.config.cap_reset_time * 3600)
    
    self.weekly_reset_time = now_time + reset_seconds
    
    if PluribusDKP.db then
        PluribusDKP.db.weekly_cap_reset_time = self.weekly_reset_time
    end
end

function Caps:ScheduleWeeklyReset()
    -- Check every hour if it's time to reset
    C_Timer.NewLoopingTimer(3600, function()
        if time() >= Caps.weekly_reset_time then
            Caps:ResetWeeklyCaps()
        end
    end)
end

function Caps:ResetWeeklyCaps()
    self.player_weekly_earned = {}
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Weekly DKP caps have been reset|r")
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("weekly_caps_reset")
    end
    
    self:CalculateNextWeeklyReset()
end

function Caps:GetPlayerWeeklyEarned(player)
    return self.player_weekly_earned[player] or 0
end

function Caps:GetPlayerWeeklyRemaining(player)
    local earned = self:GetPlayerWeeklyEarned(player)
    return math.max(0, self.config.weekly_cap_amount - earned)
end

function Caps:GetPlayerLifetimeEarned(player)
    return self.player_lifetime_earned[player] or 0
end

function Caps:GetPlayerHardCapRemaining(player)
    local earned = self:GetPlayerLifetimeEarned(player)
    return math.max(0, self.config.hard_cap_amount - earned)
end

function Caps:SetWeeklyCap(ep_amount)
    if ep_amount < 1 or ep_amount > 5000 then
        print("|cffff0000Weekly cap must be 1-5000|r")
        return false
    end
    
    self.config.weekly_cap_amount = ep_amount
    print(string.format("|cff00ccffWeekly DKP cap set to %d|r", ep_amount))
    return true
end

function Caps:SetHardCap(ep_amount)
    if ep_amount < 1 or ep_amount > 20000 then
        print("|cffff0000Hard cap must be 1-20000|r")
        return false
    end
    
    self.config.hard_cap_amount = ep_amount
    print(string.format("|cff00ccffHard DKP cap set to %d|r", ep_amount))
    return true
end

function Caps:EnableWeeklyCap(enable)
    self.config.weekly_cap_enabled = enable
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffWeekly cap enforcement %s|r", status))
    return true
end

function Caps:EnableHardCap(enable)
    self.config.hard_cap_enabled = enable
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffHard cap enforcement %s|r", status))
    return true
end

function Caps:SetCapResetDay(day_name)
    local days = {
        ["sunday"] = 0,
        ["monday"] = 1,
        ["tuesday"] = 2,
        ["wednesday"] = 3,
        ["thursday"] = 4,
        ["friday"] = 5,
        ["saturday"] = 6
    }
    
    day_name = day_name:lower()
    if not days[day_name] then
        print("|cffff0000Invalid day. Use: sunday-saturday|r")
        return false
    end
    
    self.config.cap_reset_day = days[day_name]
    self:CalculateNextWeeklyReset()
    
    print(string.format("|cff00ccffCap reset day set to %s|r", day_name:gsub("^%l", string.upper)))
    return true
end

function Caps:PrintStatus()
    print("|cff00ccffDKP Cap System Status:|r")
    print("")
    print("Weekly Cap:")
    print(string.format("  Enabled: %s", self.config.weekly_cap_enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Maximum: %d", self.config.weekly_cap_amount))
    print(string.format("  Reset Day: %s at %02d:00", self:GetDayName(self.config.cap_reset_day), self.config.cap_reset_time))
    local hours_until = math.ceil((self.weekly_reset_time - time()) / 3600)
    print(string.format("  Next Reset: ~%d hours", math.max(0, hours_until)))
    
    print("")
    print("Hard Cap:")
    print(string.format("  Enabled: %s", self.config.hard_cap_enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Maximum: %d", self.config.hard_cap_amount))
    
    print("")
    print(string.format("Violations Logged: %d", #self.cap_violations))
    print("")
end

function Caps:PrintPlayerCaps(player)
    if not player then
        print("|cffff0000Player name required|r")
        return
    end
    
    local weekly_earned = self:GetPlayerWeeklyEarned(player)
    local weekly_remaining = self:GetPlayerWeeklyRemaining(player)
    local lifetime_earned = self:GetPlayerLifetimeEarned(player)
    local hard_remaining = self:GetPlayerHardCapRemaining(player)
    
    print(string.format("|cff00ccffDKP Caps for %s:|r", player))
    print("")
    print("Weekly:")
    print(string.format("  Earned: %d / %d", weekly_earned, self.config.weekly_cap_amount))
    print(string.format("  Remaining: %d", weekly_remaining))
    
    print("")
    print("Lifetime:")
    print(string.format("  Earned: %d / %d", lifetime_earned, self.config.hard_cap_amount))
    print(string.format("  Remaining: %d", hard_remaining))
    print("")
end

function Caps:GetDayName(day)
    local days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
    return days[day + 1] or "Unknown"
end

function Caps:PrintViolations(limit)
    limit = limit or 10
    
    if #self.cap_violations == 0 then
        print("|cffff9900No cap violations recorded|r")
        return
    end
    
    print("|cff00ccffRecent DKP Cap Violations:|r")
    print("")
    
    for i = #self.cap_violations, math.max(1, #self.cap_violations - limit + 1), -1 do
        local violation = self.cap_violations[i]
        local date_str = date("%H:%M:%S", violation.timestamp)
        
        print(string.format("[%s] %s - %s cap (tried +%d, limit %d, earned %d, overage %d)",
            date_str,
            violation.player or "Unknown",
            violation.cap_type,
            violation.amount_attempted,
            violation.cap_limit,
            violation.current_earned,
            violation.overage
        ))
    end
    
    print("")
end

return PluribusDKP.Caps
