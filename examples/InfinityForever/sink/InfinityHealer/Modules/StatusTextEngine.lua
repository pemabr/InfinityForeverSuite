-- StatusTextEngine.lua - Display player status info (health %, absorbs, mana)
-- Part of InfinityHealer addon suite
-- Shows formatted status text on frames

local StatusTextEngine = {}
StatusTextEngine.enabled = false
StatusTextEngine.db = nil
StatusTextEngine.status_cache = {}

-- Configuration
StatusTextEngine.config = {
    enabled = true,
    show_health_percent = true,
    show_mana_percent = true,
    show_absorbs = true,
    show_buffs = false,
    text_size = 10,
    update_frequency = 0.5,
    format_numbers = true,  -- Show 1.2k instead of 1200
    abbreviate = true,  -- Use "pwr" instead of "Power"
}

function StatusTextEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.status_cache then
        self.db.status_cache = {}
    end
    
    self.status_cache = self.db.status_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function StatusTextEngine:FormatNumber(num)
    if not num or num == 0 then
        return "0"
    end
    
    if not self.config.format_numbers then
        return tostring(math.floor(num))
    end
    
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

function StatusTextEngine:GetHealthStatus(unitID)
    if not unitID or not UnitExists(unitID) then
        return nil
    end
    
    local health = UnitHealth(unitID)
    local maxHealth = UnitHealthMax(unitID)
    
    if maxHealth <= 0 then
        maxHealth = 100
    end
    
    local healthPercent = (health / maxHealth) * 100
    
    return {
        health = health,
        max_health = maxHealth,
        health_percent = healthPercent,
        formatted_health = self:FormatNumber(health),
        formatted_max = self:FormatNumber(maxHealth),
    }
end

function StatusTextEngine:GetManaStatus(unitID)
    if not unitID or not UnitExists(unitID) then
        return nil
    end
    
    local mana = UnitMana(unitID)
    local maxMana = UnitManaMax(unitID)
    
    if maxMana <= 0 then
        return {
            mana = 0,
            max_mana = 0,
            mana_percent = 0,
            formatted_mana = "0",
            formatted_max = "0",
        }
    end
    
    local manaPercent = (mana / maxMana) * 100
    
    return {
        mana = mana,
        max_mana = maxMana,
        mana_percent = manaPercent,
        formatted_mana = self:FormatNumber(mana),
        formatted_max = self:FormatNumber(maxMana),
    }
end

function StatusTextEngine:GetAbsorbStatus(unitID)
    if not unitID or not UnitExists(unitID) then
        return nil
    end
    
    -- Get absorbs (shields)
    local absorbs = UnitGetTotalAbsorbs(unitID) or 0
    
    return {
        absorbs = absorbs,
        formatted_absorbs = self:FormatNumber(absorbs),
    }
end

function StatusTextEngine:BuildStatusText(unitID, includeHealth, includeMana, includeAbsorbs)
    if not unitID then
        return ""
    end
    
    local parts = {}
    
    -- Health
    if includeHealth or self.config.show_health_percent then
        local health = self:GetHealthStatus(unitID)
        if health then
            table.insert(parts, math.floor(health.health_percent) .. "%")
        end
    end
    
    -- Mana
    if includeMana or self.config.show_mana_percent then
        local mana = self:GetManaStatus(unitID)
        if mana and mana.max_mana > 0 then
            table.insert(parts, "M:" .. math.floor(mana.mana_percent) .. "%")
        end
    end
    
    -- Absorbs
    if includeAbsorbs or self.config.show_absorbs then
        local absorb = self:GetAbsorbStatus(unitID)
        if absorb and absorb.absorbs > 0 then
            table.insert(parts, "S:" .. absorb.formatted_absorbs)
        end
    end
    
    return table.concat(parts, " / ")
end

function StatusTextEngine:BuildComprehensiveStatus(unitID)
    if not unitID or not UnitExists(unitID) then
        return nil
    end
    
    local name = UnitName(unitID)
    local health = self:GetHealthStatus(unitID)
    local mana = self:GetManaStatus(unitID)
    local absorb = self:GetAbsorbStatus(unitID)
    
    return {
        unit = unitID,
        name = name,
        health = health,
        mana = mana,
        absorbs = absorb,
        status_text = self:BuildStatusText(unitID),
        timestamp = GetTime(),
    }
end

function StatusTextEngine:GetStatusForGroup(groupID)
    -- Get status for entire group
    local statuses = {}
    
    for i = 1, 5 do
        local unitID = "raid" .. (groupID - 1) * 5 + i
        
        if UnitExists(unitID) then
            local status = self:BuildComprehensiveStatus(unitID)
            if status then
                table.insert(statuses, status)
            end
        end
    end
    
    return statuses
end

function StatusTextEngine:FormatLongHealth(unitID)
    local health = self:GetHealthStatus(unitID)
    local mana = self:GetManaStatus(unitID)
    local absorb = self:GetAbsorbStatus(unitID)
    
    if not health then
        return ""
    end
    
    local text = string.format("%s / %s",
        health.formatted_health,
        health.formatted_max
    )
    
    if mana and mana.max_mana > 0 then
        text = text .. string.format(" (%s / %s)",
            mana.formatted_mana,
            mana.formatted_max
        )
    end
    
    if absorb and absorb.absorbs > 0 then
        text = text .. " [" .. absorb.formatted_absorbs .. "]"
    end
    
    return text
end

function StatusTextEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function StatusTextEngine:GetStatus()
    return {
        enabled = self.enabled,
        show_health = self.config.show_health_percent,
        show_mana = self.config.show_mana_percent,
        show_absorbs = self.config.show_absorbs,
        format_numbers = self.config.format_numbers,
    }
end

function StatusTextEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[StatusTextEngine] " .. message)
    else
        print("[StatusTextEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_STATUSTEXT1 = "/statustext"
    SlashCmdList["STATUSTEXT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            if args and args ~= "" then
                local status = StatusTextEngine:BuildComprehensiveStatus(args)
                if status then
                    print("Status for " .. status.name .. ":")
                    print("  Health: " .. status.health.formatted_health .. "/" .. status.health.formatted_max .. " (" .. math.floor(status.health.health_percent) .. "%)")
                    if status.mana.max_mana > 0 then
                        print("  Mana: " .. status.mana.formatted_mana .. "/" .. status.mana.formatted_max .. " (" .. math.floor(status.mana.mana_percent) .. "%)")
                    end
                    if status.absorbs.absorbs > 0 then
                        print("  Absorbs: " .. status.absorbs.formatted_absorbs)
                    end
                else
                    print("No unit found: " .. args)
                end
            else
                print("Usage: /statustext check <unit>")
            end
        elseif cmd == "text" then
            if args and args ~= "" then
                local text = StatusTextEngine:BuildStatusText(args)
                print("Status text for " .. args .. ": " .. text)
            else
                print("Usage: /statustext text <unit>")
            end
        elseif cmd == "long" then
            if args and args ~= "" then
                local text = StatusTextEngine:FormatLongHealth(args)
                print("Long format for " .. args .. ": " .. text)
            else
                print("Usage: /statustext long <unit>")
            end
        elseif cmd == "status" then
            local status = StatusTextEngine:GetStatus()
            print("Status Text Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Status Text Commands:")
            print("  /statustext check <unit> - Show full status")
            print("  /statustext text <unit> - Show compact status text")
            print("  /statustext long <unit> - Show long format")
            print("  /statustext status - Show system status")
        end
    end
end

return StatusTextEngine
