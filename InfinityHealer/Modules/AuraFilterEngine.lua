-- AuraFilterEngine.lua - Filter and display only relevant auras
-- Part of InfinityHealer addon suite
-- Manages which buffs/debuffs to show based on configurable criteria

local AuraFilterEngine = {}
AuraFilterEngine.enabled = false
AuraFilterEngine.db = nil
AuraFilterEngine.filter_rules = {}
AuraFilterEngine.filter_presets = {}

-- Configuration
AuraFilterEngine.config = {
    enabled = true,
    filter_mode = "healer",  -- healer, tank, dps, custom
    max_buffs_shown = 5,
    max_debuffs_shown = 8,
    show_self_buffs = true,
    show_party_buffs = true,
    show_raid_buffs = false,
    priority_dangerous_first = true,
}

function AuraFilterEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.aura_filters then
        self.db.aura_filters = {}
    end
    
    self.filter_rules = self.db.aura_filters
    self:InitializePresets()
    self.enabled = true
    
    self:Log("Initialized with " .. self:CountPresets() .. " filter presets")
end

function AuraFilterEngine:InitializePresets()
    -- Healer filter preset
    self.filter_presets.healer = {
        name = "Healer",
        buffs_to_show = {
            ["Power Word: Fortitude"] = true,
            ["Mark of the Wild"] = true,
            ["Blessing of Kings"] = true,
            ["Blessing of Might"] = true,
            ["Stamina"] = true,
            ["Divine Spirit"] = true,
            ["Power Infusion"] = true,
        },
        debuffs_to_show = {
            ["Silence"] = true,
            ["Fear"] = true,
            ["Stun"] = true,
            ["Mortal Strike"] = true,
            ["Dispel Magic"] = true,
            ["Poison"] = true,
            ["Disease"] = true,
            ["Curse"] = true,
        },
        ignore_buffs = {
            ["Tracking"] = true,
            ["Stealth"] = true,
        },
    }
    
    -- Tank filter preset
    self.filter_presets.tank = {
        name = "Tank",
        buffs_to_show = {
            ["Power Word: Fortitude"] = true,
            ["Stamina"] = true,
            ["Blessing of Kings"] = true,
            ["Blessing of Sanctuary"] = true,
            ["Mark of the Wild"] = true,
            ["Thorns"] = true,
            ["Armor"] = true,
        },
        debuffs_to_show = {
            ["Mortal Strike"] = true,
            ["Bleed"] = true,
            ["Stun"] = true,
            ["Fear"] = true,
            ["Disarm"] = true,
        },
        ignore_buffs = {
            ["Tracking"] = true,
            ["Stealth"] = true,
        },
    }
    
    -- DPS filter preset
    self.filter_presets.dps = {
        name = "DPS",
        buffs_to_show = {
            ["Power Word: Fortitude"] = true,
            ["Blessing of Might"] = true,
            ["Haste"] = true,
            ["Power Infusion"] = true,
        },
        debuffs_to_show = {
            ["Silenced"] = true,
            ["Feared"] = true,
            ["Stunned"] = true,
            ["Disarmed"] = true,
        },
        ignore_buffs = {
            ["Tracking"] = true,
            ["Stealth"] = true,
        },
    }
end

function AuraFilterEngine:SetFilterMode(mode)
    if not self.filter_presets[mode] then
        self:Log("Invalid filter mode: " .. mode)
        return false
    end
    
    self.config.filter_mode = mode
    self:Log("Filter mode changed to: " .. mode)
    
    return true
end

function AuraFilterEngine:GetActivePreset()
    return self.filter_presets[self.config.filter_mode]
end

function AuraFilterEngine:ShouldShowBuff(buffName, playerRole)
    local preset = self:GetActivePreset()
    
    if not preset then
        return false
    end
    
    -- Check if explicitly ignored
    if preset.ignore_buffs and preset.ignore_buffs[buffName] then
        return false
    end
    
    -- Check if explicitly shown
    if preset.buffs_to_show and preset.buffs_to_show[buffName] then
        return true
    end
    
    -- Default: don't show
    return false
end

function AuraFilterEngine:ShouldShowDebuff(debuffName, debuffType, priority)
    local preset = self:GetActivePreset()
    
    if not preset then
        return false
    end
    
    -- Critical debuffs always shown
    if priority == "critical" then
        return true
    end
    
    -- Check if explicitly shown
    if preset.debuffs_to_show and preset.debuffs_to_show[debuffName] then
        return true
    end
    
    -- High priority with dangerous types
    if priority == "high" and (debuffType == "poison" or debuffType == "disease" or debuffType == "curse") then
        return true
    end
    
    return false
end

function AuraFilterEngine:FilterBuffs(buffs, maxCount)
    if not buffs or #buffs == 0 then
        return {}
    end
    
    maxCount = maxCount or self.config.max_buffs_shown
    local result = {}
    
    for _, buff in ipairs(buffs) do
        if self:ShouldShowBuff(buff.name) then
            table.insert(result, buff)
        end
        
        if #result >= maxCount then
            break
        end
    end
    
    return result
end

function AuraFilterEngine:FilterDebuffs(debuffs, maxCount)
    if not debuffs or #debuffs == 0 then
        return {}
    end
    
    maxCount = maxCount or self.config.max_debuffs_shown
    local result = {}
    
    -- Sort by priority if configured
    if self.config.priority_dangerous_first then
        table.sort(debuffs, function(a, b)
            local priorityA = self:GetDebuffPriority(a.name)
            local priorityB = self:GetDebuffPriority(b.name)
            
            if priorityA ~= priorityB then
                local orderA = self:GetPriorityOrder(priorityA)
                local orderB = self:GetPriorityOrder(priorityB)
                return orderA < orderB
            end
            
            return a.name < b.name
        end)
    end
    
    for _, debuff in ipairs(debuffs) do
        if self:ShouldShowDebuff(debuff.name, debuff.type, debuff.priority) then
            table.insert(result, debuff)
        end
        
        if #result >= maxCount then
            break
        end
    end
    
    return result
end

function AuraFilterEngine:GetDebuffPriority(debuffName)
    local criticalDebuffs = {
        ["Mortal Strike"] = "critical",
        ["Silence"] = "critical",
        ["Fear"] = "critical",
        ["Stun"] = "critical",
        ["Polymorph"] = "high",
    }
    
    return criticalDebuffs[debuffName] or "normal"
end

function AuraFilterEngine:GetPriorityOrder(priority)
    local order = {
        critical = 1,
        high = 2,
        medium = 3,
        normal = 4,
    }
    
    return order[priority] or 999
end

function AuraFilterEngine:AddCustomRule(ruleName, ruleConfig)
    if not ruleName or not ruleConfig then
        return false
    end
    
    self.filter_rules[ruleName] = ruleConfig
    
    self:Log("Custom filter rule added: " .. ruleName)
    
    return true
end

function AuraFilterEngine:RemoveCustomRule(ruleName)
    if not self.filter_rules[ruleName] then
        return false
    end
    
    self.filter_rules[ruleName] = nil
    
    self:Log("Custom filter rule removed: " .. ruleName)
    
    return true
end

function AuraFilterEngine:GetFilterStats()
    local preset = self:GetActivePreset()
    
    if not preset then
        return nil
    end
    
    return {
        mode = self.config.filter_mode,
        buffs_in_preset = self:CountTable(preset.buffs_to_show),
        debuffs_in_preset = self:CountTable(preset.debuffs_to_show),
        custom_rules = self:CountTable(self.filter_rules),
        max_buffs_shown = self.config.max_buffs_shown,
        max_debuffs_shown = self.config.max_debuffs_shown,
    }
end

function AuraFilterEngine:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function AuraFilterEngine:CountPresets()
    local count = 0
    for _ in pairs(self.filter_presets) do
        count = count + 1
    end
    return count
end

function AuraFilterEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function AuraFilterEngine:GetStatus()
    return {
        enabled = self.enabled,
        filter_mode = self.config.filter_mode,
        total_presets = self:CountPresets(),
        custom_rules = self:CountTable(self.filter_rules),
    }
end

function AuraFilterEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[AuraFilterEngine] " .. message)
    else
        print("[AuraFilterEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_AURAFILTER1 = "/aurafilter"
    SlashCmdList["AURAFILTER"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "mode" then
            if args and args ~= "" then
                if AuraFilterEngine:SetFilterMode(args) then
                    print("Filter mode: " .. args)
                else
                    print("Invalid mode: " .. args)
                end
            else
                print("Available modes: healer, tank, dps, custom")
            end
        elseif cmd == "status" then
            local status = AuraFilterEngine:GetStatus()
            print("Aura Filter Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "stats" then
            local stats = AuraFilterEngine:GetFilterStats()
            if stats then
                print("Filter Statistics (" .. stats.mode .. "):")
                for k, v in pairs(stats) do
                    print("  " .. k .. ": " .. tostring(v))
                end
            end
        else
            print("Aura Filter Commands:")
            print("  /aurafilter mode <healer|tank|dps> - Set filter mode")
            print("  /aurafilter status - Show system status")
            print("  /aurafilter stats - Show filter statistics")
        end
    end
end

return AuraFilterEngine
