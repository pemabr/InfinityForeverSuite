-- Alerts Module
-- Generate and manage raid alerts for important events

local InfinityEncounterAlerts = {}
_G.InfinityEncounterAlerts = InfinityEncounterAlerts

InfinityEncounterAlerts.alerts = {}
InfinityEncounterAlerts.alert_history = {}
InfinityEncounterAlerts.callbacks = {}
InfinityEncounterAlerts.enabled = true

-- Alert levels
InfinityEncounterAlerts.LEVEL_CRITICAL = 1
InfinityEncounterAlerts.LEVEL_WARNING = 2
InfinityEncounterAlerts.LEVEL_INFO = 3

function InfinityEncounterAlerts:SendAlert(text, level, duration)
    if not self.enabled then return end
    
    level = level or self.LEVEL_WARNING
    duration = duration or 5
    
    local alert = {
        text = text,
        level = level,
        time = GetTime(),
        duration = duration,
        sound_played = false,
    }
    
    table.insert(self.alerts, alert)
    table.insert(self.alert_history, alert)
    
    -- Play sound based on level
    if level == self.LEVEL_CRITICAL then
        PlaySoundFile("Interface\\AddOns\\InfinityForever\\Assets\\critical_alert.ogg", "Master")
    elseif level == self.LEVEL_WARNING then
        PlaySoundFile("Interface\\AddOns\\InfinityForever\\Assets\\warning_alert.ogg", "Master")
    end
    
    self:TriggerCallback("alert_sent", text, level)
end

function InfinityEncounterAlerts:SendAbilityAlert(abilityName, timeUntil, priority)
    priority = priority or "normal"
    
    local text
    if timeUntil < 1 then
        text = string.format("%s NOW!", abilityName)
    elseif timeUntil < 5 then
        text = string.format("%s in %.0f seconds!", abilityName, timeUntil)
    else
        text = string.format("%s in %.0f seconds", abilityName, timeUntil)
    end
    
    local level = (priority == "critical" and self.LEVEL_CRITICAL) or self.LEVEL_WARNING
    self:SendAlert(text, level, 2)
end

function InfinityEncounterAlerts:SendPlayerAlert(message, targetPlayer)
    local text = message
    if targetPlayer then
        text = string.format("%s [%s]", message, targetPlayer)
    end
    self:SendAlert(text, self.LEVEL_WARNING)
end

function InfinityEncounterAlerts:SendPhaseAlert(phaseNumber, description)
    local text = string.format("Phase %d - %s", phaseNumber, description or "Phase Change")
    self:SendAlert(text, self.LEVEL_INFO, 3)
end

function InfinityEncounterAlerts:GetActiveAlerts()
    local now = GetTime()
    local active = {}
    
    for i = #self.alerts, 1, -1 do
        local alert = self.alerts[i]
        if (now - alert.time) < alert.duration then
            table.insert(active, 1, alert)
        else
            table.remove(self.alerts, i)
        end
    end
    
    return active
end

function InfinityEncounterAlerts:GetAlertHistory(limit)
    limit = limit or 20
    local result = {}
    
    for i = #self.alert_history, math.max(1, #self.alert_history - limit + 1), -1 do
        table.insert(result, 1, self.alert_history[i])
    end
    
    return result
end

function InfinityEncounterAlerts:SetEnabled(enabled)
    self.enabled = enabled
end

function InfinityEncounterAlerts:IsEnabled()
    return self.enabled
end

function InfinityEncounterAlerts:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityEncounterAlerts:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityEncounterAlerts:Clear()
    self.alerts = {}
    self.alert_history = {}
end

return InfinityEncounterAlerts
