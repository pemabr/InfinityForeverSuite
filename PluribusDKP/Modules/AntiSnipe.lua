-- Anti-Snipe System for DKP Auctions
-- Prevents last-second bids by extending auction timer

local MODULE_NAME = "AntiSnipe"
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusDKP.AntiSnipe = {
    enabled = false,
    
    -- Configuration
    config = {
        anti_snipe_enabled = true,
        snipe_window = 10,              -- Last 10 seconds
        snipe_extension = 30,           -- Extend by 30 seconds if bid in snipe window
        max_extensions = 5,             -- Maximum number of extensions
        min_bid_increase = 5             -- Minimum DKP increase for new bid
    },
    
    active_auctions = {}
}

local AntiSnipe = PluribusDKP.AntiSnipe

function AntiSnipe:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if PluribusCore.Events then
        PluribusCore.Events:Register("auction_started", function(item, start_time, duration)
            AntiSnipe:TrackAuction(item, start_time, duration)
        end)
        
        PluribusCore.Events:Register("bid_placed", function(player, item, bid_amount, timestamp)
            AntiSnipe:OnBidPlaced(player, item, bid_amount, timestamp)
        end)
        
        PluribusCore.Events:Register("auction_ended", function(item, winner, final_bid)
            AntiSnipe:RemoveAuction(item)
        end)
    end
end

function AntiSnipe:TrackAuction(item, start_time, duration)
    if not item then return end
    
    self.active_auctions[item] = {
        start_time = start_time or GetTime(),
        duration = duration or 60,
        end_time = (start_time or GetTime()) + (duration or 60),
        extensions = 0,
        bids = {}
    }
end

function AntiSnipe:OnBidPlaced(player, item, bid_amount, timestamp)
    if not self.config.anti_snipe_enabled then return end
    if not item or not player then return end
    
    local auction = self.active_auctions[item]
    if not auction then return end
    
    local current_time = timestamp or GetTime()
    local time_remaining = auction.end_time - current_time
    
    -- Check if we're in the snipe window
    if time_remaining > 0 and time_remaining <= self.config.snipe_window then
        if auction.extensions < self.config.max_extensions then
            -- Extend the auction
            local extension_amount = self.config.snipe_extension
            auction.end_time = auction.end_time + extension_amount
            auction.extensions = auction.extensions + 1
            
            local new_remaining = auction.end_time - current_time
            
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage(
                    string.format("|cff00ccffAuction extended! New time remaining: %ds (Extension %d/%d)|r",
                        new_remaining,
                        auction.extensions,
                        self.config.max_extensions
                    )
                )
            end
            
            if PluribusCore.Events then
                PluribusCore.Events:Fire("auction_extended", item, extension_amount, auction.extensions)
            end
        end
    end
    
    -- Track the bid
    table.insert(auction.bids, {
        player = player,
        amount = bid_amount,
        time = current_time
    })
end

function AntiSnipe:RemoveAuction(item)
    if item then
        self.active_auctions[item] = nil
    end
end

function AntiSnipe:GetAuctionTimeRemaining(item)
    if not item or not self.active_auctions[item] then
        return nil
    end
    
    local auction = self.active_auctions[item]
    local remaining = auction.end_time - GetTime()
    
    return math.max(0, remaining)
end

function AntiSnipe:GetExtensionCount(item)
    if not item or not self.active_auctions[item] then
        return 0
    end
    
    return self.active_auctions[item].extensions
end

function AntiSnipe:CanExtend(item)
    if not item or not self.active_auctions[item] then
        return false
    end
    
    local auction = self.active_auctions[item]
    return auction.extensions < self.config.max_extensions
end

function AntiSnipe:GetAuctionBidHistory(item)
    if not item or not self.active_auctions[item] then
        return {}
    end
    
    return self.active_auctions[item].bids or {}
end

function AntiSnipe:SetSniperWindow(seconds)
    if seconds < 1 or seconds > 60 then
        print("|cffff0000Snipe window must be 1-60 seconds|r")
        return false
    end
    
    self.config.snipe_window = seconds
    print(string.format("|cff00ccffSnipe window set to %d seconds|r", seconds))
    return true
end

function AntiSnipe:SetExtensionAmount(seconds)
    if seconds < 1 or seconds > 300 then
        print("|cffff0000Extension amount must be 1-300 seconds|r")
        return false
    end
    
    self.config.snipe_extension = seconds
    print(string.format("|cff00ccffExtension amount set to %d seconds|r", seconds))
    return true
end

function AntiSnipe:SetMaxExtensions(max_count)
    if max_count < 1 or max_count > 20 then
        print("|cffff0000Max extensions must be 1-20|r")
        return false
    end
    
    self.config.max_extensions = max_count
    print(string.format("|cff00ccffMax extensions set to %d|r", max_count))
    return true
end

function AntiSnipe:EnableAntiSnipe(enable)
    self.config.anti_snipe_enabled = enable
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffAnti-snipe %s|r", status))
    return true
end

function AntiSnipe:PrintStatus()
    print("|cff00ccffAnti-Snipe Configuration:|r")
    print(string.format("  Enabled: %s", self.config.anti_snipe_enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Snipe Window: %d seconds", self.config.snipe_window))
    print(string.format("  Extension Amount: %d seconds", self.config.snipe_extension))
    print(string.format("  Max Extensions: %d", self.config.max_extensions))
    print(string.format("  Active Auctions: %d", self:CountActiveAuctions()))
    print("")
end

function AntiSnipe:CountActiveAuctions()
    local count = 0
    for _, _ in pairs(self.active_auctions) do
        count = count + 1
    end
    return count
end

function AntiSnipe:PrintActiveAuctions()
    print("|cff00ccffActive Auctions:|r")
    print("")
    
    local count = 0
    for item, auction in pairs(self.active_auctions) do
        local time_remaining = math.max(0, auction.end_time - GetTime())
        print(string.format("  %s - %.0fs remaining (%d extensions)",
            item,
            time_remaining,
            auction.extensions
        ))
        count = count + 1
    end
    
    if count == 0 then
        print("  No active auctions")
    end
    print("")
end

return PluribusDKP.AntiSnipe
