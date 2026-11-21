-- FocusIndicatorEngine.lua - Track focus target separately with indicators
-- Part of InfinityHealer addon suite
-- Provides focus frame rendering and status display

local FocusIndicatorEngine = {}
FocusIndicatorEngine.enabled = false
FocusIndicatorEngine.db = nil
FocusIndicatorEngine.focus_frame = nil

-- Configuration
FocusIndicatorEngine.config = {
    enabled = true,
    show_focus_frame = true,
    show_focus_health = true,
    show_focus_name = true,
    show_focus_buffs = true,
    show_focus_debuffs = true,
    focus_frame_size = 100,
    update_frequency = 0.1,
    position = { x = 100, y = 100 },
}

function FocusIndicatorEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.focus_data then
        self.db.focus_data = {}
    end
    
    self.enabled = true
    
    self:Log("Initialized")
end

function FocusIndicatorEngine:CreateFocusFrame()
    if self.focus_frame then
        return self.focus_frame
    end
    
    -- Create main frame
    local frame = CreateFrame("Frame", "InfinityFocusFrame", UIParent)
    frame:SetSize(self.config.focus_frame_size, self.config.focus_frame_size)
    frame:SetPoint("CENTER", self.config.position.x, self.config.position.y)
    
    -- Create border
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    
    -- Create name text
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    nameText:SetPoint("TOP", frame, "TOP", 0, -5)
    nameText:SetSize(self.config.focus_frame_size - 2, 20)
    nameText:SetJustifyH("CENTER")
    nameText:SetJustifyV("TOP")
    nameText:SetTextColor(1, 1, 1, 1)
    
    -- Create health bar
    local healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetSize(self.config.focus_frame_size - 4, 15)
    healthBar:SetPoint("CENTER", frame, "CENTER", 0, 0)
    healthBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
    healthBar:SetStatusBarColor(0, 0.8, 0)
    healthBar:SetValue(100)
    
    healthBar:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        tileSize = 16,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    healthBar:SetBackdropColor(0, 0, 0, 0.5)
    healthBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Create health text
    local healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
    healthText:SetJustifyH("CENTER")
    healthText:SetJustifyV("MIDDLE")
    healthText:SetTextColor(1, 1, 1, 1)
    
    self.focus_frame = {
        frame = frame,
        name_text = nameText,
        health_bar = healthBar,
        health_text = healthText,
        unit = nil,
        last_health = 0,
        last_max = 0,
    }
    
    return self.focus_frame
end

function FocusIndicatorEngine:UpdateFocusFrame()
    if not self.focus_frame then
        self:CreateFocusFrame()
    end
    
    local unitID = "focus"
    
    if not UnitExists(unitID) then
        self.focus_frame.frame:Hide()
        return
    end
    
    self.focus_frame.unit = unitID
    
    -- Update name
    local name = UnitName(unitID)
    if self.config.show_focus_name then
        self.focus_frame.name_text:SetText(name)
    end
    
    -- Update health
    if self.config.show_focus_health then
        local health = UnitHealth(unitID)
        local maxHealth = UnitHealthMax(unitID)
        
        if maxHealth <= 0 then
            maxHealth = 100
        end
        
        local healthPercent = (health / maxHealth) * 100
        self.focus_frame.health_bar:SetValue(healthPercent)
        self.focus_frame.health_text:SetText(math.floor(healthPercent) .. "%")
        
        -- Update color
        if healthPercent > 70 then
            self.focus_frame.health_bar:SetStatusBarColor(0, 0.8, 0)
        elseif healthPercent > 40 then
            self.focus_frame.health_bar:SetStatusBarColor(1, 1, 0)
        elseif healthPercent > 20 then
            self.focus_frame.health_bar:SetStatusBarColor(1, 0.5, 0)
        else
            self.focus_frame.health_bar:SetStatusBarColor(1, 0, 0)
        end
        
        self.focus_frame.last_health = health
        self.focus_frame.last_max = maxHealth
    end
    
    self.focus_frame.frame:Show()
end

function FocusIndicatorEngine:GetFocusStatus()
    local unitID = "focus"
    
    if not UnitExists(unitID) then
        return nil
    end
    
    local name = UnitName(unitID)
    local health = UnitHealth(unitID)
    local maxHealth = UnitHealthMax(unitID)
    
    if maxHealth <= 0 then
        maxHealth = 100
    end
    
    local healthPercent = (health / maxHealth) * 100
    
    return {
        unit = unitID,
        name = name,
        health = health,
        max_health = maxHealth,
        health_percent = healthPercent,
        is_alive = not UnitIsDead(unitID),
    }
end

function FocusIndicatorEngine:SetFocus(unitID)
    if unitID then
        SetFocusUnit(unitID)
        self:Log("Focus set to: " .. UnitName(unitID))
        self:UpdateFocusFrame()
    end
end

function FocusIndicatorEngine:ClearFocus()
    ClearFocus()
    self.focus_frame.frame:Hide()
    self:Log("Focus cleared")
end

function FocusIndicatorEngine:MoveFocusFrame(x, y)
    if not self.focus_frame then
        return
    end
    
    self.focus_frame.frame:SetPoint("CENTER", x, y)
    self.config.position.x = x
    self.config.position.y = y
    
    self:Log("Focus frame moved to: " .. x .. ", " .. y)
end

function FocusIndicatorEngine:ToggleFocusFrame()
    if not self.focus_frame then
        self:CreateFocusFrame()
    end
    
    if self.focus_frame.frame:IsVisible() then
        self.focus_frame.frame:Hide()
        self.config.show_focus_frame = false
    else
        self.focus_frame.frame:Show()
        self.config.show_focus_frame = true
    end
end

function FocusIndicatorEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function FocusIndicatorEngine:GetStatus()
    local focusStatus = self:GetFocusStatus()
    
    return {
        enabled = self.enabled,
        focus_set = focusStatus ~= nil,
        focus_name = focusStatus and focusStatus.name or "none",
        show_frame = self.config.show_focus_frame,
        frame_visible = self.focus_frame and self.focus_frame.frame:IsVisible() or false,
    }
end

function FocusIndicatorEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[FocusIndicatorEngine] " .. message)
    else
        print("[FocusIndicatorEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_FOCUSINDICATOR1 = "/focusindicator"
    SlashCmdList["FOCUSINDICATOR"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            if args and args ~= "" then
                FocusIndicatorEngine:SetFocus(args)
                print("Focus set to: " .. args)
            else
                print("Usage: /focusindicator set <unit>")
            end
        elseif cmd == "clear" then
            FocusIndicatorEngine:ClearFocus()
            print("Focus cleared")
        elseif cmd == "toggle" then
            FocusIndicatorEngine:ToggleFocusFrame()
            print("Focus frame toggled")
        elseif cmd == "move" then
            local x, y = args:match("^(%S+)%s+(%S+)$")
            if x and y and tonumber(x) and tonumber(y) then
                FocusIndicatorEngine:MoveFocusFrame(tonumber(x), tonumber(y))
                print("Focus frame moved to: " .. x .. ", " .. y)
            else
                print("Usage: /focusindicator move <x> <y>")
            end
        elseif cmd == "status" then
            local status = FocusIndicatorEngine:GetStatus()
            print("Focus Indicator Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Focus Indicator Commands:")
            print("  /focusindicator set <unit> - Set focus")
            print("  /focusindicator clear - Clear focus")
            print("  /focusindicator toggle - Toggle focus frame visibility")
            print("  /focusindicator move <x> <y> - Move focus frame")
            print("  /focusindicator status - Show system status")
        end
    end
end

return FocusIndicatorEngine
