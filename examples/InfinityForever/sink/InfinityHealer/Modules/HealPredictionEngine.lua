-- HealPredictionEngine.lua - Predict incoming heals to prevent overheal
-- Part of InfinityHealer addon suite
-- Tracks HoTs, incoming heals, and predicts final health values

local HealPredictionEngine = {}
HealPredictionEngine.enabled = false
HealPredictionEngine.db = nil
HealPredictionEngine.incoming_heals = {}
HealPredictionEngine.hots = {}  -- player -> { spell -> { amount, duration, end_time } }
HealPredictionEngine.player_predictions = {}

-- Configuration
HealPredictionEngine.config = {
    enabled = true,
    predict_hots = true,
    predict_incoming = true,
    tracking_interval = 0.5,
    max_hot_duration = 60,  -- Max HoT to track
    heal_timeout = 10,  -- Incoming heal expires after 10 seconds
    enable_notifications = true,
}

function HealPredictionEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    -- Initialize tracking structures
    if not self.db.heal_predictions then
        self.db.heal_predictions = {
            incoming_heals = {},
            hots_active = {},
            predictions = {},
        }
    end
    
    self.enabled = true
    
    -- Register for events
    InfinityCore.Events:RegisterListener("spell_cast", function(data)
        self:OnSpellCast(data)
    end)
    
    InfinityCore.Events:RegisterListener("heal_received", function(data)
        self:OnHealReceived(data)
    end)
    
    self:Log("Initialized")
end

function HealPredictionEngine:OnSpellCast(data)
    if not self.enabled or not data.spell or not data.target then
        return
    end
    
    -- Check if spell is a healing spell
    local healAmount = self:GetSpellHealAmount(data.spell)
    local hotDuration = self:GetSpellHotDuration(data.spell)
    
    if healAmount > 0 then
        if hotDuration > 0 then
            -- HoT spell
            self:RegisterHoT(data.target, data.spell, healAmount, hotDuration)
        else
            -- Instant heal
            self:RegisterIncomingHeal(data.target, healAmount, data.spell)
        end
    end
end

function HealPredictionEngine:OnHealReceived(data)
    if not self.enabled or not data.player or not data.amount then
        return
    end
    
    -- Remove from incoming heals (actual heal happened)
    self:RemoveIncomingHeal(data.player, data.amount)
end

function HealPredictionEngine:RegisterIncomingHeal(playerName, amount, spellName)
    if not playerName or not amount or amount <= 0 then
        return
    end
    
    -- Create incoming heal record
    local healRecord = {
        amount = amount,
        spell = spellName or "Unknown",
        timestamp = GetTime(),
        expires_at = GetTime() + self.config.heal_timeout,
    }
    
    if not self.incoming_heals[playerName] then
        self.incoming_heals[playerName] = {}
    end
    
    table.insert(self.incoming_heals[playerName], healRecord)
    
    self:Log("Incoming heal registered: " .. playerName .. " will receive " .. amount .. " HP")
end

function HealPredictionEngine:RegisterHoT(playerName, spellName, amount, duration)
    if not playerName or not spellName or not amount or amount <= 0 then
        return
    end
    
    -- Cap duration to max
    if duration > self.config.max_hot_duration then
        duration = self.config.max_hot_duration
    end
    
    if not self.hots[playerName] then
        self.hots[playerName] = {}
    end
    
    -- Create HoT record
    local hotRecord = {
        spell = spellName,
        amount = amount,
        duration = duration,
        end_time = GetTime() + duration,
        ticks_remaining = math.ceil(duration / 3),  -- Assume 3-second tick
    }
    
    self.hots[playerName][spellName] = hotRecord
    
    self:Log("HoT registered: " .. playerName .. " " .. spellName .. " " .. amount .. " HP over " .. duration .. "s")
end

function HealPredictionEngine:RemoveIncomingHeal(playerName, amount)
    if not self.incoming_heals[playerName] then
        return
    end
    
    -- Remove heals up to the amount
    local remaining = amount
    
    for i = #self.incoming_heals[playerName], 1, -1 do
        local heal = self.incoming_heals[playerName][i]
        
        if heal.amount <= remaining then
            remaining = remaining - heal.amount
            table.remove(self.incoming_heals[playerName], i)
        else
            heal.amount = heal.amount - remaining
            remaining = 0
            break
        end
    end
end

function HealPredictionEngine:CalculatePrediction(playerName)
    if not playerName then
        return nil
    end
    
    -- Get current health
    local maxHealth = UnitHealthMax(playerName)
    local currentHealth = UnitHealth(playerName)
    
    if not maxHealth or maxHealth <= 0 then
        return nil
    end
    
    -- Calculate incoming heals
    local incomingHeal = 0
    if self.incoming_heals[playerName] then
        for _, heal in ipairs(self.incoming_heals[playerName]) do
            if GetTime() <= heal.expires_at then
                incomingHeal = incomingHeal + heal.amount
            end
        end
    end
    
    -- Calculate HoT heals
    local hotHeal = 0
    if self.hots[playerName] then
        for spellName, hot in pairs(self.hots[playerName]) do
            if GetTime() <= hot.end_time then
                -- Calculate remaining ticks
                local ticksRemaining = math.max(1, hot.ticks_remaining)
                hotHeal = hotHeal + (hot.amount * ticksRemaining / hot.ticks_remaining)
            end
        end
    end
    
    -- Calculate predicted health
    local predictedHealth = math.min(maxHealth, currentHealth + incomingHeal + hotHeal)
    local overheal = math.max(0, predictedHealth - maxHealth)
    
    local prediction = {
        player = playerName,
        current_health = currentHealth,
        max_health = maxHealth,
        health_percent = (currentHealth / maxHealth) * 100,
        incoming_heal = incomingHeal,
        hot_heal = hotHeal,
        total_predicted = incomingHeal + hotHeal,
        predicted_health = predictedHealth,
        predicted_percent = (predictedHealth / maxHealth) * 100,
        overheal_amount = overheal,
        will_overheal = overheal > 0,
    }
    
    return prediction
end

function HealPredictionEngine:GetPredictionForPlayer(playerName)
    if not playerName then
        return nil
    end
    
    -- Check if prediction is fresh
    if self.player_predictions[playerName] then
        local prediction = self.player_predictions[playerName]
        if GetTime() - prediction.timestamp < 0.5 then
            return prediction
        end
    end
    
    -- Calculate new prediction
    local prediction = self:CalculatePrediction(playerName)
    if prediction then
        prediction.timestamp = GetTime()
        self.player_predictions[playerName] = prediction
    end
    
    return prediction
end

function HealPredictionEngine:CleanupExpiredHeals()
    local now = GetTime()
    
    for playerName, heals in pairs(self.incoming_heals) do
        for i = #heals, 1, -1 do
            if now > heals[i].expires_at then
                table.remove(heals, i)
            end
        end
        
        if #heals == 0 then
            self.incoming_heals[playerName] = nil
        end
    end
end

function HealPredictionEngine:CleanupExpiredHoTs()
    local now = GetTime()
    
    for playerName, hots in pairs(self.hots) do
        for spellName, hot in pairs(hots) do
            if now > hot.end_time then
                hots[spellName] = nil
            else
                -- Update ticks remaining
                local remaining = hot.end_time - now
                hot.ticks_remaining = math.max(1, math.ceil(remaining / 3))
            end
        end
        
        if self:CountTable(hots) == 0 then
            self.hots[playerName] = nil
        end
    end
end

function HealPredictionEngine:GetSpellHealAmount(spellName)
    -- Healing spells database - would be much larger in production
    local healSpells = {
        ["Flash Heal"] = 100,
        ["Heal"] = 150,
        ["Greater Heal"] = 200,
        ["Power Word: Shield"] = 50,
        ["Renew"] = 20,
        ["Regrowth"] = 100,
        ["Healing Touch"] = 200,
        ["Rejuvenation"] = 50,
    }
    
    return healSpells[spellName] or 0
end

function HealPredictionEngine:GetSpellHotDuration(spellName)
    -- HoT spells database
    local hotSpells = {
        ["Renew"] = 15,
        ["Rejuvenation"] = 12,
        ["Regrowth"] = 21,
        ["Lifebloom"] = 7,
        ["Wild Growth"] = 7,
        ["Beacon of Light"] = 60,
    }
    
    return hotSpells[spellName] or 0
end

function HealPredictionEngine:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function HealPredictionEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function HealPredictionEngine:GetStatus()
    return {
        enabled = self.enabled,
        tracking_players = self:CountTable(self.player_predictions),
        active_incoming_heals = self:CountTable(self.incoming_heals),
        active_hots = self:CountTable(self.hots),
    }
end

function HealPredictionEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[HealPredictionEngine] " .. message)
    else
        print("[HealPredictionEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HEALPRED1 = "/healpred"
    SlashCmdList["HEALPRED"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "predict" then
            if args and args ~= "" then
                local pred = HealPredictionEngine:GetPredictionForPlayer(args)
                if pred then
                    print("Prediction for " .. args .. ":")
                    print("  Current: " .. math.floor(pred.current_health) .. "/" .. pred.max_health .. " (" .. math.floor(pred.health_percent) .. "%)")
                    print("  Incoming: " .. math.floor(pred.incoming_heal) .. " HP")
                    print("  HoT: " .. math.floor(pred.hot_heal) .. " HP")
                    print("  Predicted: " .. math.floor(pred.predicted_health) .. "/" .. pred.max_health .. " (" .. math.floor(pred.predicted_percent) .. "%)")
                    if pred.will_overheal then
                        print("  ⚠️ WILL OVERHEAL by " .. math.floor(pred.overheal_amount) .. " HP")
                    end
                else
                    print("No prediction available for " .. args)
                end
            else
                print("Usage: /healpred predict <player>")
            end
        elseif cmd == "status" then
            local status = HealPredictionEngine:GetStatus()
            print("Heal Prediction Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Heal Prediction Commands:")
            print("  /healpred predict <player> - Show prediction for player")
            print("  /healpred status - Show system status")
        end
    end
end

return HealPredictionEngine
