-- EncounterComparisonEngine.lua - Compare performance across multiple attempts
-- Part of PluribusDetails addon suite
-- Tracks raid attempts and provides comparative analysis

local EncounterComparisonEngine = {}
EncounterComparisonEngine.enabled = false
EncounterComparisonEngine.db = nil
EncounterComparisonEngine.attempts = {}
EncounterComparisonEngine.current_attempt = nil

-- Configuration
EncounterComparisonEngine.config = {
    enabled = true,
    max_attempts = 100,  -- Store up to 100 attempts
    auto_save = true,
}

function EncounterComparisonEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.attempts then
        self.db.attempts = {}
    end
    
    self.attempts = self.db.attempts
    self.enabled = true
    
    self:Log("Initialized encounter comparison engine")
end

function EncounterComparisonEngine:StartAttempt(bossName, difficulty)
    if not bossName then
        return false
    end
    
    self.current_attempt = {
        boss_name = bossName,
        difficulty = difficulty or "Normal",
        start_time = GetTime(),
        end_time = nil,
        duration = 0,
        success = false,
        total_damage = 0,
        total_healing = 0,
        total_deaths = 0,
        player_stats = {},
        timestamp = date("%Y-%m-%d %H:%M:%S"),
    }
    
    self:Log("Started attempt: " .. bossName .. " (" .. (difficulty or "Normal") .. ")")
    return true
end

function EncounterComparisonEngine:EndAttempt(success, totalDamage, totalHealing, deaths)
    if not self.current_attempt then
        return false
    end
    
    self.current_attempt.end_time = GetTime()
    self.current_attempt.duration = self.current_attempt.end_time - self.current_attempt.start_time
    self.current_attempt.success = success or false
    self.current_attempt.total_damage = totalDamage or 0
    self.current_attempt.total_healing = totalHealing or 0
    self.current_attempt.total_deaths = deaths or 0
    
    -- Store attempt
    if #self.attempts >= self.config.max_attempts then
        table.remove(self.attempts, 1)  -- Remove oldest
    end
    
    table.insert(self.attempts, self.current_attempt)
    self:Log("Ended attempt: " .. self.current_attempt.boss_name .. " (" .. 
             (self.current_attempt.success and "SUCCESS" or "WIPE") .. ")")
    
    return true
end

function EncounterComparisonEngine:RecordPlayerStats(playerName, damage, healing, deaths, role)
    if not self.current_attempt or not playerName then
        return false
    end
    
    if not self.current_attempt.player_stats[playerName] then
        self.current_attempt.player_stats[playerName] = {
            name = playerName,
            damage = 0,
            healing = 0,
            deaths = 0,
            role = role or "Unknown",
        }
    end
    
    self.current_attempt.player_stats[playerName].damage = damage or 0
    self.current_attempt.player_stats[playerName].healing = healing or 0
    self.current_attempt.player_stats[playerName].deaths = deaths or 0
    
    return true
end

function EncounterComparisonEngine:GetAttemptByIndex(index)
    if index < 1 or index > #self.attempts then
        return nil
    end
    
    return self.attempts[index]
end

function EncounterComparisonEngine:GetAttemptsByBoss(bossName)
    local results = {}
    
    for _, attempt in ipairs(self.attempts) do
        if attempt.boss_name == bossName then
            table.insert(results, attempt)
        end
    end
    
    return results
end

function EncounterComparisonEngine:GetSuccessRate(bossName)
    local attempts = self:GetAttemptsByBoss(bossName)
    if #attempts == 0 then
        return 0
    end
    
    local successes = 0
    
    for _, attempt in ipairs(attempts) do
        if attempt.success then
            successes = successes + 1
        end
    end
    
    return (successes / #attempts) * 100
end

function EncounterComparisonEngine:GetAverageDuration(bossName)
    local attempts = self:GetAttemptsByBoss(bossName)
    if #attempts == 0 then
        return 0
    end
    
    local totalDuration = 0
    
    for _, attempt in ipairs(attempts) do
        totalDuration = totalDuration + attempt.duration
    end
    
    return totalDuration / #attempts
end

function EncounterComparisonEngine:GetBestAttempt(bossName)
    local attempts = self:GetAttemptsByBoss(bossName)
    if #attempts == 0 then
        return nil
    end
    
    local best = nil
    local maxDamage = 0
    
    for _, attempt in ipairs(attempts) do
        if attempt.total_damage > maxDamage then
            maxDamage = attempt.total_damage
            best = attempt
        end
    end
    
    return best
end

function EncounterComparisonEngine:GetWorstAttempt(bossName)
    local attempts = self:GetAttemptsByBoss(bossName)
    if #attempts == 0 then
        return nil
    end
    
    local worst = nil
    local minDamage = math.huge
    
    for _, attempt in ipairs(attempts) do
        if attempt.total_damage < minDamage then
            minDamage = attempt.total_damage
            worst = attempt
        end
    end
    
    return worst
end

function EncounterComparisonEngine:GetPlayerConsistency(bossName, playerName)
    local attempts = self:GetAttemptsByBoss(bossName)
    if #attempts == 0 then
        return 0, 0, 0  -- avg, min, max
    end
    
    local damages = {}
    
    for _, attempt in ipairs(attempts) do
        if attempt.player_stats[playerName] then
            table.insert(damages, attempt.player_stats[playerName].damage)
        end
    end
    
    if #damages == 0 then
        return 0, 0, 0
    end
    
    local sum = 0
    local min = math.huge
    local max = 0
    
    for _, damage in ipairs(damages) do
        sum = sum + damage
        if damage < min then min = damage end
        if damage > max then max = damage end
    end
    
    return sum / #damages, min, max
end

function EncounterComparisonEngine:GetDamageProgression(bossName)
    local attempts = self:GetAttemptsByBoss(bossName)
    if #attempts == 0 then
        return {}
    end
    
    local progression = {}
    
    for _, attempt in ipairs(attempts) do
        table.insert(progression, {
            timestamp = attempt.timestamp,
            duration = attempt.duration,
            total_damage = attempt.total_damage,
            success = attempt.success,
        })
    end
    
    return progression
end

function EncounterComparisonEngine:GetTopPerformers(bossName, limit)
    local attempts = self:GetAttemptsByBoss(bossName)
    if #attempts == 0 then
        return {}
    end
    
    limit = limit or 5
    local performers = {}
    
    for _, attempt in ipairs(attempts) do
        for playerName, stats in pairs(attempt.player_stats) do
            if not performers[playerName] then
                performers[playerName] = {
                    name = playerName,
                    total_damage = 0,
                    total_healing = 0,
                    appearance_count = 0,
                }
            end
            
            performers[playerName].total_damage = performers[playerName].total_damage + stats.damage
            performers[playerName].total_healing = performers[playerName].total_healing + stats.healing
            performers[playerName].appearance_count = performers[playerName].appearance_count + 1
        end
    end
    
    -- Sort by average damage
    local sorted = {}
    for _, stats in pairs(performers) do
        table.insert(sorted, stats)
    end
    
    table.sort(sorted, function(a, b)
        return (a.total_damage / a.appearance_count) > (b.total_damage / b.appearance_count)
    end)
    
    local results = {}
    for i = 1, math.min(limit, #sorted) do
        table.insert(results, sorted[i])
    end
    
    return results
end

function EncounterComparisonEngine:ClearOldAttempts(days)
    days = days or 7
    local cutoffTime = GetTime() - (days * 86400)
    local newAttempts = {}
    
    for _, attempt in ipairs(self.attempts) do
        if (attempt.end_time or attempt.start_time) > cutoffTime then
            table.insert(newAttempts, attempt)
        end
    end
    
    self.attempts = newAttempts
    self.db.attempts = newAttempts
    
    self:Log("Cleared attempts older than " .. days .. " days")
end

function EncounterComparisonEngine:GetStatus()
    local bossCount = {}
    
    for _, attempt in ipairs(self.attempts) do
        if not bossCount[attempt.boss_name] then
            bossCount[attempt.boss_name] = 0
        end
        bossCount[attempt.boss_name] = bossCount[attempt.boss_name] + 1
    end
    
    return {
        enabled = self.enabled,
        total_attempts = #self.attempts,
        bosses_tracked = bossCount,
        max_attempts = self.config.max_attempts,
    }
end

function EncounterComparisonEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[EncounterComparisonEngine] " .. message)
    else
        print("[EncounterComparisonEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_ENCOUNTER1 = "/encounter"
    SlashCmdList["ENCOUNTER"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "start" then
            local bossName = args or "Unknown Boss"
            EncounterComparisonEngine:StartAttempt(bossName)
            print("Encounter started: " .. bossName)
        elseif cmd == "end" then
            local success = string.find(args or "", "success") ~= nil
            EncounterComparisonEngine:EndAttempt(success, 0, 0, 0)
            print("Encounter ended: " .. (success and "SUCCESS" or "WIPE"))
        elseif cmd == "bosses" then
            local status = EncounterComparisonEngine:GetStatus()
            print("Boss Attempts:")
            for boss, count in pairs(status.bosses_tracked) do
                print("  " .. boss .. ": " .. count .. " attempts")
            end
        elseif cmd == "stats" then
            local status = EncounterComparisonEngine:GetStatus()
            print("Encounter Comparison:")
            print("  Total Attempts: " .. status.total_attempts)
            print("  Bosses Tracked: " .. table.getn(status.bosses_tracked))
        elseif cmd == "clear" then
            EncounterComparisonEngine.attempts = {}
            EncounterComparisonEngine.db.attempts = {}
            print("All encounter data cleared")
        else
            print("Encounter Commands:")
            print("  /encounter start <boss> - Start new attempt")
            print("  /encounter end [success] - End attempt")
            print("  /encounter bosses - List bosses")
            print("  /encounter stats - Show statistics")
            print("  /encounter clear - Clear all data")
        end
    end
end

return EncounterComparisonEngine
