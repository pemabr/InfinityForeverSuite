-- TargetAnalysisEngine.lua - Track damage and interactions by target
-- Part of PluribusDetails addon suite
-- Provides target-level damage breakdown and enemy analysis

local TargetAnalysisEngine = {}
TargetAnalysisEngine.enabled = false
TargetAnalysisEngine.db = nil
TargetAnalysisEngine.target_data = {}

-- Configuration
TargetAnalysisEngine.config = {
    enabled = true,
    max_targets = 100,
}

function TargetAnalysisEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.target_analysis then
        self.db.target_analysis = {
            targets = {},
        }
    end
    
    self.target_data = self.db.target_analysis.targets
    self.enabled = true
    
    self:Log("Initialized target analysis engine")
end

function TargetAnalysisEngine:RecordDamageToTarget(targetGUID, targetName, targetType, damageAmount, damageType, 
                                                   casterGUID, casterName, spellName, spellId, isCritical)
    if not targetGUID or not damageAmount or damageAmount <= 0 then
        return false
    end
    
    -- Create target entry if not exists
    if not self.target_data[targetGUID] then
        self.target_data[targetGUID] = {
            name = targetName,
            guid = targetGUID,
            type = targetType or "unknown",
            stats = {
                total_damage = 0,
                hit_count = 0,
                crit_count = 0,
                total_crits = 0,
                min_damage = math.huge,
                max_damage = 0,
                by_caster = {},
                by_spell = {},
            },
            last_hit = GetTime(),
        }
    end
    
    local targetStats = self.target_data[targetGUID].stats
    
    -- Update stats
    targetStats.total_damage = targetStats.total_damage + damageAmount
    targetStats.hit_count = targetStats.hit_count + 1
    
    if isCritical then
        targetStats.crit_count = targetStats.crit_count + 1
        targetStats.total_crits = targetStats.total_crits + damageAmount
    end
    
    if damageAmount < targetStats.min_damage then
        targetStats.min_damage = damageAmount
    end
    
    if damageAmount > targetStats.max_damage then
        targetStats.max_damage = damageAmount
    end
    
    self.target_data[targetGUID].last_hit = GetTime()
    
    -- Track by caster
    if casterGUID then
        if not targetStats.by_caster[casterGUID] then
            targetStats.by_caster[casterGUID] = {
                name = casterName,
                guid = casterGUID,
                damage = 0,
                hits = 0,
            }
        end
        
        targetStats.by_caster[casterGUID].damage = targetStats.by_caster[casterGUID].damage + damageAmount
        targetStats.by_caster[casterGUID].hits = targetStats.by_caster[casterGUID].hits + 1
    end
    
    -- Track by spell
    if spellId then
        if not targetStats.by_spell[spellId] then
            targetStats.by_spell[spellId] = {
                name = spellName,
                spell_id = spellId,
                damage = 0,
                hits = 0,
            }
        end
        
        targetStats.by_spell[spellId].damage = targetStats.by_spell[spellId].damage + damageAmount
        targetStats.by_spell[spellId].hits = targetStats.by_spell[spellId].hits + 1
    end
    
    return true
end

function TargetAnalysisEngine:GetTargetStats(targetGUID)
    if not targetGUID or not self.target_data[targetGUID] then
        return nil
    end
    
    local targetInfo = self.target_data[targetGUID]
    local stats = targetInfo.stats
    
    return {
        name = targetInfo.name,
        guid = targetGUID,
        type = targetInfo.type,
        total_damage = stats.total_damage,
        hit_count = stats.hit_count,
        crits = stats.crit_count,
        crit_damage = stats.total_crits,
        avg_hit = stats.hit_count > 0 and (stats.total_damage / stats.hit_count) or 0,
        avg_crit = stats.crit_count > 0 and (stats.total_crits / stats.crit_count) or 0,
        crit_percent = stats.hit_count > 0 and (stats.crit_count / stats.hit_count * 100) or 0,
        min_damage = stats.min_damage,
        max_damage = stats.max_damage,
    }
end

function TargetAnalysisEngine:GetTargetDamageBySpell(targetGUID)
    if not targetGUID or not self.target_data[targetGUID] then
        return {}
    end
    
    local spells = {}
    
    for spellId, spellData in pairs(self.target_data[targetGUID].stats.by_spell) do
        table.insert(spells, {
            name = spellData.name,
            spell_id = spellId,
            damage = spellData.damage,
            hits = spellData.hits,
            avg_hit = spellData.hits > 0 and (spellData.damage / spellData.hits) or 0,
        })
    end
    
    -- Sort by damage descending
    table.sort(spells, function(a, b) return a.damage > b.damage end)
    
    return spells
end

function TargetAnalysisEngine:GetTargetDamageByCaster(targetGUID)
    if not targetGUID or not self.target_data[targetGUID] then
        return {}
    end
    
    local casters = {}
    
    for casterGUID, casterData in pairs(self.target_data[targetGUID].stats.by_caster) do
        table.insert(casters, {
            name = casterData.name,
            guid = casterGUID,
            damage = casterData.damage,
            hits = casterData.hits,
            avg_hit = casterData.hits > 0 and (casterData.damage / casterData.hits) or 0,
        })
    end
    
    -- Sort by damage descending
    table.sort(casters, function(a, b) return a.damage > b.damage end)
    
    return casters
end

function TargetAnalysisEngine:GetAllTargets()
    local targets = {}
    
    for guid, targetInfo in pairs(self.target_data) do
        table.insert(targets, {
            name = targetInfo.name,
            guid = guid,
            type = targetInfo.type,
            damage = targetInfo.stats.total_damage,
        })
    end
    
    -- Sort by damage descending
    table.sort(targets, function(a, b) return a.damage > b.damage end)
    
    return targets
end

function TargetAnalysisEngine:GetTargetsByType(targetType)
    if not targetType then
        return {}
    end
    
    local targets = {}
    
    for guid, targetInfo in pairs(self.target_data) do
        if targetInfo.type == targetType then
            table.insert(targets, {
                name = targetInfo.name,
                guid = guid,
                damage = targetInfo.stats.total_damage,
            })
        end
    end
    
    -- Sort by damage descending
    table.sort(targets, function(a, b) return a.damage > b.damage end)
    
    return targets
end

function TargetAnalysisEngine:GetTopTargets(count)
    if not count or count <= 0 then
        count = 10
    end
    
    local targets = self:GetAllTargets()
    local top = {}
    
    for i = 1, math.min(count, #targets) do
        table.insert(top, targets[i])
    end
    
    return top
end

function TargetAnalysisEngine:GetTotalTargets()
    local count = 0
    
    for _ in pairs(self.target_data) do
        count = count + 1
    end
    
    return count
end

function TargetAnalysisEngine:GetTotalDamage()
    local total = 0
    
    for _, targetInfo in pairs(self.target_data) do
        total = total + targetInfo.stats.total_damage
    end
    
    return total
end

function TargetAnalysisEngine:ClearData()
    self.target_data = {}
    self:Log("All target analysis data cleared")
end

function TargetAnalysisEngine:GetStatus()
    return {
        enabled = self.enabled,
        total_targets = self:GetTotalTargets(),
        total_damage = self:GetTotalDamage(),
    }
end

function TargetAnalysisEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[TargetAnalysisEngine] " .. message)
    else
        print("[TargetAnalysisEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_TARGET1 = "/targetbd"
    SlashCmdList["TARGET"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "top" then
            local count = tonumber(args) or 10
            local top = TargetAnalysisEngine:GetTopTargets(count)
            print("Top " .. count .. " Targets:")
            for i, target in ipairs(top) do
                print(string.format("  %d. %s: %.0f damage", i, target.name, target.damage))
            end
        elseif cmd == "spells" then
            if args and args ~= "" then
                for guid, targetInfo in pairs(TargetAnalysisEngine.target_data) do
                    if targetInfo.name == args then
                        local spells = TargetAnalysisEngine:GetTargetDamageBySpell(guid)
                        print("Spells vs " .. args .. ":")
                        for _, spell in ipairs(spells) do
                            print(string.format("  %s: %.0f damage", spell.name, spell.damage))
                        end
                        return
                    end
                end
                print("Target not found: " .. args)
            else
                print("Usage: /targetbd spells <name>")
            end
        elseif cmd == "casters" then
            if args and args ~= "" then
                for guid, targetInfo in pairs(TargetAnalysisEngine.target_data) do
                    if targetInfo.name == args then
                        local casters = TargetAnalysisEngine:GetTargetDamageByCaster(guid)
                        print("Damage on " .. args .. " by:")
                        for _, caster in ipairs(casters) do
                            print(string.format("  %s: %.0f damage", caster.name, caster.damage))
                        end
                        return
                    end
                end
                print("Target not found: " .. args)
            else
                print("Usage: /targetbd casters <name>")
            end
        elseif cmd == "clear" then
            TargetAnalysisEngine:ClearData()
            print("Target analysis data cleared")
        elseif cmd == "status" then
            local status = TargetAnalysisEngine:GetStatus()
            print("Target Analysis:")
            print("  Targets: " .. status.total_targets)
            print("  Total Damage: " .. status.total_damage)
        else
            print("Target Analysis Commands:")
            print("  /targetbd top [count] - Top targets by damage")
            print("  /targetbd spells <name> - Show damage spells used vs target")
            print("  /targetbd casters <name> - Show who damaged target")
            print("  /targetbd status - Show system status")
            print("  /targetbd clear - Clear all data")
        end
    end
end

return TargetAnalysisEngine
