-- LineOfSightEngine.lua - Calculate and display line of sight status
-- Part of PluribusHealer addon suite
-- Checks if targets are blocked by obstacles

local LineOfSightEngine = {}
LineOfSightEngine.enabled = false
LineOfSightEngine.db = nil
LineOfSightEngine.los_cache = {}

-- Configuration
LineOfSightEngine.config = {
    enabled = true,
    cache_los = true,
    cache_duration = 2,
    check_interval = 1,
    highlight_blocked = true,
    show_los_indicators = true,
}

function LineOfSightEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.los_cache then
        self.db.los_cache = {}
    end
    
    self.los_cache = self.db.los_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function LineOfSightEngine:CheckLineOfSight(source, target)
    if not source or not target then
        return nil
    end
    
    -- Check cache
    local cacheKey = source .. ">" .. target
    local cached = self.los_cache[cacheKey]
    
    if cached and GetTime() - cached.timestamp < self.config.cache_duration then
        return cached.los
    end
    
    -- Perform LoS check
    local los = self:PerformLosCheck(source, target)
    
    -- Cache result
    self.los_cache[cacheKey] = {
        los = los,
        timestamp = GetTime(),
    }
    
    return los
end

function LineOfSightEngine:PerformLosCheck(source, target)
    if not source or not target then
        return false
    end
    
    -- Get positions
    local sourceX, sourceY, sourceZ = GetPlayerMapPosition(source)
    local targetX, targetY, targetZ = GetPlayerMapPosition(target)
    
    if not sourceX or not targetX then
        return true  -- Assume in LoS if no position data
    end
    
    -- Simple line-of-sight check using map positions
    -- In production, would use raycasting against terrain data
    
    -- For now, check if on same horizontal level (within reasonable height)
    local heightDiff = math.abs((sourceZ or 0) - (targetZ or 0))
    
    if heightDiff > 10 then
        -- Likely blocked by terrain if significant height difference
        return false
    end
    
    return true  -- Simplified check
end

function LineOfSightEngine:IsInLineOfSight(unitID)
    if not unitID then
        return false
    end
    
    local playerName = UnitName("player")
    local targetName = UnitName(unitID)
    
    if not playerName or not targetName then
        return false
    end
    
    return self:CheckLineOfSight(playerName, targetName)
end

function LineOfSightEngine:CanCastSpellOn(spellName, unitID)
    if not spellName or not unitID then
        return false
    end
    
    -- Check range
    local range = UnitDistanceSquared(unitID)
    if not range then
        return false
    end
    
    -- Rough range check (40 yards squared = 1600 distance units)
    local maxRangeSquared = 40 * 40
    if range > maxRangeSquared then
        return false
    end
    
    -- Check LoS
    return self:IsInLineOfSight(unitID)
end

function LineOfSightEngine:GetLosStatus(unitID)
    if not unitID then
        return nil
    end
    
    local name = UnitName(unitID)
    local los = self:IsInLineOfSight(unitID)
    local range = UnitDistanceSquared(unitID)
    local inRange = range and range <= (40 * 40)
    
    return {
        unit = unitID,
        name = name,
        line_of_sight = los,
        in_range = inRange,
        can_cast = los and inRange,
        range_squared = range,
        last_check = GetTime(),
    }
end

function LineOfSightEngine:GetLosReport()
    local raidSize = GetNumRaidMembers()
    if raidSize == 0 then
        raidSize = GetNumPartyMembers()
    end
    
    local report = {
        total_members = raidSize,
        in_los = 0,
        blocked = 0,
        out_of_range = 0,
        members = {},
    }
    
    for i = 1, raidSize do
        local unitID = GetNumRaidMembers() > 0 and "raid" .. i or "party" .. i
        
        if UnitExists(unitID) then
            local status = self:GetLosStatus(unitID)
            
            if status then
                table.insert(report.members, status)
                
                if status.line_of_sight and status.in_range then
                    report.in_los = report.in_los + 1
                elseif not status.line_of_sight then
                    report.blocked = report.blocked + 1
                else
                    report.out_of_range = report.out_of_range + 1
                end
            end
        end
    end
    
    return report
end

function LineOfSightEngine:GetBlockedMembers()
    local blocked = {}
    
    local report = self:GetLosReport()
    
    for _, member in ipairs(report.members) do
        if not member.line_of_sight and member.in_range then
            table.insert(blocked, member)
        end
    end
    
    return blocked
end

function LineOfSightEngine:InvalidateCache(unitID)
    if unitID then
        -- Invalidate specific cache entries
        local pattern = unitID:gsub("([^%w])", "%%%1")
        
        for key in pairs(self.los_cache) do
            if key:match(pattern) then
                self.los_cache[key] = nil
            end
        end
    else
        -- Clear entire cache
        self.los_cache = {}
    end
end

function LineOfSightEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function LineOfSightEngine:GetStatus()
    local cacheSize = 0
    for _ in pairs(self.los_cache) do
        cacheSize = cacheSize + 1
    end
    
    return {
        enabled = self.enabled,
        cache_size = cacheSize,
        cache_enabled = self.config.cache_los,
        cache_duration = self.config.cache_duration,
    }
end

function LineOfSightEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[LineOfSightEngine] " .. message)
    else
        print("[LineOfSightEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_LOSCHECK1 = "/loscheck"
    SlashCmdList["LOSCHECK"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            if args and args ~= "" then
                local status = LineOfSightEngine:GetLosStatus(args)
                if status then
                    print("LoS Check for " .. status.name .. ":")
                    print("  Line of Sight: " .. (status.line_of_sight and "YES" or "NO"))
                    print("  In Range: " .. (status.in_range and "YES" or "NO"))
                    print("  Can Cast: " .. (status.can_cast and "YES ✓" or "NO ✗"))
                else
                    print("No unit found: " .. args)
                end
            else
                print("Usage: /loscheck check <unit>")
            end
        elseif cmd == "report" then
            local report = LineOfSightEngine:GetLosReport()
            print("LoS Report:")
            print("  Total: " .. report.total_members)
            print("  In LoS: " .. report.in_los)
            print("  Blocked: " .. report.blocked)
            print("  Out of Range: " .. report.out_of_range)
        elseif cmd == "blocked" then
            local blocked = LineOfSightEngine:GetBlockedMembers()
            if #blocked > 0 then
                print("Blocked Members (" .. #blocked .. "):")
                for _, member in ipairs(blocked) do
                    print("  " .. member.name)
                end
            else
                print("No blocked members")
            end
        elseif cmd == "clear" then
            LineOfSightEngine:InvalidateCache()
            print("LoS cache cleared")
        elseif cmd == "status" then
            local status = LineOfSightEngine:GetStatus()
            print("LoS Engine Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Line of Sight Commands:")
            print("  /loscheck check <unit> - Check LoS to unit")
            print("  /loscheck report - Show full report")
            print("  /loscheck blocked - Show blocked members")
            print("  /loscheck clear - Clear cache")
            print("  /loscheck status - Show system status")
        end
    end
end

return LineOfSightEngine
