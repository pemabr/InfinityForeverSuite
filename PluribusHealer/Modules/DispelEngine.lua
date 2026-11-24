-- DispelEngine.lua - Identify and highlight dispellable debuffs
-- Part of PluribusHealer addon suite
-- Shows which debuffs can be removed by player's class

local DispelEngine = {}
DispelEngine.enabled = false
DispelEngine.db = nil
DispelEngine.dispellable_buffs = {}

-- Dispel capabilities by class
DispelEngine.CLASS_DISPELS = {
    PRIEST = {
        ["Dispel Magic"] = { magic = true },
        ["Mass Dispel"] = { magic = true },
    },
    DRUID = {
        ["Remove Curse"] = { curse = true },
        ["Abolish Poison"] = { poison = true },
    },
    PALADIN = {
        ["Cleanse"] = { disease = true, poison = true },
        ["Divine Shield"] = { all = true },  -- Prevents buffs, doesn't remove
    },
    SHAMAN = {
        ["Cleanse Spirit"] = { curse = true },
        ["Poison Cleansing Totem"] = { poison = true },
    },
    ROGUE = {
        ["Cloak of Shadows"] = { all = true },  -- Prevents buffs
    },
    MAGE = {
        ["Spellsteal"] = { magic = true },
    },
}

-- Debuff types
DispelEngine.DEBUFF_TYPES = {
    magic = { name = "Magic", priority = "high", color = "FFFFFF" },
    disease = { name = "Disease", priority = "high", color = "8B4513" },
    poison = { name = "Poison", priority = "high", color = "00AA00" },
    curse = { name = "Curse", priority = "medium", color = "9400D3" },
    bleed = { name = "Bleed", priority = "medium", color = "FF0000" },
}

-- Configuration
DispelEngine.config = {
    enabled = true,
    highlight_dispellable = true,
    show_dispel_type = true,
    auto_target_dispel = false,
    max_dispel_targets = 5,
}

function DispelEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.dispellable then
        self.db.dispellable = {}
    end
    
    self.dispellable_buffs = self.db.dispellable
    self.enabled = true
    
    self:Log("Initialized")
end

function DispelEngine:GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

function DispelEngine:GetAvailableDispels()
    local playerClass = self:GetPlayerClass()
    
    if not playerClass or not self.CLASS_DISPELS[playerClass] then
        return {}
    end
    
    local dispels = {}
    for spell, types in pairs(self.CLASS_DISPELS[playerClass]) do
        table.insert(dispels, {
            spell = spell,
            types = types,
        })
    end
    
    return dispels
end

function DispelEngine:CanDispel(debuffType)
    local dispels = self:GetAvailableDispels()
    
    for _, dispel in ipairs(dispels) do
        if dispel.types.all then
            return true
        end
        
        for type, canDispel in pairs(dispel.types) do
            if type == debuffType and canDispel then
                return true
            end
        end
    end
    
    return false
end

function DispelEngine:FindDispellableDebuffs(playerName)
    if not playerName then
        return {}
    end
    
    local dispellable = {}
    
    -- Check all auras on player
    local index = 1
    while true do
        local name, texture, count, debuffType, duration, expirationTime, caster, isStealable = PluribusUtils:GetUnitAura(playerName, index, "HARMFUL")
        
        if not name then
            break
        end
        
        -- Check if this debuff type is dispellable
        local lowerType = debuffType and debuffType:lower() or ""
        if lowerType ~= "" and self:CanDispel(lowerType) then
            table.insert(dispellable, {
                name = name,
                type = lowerType,
                duration = duration,
                expires = expirationTime,
                priority = self.DEBUFF_TYPES[lowerType] and self.DEBUFF_TYPES[lowerType].priority or "low",
            })
        end
        
        index = index + 1
    end
    
    return dispellable
end

function DispelEngine:FindDispelTargets()
    local targets = {}
    
    local raidSize = GetNumRaidMembers()
    if raidSize == 0 then
        raidSize = GetNumPartyMembers()
        if raidSize == 0 then
            raidSize = 1
        end
    end
    
    for i = 1, raidSize do
        local unitID
        if GetNumRaidMembers() > 0 then
            unitID = "raid" .. i
        else
            unitID = "party" .. i
        end
        
        local name = UnitName(unitID)
        if name and UnitExists(unitID) then
            local dispellable = self:FindDispellableDebuffs(name)
            
            if #dispellable > 0 then
                table.insert(targets, {
                    name = name,
                    unit = unitID,
                    debuffs = dispellable,
                    debuff_count = #dispellable,
                    highest_priority = dispellable[1].priority,
                })
            end
        end
    end
    
    -- Sort by number of dispellable debuffs
    table.sort(targets, function(a, b)
        return a.debuff_count > b.debuff_count
    end)
    
    -- Limit to max targets
    local result = {}
    for i = 1, math.min(#targets, self.config.max_dispel_targets) do
        table.insert(result, targets[i])
    end
    
    return result
end

function DispelEngine:GetDispelPriority(debuffName)
    -- Get priority for a specific debuff
    local criticalDebuffs = {
        ["Mortal Strike"] = "critical",
        ["Silence"] = "critical",
        ["Fear"] = "critical",
        ["Stun"] = "critical",
        ["Polymorph"] = "high",
        ["Hex"] = "high",
    }
    
    return criticalDebuffs[debuffName] or "normal"
end

function DispelEngine:ShouldAutoDispel(debuffName, playerHealth)
    if not self.config.auto_target_dispel then
        return false
    end
    
    -- Auto dispel if critical or player low health
    local priority = self:GetDispelPriority(debuffName)
    
    if priority == "critical" then
        return true
    end
    
    -- Auto dispel if player is at critical health
    if playerHealth and playerHealth < 30 then
        return true
    end
    
    return false
end

function DispelEngine:GetDispelSpellForType(debuffType)
    local dispels = self:GetAvailableDispels()
    
    for _, dispel in ipairs(dispels) do
        for type, canDispel in pairs(dispel.types) do
            if (type == debuffType or type == "all") and canDispel then
                return dispel.spell
            end
        end
    end
    
    return nil
end

function DispelEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function DispelEngine:GetStatus()
    local dispels = self:GetAvailableDispels()
    
    return {
        enabled = self.enabled,
        player_class = self:GetPlayerClass(),
        available_dispels = #dispels,
        dispel_spells = self:CountTable(self.CLASS_DISPELS[self:GetPlayerClass()] or {}),
    }
end

function DispelEngine:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function DispelEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[DispelEngine] " .. message)
    else
        print("[DispelEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_DISPEL1 = "/dispel"
    SlashCmdList["DISPEL"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "status" then
            local status = DispelEngine:GetStatus()
            print("Dispel Engine Status (" .. status.player_class .. "):")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "targets" then
            local targets = DispelEngine:FindDispelTargets()
            if #targets > 0 then
                print("Players needing dispel (" .. #targets .. "):")
                for _, target in ipairs(targets) do
                    print(string.format("  %s: %d debuffs", target.name, target.debuff_count))
                    for _, debuff in ipairs(target.debuffs) do
                        print(string.format("    - %s (%s)", debuff.name, debuff.type))
                    end
                end
            else
                print("No dispel targets found")
            end
        elseif cmd == "check" then
            if args and args ~= "" then
                local dispellable = DispelEngine:FindDispellableDebuffs(args)
                if #dispellable > 0 then
                    print("Dispellable debuffs on " .. args .. ":")
                    for _, debuff in ipairs(dispellable) do
                        print(string.format("  %s (%s)", debuff.name, debuff.type))
                    end
                else
                    print("No dispellable debuffs on " .. args)
                end
            else
                print("Usage: /dispel check <player>")
            end
        else
            print("Dispel Engine Commands:")
            print("  /dispel status - Show system status")
            print("  /dispel targets - Show players needing dispel")
            print("  /dispel check <player> - Check dispellable debuffs")
        end
    end
end

return DispelEngine
