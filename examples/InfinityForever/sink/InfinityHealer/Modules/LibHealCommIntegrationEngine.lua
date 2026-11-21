-- LibHealCommIntegrationEngine.lua - Integrate with LibHealComm library
-- Part of InfinityHealer addon suite
-- Receives incoming heals from LibHealComm and displays them on frames

local LibHealCommIntegrationEngine = {}
LibHealCommIntegrationEngine.enabled = false
LibHealCommIntegrationEngine.db = nil
LibHealCommIntegrationEngine.incoming_heals = {}
LibHealCommIntegrationEngine.lib_healcomm = nil

-- Configuration
LibHealCommIntegrationEngine.config = {
    enabled = true,
    lib_enabled = false,  -- Set to true if LibHealComm is available
    sync_frequency = 0.1,
    max_heals_to_track = 100,
    heal_timeout = 10,
    trust_sources = true,
}

function LibHealCommIntegrationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.lib_healcomm_heals then
        self.db.lib_healcomm_heals = {}
    end
    
    self.incoming_heals = self.db.lib_healcomm_heals
    
    -- Try to load LibHealComm
    if self:TryLoadLibHealComm() then
        self.config.lib_enabled = true
        self:Log("LibHealComm integration enabled")
    else
        self:Log("LibHealComm not available - falling back to basic healing comms")
    end
    
    self.enabled = true
end

function LibHealCommIntegrationEngine:TryLoadLibHealComm()
    -- Try to load the library
    local LibHealComm = LibStub and LibStub:GetLibrary("LibHealComm-4.0")
    
    if not LibHealComm then
        return false
    end
    
    self.lib_healcomm = LibHealComm
    
    -- Register for healing updates
    if LibHealComm.RegisterCallback then
        LibHealComm:RegisterCallback(self, "HealComm_HealStarted", "OnHealStarted")
        LibHealComm:RegisterCallback(self, "HealComm_HealDelayed", "OnHealDelayed")
        LibHealComm:RegisterCallback(self, "HealComm_HealDone", "OnHealDone")
    end
    
    return true
end

function LibHealCommIntegrationEngine:OnHealStarted(guid, casterGUID, spellID, healAmount, castEndTime)
    -- Heal cast started
    self:RecordIncomingHeal(guid, casterGUID, spellID, healAmount, castEndTime)
end

function LibHealCommIntegrationEngine:OnHealDelayed(guid, casterGUID, spellID, healAmount, castEndTime)
    -- Heal cast is delayed (channeled spell)
    self:RecordIncomingHeal(guid, casterGUID, spellID, healAmount, castEndTime)
end

function LibHealCommIntegrationEngine:OnHealDone(guid, casterGUID, spellID, healAmount, actualAmount, overHeal, absorbed)
    -- Heal completed
    self:RemoveIncomingHeal(guid, casterGUID, spellID)
end

function LibHealCommIntegrationEngine:RecordIncomingHeal(targetGUID, casterGUID, spellID, healAmount, castEndTime)
    if not targetGUID or not casterGUID or not spellID or not healAmount then
        return false
    end
    
    if #self.incoming_heals >= self.config.max_heals_to_track then
        self:CleanupExpiredHeals()
    end
    
    local healData = {
        target_guid = targetGUID,
        caster_guid = casterGUID,
        spell_id = spellID,
        amount = healAmount,
        cast_end_time = castEndTime,
        recorded_at = GetTime(),
        expires_at = GetTime() + self.config.heal_timeout,
    }
    
    table.insert(self.incoming_heals, healData)
    
    return true
end

function LibHealCommIntegrationEngine:RemoveIncomingHeal(targetGUID, casterGUID, spellID)
    for i = #self.incoming_heals, 1, -1 do
        local heal = self.incoming_heals[i]
        
        if heal.target_guid == targetGUID and heal.caster_guid == casterGUID and heal.spell_id == spellID then
            table.remove(self.incoming_heals, i)
            return true
        end
    end
    
    return false
end

function LibHealCommIntegrationEngine:GetIncomingHealsForTarget(targetGUID)
    if not targetGUID then
        return {}
    end
    
    local heals = {}
    local currentTime = GetTime()
    
    for _, heal in ipairs(self.incoming_heals) do
        if heal.target_guid == targetGUID and currentTime < heal.expires_at then
            table.insert(heals, heal)
        end
    end
    
    return heals
end

function LibHealCommIntegrationEngine:GetTotalIncomingHealForTarget(targetGUID)
    if not targetGUID then
        return 0
    end
    
    local heals = self:GetIncomingHealsForTarget(targetGUID)
    local total = 0
    
    for _, heal in ipairs(heals) do
        total = total + heal.amount
    end
    
    return total
end

function LibHealCommIntegrationEngine:CleanupExpiredHeals()
    local currentTime = GetTime()
    local remaining = {}
    
    for _, heal in ipairs(self.incoming_heals) do
        if currentTime < heal.expires_at then
            table.insert(remaining, heal)
        end
    end
    
    self.incoming_heals = remaining
    
    return #remaining
end

function LibHealCommIntegrationEngine:GetHealsInProgress()
    self:CleanupExpiredHeals()
    return #self.incoming_heals
end

function LibHealCommIntegrationEngine:IsLibHealCommAvailable()
    return self.lib_healcomm ~= nil
end

function LibHealCommIntegrationEngine:GetLibHealCommStatus()
    if not self.lib_healcomm then
        return "UNAVAILABLE"
    end
    
    if self.config.lib_enabled then
        return "ENABLED"
    else
        return "LOADED_BUT_DISABLED"
    end
end

function LibHealCommIntegrationEngine:SetLibHealCommEnabled(enabled)
    if not self.lib_healcomm then
        return false
    end
    
    self.config.lib_enabled = enabled
    self:Log("LibHealComm: " .. (enabled and "enabled" or "disabled"))
    return true
end

function LibHealCommIntegrationEngine:GetStatus()
    return {
        enabled = self.enabled,
        lib_healcomm_available = self:IsLibHealCommAvailable(),
        lib_healcomm_status = self:GetLibHealCommStatus(),
        heals_in_progress = self:GetHealsInProgress(),
        max_track_heals = self.config.max_heals_to_track,
        heal_timeout = self.config.heal_timeout,
    }
end

function LibHealCommIntegrationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[LibHealCommIntegrationEngine] " .. message)
    else
        print("[LibHealCommIntegrationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_LIBHEALCOMM1 = "/libhealcomm"
    SlashCmdList["LIBHEALCOMM"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "check" then
            if LibHealCommIntegrationEngine:IsLibHealCommAvailable() then
                print("LibHealComm is available!")
                print("Status: " .. LibHealCommIntegrationEngine:GetLibHealCommStatus())
            else
                print("LibHealComm not found")
                print("Install LibHealComm-4.0 to enable advanced heal prediction")
            end
        elseif cmd == "enable" then
            if LibHealCommIntegrationEngine:SetLibHealCommEnabled(true) then
                print("LibHealComm integration enabled")
            else
                print("LibHealComm not available")
            end
        elseif cmd == "disable" then
            LibHealCommIntegrationEngine:SetLibHealCommEnabled(false)
            print("LibHealComm integration disabled")
        elseif cmd == "heals" then
            local healCount = LibHealCommIntegrationEngine:GetHealsInProgress()
            print("Heals in progress: " .. healCount)
        elseif cmd == "cleanup" then
            local remaining = LibHealCommIntegrationEngine:CleanupExpiredHeals()
            print("Cleaned up expired heals. Remaining: " .. remaining)
        elseif cmd == "status" then
            local status = LibHealCommIntegrationEngine:GetStatus()
            print("LibHealComm Integration Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("LibHealComm Integration Commands:")
            print("  /libhealcomm check - Check if LibHealComm is available")
            print("  /libhealcomm enable - Enable LibHealComm integration")
            print("  /libhealcomm disable - Disable LibHealComm integration")
            print("  /libhealcomm heals - Show heals in progress")
            print("  /libhealcomm cleanup - Clean up expired heals")
            print("  /libhealcomm status - Show system status")
        end
    end
end

return LibHealCommIntegrationEngine
