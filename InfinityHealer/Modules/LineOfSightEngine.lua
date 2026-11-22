-- Range reporting; line of sight is not exposed by the client API.

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
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    self.los_cache = {}
    self.enabled = true
    
    self:Log("Initialized")
end

function LineOfSightEngine:CheckLineOfSight(source, target)
    return nil
end

function LineOfSightEngine:PerformLosCheck(source, target)
    return nil
end

function LineOfSightEngine:IsInLineOfSight(unitID)
    return nil
end

function LineOfSightEngine:CanCastSpellOn(spellName, unitID)
    return nil
end

local function Public(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

function LineOfSightEngine:GetLosStatus(unitID)
    if _G.issecretvalue and _G.issecretvalue(unitID) then return nil end
    if type(unitID) ~= "string" or unitID == "" or type(_G.UnitExists) ~= "function" then return nil end
    local exists = Public(UnitExists(unitID))
    if exists ~= true and exists ~= 1 then return nil end
    local name = _G.UnitName and Public(UnitName(unitID))
    if type(name) ~= "string" then name = unitID end
    local range, checked
    if _G.UnitDistanceSquared then
        range, checked = UnitDistanceSquared(unitID)
        range, checked = Public(range), Public(checked)
    end
    if type(range) ~= "number" or range ~= range or range < 0 or range >= math.huge
        or (checked ~= true and checked ~= 1) then
        range = nil
    end
    local inRange
    if range then inRange = range <= (40 * 40) end
    return {
        unit = unitID,
        name = name,
        in_range = inRange,
        range_squared = range,
        last_check = GetTime(),
    }
end

function LineOfSightEngine:GetLosReport()
    if not _G.GetNumGroupMembers or not _G.IsInRaid then return nil end
    local count, inRaid = GetNumGroupMembers(), IsInRaid()
    if _G.issecretvalue and (_G.issecretvalue(count) or _G.issecretvalue(inRaid)) then return nil end
    if type(count) ~= "number" or count < 0 or count >= math.huge or count ~= math.floor(count) then return nil end
    if inRaid == nil then inRaid = false elseif inRaid == 1 then inRaid = true end
    if type(inRaid) ~= "boolean" then return nil end
    local report = {
        total_members = 0,
        in_range = 0,
        out_of_range = 0,
        unknown_range = 0,
        unavailable_members = 0,
        members = {},
    }
    local function Add(unitID)
        local status = self:GetLosStatus(unitID)
        if status then
            report.members[#report.members + 1] = status
            report.total_members = report.total_members + 1
            if status.in_range == true then report.in_range = report.in_range + 1
            elseif status.in_range == false then report.out_of_range = report.out_of_range + 1
            else report.unknown_range = report.unknown_range + 1 end
        else
            report.unavailable_members = report.unavailable_members + 1
        end
    end
    if inRaid then
        for i = 1, count do Add("raid" .. i) end
    else
        Add("player")
        for i = 1, math.max(0, count - 1) do Add("party" .. i) end
    end
    return report
end

function LineOfSightEngine:GetBlockedMembers()
    return nil
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
        line_of_sight_available = false,
        cache_size = cacheSize,
        cache_enabled = false,
        cache_duration = self.config.cache_duration,
    }
end

function LineOfSightEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[LineOfSightEngine] " .. message)
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
                    print("  Line of Sight and castability: unavailable")
                    print("  Within 40 yards: " .. (status.in_range == nil and "unknown" or (status.in_range and "yes" or "no")))
                else
                    print("Unit unavailable or not found: " .. args)
                end
            else
                print("Usage: /loscheck check <unit>")
            end
        elseif cmd == "report" then
            local report = LineOfSightEngine:GetLosReport()
            if not report then
                print("Group roster unavailable.")
            else
                print("40-yard range report (line of sight unavailable):")
                print("  Total: " .. report.total_members)
                print("  In range: " .. report.in_range)
                print("  Out of range: " .. report.out_of_range)
                print("  Unknown range: " .. report.unknown_range)
                print("  Unavailable members: " .. report.unavailable_members)
            end
        elseif cmd == "blocked" then
            print("Blocked line of sight cannot be determined by this client API.")
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
            print("  /loscheck check <unit> - Check 40-yard range")
            print("  /loscheck report - Show group range report")
            print("  /loscheck blocked - Explain LoS availability")
            print("  /loscheck clear - Clear cache")
            print("  /loscheck status - Show system status")
        end
    end
end

return LineOfSightEngine
