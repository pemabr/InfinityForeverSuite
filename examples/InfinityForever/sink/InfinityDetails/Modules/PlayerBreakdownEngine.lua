-- PlayerBreakdownEngine.lua - Detailed per-player breakdown of combat stats
-- Part of InfinityDetails addon suite
-- Provides comprehensive player-level statistics and analysis

local PlayerBreakdownEngine = {}
PlayerBreakdownEngine.enabled = false
PlayerBreakdownEngine.db = nil
PlayerBreakdownEngine.player_stats = {}

-- Configuration
PlayerBreakdownEngine.config = {
    enabled = true,
}

function PlayerBreakdownEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.player_breakdown then
        self.db.player_breakdown = {
            players = {},
        }
    end
    
    self.player_stats = self.db.player_breakdown.players
    self.enabled = true
    
    self:Log("Initialized player breakdown engine")
end

function PlayerBreakdownEngine:RecordPlayerStats(playerGUID, playerName, playerClass, playerSpec, 
                                               damageDealt, healingDealt, damageReceived, deathCount)
    if not playerGUID or not playerName then
        return false
    end
    
    -- Create player entry if not exists
    if not self.player_stats[playerGUID] then
        self.player_stats[playerGUID] = {
            name = playerName,
            guid = playerGUID,
            class = playerClass,
            spec = playerSpec,
            stats = {
                damage = 0,
                healing = 0,
                damage_received = 0,
                deaths = 0,
                kills = 0,
                assists = 0,
                crowd_control_time = 0,
                interrupts = 0,
                dispels = 0,
            },
            timeline = {},
            first_action = GetTime(),
            last_action = GetTime(),
        }
    end
    
    local playerData = self.player_stats[playerGUID]
    
    -- Update stats
    if damageDealt then
        playerData.stats.damage = damageDealt
    end
    
    if healingDealt then
        playerData.stats.healing = healingDealt
    end
    
    if damageReceived then
        playerData.stats.damage_received = damageReceived
    end
    
    if deathCount then
        playerData.stats.deaths = deathCount
    end
    
    playerData.last_action = GetTime()
    
    return true
end

function PlayerBreakdownEngine:RecordKill(playerGUID, targetGUID, targetName)
    if not playerGUID or not self.player_stats[playerGUID] then
        return false
    end
    
    self.player_stats[playerGUID].stats.kills = self.player_stats[playerGUID].stats.kills + 1
    
    return true
end

function PlayerBreakdownEngine:RecordAssist(playerGUID)
    if not playerGUID or not self.player_stats[playerGUID] then
        return false
    end
    
    self.player_stats[playerGUID].stats.assists = self.player_stats[playerGUID].stats.assists + 1
    
    return true
end

function PlayerBreakdownEngine:RecordCrowdControl(playerGUID, duration)
    if not playerGUID or not duration or not self.player_stats[playerGUID] then
        return false
    end
    
    self.player_stats[playerGUID].stats.crowd_control_time = 
        self.player_stats[playerGUID].stats.crowd_control_time + duration
    
    return true
end

function PlayerBreakdownEngine:RecordInterrupt(playerGUID)
    if not playerGUID or not self.player_stats[playerGUID] then
        return false
    end
    
    self.player_stats[playerGUID].stats.interrupts = self.player_stats[playerGUID].stats.interrupts + 1
    
    return true
end

function PlayerBreakdownEngine:RecordDispel(playerGUID)
    if not playerGUID or not self.player_stats[playerGUID] then
        return false
    end
    
    self.player_stats[playerGUID].stats.dispels = self.player_stats[playerGUID].stats.dispels + 1
    
    return true
end

function PlayerBreakdownEngine:GetPlayerBreakdown(playerGUID)
    if not playerGUID or not self.player_stats[playerGUID] then
        return nil
    end
    
    local playerData = self.player_stats[playerGUID]
    local stats = playerData.stats
    
    return {
        name = playerData.name,
        guid = playerGUID,
        class = playerData.class,
        spec = playerData.spec,
        damage = stats.damage,
        healing = stats.healing,
        damage_received = stats.damage_received,
        deaths = stats.deaths,
        kills = stats.kills,
        assists = stats.assists,
        crowd_control_time = stats.crowd_control_time,
        interrupts = stats.interrupts,
        dispels = stats.dispels,
    }
end

function PlayerBreakdownEngine:GetAllPlayerBreakdowns()
    local breakdowns = {}
    
    for guid, playerData in pairs(self.player_stats) do
        local breakdown = self:GetPlayerBreakdown(guid)
        if breakdown then
            table.insert(breakdowns, breakdown)
        end
    end
    
    return breakdowns
end

function PlayerBreakdownEngine:GetPlayersByDamage()
    local players = {}
    
    for guid, playerData in pairs(self.player_stats) do
        table.insert(players, {
            name = playerData.name,
            guid = guid,
            class = playerData.class,
            damage = playerData.stats.damage,
        })
    end
    
    -- Sort by damage descending
    table.sort(players, function(a, b) return a.damage > b.damage end)
    
    return players
end

function PlayerBreakdownEngine:GetPlayersByHealing()
    local players = {}
    
    for guid, playerData in pairs(self.player_stats) do
        table.insert(players, {
            name = playerData.name,
            guid = guid,
            class = playerData.class,
            healing = playerData.stats.healing,
        })
    end
    
    -- Sort by healing descending
    table.sort(players, function(a, b) return a.healing > b.healing end)
    
    return players
end

function PlayerBreakdownEngine:GetPlayersByClass(playerClass)
    if not playerClass then
        return {}
    end
    
    local players = {}
    
    for guid, playerData in pairs(self.player_stats) do
        if playerData.class == playerClass then
            table.insert(players, {
                name = playerData.name,
                guid = guid,
                damage = playerData.stats.damage,
                healing = playerData.stats.healing,
            })
        end
    end
    
    return players
end

function PlayerBreakdownEngine:GetPlayersBySpec(spec)
    if not spec then
        return {}
    end
    
    local players = {}
    
    for guid, playerData in pairs(self.player_stats) do
        if playerData.spec == spec then
            table.insert(players, {
                name = playerData.name,
                guid = guid,
                damage = playerData.stats.damage,
                healing = playerData.stats.healing,
            })
        end
    end
    
    return players
end

function PlayerBreakdownEngine:GetPlayerCount()
    local count = 0
    
    for _ in pairs(self.player_stats) do
        count = count + 1
    end
    
    return count
end

function PlayerBreakdownEngine:GetClassDistribution()
    local distribution = {}
    
    for _, playerData in pairs(self.player_stats) do
        if playerData.class then
            if not distribution[playerData.class] then
                distribution[playerData.class] = 0
            end
            
            distribution[playerData.class] = distribution[playerData.class] + 1
        end
    end
    
    return distribution
end

function PlayerBreakdownEngine:GetTotalDamage()
    local total = 0
    
    for _, playerData in pairs(self.player_stats) do
        total = total + playerData.stats.damage
    end
    
    return total
end

function PlayerBreakdownEngine:GetTotalHealing()
    local total = 0
    
    for _, playerData in pairs(self.player_stats) do
        total = total + playerData.stats.healing
    end
    
    return total
end

function PlayerBreakdownEngine:GetTotalDeaths()
    local total = 0
    
    for _, playerData in pairs(self.player_stats) do
        total = total + playerData.stats.deaths
    end
    
    return total
end

function PlayerBreakdownEngine:ClearData()
    self.player_stats = {}
    self:Log("All player breakdown data cleared")
end

function PlayerBreakdownEngine:GetStatus()
    return {
        enabled = self.enabled,
        player_count = self:GetPlayerCount(),
        total_damage = self:GetTotalDamage(),
        total_healing = self:GetTotalHealing(),
        total_deaths = self:GetTotalDeaths(),
    }
end

function PlayerBreakdownEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[PlayerBreakdownEngine] " .. message)
    else
        print("[PlayerBreakdownEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_PLAYERBD1 = "/playerbd"
    SlashCmdList["PLAYERBD"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "damage" then
            local players = PlayerBreakdownEngine:GetPlayersByDamage()
            print("Players by Damage:")
            for i, player in ipairs(players) do
                print(string.format("  %d. %s: %.0f", i, player.name, player.damage))
            end
        elseif cmd == "healing" then
            local players = PlayerBreakdownEngine:GetPlayersByHealing()
            print("Players by Healing:")
            for i, player in ipairs(players) do
                print(string.format("  %d. %s: %.0f", i, player.name, player.healing))
            end
        elseif cmd == "class" then
            if args and args ~= "" then
                local players = PlayerBreakdownEngine:GetPlayersByClass(args)
                print("Players - " .. args .. ":")
                for _, player in ipairs(players) do
                    print(string.format("  %s: %.0f damage, %.0f healing", player.name, player.damage, player.healing))
                end
            else
                local dist = PlayerBreakdownEngine:GetClassDistribution()
                print("Class Distribution:")
                for class, count in pairs(dist) do
                    print("  " .. class .. ": " .. count)
                end
            end
        elseif cmd == "clear" then
            PlayerBreakdownEngine:ClearData()
            print("Player breakdown data cleared")
        elseif cmd == "status" then
            local status = PlayerBreakdownEngine:GetStatus()
            print("Player Breakdown:")
            print("  Players: " .. status.player_count)
            print("  Total Damage: " .. status.total_damage)
            print("  Total Healing: " .. status.total_healing)
            print("  Total Deaths: " .. status.total_deaths)
        else
            print("Player Breakdown Commands:")
            print("  /playerbd damage - Sort by damage")
            print("  /playerbd healing - Sort by healing")
            print("  /playerbd class [class] - Filter by class")
            print("  /playerbd status - Show system status")
            print("  /playerbd clear - Clear all data")
        end
    end
end

return PlayerBreakdownEngine
