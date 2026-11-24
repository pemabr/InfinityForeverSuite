-- Minimum GP Thresholds System
-- Enforce minimum gear point costs to prevent too-cheap gearing

local MODULE_NAME = "MinGPThresholds"
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusDKP.MinGP = {
    enabled = false,
    
    config = {
        min_gp_enabled = true,
        min_gp_global = 50,              -- Global minimum GP per item
        min_gp_per_quality = {           -- Per-rarity minimum
            [0] = 10,   -- Gray
            [1] = 10,   -- White
            [2] = 20,   -- Green
            [3] = 50,   -- Blue
            [4] = 100,  -- Purple
            [5] = 200,  -- Orange
            [6] = 300   -- Artifact
        },
        min_gp_per_slot = {},            -- Per-slot minimum (optional)
        enforce_on_bid = true,
        enforce_on_award = true,
        log_violations = true
    },
    
    violations = {}
}

local MinGP = PluribusDKP.MinGP

function MinGP:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if not PluribusDKP.db then
        PluribusDKP.db = {}
    end
    if not PluribusDKP.db.min_gp_violations then
        PluribusDKP.db.min_gp_violations = {}
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Register("bid_placed", function(player, item, bid_amount)
            MinGP:ValidateBidGP(player, item, bid_amount)
        end)
        
        PluribusCore.Events:Register("loot_awarded", function(player, item, gp_cost)
            MinGP:ValidateAwardGP(player, item, gp_cost)
        end)
    end
end

function MinGP:CalculateMinimumGP(item)
    if not item then return self.config.min_gp_global end
    
    -- Get item quality
    local quality = item.quality or 1
    
    -- Check per-quality minimum
    if self.config.min_gp_per_quality[quality] then
        return math.max(
            self.config.min_gp_global,
            self.config.min_gp_per_quality[quality]
        )
    end
    
    -- Check per-slot minimum (if configured)
    if item.slot and self.config.min_gp_per_slot[item.slot] then
        return math.max(
            self.config.min_gp_global,
            self.config.min_gp_per_slot[item.slot]
        )
    end
    
    return self.config.min_gp_global
end

function MinGP:ValidateBidGP(player, item, bid_amount)
    if not self.config.min_gp_enabled or not self.config.enforce_on_bid then
        return true, nil
    end
    
    local minimum_gp = self:CalculateMinimumGP(item)
    
    if bid_amount < minimum_gp then
        self:LogViolation(player, item, bid_amount, minimum_gp, "bid")
        
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                string.format("|cffff0000Bid rejected: Minimum GP for %s is %d (you bid %d)|r",
                    item.name or "item",
                    minimum_gp,
                    bid_amount
                )
            )
        end
        
        return false, string.format("Bid too low. Minimum GP: %d", minimum_gp)
    end
    
    return true, nil
end

function MinGP:ValidateAwardGP(player, item, gp_cost)
    if not self.config.min_gp_enabled or not self.config.enforce_on_award then
        return true, nil
    end
    
    local minimum_gp = self:CalculateMinimumGP(item)
    
    if gp_cost < minimum_gp then
        self:LogViolation(player, item, gp_cost, minimum_gp, "award")
        
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(
                string.format("|cffff0000Award warning: Minimum GP for %s is %d (you awarded %d)|r",
                    item.name or "item",
                    minimum_gp,
                    gp_cost
                )
            )
        end
        
        -- Still allow the award but log violation
        return true, "Award below minimum threshold"
    end
    
    return true, nil
end

function MinGP:LogViolation(player, item, gp_attempted, minimum_gp, event_type)
    if not self.config.log_violations then return end
    
    local violation = {
        timestamp = time(),
        player = player,
        item_name = item and item.name or "Unknown",
        gp_attempted = gp_attempted,
        minimum_gp = minimum_gp,
        event_type = event_type,
        shortfall = minimum_gp - gp_attempted
    }
    
    table.insert(self.violations, violation)
    
    if PluribusDKP.db then
        PluribusDKP.db.min_gp_violations = self.violations
    end
end

function MinGP:SetGlobalMinimumGP(gp_amount)
    if gp_amount < 0 or gp_amount > 1000 then
        print("|cffff0000Global minimum GP must be 0-1000|r")
        return false
    end
    
    self.config.min_gp_global = gp_amount
    print(string.format("|cff00ccffGlobal minimum GP set to %d|r", gp_amount))
    return true
end

function MinGP:SetQualityMinimumGP(quality, gp_amount)
    if quality < 0 or quality > 6 then
        print("|cffff0000Quality must be 0-6|r")
        return false
    end
    
    if gp_amount < 0 or gp_amount > 1000 then
        print("|cffff0000Minimum GP must be 0-1000|r")
        return false
    end
    
    self.config.min_gp_per_quality[quality] = gp_amount
    
    local quality_name = self:GetQualityName(quality)
    print(string.format("|cff00ccff%s items minimum GP set to %d|r", quality_name, gp_amount))
    return true
end

function MinGP:SetSlotMinimumGP(slot, gp_amount)
    if not slot then
        print("|cffff0000Slot name required|r")
        return false
    end
    
    if gp_amount < 0 or gp_amount > 2000 then
        print("|cffff0000Minimum GP must be 0-2000|r")
        return false
    end
    
    self.config.min_gp_per_slot[slot] = gp_amount
    print(string.format("|cff00ccff%s minimum GP set to %d|r", slot, gp_amount))
    return true
end

function MinGP:EnableMinimumGP(enable)
    self.config.min_gp_enabled = enable
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffMinimum GP enforcement %s|r", status))
    return true
end

function MinGP:EnableEnforceOnBid(enable)
    self.config.enforce_on_bid = enable
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffMinimum GP enforcement on bids %s|r", status))
    return true
end

function MinGP:EnableEnforceOnAward(enable)
    self.config.enforce_on_award = enable
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffMinimum GP enforcement on awards %s|r", status))
    return true
end

function MinGP:GetQualityName(quality)
    local quality_names = {
        "Gray",
        "White",
        "Green",
        "Blue",
        "Purple",
        "Orange",
        "Artifact"
    }
    
    return quality_names[quality + 1] or "Unknown"
end

function MinGP:PrintStatus()
    print("|cff00ccffMinimum GP Configuration:|r")
    print(string.format("  Enabled: %s", self.config.min_gp_enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Global Minimum: %d", self.config.min_gp_global))
    print(string.format("  Enforce on Bids: %s", self.config.enforce_on_bid and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Enforce on Awards: %s", self.config.enforce_on_award and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Violations Logged: %d", #self.violations))
    print("")
end

function MinGP:PrintQualityLimits()
    print("|cff00ccffQuality-Based Minimum GP:|r")
    print("")
    
    for quality = 0, 6 do
        local min_gp = self.config.min_gp_per_quality[quality] or self.config.min_gp_global
        local quality_name = self:GetQualityName(quality)
        print(string.format("  %s: %d", quality_name, min_gp))
    end
    
    print("")
end

function MinGP:PrintSlotLimits()
    if not next(self.config.min_gp_per_slot) then
        print("|cffff9900No per-slot minimums configured|r")
        return
    end
    
    print("|cff00ccffSlot-Based Minimum GP:|r")
    print("")
    
    for slot, min_gp in pairs(self.config.min_gp_per_slot) do
        print(string.format("  %s: %d", slot, min_gp))
    end
    
    print("")
end

function MinGP:PrintViolations(limit)
    limit = limit or 10
    
    if #self.violations == 0 then
        print("|cffff9900No minimum GP violations recorded|r")
        return
    end
    
    print("|cff00ccffRecent Minimum GP Violations:|r")
    print("")
    
    for i = #self.violations, math.max(1, #self.violations - limit + 1), -1 do
        local violation = self.violations[i]
        local date_str = date("%H:%M:%S", violation.timestamp)
        
        print(string.format("[%s] %s - %s (need %d, tried %d, short %d)",
            date_str,
            violation.player or "Unknown",
            violation.item_name,
            violation.minimum_gp,
            violation.gp_attempted,
            violation.shortfall
        ))
    end
    
    print("")
end

function MinGP:ClearViolations()
    self.violations = {}
    if PluribusDKP.db then
        PluribusDKP.db.min_gp_violations = {}
    end
    print("|cff00ccffMinimum GP violations cleared|r")
end

return PluribusDKP.MinGP
