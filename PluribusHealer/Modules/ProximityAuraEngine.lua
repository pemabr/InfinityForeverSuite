-- ProximityAuraEngine.lua - Track and display proximity auras for group members
-- Part of PluribusHealer addon suite
-- Shows which party members are nearby and in range

local ProximityAuraEngine = {}
ProximityAuraEngine.enabled = false
ProximityAuraEngine.db = nil
ProximityAuraEngine.proximity_data = {}

-- Configuration
ProximityAuraEngine.config = {
    enabled = true,
    check_frequency = 1,  -- Check every 1 second
    max_range = 50,  -- Yards
    show_indicators = true,
    highlight_out_of_range = true,
}

-- Proximity aura definitions
ProximityAuraEngine.proximity_auras = {
    BATTLE_SHOUT = {
        spell_id = 6673,
        range = 100,
        name = "Battle Shout",
        class = "WARRIOR",
    },
    COMMANDING_SHOUT = {
        spell_id = 469,
        range = 100,
        name = "Commanding Shout",
        class = "WARRIOR",
    },
    PRAYER_OF_FORTITUDE = {
        spell_id = 1243,
        range = 30,
        name = "Prayer of Fortitude",
        class = "PRIEST",
    },
    PRAYER_OF_SPIRIT = {
        spell_id = 27681,
        range = 30,
        name = "Prayer of Spirit",
        class = "PRIEST",
    },
    BLESSING_OF_KINGS = {
        spell_id = 20217,
        range = 100,
        name = "Blessing of Kings",
        class = "PALADIN",
    },
    BLESSING_OF_MIGHT = {
        spell_id = 19740,
        range = 100,
        name = "Blessing of Might",
        class = "PALADIN",
    },
    MARK_OF_THE_WILD = {
        spell_id = 24932,
        range = 30,
        name = "Mark of the Wild",
        class = "DRUID",
    },
    STRENGTH_OF_EARTH = {
        spell_id = 25528,
        range = 30,
        name = "Strength of Earth",
        class = "SHAMAN",
    },
}

function ProximityAuraEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.proximity_tracking then
        self.db.proximity_tracking = {}
    end
    
    if not self.db.aura_tracking then
        self.db.aura_tracking = {}
    end
    
    self.proximity_data = self.db.proximity_tracking
    self.enabled = true
    
    self:Log("Initialized with " .. self:CountProximityAuras() .. " proximity auras")
end

function ProximityAuraEngine:CountProximityAuras()
    local count = 0
    
    for _ in pairs(self.proximity_auras) do
        count = count + 1
    end
    
    return count
end

function ProximityAuraEngine:CheckProximity(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    
    -- Get unit distance
    local distance = self:GetDistance(unit)
    
    if not distance then
        return false
    end
    
    if distance <= self.config.max_range then
        return true
    end
    
    return false
end

function ProximityAuraEngine:GetDistance(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    
    -- Get positions
    local unitX, unitY = UnitPosition(unit)
    local playerX, playerY = UnitPosition("player")
    
    if not unitX or not playerX then
        return nil
    end
    
    -- Calculate distance
    local dx = unitX - playerX
    local dy = unitY - playerY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    return distance
end

function ProximityAuraEngine:GetPlayerProximityAuras(unit)
    if not unit or not UnitExists(unit) then
        return {}
    end
    
    local auras = {}
    local unitClass = select(2, UnitClass(unit))
    
    for auraName, auraData in pairs(self.proximity_auras) do
        if auraData.class == unitClass then
            -- Check if unit has this buff
            local hasAura = false
            
            for i = 1, 32 do
                local name, icon, count, dispelType, duration, expirationTime = PluribusUtils:GetUnitAura(unit, i, "HELPFUL")
                
                if not name then
                    break
                end
                
                if name == auraData.name then
                    hasAura = true
                    table.insert(auras, {
                        name = name,
                        icon = icon,
                        duration = duration,
                        expiration = expirationTime,
                        range = auraData.range,
                    })
                    break
                end
            end
        end
    end
    
    return auras
end

function ProximityAuraEngine:GetGroupProximity()
    local groupData = {}
    
    for i = 1, GetNumGroupMembers() do
        local unit = "party" .. i
        
        if UnitExists(unit) then
            local name = UnitName(unit)
            local distance = self:GetDistance(unit)
            local inRange = self:CheckProximity(unit)
            
            if name and distance then
                table.insert(groupData, {
                    unit = unit,
                    name = name,
                    distance = math.floor(distance),
                    in_range = inRange,
                    auras = self:GetPlayerProximityAuras(unit),
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(groupData, function(a, b) return a.distance < b.distance end)
    
    return groupData
end

function ProximityAuraEngine:IsPlayerInAuraRange(unit, maxRange)
    if not unit or not UnitExists(unit) or not maxRange then
        return false
    end
    
    local distance = self:GetDistance(unit)
    
    if not distance then
        return false
    end
    
    return distance <= maxRange
end

function ProximityAuraEngine:GetMembersWithinRange(maxRange)
    if not maxRange or maxRange <= 0 then
        return {}
    end
    
    local members = {}
    
    for i = 1, GetNumGroupMembers() do
        local unit = "party" .. i
        
        if UnitExists(unit) and self:IsPlayerInAuraRange(unit, maxRange) then
            table.insert(members, {
                unit = unit,
                name = UnitName(unit),
                distance = math.floor(self:GetDistance(unit) or 0),
            })
        end
    end
    
    return members
end

function ProximityAuraEngine:SetMaxRange(range)
    if range and range > 0 and range <= 100 then
        self.config.max_range = range
        self:Log("Max range set to: " .. range)
        return true
    end
    return false
end

function ProximityAuraEngine:SetCheckFrequency(frequency)
    if frequency and frequency > 0 and frequency <= 10 then
        self.config.check_frequency = frequency
        self:Log("Check frequency set to: " .. frequency .. "s")
        return true
    end
    return false
end

function ProximityAuraEngine:GetStatus()
    local groupData = self:GetGroupProximity()
    local inRangeCount = 0
    
    for _, member in ipairs(groupData) do
        if member.in_range then
            inRangeCount = inRangeCount + 1
        end
    end
    
    return {
        enabled = self.enabled,
        max_range = self.config.max_range,
        group_size = #groupData,
        in_range = inRangeCount,
        out_of_range = #groupData - inRangeCount,
        check_frequency = self.config.check_frequency,
    }
end

function ProximityAuraEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[ProximityAuraEngine] " .. message)
    else
        print("[ProximityAuraEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_PROXIMITY1 = "/proximity"
    SlashCmdList["PROXIMITY"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            local groupData = ProximityAuraEngine:GetGroupProximity()
            print("Group Proximity (" .. #groupData .. " members):")
            for _, member in ipairs(groupData) do
                local status = member.in_range and "✓" or "✗"
                print("  [" .. status .. "] " .. member.name .. " - " .. member.distance .. "y")
                if #member.auras > 0 then
                    for _, aura in ipairs(member.auras) do
                        print("      " .. aura.name .. " (range: " .. aura.range .. "y)")
                    end
                end
            end
        elseif cmd == "range" then
            if args and tonumber(args) then
                ProximityAuraEngine:SetMaxRange(tonumber(args))
                print("Max range: " .. args .. " yards")
            else
                print("Usage: /proximity range <yards>")
            end
        elseif cmd == "frequency" then
            if args and tonumber(args) then
                ProximityAuraEngine:SetCheckFrequency(tonumber(args))
                print("Check frequency: " .. args .. " seconds")
            else
                print("Usage: /proximity frequency <seconds>")
            end
        elseif cmd == "auras" then
            local auraCount = ProximityAuraEngine:CountProximityAuras()
            print("Tracked Proximity Auras (" .. auraCount .. "):")
            for auraName, auraData in pairs(ProximityAuraEngine.proximity_auras) do
                print("  " .. auraData.name .. " (" .. auraData.class .. ") - Range: " .. auraData.range .. "y")
            end
        elseif cmd == "status" then
            local status = ProximityAuraEngine:GetStatus()
            print("Proximity Aura Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Proximity Aura Commands:")
            print("  /proximity check - Show group proximity")
            print("  /proximity range <yards> - Set max range")
            print("  /proximity frequency <seconds> - Set check frequency")
            print("  /proximity auras - List tracked auras")
            print("  /proximity status - Show system status")
        end
    end
end

return ProximityAuraEngine
