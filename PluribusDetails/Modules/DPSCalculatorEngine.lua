-- DPSCalculatorEngine.lua - Calculate damage per second for all players
-- Part of PluribusDetails addon suite
-- Provides accurate DPS calculations with per-segment and time-window support

local DPSCalculatorEngine = {}
DPSCalculatorEngine.enabled = false
DPSCalculatorEngine.db = nil
DPSCalculatorEngine.dps_data = {}
DPSCalculatorEngine.player_damage = {}

-- Configuration
DPSCalculatorEngine.config = {
    enabled = true,
    calc_frequency = 1,  -- Calculate every 1 second
    time_window = 60,  -- Default 60-second window
    min_actors = 2,  -- At least 2 actors for calculations
}

function DPSCalculatorEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.dps_data then
        self.db.dps_data = {
            players = {},
            total_damage = 0,
            encounter_time = 0,
            segments = {},
        }
    end
    
    self.dps_data = self.db.dps_data
    self.enabled = true
    
    self:Log("Initialized DPS calculator")
end

function DPSCalculatorEngine:RecordDamage(sourceGUID, sourceName, spellName, spellId, damage, timestamp)
    if not sourceGUID or not damage or damage <= 0 then
        return false
    end
    
    -- Create player entry if not exists
    if not self.player_damage[sourceGUID] then
        self.player_damage[sourceGUID] = {
            name = sourceName,
            guid = sourceGUID,
            total_damage = 0,
            damage_events = 0,
            spells = {},
            first_hit = timestamp or GetTime(),
            last_hit = timestamp or GetTime(),
            crits = 0,
            critical_damage = 0,
        }
    end
    
    local playerData = self.player_damage[sourceGUID]
    
    -- Update player stats
    playerData.total_damage = playerData.total_damage + damage
    playerData.damage_events = playerData.damage_events + 1
    playerData.last_hit = timestamp or GetTime()
    
    -- Track spell damage
    if spellName then
        if not playerData.spells[spellName] then
            playerData.spells[spellName] = {
                name = spellName,
                spell_id = spellId,
                damage = 0,
                hits = 0,
                crits = 0,
            }
        end
        
        playerData.spells[spellName].damage = playerData.spells[spellName].damage + damage
        playerData.spells[spellName].hits = playerData.spells[spellName].hits + 1
    end
    
    return true
end

function DPSCalculatorEngine:RecordCrit(sourceGUID, sourceName, spellName, spellId, damage, timestamp)
    if not sourceGUID or not damage then
        return false
    end
    
    if not self.player_damage[sourceGUID] then
        self.player_damage[sourceGUID] = {
            name = sourceName,
            guid = sourceGUID,
            total_damage = 0,
            damage_events = 0,
            spells = {},
            first_hit = timestamp or GetTime(),
            last_hit = timestamp or GetTime(),
            crits = 0,
            critical_damage = 0,
        }
    end
    
    local playerData = self.player_damage[sourceGUID]
    playerData.crits = playerData.crits + 1
    playerData.critical_damage = playerData.critical_damage + damage
    
    if spellName and playerData.spells[spellName] then
        playerData.spells[spellName].crits = playerData.spells[spellName].crits + 1
    end
    
    return true
end

function DPSCalculatorEngine:CalculateDPS(sourceGUID, startTime, endTime)
    if not sourceGUID or not self.player_damage[sourceGUID] then
        return 0
    end
    
    local playerData = self.player_damage[sourceGUID]
    
    if not startTime then
        startTime = playerData.first_hit
    end
    
    if not endTime then
        endTime = playerData.last_hit
    end
    
    local duration = endTime - startTime
    
    if duration <= 0 then
        return 0
    end
    
    local dps = playerData.total_damage / duration
    
    return dps
end

function DPSCalculatorEngine:GetPlayerDPS(sourceGUID)
    if not sourceGUID or not self.player_damage[sourceGUID] then
        return 0
    end
    
    return self:CalculateDPS(sourceGUID)
end

function DPSCalculatorEngine:GetPlayerStats(sourceGUID)
    if not sourceGUID or not self.player_damage[sourceGUID] then
        return nil
    end
    
    local playerData = self.player_damage[sourceGUID]
    local duration = playerData.last_hit - playerData.first_hit
    
    return {
        name = playerData.name,
        guid = playerData.guid,
        total_damage = playerData.total_damage,
        damage_events = playerData.damage_events,
        dps = self:CalculateDPS(sourceGUID),
        duration = duration,
        first_hit = playerData.first_hit,
        last_hit = playerData.last_hit,
        crits = playerData.crits,
        crit_percent = playerData.damage_events > 0 and (playerData.crits / playerData.damage_events * 100) or 0,
        critical_damage = playerData.critical_damage,
        avg_hit = playerData.damage_events > 0 and (playerData.total_damage / playerData.damage_events) or 0,
        avg_crit = playerData.crits > 0 and (playerData.critical_damage / playerData.crits) or 0,
    }
end

function DPSCalculatorEngine:GetAllPlayerDPS()
    local dps_list = {}
    
    for guid, playerData in pairs(self.player_damage) do
        local dps = self:GetPlayerDPS(guid)
        
        table.insert(dps_list, {
            name = playerData.name,
            guid = guid,
            dps = dps,
        })
    end
    
    -- Sort by DPS descending
    table.sort(dps_list, function(a, b) return a.dps > b.dps end)
    
    return dps_list
end

function DPSCalculatorEngine:GetTopDPS(count)
    if not count or count <= 0 then
        count = 10
    end
    
    local dps_list = self:GetAllPlayerDPS()
    local top_dps = {}
    
    for i = 1, math.min(count, #dps_list) do
        table.insert(top_dps, dps_list[i])
    end
    
    return top_dps
end

function DPSCalculatorEngine:GetPlayerSpells(sourceGUID)
    if not sourceGUID or not self.player_damage[sourceGUID] then
        return {}
    end
    
    local playerData = self.player_damage[sourceGUID]
    local spells = {}
    
    for spellName, spellData in pairs(playerData.spells) do
        table.insert(spells, {
            name = spellName,
            spell_id = spellData.spell_id,
            damage = spellData.damage,
            hits = spellData.hits,
            crits = spellData.crits,
            avg_hit = spellData.hits > 0 and (spellData.damage / spellData.hits) or 0,
            crit_percent = spellData.hits > 0 and (spellData.crits / spellData.hits * 100) or 0,
        })
    end
    
    -- Sort by damage descending
    table.sort(spells, function(a, b) return a.damage > b.damage end)
    
    return spells
end

function DPSCalculatorEngine:GetTotalDamage()
    local total = 0
    
    for _, playerData in pairs(self.player_damage) do
        total = total + playerData.total_damage
    end
    
    return total
end

function DPSCalculatorEngine:GetEncounterDuration()
    local minTime = math.huge
    local maxTime = 0
    
    for _, playerData in pairs(self.player_damage) do
        if playerData.first_hit < minTime then
            minTime = playerData.first_hit
        end
        
        if playerData.last_hit > maxTime then
            maxTime = playerData.last_hit
        end
    end
    
    if minTime == math.huge then
        return 0
    end
    
    return maxTime - minTime
end

function DPSCalculatorEngine:GetGroupDPS()
    local duration = self:GetEncounterDuration()
    
    if duration <= 0 then
        return 0
    end
    
    return self:GetTotalDamage() / duration
end

function DPSCalculatorEngine:GetPlayerCount()
    local count = 0
    
    for _ in pairs(self.player_damage) do
        count = count + 1
    end
    
    return count
end

function DPSCalculatorEngine:ClearData()
    self.player_damage = {}
    self:Log("All DPS data cleared")
end

function DPSCalculatorEngine:GetStatus()
    local duration = self:GetEncounterDuration()
    
    return {
        enabled = self.enabled,
        player_count = self:GetPlayerCount(),
        total_damage = self:GetTotalDamage(),
        encounter_duration = duration,
        group_dps = self:GetGroupDPS(),
        active_players = self:CountActivePlayers(),
    }
end

function DPSCalculatorEngine:CountActivePlayers()
    local count = 0
    
    for _, playerData in pairs(self.player_damage) do
        if playerData.damage_events > 0 then
            count = count + 1
        end
    end
    
    return count
end

function DPSCalculatorEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[DPSCalculatorEngine] " .. message)
    else
        print("[DPSCalculatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_DPS1 = "/dps"
    SlashCmdList["DPS"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "top" then
            local count = tonumber(args) or 10
            local topDPS = DPSCalculatorEngine:GetTopDPS(count)
            print("Top " .. count .. " DPS:")
            for i, player in ipairs(topDPS) do
                print(string.format("  %d. %s: %.1f DPS", i, player.name, player.dps))
            end
        elseif cmd == "player" then
            if args and args ~= "" then
                for guid, playerData in pairs(DPSCalculatorEngine.player_damage) do
                    if playerData.name == args then
                        local stats = DPSCalculatorEngine:GetPlayerStats(guid)
                        if stats then
                            print("Player: " .. stats.name)
                            print("  DPS: " .. string.format("%.1f", stats.dps))
                            print("  Total Damage: " .. stats.total_damage)
                            print("  Hits: " .. stats.damage_events)
                            print("  Crits: " .. stats.crits .. " (" .. string.format("%.1f", stats.crit_percent) .. "%)")
                            print("  Avg Hit: " .. string.format("%.1f", stats.avg_hit))
                            print("  Avg Crit: " .. string.format("%.1f", stats.avg_crit))
                        end
                        return
                    end
                end
                print("Player not found: " .. args)
            else
                print("Usage: /dps player <name>")
            end
        elseif cmd == "spells" then
            if args and args ~= "" then
                for guid, playerData in pairs(DPSCalculatorEngine.player_damage) do
                    if playerData.name == args then
                        local spells = DPSCalculatorEngine:GetPlayerSpells(guid)
                        print("Spells for " .. args .. ":")
                        for _, spell in ipairs(spells) do
                            print(string.format("  %s: %.0f damage", spell.name, spell.damage))
                        end
                        return
                    end
                end
            else
                print("Usage: /dps spells <name>")
            end
        elseif cmd == "clear" then
            DPSCalculatorEngine:ClearData()
            print("DPS data cleared")
        elseif cmd == "status" then
            local status = DPSCalculatorEngine:GetStatus()
            print("DPS Calculator:")
            print("  Enabled: " .. tostring(status.enabled))
            print("  Players: " .. status.player_count)
            print("  Total Damage: " .. status.total_damage)
            print("  Duration: " .. string.format("%.1f", status.encounter_duration) .. "s")
            print("  Group DPS: " .. string.format("%.1f", status.group_dps))
        else
            print("DPS Calculator Commands:")
            print("  /dps top [count] - Show top DPS players (default 10)")
            print("  /dps player <name> - Show detailed stats for player")
            print("  /dps spells <name> - Show spell breakdown for player")
            print("  /dps clear - Clear all DPS data")
            print("  /dps status - Show system status")
        end
    end
end

return DPSCalculatorEngine
