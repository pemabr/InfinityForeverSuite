-- DamageCalculationEngine.lua - Track and analyze damage events in detail
-- Part of PluribusDetails addon suite
-- Provides granular damage tracking, absorption, resists, and damage type analysis

local DamageCalculationEngine = {}
DamageCalculationEngine.enabled = false
DamageCalculationEngine.db = nil
DamageCalculationEngine.damage_events = {}
DamageCalculationEngine.damage_summary = {}

-- Configuration
DamageCalculationEngine.config = {
    enabled = true,
    track_absorbs = true,
    track_resists = true,
    max_events = 10000,
}

-- Damage types
DamageCalculationEngine.damage_types = {
    PHYSICAL = 1,
    HOLY = 2,
    FIRE = 4,
    NATURE = 8,
    FROST = 16,
    SHADOW = 32,
    ARCANE = 64,
}

function DamageCalculationEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.damage_tracking then
        self.db.damage_tracking = {
            events = {},
            summary = {},
        }
    end
    
    self.damage_events = self.db.damage_tracking.events
    self.damage_summary = self.db.damage_tracking.summary
    self.enabled = true
    
    self:Log("Initialized with max " .. self.config.max_events .. " tracked events")
end

function DamageCalculationEngine:RecordDamage(sourceGUID, sourceName, destGUID, destName, 
                                            spellId, spellName, damageAmount, damageType, 
                                            isCritical, resisted, blocked, absorbed)
    if not sourceGUID or not damageAmount or damageAmount <= 0 then
        return false
    end
    
    -- Create event
    local event = {
        timestamp = GetTime(),
        source_guid = sourceGUID,
        source_name = sourceName,
        dest_guid = destGUID,
        dest_name = destName,
        spell_id = spellId,
        spell_name = spellName,
        damage = damageAmount,
        damage_type = damageType or self.damage_types.PHYSICAL,
        critical = isCritical or false,
        resisted = resisted or 0,
        blocked = blocked or 0,
        absorbed = absorbed or 0,
        overkill = 0,
    }
    
    -- Add to events
    table.insert(self.damage_events, event)
    
    -- Trim if too many
    if #self.damage_events > self.config.max_events then
        table.remove(self.damage_events, 1)
    end
    
    -- Update summary
    self:UpdateSummary(event)
    
    return true
end

function DamageCalculationEngine:UpdateSummary(event)
    local sourceKey = event.source_guid
    local destKey = event.dest_guid
    
    -- Create source summary if not exists
    if not self.damage_summary[sourceKey] then
        self.damage_summary[sourceKey] = {
            name = event.source_name,
            total_damage = 0,
            total_hits = 0,
            total_crits = 0,
            total_resisted = 0,
            total_absorbed = 0,
            total_blocked = 0,
            by_target = {},
            by_spell = {},
            damage_types = {},
        }
    end
    
    local summary = self.damage_summary[sourceKey]
    
    -- Update totals
    summary.total_damage = summary.total_damage + event.damage
    summary.total_hits = summary.total_hits + 1
    
    if event.critical then
        summary.total_crits = summary.total_crits + 1
    end
    
    if event.resisted and event.resisted > 0 then
        summary.total_resisted = summary.total_resisted + event.resisted
    end
    
    if event.absorbed and event.absorbed > 0 then
        summary.total_absorbed = summary.total_absorbed + event.absorbed
    end
    
    if event.blocked and event.blocked > 0 then
        summary.total_blocked = summary.total_blocked + event.blocked
    end
    
    -- Track by target
    if not summary.by_target[destKey] then
        summary.by_target[destKey] = {
            name = event.dest_name,
            damage = 0,
            hits = 0,
        }
    end
    
    summary.by_target[destKey].damage = summary.by_target[destKey].damage + event.damage
    summary.by_target[destKey].hits = summary.by_target[destKey].hits + 1
    
    -- Track by spell
    if event.spell_id then
        if not summary.by_spell[event.spell_id] then
            summary.by_spell[event.spell_id] = {
                name = event.spell_name,
                damage = 0,
                hits = 0,
                crits = 0,
            }
        end
        
        summary.by_spell[event.spell_id].damage = summary.by_spell[event.spell_id].damage + event.damage
        summary.by_spell[event.spell_id].hits = summary.by_spell[event.spell_id].hits + 1
        
        if event.critical then
            summary.by_spell[event.spell_id].crits = summary.by_spell[event.spell_id].crits + 1
        end
    end
    
    -- Track by damage type
    if not summary.damage_types[event.damage_type] then
        summary.damage_types[event.damage_type] = 0
    end
    
    summary.damage_types[event.damage_type] = summary.damage_types[event.damage_type] + event.damage
end

function DamageCalculationEngine:GetPlayerDamageSummary(sourceGUID)
    if not sourceGUID or not self.damage_summary[sourceGUID] then
        return nil
    end
    
    local summary = self.damage_summary[sourceGUID]
    
    return {
        name = summary.name,
        total_damage = summary.total_damage,
        total_hits = summary.total_hits,
        total_crits = summary.total_crits,
        avg_hit = summary.total_hits > 0 and (summary.total_damage / summary.total_hits) or 0,
        crit_percent = summary.total_hits > 0 and (summary.total_crits / summary.total_hits * 100) or 0,
        total_resisted = summary.total_resisted,
        total_absorbed = summary.total_absorbed,
        total_blocked = summary.total_blocked,
        effective_damage = summary.total_damage - summary.total_resisted - summary.total_absorbed - summary.total_blocked,
    }
end

function DamageCalculationEngine:GetTargetDamage(sourceGUID, destGUID)
    if not sourceGUID or not self.damage_summary[sourceGUID] then
        return nil
    end
    
    local targetData = self.damage_summary[sourceGUID].by_target[destGUID]
    
    if not targetData then
        return nil
    end
    
    return {
        name = targetData.name,
        damage = targetData.damage,
        hits = targetData.hits,
        avg_hit = targetData.hits > 0 and (targetData.damage / targetData.hits) or 0,
    }
end

function DamageCalculationEngine:GetSpellDamage(sourceGUID, spellId)
    if not sourceGUID or not spellId or not self.damage_summary[sourceGUID] then
        return nil
    end
    
    local spellData = self.damage_summary[sourceGUID].by_spell[spellId]
    
    if not spellData then
        return nil
    end
    
    return {
        name = spellData.name,
        damage = spellData.damage,
        hits = spellData.hits,
        crits = spellData.crits,
        avg_hit = spellData.hits > 0 and (spellData.damage / spellData.hits) or 0,
        crit_percent = spellData.hits > 0 and (spellData.crits / spellData.hits * 100) or 0,
    }
end

function DamageCalculationEngine:GetAllPlayerSummaries()
    local summaries = {}
    
    for guid, summary in pairs(self.damage_summary) do
        table.insert(summaries, {
            guid = guid,
            name = summary.name,
            total_damage = summary.total_damage,
            total_hits = summary.total_hits,
        })
    end
    
    -- Sort by damage descending
    table.sort(summaries, function(a, b) return a.total_damage > b.total_damage end)
    
    return summaries
end

function DamageCalculationEngine:GetTotalDamage()
    local total = 0
    
    for _, summary in pairs(self.damage_summary) do
        total = total + summary.total_damage
    end
    
    return total
end

function DamageCalculationEngine:GetEventCount()
    return #self.damage_events
end

function DamageCalculationEngine:GetEventsByTimeWindow(startTime, endTime)
    local events = {}
    
    for _, event in ipairs(self.damage_events) do
        if event.timestamp >= startTime and event.timestamp <= endTime then
            table.insert(events, event)
        end
    end
    
    return events
end

function DamageCalculationEngine:GetAverageResistPercentage()
    local total_hits = 0
    local resisted_hits = 0
    
    for _, event in ipairs(self.damage_events) do
        total_hits = total_hits + 1
        
        if event.resisted and event.resisted > 0 then
            resisted_hits = resisted_hits + 1
        end
    end
    
    if total_hits == 0 then
        return 0
    end
    
    return (resisted_hits / total_hits) * 100
end

function DamageCalculationEngine:GetAverageAbsorbPercentage()
    local total_hits = 0
    local absorbed_hits = 0
    
    for _, event in ipairs(self.damage_events) do
        total_hits = total_hits + 1
        
        if event.absorbed and event.absorbed > 0 then
            absorbed_hits = absorbed_hits + 1
        end
    end
    
    if total_hits == 0 then
        return 0
    end
    
    return (absorbed_hits / total_hits) * 100
end

function DamageCalculationEngine:ClearData()
    self.damage_events = {}
    self.damage_summary = {}
    self:Log("All damage data cleared")
end

function DamageCalculationEngine:GetStatus()
    return {
        enabled = self.enabled,
        event_count = self:GetEventCount(),
        max_events = self.config.max_events,
        total_damage = self:GetTotalDamage(),
        player_count = self:CountPlayers(),
        avg_resist_percent = string.format("%.1f", self:GetAverageResistPercentage()),
        avg_absorb_percent = string.format("%.1f", self:GetAverageAbsorbPercentage()),
    }
end

function DamageCalculationEngine:CountPlayers()
    local count = 0
    
    for _ in pairs(self.damage_summary) do
        count = count + 1
    end
    
    return count
end

function DamageCalculationEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[DamageCalculationEngine] " .. message)
    else
        print("[DamageCalculationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_DMGCALC1 = "/dmgcalc"
    SlashCmdList["DMGCALC"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "summary" then
            local summaries = DamageCalculationEngine:GetAllPlayerSummaries()
            print("Damage Summary:")
            for i, summary in ipairs(summaries) do
                print(string.format("  %d. %s: %.0f damage", i, summary.name, summary.total_damage))
            end
        elseif cmd == "clear" then
            DamageCalculationEngine:ClearData()
            print("Damage data cleared")
        elseif cmd == "status" then
            local status = DamageCalculationEngine:GetStatus()
            print("Damage Calculator:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Damage Calculator Commands:")
            print("  /dmgcalc summary - Show damage summary")
            print("  /dmgcalc status - Show system status")
            print("  /dmgcalc clear - Clear all data")
        end
    end
end

return DamageCalculationEngine
