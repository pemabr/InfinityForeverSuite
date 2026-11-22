-- TooltipPriceInfo.lua - Show DKP point values in item tooltips
-- Part of InfinityDKP addon suite
-- Displays locally recorded DKP information when hovering items

local TooltipPriceInfo = {}
_G.InfinityDKPTooltipPriceInfo = TooltipPriceInfo
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
    
    -- Hook into tooltip system (Forever 1.60.1 TooltipDataProcessor + legacy fallback)
    if not self.hooked then
        local hooked = false
        if _G.TooltipDataProcessor and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function" and _G.Enum and _G.Enum.TooltipDataType and _G.Enum.TooltipDataType.Item then
            local ok, err = pcall(_G.TooltipDataProcessor.AddTooltipPostCall, _G.Enum.TooltipDataType.Item, function(tooltip, data)
                TooltipPriceInfo:OnTooltipShow(tooltip, data)
            end)
            if ok and not (issecretvalue and issecretvalue(err)) and err ~= false then hooked = true
            else
                if issecretvalue and issecretvalue(err) then err = nil end
                InfinityUtils:Warning("DKP tooltip registration failed: " .. tostring(err or "protected error"), "DKP")
            end
        else
            if GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
                GameTooltip:HookScript("OnTooltipSetItem", function(tt)
                    TooltipPriceInfo:OnTooltipShow(tt)
                end)
                hooked = true
            end
            if ItemRefTooltip and ItemRefTooltip.HasScript and ItemRefTooltip:HasScript("OnTooltipSetItem") then
                ItemRefTooltip:HookScript("OnTooltipSetItem", function(tt)
                    TooltipPriceInfo:OnTooltipShow(tt)
                end)
                hooked = true
            end
        end
        self.hooked = hooked
        if not hooked then InfinityUtils:Warning("DKP item tooltip hooks unavailable.", "DKP") end
    end
    
    self:Log("Initialized")
end

function TooltipPriceInfo:OnTooltipShow(tooltip, data)
    if not self.enabled or not self.config.enabled or not tooltip then
        return
    end
    if InfinitySettingsPanel and InfinitySettingsPanel:GetSetting("General", "Enable Tooltips") == false then return end
    local forbidden = tooltip.IsForbidden and tooltip:IsForbidden()
    if (issecretvalue and issecretvalue(forbidden)) or forbidden then
        return
    end
    
    if (issecretvalue and issecretvalue(data)) or type(data) ~= "table" then data = nil end
    local itemID = data and data.id
    if (issecretvalue and issecretvalue(itemID)) or type(itemID) ~= "number" or itemID ~= itemID
        or itemID <= 0 or itemID > 1000000000 or itemID ~= math.floor(itemID) then itemID = nil end
    if not itemID and tooltip.GetItem then
        local ok, _, link = pcall(tooltip.GetItem, tooltip)
        if ok then itemID = self:ExtractItemID(link)
        elseif not self.warnedRead then
            self.warnedRead = true
            InfinityUtils:Warning("DKP tooltip item information is unavailable.", "DKP")
        end
    end
    if not itemID and data then
        itemID = self:ExtractItemID(data.hyperlink)
    end
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
    if (issecretvalue and issecretvalue(link)) or type(link) ~= "string" then
        return nil
    end
    
    -- Item links are |cff9d9d9d|Hitem:12345:0:0:0:0:0:0:0:0:0|h[Item Name]|h|r
    local itemID = link:match("item:(%d+)")
    itemID = tonumber(itemID)
    if itemID and itemID > 0 and itemID <= 1000000000 then return itemID end
end

function TooltipPriceInfo:GetItemPrice(itemID)
    if not itemID then
        return nil
    end
    
    -- Only display configured prices or recorded awards, never inferred costs.
    local economy = self.db and self.db.economy
    if (issecretvalue and issecretvalue(economy)) or type(economy) ~= "table" then economy = nil end
    local prices = economy and economy.item_prices
    if (issecretvalue and issecretvalue(prices)) or type(prices) ~= "table" then prices = nil end
    local priceData = prices and prices[itemID]
    if (issecretvalue and issecretvalue(priceData)) or type(priceData) ~= "table" then priceData = {} end
    
    -- Calculate statistics
    local stats = self:CalculateItemStats(itemID, priceData)
    
    if stats.gp_base ~= nil or stats.times_awarded > 0 then return stats end
    return nil
end

function TooltipPriceInfo:CalculateItemStats(itemID, priceData)
    local gp = priceData.gp
    if (issecretvalue and issecretvalue(gp)) or type(gp) ~= "number" or gp ~= gp or gp < 0 or gp > 1000000000 then gp = nil end
    local stats = {
        item_id = itemID,
        gp_base = gp,
        times_awarded = 0,
        last_awarded = nil,
        avg_winning_bid = 0,
        bid_count = 0,
        dkp_total = 0,
        dkp_count = 0,
    }
    local gpTotal = 0
    local function Add(id, points, kind, timestamp, refund)
        if issecretvalue and (issecretvalue(id) or issecretvalue(points) or issecretvalue(kind)
            or issecretvalue(timestamp) or issecretvalue(refund)) then return end
        if id ~= itemID then return end
        stats.times_awarded = stats.times_awarded + 1
        if type(timestamp) == "number" and timestamp == timestamp and timestamp > 0
            and timestamp < math.huge and (not stats.last_awarded or timestamp > stats.last_awarded) then
            stats.last_awarded = timestamp
        end
        if not refund and type(points) == "number" and points == points and points >= 0 and points <= 1000000000 then
            if kind == "manual" then
                gpTotal, stats.bid_count = gpTotal + points, stats.bid_count + 1
            elseif kind == "dkp" then
                stats.dkp_total, stats.dkp_count = stats.dkp_total + points, stats.dkp_count + 1
            end
        end
    end
    local legacy = self.db.loot_history
    if not (issecretvalue and issecretvalue(legacy)) and type(legacy) == "table" then
        for _, entry in ipairs(legacy) do
            if not (issecretvalue and issecretvalue(entry)) and type(entry) == "table" then
                Add(entry.item_id, entry.gp_cost, "manual", entry.timestamp, entry.refund)
            end
        end
    end
    local history = _G.InfinityDKPHistory
    local awards = history and history.awards
    if not (issecretvalue and issecretvalue(awards)) and type(awards) == "table" then
        for _, award in ipairs(awards) do
            if not (issecretvalue and issecretvalue(award)) and type(award) == "table" then
                Add(award.itemID, award.points, award.type, award.time, award.refund)
            end
        end
    end
    if stats.bid_count > 0 then stats.avg_winning_bid = gpTotal / stats.bid_count end
    return stats
end

function TooltipPriceInfo:AddTooltipLines(tooltip, priceInfo)
    if not priceInfo then
        return
    end
    
    -- Add blank line
    tooltip:AddLine(" ")
    
    -- Add header
    tooltip:AddLine("Local DKP Information", 0.5, 1, 0.5)
    
    -- Add GP estimate
    if self.config.show_gp_estimate and priceInfo.gp_base ~= nil then
        local gpText = "Configured GP: " .. tostring(priceInfo.gp_base)
        tooltip:AddDoubleLine(gpText, "", 1, 1, 0, 1, 0.8, 0.8)
    end
    
    -- Add times awarded
    if self.config.show_times_awarded and priceInfo.times_awarded > 0 then
        local timesText = "Times Awarded (including refunds): " .. tostring(priceInfo.times_awarded)
        tooltip:AddDoubleLine(timesText, "", 0.8, 0.8, 0.8, 1, 1, 1)
    end
    
    -- Add average winning bid
    if priceInfo.bid_count > 0 then
        local avgBidText = "Avg Recorded GP: " .. tostring(math.floor(priceInfo.avg_winning_bid))
        tooltip:AddDoubleLine(avgBidText, "", 1, 0.8, 0, 1, 1, 1)
    end
    if priceInfo.dkp_count > 0 then
        local avgDKP = "Avg Recorded DKP: " .. tostring(math.floor(priceInfo.dkp_total / priceInfo.dkp_count))
        tooltip:AddDoubleLine(avgDKP, "", 1, 0.8, 0, 1, 1, 1)
    end
    
    -- Add last awarded
    if priceInfo.last_awarded then
        local now = time()
        if not (issecretvalue and issecretvalue(now)) and type(now) == "number" and now == now and now < math.huge then
            local daysAgo = math.max(0, math.floor((now - priceInfo.last_awarded) / (24 * 60 * 60)))
            local lastText = "Last Awarded: " .. tostring(daysAgo) .. " days ago"
            tooltip:AddDoubleLine(lastText, "", 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
        end
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
