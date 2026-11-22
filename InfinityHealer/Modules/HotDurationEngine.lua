-- HotDurationEngine.lua - Display remaining time on HoT effects
-- Part of InfinityHealer addon suite
-- Tracks and displays heal-over-time durations for all players

local HotDurationEngine = {}
HotDurationEngine.enabled = false
HotDurationEngine.db = nil
HotDurationEngine.hot_cache = {}
HotDurationEngine.hot_database = {}

-- Configuration
HotDurationEngine.config = {
    enabled = true,
    show_hots = true,
    show_duration = true,
    duration_format = "numeric",  -- numeric, percent, both
    update_frequency = 0.5,
    max_hots_per_player = 5,
    highlight_critical = true,  -- Show when <5 seconds left
    critical_threshold = 5,
}

-- HoT spell database (spell name -> base duration in seconds)
HotDurationEngine.hot_database = {
    -- Druid
    ["Rejuvenation"] = 12,
    ["Rejuvenation (Germination)"] = 12,
    ["Lifebloom"] = 7,
    ["Wild Growth"] = 7,
    ["Regrowth"] = 21,
    
    -- Priest
    ["Renew"] = 15,
    ["Power Word: Shield"] = 15,
    
    -- Shaman
    ["Chain Heal"] = 0,  -- Instant
    ["Riptide"] = 10,
    ["Healing Stream Totem"] = 120,
    ["Mana Tide Totem"] = 12,
    
    -- Paladin
    ["Sacred Shield"] = 10,
    ["Beacon of Light"] = 60,
    ["Flash of Light"] = 0,
    ["Holy Light"] = 0,
    
    -- Monk (if expansion)
    ["Renewing Mist"] = 8,
    ["Enveloping Mist"] = 6,
}

function HotDurationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.hot_cache then
        self.db.hot_cache = {}
    end
    
    self.hot_cache = self.db.hot_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function HotDurationEngine:RegisterHoT(unitID, spellName, duration)
    if not unitID or not spellName then
        return false
    end
    
    if not self.hot_cache[unitID] then
        self.hot_cache[unitID] = {}
    end
    
    if not duration then
        duration = self.hot_database[spellName] or 10
    end
    
    -- Add to cache
    self.hot_cache[unitID][spellName] = {
        spell_name = spellName,
        duration = duration,
        applied_at = GetTime(),
        expires_at = GetTime() + duration,
    }
    
    return true
end

function HotDurationEngine:GetPlayerHoTs(unitID)
    if not unitID or not UnitExists(unitID) then
        return nil
    end
    
    if not self.hot_cache[unitID] then
        return {}
    end
    
    local hots = {}
    local currentTime = GetTime()
    
    -- Filter out expired HoTs
    for spellName, hotData in pairs(self.hot_cache[unitID]) do
        if currentTime < hotData.expires_at then
            local remaining = hotData.expires_at - currentTime
            table.insert(hots, {
                spell_name = spellName,
                duration = hotData.duration,
                remaining = remaining,
                percent_remaining = (remaining / hotData.duration) * 100,
                is_critical = remaining < self.config.critical_threshold,
            })
        else
            self.hot_cache[unitID][spellName] = nil
        end
    end
    
    -- Sort by remaining time (soonest first)
    table.sort(hots, function(a, b)
        return a.remaining < b.remaining
    end)
    
    return hots
end

function HotDurationEngine:GetHoTStatus(unitID, spellName)
    if not unitID or not spellName then
        return nil
    end
    
    if not self.hot_cache[unitID] or not self.hot_cache[unitID][spellName] then
        return nil
    end
    
    local hotData = self.hot_cache[unitID][spellName]
    local currentTime = GetTime()
    local remaining = hotData.expires_at - currentTime
    
    if remaining <= 0 then
        self.hot_cache[unitID][spellName] = nil
        return nil
    end
    
    return {
        spell_name = spellName,
        duration = hotData.duration,
        remaining = remaining,
        percent_remaining = (remaining / hotData.duration) * 100,
        is_critical = remaining < self.config.critical_threshold,
    }
end

function HotDurationEngine:FormatHotText(hotStatus)
    if not hotStatus then
        return ""
    end
    
    if self.config.duration_format == "numeric" then
        if hotStatus.remaining >= 1 then
            return math.floor(hotStatus.remaining) .. "s"
        else
            return string.format("%.1f", hotStatus.remaining) .. "s"
        end
    elseif self.config.duration_format == "percent" then
        return math.floor(hotStatus.percent_remaining) .. "%"
    elseif self.config.duration_format == "both" then
        if hotStatus.remaining >= 1 then
            return math.floor(hotStatus.remaining) .. "s (" .. math.floor(hotStatus.percent_remaining) .. "%)"
        else
            return string.format("%.1f", hotStatus.remaining) .. "s (" .. math.floor(hotStatus.percent_remaining) .. "%)"
        end
    end
    
    return ""
end

function HotDurationEngine:GetCriticalHoTs(unitID)
    if not unitID then
        return {}
    end
    
    local hots = self:GetPlayerHoTs(unitID)
    local critical = {}
    
    for _, hot in ipairs(hots) do
        if hot.is_critical then
            table.insert(critical, hot)
        end
    end
    
    return critical
end

function HotDurationEngine:GetHoTSummary(unitID)
    if not unitID then
        return nil
    end
    
    local hots = self:GetPlayerHoTs(unitID)
    
    if #hots == 0 then
        return {
            unit = unitID,
            hot_count = 0,
            total_healing = 0,
            critical_count = 0,
        }
    end
    
    local totalHealing = 0
    local criticalCount = 0
    
    for _, hot in ipairs(hots) do
        if hot.is_critical then
            criticalCount = criticalCount + 1
        end
    end
    
    return {
        unit = unitID,
        hot_count = #hots,
        total_healing = totalHealing,
        critical_count = criticalCount,
        hots = hots,
    }
end

function HotDurationEngine:ClearExpiredHoTs()
    local currentTime = GetTime()
    
    for unitID, hots in pairs(self.hot_cache) do
        for spellName, hotData in pairs(hots) do
            if currentTime >= hotData.expires_at then
                hots[spellName] = nil
            end
        end
        
        -- Remove unit if no HoTs left
        if next(hots) == nil then
            self.hot_cache[unitID] = nil
        end
    end
end

function HotDurationEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function HotDurationEngine:GetStatus()
    local totalHoTs = 0
    local unitCount = 0
    
    for unitID, hots in pairs(self.hot_cache) do
        unitCount = unitCount + 1
        for _ in pairs(hots) do
            totalHoTs = totalHoTs + 1
        end
    end
    
    return {
        enabled = self.enabled,
        tracking_units = unitCount,
        total_hots = totalHoTs,
        duration_format = self.config.duration_format,
    }
end

function HotDurationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[HotDurationEngine] " .. message)
    else
        print("[HotDurationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HOTDURATION1 = "/hotduration"
    SlashCmdList["HOTDURATION"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            if args and args ~= "" then
                local summary = HotDurationEngine:GetHoTSummary(args)
                if summary and summary.hot_count > 0 then
                    print("HoTs on " .. args .. " (" .. summary.hot_count .. "):")
                    for _, hot in ipairs(summary.hots) do
                        local text = HotDurationEngine:FormatHotText(hot)
                        print("  " .. hot.spell_name .. ": " .. text)
                    end
                else
                    print("No HoTs on " .. args)
                end
            else
                print("Usage: /hotduration check <unit>")
            end
        elseif cmd == "list" then
            local unitCount = 0
            for unitID, hots in pairs(HotDurationEngine.hot_cache) do
                for _ in pairs(hots) do
                    unitCount = unitCount + 1
                end
            end
            if unitCount == 0 then
                print("No HoTs tracked")
            else
                print("Tracked HoTs:")
                for unitID, hots in pairs(HotDurationEngine.hot_cache) do
                    if next(hots) ~= nil then
                        print("  " .. unitID .. " (" .. table.getn(hots) .. " HoTs)")
                    end
                end
            end
        elseif cmd == "format" then
            if args and args ~= "" then
                if args == "numeric" or args == "percent" or args == "both" then
                    HotDurationEngine:SetConfig("duration_format", args)
                    print("HoT format: " .. args)
                else
                    print("Usage: /hotduration format <numeric|percent|both>")
                end
            end
        elseif cmd == "status" then
            local status = HotDurationEngine:GetStatus()
            print("HoT Duration Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("HoT Duration Commands:")
            print("  /hotduration check <unit> - Check HoTs on unit")
            print("  /hotduration list - List all tracked HoTs")
            print("  /hotduration format <numeric|percent|both> - Set format")
            print("  /hotduration status - Show system status")
        end
    end
end

return HotDurationEngine
