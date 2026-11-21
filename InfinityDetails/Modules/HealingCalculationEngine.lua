-- HealingCalculationEngine.lua - Track and analyze healing events
-- Part of InfinityDetails addon suite
-- Provides detailed healing tracking, overheal analysis, and healer performance metrics

local HealingCalculationEngine = {}
HealingCalculationEngine.enabled = false
HealingCalculationEngine.db = nil
HealingCalculationEngine.healing_events = {}
HealingCalculationEngine.healing_summary = {}

-- Configuration
HealingCalculationEngine.config = {
    enabled = true,
    track_overheals = true,
    track_absorbed = true,
    max_events = 10000,
}

function HealingCalculationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.healing_tracking then
        self.db.healing_tracking = {
            events = {},
            summary = {},
        }
    end
    
    self.healing_events = self.db.healing_tracking.events
    self.healing_summary = self.db.healing_tracking.summary
    self.enabled = true
    
    self:Log("Initialized with max " .. self.config.max_events .. " tracked events")
end

function HealingCalculationEngine:RecordHeal(sourceGUID, sourceName, destGUID, destName,
                                           spellId, spellName, healAmount, overhealAmount, 
                                           absorbed, isCritical)
    if not sourceGUID or not healAmount or healAmount <= 0 then
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
        heal = healAmount,
        overheal = overhealAmount or 0,
        absorbed = absorbed or 0,
        effective_heal = healAmount - (overhealAmount or 0),
        critical = isCritical or false,
    }
    
    -- Add to events
    table.insert(self.healing_events, event)
    
    -- Trim if too many
    if #self.healing_events > self.config.max_events then
        table.remove(self.healing_events, 1)
    end
    
    -- Update summary
    self:UpdateSummary(event)
    
    return true
end

function HealingCalculationEngine:UpdateSummary(event)
    local sourceKey = event.source_guid
    local destKey = event.dest_guid
    
    -- Create source summary if not exists
    if not self.healing_summary[sourceKey] then
        self.healing_summary[sourceKey] = {
            name = event.source_name,
            total_healing = 0,
            total_overheal = 0,
            total_hits = 0,
            total_crits = 0,
            total_absorbed = 0,
            by_target = {},
            by_spell = {},
        }
    end
    
    local summary = self.healing_summary[sourceKey]
    
    -- Update totals
    summary.total_healing = summary.total_healing + event.heal
    summary.total_overheal = summary.total_overheal + event.overheal
    summary.total_hits = summary.total_hits + 1
    
    if event.critical then
        summary.total_crits = summary.total_crits + 1
    end
    
    if event.absorbed and event.absorbed > 0 then
        summary.total_absorbed = summary.total_absorbed + event.absorbed
    end
    
    -- Track by target
    if not summary.by_target[destKey] then
        summary.by_target[destKey] = {
            name = event.dest_name,
            healing = 0,
            hits = 0,
            overheal = 0,
        }
    end
    
    summary.by_target[destKey].healing = summary.by_target[destKey].healing + event.heal
    summary.by_target[destKey].hits = summary.by_target[destKey].hits + 1
    summary.by_target[destKey].overheal = summary.by_target[destKey].overheal + event.overheal
    
    -- Track by spell
    if event.spell_id then
        if not summary.by_spell[event.spell_id] then
            summary.by_spell[event.spell_id] = {
                name = event.spell_name,
                healing = 0,
                hits = 0,
                crits = 0,
                overheal = 0,
            }
        end
        
        summary.by_spell[event.spell_id].healing = summary.by_spell[event.spell_id].healing + event.heal
        summary.by_spell[event.spell_id].hits = summary.by_spell[event.spell_id].hits + 1
        summary.by_spell[event.spell_id].overheal = summary.by_spell[event.spell_id].overheal + event.overheal
        
        if event.critical then
            summary.by_spell[event.spell_id].crits = summary.by_spell[event.spell_id].crits + 1
        end
    end
end

function HealingCalculationEngine:GetHealerStats(sourceGUID)
    if not sourceGUID or not self.healing_summary[sourceGUID] then
        return nil
    end
    
    local summary = self.healing_summary[sourceGUID]
    local effective = summary.total_healing - summary.total_overheal
    
    return {
        name = summary.name,
        total_healing = summary.total_healing,
        effective_healing = effective,
        total_overheal = summary.total_overheal,
        total_hits = summary.total_hits,
        total_crits = summary.total_crits,
        total_absorbed = summary.total_absorbed,
        avg_heal = summary.total_hits > 0 and (summary.total_healing / summary.total_hits) or 0,
        overheal_percent = summary.total_healing > 0 and (summary.total_overheal / summary.total_healing * 100) or 0,
        crit_percent = summary.total_hits > 0 and (summary.total_crits / summary.total_hits * 100) or 0,
        efficiency = summary.total_healing > 0 and (effective / summary.total_healing * 100) or 0,
    }
end

function HealingCalculationEngine:GetTargetHealing(sourceGUID, destGUID)
    if not sourceGUID or not self.healing_summary[sourceGUID] then
        return nil
    end
    
    local targetData = self.healing_summary[sourceGUID].by_target[destGUID]
    
    if not targetData then
        return nil
    end
    
    return {
        name = targetData.name,
        healing = targetData.healing,
        hits = targetData.hits,
        overheal = targetData.overheal,
        avg_heal = targetData.hits > 0 and (targetData.healing / targetData.hits) or 0,
        overheal_percent = targetData.healing > 0 and (targetData.overheal / targetData.healing * 100) or 0,
    }
end

function HealingCalculationEngine:GetSpellHealing(sourceGUID, spellId)
    if not sourceGUID or not spellId or not self.healing_summary[sourceGUID] then
        return nil
    end
    
    local spellData = self.healing_summary[sourceGUID].by_spell[spellId]
    
    if not spellData then
        return nil
    end
    
    return {
        name = spellData.name,
        healing = spellData.healing,
        hits = spellData.hits,
        crits = spellData.crits,
        overheal = spellData.overheal,
        avg_heal = spellData.hits > 0 and (spellData.healing / spellData.hits) or 0,
        crit_percent = spellData.hits > 0 and (spellData.crits / spellData.hits * 100) or 0,
        overheal_percent = spellData.healing > 0 and (spellData.overheal / spellData.healing * 100) or 0,
    }
end

function HealingCalculationEngine:GetAllHealerStats()
    local healers = {}
    
    for guid, summary in pairs(self.healing_summary) do
        local stats = self:GetHealerStats(guid)
        if stats then
            stats.guid = guid
            table.insert(healers, stats)
        end
    end
    
    -- Sort by healing descending
    table.sort(healers, function(a, b) return a.total_healing > b.total_healing end)
    
    return healers
end

function HealingCalculationEngine:GetTotalHealing()
    local total = 0
    
    for _, summary in pairs(self.healing_summary) do
        total = total + summary.total_healing
    end
    
    return total
end

function HealingCalculationEngine:GetTotalOverhealing()
    local total = 0
    
    for _, summary in pairs(self.healing_summary) do
        total = total + summary.total_overheal
    end
    
    return total
end

function HealingCalculationEngine:GetTotalEffectiveHealing()
    return self:GetTotalHealing() - self:GetTotalOverhealing()
end

function HealingCalculationEngine:GetAverageOverhealPercent()
    local total = self:GetTotalHealing()
    
    if total <= 0 then
        return 0
    end
    
    return (self:GetTotalOverhealing() / total) * 100
end

function HealingCalculationEngine:GetEventCount()
    return #self.healing_events
end

function HealingCalculationEngine:GetEventsByTimeWindow(startTime, endTime)
    local events = {}
    
    for _, event in ipairs(self.healing_events) do
        if event.timestamp >= startTime and event.timestamp <= endTime then
            table.insert(events, event)
        end
    end
    
    return events
end

function HealingCalculationEngine:ClearData()
    self.healing_events = {}
    self.healing_summary = {}
    self:Log("All healing data cleared")
end

function HealingCalculationEngine:GetStatus()
    return {
        enabled = self.enabled,
        event_count = self:GetEventCount(),
        max_events = self.config.max_events,
        total_healing = self:GetTotalHealing(),
        total_overheal = self:GetTotalOverhealing(),
        effective_healing = self:GetTotalEffectiveHealing(),
        healer_count = self:CountHealers(),
        avg_overheal_percent = string.format("%.1f", self:GetAverageOverhealPercent()),
    }
end

function HealingCalculationEngine:CountHealers()
    local count = 0
    
    for _ in pairs(self.healing_summary) do
        count = count + 1
    end
    
    return count
end

function HealingCalculationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[HealingCalculationEngine] " .. message)
    else
        print("[HealingCalculationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HEALCALC1 = "/healcalc"
    SlashCmdList["HEALCALC"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "summary" then
            local healers = HealingCalculationEngine:GetAllHealerStats()
            print("Healing Summary:")
            for i, healer in ipairs(healers) do
                print(string.format("  %d. %s: %.0f healing (%.1f%% overheal)", 
                      i, healer.name, healer.total_healing, healer.overheal_percent))
            end
        elseif cmd == "efficiency" then
            local healers = HealingCalculationEngine:GetAllHealerStats()
            print("Healing Efficiency:")
            for i, healer in ipairs(healers) do
                print(string.format("  %s: %.1f%% efficient", healer.name, healer.efficiency))
            end
        elseif cmd == "clear" then
            HealingCalculationEngine:ClearData()
            print("Healing data cleared")
        elseif cmd == "status" then
            local status = HealingCalculationEngine:GetStatus()
            print("Healing Calculator:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Healing Calculator Commands:")
            print("  /healcalc summary - Show healer summary")
            print("  /healcalc efficiency - Show healer efficiency")
            print("  /healcalc status - Show system status")
            print("  /healcalc clear - Clear all data")
        end
    end
end

return HealingCalculationEngine
