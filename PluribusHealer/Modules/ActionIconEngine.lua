-- ActionIconEngine.lua - Display spell icon for current/queued cast
-- Part of PluribusHealer addon suite
-- Shows what spell you're currently casting or queued to cast

local ActionIconEngine = {}
ActionIconEngine.enabled = false
ActionIconEngine.db = nil
ActionIconEngine.action_cache = {}

-- Configuration
ActionIconEngine.config = {
    enabled = true,
    show_current_cast = true,
    show_queued_cast = true,
    show_cast_text = true,
    update_frequency = 0.1,
    icon_size = 64,
    show_cast_bar = true,
}

function ActionIconEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.action_cache then
        self.db.action_cache = {}
    end
    
    self.action_cache = self.db.action_cache
    self.enabled = true
    
    self:Log("Initialized")
end

function ActionIconEngine:CreateActionIcon(parent, width, height)
    if not parent then
        return nil
    end
    
    -- Create icon frame
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(width or self.config.icon_size, height or self.config.icon_size)
    
    -- Create texture for icon
    local texture = icon:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(icon)
    
    -- Create border
    icon:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    icon:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    icon:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Create cast bar under icon
    local castbar = CreateFrame("StatusBar", nil, icon)
    castbar:SetSize(width or self.config.icon_size, 4)
    castbar:SetPoint("BOTTOM", icon, "BOTTOM", 0, -6)
    castbar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    castbar:SetStatusBarColor(0, 0.8, 1)
    castbar:SetValue(0)
    
    castbar:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    castbar:SetBackdropColor(0, 0, 0, 0.5)
    castbar:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Create text label
    local text = icon:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    text:SetPoint("CENTER", icon, "CENTER", 0, 0)
    text:SetSize(width - 2, 20)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetWordWrap(true)
    
    -- Create cast time text
    local casttext = icon:CreateFontString(nil, "OVERLAY", "NumberFont_Outline_Med")
    casttext:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    casttext:SetJustifyH("RIGHT")
    casttext:SetTextColor(1, 1, 0, 1)
    
    return {
        frame = icon,
        texture = texture,
        castbar = castbar,
        text = text,
        casttext = casttext,
        current_spell = nil,
        is_casting = false,
        cast_start = 0,
        cast_duration = 0,
    }
end

function ActionIconEngine:GetCurrentCastInfo()
    local unit = "player"
    
    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
    
    if name then
        return {
            spell_name = name,
            icon = texture,
            start_time = startTime / 1000,  -- Convert to seconds
            end_time = endTime / 1000,
            duration = (endTime - startTime) / 1000,
            cast_type = "cast",
            is_interruptible = not notInterruptible,
        }
    end
    
    -- Check for channel
    name, text, texture, startTime, endTime, isTradeSkill = UnitChannelInfo(unit)
    
    if name then
        return {
            spell_name = name,
            icon = texture,
            start_time = startTime / 1000,
            end_time = endTime / 1000,
            duration = (endTime - startTime) / 1000,
            cast_type = "channel",
            is_interruptible = true,
        }
    end
    
    return nil
end

function ActionIconEngine:UpdateActionIcon(iconData)
    if not iconData then
        return
    end
    
    local castInfo = self:GetCurrentCastInfo()
    
    if castInfo then
        -- Show current cast
        iconData.texture:SetTexture(castInfo.icon)
        iconData.current_spell = castInfo.spell_name
        iconData.is_casting = true
        iconData.cast_start = castInfo.start_time
        iconData.cast_duration = castInfo.duration
        
        -- Update cast bar
        local elapsed = GetTime() - (castInfo.start_time / 1000)
        if elapsed < 0 then elapsed = 0 end
        local progress = (elapsed / castInfo.duration) * 100
        if progress > 100 then progress = 100 end
        
        if self.config.show_cast_bar then
            iconData.castbar:SetValue(progress)
            iconData.castbar:Show()
        end
        
        -- Update text
        if self.config.show_cast_text then
            iconData.text:SetText(castInfo.spell_name)
        end
        
        -- Update time remaining
        local remaining = castInfo.duration - elapsed
        if remaining > 0 then
            if remaining >= 1 then
                iconData.casttext:SetText(string.format("%.1f", remaining))
            else
                iconData.casttext:SetText(string.format("%.2f", remaining))
            end
        end
        
        iconData.frame:Show()
    else
        -- No cast - hide
        iconData.is_casting = false
        iconData.text:SetText("")
        iconData.casttext:SetText("")
        iconData.castbar:SetValue(0)
        iconData.castbar:Hide()
        
        -- Could show queued spell or last cast here
        if not self.config.show_queued_cast then
            iconData.texture:SetTexture("")
            iconData.frame:Hide()
        end
    end
end

function ActionIconEngine:GetCastStatus()
    local castInfo = self:GetCurrentCastInfo()
    
    if castInfo then
        local elapsed = GetTime() - (castInfo.start_time / 1000)
        if elapsed < 0 then elapsed = 0 end
        local remaining = castInfo.duration - elapsed
        
        return {
            is_casting = true,
            spell_name = castInfo.spell_name,
            cast_type = castInfo.cast_type,
            elapsed = elapsed,
            duration = castInfo.duration,
            remaining = remaining,
            progress_percent = (elapsed / castInfo.duration) * 100,
            is_interruptible = castInfo.is_interruptible,
        }
    end
    
    return {
        is_casting = false,
        spell_name = nil,
        cast_type = nil,
        elapsed = 0,
        duration = 0,
        remaining = 0,
        progress_percent = 0,
    }
end

function ActionIconEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function ActionIconEngine:GetStatus()
    local castStatus = self:GetCastStatus()
    
    return {
        enabled = self.enabled,
        is_casting = castStatus.is_casting,
        current_spell = castStatus.spell_name,
        show_cast_text = self.config.show_cast_text,
        show_cast_bar = self.config.show_cast_bar,
    }
end

function ActionIconEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[ActionIconEngine] " .. message)
    else
        print("[ActionIconEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_ACTIONICON1 = "/actionicon"
    SlashCmdList["ACTIONICON"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            local status = ActionIconEngine:GetCastStatus()
            if status.is_casting then
                print("Currently casting: " .. status.spell_name .. " (" .. status.cast_type .. ")")
                print("  Progress: " .. math.floor(status.elapsed) .. "/" .. math.floor(status.duration) .. " seconds")
                print("  Remaining: " .. math.floor(status.remaining) .. " seconds")
                print("  Percent: " .. math.floor(status.progress_percent) .. "%")
            else
                print("Not casting")
            end
        elseif cmd == "status" then
            local status = ActionIconEngine:GetStatus()
            print("Action Icon Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Action Icon Commands:")
            print("  /actionicon check - Check current cast")
            print("  /actionicon status - Show system status")
        end
    end
end

return ActionIconEngine
