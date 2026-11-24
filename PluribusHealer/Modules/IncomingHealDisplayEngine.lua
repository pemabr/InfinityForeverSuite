-- IncomingHealDisplayEngine.lua - Visual display of incoming heals on frames
-- Part of PluribusHealer addon suite
-- Shows heal prediction bars and incoming heal amounts

local IncomingHealDisplayEngine = {}
IncomingHealDisplayEngine.enabled = false
IncomingHealDisplayEngine.db = nil
IncomingHealDisplayEngine.heal_bars = {}

-- Configuration
IncomingHealDisplayEngine.config = {
    enabled = true,
    show_bars = true,
    show_text = true,
    bar_height = 4,
    text_format = "SHORT",  -- SHORT, FULL, PERCENTAGE
    update_frequency = 0.1,
    bar_color = {0.2, 0.8, 0.2},  -- Green
    critical_color = {0.8, 0.8, 0.2},  -- Yellow
    overflow_color = {0.8, 0.2, 0.2},  -- Red
    animation_speed = 0.5,
}

function IncomingHealDisplayEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.heal_bars then
        self.db.heal_bars = {}
    end
    
    self.heal_bars = self.db.heal_bars
    self.enabled = true
    
    self:Log("Initialized with format: " .. self.config.text_format)
end

function IncomingHealDisplayEngine:CreateHealBar(frame, targetUnit)
    if not frame or not targetUnit then
        return nil
    end
    
    local barName = frame:GetName() .. "_IncomingHealBar"
    local healBar = frame:CreateTexture(barName, "ARTWORK")
    
    healBar:SetHeight(self.config.bar_height)
    healBar:SetWidth(frame:GetWidth())
    healBar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    
    -- Color the bar
    local color = self.config.bar_color
    healBar:SetColorTexture(color[1], color[2], color[3], 0.6)
    
    local healText = frame:CreateFontString(barName .. "Text", "OVERLAY", "GameFontNormal")
    healText:SetPoint("CENTER", healBar, "CENTER")
    healText:SetTextColor(1, 1, 1, 0.8)
    
    local healData = {
        frame = frame,
        unit = targetUnit,
        bar = healBar,
        text = healText,
        last_amount = 0,
        animation_progress = 0,
        created_at = GetTime(),
    }
    
    self.heal_bars[targetUnit] = healData
    
    return healData
end

function IncomingHealDisplayEngine:UpdateHealBar(targetUnit, incomingAmount, maxHealth)
    if not targetUnit or not self.heal_bars[targetUnit] then
        return false
    end
    
    local healData = self.heal_bars[targetUnit]
    local frame = healData.frame
    
    if not frame or not frame:IsVisible() then
        return false
    end
    
    -- Calculate bar width based on incoming heal percentage of max health
    local barWidth = frame:GetWidth()
    local healPercentage = math.min(incomingAmount / maxHealth, 1.0)
    
    -- Check if overheal
    local currentHealth = UnitHealth(targetUnit)
    local healPercentageOfCurrent = (currentHealth + incomingAmount) / maxHealth
    local isOverheal = healPercentageOfCurrent > 1.0
    
    -- Update bar appearance
    local displayWidth = barWidth * healPercentage
    healData.bar:SetWidth(displayWidth)
    
    -- Color based on overheal status
    local color
    if isOverheal then
        color = self.config.overflow_color
    elseif healPercentage > 0.7 then
        color = self.config.critical_color
    else
        color = self.config.bar_color
    end
    
    healData.bar:SetColorTexture(color[1], color[2], color[3], 0.6)
    
    -- Update text
    if self.config.show_text then
        local textDisplay = self:FormatHealText(incomingAmount)
        healData.text:SetText(textDisplay)
        healData.text:SetShown(displayWidth > 20)  -- Only show if bar wide enough
    end
    
    healData.last_amount = incomingAmount
    healData.last_update = GetTime()
    
    return true
end

function IncomingHealDisplayEngine:FormatHealText(amount)
    if self.config.text_format == "SHORT" then
        if amount >= 1000 then
            return math.floor(amount / 1000) .. "k"
        else
            return math.floor(amount)
        end
    elseif self.config.text_format == "FULL" then
        return math.floor(amount) .. " HP"
    elseif self.config.text_format == "PERCENTAGE" then
        return math.floor((amount / UnitHealthMax("player")) * 100) .. "%"
    end
    
    return tostring(math.floor(amount))
end

function IncomingHealDisplayEngine:HideHealBar(targetUnit)
    if not targetUnit or not self.heal_bars[targetUnit] then
        return false
    end
    
    local healData = self.heal_bars[targetUnit]
    
    if healData.bar then
        healData.bar:SetShown(false)
    end
    
    if healData.text then
        healData.text:SetShown(false)
    end
    
    return true
end

function IncomingHealDisplayEngine:UpdateAllHealBars()
    if not self.enabled or not self.config.show_bars then
        return 0
    end
    
    local updated = 0
    
    for targetUnit, healData in pairs(self.heal_bars) do
        if UnitExists(targetUnit) then
            local maxHealth = UnitHealthMax(targetUnit)
            local currentHealth = UnitHealth(targetUnit)
            
            -- Get incoming heals from communication engine
            local incomingAmount = 0
            if PluribusHealer and PluribusHealer.HealCommunicationEngine then
                incomingAmount = PluribusHealer.HealCommunicationEngine:GetTotalIncomingHeal(targetUnit)
            end
            
            if incomingAmount > 0 then
                self:UpdateHealBar(targetUnit, incomingAmount, maxHealth)
                updated = updated + 1
            else
                self:HideHealBar(targetUnit)
            end
        else
            self:HideHealBar(targetUnit)
        end
    end
    
    return updated
end

function IncomingHealDisplayEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function IncomingHealDisplayEngine:GetStatus()
    local barCount = 0
    
    for _ in pairs(self.heal_bars) do
        barCount = barCount + 1
    end
    
    return {
        enabled = self.enabled,
        show_bars = self.config.show_bars,
        show_text = self.config.show_text,
        bar_height = self.config.bar_height,
        text_format = self.config.text_format,
        active_bars = barCount,
    }
end

function IncomingHealDisplayEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[IncomingHealDisplayEngine] " .. message)
    else
        print("[IncomingHealDisplayEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_INCOMINGHEAL1 = "/incomingheal"
    SlashCmdList["INCOMINGHEAL"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "bar" then
            if args == "on" then
                IncomingHealDisplayEngine:SetConfig("show_bars", true)
                print("Incoming heal bars enabled")
            elseif args == "off" then
                IncomingHealDisplayEngine:SetConfig("show_bars", false)
                print("Incoming heal bars disabled")
            else
                print("Usage: /incomingheal bar <on|off>")
            end
        elseif cmd == "text" then
            if args == "on" then
                IncomingHealDisplayEngine:SetConfig("show_text", true)
                print("Incoming heal text enabled")
            elseif args == "off" then
                IncomingHealDisplayEngine:SetConfig("show_text", false)
                print("Incoming heal text disabled")
            else
                print("Usage: /incomingheal text <on|off>")
            end
        elseif cmd == "format" then
            if args and (args == "SHORT" or args == "FULL" or args == "PERCENTAGE") then
                IncomingHealDisplayEngine:SetConfig("text_format", args)
                print("Text format: " .. args)
            else
                print("Usage: /incomingheal format <SHORT|FULL|PERCENTAGE>")
            end
        elseif cmd == "height" then
            if args and tonumber(args) then
                IncomingHealDisplayEngine:SetConfig("bar_height", tonumber(args))
                print("Bar height: " .. args)
            else
                print("Usage: /incomingheal height <number>")
            end
        elseif cmd == "update" then
            local updated = IncomingHealDisplayEngine:UpdateAllHealBars()
            print("Updated " .. updated .. " heal bars")
        elseif cmd == "status" then
            local status = IncomingHealDisplayEngine:GetStatus()
            print("Incoming Heal Display Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Incoming Heal Display Commands:")
            print("  /incomingheal bar <on|off> - Toggle heal bars")
            print("  /incomingheal text <on|off> - Toggle text display")
            print("  /incomingheal format <SHORT|FULL|PERCENTAGE> - Set text format")
            print("  /incomingheal height <number> - Set bar height in pixels")
            print("  /incomingheal update - Update all bars immediately")
            print("  /incomingheal status - Show system status")
        end
    end
end

return IncomingHealDisplayEngine
