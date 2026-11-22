-- Combat Analytics - DPS/HPS Tracking
-- Advanced performance metrics for DPS, HPS, TPS, and damage breakdown

local MODULE_NAME = "CombatAnalytics"
local InfinityCore = InfinityCore or {}
local InfinityPerformanceAnalytics = InfinityPerformanceAnalytics or {}

InfinityPerformanceAnalytics.CombatAnalytics = {
    enabled = false,
    tracking = false,
    encounter_active = false,
    encounter_start_time = 0,
    
    db = {
        players = {},
        encounters = {},
        combat_session = nil
    },
    
    config = {
        track_dps = true,
        track_hps = true,
        track_tps = true,
        min_damage_threshold = 10,
        refresh_rate = 1.0,
    }
}

local Analytics = InfinityPerformanceAnalytics.CombatAnalytics

function Analytics:Initialize()
    -- Subscribe to combat events
    if InfinityCore.Events then
        InfinityCore.Events:Subscribe("ENCOUNTER_START", function(encounter_id, encounter_name)
            Analytics:StartEncounter(encounter_id, encounter_name)
        end)
        
        InfinityCore.Events:Subscribe("ENCOUNTER_END", function(success)
            Analytics:EndEncounter(success)
        end)
        
        InfinityCore.Events:Subscribe("COMBAT_LOG_EVENT", function(event_type, source, target, amount)
            Analytics:RecordEvent(event_type, source, target, amount)
        end)
    end
    
    self:ResetSession()
end

function Analytics:ResetSession()
    self.db.players = {}
    self.db.encounters = {}
    self.db.combat_session = {
        start_time = 0,
        end_time = 0,
        boss_name = "Unknown",
        duration = 0,
        success = false,
        total_damage = 0,
        total_healing = 0,
    }
end

function Analytics:StartEncounter(encounter_id, encounter_name)
    self.encounter_active = true
    self.encounter_start_time = GetTime()
    
    self:ResetSession()
    
    self.db.combat_session.start_time = GetServerTime()
    self.db.combat_session.boss_name = encounter_name or "Unknown"
    self.db.combat_session.encounter_id = encounter_id
    
    print("|cff00ccffCombat Analytics:|r Tracking encounter: " .. (encounter_name or "Unknown"))
end

function Analytics:EndEncounter(success)
    self.encounter_active = false
    
    local duration = GetTime() - self.encounter_start_time
    self.db.combat_session.end_time = GetServerTime()
    self.db.combat_session.duration = duration
    self.db.combat_session.success = success or false
    
    self:LogEncounterResults()
end

function Analytics:RecordEvent(event_type, source, target, amount)
    if not self.encounter_active then
        return
    end
    
    if not source or not amount or amount <= self.config.min_damage_threshold then
        return
    end
    
    -- Initialize player if needed
    if not self.db.players[source] then
        self.db.players[source] = {
            name = source,
            damage = 0,
            healing = 0,
            threat = 0,
            damage_breakdown = {},
            healing_breakdown = {},
            spell_counts = {},
            first_action = GetTime(),
            last_action = GetTime()
        }
    end
    
    local player = self.db.players[source]
    player.last_action = GetTime()
    
    if event_type == "DAMAGE" then
        player.damage = player.damage + amount
        self.db.combat_session.total_damage = self.db.combat_session.total_damage + amount
        
        -- Track damage breakdown by school
        local school = "physical"
        player.damage_breakdown[school] = (player.damage_breakdown[school] or 0) + amount
        
        -- Track spell cast counts
        player.spell_counts[target] = (player.spell_counts[target] or 0) + 1
        
    elseif event_type == "HEALING" then
        player.healing = player.healing + amount
        self.db.combat_session.total_healing = self.db.combat_session.total_healing + amount
        
        -- Track healing breakdown by type
        local heal_type = "direct"
        player.healing_breakdown[heal_type] = (player.healing_breakdown[heal_type] or 0) + amount
        
        -- Track spell cast counts
        player.spell_counts[target] = (player.spell_counts[target] or 0) + 1
        
    elseif event_type == "THREAT" then
        player.threat = player.threat + amount
    end
end

function Analytics:CalculateDPS()
    local results = {}
    local duration = math.max(self.db.combat_session.duration, 1)
    
    for player_name, player_data in pairs(self.db.players) do
        local dps = player_data.damage / duration
        
        table.insert(results, {
            name = player_name,
            dps = dps,
            damage = player_data.damage,
            duration = duration
        })
    end
    
    -- Sort by DPS (highest first)
    table.sort(results, function(a, b)
        return a.dps > b.dps
    end)
    
    return results
end

function Analytics:CalculateHPS()
    local results = {}
    local duration = math.max(self.db.combat_session.duration, 1)
    
    for player_name, player_data in pairs(self.db.players) do
        if player_data.healing > 0 then
            local hps = player_data.healing / duration
            
            table.insert(results, {
                name = player_name,
                hps = hps,
                healing = player_data.healing,
                duration = duration
            })
        end
    end
    
    -- Sort by HPS (highest first)
    table.sort(results, function(a, b)
        return a.hps > b.hps
    end)
    
    return results
end

function Analytics:CalculateDamagePercent()
    local results = {}
    local total = math.max(self.db.combat_session.total_damage, 1)
    
    for player_name, player_data in pairs(self.db.players) do
        if player_data.damage > 0 then
            local percent = (player_data.damage / total) * 100
            
            table.insert(results, {
                name = player_name,
                damage = player_data.damage,
                percent = percent
            })
        end
    end
    
    table.sort(results, function(a, b)
        return a.damage > b.damage
    end)
    
    return results
end

function Analytics:CalculateHealingPercent()
    local results = {}
    local total = math.max(self.db.combat_session.total_healing, 1)
    
    for player_name, player_data in pairs(self.db.players) do
        if player_data.healing > 0 then
            local percent = (player_data.healing / total) * 100
            
            table.insert(results, {
                name = player_name,
                healing = player_data.healing,
                percent = percent
            })
        end
    end
    
    table.sort(results, function(a, b)
        return a.healing > b.healing
    end)
    
    return results
end

function Analytics:GetPlayerStats(player_name)
    if not self.db.players[player_name] then
        return nil
    end
    
    local player = self.db.players[player_name]
    local duration = math.max(self.db.combat_session.duration, 1)
    
    return {
        name = player_name,
        total_damage = player.damage,
        total_healing = player.healing,
        total_threat = player.threat,
        dps = player.damage / duration,
        hps = player.healing / duration,
        tps = player.threat / duration,
        damage_percent = (player.damage / math.max(self.db.combat_session.total_damage, 1)) * 100,
        healing_percent = (player.healing / math.max(self.db.combat_session.total_healing, 1)) * 100,
        spell_count = table.getn(player.spell_counts)
    }
end

function Analytics:LogEncounterResults()
    if not InfinityDKP or not InfinityDKP.db then
        return
    end
    
    -- Create encounter log entry
    local encounter_log = {
        timestamp = GetServerTime(),
        boss_name = self.db.combat_session.boss_name,
        encounter_id = self.db.combat_session.encounter_id,
        duration = self.db.combat_session.duration,
        success = self.db.combat_session.success,
        total_damage = self.db.combat_session.total_damage,
        total_healing = self.db.combat_session.total_healing,
        participants = {}
    }
    
    -- Record top performers
    local top_dps = self:CalculateDPS()
    local top_hps = self:CalculateHPS()
    
    for idx, entry in ipairs(top_dps) do
        if idx <= 5 then
            table.insert(encounter_log.participants, {
                role = "DPS",
                name = entry.name,
                value = math.floor(entry.dps),
                unit = "DPS"
            })
        end
    end
    
    for idx, entry in ipairs(top_hps) do
        if idx <= 3 then
            table.insert(encounter_log.participants, {
                role = "Healing",
                name = entry.name,
                value = math.floor(entry.hps),
                unit = "HPS"
            })
        end
    end
    
    -- Store in database
    if not InfinityDKP.db.encounter_logs then
        InfinityDKP.db.encounter_logs = {}
    end
    
    table.insert(InfinityDKP.db.encounter_logs, encounter_log)
end

function Analytics:PrintDPSReport()
    if not self.encounter_active and self.db.combat_session.duration == 0 then
        print("|cffff0000No encounter data to report.|r")
        return
    end
    
    print("|cff00ccffDPS Report|r - " .. self.db.combat_session.boss_name)
    print(string.rep("-", 60))
    
    local dps_results = self:CalculateDPS()
    
    for idx, entry in ipairs(dps_results) do
        local dmg_pct = (entry.damage / math.max(self.db.combat_session.total_damage, 1)) * 100
        
        print(string.format(
            "%2d. %s - %7.0f DPS (%d damage, %.1f%%)",
            idx,
            entry.name,
            entry.dps,
            entry.damage,
            dmg_pct
        ))
        
        if idx >= 10 then
            break
        end
    end
    
    print(string.rep("-", 60))
    print(string.format("Encounter Duration: %.1f seconds", self.db.combat_session.duration))
    print(string.format("Total Damage: %d", self.db.combat_session.total_damage))
end

function Analytics:PrintHPSReport()
    if not self.encounter_active and self.db.combat_session.duration == 0 then
        print("|cffff0000No encounter data to report.|r")
        return
    end
    
    print("|cff00ccffHPS Report|r - " .. self.db.combat_session.boss_name)
    print(string.rep("-", 60))
    
    local hps_results = self:CalculateHPS()
    
    for idx, entry in ipairs(hps_results) do
        local heal_pct = (entry.healing / math.max(self.db.combat_session.total_healing, 1)) * 100
        
        print(string.format(
            "%2d. %s - %7.0f HPS (%d healing, %.1f%%)",
            idx,
            entry.name,
            entry.hps,
            entry.healing,
            heal_pct
        ))
        
        if idx >= 10 then
            break
        end
    end
    
    print(string.rep("-", 60))
    print(string.format("Encounter Duration: %.1f seconds", self.db.combat_session.duration))
    print(string.format("Total Healing: %d", self.db.combat_session.total_healing))
end

function Analytics:PrintFullReport()
    self:PrintDPSReport()
    print("")
    self:PrintHPSReport()
end

-- Register slash commands
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("dps", function(args)
        if args == "report" then
            Analytics:PrintDPSReport()
        elseif args == "hps" then
            Analytics:PrintHPSReport()
        elseif args == "full" then
            Analytics:PrintFullReport()
        else
            Analytics:PrintDPSReport()
        end
    end, "Show DPS/HPS combat reports")
end

return InfinityPerformanceAnalytics.CombatAnalytics

