-- HealthBarRenderer.lua - Render health bars with dynamic colors
-- Part of PluribusHealer addon suite
-- Displays player health and mana/resource bars

local HealthBarRenderer = {}
HealthBarRenderer.enabled = false
HealthBarRenderer.db = nil
HealthBarRenderer.bar_cache = {}

-- Configuration
HealthBarRenderer.config = {
    enabled = true,
    show_health_text = true,
    show_mana_text = true,
    color_by_class = true,
    color_by_health = false,  -- Dynamic red when low
    health_threshold = 30,  -- Percentage for low health
    update_frequency = 0.5,
    bar_width = 100,
    bar_height = 20,
    text_format = "percent",  -- percent, number, both
}

function HealthBarRenderer:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.health_bars then
        self.db.health_bars = {}
    end
    
    self.bar_cache = self.db.health_bars
    self.enabled = true
    
    self:Log("Initialized")
end

function HealthBarRenderer:CreateHealthBar(frame, width, height)
    if not frame then
        return nil
    end
    
    -- Create bar frame
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetSize(width or self.config.bar_width, height or self.config.bar_height)
    bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    bar:SetStatusBarColor(0, 0.8, 0)
    bar:SetValue(100)
    
    -- Create background
    bar:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    bar:SetBackdropColor(0, 0, 0, 0.5)
    bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Create text
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetSize(width - 2, height - 2)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetTextColor(1, 1, 1, 1)
    
    return {
        frame = bar,
        text = text,
        unit = nil,
        last_health = 0,
        last_max = 0,
    }
end

function HealthBarRenderer:UpdateHealthBar(barData, unitID)
    if not barData or not unitID then
        return
    end
    
    if not UnitExists(unitID) then
        barData.frame:Hide()
        return
    end
    
    barData.unit = unitID
    
    local health = UnitHealth(unitID)
    local maxHealth = UnitHealthMax(unitID)
    
    if maxHealth <= 0 then
        maxHealth = 100
    end
    
    -- Update bar
    local healthPercent = (health / maxHealth) * 100
    barData.frame:SetValue(healthPercent)
    
    -- Update color
    if self.config.color_by_health then
        self:UpdateHealthBarColor(barData, healthPercent)
    else
        self:UpdateClassColor(barData, unitID)
    end
    
    -- Update text
    if self.config.show_health_text then
        self:UpdateHealthText(barData, health, maxHealth, healthPercent)
    end
    
    -- Fade dead players
    if UnitIsDead(unitID) then
        barData.frame:SetAlpha(0.3)
    else
        barData.frame:SetAlpha(1)
    end
    
    barData.last_health = health
    barData.last_max = maxHealth
    
    barData.frame:Show()
end

function HealthBarRenderer:UpdateHealthBarColor(barData, healthPercent)
    if healthPercent > 70 then
        barData.frame:SetStatusBarColor(0, 0.8, 0)  -- Green
    elseif healthPercent > 40 then
        barData.frame:SetStatusBarColor(1, 1, 0)  -- Yellow
    elseif healthPercent > 20 then
        barData.frame:SetStatusBarColor(1, 0.5, 0)  -- Orange
    else
        barData.frame:SetStatusBarColor(1, 0, 0)  -- Red
    end
end

function HealthBarRenderer:UpdateClassColor(barData, unitID)
    local class = select(2, UnitClass(unitID))
    
    if class == "WARRIOR" then
        barData.frame:SetStatusBarColor(0.78, 0.61, 0.43)
    elseif class == "PALADIN" then
        barData.frame:SetStatusBarColor(0.96, 0.55, 0.73)
    elseif class == "HUNTER" then
        barData.frame:SetStatusBarColor(0.67, 0.83, 0.45)
    elseif class == "ROGUE" then
        barData.frame:SetStatusBarColor(1, 0.96, 0.41)
    elseif class == "PRIEST" then
        barData.frame:SetStatusBarColor(1, 1, 1)
    elseif class == "SHAMAN" then
        barData.frame:SetStatusBarColor(0, 0.44, 0.87)
    elseif class == "DRUID" then
        barData.frame:SetStatusBarColor(1, 0.49, 0.04)
    elseif class == "WARLOCK" then
        barData.frame:SetStatusBarColor(0.58, 0.51, 0.79)
    elseif class == "MAGE" then
        barData.frame:SetStatusBarColor(0.41, 0.80, 0.94)
    else
        barData.frame:SetStatusBarColor(0.5, 0.5, 0.5)
    end
end

function HealthBarRenderer:UpdateHealthText(barData, health, maxHealth, healthPercent)
    if self.config.text_format == "percent" then
        barData.text:SetText(math.floor(healthPercent) .. "%")
    elseif self.config.text_format == "number" then
        barData.text:SetText(math.floor(health) .. "/" .. math.floor(maxHealth))
    elseif self.config.text_format == "both" then
        barData.text:SetText(math.floor(health) .. "/" .. math.floor(maxHealth) .. " (" .. math.floor(healthPercent) .. "%)")
    end
end

function HealthBarRenderer:GetHealthBarState(barData)
    if not barData then
        return nil
    end
    
    return {
        unit = barData.unit,
        health = barData.last_health,
        max_health = barData.last_max,
        health_percent = (barData.last_health / math.max(1, barData.last_max)) * 100,
        is_visible = barData.frame:IsVisible(),
    }
end

function HealthBarRenderer:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function HealthBarRenderer:GetStatus()
    local barsCreated = 0
    for _ in pairs(self.bar_cache) do
        barsCreated = barsCreated + 1
    end
    
    return {
        enabled = self.enabled,
        bars_created = barsCreated,
        color_mode = self.config.color_by_health and "health" or "class",
        text_format = self.config.text_format,
    }
end

function HealthBarRenderer:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[HealthBarRenderer] " .. message)
    else
        print("[HealthBarRenderer] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HEALTHBAR1 = "/healthbar"
    SlashCmdList["HEALTHBAR"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "color" then
            if args == "health" then
                HealthBarRenderer:SetConfig("color_by_health", true)
                print("Color mode: health")
            elseif args == "class" then
                HealthBarRenderer:SetConfig("color_by_health", false)
                print("Color mode: class")
            else
                print("Usage: /healthbar color <health|class>")
            end
        elseif cmd == "text" then
            if args and args ~= "" then
                if args == "percent" or args == "number" or args == "both" then
                    HealthBarRenderer:SetConfig("text_format", args)
                    print("Text format: " .. args)
                else
                    print("Usage: /healthbar text <percent|number|both>")
                end
            else
                print("Current format: " .. HealthBarRenderer.config.text_format)
            end
        elseif cmd == "status" then
            local status = HealthBarRenderer:GetStatus()
            print("Health Bar Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Health Bar Commands:")
            print("  /healthbar color <health|class> - Set color mode")
            print("  /healthbar text <percent|number|both> - Set text format")
            print("  /healthbar status - Show system status")
        end
    end
end

return HealthBarRenderer
