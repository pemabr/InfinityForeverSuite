-- DeathTrackingEngine.lua - Track and analyze player deaths
-- Part of PluribusDetails addon suite
-- Provides death timeline, cause of death, and resurrection tracking

local DeathTrackingEngine = {}
DeathTrackingEngine.enabled = false
DeathTrackingEngine.db = nil
DeathTrackingEngine.deaths = {}
DeathTrackingEngine.player_deaths = {}

-- Configuration
DeathTrackingEngine.config = {
    enabled = true,
    max_deaths = 1000,
}

function DeathTrackingEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.death_tracking then
        self.db.death_tracking = {
            events = {},
            by_player = {},
        }
    end
    
    self.deaths = self.db.death_tracking.events
    self.player_deaths = self.db.death_tracking.by_player
    self.enabled = true
    
    self:Log("Initialized death tracker")
end

function DeathTrackingEngine:RecordDeath(playerGUID, playerName, deathTime, killedByGUID, killedByName, 
                                        damageType, lastDamage, environmentDeath)
    if not playerGUID or not playerName then
        return false
    end
    
    -- Create death event
    local death = {
        id = self:GetNextDeathId(),
        player_guid = playerGUID,
        player_name = playerName,
        time = deathTime or GetTime(),
        killed_by_guid = killedByGUID,
        killed_by_name = killedByName or "Unknown",
        damage_type = damageType or "physical",
        last_damage = lastDamage or 0,
        environment_death = environmentDeath or false,
        is_player_kill = not environmentDeath and killedByGUID ~= nil,
        resurrected = false,
        resurrection_time = nil,
        resurrecter = nil,
    }
    
    -- Add to deaths list
    table.insert(self.deaths, death)
    
    -- Trim if too many
    if #self.deaths > self.config.max_deaths then
        table.remove(self.deaths, 1)
    end
    
    -- Create player death entry if not exists
    if not self.player_deaths[playerGUID] then
        self.player_deaths[playerGUID] = {
            name = playerName,
            guid = playerGUID,
            total_deaths = 0,
            deaths = {},
        }
    end
    
    -- Add to player deaths
    self.player_deaths[playerGUID].total_deaths = self.player_deaths[playerGUID].total_deaths + 1
    table.insert(self.player_deaths[playerGUID].deaths, death)
    
    self:Log("Death recorded: " .. playerName .. " (" .. (death.killed_by_name or "environment") .. ")")
    
    return death
end

function DeathTrackingEngine:RecordResurrection(playerGUID, playerName, resurrectionTime, resurrecterName)
    if not playerGUID then
        return false
    end
    
    -- Find most recent death for this player
    local mostRecentDeath = nil
    
    for i = #self.deaths, 1, -1 do
        if self.deaths[i].player_guid == playerGUID and not self.deaths[i].resurrected then
            mostRecentDeath = self.deaths[i]
            break
        end
    end
    
    if mostRecentDeath then
        mostRecentDeath.resurrected = true
        mostRecentDeath.resurrection_time = resurrectionTime or GetTime()
        mostRecentDeath.resurrecter = resurrecterName or "Unknown"
        
        self:Log("Resurrection recorded: " .. playerName .. " by " .. (resurrecterName or "Unknown"))
        
        return mostRecentDeath
    end
    
    return false
end

function DeathTrackingEngine:GetPlayerDeaths(playerGUID)
    if not playerGUID or not self.player_deaths[playerGUID] then
        return {}
    end
    
    return self.player_deaths[playerGUID].deaths
end

function DeathTrackingEngine:GetPlayerDeathStats(playerGUID)
    if not playerGUID or not self.player_deaths[playerGUID] then
        return nil
    end
    
    local playerData = self.player_deaths[playerGUID]
    local deaths = playerData.deaths
    
    local player_kills = 0
    local environment_deaths = 0
    local avg_time_to_death = 0
    local avg_time_to_res = 0
    local resurrections = 0
    
    for _, death in ipairs(deaths) do
        if death.is_player_kill then
            player_kills = player_kills + 1
        else
            environment_deaths = environment_deaths + 1
        end
        
        if death.resurrection_time then
            resurrections = resurrections + 1
            avg_time_to_res = avg_time_to_res + (death.resurrection_time - death.time)
        end
    end
    
    if resurrections > 0 then
        avg_time_to_res = avg_time_to_res / resurrections
    end
    
    return {
        name = playerData.name,
        guid = playerGUID,
        total_deaths = playerData.total_deaths,
        player_kills = player_kills,
        environment_deaths = environment_deaths,
        resurrections = resurrections,
        avg_time_to_resurrection = avg_time_to_res,
        remains_dead = playerData.total_deaths - resurrections,
    }
end

function DeathTrackingEngine:GetDeathsByKiller(killerGUID, killerName)
    if not killerGUID then
        return {}
    end
    
    local deaths = {}
    
    for _, death in ipairs(self.deaths) do
        if death.killed_by_guid == killerGUID then
            table.insert(deaths, death)
        end
    end
    
    return deaths
end

function DeathTrackingEngine:GetMostDangerousMobs()
    local killers = {}
    
    for _, death in ipairs(self.deaths) do
        if death.is_player_kill and death.killed_by_guid then
            if not killers[death.killed_by_guid] then
                killers[death.killed_by_guid] = {
                    guid = death.killed_by_guid,
                    name = death.killed_by_name,
                    kills = 0,
                }
            end
            
            killers[death.killed_by_guid].kills = killers[death.killed_by_guid].kills + 1
        end
    end
    
    local topKillers = {}
    for _, killer in pairs(killers) do
        table.insert(topKillers, killer)
    end
    
    -- Sort by kills descending
    table.sort(topKillers, function(a, b) return a.kills > b.kills end)
    
    return topKillers
end

function DeathTrackingEngine:GetDeathTimeline()
    local timeline = {}
    
    for _, death in ipairs(self.deaths) do
        table.insert(timeline, {
            time = death.time,
            player = death.player_name,
            killer = death.killed_by_name,
            is_pk = death.is_player_kill,
        })
    end
    
    return timeline
end

function DeathTrackingEngine:GetDeathCount()
    return #self.deaths
end

function DeathTrackingEngine:GetPlayerCount()
    local count = 0
    
    for _ in pairs(self.player_deaths) do
        count = count + 1
    end
    
    return count
end

function DeathTrackingEngine:GetDeathlessPlayers()
    local deathless = {}
    
    for guid, playerData in pairs(self.player_deaths) do
        if playerData.total_deaths == 0 then
            table.insert(deathless, {
                name = playerData.name,
                guid = guid,
            })
        end
    end
    
    return deathless
end

function DeathTrackingEngine:GetAvgDeathsPerPlayer()
    local playerCount = self:GetPlayerCount()
    
    if playerCount == 0 then
        return 0
    end
    
    return self:GetDeathCount() / playerCount
end

function DeathTrackingEngine:ClearData()
    self.deaths = {}
    self.player_deaths = {}
    self:Log("All death data cleared")
end

function DeathTrackingEngine:GetNextDeathId()
    local maxId = 0
    
    for _, death in ipairs(self.deaths) do
        if death.id and death.id > maxId then
            maxId = death.id
        end
    end
    
    return maxId + 1
end

function DeathTrackingEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_deaths = self:GetDeathCount(),
        total_players = self:GetPlayerCount(),
        avg_deaths_per_player = string.format("%.1f", self:GetAvgDeathsPerPlayer()),
        deathless_players = #self:GetDeathlessPlayers(),
    }
end

function DeathTrackingEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[DeathTrackingEngine] " .. message)
    else
        print("[DeathTrackingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_DEATH1 = "/death"
    SlashCmdList["DEATH"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "summary" then
            local deathless = DeathTrackingEngine:GetDeathlessPlayers()
            print("Death Summary:")
            print("  Total Deaths: " .. DeathTrackingEngine:GetDeathCount())
            print("  Avg Per Player: " .. string.format("%.1f", DeathTrackingEngine:GetAvgDeathsPerPlayer()))
            print("  Deathless Players: " .. #deathless)
        elseif cmd == "dangerous" then
            local killers = DeathTrackingEngine:GetMostDangerousMobs()
            print("Most Dangerous Encounters:")
            for i, killer in ipairs(killers) do
                print(string.format("  %d. %s: %d kills", i, killer.name, killer.kills))
            end
        elseif cmd == "clear" then
            DeathTrackingEngine:ClearData()
            print("Death data cleared")
        elseif cmd == "status" then
            local status = DeathTrackingEngine:GetStatus()
            print("Death Tracker:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Death Tracker Commands:")
            print("  /death summary - Show death summary")
            print("  /death dangerous - Show dangerous mobs")
            print("  /death status - Show system status")
            print("  /death clear - Clear all data")
        end
    end
end

return DeathTrackingEngine
