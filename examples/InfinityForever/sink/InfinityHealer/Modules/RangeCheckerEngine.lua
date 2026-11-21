-- RangeCheckerEngine.lua - Calculate and display range to each player
-- Part of InfinityHealer addon suite
-- Maintains real-time distance calculations and range indicators

local RangeCheckerEngine = {}
RangeCheckerEngine.enabled = false
RangeCheckerEngine.db = nil
RangeCheckerEngine.player_ranges = {}
RangeCheckerEngine.range_cache = {}

-- Range bands for different spell types
RangeCheckerEngine.RANGE_BANDS = {
    MELEE = { min = 0, max = 5, color = "FF0000" },      -- Melee
    SHORT = { min = 5, max = 10, color = "FFA500" },     -- 10 yards
    MEDIUM = { min = 10, max = 25, color = "FFFF00" },   -- 25 yards
    LONG = { min = 25, max = 40, color = "00FF00" },     -- 40 yards (healing range)
    VERY_LONG = { min = 40, max = 100, color = "0000FF" },  -- 100 yards
    OUT_OF_RANGE = { min = 100, max = math.huge, color = "808080" },  -- Out of range
}

-- Configuration
RangeCheckerEngine.config = {
    enabled = true,
    update_interval = 0.5,
    cache_duration = 1,
    max_range = 100,
    calculate_los = true,  -- Calculate line of sight
    show_distance_numbers = true,
    healing_spell_range = 40,
}

function RangeCheckerEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.range_cache then
        self.db.range_cache = {}
    end
    
    self.range_cache = self.db.range_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function RangeCheckerEngine:CalculateDistance(unit1, unit2)
    if not unit1 or not unit2 then
        return nil
    end
    
    -- Get positions
    local x1, y1, map1 = GetPlayerMapPosition(unit1)
    local x2, y2, map2 = GetPlayerMapPosition(unit2)
    
    if not x1 or not y1 or not x2 or not y2 then
        return nil
    end
    
    -- Check if on same map
    if map1 ~= map2 then
        return math.huge  -- Different maps = out of range
    end
    
    -- Calculate distance
    local distance = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    
    -- Rough conversion from map coordinates to yards (100 yards ~= 1 map unit on some scales)
    -- This is a simplification; actual conversion varies by zone
    distance = distance * 100
    
    return distance
end

function RangeCheckerEngine:GetPlayerDistance(playerName)
    if not playerName or playerName == "" then
        return nil
    end
    
    -- Check cache
    local cached = self.range_cache[playerName]
    if cached and GetTime() - cached.timestamp < self.config.cache_duration then
        return cached.distance, cached.los, cached.timestamp
    end
    
    -- Calculate new distance
    local distance = self:CalculateDistance("player", playerName)
    
    -- Calculate LOS if configured
    local los = false
    if self.config.calculate_los and distance and distance < 100 then
        los = self:CalculateLineOfSight("player", playerName)
    end
    
    -- Cache result
    if distance then
        self.range_cache[playerName] = {
            distance = distance,
            los = los,
            timestamp = GetTime(),
        }
    end
    
    return distance, los
end

function RangeCheckerEngine:CalculateLineOfSight(unit1, unit2)
    if not unit1 or not unit2 then
        return false
    end
    
    -- Simplified LOS check - in production would use raycasting
    -- For now, assume LOS if on same map and not behind walls
    -- This would need actual implementation with collision detection
    
    return true  -- Placeholder
end

function RangeCheckerEngine:GetRangeBand(distance)
    if not distance then
        return self.RANGE_BANDS.OUT_OF_RANGE
    end
    
    if distance <= 5 then
        return self.RANGE_BANDS.MELEE
    elseif distance <= 10 then
        return self.RANGE_BANDS.SHORT
    elseif distance <= 25 then
        return self.RANGE_BANDS.MEDIUM
    elseif distance <= 40 then
        return self.RANGE_BANDS.LONG
    elseif distance <= 100 then
        return self.RANGE_BANDS.VERY_LONG
    else
        return self.RANGE_BANDS.OUT_OF_RANGE
    end
end

function RangeCheckerEngine:IsInHealingRange(playerName)
    local distance = self:GetPlayerDistance(playerName)
    
    if not distance then
        return false
    end
    
    return distance <= self.config.healing_spell_range
end

function RangeCheckerEngine:IsInRangeForSpell(playerName, spellName)
    local distance = self:GetPlayerDistance(playerName)
    
    if not distance then
        return false
    end
    
    local maxRange = self:GetSpellMaxRange(spellName)
    if not maxRange then
        return true  -- Unknown spell, assume in range
    end
    
    return distance <= maxRange
end

function RangeCheckerEngine:GetSpellMaxRange(spellName)
    -- Spell range database
    local spellRanges = {
        -- Healing spells
        ["Flash Heal"] = 40,
        ["Heal"] = 40,
        ["Greater Heal"] = 40,
        ["Renew"] = 40,
        ["Power Word: Shield"] = 40,
        ["Regrowth"] = 40,
        ["Healing Touch"] = 40,
        ["Rejuvenation"] = 40,
        ["Lifebloom"] = 40,
        ["Wild Growth"] = 40,
        
        -- Buff/Support
        ["Beacon of Light"] = 60,
        ["Power Infusion"] = 40,
        ["Pain Suppression"] = 40,
        
        -- Damage spells
        ["Fireball"] = 40,
        ["Shadowbolt"] = 40,
        ["Holy Fire"] = 40,
    }
    
    return spellRanges[spellName]
end

function RangeCheckerEngine:GetRangeStatus(playerName)
    if not playerName then
        return nil
    end
    
    local distance, los = self:GetPlayerDistance(playerName)
    local rangeBand = self:GetRangeBand(distance)
    local inHealing = self:IsInHealingRange(playerName)
    
    return {
        player = playerName,
        distance = distance,
        distance_formatted = distance and string.format("%.1f", distance) or "?",
        range_band = rangeBand,
        range_name = self:GetRangeName(rangeBand),
        in_healing_range = inHealing,
        line_of_sight = los,
        can_heal = inHealing and los,
    }
end

function RangeCheckerEngine:GetRangeName(rangeBand)
    if rangeBand == self.RANGE_BANDS.MELEE then
        return "Melee"
    elseif rangeBand == self.RANGE_BANDS.SHORT then
        return "Close"
    elseif rangeBand == self.RANGE_BANDS.MEDIUM then
        return "Medium"
    elseif rangeBand == self.RANGE_BANDS.LONG then
        return "Long"
    elseif rangeBand == self.RANGE_BANDS.VERY_LONG then
        return "Very Long"
    else
        return "Out of Range"
    end
end

function RangeCheckerEngine:GetRaidDistances()
    local distances = {}
    
    -- Get raid members
    local raidSize = GetNumRaidMembers()
    if raidSize == 0 then
        raidSize = GetNumPartyMembers() + 1  -- Party mode
    end
    
    for i = 1, raidSize do
        local name = UnitName("raid" .. i)
        if name then
            local distance = self:GetPlayerDistance(name)
            if distance then
                table.insert(distances, {
                    player = name,
                    distance = distance,
                    range_band = self:GetRangeBand(distance),
                })
            end
        end
    end
    
    return distances
end

function RangeCheckerEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function RangeCheckerEngine:GetStatus()
    local cacheSize = 0
    for _ in pairs(self.range_cache) do
        cacheSize = cacheSize + 1
    end
    
    return {
        enabled = self.enabled,
        cached_players = cacheSize,
        cache_duration = self.config.cache_duration,
        healing_range = self.config.healing_spell_range,
    }
end

function RangeCheckerEngine:ClearCache()
    self.range_cache = {}
    self:Log("Cache cleared")
end

function RangeCheckerEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[RangeCheckerEngine] " .. message)
    else
        print("[RangeCheckerEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_RANGECHK1 = "/rangechk"
    SlashCmdList["RANGECHK"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            if args and args ~= "" then
                local status = RangeCheckerEngine:GetRangeStatus(args)
                if status then
                    print("Range to " .. args .. ":")
                    print("  Distance: " .. status.distance_formatted .. " yards")
                    print("  Band: " .. status.range_name)
                    print("  Healing Range: " .. (status.in_healing_range and "YES" or "NO"))
                    print("  Line of Sight: " .. (status.line_of_sight and "YES" or "NO"))
                    print("  Can Heal: " .. (status.can_heal and "YES ✓" or "NO ✗"))
                else
                    print("No range data for " .. args)
                end
            else
                print("Usage: /rangechk check <player>")
            end
        elseif cmd == "raid" then
            local distances = RangeCheckerEngine:GetRaidDistances()
            if #distances > 0 then
                print("Raid range check:")
                for _, data in ipairs(distances) do
                    print(string.format("  %s: %.1f yards (%s)", 
                        data.player, data.distance, RangeCheckerEngine:GetRangeName(data.range_band)))
                end
            else
                print("No raid members found")
            end
        elseif cmd == "status" then
            local status = RangeCheckerEngine:GetStatus()
            print("Range Checker Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "clear" then
            RangeCheckerEngine:ClearCache()
            print("Range cache cleared")
        else
            print("Range Checker Commands:")
            print("  /rangechk check <player> - Check range to player")
            print("  /rangechk raid - Check range to all raid members")
            print("  /rangechk status - Show system status")
            print("  /rangechk clear - Clear range cache")
        end
    end
end

return RangeCheckerEngine
