-- HealCommunicationEngine.lua - Share incoming heal data with raid group
-- Part of PluribusHealer addon suite
-- Broadcasts heals to group and receives incoming heal announcements

local HealCommunicationEngine = {}
HealCommunicationEngine.enabled = false
HealCommunicationEngine.db = nil
HealCommunicationEngine.incoming_heals = {}

-- Configuration
HealCommunicationEngine.config = {
    enabled = true,
    broadcast_heals = true,
    receive_heals = true,
    update_frequency = 0.1,
    broadcast_channel = "RAID",  -- RAID, PARTY, GUILD
    heal_timeout = 10,
    min_heal_to_broadcast = 100,
}

function HealCommunicationEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.incoming_heals then
        self.db.incoming_heals = {}
    end
    
    self.incoming_heals = self.db.incoming_heals
    self.enabled = true
    
    self:Log("Initialized with channel: " .. self.config.broadcast_channel)
end

function HealCommunicationEngine:BroadcastHeal(targetUnit, spellName, healAmount, isCrit)
    if not self.config.broadcast_heals then
        return false
    end
    
    if healAmount < self.config.min_heal_to_broadcast then
        return false
    end
    
    if not targetUnit or not spellName then
        return false
    end
    
    local targetName = UnitName(targetUnit)
    local message = string.format("HEAL:%s:%s:%d:%s",
        spellName,
        targetName,
        healAmount,
        isCrit and "1" or "0"
    )
    
    if GetNumGroupMembers() > 0 then
        if IsInRaid() then
            SendChatMessage(message, self.config.broadcast_channel)
        elseif IsInGroup() then
            SendChatMessage(message, "PARTY")
        end
    end
    
    return true
end

function HealCommunicationEngine:RegisterIncomingHeal(sourceName, targetUnit, spellName, healAmount, isCrit)
    if not targetUnit then
        return false
    end
    
    if not self.incoming_heals[targetUnit] then
        self.incoming_heals[targetUnit] = {}
    end
    
    -- Store incoming heal
    self.incoming_heals[targetUnit][sourceName] = {
        source = sourceName,
        spell = spellName,
        amount = healAmount,
        is_crit = isCrit or false,
        received_at = GetTime(),
        expires_at = GetTime() + self.config.heal_timeout,
    }
    
    return true
end

function HealCommunicationEngine:GetIncomingHeals(targetUnit)
    if not targetUnit or not self.incoming_heals[targetUnit] then
        return {}
    end
    
    local heals = {}
    local currentTime = GetTime()
    
    -- Filter out expired heals
    for sourceName, healData in pairs(self.incoming_heals[targetUnit]) do
        if currentTime < healData.expires_at then
            table.insert(heals, healData)
        else
            self.incoming_heals[targetUnit][sourceName] = nil
        end
    end
    
    return heals
end

function HealCommunicationEngine:GetTotalIncomingHeal(targetUnit)
    if not targetUnit then
        return 0
    end
    
    local heals = self:GetIncomingHeals(targetUnit)
    local total = 0
    
    for _, healData in ipairs(heals) do
        total = total + healData.amount
    end
    
    return total
end

function HealCommunicationEngine:GetIncomingHealReport(targetUnit)
    if not targetUnit or not UnitExists(targetUnit) then
        return nil
    end
    
    local heals = self:GetIncomingHeals(targetUnit)
    
    if #heals == 0 then
        return {
            unit = targetUnit,
            incoming_heal_count = 0,
            total_incoming = 0,
        }
    end
    
    local total = 0
    for _, healData in ipairs(heals) do
        total = total + healData.amount
    end
    
    return {
        unit = targetUnit,
        incoming_heal_count = #heals,
        total_incoming = total,
        heals = heals,
    }
end

function HealCommunicationEngine:SetBroadcastChannel(channel)
    if channel == "RAID" or channel == "PARTY" or channel == "GUILD" then
        self.config.broadcast_channel = channel
        self:Log("Broadcast channel set to: " .. channel)
        return true
    end
    return false
end

function HealCommunicationEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function HealCommunicationEngine:GetStatus()
    local incomingCount = 0
    
    for _, heals in pairs(self.incoming_heals) do
        for _ in pairs(heals) do
            incomingCount = incomingCount + 1
        end
    end
    
    return {
        enabled = self.enabled,
        broadcast_heals = self.config.broadcast_heals,
        receive_heals = self.config.receive_heals,
        broadcast_channel = self.config.broadcast_channel,
        incoming_heals = incomingCount,
    }
end

function HealCommunicationEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[HealCommunicationEngine] " .. message)
    else
        print("[HealCommunicationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HEALCOMM1 = "/healcomm"
    SlashCmdList["HEALCOMM"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "broadcast" then
            if args == "on" then
                HealCommunicationEngine:SetConfig("broadcast_heals", true)
                print("Heal broadcasting enabled")
            elseif args == "off" then
                HealCommunicationEngine:SetConfig("broadcast_heals", false)
                print("Heal broadcasting disabled")
            else
                print("Usage: /healcomm broadcast <on|off>")
            end
        elseif cmd == "receive" then
            if args == "on" then
                HealCommunicationEngine:SetConfig("receive_heals", true)
                print("Heal receiving enabled")
            elseif args == "off" then
                HealCommunicationEngine:SetConfig("receive_heals", false)
                print("Heal receiving disabled")
            else
                print("Usage: /healcomm receive <on|off>")
            end
        elseif cmd == "channel" then
            if args and args ~= "" then
                if HealCommunicationEngine:SetBroadcastChannel(args) then
                    print("Broadcast channel: " .. args)
                else
                    print("Usage: /healcomm channel <RAID|PARTY|GUILD>")
                end
            else
                print("Current channel: " .. HealCommunicationEngine.config.broadcast_channel)
            end
        elseif cmd == "check" then
            if args and args ~= "" then
                local report = HealCommunicationEngine:GetIncomingHealReport(args)
                if report then
                    print("Incoming heals for " .. args .. ":")
                    if report.incoming_heal_count > 0 then
                        print("  Total: " .. math.floor(report.total_incoming))
                        for _, heal in ipairs(report.heals) do
                            print("    " .. heal.source .. " - " .. heal.spell .. ": " .. heal.amount)
                        end
                    else
                        print("  No incoming heals")
                    end
                else
                    print("Unit not found: " .. args)
                end
            else
                print("Usage: /healcomm check <unit>")
            end
        elseif cmd == "status" then
            local status = HealCommunicationEngine:GetStatus()
            print("Heal Communication Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Heal Communication Commands:")
            print("  /healcomm broadcast <on|off> - Toggle heal broadcasting")
            print("  /healcomm receive <on|off> - Toggle heal receiving")
            print("  /healcomm channel <RAID|PARTY|GUILD> - Set broadcast channel")
            print("  /healcomm check <unit> - Check incoming heals")
            print("  /healcomm status - Show system status")
        end
    end
end

return HealCommunicationEngine
