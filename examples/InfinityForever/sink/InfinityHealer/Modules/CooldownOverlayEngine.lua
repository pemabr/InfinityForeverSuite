-- CooldownOverlayEngine.lua - Render cooldown spirals on frame icons
-- Part of InfinityHealer addon suite
-- Displays spell cooldown status with spiral animation

local CooldownOverlayEngine = {}
CooldownOverlayEngine.enabled = false
CooldownOverlayEngine.db = nil
CooldownOverlayEngine.cooldown_cache = {}
CooldownOverlayEngine.monitored_spells = {}

-- Configuration
CooldownOverlayEngine.config = {
    enabled = true,
    show_cooldown_spiral = true,
    show_cooldown_text = true,
    update_frequency = 0.1,  -- Update at 10 FPS for smooth spiral
    text_format = "seconds",  -- seconds, percent, both
    minimum_cooldown = 1,  -- Only show if cooldown > 1 second
    alpha = 0.8,  -- Overlay alpha
}

function CooldownOverlayEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.cooldown_cache then
        self.db.cooldown_cache = {}
    end
    
    self.cooldown_cache = self.db.cooldown_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function CooldownOverlayEngine:CreateCooldownOverlay(frame, size)
    if not frame then
        return nil
    end
    
    -- Create cooldown frame
    local cooldown = CreateFrame("Cooldown", nil, frame)
    cooldown:SetAllPoints(frame)
    cooldown:SetDrawEdge(false)
    
    -- Create cooldown text
    local text = frame:CreateFontString(nil, "OVERLAY", "NumberFont_Outline_Med")
    text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    text:SetJustifyH("RIGHT")
    text:SetJustifyV("BOTTOM")
    text:SetTextColor(1, 1, 0, 1)
    
    return {
        frame = cooldown,
        text = text,
        spell_name = nil,
        last_cooldown = 0,
        last_max = 0,
    }
end

function CooldownOverlayEngine:MonitorSpell(spellName)
    if not spellName then
        return false
    end
    
    if not self.monitored_spells[spellName] then
        self.monitored_spells[spellName] = {
            name = spellName,
            last_cooldown = 0,
            last_max = 0,
            on_cooldown = false,
        }
        self:Log("Monitoring spell: " .. spellName)
        return true
    end
    
    return false
end

function CooldownOverlayEngine:GetSpellCooldown(spellName)
    if not spellName then
        return nil
    end
    
    local start, duration, enabled = GetSpellCooldown(spellName)
    
    if not start or start == 0 then
        return {
            spell_name = spellName,
            current = 0,
            max = 0,
            remaining = 0,
            percent = 0,
            on_cooldown = false,
        }
    end
    
    local remaining = (start + duration) - GetTime()
    if remaining < 0 then
        remaining = 0
    end
    
    return {
        spell_name = spellName,
        current = start,
        max = duration,
        remaining = remaining,
        percent = (remaining / duration) * 100,
        on_cooldown = remaining > 0 and enabled,
    }
end

function CooldownOverlayEngine:UpdateCooldownOverlay(overlayData, spellName)
    if not overlayData or not spellName then
        return
    end
    
    overlayData.spell_name = spellName
    
    local cooldownInfo = self:GetSpellCooldown(spellName)
    if not cooldownInfo then
        overlayData.frame:SetAlpha(0)
        return
    end
    
    -- Only show if cooldown is long enough
    if cooldownInfo.remaining < self.config.minimum_cooldown then
        overlayData.frame:SetAlpha(0)
        overlayData.text:SetText("")
        return
    end
    
    if self.config.show_cooldown_spiral then
        overlayData.frame:SetAlpha(self.config.alpha)
        
        -- Set the spiral cooldown
        if cooldownInfo.on_cooldown then
            overlayData.frame:SetCooldown(cooldownInfo.current, cooldownInfo.max)
        else
            overlayData.frame:Clear()
        end
    else
        overlayData.frame:SetAlpha(0)
    end
    
    -- Update text
    if self.config.show_cooldown_text then
        self:UpdateCooldownText(overlayData, cooldownInfo)
    else
        overlayData.text:SetText("")
    end
    
    overlayData.last_cooldown = cooldownInfo.remaining
    overlayData.last_max = cooldownInfo.max
end

function CooldownOverlayEngine:UpdateCooldownText(overlayData, cooldownInfo)
    if not overlayData or not cooldownInfo then
        return
    end
    
    if cooldownInfo.remaining <= 0 then
        overlayData.text:SetText("")
        return
    end
    
    if self.config.text_format == "seconds" then
        if cooldownInfo.remaining >= 1 then
            overlayData.text:SetText(math.floor(cooldownInfo.remaining))
        else
            overlayData.text:SetText(string.format("%.1f", cooldownInfo.remaining))
        end
    elseif self.config.text_format == "percent" then
        overlayData.text:SetText(math.floor(cooldownInfo.percent) .. "%")
    elseif self.config.text_format == "both" then
        overlayData.text:SetText(math.floor(cooldownInfo.remaining) .. " (" .. math.floor(cooldownInfo.percent) .. "%)")
    end
end

function CooldownOverlayEngine:GetMonitoredSpellStatus(spellName)
    if not spellName or not self.monitored_spells[spellName] then
        return nil
    end
    
    local cooldown = self:GetSpellCooldown(spellName)
    
    return {
        spell_name = spellName,
        is_on_cooldown = cooldown.on_cooldown,
        remaining = cooldown.remaining,
        total_duration = cooldown.max,
        percent_remaining = cooldown.percent,
    }
end

function CooldownOverlayEngine:GetAllMonitoredSpells()
    local statuses = {}
    
    for spellName, _ in pairs(self.monitored_spells) do
        local status = self:GetMonitoredSpellStatus(spellName)
        if status then
            table.insert(statuses, status)
        end
    end
    
    return statuses
end

function CooldownOverlayEngine:ClearCooldowns()
    for _, overlay in pairs(self.cooldown_cache) do
        if overlay and overlay.frame then
            overlay.frame:Clear()
            overlay.text:SetText("")
        end
    end
end

function CooldownOverlayEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function CooldownOverlayEngine:GetStatus()
    local spellsMonitored = 0
    for _ in pairs(self.monitored_spells) do
        spellsMonitored = spellsMonitored + 1
    end
    
    return {
        enabled = self.enabled,
        spells_monitored = spellsMonitored,
        show_spiral = self.config.show_cooldown_spiral,
        show_text = self.config.show_cooldown_text,
        text_format = self.config.text_format,
        update_frequency = self.config.update_frequency,
    }
end

function CooldownOverlayEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[CooldownOverlayEngine] " .. message)
    else
        print("[CooldownOverlayEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_COOLDOWN1 = "/cooldown"
    SlashCmdList["COOLDOWN"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "monitor" then
            if args and args ~= "" then
                if CooldownOverlayEngine:MonitorSpell(args) then
                    print("Now monitoring: " .. args)
                else
                    print("Already monitoring: " .. args)
                end
            else
                print("Usage: /cooldown monitor <spell_name>")
            end
        elseif cmd == "check" then
            if args and args ~= "" then
                local status = CooldownOverlayEngine:GetMonitoredSpellStatus(args)
                if status then
                    print("Cooldown for " .. status.spell_name .. ":")
                    print("  On Cooldown: " .. tostring(status.is_on_cooldown))
                    print("  Remaining: " .. math.floor(status.remaining) .. " seconds")
                    print("  Duration: " .. math.floor(status.total_duration) .. " seconds")
                    print("  Percent: " .. math.floor(status.percent_remaining) .. "%")
                else
                    print("Spell not monitored: " .. args)
                end
            else
                print("Usage: /cooldown check <spell_name>")
            end
        elseif cmd == "text" then
            if args == "seconds" or args == "percent" or args == "both" then
                CooldownOverlayEngine:SetConfig("text_format", args)
                print("Text format: " .. args)
            else
                print("Usage: /cooldown text <seconds|percent|both>")
            end
        elseif cmd == "status" then
            local status = CooldownOverlayEngine:GetStatus()
            print("Cooldown Overlay Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "list" then
            local spells = CooldownOverlayEngine:GetAllMonitoredSpells()
            if #spells == 0 then
                print("No spells monitored")
            else
                print("Monitored spells:")
                for _, spell in ipairs(spells) do
                    local status = spell.is_on_cooldown and "ON CD" or "READY"
                    print("  " .. spell.spell_name .. ": " .. status .. " (" .. math.floor(spell.remaining) .. "s)")
                end
            end
        else
            print("Cooldown Commands:")
            print("  /cooldown monitor <spell> - Monitor spell cooldown")
            print("  /cooldown check <spell> - Check spell cooldown")
            print("  /cooldown text <seconds|percent|both> - Set text format")
            print("  /cooldown list - List monitored spells")
            print("  /cooldown status - Show system status")
        end
    end
end

return CooldownOverlayEngine
