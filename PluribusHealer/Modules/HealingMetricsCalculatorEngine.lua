-- HealingMetricsCalculatorEngine.lua - Calculate and track real-time healing metrics
-- Part of PluribusHealer addon suite
-- Provides HPS, HPCT, overheal %, efficiency metrics

local HealingMetricsCalculatorEngine = {}
HealingMetricsCalculatorEngine.enabled = false
HealingMetricsCalculatorEngine.db = nil
HealingMetricsCalculatorEngine.healing_data = {}

-- Configuration
HealingMetricsCalculatorEngine.config = {
    enabled = true,
    track_history = true,
    history_window = 300,  -- 5 minutes in seconds
    update_frequency = 1,  -- 1 second updates
    calculate_efficiency = true,
}

function HealingMetricsCalculatorEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.healing_metrics then
        self.db.healing_metrics = {}
    end
    
    if not self.db.healing_history then
        self.db.healing_history = {}
    end
    
    self.healing_data = self.db.healing_metrics
    self.enabled = true
    
    self:Log("Initialized with " .. self.config.history_window .. "s history window")
end

function HealingMetricsCalculatorEngine:RecordHeal(healerName, targetName, spellName, healAmount, isCrit, isOverheal)
    if not healerName or not spellName or not healAmount then
        return false
    end
    
    -- Initialize healer data if needed
    if not self.healing_data[healerName] then
        self.healing_data[healerName] = {
            name = healerName,
            total_healing = 0,
            total_overheal = 0,
            total_casts = 0,
            crit_casts = 0,
            last_cast_time = 0,
            spell_counts = {},
        }
    end
    
    local healerData = self.healing_data[healerName]
    
    -- Update totals
    healerData.total_healing = healerData.total_healing + (healAmount - (isOverheal and healAmount or 0))
    if isOverheal then
        healerData.total_overheal = healerData.total_overheal + (healAmount - (UnitHealthMax(targetName) - UnitHealth(targetName)))
    end
    
    healerData.total_casts = healerData.total_casts + 1
    if isCrit then
        healerData.crit_casts = healerData.crit_casts + 1
    end
    
    -- Track spell usage
    if not healerData.spell_counts[spellName] then
        healerData.spell_counts[spellName] = 0
    end
    healerData.spell_counts[spellName] = healerData.spell_counts[spellName] + 1
    
    healerData.last_cast_time = GetTime()
    
    return true
end

function HealingMetricsCalculatorEngine:GetHealerMetrics(healerName)
    if not healerName or not self.healing_data[healerName] then
        return nil
    end
    
    local healerData = self.healing_data[healerName]
    local combatDuration = self:GetCombatDuration()
    
    -- Calculate HPS (healing per second)
    local hps = 0
    if combatDuration > 0 then
        hps = math.floor(healerData.total_healing / combatDuration)
    end
    
    -- Calculate overheal percentage
    local overHealPercent = 0
    if healerData.total_healing > 0 then
        overHealPercent = math.floor((healerData.total_overheal / (healerData.total_healing + healerData.total_overheal)) * 100)
    end
    
    -- Calculate crit percentage
    local critPercent = 0
    if healerData.total_casts > 0 then
        critPercent = math.floor((healerData.crit_casts / healerData.total_casts) * 100)
    end
    
    -- Get top spells
    local topSpells = self:GetTopSpells(healerName, 5)
    
    return {
        name = healerName,
        total_healing = healerData.total_healing,
        hps = hps,
        total_casts = healerData.total_casts,
        casts_per_minute = math.floor((healerData.total_casts / math.max(combatDuration / 60, 1))),
        overheal_percent = overHealPercent,
        crit_percent = critPercent,
        top_spells = topSpells,
        combat_time = combatDuration,
    }
end

function HealingMetricsCalculatorEngine:GetTopSpells(healerName, limit)
    if not healerName or not self.healing_data[healerName] then
        return {}
    end
    
    local healerData = self.healing_data[healerName]
    local spells = {}
    
    for spellName, count in pairs(healerData.spell_counts) do
        table.insert(spells, {
            name = spellName,
            casts = count,
        })
    end
    
    -- Sort by cast count
    table.sort(spells, function(a, b) return a.casts > b.casts end)
    
    -- Return top N
    local result = {}
    for i = 1, math.min(#spells, limit or 5) do
        table.insert(result, spells[i])
    end
    
    return result
end

function HealingMetricsCalculatorEngine:GetCombatDuration()
    -- In a real implementation, would track actual combat start time
    -- For now, return time since first recorded heal
    local firstHealTime = nil
    
    for _, healerData in pairs(self.healing_data) do
        if healerData.last_cast_time > 0 then
            if not firstHealTime or healerData.last_cast_time < firstHealTime then
                firstHealTime = healerData.last_cast_time
            end
        end
    end
    
    if not firstHealTime then
        return 0
    end
    
    return math.floor(GetTime() - firstHealTime)
end

function HealingMetricsCalculatorEngine:GetGroupHealingMetrics()
    local groupMetrics = {
        healers = {},
        total_healing = 0,
        total_hps = 0,
        healer_count = 0,
    }
    
    for healerName, _ in pairs(self.healing_data) do
        local metrics = self:GetHealerMetrics(healerName)
        if metrics then
            table.insert(groupMetrics.healers, metrics)
            groupMetrics.total_healing = groupMetrics.total_healing + metrics.total_healing
            groupMetrics.total_hps = groupMetrics.total_hps + metrics.hps
            groupMetrics.healer_count = groupMetrics.healer_count + 1
        end
    end
    
    -- Sort by HPS
    table.sort(groupMetrics.healers, function(a, b) return a.hps > b.hps end)
    
    return groupMetrics
end

function HealingMetricsCalculatorEngine:ResetMetrics()
    self.healing_data = {}
    self:Log("All metrics reset")
    return true
end

function HealingMetricsCalculatorEngine:ResetHealerMetrics(healerName)
    if not healerName or not self.healing_data[healerName] then
        return false
    end
    
    self.healing_data[healerName] = nil
    self:Log("Metrics reset for: " .. healerName)
    return true
end

function HealingMetricsCalculatorEngine:ExportMetrics()
    local export = {}
    
    for healerName, healerData in pairs(self.healing_data) do
        export[healerName] = self:GetHealerMetrics(healerName)
    end
    
    return export
end

function HealingMetricsCalculatorEngine:GetStatus()
    local healer_count = 0
    local total_healing = 0
    
    for _, healerData in pairs(self.healing_data) do
        healer_count = healer_count + 1
        total_healing = total_healing + healerData.total_healing
    end
    
    return {
        enabled = self.enabled,
        healer_count = healer_count,
        total_healing_recorded = total_healing,
        history_window = self.config.history_window,
        combat_duration = self:GetCombatDuration(),
    }
end

function HealingMetricsCalculatorEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[HealingMetricsCalculatorEngine] " .. message)
    else
        print("[HealingMetricsCalculatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HEALMETRICS1 = "/healmetrics"
    SlashCmdList["HEALMETRICS"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "healer" then
            if args and args ~= "" then
                local metrics = HealingMetricsCalculatorEngine:GetHealerMetrics(args)
                if metrics then
                    print("Healer: " .. args)
                    print("  Total Healing: " .. math.floor(metrics.total_healing))
                    print("  HPS: " .. metrics.hps)
                    print("  Total Casts: " .. metrics.total_casts)
                    print("  CPM: " .. metrics.casts_per_minute)
                    print("  Overheal %: " .. metrics.overheal_percent .. "%")
                    print("  Crit %: " .. metrics.crit_percent .. "%")
                    if #metrics.top_spells > 0 then
                        print("  Top Spells:")
                        for i, spell in ipairs(metrics.top_spells) do
                            print("    " .. i .. ". " .. spell.name .. " (" .. spell.casts .. "x)")
                        end
                    end
                else
                    print("Healer not found: " .. args)
                end
            else
                print("Usage: /healmetrics healer <name>")
            end
        elseif cmd == "group" then
            local groupMetrics = HealingMetricsCalculatorEngine:GetGroupHealingMetrics()
            print("Group Healing Metrics (" .. groupMetrics.healer_count .. " healers):")
            print("Total Healing: " .. math.floor(groupMetrics.total_healing))
            print("Total HPS: " .. groupMetrics.total_hps)
            if #groupMetrics.healers > 0 then
                print("Healers (by HPS):")
                for i, metrics in ipairs(groupMetrics.healers) do
                    print("  " .. i .. ". " .. metrics.name .. " - " .. metrics.hps .. " HPS (" .. math.floor(metrics.total_healing) .. " total)")
                end
            end
        elseif cmd == "reset" then
            if args == "confirm" then
                HealingMetricsCalculatorEngine:ResetMetrics()
                print("All metrics reset")
            else
                print("Usage: /healmetrics reset confirm")
            end
        elseif cmd == "status" then
            local status = HealingMetricsCalculatorEngine:GetStatus()
            print("Healing Metrics Calculator:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Healing Metrics Commands:")
            print("  /healmetrics healer <name> - Show healer stats")
            print("  /healmetrics group - Show group healing summary")
            print("  /healmetrics reset confirm - Reset all metrics")
            print("  /healmetrics status - Show system status")
        end
    end
end

return HealingMetricsCalculatorEngine
