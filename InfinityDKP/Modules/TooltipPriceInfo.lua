-- TooltipPriceInfo.lua - Show DKP point values in item tooltips
-- Part of InfinityDKP addon suite
-- Displays estimated GP cost and priority info when hovering items

local TooltipPriceInfo = {}
TooltipPriceInfo.enabled = false
TooltipPriceInfo.db = nil
TooltipPriceInfo.cache = {}

-- Configuration
TooltipPriceInfo.config = {
    enabled = true,
    show_gp_estimate = true,
    show_ep_value = false,
    show_priority = true,
    show_times_awarded = true,
    cache_size = 1000,
    update_cache_interval = 300, -- 5 minutes
}

function TooltipPriceInfo:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDKP")
    if not self.db then
        self:Log("No DKP database found")
        return
    end
    
    self.enabled = true
    
    -- Hook into tooltip system
    if GameTooltip then
        GameTooltip:HookScript("OnTooltipSetItem", function(self)
            TooltipPriceInfo:OnTooltipShow(self)
        end)
    end
    
    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", function(self)
            TooltipPriceInfo:OnTooltipShow(self)
        end)
    end
    
    self:Log("Initialized")
end

function TooltipPriceInfo:OnTooltipShow(tooltip)
    if not self.enabled or not self.db then
        return
    end
    
    -- Get item link from tooltip
    local name, link = tooltip:GetItem()
    if not link then
        return
    end
    
    -- Parse item ID from link
    local itemID = self:ExtractItemID(link)
    if not itemID then
        return
    end
    
    -- Get price info
    local priceInfo = self:GetItemPrice(itemID)
    if priceInfo then
        self:AddTooltipLines(tooltip, priceInfo)
    end
end

function TooltipPriceInfo:ExtractItemID(link)
    if not link then
        return nil
    end
    
    -- Item links are |cff9d9d9d|Hitem:12345:0:0:0:0:0:0:0:0:0|h[Item Name]|h|r
    local itemID = link:match("item:(%d+):")
    return tonumber(itemID)
end

function TooltipPriceInfo:GetItemPrice(itemID)
    if not itemID then
        return nil
    end
    
    -- Check cache
    if self.cache[itemID] then
        return self.cache[itemID]
    end
    
    -- Look up in DKP economy system
    if not self.db.economy or not self.db.economy.item_prices then
        return nil
    end
    
    local priceData = self.db.economy.item_prices[itemID]
    if not priceData then
        return nil
    end
    
    -- Calculate statistics
    local stats = self:CalculateItemStats(itemID, priceData)
    
    -- Cache the result
    self.cache[itemID] = stats
    
    return stats
end

function TooltipPriceInfo:CalculateItemStats(itemID, priceData)
    local stats = {
        item_id = itemID,
        gp_base = priceData.gp or 0,
        ep_base = priceData.ep or 0,
        times_awarded = 0,
        last_awarded = nil,
        average_winner_dkp = 0,
        min_winning_bid = 0,
        max_winning_bid = 0,
        avg_winning_bid = 0,
    }
    
    -- Count how many times this item was awarded
    if self.db.loot_history then
        local count = 0
        local totalBid = 0
        
        for _, entry in ipairs(self.db.loot_history or {}) do
            if entry.item_id == itemID then
                count = count + 1
                totalBid = totalBid + (entry.gp_cost or 0)
                
                -- Track last award
                if not stats.last_awarded or entry.timestamp > stats.last_awarded then
                    stats.last_awarded = entry.timestamp
                end
            end
        end
        
        stats.times_awarded = count
        if count > 0 then
            stats.avg_winning_bid = totalBid / count
        end
    end
    
    return stats
end

function TooltipPriceInfo:AddTooltipLines(tooltip, priceInfo)
    if not priceInfo then
        return
    end
    
    -- Add blank line
    tooltip:AddLine(" ")
    
    -- Add header
    tooltip:AddLine("DKP Information", 0.5, 1, 0.5)
    
    -- Add GP estimate
    if self.config.show_gp_estimate then
        local gpText = "GP Cost: " .. tostring(math.floor(priceInfo.gp_base))
        tooltip:AddDoubleLine(gpText, "", 1, 1, 0, 1, 0.8, 0.8)
    end
    
    -- Add times awarded
    if self.config.show_times_awarded then
        local timesText = "Times Awarded: " .. tostring(priceInfo.times_awarded)
        tooltip:AddDoubleLine(timesText, "", 0.8, 0.8, 0.8, 1, 1, 1)
    end
    
    -- Add average winning bid
    if priceInfo.times_awarded > 0 then
        local avgBidText = "Avg Bid: " .. tostring(math.floor(priceInfo.avg_winning_bid)) .. " DKP"
        tooltip:AddDoubleLine(avgBidText, "", 1, 0.8, 0, 1, 1, 1)
    end
    
    -- Add last awarded
    if priceInfo.last_awarded then
        local daysAgo = math.floor((time() - priceInfo.last_awarded) / (24 * 60 * 60))
        local lastText = "Last Awarded: " .. tostring(daysAgo) .. " days ago"
        tooltip:AddDoubleLine(lastText, "", 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
    end
end

function TooltipPriceInfo:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function TooltipPriceInfo:ClearCache()
    self.cache = {}
    self:Log("Cache cleared")
end

function TooltipPriceInfo:GetStatus()
    return {
        enabled = self.enabled,
        cache_size = self:CountTable(self.cache),
        config = self.config,
    }
end

function TooltipPriceInfo:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function TooltipPriceInfo:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[TooltipPriceInfo] " .. message)
    else
        print("[TooltipPriceInfo] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_TOOLTIPPRICE1 = "/tooltipprice"
    SlashCmdList["TOOLTIPPRICE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "toggle" then
            TooltipPriceInfo.enabled = not TooltipPriceInfo.enabled
            print("Tooltip price info: " .. (TooltipPriceInfo.enabled and "ENABLED" or "DISABLED"))
        elseif cmd == "cache" then
            if args == "clear" then
                TooltipPriceInfo:ClearCache()
            else
                local status = TooltipPriceInfo:GetStatus()
                print("Cache entries: " .. tostring(status.cache_size))
            end
        elseif cmd == "status" then
            local status = TooltipPriceInfo:GetStatus()
            print("Tooltip Price Info Status:")
            print("  enabled: " .. tostring(status.enabled))
            print("  cache_size: " .. tostring(status.cache_size))
        else
            print("Tooltip Price Info Commands:")
            print("  /tooltipprice toggle - Toggle tooltip display")
            print("  /tooltipprice cache clear - Clear price cache")
            print("  /tooltipprice status - Show current status")
        end
    end
end

return TooltipPriceInfo
