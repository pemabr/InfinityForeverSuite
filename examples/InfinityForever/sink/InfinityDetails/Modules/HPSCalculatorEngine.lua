-- HPSCalculatorEngine.lua - Calculate healing per second for all healers
-- Part of InfinityDetails addon suite
-- Provides accurate HPS calculations with per-segment and time-window support

local HPSCalculatorEngine = {}
HPSCalculatorEngine.enabled = false
HPSCalculatorEngine.db = nil
HPSCalculatorEngine.healer_healing = {}

-- Configuration
HPSCalculatorEngine.config = {
    enabled = true,
    calc_frequency = 1,  -- Calculate every 1 second
    min_healers = 1,
}

function HPSCalculatorEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.hps_data then
        self.db.hps_data = {
            healers = {},
            total_healing = 0,
            encounter_time = 0,
        }
    end
    
    self.healer_healing = self.db.hps_data
    self.enabled = true
    
    self:Log("Initialized HPS calculator")
end

function HPSCalculatorEngine:RecordHealing(healerGUID, healerName, healAmount, overhealAmount, timestamp)
    if not healerGUID or not healAmount or healAmount <= 0 then
        return false
    end
    
    -- Create healer entry if not exists
    if not self.healer_healing.healers[healerGUID] then
        self.healer_healing.healers[healerGUID] = {
            name = healerName,
            guid = healerGUID,
            total_healing = 0,
            total_overheal = 0,
            heal_events = 0,
            first_heal = timestamp or GetTime(),
            last_heal = timestamp or GetTime(),
            crits = 0,
            critical_healing = 0,
        }
    end
    
    local healerData = self.healer_healing.healers[healerGUID]
    
    -- Update healer stats
    healerData.total_healing = healerData.total_healing + healAmount
    healerData.total_overheal = healerData.total_overheal + (overhealAmount or 0)
    healerData.heal_events = healerData.heal_events + 1
    healerData.last_heal = timestamp or GetTime()
    
    return true
end

function HPSCalculatorEngine:RecordCritHeal(healerGUID, healerName, healAmount, timestamp)
    if not healerGUID or not healAmount then
        return false
    end
    
    if not self.healer_healing.healers[healerGUID] then
        self.healer_healing.healers[healerGUID] = {
            name = healerName,
            guid = healerGUID,
            total_healing = 0,
            total_overheal = 0,
            heal_events = 0,
            first_heal = timestamp or GetTime(),
            last_heal = timestamp or GetTime(),
            crits = 0,
            critical_healing = 0,
        }
    end
    
    local healerData = self.healer_healing.healers[healerGUID]
    healerData.crits = healerData.crits + 1
    healerData.critical_healing = healerData.critical_healing + healAmount
    
    return true
end

function HPSCalculatorEngine:CalculateHPS(healerGUID, startTime, endTime)
    if not healerGUID or not self.healer_healing.healers[healerGUID] then
        return 0
    end
    
    local healerData = self.healer_healing.healers[healerGUID]
    
    if not startTime then
        startTime = healerData.first_heal
    end
    
    if not endTime then
        endTime = healerData.last_heal
    end
    
    local duration = endTime - startTime
    
    if duration <= 0 then
        return 0
    end
    
    local hps = healerData.total_healing / duration
    
    return hps
end

function HPSCalculatorEngine:GetHealerHPS(healerGUID)
    if not healerGUID or not self.healer_healing.healers[healerGUID] then
        return 0
    end
    
    return self:CalculateHPS(healerGUID)
end

function HPSCalculatorEngine:GetHealerStats(healerGUID)
    if not healerGUID or not self.healer_healing.healers[healerGUID] then
        return nil
    end
    
    local healerData = self.healer_healing.healers[healerGUID]
    local duration = healerData.last_heal - healerData.first_heal
    local effectiveHealing = healerData.total_healing - healerData.total_overheal
    
    return {
        name = healerData.name,
        guid = healerGUID,
        total_healing = healerData.total_healing,
        effective_healing = effectiveHealing,
        total_overheal = healerData.total_overheal,
        heal_events = healerData.heal_events,
        hps = self:CalculateHPS(healerGUID),
        duration = duration,
        crits = healerData.crits,
        crit_percent = healerData.heal_events > 0 and (healerData.crits / healerData.heal_events * 100) or 0,
        critical_healing = healerData.critical_healing,
        avg_heal = healerData.heal_events > 0 and (healerData.total_healing / healerData.heal_events) or 0,
        avg_crit = healerData.crits > 0 and (healerData.critical_healing / healerData.crits) or 0,
        overheal_percent = healerData.total_healing > 0 and (healerData.total_overheal / healerData.total_healing * 100) or 0,
        efficiency = effectiveHealing > 0 and (effectiveHealing / healerData.total_healing * 100) or 0,
    }
end

function HPSCalculatorEngine:GetAllHealerHPS()
    local hps_list = {}
    
    for guid, healerData in pairs(self.healer_healing.healers) do
        local hps = self:GetHealerHPS(guid)
        
        table.insert(hps_list, {
            name = healerData.name,
            guid = guid,
            hps = hps,
        })
    end
    
    -- Sort by HPS descending
    table.sort(hps_list, function(a, b) return a.hps > b.hps end)
    
    return hps_list
end

function HPSCalculatorEngine:GetTopHealers(count)
    if not count or count <= 0 then
        count = 10
    end
    
    local hps_list = self:GetAllHealerHPS()
    local top_healers = {}
    
    for i = 1, math.min(count, #hps_list) do
        table.insert(top_healers, hps_list[i])
    end
    
    return top_healers
end

function HPSCalculatorEngine:GetTotalHealing()
    local total = 0
    
    for _, healerData in pairs(self.healer_healing.healers) do
        total = total + healerData.total_healing
    end
    
    return total
end

function HPSCalculatorEngine:GetTotalOverhealing()
    local total = 0
    
    for _, healerData in pairs(self.healer_healing.healers) do
        total = total + healerData.total_overheal
    end
    
    return total
end

function HPSCalculatorEngine:GetEncounterDuration()
    local minTime = math.huge
    local maxTime = 0
    
    for _, healerData in pairs(self.healer_healing.healers) do
        if healerData.first_heal < minTime then
            minTime = healerData.first_heal
        end
        
        if healerData.last_heal > maxTime then
            maxTime = healerData.last_heal
        end
    end
    
    if minTime == math.huge then
        return 0
    end
    
    return maxTime - minTime
end

function HPSCalculatorEngine:GetGroupHPS()
    local duration = self:GetEncounterDuration()
    
    if duration <= 0 then
        return 0
    end
    
    return self:GetTotalHealing() / duration
end

function HPSCalculatorEngine:GetHealerCount()
    local count = 0
    
    for _ in pairs(self.healer_healing.healers) do
        count = count + 1
    end
    
    return count
end

function HPSCalculatorEngine:ClearData()
    self.healer_healing.healers = {}
    self:Log("All HPS data cleared")
end

function HPSCalculatorEngine:GetStatus()
    local duration = self:GetEncounterDuration()
    
    return {
        enabled = self.enabled,
        healer_count = self:GetHealerCount(),
        total_healing = self:GetTotalHealing(),
        encounter_duration = duration,
        group_hps = self:GetGroupHPS(),
        total_overheal = self:GetTotalOverhealing(),
        avg_overheal_percent = duration > 0 and (self:GetTotalOverhealing() / self:GetTotalHealing() * 100) or 0,
    }
end

function HPSCalculatorEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[HPSCalculatorEngine] " .. message)
    else
        print("[HPSCalculatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HPS1 = "/hps"
    SlashCmdList["HPS"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "top" then
            local count = tonumber(args) or 10
            local topHPS = HPSCalculatorEngine:GetTopHealers(count)
            print("Top " .. count .. " Healers (HPS):")
            for i, healer in ipairs(topHPS) do
                print(string.format("  %d. %s: %.1f HPS", i, healer.name, healer.hps))
            end
        elseif cmd == "healer" then
            if args and args ~= "" then
                for guid, healerData in pairs(HPSCalculatorEngine.healer_healing.healers) do
                    if healerData.name == args then
                        local stats = HPSCalculatorEngine:GetHealerStats(guid)
                        if stats then
                            print("Healer: " .. stats.name)
                            print("  HPS: " .. string.format("%.1f", stats.hps))
                            print("  Total Healing: " .. stats.total_healing)
                            print("  Effective: " .. stats.effective_healing)
                            print("  Overheal: " .. string.format("%.1f", stats.overheal_percent) .. "%")
                            print("  Efficiency: " .. string.format("%.1f", stats.efficiency) .. "%")
                            print("  Crits: " .. stats.crits .. " (" .. string.format("%.1f", stats.crit_percent) .. "%)")
                        end
                        return
                    end
                end
                print("Healer not found: " .. args)
            else
                print("Usage: /hps healer <name>")
            end
        elseif cmd == "clear" then
            HPSCalculatorEngine:ClearData()
            print("HPS data cleared")
        elseif cmd == "status" then
            local status = HPSCalculatorEngine:GetStatus()
            print("HPS Calculator:")
            print("  Enabled: " .. tostring(status.enabled))
            print("  Healers: " .. status.healer_count)
            print("  Total Healing: " .. status.total_healing)
            print("  Duration: " .. string.format("%.1f", status.encounter_duration) .. "s")
            print("  Group HPS: " .. string.format("%.1f", status.group_hps))
            print("  Avg Overheal: " .. string.format("%.1f", status.avg_overheal_percent) .. "%")
        else
            print("HPS Calculator Commands:")
            print("  /hps top [count] - Show top healers (default 10)")
            print("  /hps healer <name> - Show detailed stats for healer")
            print("  /hps clear - Clear all HPS data")
            print("  /hps status - Show system status")
        end
    end
end

return HPSCalculatorEngine
