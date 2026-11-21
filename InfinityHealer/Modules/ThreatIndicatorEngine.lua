-- ThreatIndicatorEngine.lua - Display threat/aggro levels
-- Part of InfinityHealer addon suite
-- Shows which players have aggro and threat level intensity

local ThreatIndicatorEngine = {}
ThreatIndicatorEngine.enabled = false
ThreatIndicatorEngine.db = nil
ThreatIndicatorEngine.player_threat = {}

-- Configuration
ThreatIndicatorEngine.config = {
    enabled = true,
    show_threat_numbers = true,
    show_threat_colors = true,
    update_interval = 1,
    threat_polling = true,
    highlight_tank = true,
}

function ThreatIndicatorEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.threat_data then
        self.db.threat_data = {}
    end
    
    self.player_threat = self.db.threat_data
    self.enabled = true
    
    self:Log("Initialized")
end

function ThreatIndicatorEngine:GetThreatStatus(playerName)
    if not playerName then
        return nil
    end
    
    -- Determine threat level
    -- In WoW Classic, threat is binary: has threat or doesn't
    -- In retail, threat has percentages
    
    local threat = UnitThreatSituation("player", playerName)
    
    if threat == nil then
        return {
            player = playerName,
            has_threat = false,
            threat_percent = 0,
            threat_level = "none",
            color = { r = 0.5, g = 0.5, b = 0.5 },
        }
    end
    
    -- Determine threat level
    local threatLevel = "none"
    local threatColor = { r = 0.5, g = 0.5, b = 0.5 }
    local threatPercent = 0
    
    if threat == 0 then
        threatLevel = "none"
        threatColor = { r = 0.5, g = 0.5, b = 0.5 }
    elseif threat == 1 then
        threatLevel = "low"
        threatColor = { r = 1, g = 1, b = 0 }  -- Yellow
        threatPercent = 33
    elseif threat == 2 then
        threatLevel = "medium"
        threatColor = { r = 1, g = 0.5, b = 0 }  -- Orange
        threatPercent = 66
    elseif threat == 3 then
        threatLevel = "high"
        threatColor = { r = 1, g = 0, b = 0 }  -- Red
        threatPercent = 100
    end
    
    return {
        player = playerName,
        has_threat = threat > 0,
        threat_percent = threatPercent,
        threat_level = threatLevel,
        threat_code = threat,
        color = threatColor,
        timestamp = GetTime(),
    }
end

function ThreatIndicatorEngine:UpdateAllThreat()
    -- Update threat for all raid members
    local raidSize = GetNumRaidMembers()
    if raidSize == 0 then
        raidSize = GetNumPartyMembers()
    end
    
    for i = 1, raidSize do
        local unitID = "raid" .. i
        if raidSize == 0 then
            unitID = "party" .. i
        end
        
        local name = UnitName(unitID)
        if name then
            local threat = self:GetThreatStatus(name)
            if threat then
                self.player_threat[name] = threat
            end
        end
    end
end

function ThreatIndicatorEngine:GetHighThreatPlayers()
    local highThreat = {}
    
    for playerName, threat in pairs(self.player_threat) do
        if threat and (threat.threat_level == "medium" or threat.threat_level == "high") then
            table.insert(highThreat, threat)
        end
    end
    
    -- Sort by threat level
    table.sort(highThreat, function(a, b)
        return a.threat_percent > b.threat_percent
    end)
    
    return highThreat
end

function ThreatIndicatorEngine:IsTankOfBoss()
    -- Simplified tank detection - check if have threat on target
    if UnitThreatSituation("player") == nil or UnitThreatSituation("player") == 0 then
        return false
    end
    
    return true
end

function ThreatIndicatorEngine:GetTankList()
    local tanks = {}
    
    local raidSize = GetNumRaidMembers()
    if raidSize == 0 then
        raidSize = GetNumPartyMembers()
    end
    
    for i = 1, raidSize do
        local unitID = "raid" .. i
        if raidSize == 0 then
            unitID = "party" .. i
        end
        
        local name = UnitName(unitID)
        local class = select(2, UnitClass(unitID))
        
        -- Check if likely tank class
        if class and (class == "WARRIOR" or class == "PALADIN" or class == "DRUID") then
            local threat = self:GetThreatStatus(name)
            if threat and threat.has_threat then
                table.insert(tanks, {
                    name = name,
                    class = class,
                    threat = threat,
                })
            end
        end
    end
    
    return tanks
end

function ThreatIndicatorEngine:GetThreatColor(threatLevel)
    local colors = {
        none = { r = 0.5, g = 0.5, b = 0.5 },
        low = { r = 1, g = 1, b = 0 },
        medium = { r = 1, g = 0.5, b = 0 },
        high = { r = 1, g = 0, b = 0 },
    }
    
    return colors[threatLevel] or colors.none
end

function ThreatIndicatorEngine:FormatThreatDisplay(threat)
    if not threat then
        return "No threat"
    end
    
    if threat.threat_level == "none" then
        return "Safe"
    end
    
    return string.format("%s (%d%%)", threat.threat_level, threat.threat_percent)
end

function ThreatIndicatorEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function ThreatIndicatorEngine:GetStatus()
    local tracking = 0
    for _ in pairs(self.player_threat) do
        tracking = tracking + 1
    end
    
    return {
        enabled = self.enabled,
        players_tracked = tracking,
        high_threat_count = #self:GetHighThreatPlayers(),
        threat_polling = self.config.threat_polling,
    }
end

function ThreatIndicatorEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[ThreatIndicatorEngine] " .. message)
    else
        print("[ThreatIndicatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HEALERTHREAT1 = "/healerthreat"
    SlashCmdList["HEALERTHREAT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "status" then
            ThreatIndicatorEngine:UpdateAllThreat()
            local status = ThreatIndicatorEngine:GetStatus()
            print("Threat Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "high" then
            ThreatIndicatorEngine:UpdateAllThreat()
            local high = ThreatIndicatorEngine:GetHighThreatPlayers()
            if #high > 0 then
                print("High Threat Players:")
                for _, threat in ipairs(high) do
                    print(string.format("  %s: %s", threat.player, ThreatIndicatorEngine:FormatThreatDisplay(threat)))
                end
            else
                print("No high threat players")
            end
        elseif cmd == "tanks" then
            local tanks = ThreatIndicatorEngine:GetTankList()
            if #tanks > 0 then
                print("Tanks:")
                for _, tank in ipairs(tanks) do
                    print(string.format("  %s (%s): %s", tank.name, tank.class, ThreatIndicatorEngine:FormatThreatDisplay(tank.threat)))
                end
            else
                print("No tanks detected")
            end
        else
            print("Threat Commands:")
            print("  /threat status - Show threat status")
            print("  /threat high - Show high threat players")
            print("  /threat tanks - Show tanks with threat")
        end
    end
end

return ThreatIndicatorEngine
