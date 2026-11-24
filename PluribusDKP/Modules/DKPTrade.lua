-- DKP Trading System
-- Allow players to trade DKP points with each other

local MODULE_NAME = "DKPTrade"
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusDKP.Trade = {
    enabled = false,
    
    -- Configuration
    config = {
        trading_enabled = true,
        min_trade_amount = 1,
        max_trade_amount = 1000,
        trade_tax_enabled = true,
        trade_tax_rate = 0.05,          -- 5% tax
        trade_cooldown_enabled = true,
        trade_cooldown = 3600,          -- 1 hour per player
        require_officer_approval = false
    },
    
    active_trades = {},
    pending_trades = {},
    trade_history = {},
    player_last_trade = {}
}

local Trade = PluribusDKP.Trade

function Trade:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if not PluribusDKP.db then
        PluribusDKP.db = {}
    end
    if not PluribusDKP.db.trade_history then
        PluribusDKP.db.trade_history = {}
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Register("trade_proposed", function(from, to, amount)
            Trade:ReceiveTradeProposal(from, to, amount)
        end)
        
        PluribusCore.Events:Register("trade_accepted", function(from, to, amount, trade_id)
            Trade:ExecuteTrade(from, to, amount, trade_id)
        end)
        
        PluribusCore.Events:Register("trade_rejected", function(trade_id, reason)
            Trade:CancelTrade(trade_id, reason)
        end)
    end
end

function Trade:CanPlayerTrade(player)
    if not player then return false, "No player specified" end
    
    -- Check cooldown
    if self.config.trade_cooldown_enabled then
        local last_trade = self.player_last_trade[player] or 0
        local now = time()
        
        if now - last_trade < self.config.trade_cooldown then
            local remaining = self.config.trade_cooldown - (now - last_trade)
            return false, string.format("Please wait %.0f seconds before trading again", remaining)
        end
    end
    
    return true, nil
end

function Trade:ProposeTradeRequest(from_player, to_player, dkp_amount)
    if not self.config.trading_enabled then
        return false, "Trading is disabled"
    end
    
    if not from_player or not to_player or not dkp_amount then
        return false, "Invalid trade parameters"
    end
    
    if from_player == to_player then
        return false, "Cannot trade with yourself"
    end
    
    if dkp_amount < self.config.min_trade_amount or dkp_amount > self.config.max_trade_amount then
        return false, string.format("Trade amount must be %d-%d DKP",
            self.config.min_trade_amount,
            self.config.max_trade_amount
        )
    end
    
    -- Check if player can trade
    local can_trade, reason = self:CanPlayerTrade(from_player)
    if not can_trade then
        return false, reason
    end
    
    -- Check if from_player has enough DKP
    if not PluribusDKP.db or not PluribusDKP.db.players then
        return false, "Database not ready"
    end
    
    local from_data = PluribusDKP.db.players[from_player]
    if not from_data or (from_data.balance or 0) < dkp_amount then
        return false, "Insufficient DKP balance"
    end
    
    -- Create trade proposal
    local trade_id = self:GenerateTradeID()
    
    self.pending_trades[trade_id] = {
        id = trade_id,
        from = from_player,
        to = to_player,
        amount = dkp_amount,
        status = "pending",
        created_at = time(),
        expires_at = time() + 300  -- 5 minute expiry
    }
    
    -- Notify recipient
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff00ccff%s is proposing to trade %d DKP with you. Type: /pluribus dkp trade accept %s|r",
                from_player,
                dkp_amount,
                trade_id
            )
        )
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("trade_proposed", from_player, to_player, dkp_amount, trade_id)
    end
    
    return true, trade_id
end

function Trade:AcceptTrade(trade_id)
    local trade = self.pending_trades[trade_id]
    if not trade then
        return false, "Trade not found"
    end
    
    if time() > trade.expires_at then
        self.pending_trades[trade_id] = nil
        return false, "Trade has expired"
    end
    
    if trade.status ~= "pending" then
        return false, "Trade is no longer pending"
    end
    
    return self:ExecuteTrade(trade.from, trade.to, trade.amount, trade_id)
end

function Trade:ExecuteTrade(from_player, to_player, dkp_amount, trade_id)
    if not PluribusDKP.db or not PluribusDKP.db.players then
        return false, "Database not ready"
    end
    
    local from_data = PluribusDKP.db.players[from_player]
    local to_data = PluribusDKP.db.players[to_player]
    
    if not from_data or not to_data then
        return false, "Player data not found"
    end
    
    -- Calculate tax
    local tax_amount = 0
    if self.config.trade_tax_enabled then
        tax_amount = math.floor(dkp_amount * self.config.trade_tax_rate)
    end
    
    local net_amount = dkp_amount - tax_amount
    
    -- Execute transfer
    from_data.balance = (from_data.balance or 0) - dkp_amount
    to_data.balance = (to_data.balance or 0) + net_amount
    
    -- Log transactions
    if PluribusDKP.db.transactions then
        table.insert(PluribusDKP.db.transactions, {
            timestamp = time(),
            player = from_player,
            amount = -dkp_amount,
            reason = string.format("Trade to %s (ID: %s)", to_player, trade_id or "manual"),
            balance_after = from_data.balance,
            source = "player",
            type = "trade",
            trade_id = trade_id
        })
        
        table.insert(PluribusDKP.db.transactions, {
            timestamp = time(),
            player = to_player,
            amount = net_amount,
            reason = string.format("Trade from %s (ID: %s)", from_player, trade_id or "manual"),
            balance_after = to_data.balance,
            source = "player",
            type = "trade",
            trade_id = trade_id
        })
    end
    
    -- Log trade
    table.insert(self.trade_history, {
        id = trade_id,
        from = from_player,
        to = to_player,
        gross_amount = dkp_amount,
        tax = tax_amount,
        net_amount = net_amount,
        timestamp = time()
    })
    
    -- Update cooldown
    self.player_last_trade[from_player] = time()
    
    -- Mark pending trade as completed
    if self.pending_trades[trade_id] then
        self.pending_trades[trade_id].status = "completed"
    end
    
    -- Notify both players
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff00ff00Trade completed: %s sent %d DKP to %s (Tax: %d)|r",
                from_player,
                dkp_amount,
                to_player,
                tax_amount
            )
        )
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("trade_completed", from_player, to_player, net_amount, tax_amount)
    end
    
    return true, "Trade completed"
end

function Trade:RejectTrade(trade_id, reason)
    local trade = self.pending_trades[trade_id]
    if not trade then
        return false, "Trade not found"
    end
    
    trade.status = "rejected"
    trade.rejected_reason = reason or "No reason provided"
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cffff0000Trade rejected: %s|r",
                trade.rejected_reason
            )
        )
    end
    
    return true, "Trade rejected"
end

function Trade:CancelTrade(trade_id, reason)
    if self.pending_trades[trade_id] then
        self.pending_trades[trade_id].status = "cancelled"
        self.pending_trades[trade_id].cancelled_reason = reason or "Cancelled"
    end
end

function Trade:GenerateTradeID()
    local id = "TRADE_" .. tostring(time()):reverse():sub(1, 8) .. "_" .. 
        string.format("%04d", math.random(9999))
    return id
end

function Trade:GetTradeStatus(trade_id)
    local trade = self.pending_trades[trade_id] or self.active_trades[trade_id]
    return trade and trade.status or nil
end

function Trade:EnableTrading(enable)
    self.config.trading_enabled = enable
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffDKP trading %s|r", status))
    return true
end

function Trade:SetTradeLimit(min_amount, max_amount)
    if min_amount < 1 or max_amount < min_amount then
        print("|cffff0000Invalid trade limits|r")
        return false
    end
    
    self.config.min_trade_amount = min_amount
    self.config.max_trade_amount = max_amount
    print(string.format("|cff00ccffTrade limit set to %d-%d DKP|r", min_amount, max_amount))
    return true
end

function Trade:SetTradeTax(rate)
    if rate < 0 or rate > 1 then
        print("|cffff0000Tax rate must be 0-1 (0%-100%)|r")
        return false
    end
    
    self.config.trade_tax_rate = rate
    print(string.format("|cff00ccffTrade tax set to %.1f%%|r", rate * 100))
    return true
end

function Trade:PrintStatus()
    print("|cff00ccffDKP Trading Status:|r")
    print(string.format("  Enabled: %s", self.config.trading_enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Trade Limit: %d-%d DKP", self.config.min_trade_amount, self.config.max_trade_amount))
    print(string.format("  Tax Rate: %.1f%%", self.config.trade_tax_rate * 100))
    print(string.format("  Cooldown: %d seconds", self.config.trade_cooldown))
    print(string.format("  Pending Trades: %d", self:CountPendingTrades()))
    print("")
end

function Trade:CountPendingTrades()
    local count = 0
    for _, trade in pairs(self.pending_trades) do
        if trade.status == "pending" then
            count = count + 1
        end
    end
    return count
end

function Trade:GetTradeHistory(limit)
    limit = limit or 20
    
    local history = {}
    for i = #self.trade_history, math.max(1, #self.trade_history - limit + 1), -1 do
        table.insert(history, self.trade_history[i])
    end
    
    return history
end

return PluribusDKP.Trade
