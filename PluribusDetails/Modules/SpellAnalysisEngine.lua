-- SpellAnalysisEngine.lua - Detailed spell-level breakdown of combat stats
-- Part of PluribusDetails addon suite
-- Provides spell damage, healing, and usage statistics

local SpellAnalysisEngine = {}
SpellAnalysisEngine.enabled = false
SpellAnalysisEngine.db = nil
SpellAnalysisEngine.spell_stats = {}

-- Configuration
SpellAnalysisEngine.config = {
    enabled = true,
    max_spells = 500,
}

function SpellAnalysisEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.spell_analysis then
        self.db.spell_analysis = {
            spells = {},
        }
    end
    
    self.spell_stats = self.db.spell_analysis.spells
    self.enabled = true
    
    self:Log("Initialized spell analysis engine")
end

function SpellAnalysisEngine:RecordSpellDamage(spellId, spellName, spellSchool, casterGUID, casterName,
                                             targetGUID, targetName, damage, isCritical)
    if not spellId or not spellName or not damage or damage <= 0 then
        return false
    end
    
    -- Create spell entry if not exists
    if not self.spell_stats[spellId] then
        self.spell_stats[spellId] = {
            id = spellId,
            name = spellName,
            school = spellSchool,
            type = "damage",
            stats = {
                total_damage = 0,
                hit_count = 0,
                crit_count = 0,
                total_crits = 0,
                min_damage = math.huge,
                max_damage = 0,
                casters = {},
                targets = {},
            }
        }
    end
    
    local spellData = self.spell_stats[spellId]
    local stats = spellData.stats
    
    -- Update stats
    stats.total_damage = stats.total_damage + damage
    stats.hit_count = stats.hit_count + 1
    
    if isCritical then
        stats.crit_count = stats.crit_count + 1
        stats.total_crits = stats.total_crits + damage
    end
    
    if damage < stats.min_damage then
        stats.min_damage = damage
    end
    
    if damage > stats.max_damage then
        stats.max_damage = damage
    end
    
    -- Track caster
    if casterGUID then
        if not stats.casters[casterGUID] then
            stats.casters[casterGUID] = {
                name = casterName,
                guid = casterGUID,
                damage = 0,
                hits = 0,
            }
        end
        
        stats.casters[casterGUID].damage = stats.casters[casterGUID].damage + damage
        stats.casters[casterGUID].hits = stats.casters[casterGUID].hits + 1
    end
    
    -- Track target
    if targetGUID then
        if not stats.targets[targetGUID] then
            stats.targets[targetGUID] = {
                name = targetName,
                guid = targetGUID,
                damage = 0,
                hits = 0,
            }
        end
        
        stats.targets[targetGUID].damage = stats.targets[targetGUID].damage + damage
        stats.targets[targetGUID].hits = stats.targets[targetGUID].hits + 1
    end
    
    return true
end

function SpellAnalysisEngine:RecordSpellHealing(spellId, spellName, spellSchool, casterGUID, casterName,
                                              targetGUID, targetName, healing, overheal, isCritical)
    if not spellId or not spellName or not healing or healing <= 0 then
        return false
    end
    
    -- Create spell entry if not exists
    if not self.spell_stats[spellId] then
        self.spell_stats[spellId] = {
            id = spellId,
            name = spellName,
            school = spellSchool,
            type = "healing",
            stats = {
                total_healing = 0,
                total_overheal = 0,
                hit_count = 0,
                crit_count = 0,
                total_crits = 0,
                min_heal = math.huge,
                max_heal = 0,
                casters = {},
                targets = {},
            }
        }
    end
    
    local spellData = self.spell_stats[spellId]
    local stats = spellData.stats
    
    -- Update stats
    stats.total_healing = stats.total_healing + healing
    stats.total_overheal = stats.total_overheal + (overheal or 0)
    stats.hit_count = stats.hit_count + 1
    
    if isCritical then
        stats.crit_count = stats.crit_count + 1
        stats.total_crits = stats.total_crits + healing
    end
    
    if healing < stats.min_heal then
        stats.min_heal = healing
    end
    
    if healing > stats.max_heal then
        stats.max_heal = healing
    end
    
    -- Track caster
    if casterGUID then
        if not stats.casters[casterGUID] then
            stats.casters[casterGUID] = {
                name = casterName,
                guid = casterGUID,
                healing = 0,
                hits = 0,
            }
        end
        
        stats.casters[casterGUID].healing = stats.casters[casterGUID].healing + healing
        stats.casters[casterGUID].hits = stats.casters[casterGUID].hits + 1
    end
    
    -- Track target
    if targetGUID then
        if not stats.targets[targetGUID] then
            stats.targets[targetGUID] = {
                name = targetName,
                guid = targetGUID,
                healing = 0,
                hits = 0,
            }
        end
        
        stats.targets[targetGUID].healing = stats.targets[targetGUID].healing + healing
        stats.targets[targetGUID].hits = stats.targets[targetGUID].hits + 1
    end
    
    return true
end

function SpellAnalysisEngine:GetSpellStats(spellId)
    if not spellId or not self.spell_stats[spellId] then
        return nil
    end
    
    local spellData = self.spell_stats[spellId]
    local stats = spellData.stats
    
    if spellData.type == "damage" then
        return {
            id = spellId,
            name = spellData.name,
            type = "damage",
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
    else
        return {
            id = spellId,
            name = spellData.name,
            type = "healing",
            total_healing = stats.total_healing,
            total_overheal = stats.total_overheal,
            hit_count = stats.hit_count,
            crits = stats.crit_count,
            crit_healing = stats.total_crits,
            avg_heal = stats.hit_count > 0 and (stats.total_healing / stats.hit_count) or 0,
            avg_crit = stats.crit_count > 0 and (stats.total_crits / stats.crit_count) or 0,
            crit_percent = stats.hit_count > 0 and (stats.crit_count / stats.hit_count * 100) or 0,
            min_heal = stats.min_heal,
            max_heal = stats.max_heal,
            overheal_percent = stats.total_healing > 0 and (stats.total_overheal / stats.total_healing * 100) or 0,
        }
    end
end

function SpellAnalysisEngine:GetTopDamageSpells(count)
    if not count or count <= 0 then
        count = 10
    end
    
    local spells = {}
    
    for spellId, spellData in pairs(self.spell_stats) do
        if spellData.type == "damage" then
            table.insert(spells, {
                id = spellId,
                name = spellData.name,
                damage = spellData.stats.total_damage,
            })
        end
    end
    
    -- Sort by damage descending
    table.sort(spells, function(a, b) return a.damage > b.damage end)
    
    local top = {}
    for i = 1, math.min(count, #spells) do
        table.insert(top, spells[i])
    end
    
    return top
end

function SpellAnalysisEngine:GetTopHealingSpells(count)
    if not count or count <= 0 then
        count = 10
    end
    
    local spells = {}
    
    for spellId, spellData in pairs(self.spell_stats) do
        if spellData.type == "healing" then
            table.insert(spells, {
                id = spellId,
                name = spellData.name,
                healing = spellData.stats.total_healing,
            })
        end
    end
    
    -- Sort by healing descending
    table.sort(spells, function(a, b) return a.healing > b.healing end)
    
    local top = {}
    for i = 1, math.min(count, #spells) do
        table.insert(top, spells[i])
    end
    
    return top
end

function SpellAnalysisEngine:GetSpellCasters(spellId)
    if not spellId or not self.spell_stats[spellId] then
        return {}
    end
    
    local casters = {}
    
    for guid, casterData in pairs(self.spell_stats[spellId].stats.casters) do
        table.insert(casters, {
            name = casterData.name,
            guid = guid,
            damage = casterData.damage or casterData.healing or 0,
            hits = casterData.hits,
        })
    end
    
    -- Sort by damage/healing descending
    table.sort(casters, function(a, b) return a.damage > b.damage end)
    
    return casters
end

function SpellAnalysisEngine:GetSpellTargets(spellId)
    if not spellId or not self.spell_stats[spellId] then
        return {}
    end
    
    local targets = {}
    
    for guid, targetData in pairs(self.spell_stats[spellId].stats.targets) do
        table.insert(targets, {
            name = targetData.name,
            guid = guid,
            damage = targetData.damage or targetData.healing or 0,
            hits = targetData.hits,
        })
    end
    
    -- Sort by damage/healing descending
    table.sort(targets, function(a, b) return a.damage > b.damage end)
    
    return targets
end

function SpellAnalysisEngine:GetTotalSpells()
    return #self.spell_stats
end

function SpellAnalysisEngine:ClearData()
    self.spell_stats = {}
    self:Log("All spell analysis data cleared")
end

function SpellAnalysisEngine:GetStatus()
    local damageSpells = 0
    local healingSpells = 0
    
    for _, spellData in pairs(self.spell_stats) do
        if spellData.type == "damage" then
            damageSpells = damageSpells + 1
        else
            healingSpells = healingSpells + 1
        end
    end
    
    return {
        enabled = self.enabled,
        total_spells = self:GetTotalSpells(),
        damage_spells = damageSpells,
        healing_spells = healingSpells,
    }
end

function SpellAnalysisEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[SpellAnalysisEngine] " .. message)
    else
        print("[SpellAnalysisEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_SPELL1 = "/spell"
    SlashCmdList["SPELL"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "dmg" then
            local count = tonumber(args) or 10
            local top = SpellAnalysisEngine:GetTopDamageSpells(count)
            print("Top " .. count .. " Damage Spells:")
            for i, spell in ipairs(top) do
                print(string.format("  %d. %s: %.0f damage", i, spell.name, spell.damage))
            end
        elseif cmd == "heal" then
            local count = tonumber(args) or 10
            local top = SpellAnalysisEngine:GetTopHealingSpells(count)
            print("Top " .. count .. " Healing Spells:")
            for i, spell in ipairs(top) do
                print(string.format("  %d. %s: %.0f healing", i, spell.name, spell.healing))
            end
        elseif cmd == "clear" then
            SpellAnalysisEngine:ClearData()
            print("Spell analysis data cleared")
        elseif cmd == "status" then
            local status = SpellAnalysisEngine:GetStatus()
            print("Spell Analysis:")
            print("  Total Spells: " .. status.total_spells)
            print("  Damage Spells: " .. status.damage_spells)
            print("  Healing Spells: " .. status.healing_spells)
        else
            print("Spell Analysis Commands:")
            print("  /spell dmg [count] - Top damage spells (default 10)")
            print("  /spell heal [count] - Top healing spells (default 10)")
            print("  /spell status - Show system status")
            print("  /spell clear - Clear all data")
        end
    end
end

return SpellAnalysisEngine
